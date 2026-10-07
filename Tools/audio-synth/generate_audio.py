#!/usr/bin/env python3
"""FisuEvolution — sintetizador de audio del juego (100% código, 0 samples).

Genera todos los SFX y los dos loops de música por síntesis sustractiva usando
SOLO la stdlib de Python (wave, math, struct, random con seed fija →
determinístico: dos corridas producen bytes idénticos).

Cadena de señal: osciladores band-limited → filtro (pasabajos resonante con
envolvente) → saturación suave (tanh) → reverb Schroeder → normalización.
El filtro y la reverb son lo que separa "un beep" de "un sonido": la versión
anterior era wavetable en seco y por eso sonaba a código.

Salida:
  - WAV intermedios en  Tools/audio-synth/build/
  - Finales via afconvert en FisuEvolution/Resources/Audio/, todos .caf LEI16.

**Formato — es contrato.** `AudioManager.url(forResource:)` prueba las
extensiones caf, m4a y wav en ese orden, y busca por el `rawValue` del enum
`AudioManager.SFX`. Los nombres de acá tienen que coincidir exactamente o el
juego se queda mudo (loguea `audio asset missing`) sin romperse.

**Nada de AAC/m4a para la música**: el encoder AAC agrega priming/padding que
mete un hueco en el punto de loop, y `AVAudioPlayer` corre con
`numberOfLoops = -1` sin crossfade. PCM es la única garantía de costura limpia.

**Presupuesto de bytes.** Un .caf LEI16 pesa 4096 (cabecera) + 2 bytes por
frame. El techo es lo que pesaba la versión anterior:
    earth   1.768.096 B  →  882.000 frames
    cosmic  2.356.096 B  → ≤1.176.000 frames
Para gastar esos frames en tiempo y no en ancho de banda, cada loop se
renderiza a su propia frecuencia de muestreo: 22.050 Hz el terrenal (es lo-fi
por diseño, el parlante del teléfono no pasa de 10 kHz igual) y 32.000 Hz el
cósmico (necesita brillo en las campanas). Eso compra 40 s y 36 s de loop
contra los 20 s y 26,7 s de antes — la mitad del problema de "cansa en la
décima repetición" es que el loop era corto.

Loops perfectos: los music_* se renderizan con "wrap-around" (todo evento cuya
cola pasa el final se suma al principio, módulo N) y la reverb se corre DOS
veces sobre el buffer periódico quedándose con la segunda pasada, así el estado
de los peines al final es el mismo que al principio. El largo cae exacto en
frontera de compás. Al final se verifica el salto entre la última muestra y la
primera (assert).

Normalización: SFX pico a -3 dBFS, música pico a -9 dBFS (los mismos de antes,
para no cambiarle el balance de volumen al jugador).
"""

import math
import os
import random
import struct
import subprocess
import sys
import wave

HERE = os.path.dirname(os.path.abspath(__file__))
BUILD = os.path.join(HERE, "build")
DEST = os.path.normpath(
    os.path.join(HERE, "..", "..", "FisuEvolution", "Resources", "Audio")
)

SR_SFX = 44100
SR_EARTH = 22050
SR_COSMIC = 32000

SFX_PEAK_DB = -3.0
MUSIC_PEAK_DB = -9.0
RMS_FLOOR_DB = -60.0

CAF_HEADER_BYTES = 4096
MAX_BYTES = {
    "music_earth_loop": 1_768_096,
    "music_cosmic_loop": 2_356_096,
}

TWO_PI = 2.0 * math.pi
TABLE_SIZE = 4096

# ---------------------------------------------------------------------------
# Wavetables (aditivas, band-limited contra el Nyquist de CADA frecuencia
# de muestreo — a 22.050 Hz un armónico que a 44.100 era legal aliasea)
# ---------------------------------------------------------------------------

_tables = {}


def _build_table(kind, max_harm):
    tab = []
    for i in range(TABLE_SIZE):
        x = i / TABLE_SIZE
        v = 0.0
        if kind == "sine":
            v = math.sin(TWO_PI * x)
        elif kind == "square":
            n = 1
            while n <= max_harm:
                v += math.sin(TWO_PI * n * x) / n
                n += 2
        elif kind == "triangle":
            n = 1
            sign = 1.0
            while n <= max_harm:
                v += sign * math.sin(TWO_PI * n * x) / (n * n)
                sign = -sign
                n += 2
        elif kind == "saw":
            for n in range(1, max_harm + 1):
                v += math.sin(TWO_PI * n * x) / n
        tab.append(v)
    peak = max(abs(s) for s in tab) or 1.0
    return [s / peak for s in tab]


def table_for(kind, freq, sr):
    """Tabla del timbre pedido, con los armónicos cortados bajo 0,9·Nyquist."""
    if kind == "sine":
        max_harm = 1
    else:
        ceiling = 0.9 * sr / 2.0
        max_harm = max(1, min(24, int(ceiling / max(freq, 1.0))))
        if kind in ("square", "triangle") and max_harm % 2 == 0:
            max_harm -= 1
            max_harm = max(1, max_harm)
    key = (kind, max_harm)
    if key not in _tables:
        _tables[key] = _build_table(kind, max_harm)
    return _tables[key]


# ---------------------------------------------------------------------------
# Envolventes (todas terminan en 0 → sin clicks)
# ---------------------------------------------------------------------------

def env_perc(dur, attack=0.004, curve=6.0):
    """Ataque lineal corto + decay exponencial + fade final a 0 exacto."""
    rel = min(0.012, dur * 0.2)

    def e(t):
        g = (t / attack) if t < attack else math.exp(-curve * (t - attack) / dur)
        if t > dur - rel:
            g *= max(0.0, (dur - t) / rel)
        return g

    return e


def env_sustain(dur, a=0.008, r=0.03):
    def e(t):
        if t < a:
            return t / a
        if t > dur - r:
            return max(0.0, (dur - t) / r)
        return 1.0

    return e


def env_swell(dur, a, r):
    """Trapecio suavizado (smoothstep) para pads: sube, sostiene, baja a 0."""

    def smooth(x):
        x = max(0.0, min(1.0, x))
        return x * x * (3.0 - 2.0 * x)

    def e(t):
        if t < a:
            return smooth(t / a)
        if t > dur - r:
            return smooth((dur - t) / r)
        return 1.0

    return e


# ---------------------------------------------------------------------------
# Motor de render
# ---------------------------------------------------------------------------

def render_tone(buf, sr, start_s, dur_s, freq, kind="sine", amp=1.0, env=None,
                vib_hz=0.0, vib_depth=0.0, detune_cents=0.0, wrap=False,
                phase=0.0, lp_hz=None):
    """Suma un tono al buffer. `freq` es Hz fijo o callable(t)->Hz.

    `lp_hz` (Hz fijo o callable(t)->Hz) mete un pasabajos de un polo DENTRO de
    la voz: con un cutoff que decae, una onda estática pasa a sonar a púa o a
    mazo. Es la diferencia entre "beep" y "nota".

    Con wrap=True los samples que pasan el final del buffer se suman al
    principio (módulo N) → loop perfecto por construcción.
    """
    n = len(buf)
    f0 = freq(0.0) if callable(freq) else freq
    table = table_for(kind, f0 * (2 ** (vib_depth + abs(detune_cents) / 1200.0)), sr)
    ts = len(table)
    start = int(round(start_s * sr))
    count = int(round(dur_s * sr))
    det = 2.0 ** (detune_cents / 1200.0)
    ph = phase * ts
    inv_sr = 1.0 / sr
    step_k = ts * inv_sr
    fixed = not callable(freq)
    lp_fixed = lp_hz is not None and not callable(lp_hz)
    lp_a = 0.0
    if lp_fixed:
        lp_a = 1.0 - math.exp(-TWO_PI * lp_hz * inv_sr)
    lp_y = 0.0
    for i in range(count):
        t = i * inv_sr
        f = freq if fixed else freq(t)
        if vib_depth:
            f *= 1.0 + vib_depth * math.sin(TWO_PI * vib_hz * t)
        ph += f * det * step_k
        idx = ph % ts
        i0 = int(idx)
        frac = idx - i0
        s0 = table[i0]
        v = s0 + (table[(i0 + 1) % ts] - s0) * frac
        if lp_hz is not None:
            if not lp_fixed:
                lp_a = 1.0 - math.exp(-TWO_PI * lp_hz(t) * inv_sr)
            lp_y += lp_a * (v - lp_y)
            v = lp_y
        g = env(t) if env else 1.0
        j = start + i
        if wrap:
            j %= n
        elif j >= n:
            break
        buf[j] += v * amp * g


def render_noise(buf, sr, start_s, dur_s, amp, decay, rng, env=None, wrap=False,
                 center=None, q=1.2):
    """Ruido con decay. Con `center` pasa por un pasabanda (escobilla, shaker,
    aire); sin `center`, ruido blanco con un pasaaltos de primera diferencia.

    El pasabanda es lo que hace que la percusión suene a percusión y no a
    "pssst": el ruido blanco crudo no tiene carácter y encima cambia de color
    con la frecuencia de muestreo.
    """
    n = len(buf)
    start = int(round(start_s * sr))
    count = int(round(dur_s * sr))
    rel = min(0.005, dur_s * 0.2)
    inv_sr = 1.0 / sr
    prev = 0.0
    # Filtro de estado variable para el pasabanda (coeficientes clampeados:
    # ver svf_coeffs, que es donde vive la condición de estabilidad).
    f_svf, damp_svf = svf_coeffs(center or 1000.0, q, sr)
    low = band = 0.0
    for i in range(count):
        t = i * inv_sr
        w = rng.uniform(-1.0, 1.0)
        if center is None:
            v = (w - prev) * 0.5
            prev = w
        else:
            low += f_svf * band
            high = w - low - damp_svf * band
            band += f_svf * high
            v = band * 0.6
        g = env(t) if env else math.exp(-t / decay)
        if env is None and t > dur_s - rel:
            g *= max(0.0, (dur_s - t) / rel)
        j = start + i
        if wrap:
            j %= n
        elif j >= n:
            break
        buf[j] += v * amp * g


def render_bell(buf, sr, start_s, dur_s, freq, amp, rng=None, wrap=False,
                partials=((1.0, 1.0), (2.01, 0.42), (3.03, 0.22), (4.17, 0.12),
                          (5.43, 0.07))):
    """Campana: parciales inarmónicos con decay más rápido cuanto más agudos.

    Es aditiva pura, pero la inarmonicidad y el decay diferencial son lo que
    la separan de un seno con envolvente.
    """
    for ratio, gain in partials:
        f = freq * ratio
        if f > 0.45 * sr:
            continue
        d = dur_s / (1.0 + 0.55 * (ratio - 1.0))
        render_tone(buf, sr, start_s, d, f, "sine", amp * gain,
                    env_perc(d, attack=0.006, curve=4.2), wrap=wrap)


# ---------------------------------------------------------------------------
# Procesadores de bus
# ---------------------------------------------------------------------------

def highpass(buf, sr, hz, poles=1, wrap=False):
    """Pasaaltos. Saca la energía por debajo de lo que el parlante del teléfono
    puede mover: abajo de ~200 Hz un iPhone no reproduce nada, así que todo lo
    que va ahí es headroom tirado a la basura — y encima se come el margen de
    normalización que le hace falta a lo que sí se escucha.

    Un polo solo son 6 dB/octava, que casi no mueve la aguja; con dos ya se
    nota.

    `wrap=True` hace primero una pasada EN VACÍO (lee el buffer sin escribirlo)
    para dejar el estado del filtro donde estaría si el loop ya viniera
    sonando. Sin eso, el filtro arranca en cero y mete un escalón en la muestra
    0: mientras el loop empezaba en silencio no se notaba, pero apenas empieza
    con señal — que es justo lo que hay que lograr para que no haya bache — el
    escalón es un click en cada vuelta.
    """
    a = 1.0 / (1.0 + TWO_PI * hz / sr)
    for _ in range(poles):
        y = 0.0
        xp = 0.0
        if wrap:
            for x in buf:
                y = a * (y + x - xp)
                xp = x
        for i, x in enumerate(buf):
            y = a * (y + x - xp)
            xp = x
            buf[i] = y
    return buf


def lowpass_lfo(buf, sr, base_hz, depth, lfo_hz, q=0.9, wrap=False):
    """Pasabajos resonante con el cutoff barrido por un LFO senoidal.

    El barrido lento es lo que hace que un pad de 36 s no suene igual en el
    segundo 3 que en el 30 sin que haya que escribir notas distintas.

    Con `wrap=True`, pasada en vacío previa (ver `highpass`). El LFO tiene que
    completar un número ENTERO de ciclos en el largo del buffer o el barrido
    tampoco empalma: `lfo_hz` se elige para eso.
    """
    inv_sr = 1.0 / sr
    # El cutoff se mueve, así que los coeficientes se calculan por muestra —
    # pero siempre por svf_coeffs, que es quien garantiza la estabilidad.
    low = band = 0.0
    if wrap:
        for i, x in enumerate(buf):
            fc = base_hz * (1.0 + depth * math.sin(TWO_PI * lfo_hz * i * inv_sr))
            f, damp = svf_coeffs(fc, q, sr)
            low += f * band
            high = x - low - damp * band
            band += f * high
    for i, x in enumerate(buf):
        fc = base_hz * (1.0 + depth * math.sin(TWO_PI * lfo_hz * i * inv_sr))
        f, damp = svf_coeffs(fc, q, sr)
        low += f * band
        high = x - low - damp * band
        band += f * high
        buf[i] = low
    return buf


def saturate(buf, drive=1.6):
    """Saturación suave. Sube el RMS sin subir el pico y pega los armónicos:
    es lo que hace que una mezcla sintética suene compacta y no a capas sueltas.
    """
    k = math.tanh(drive) or 1.0
    for i, x in enumerate(buf):
        buf[i] = math.tanh(x * drive) / k
    return buf


def reverb(buf, sr, room=0.80, damp=0.32, wet=0.26, wrap=False):
    """Reverb Schroeder (4 peines en paralelo + 2 allpass en serie).

    Con wrap=True corre DOS pasadas sobre el mismo buffer periódico y devuelve
    la segunda: al entrar la segunda vez, el estado de los peines ya es el
    estado "de régimen", así que la cola que sale por el final es exactamente
    la que ya está sonando al principio. Sin esto, agregar reverb a un loop
    rompe la costura que tanto cuesta conseguir.
    """
    scale = sr / 44100.0
    cl = [max(8, int(round(d * scale))) for d in (1116, 1188, 1277, 1356)]
    al = [max(8, int(round(d * scale))) for d in (556, 441)]
    c0, c1, c2, c3 = ([0.0] * L for L in cl)
    a0, a1 = ([0.0] * L for L in al)
    i0 = i1 = i2 = i3 = j0 = j1 = 0
    l0 = l1 = l2 = l3 = 0.0
    n0, n1, n2, n3 = cl
    m0, m1 = al
    keep = 1.0 - damp
    dry = 1.0 - wet
    out = buf
    for _ in range(2 if wrap else 1):
        out = [0.0] * len(buf)
        for i, x in enumerate(buf):
            v = c0[i0]
            l0 = v * keep + l0 * damp
            c0[i0] = x + l0 * room
            i0 = i0 + 1 if i0 + 1 < n0 else 0
            acc = v
            v = c1[i1]
            l1 = v * keep + l1 * damp
            c1[i1] = x + l1 * room
            i1 = i1 + 1 if i1 + 1 < n1 else 0
            acc += v
            v = c2[i2]
            l2 = v * keep + l2 * damp
            c2[i2] = x + l2 * room
            i2 = i2 + 1 if i2 + 1 < n2 else 0
            acc += v
            v = c3[i3]
            l3 = v * keep + l3 * damp
            c3[i3] = x + l3 * room
            i3 = i3 + 1 if i3 + 1 < n3 else 0
            acc += v
            acc *= 0.25
            v = a0[j0]
            a0[j0] = acc + v * 0.5
            acc = v - acc
            j0 = j0 + 1 if j0 + 1 < m0 else 0
            v = a1[j1]
            a1[j1] = acc + v * 0.5
            acc = v - acc
            j1 = j1 + 1 if j1 + 1 < m1 else 0
            out[i] = x * dry + acc * wet
    return out


# ---------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------

def svf_coeffs(center, q, sr):
    """Coeficientes del filtro de estado variable de Chamberlin, CLAMPEADOS.

    ⚠️ El filtro es inestable si `f + 1/q >= 2`, y `f` crece con `center/sr`.
    Un centro de 5,2 kHz con q=1,1 es seguro a 44.100 Hz (f=0,72) y EXPLOTA a
    22.050 Hz (f=1,35 contra un límite de 1,09). Es exactamente lo que pasó al
    bajarle la frecuencia de muestreo a la música: la mezcla se fue a +1293 dB,
    la saturación la recortó a fondo de escala y el loop terrenal salió siendo
    un zumbido. Los coeficientes de un filtro NO son portables entre
    frecuencias de muestreo, y por eso se calculan en un solo lugar.

    Es estable mientras `damp < 2` y `f < 2 - damp`, así que se acotan LOS DOS:
    la amortiguación a 1,4 (un `q` más bajo que eso ya no describe ningún
    filtro estable) y la frecuencia al margen que quede. Acotar sólo `f` contra
    `2 - damp` no alcanza: con q=0,5 la cuenta da `f < -0,1`, o sea una
    frecuencia negativa, y el filtro diverge lo mismo.
    """
    damp = min(1.4, 1.0 / max(q, 0.05))
    fc = max(40.0, min(center, sr / 6.0))
    f = 2.0 * math.sin(math.pi * fc / sr)
    return max(0.02, min(f, 1.9 - damp)), damp


def assert_sane(buf, label):
    """Un bus sano vive cerca de ±1. Si se fue a las nubes, hay un filtro
    inestable: cortar acá y no dejar que la normalización lo disimule."""
    pk = max(abs(x) for x in buf)
    if not (pk == pk) or pk > 100.0:  # NaN o explosión
        raise RuntimeError(
            f"{label}: la mezcla se fue a pico {pk:.3g} — hay un filtro "
            f"inestable (ver svf_coeffs)")
    return buf


def midi_hz(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def glide(f0, f1, dur):
    """Barrido exponencial de f0 a f1 en dur segundos."""
    ratio = f1 / f0
    return lambda t: f0 * ratio ** (min(t, dur) / dur)


def decay_to(v0, v1, tau):
    """Cutoff que cae de v0 a v1 con constante tau (para filtros de púa)."""
    return lambda t: v1 + (v0 - v1) * math.exp(-t / tau)


def edge_fades(buf, sr, fade_in=0.002, fade_out=0.010):
    n_in = max(1, int(fade_in * sr))
    n_out = max(1, int(fade_out * sr))
    for i in range(min(n_in, len(buf))):
        buf[i] *= i / n_in
    for i in range(min(n_out, len(buf))):
        buf[len(buf) - 1 - i] *= i / n_out


def normalize(buf, peak_db):
    peak = max(abs(x) for x in buf)
    if peak == 0.0:
        raise RuntimeError("buffer en silencio total")
    target = 10.0 ** (peak_db / 20.0)
    scale = target / peak
    return [x * scale for x in buf]


def write_wav(path, buf, sr):
    frames = bytearray()
    for x in buf:
        x = max(-1.0, min(1.0, x))
        frames += struct.pack("<h", int(round(x * 32767.0)))
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(bytes(frames))


def measure(buf):
    peak = max(abs(x) for x in buf)
    rms = math.sqrt(sum(x * x for x in buf) / len(buf))
    to_db = lambda v: (20.0 * math.log10(v)) if v > 0 else float("-inf")
    return to_db(peak), to_db(rms)


def seam_ratio(buf, window=2000):
    """Salto en el punto de loop, MEDIDO CONTRA el salto típico entre muestras
    vecinas.

    El salto crudo no sirve como criterio: entre dos muestras contiguas de un
    loop con escobillas a 4 kHz hay naturalmente un salto grande, y entre dos
    de un pad grave no hay casi ninguno. Lo que delata un click es que el salto
    del punto de loop se salga de la distribución de sus vecinos. Un loop
    perfecto da ~1×.
    """
    d = abs(buf[0] - buf[-1])
    diffs = [buf[i] - buf[i - 1] for i in range(1, window)]
    diffs += [buf[i] - buf[i - 1] for i in range(len(buf) - window, len(buf))]
    rms = math.sqrt(sum(x * x for x in diffs) / len(diffs))
    return d / rms if rms else float("inf")


def edge_life(buf, sr, ms=50.0):
    """Nivel de los 50 ms del principio y del final, como fracción del RMS del
    track. Detecta el otro defecto de loop, que no es un click sino un HUECO.

    El loop terrenal anterior terminaba en 0,08× su propio nivel medio: 40 ms
    de silencio digital antes de volver a empezar, o sea un bache rítmico cada
    20 segundos. El cósmico se apagaba en los dos bordes (0,06× y 0,08×), que
    es un bajón de volumen cada vuelta.
    """
    k = max(1, int(sr * ms / 1000.0))
    glob = math.sqrt(sum(x * x for x in buf) / len(buf)) or 1e-12
    head = math.sqrt(sum(x * x for x in buf[:k]) / k)
    tail = math.sqrt(sum(x * x for x in buf[-k:]) / k)
    return head / glob, tail / glob


_FFT_N = 4096


def _fft(a):
    """FFT radix-2 iterativa (Cooley-Tukey), len(a) potencia de 2."""
    n = len(a)
    j = 0
    for i in range(1, n):
        bit = n >> 1
        while j & bit:
            j ^= bit
            bit >>= 1
        j |= bit
        if i < j:
            a[i], a[j] = a[j], a[i]
    length = 2
    while length <= n:
        ang = -TWO_PI / length
        wl = complex(math.cos(ang), math.sin(ang))
        for i in range(0, n, length):
            w = 1 + 0j
            half = length >> 1
            for k in range(i, i + half):
                u = a[k]
                v = a[k + half] * w
                a[k] = u + v
                a[k + half] = u - v
                w *= wl
        length <<= 1
    return a


def _spectrum(buf, sr, windows=24):
    """Potencia media por bin, con ventana Hann, promediando hasta `windows`
    tramos repartidos por todo el archivo.

    Dos detalles que ya dieron números falsos una vez:

    - Todos los bins, no un muestreo: con ventana Hann la energía de un tono
      cae en 3-4 bins contiguos, así que saltear bins hace que un pico angosto
      se mida como si no existiera.
    - Varios tramos, no el más fuerte: 4096 muestras son 93 ms, y juzgar un
      loop de 40 s por sus 93 ms más fuertes mide un golpe, no la mezcla.
    """
    N = _FFT_N
    if len(buf) <= N:
        starts = [0]
        pad = list(buf) + [0.0] * (N - len(buf))
        segs = [pad]
    else:
        count = max(1, min(windows, len(buf) // N))
        stride = (len(buf) - N) / count if count > 1 else 0
        starts = [int(i * stride) for i in range(count)]
        segs = [buf[s:s + N] for s in starts]
    hann = [0.5 - 0.5 * math.cos(TWO_PI * i / (N - 1)) for i in range(N)]
    acc = [0.0] * (N // 2 - 1)
    for seg in segs:
        spec = _fft([complex(v * w, 0.0) for v, w in zip(seg, hann)])
        # El bin 0 (DC) se descarta: no es sonido y ensucia el reparto.
        for k in range(len(acc)):
            c = spec[k + 1]
            acc[k] += c.real * c.real + c.imag * c.imag
    return acc, sr / N


def band_share(buf, sr, lo, hi):
    """Porción de energía (0..1) en [lo, hi) Hz. Sirve para chequear
    afirmaciones de mezcla con un assert en vez de con un 'me parece que'."""
    mags, df = _spectrum(buf, sr)
    total = sum(mags) or 1.0
    inside = sum(m for k, m in enumerate(mags) if lo <= (k + 1) * df < hi)
    return inside / total


def centroid(buf, sr):
    """Centroide espectral en Hz: el número que dice si dos sonidos que suenan
    uno atrás del otro se van a confundir."""
    mags, df = _spectrum(buf, sr)
    den = sum(mags) or 1.0
    return sum(m * (k + 1) * df for k, m in enumerate(mags)) / den


# ---------------------------------------------------------------------------
# SFX
# ---------------------------------------------------------------------------
# Reglas del frente: todos por debajo de 400 ms salvo `evolution` y `prestige`,
# que son celebraciones; y `merge` / `evolution` tienen que ser DISTINGUIBLES
# porque suenan uno atrás del otro cuando un merge asciende de tier.

def sfx_tap():
    """Mazo de madera ~90 ms. Es el sonido más frecuente del juego, así que es
    corto, mate y sin cola: un seno con cuerpo, un golpe de mazo filtrado y una
    pizca de aire. Antes era un seno pelado de 60 ms — 100% de la energía en una
    sola banda, o sea un beep."""
    sr = SR_SFX
    dur = 0.090
    buf = [0.0] * int(dur * sr)
    rng = random.Random(11)
    e = env_perc(0.070, attack=0.001, curve=8.0)
    # Cuerpo: triangular con el cutoff cayendo → "tok" de madera.
    render_tone(buf, sr, 0.0, 0.070, glide(700.0, 610.0, 0.070), "triangle",
                0.85, e, lp_hz=decay_to(4200.0, 900.0, 0.012))
    render_tone(buf, sr, 0.0, 0.055, glide(1400.0, 1230.0, 0.055), "sine",
                0.22, env_perc(0.055, attack=0.001, curve=11.0))
    # Golpe: click de ruido muy corto que le da definición al ataque.
    render_noise(buf, sr, 0.0, 0.012, 0.30, 0.003, rng, center=2600.0, q=0.8)
    return sr, reverb(buf, sr, room=0.62, damp=0.45, wet=0.10)


def sfx_merge():
    """Dos piezas que encajan ~170 ms: GRAVE y mate, pero SUBIENDO.

    Dos decisiones, las dos por contraste con otro sonido:

    - Grave y opaco para no chocar con `evolution`. Antes los dos eran arpegios
      de cuadradas ascendentes con el centroide en 1021 y 1023 Hz: indistinguibles,
      y suenan uno atrás del otro cuando un merge asciende de tier. Ahora éste
      vive en 400 Hz y el otro en 2200.
    - Sube una tercera menor (440→523 Hz) en vez de bajar. Un merge es un
      acierto, y en la gramática de un juego lo que baja de tono se lee como
      error — que además es justo el otro sonido opaco de la paleta."""
    sr = SR_SFX
    dur = 0.170
    buf = [0.0] * int(dur * sr)
    rng = random.Random(22)
    # Golpe 1: mazo medio, seco.
    e1 = env_perc(0.075, attack=0.002, curve=7.0)
    render_tone(buf, sr, 0.0, 0.075, 440.0, "triangle", 0.75, e1,
                lp_hz=decay_to(2600.0, 700.0, 0.018))
    render_tone(buf, sr, 0.0, 0.075, 220.0, "sine", 0.45, e1)
    # Golpe 2: sube una tercera menor y se abre — sensación de "encajó".
    e2 = env_perc(0.105, attack=0.003, curve=5.0)
    render_tone(buf, sr, 0.062, 0.105, 523.25, "triangle", 0.80, e2,
                detune_cents=-6.0, lp_hz=decay_to(2400.0, 620.0, 0.030))
    render_tone(buf, sr, 0.062, 0.105, 523.25, "triangle", 0.55, e2,
                detune_cents=7.0, lp_hz=decay_to(2200.0, 580.0, 0.030))
    render_tone(buf, sr, 0.062, 0.105, 261.6, "sine", 0.50, e2)
    render_noise(buf, sr, 0.062, 0.020, 0.16, 0.006, rng, center=1500.0, q=0.7)
    return sr, reverb(buf, sr, room=0.66, damp=0.55, wet=0.14)


def sfx_evolution():
    """Ascenso de tier ~560 ms: BRILLANTE y ascendente, con cola de campanas.

    Es la contracara de `merge`: sube dos octavas, vive arriba de 1,5 kHz y
    deja cola. Los dos suenan pegados y tienen que leerse como dos cosas."""
    sr = SR_SFX
    dur = 0.560
    buf = [0.0] * int(dur * sr)
    # Arpegio ascendente con púa filtrada: C6 E6 G6 C7.
    arp = [(0.000, 1046.5), (0.062, 1318.5), (0.124, 1568.0), (0.186, 2093.0)]
    for t0, f in arp:
        e = env_perc(0.130, attack=0.003, curve=4.5)
        render_tone(buf, sr, t0, 0.130, f, "saw", 0.42, e,
                    lp_hz=decay_to(9000.0, 2400.0, 0.040))
        render_tone(buf, sr, t0, 0.130, f, "sine", 0.30, e)
    # Remate: campana en C7 con cola inarmónica.
    render_bell(buf, sr, 0.250, 0.300, 2093.0, 0.40)
    render_bell(buf, sr, 0.290, 0.260, 3136.0, 0.20)
    return sr, reverb(buf, sr, room=0.84, damp=0.16, wet=0.34)


def sfx_coin():
    """Moneda ~200 ms: dos notas agudas con un parcial metálico encima."""
    sr = SR_SFX
    dur = 0.200
    buf = [0.0] * int(dur * sr)
    e1 = env_perc(0.060, attack=0.002, curve=6.0)
    render_tone(buf, sr, 0.0, 0.060, 988.0, "saw", 0.50, e1,
                lp_hz=decay_to(7000.0, 2200.0, 0.020))
    render_tone(buf, sr, 0.0, 0.060, 988.0, "sine", 0.35, e1)
    render_bell(buf, sr, 0.055, 0.140, 1319.0, 0.55)
    return sr, reverb(buf, sr, room=0.76, damp=0.28, wet=0.22)


def sfx_buy():
    """Compra ~150 ms: click doble mate, con cajón de madera y un tintineo."""
    sr = SR_SFX
    dur = 0.150
    buf = [0.0] * int(dur * sr)
    rng = random.Random(33)
    e1 = env_perc(0.050, attack=0.001, curve=8.0)
    render_tone(buf, sr, 0.0, 0.050, 620.0, "triangle", 0.70, e1,
                lp_hz=decay_to(3200.0, 800.0, 0.012))
    render_noise(buf, sr, 0.0, 0.014, 0.24, 0.004, rng, center=2200.0, q=0.8)
    e2 = env_perc(0.085, attack=0.002, curve=5.5)
    render_tone(buf, sr, 0.058, 0.085, 932.0, "triangle", 0.75, e2,
                lp_hz=decay_to(4000.0, 1000.0, 0.020))
    render_bell(buf, sr, 0.062, 0.080, 1864.0, 0.20)
    return sr, reverb(buf, sr, room=0.68, damp=0.42, wet=0.16)


def sfx_error():
    """Rechazo ~230 ms. **Subido de registro a propósito.**

    La versión anterior era un buzz de cuadradas a 110 Hz: el 69,5% de su
    energía caía abajo de 200 Hz, que es justo donde el parlante de un teléfono
    no reproduce nada — o sea, en el dispositivo real casi no se oía. Ahora el
    grueso vive entre 300 y 900 Hz (dos notas que bajan un semitono, con roce
    detuneado), que suena igual de "no" pero se escucha."""
    sr = SR_SFX
    dur = 0.230
    buf = [0.0] * int(dur * sr)
    e = env_perc(dur * 0.85, attack=0.006, curve=3.4)
    for det, gain in ((-14.0, 0.55), (0.0, 0.62), (15.0, 0.55)):
        render_tone(buf, sr, 0.0, dur * 0.85, glide(392.0, 349.2, dur * 0.85),
                    "square", gain, e, detune_cents=det,
                    lp_hz=decay_to(2600.0, 900.0, 0.070))
    # Un poco de cuerpo abajo, pero sólo un poco: es sabor, no el sonido.
    render_tone(buf, sr, 0.0, dur * 0.7, glide(196.0, 174.6, dur * 0.7), "sine",
                0.30, env_perc(dur * 0.7, attack=0.006, curve=3.4))
    out = reverb(buf, sr, room=0.60, damp=0.60, wet=0.10)
    return sr, highpass(out, sr, 150.0)


def sfx_rare():
    """Hallazgo raro ~390 ms: chispas agudas con eco, bien arriba."""
    sr = SR_SFX
    dur = 0.390
    buf = [0.0] * int(dur * sr)
    notes = [(0.000, 1568.0), (0.048, 2093.0), (0.096, 2637.0)]  # G6 C7 E7
    for gain, offset in ((1.0, 0.0), (0.38, 0.150)):
        for t0, f in notes:
            render_bell(buf, sr, t0 + offset, 0.150, f, 0.45 * gain,
                        partials=((1.0, 1.0), (2.76, 0.30), (5.40, 0.12)))
    return sr, reverb(buf, sr, room=0.86, damp=0.12, wet=0.36)


def sfx_prestige():
    """Reencarnación ~950 ms: riser + acorde mayor abierto con cola larga."""
    sr = SR_SFX
    dur = 0.950
    buf = [0.0] * int(dur * sr)
    rise = 0.52
    rng = random.Random(404)
    # Barrido: saw filtrada que abre el cutoff mientras sube de tono.
    render_tone(buf, sr, 0.0, rise, glide(196.0, 784.0, rise), "saw", 0.40,
                lambda t: (t / rise) ** 1.4 * (1.0 if t < rise - 0.012
                                               else max(0.0, (rise - t) / 0.012)),
                vib_hz=7.0, vib_depth=0.003,
                lp_hz=lambda t: 500.0 + 6500.0 * (t / rise) ** 1.6)
    render_noise(buf, sr, 0.0, rise, 0.26, 1.0, rng, center=3200.0, q=1.6,
                 env=lambda t: (t / rise) ** 2.2
                 * (1.0 if t < rise - 0.012 else max(0.0, (rise - t) / 0.012)))
    # Acorde: C mayor add9 abierto, pares detuneados + campana en la punta.
    chord_dur = dur - rise
    e = env_perc(chord_dur, attack=0.010, curve=2.8)
    for f in (261.6, 392.0, 523.25, 659.26, 783.99):
        for det in (-7.0, 7.0):
            render_tone(buf, sr, rise, chord_dur, f, "saw", 0.16, e, detune_cents=det,
                        lp_hz=decay_to(5200.0, 1400.0, 0.28))
        render_tone(buf, sr, rise, chord_dur, f, "sine", 0.10, e)
    render_bell(buf, sr, rise + 0.02, chord_dur - 0.08, 1046.5, 0.26)
    return sr, reverb(buf, sr, room=0.88, damp=0.14, wet=0.34)


def sfx_event():
    """Aviso de evento ~280 ms: dos tonos, quinta abierta, timbre de campanita
    de mostrador. Neutro a propósito: no es premio ni castigo."""
    sr = SR_SFX
    dur = 0.280
    buf = [0.0] * int(dur * sr)
    render_bell(buf, sr, 0.000, 0.130, 587.33, 0.60,
                partials=((1.0, 1.0), (2.4, 0.34), (4.1, 0.14)))
    render_bell(buf, sr, 0.105, 0.170, 880.0, 0.66,
                partials=((1.0, 1.0), (2.4, 0.34), (4.1, 0.14)))
    return sr, reverb(buf, sr, room=0.80, damp=0.30, wet=0.26)


def sfx_daily():
    """Recompensa diaria ~330 ms: triada mayor en strum, cálida (púas
    filtradas en vez de cuadradas), con cola corta."""
    sr = SR_SFX
    dur = 0.330
    buf = [0.0] * int(dur * sr)
    for i, f in enumerate((523.25, 659.26, 783.99, 1046.5)):
        t0 = i * 0.036
        ring = dur - t0 - 0.02
        e = env_perc(ring, attack=0.004, curve=3.2)
        render_tone(buf, sr, t0, ring, f, "saw", 0.34, e,
                    lp_hz=decay_to(6000.0, 1500.0, 0.070))
        render_tone(buf, sr, t0, ring, f, "sine", 0.26, e)
    return sr, reverb(buf, sr, room=0.82, damp=0.24, wet=0.28)


# ---------------------------------------------------------------------------
# Música — loops perfectos (render con wrap-around)
# ---------------------------------------------------------------------------
# El juego arranca en un callejón de Buenos Aires y termina en el cosmos.
# `music_earth_loop` acompaña la parte terrenal y `music_cosmic_loop` la
# cósmica.
#
# Decisión de diseño, contra "cansa en la décima repetición": NINGUNO DE LOS
# DOS LLEVA MELODÍA CONTINUA. La versión anterior tenía una cuadrada tocando
# corcheas sin parar durante 20 s — una melodía en primer plano es lo primero
# que cansa cuando se escucha por horas. Acá el frente lo ocupan el groove, el
# bajo y la textura, y lo melódico entra de a ratos y por atrás.

# --- Terrenal: milonga lo-fi, 96 BPM, 16 compases 4/4 -----------------------
# 22.050 Hz × 882.000 frames = 40,000 s exactos (el doble que antes, en los
# mismos bytes). 16 compases = 2 vueltas de un ciclo armónico de 8, con
# instrumentación distinta en cada vuelta para que las repeticiones no calquen.
EARTH_BPM = 96
EARTH_BARS = 16

# Am–Dm–E7: la vuelta de milonga/tango, no el Am–F–C–G de cualquier juego.
# (raíz del bajo, acorde del bandoneón)
EARTH_CYCLE = [
    (45, (57, 60, 64)),   # Am
    (45, (57, 60, 64)),   # Am
    (50, (57, 62, 65)),   # Dm
    (40, (56, 59, 62)),   # E7  (G#3 B3 D4 → el trítono que pide resolver)
    (45, (57, 60, 64)),   # Am
    (41, (57, 60, 65)),   # F
    (50, (57, 62, 65)),   # Dm
    (40, (56, 59, 62)),   # E7
]
# Milonga: el acento 3+3+2 sobre las 8 corcheas del compás. Es LA figura
# rioplatense; con esto sólo, el loop ya suena de acá.
EARTH_ACCENTS = (0, 3, 6)


def music_earth_loop():
    sr = SR_EARTH
    beat = 60.0 / EARTH_BPM
    slot = beat / 2.0
    total = int(round(EARTH_BARS * 4 * beat * sr))  # 882000
    rng = random.Random(1987)

    bass = [0.0] * total
    pad = [0.0] * total
    pluck = [0.0] * total
    perc = [0.0] * total

    for bar in range(EARTH_BARS):
        root, chord = EARTH_CYCLE[bar % 8]
        second_half = bar >= 8
        bar_t = bar * 8 * slot

        # --- Bajo (contrabajo con púa): raíz y quinta en 3+3+2.
        # Nivel deliberadamente contenido: en la primera pasada el bajo se
        # llevaba el 75% de la energía del loop y dejaba el centroide en 236 Hz,
        # o sea un track que en el parlante de un teléfono es casi nada.
        for k, s in enumerate(EARTH_ACCENTS):
            note = root if k != 1 else root + 7
            if second_half and k == 2:
                note = root + 12
            t0 = bar_t + s * slot
            gate = (3 if k < 2 else 2) * slot * 0.86
            render_tone(bass, sr, t0, gate, midi_hz(note), "triangle", 0.24,
                        env_perc(gate, attack=0.006, curve=3.0),
                        lp_hz=decay_to(1400.0, 320.0, 0.09), wrap=True)
            render_tone(bass, sr, t0, gate * 0.8, midi_hz(note), "sine", 0.13,
                        env_perc(gate * 0.8, attack=0.006, curve=3.2), wrap=True)
            # Octava arriba: es la que hace que el bajo se OIGA en un teléfono.
            render_tone(bass, sr, t0, gate * 0.7, midi_hz(note + 12), "triangle",
                        0.11, env_perc(gate * 0.7, attack=0.008, curve=3.6),
                        lp_hz=decay_to(2000.0, 700.0, 0.06), wrap=True)

        # --- Bandoneón: colchón por compás + estocadas en los acentos 2 y 3.
        # El colchón se SOLAPA con el del compás vecino (arranca antes y
        # termina después): si cada compás abriera y cerrara en su propio
        # borde, el pad tocaría cero en cada línea de compás — y una de esas
        # líneas es el punto de loop, o sea un bache cada vuelta.
        bed_a, bed_r = 0.20, 0.35
        e_bed = env_swell(4 * beat + bed_a + bed_r, a=bed_a, r=bed_r)
        for m in chord:
            for det in (-8.0, 9.0):
                render_tone(pad, sr, bar_t - bed_a, 4 * beat + bed_a + bed_r,
                            midi_hz(m), "saw", 0.12, e_bed, detune_cents=det,
                            vib_hz=4.2, vib_depth=0.002, lp_hz=2000.0, wrap=True)
        for s in EARTH_ACCENTS[1:]:
            t0 = bar_t + s * slot
            gate = slot * 1.4
            e = env_perc(gate, attack=0.010, curve=3.6)
            for m in chord:
                render_tone(pad, sr, t0, gate, midi_hz(m), "saw", 0.16, e,
                            detune_cents=6.0, lp_hz=decay_to(3000.0, 900.0, 0.10),
                            wrap=True)

        # --- Guitarra: sólo en la segunda vuelta, y sólo en compases pares.
        # Que entre a mitad del loop es lo que hace que 40 s no suenen como
        # 20 s repetidos.
        if second_half and bar % 2 == 0:
            for k, s in enumerate((1, 4, 7)):
                m = chord[(k + bar // 2) % len(chord)] + 12
                t0 = bar_t + s * slot + rng.uniform(-0.006, 0.006)
                gate = slot * 2.0
                e = env_perc(gate, attack=0.003, curve=4.2)
                render_tone(pluck, sr, t0, gate, midi_hz(m), "saw", 0.34, e,
                            lp_hz=decay_to(4200.0, 1100.0, 0.045), wrap=True)

        # --- Escobillas: 3+3+2 marcado, y un shaker suave en las corcheas.
        # Son lo único con contenido arriba de 2 kHz: sin ellas el loop es puro
        # barro.
        for s in range(8):
            t0 = bar_t + s * slot + rng.uniform(-0.004, 0.004)
            if s in EARTH_ACCENTS:
                # Cuerpo de escobilla sobre parche, no siseo.
                render_noise(perc, sr, t0, 0.075, 0.30, 0.022, rng,
                             center=1800.0, q=0.9, wrap=True)
            else:
                # El shaker pide 5,2 kHz pero svf_coeffs lo recorta a sr/6
                # (3,7 kHz a 22.050 Hz). Alcanza para separarlo del acento.
                render_noise(perc, sr, t0, 0.035, 0.12, 0.010, rng,
                             center=5200.0, q=1.1, wrap=True)
        # Barrido de escobilla en el último tiempo de cada 4 compases: la cola
        # envuelve al principio del loop cuando toca el compás 16.
        if bar % 4 == 3:
            render_noise(perc, sr, bar_t + 3.2 * beat, 0.8 * beat, 0.16, 1.0,
                         rng, center=2400.0, q=0.6, wrap=True,
                         env=env_swell(0.8 * beat, a=0.55 * beat, r=0.2 * beat))

    # Bus del pad: barrido lento de filtro (0,05 Hz = un ciclo cada 20 s, o sea
    # medio loop) para que las dos vueltas no tengan el mismo color.
    lowpass_lfo(pad, sr, base_hz=1250.0, depth=0.40, lfo_hz=0.05, q=1.1, wrap=True)

    mix = [b + p + g + k for b, p, g, k in zip(bass, pad, pluck, perc)]
    assert_sane(mix, "music_earth_loop")
    # Fuera el subgrave: el 39% de la energía del loop viejo estaba abajo de
    # 200 Hz, donde el parlante del teléfono no reproduce nada.
    highpass(mix, sr, 85.0, poles=2, wrap=True)
    saturate(mix, drive=1.7)
    return sr, reverb(mix, sr, room=0.74, damp=0.42, wet=0.17, wrap=True)


# --- Cósmico: pads a la deriva, 80 BPM, 12 compases 4/4 ---------------------
# 32.000 Hz × 1.152.000 frames = 36,000 s exactos (contra 26,7 s), y 48 KB
# MENOS que el archivo anterior.
COSMIC_BPM = 80
COSMIC_BARS = 12

# Seis acordes de dos compases. Seis y no cuatro a propósito: un ciclo de
# cuatro se predice enseguida; uno de seis flota.
COSMIC_CYCLE = [
    (45, (60, 64, 67, 71)),   # Am9
    (41, (60, 65, 69, 72)),   # Fmaj7
    (48, (59, 64, 67, 74)),   # Cmaj9
    (40, (59, 62, 67, 71)),   # Em7
    (41, (57, 60, 65, 72)),   # Fmaj7 (otra voz)
    (43, (57, 62, 64, 69)),   # G6sus
]
# Motivo de campanas en pentatónica de La menor. Los tiempos NO caen en la
# grilla de 2 compases del acorde: así ninguna vuelta suena igual a la anterior.
COSMIC_BELLS = [
    (1.5, 76), (6.0, 81), (11.5, 72), (17.0, 79), (21.5, 84),
    (27.0, 74), (31.5, 81), (34.0, 88),
]


def music_cosmic_loop():
    sr = SR_COSMIC
    beat = 60.0 / COSMIC_BPM
    bar_s = 4.0 * beat
    total = int(round(COSMIC_BARS * bar_s * sr))  # 1152000
    rng = random.Random(2001)

    pad = [0.0] * total
    low = [0.0] * total
    bell = [0.0] * total
    air = [0.0] * total

    # Cada acorde se solapa con el siguiente por `xf` segundos: entra mientras
    # el anterior todavía suena. Sin el solape, cada acorde abriría y cerraría
    # en su propio borde y el pad tocaría cero seis veces por vuelta — una de
    # ellas justo en el punto de loop. Con wrap, el acorde 1 arranca "antes de
    # cero", o sea encima de la cola del acorde 6.
    xf = 1.8
    for ci, (root, chord) in enumerate(COSMIC_CYCLE):
        t0 = ci * 2 * bar_s - xf
        dur = 2 * bar_s + 2 * xf
        e = env_swell(dur, a=2 * xf, r=2 * xf)
        for m in chord:
            for det in (-7.0, 8.0):
                render_tone(pad, sr, t0, dur, midi_hz(m), "saw", 0.15, e,
                            detune_cents=det, lp_hz=2600.0, wrap=True)
            render_tone(pad, sr, t0, dur, midi_hz(m + 12), "sine", 0.060, e,
                        wrap=True)
        # Raíz: la nota grave, PERO doblada una octava arriba, y con la octava
        # pesando MÁS que el sub. El loop anterior tenía el 98% de la energía
        # abajo de 500 Hz y en un teléfono prácticamente desaparecía; la
        # primera pasada de éste seguía en el 12% entre 500 Hz y 4 kHz.
        e_low = env_swell(dur, a=2 * xf, r=2 * xf)
        render_tone(low, sr, t0, dur, midi_hz(root), "sine", 0.14, e_low, wrap=True)
        render_tone(low, sr, t0, dur, midi_hz(root + 12), "triangle", 0.24, e_low,
                    detune_cents=4.0, lp_hz=1100.0, wrap=True)

    # Campanas con eco: las colas envuelven el final del loop por construcción.
    for t0, m in COSMIC_BELLS:
        for gain, off in ((1.0, 0.0), (0.42, 0.75 * beat), (0.18, 1.5 * beat)):
            render_bell(bell, sr, t0 + off, 2.6 * beat, midi_hz(m), 0.22 * gain,
                        wrap=True)

    # Respiración: swells de aire que entran a los compases 4, 8 y 12 (el de 12
    # envuelve al 0). Es lo único rítmico del track.
    for target in (4, 8, 12):
        dur = 2.2 * beat
        render_noise(air, sr, target * bar_s - dur, dur, 0.085, 1.0, rng,
                     center=1800.0, q=0.5, wrap=True,
                     env=env_swell(dur, a=dur * 0.82, r=dur * 0.18))

    # Barrido de filtro de 1 ciclo cada 36 s = exactamente un loop: el color
    # nunca vuelve al mismo punto dentro de la vuelta, y empalma consigo mismo.
    lowpass_lfo(pad, sr, base_hz=1500.0, depth=0.42, lfo_hz=1.0 / 36.0, q=1.2,
                wrap=True)

    mix = [p + l + b + a for p, l, b, a in zip(pad, low, bell, air)]
    assert_sane(mix, "music_cosmic_loop")
    highpass(mix, sr, 90.0, poles=2, wrap=True)
    saturate(mix, drive=1.6)
    return sr, reverb(mix, sr, room=0.87, damp=0.20, wet=0.34, wrap=True)


# ---------------------------------------------------------------------------
# Pipeline
# ---------------------------------------------------------------------------

SFX = {
    "sfx_tap": sfx_tap,
    "sfx_coin": sfx_coin,
    "sfx_merge": sfx_merge,
    "sfx_evolution": sfx_evolution,
    "sfx_buy": sfx_buy,
    "sfx_error": sfx_error,
    "sfx_rare": sfx_rare,
    "sfx_prestige": sfx_prestige,
    "sfx_event": sfx_event,
    "sfx_daily": sfx_daily,
}
MUSIC = {
    "music_earth_loop": music_earth_loop,
    "music_cosmic_loop": music_cosmic_loop,
}

# Los SFX cortos no pueden pasarse de 400 ms; las dos celebraciones sí.
SFX_MAX_SECONDS = {"sfx_evolution": 0.60, "sfx_prestige": 1.00}
SFX_DEFAULT_MAX = 0.40


def afconvert(wav_path, out_path):
    subprocess.run(
        ["/usr/bin/afconvert", wav_path, out_path, "-d", "LEI16", "-f", "caff"],
        check=True,
    )


def main():
    convert = "--no-convert" not in sys.argv
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    os.makedirs(BUILD, exist_ok=True)
    if convert:
        os.makedirs(DEST, exist_ok=True)

    results = {}
    print(f"{'archivo':<22}{'sr':>7}{'dur':>9}{'pico':>9}{'RMS':>9}{'centroide':>11}")
    for name, fn, peak_db in (
        [(n, f, SFX_PEAK_DB) for n, f in SFX.items()]
        + [(n, f, MUSIC_PEAK_DB) for n, f in MUSIC.items()]
    ):
        if only and name not in only:
            continue
        sr, buf = fn()
        is_sfx = name.startswith("sfx_")
        if is_sfx:
            edge_fades(buf, sr)
        buf = normalize(buf, peak_db)
        peak, rms = measure(buf)
        cen = centroid(buf, sr)
        results[name] = (sr, buf, cen)

        assert peak <= peak_db + 0.01, f"{name}: clipping ({peak:.2f} dBFS)"
        assert rms > RMS_FLOOR_DB, f"{name}: archivo casi mudo ({rms:.1f} dBFS)"
        dur = len(buf) / sr
        if is_sfx:
            cap = SFX_MAX_SECONDS.get(name, SFX_DEFAULT_MAX)
            assert dur <= cap + 1e-6, f"{name}: dura {dur:.3f}s, tope {cap:.2f}s"
        else:
            # Los dos defectos de loop, que son distintos: el click (salto fuera
            # de la distribución de sus vecinos) y el hueco (el track se apaga
            # antes de volver a empezar).
            ratio = seam_ratio(buf)
            head, tail = edge_life(buf, sr)
            nbytes = CAF_HEADER_BYTES + 2 * len(buf)
            print(f"    loop: costura {ratio:.2f}× el salto vecino · bordes "
                  f"{head:.2f}× / {tail:.2f}× · {nbytes} B "
                  f"(tope {MAX_BYTES[name]})")
            assert ratio < 4.0, (
                f"{name}: click en el punto de loop ({ratio:.2f}× el salto "
                f"típico entre muestras vecinas)")
            assert head > 0.35 and tail > 0.35, (
                f"{name}: el loop se apaga en los bordes ({head:.2f}× / "
                f"{tail:.2f}× del nivel medio) — cada vuelta se oye el bache")
            assert nbytes <= MAX_BYTES[name], (
                f"{name}: {nbytes} bytes > tope {MAX_BYTES[name]}")

        wav_path = os.path.join(BUILD, f"{name}.wav")
        write_wav(wav_path, buf, sr)
        if convert:
            afconvert(wav_path, os.path.join(DEST, f"{name}.caf"))
        print(f"{name:<22}{sr:>7}{dur:>8.3f}s{peak:>8.2f}dB{rms:>8.2f}dB"
              f"{cen:>10.0f}Hz")

    # --- Chequeos que cruzan archivos --------------------------------------
    if "sfx_merge" in results and "sfx_evolution" in results:
        cm = results["sfx_merge"][2]
        ce = results["sfx_evolution"][2]
        ratio = ce / cm if cm else 0.0
        print(f"\nmerge vs evolution: centroides {cm:.0f} Hz y {ce:.0f} Hz"
              f" (razón {ratio:.2f}×)")
        assert ratio >= 1.6, (
            "merge y evolution suenan uno atrás del otro y hay que poder "
            f"distinguirlos: centroides {cm:.0f} y {ce:.0f} Hz")

    if "sfx_error" in results:
        sr, buf, _ = results["sfx_error"]
        sub = band_share(buf, sr, 0.0, 200.0)
        print(f"sfx_error bajo 200 Hz: {100 * sub:.1f}% "
              f"(antes 69,5%; el parlante del teléfono no llega ahí)")
        assert sub < 0.25, f"sfx_error se va al subgrave otra vez ({sub:.2f})"

    # La música tiene que tener cuerpo DONDE EL TELÉFONO SUENA. Un iPhone no
    # mueve nada por debajo de ~200 Hz, así que un loop con toda la energía
    # ahí abajo se escucha como si estuviera en silencio.
    for name, floor_hz in (("music_earth_loop", 400.0), ("music_cosmic_loop", 330.0)):
        if name not in results:
            continue
        sr, buf, cen = results[name]
        mid = band_share(buf, sr, 500.0, 4000.0)
        sub = band_share(buf, sr, 0.0, 200.0)
        print(f"{name}: centroide {cen:.0f} Hz · entre 500 Hz y 4 kHz "
              f"{100 * mid:.1f}% · bajo 200 Hz {100 * sub:.1f}%")
        assert cen > floor_hz, (
            f"{name}: centroide {cen:.0f} Hz, se hunde en el grave "
            f"(mínimo {floor_hz:.0f} Hz)")
        assert mid > 0.15, f"{name}: sólo {mid:.2f} de energía entre 500 Hz y 4 kHz"

    if convert:
        print(f"\nfinales (.caf) en {DEST}")


if __name__ == "__main__":
    main()
