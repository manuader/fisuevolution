#!/usr/bin/env python3
"""FisuEvolution — sintetizador de audio del juego (100% código, 0 samples).

Genera todos los SFX y loops de música por síntesis aditiva/wavetable usando
SOLO la stdlib de Python (wave, math, struct, random con seed fija →
determinístico: dos corridas producen bytes idénticos).

Familia sonora: chiptune/arcade moderno — ondas cuadradas band-limited (sin
aliasing, redondeadas), triangulares y senos, con envolventes suaves. Nada
estridente.

Salida:
  - WAV intermedios en  Tools/audio-synth/build/   (44100 Hz, 16-bit, mono)
  - Finales via afconvert en FisuEvolution/Resources/Audio/
      * SFX    → .caf LEI16
      * música del arranque (`music_earth_loop`) → .caf LEI16 (NO m4a: AAC
        agrega padding de encoder que rompe el loop; AudioManager prueba caf
        antes que m4a, así que caf gana).
      * temas por piso (`music_<piso>_loop`, 2.0) → .caf **AAC a 80 kbps**.
        Diez loops en PCM pesarían ~22 MB; en AAC, 2,4. El padding del
        encoder ya no rompe el loop porque el CAF guarda la tabla de paquetes
        (priming + remainder) y `AudioManager` decodifica el tema entero a PCM
        en memoria antes de loopearlo: el largo decodificado es exacto. Cada
        corrida lo verifica decodificando el .caf de vuelta (ver
        `check_aac_loop`).

Loops perfectos: todos los music_* se renderizan con "wrap-around" — todo
evento cuya cola pasa el final del buffer se suma al principio (módulo N).
El largo cae exacto en frontera de compás (96 BPM → 8 compases = 882000
samples = 20.000 s) y la señal es continua en el punto de loop por
construcción.

Normalización: SFX pico a -3 dBFS, música del arranque pico a -9 dBFS. Los
temas por piso se igualan por RMS (-20 dBFS) con techo de pico en -9 dBFS:
el crossfade pasa de uno a otro y un tema no puede sonar el doble de fuerte
que el anterior. El techo es el de la v1, el margen que dejan los SFX. Se
verifica que no haya clipping y que el RMS supere el piso de silencio
(-60 dBFS).

Uso:
  python3 Tools/audio-synth/generate_audio.py                  # todo
  python3 Tools/audio-synth/generate_audio.py music_moon_loop  # sólo ése
  python3 Tools/audio-synth/generate_audio.py --no-convert     # sólo WAV
"""

import math
import os
import random
import struct
import subprocess
import sys
import wave

SR = 44100
HERE = os.path.dirname(os.path.abspath(__file__))
BUILD = os.path.join(HERE, "build")
DEST = os.path.normpath(
    os.path.join(HERE, "..", "..", "FisuEvolution", "Resources", "Audio")
)

SFX_PEAK_DB = -3.0
MUSIC_PEAK_DB = -9.0
RMS_FLOOR_DB = -60.0

TWO_PI = 2.0 * math.pi
TABLE_SIZE = 4096
PULSE_DUTY = {"pulse25": 0.25}

# ---------------------------------------------------------------------------
# Wavetables (síntesis aditiva band-limited, cacheadas por armónico máximo)
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
        elif kind in PULSE_DUTY:
            # El pulso angosto es el timbre "NES": nasal, más fino que la
            # cuadrada. Serie de Fourier del pulso centrado, sin la continua.
            duty = PULSE_DUTY[kind]
            for n in range(1, max_harm + 1):
                v += (math.sin(math.pi * n * duty) / n
                      * math.cos(TWO_PI * n * (x - duty / 2.0)))
        tab.append(v)
    peak = max(abs(s) for s in tab) or 1.0
    return [s / peak for s in tab]


def table_for(kind, freq):
    """Tabla del timbre pedido con armónicos limitados bajo ~18 kHz."""
    if kind == "sine":
        max_harm = 1
    elif kind in PULSE_DUTY:
        # El pulso usa todos los armónicos, no sólo los impares.
        max_harm = max(1, min(24, int(18000.0 / max(freq, 1.0))))
    else:
        max_harm = max(1, min(15, int(18000.0 / max(freq, 1.0))))
        if max_harm % 2 == 0:
            max_harm -= 1
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

def render_tone(buf, start_s, dur_s, freq, kind="sine", amp=1.0, env=None,
                vib_hz=0.0, vib_depth=0.0, detune_cents=0.0, wrap=False,
                phase=0.0):
    """Suma un tono al buffer. `freq` es Hz fijo o callable(t)->Hz.

    Con wrap=True los samples que pasan el final del buffer se suman al
    principio (módulo N) → loop perfecto por construcción.
    """
    n = len(buf)
    f0 = freq(0.0) if callable(freq) else freq
    table = table_for(kind, f0 * (2 ** (vib_depth + abs(detune_cents) / 1200.0)))
    ts = len(table)
    start = int(round(start_s * SR))
    count = int(round(dur_s * SR))
    det = 2.0 ** (detune_cents / 1200.0)
    ph = phase * ts
    inv_sr = 1.0 / SR
    step_k = ts * inv_sr
    fixed = not callable(freq)
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
        s1 = table[(i0 + 1) % ts]
        g = env(t) if env else 1.0
        j = start + i
        if wrap:
            j %= n
        elif j >= n:
            break
        buf[j] += (s0 + (s1 - s0) * frac) * amp * g


def render_noise(buf, start_s, dur_s, amp, decay, rng, env=None, wrap=False):
    """Ruido blanco filtrado (high-pass por primera diferencia) con decay."""
    n = len(buf)
    start = int(round(start_s * SR))
    count = int(round(dur_s * SR))
    rel = min(0.005, dur_s * 0.2)
    inv_sr = 1.0 / SR
    prev = 0.0
    for i in range(count):
        t = i * inv_sr
        w = rng.uniform(-1.0, 1.0)
        v = (w - prev) * 0.5
        prev = w
        g = env(t) if env else math.exp(-t / decay)
        if env is None and t > dur_s - rel:
            g *= max(0.0, (dur_s - t) / rel)
        j = start + i
        if wrap:
            j %= n
        elif j >= n:
            break
        buf[j] += v * amp * g


def render_noise_lp(buf, start_s, dur_s, amp, rng, alpha, env, wrap=False):
    """Ruido blanco por un pasabajos de un polo: viento, escobillas, estática.

    `alpha` chico oscurece (0.02 ≈ viento grave, 0.3 ≈ siseo). La envolvente
    es obligatoria y tiene que terminar en 0: el ruido filtrado no decae solo.
    """
    n = len(buf)
    start = int(round(start_s * SR))
    count = int(round(dur_s * SR))
    inv_sr = 1.0 / SR
    y = 0.0
    for i in range(count):
        y += alpha * (rng.uniform(-1.0, 1.0) - y)
        j = start + i
        if wrap:
            j %= n
        elif j >= n:
            break
        buf[j] += y * amp * env(i * inv_sr)


# ---------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------

def midi_hz(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def glide(f0, f1, dur):
    """Barrido exponencial de f0 a f1 en dur segundos."""
    ratio = f1 / f0
    return lambda t: f0 * ratio ** (min(t, dur) / dur)


def edge_fades(buf, fade_in=0.002, fade_out=0.008):
    n_in = int(fade_in * SR)
    n_out = int(fade_out * SR)
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


def write_wav(path, buf):
    frames = bytearray()
    for x in buf:
        x = max(-1.0, min(1.0, x))
        frames += struct.pack("<h", int(round(x * 32767.0)))
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(frames))


def measure(buf):
    peak = max(abs(x) for x in buf)
    rms = math.sqrt(sum(x * x for x in buf) / len(buf))
    to_db = lambda v: (20.0 * math.log10(v)) if v > 0 else float("-inf")
    return to_db(peak), to_db(rms)


def normalize_loudness(buf, rms_db, peak_ceiling_db):
    """Lleva el RMS a `rms_db` salvo que el pico pase el techo: ahí manda el
    techo y el tema queda un poco más bajo (los ralos, como la Luna)."""
    peak = max(abs(x) for x in buf)
    rms = math.sqrt(sum(x * x for x in buf) / len(buf))
    if peak == 0.0:
        raise RuntimeError("buffer en silencio total")
    scale = min(10.0 ** (rms_db / 20.0) / rms,
                10.0 ** (peak_ceiling_db / 20.0) / peak)
    return [x * scale for x in buf]


def read_wav(path):
    with wave.open(path, "rb") as w:
        count = w.getnframes()
        raw = w.readframes(count)
    return [s / 32768.0 for s in struct.unpack(f"<{count}h", raw)]


# ---------------------------------------------------------------------------
# SFX
# ---------------------------------------------------------------------------

def sfx_tap():
    """Pop suave ~60 ms: seno 880→660 Hz con decay rápido."""
    dur = 0.060
    buf = [0.0] * int(dur * SR)
    render_tone(buf, 0.0, dur, glide(880.0, 660.0, dur), "sine", 1.0,
                env_perc(dur, attack=0.002, curve=7.0))
    return buf


def sfx_coin():
    """Ding clásico ~180 ms: cuadrada B5 (988) → E6 (1319), dos notas."""
    dur = 0.180
    buf = [0.0] * int(dur * SR)
    render_tone(buf, 0.0, 0.055, 988.0, "square", 0.9,
                env_sustain(0.055, a=0.003, r=0.008))
    render_tone(buf, 0.055, dur - 0.055, 1319.0, "square", 1.0,
                env_perc(dur - 0.055, attack=0.003, curve=4.0))
    return buf


def sfx_merge():
    """Chirp ascendente de 2 notas ~150 ms, más gordo que el tap."""
    dur = 0.150
    buf = [0.0] * int(dur * SR)
    # Nota 1: C5 con chirpcito hacia arriba, cuadrada + sub seno una octava abajo.
    e1 = env_perc(0.075, attack=0.004, curve=5.0)
    render_tone(buf, 0.0, 0.075, glide(523.25, 554.0, 0.075), "square", 0.8, e1)
    render_tone(buf, 0.0, 0.075, glide(261.6, 277.0, 0.075), "sine", 0.5, e1)
    # Nota 2: G5, doble oscilador detuneado (gordura) + sub.
    e2 = env_perc(dur - 0.065, attack=0.004, curve=4.5)
    render_tone(buf, 0.065, dur - 0.065, glide(784.0, 830.0, 0.085), "square",
                0.6, e2, detune_cents=-7.0)
    render_tone(buf, 0.065, dur - 0.065, glide(784.0, 830.0, 0.085), "square",
                0.6, e2, detune_cents=7.0)
    render_tone(buf, 0.065, dur - 0.065, glide(392.0, 415.0, 0.085), "sine",
                0.45, e2)
    return buf


def sfx_evolution():
    """Arpegio ascendente brillante ~500 ms + shimmer final."""
    dur = 0.500
    buf = [0.0] * int(dur * SR)
    arp = [(0.00, 523.25), (0.08, 659.26), (0.16, 783.99), (0.24, 1046.5)]
    for t0, f in arp:
        render_tone(buf, t0, 0.10, f, "square", 0.85,
                    env_perc(0.10, attack=0.004, curve=4.0))
        render_tone(buf, t0, 0.10, f * 0.5, "sine", 0.35,
                    env_perc(0.10, attack=0.004, curve=4.0))
    # Shimmer: díada C6+E6 detuneada con trémolo de 12 Hz que decae.
    sh_dur = dur - 0.32
    e = env_perc(sh_dur, attack=0.006, curve=3.0)
    for f in (1046.5, 1318.5):
        for det in (-6.0, 6.0):
            render_tone(buf, 0.32, sh_dur, f, "triangle", 0.45, e,
                        vib_hz=12.0, vib_depth=0.006, detune_cents=det)
    return buf


def sfx_buy():
    """Doble click suave ~120 ms."""
    dur = 0.120
    buf = [0.0] * int(dur * SR)
    render_tone(buf, 0.0, 0.040, 660.0, "sine", 0.9,
                env_perc(0.040, attack=0.002, curve=6.0))
    render_tone(buf, 0.0, 0.025, 1320.0, "triangle", 0.25,
                env_perc(0.025, attack=0.001, curve=8.0))
    render_tone(buf, 0.060, dur - 0.060, 880.0, "sine", 1.0,
                env_perc(dur - 0.060, attack=0.002, curve=5.0))
    render_tone(buf, 0.060, 0.030, 1760.0, "triangle", 0.25,
                env_perc(0.030, attack=0.001, curve=8.0))
    return buf


def sfx_error():
    """Buzz grave ~200 ms: cuadradas 110 Hz + roce detuneado, cae de tono."""
    dur = 0.200
    buf = [0.0] * int(dur * SR)
    e = env_perc(dur, attack=0.005, curve=3.0)
    render_tone(buf, 0.0, dur, glide(110.0, 98.0, dur), "square", 0.8, e)
    render_tone(buf, 0.0, dur, glide(116.5, 103.8, dur), "square", 0.5, e)
    return buf


def sfx_rare():
    """Sparkle ~400 ms: 3 notas agudas rápidas + eco."""
    dur = 0.400
    buf = [0.0] * int(dur * SR)
    notes = [(0.00, 1318.5), (0.05, 1568.0), (0.10, 1975.5)]  # E6 G6 B6
    for gain, offset in ((1.0, 0.0), (0.42, 0.18)):  # golpe + eco
        for t0, f in notes:
            e = env_perc(0.09, attack=0.003, curve=4.5)
            render_tone(buf, t0 + offset, 0.09, f, "triangle", 0.7 * gain, e)
            render_tone(buf, t0 + offset, 0.09, f, "sine", 0.5 * gain, e)
    return buf


def sfx_prestige():
    """Riser épico ~900 ms: barrido ascendente + acorde mayor final."""
    dur = 0.900
    buf = [0.0] * int(dur * SR)
    rise = 0.55
    # Barrido C4→C6 con ruido que sube detrás.
    render_tone(buf, 0.0, rise, glide(261.6, 1046.5, rise), "square", 0.55,
                lambda t: (t / rise) ** 1.5 * (1.0 if t < rise - 0.01
                                               else max(0.0, (rise - t) / 0.01)),
                vib_hz=9.0, vib_depth=0.004)
    rng = random.Random(404)
    render_noise(buf, 0.0, rise, 0.35, 1.0, rng,
                 env=lambda t: (t / rise) ** 2
                 * (1.0 if t < rise - 0.01 else max(0.0, (rise - t) / 0.01)))
    # Acorde final: C mayor (C5 E5 G5 C6) con pares detuneados, decae al final.
    chord_dur = dur - rise
    e = env_perc(chord_dur, attack=0.008, curve=3.2)
    for f in (523.25, 659.26, 783.99, 1046.5):
        for det in (-5.0, 5.0):
            render_tone(buf, rise, chord_dur, f, "square", 0.28, e,
                        detune_cents=det)
        render_tone(buf, rise, chord_dur, f * 0.5, "sine", 0.18, e)
    return buf


def sfx_event():
    """Notificación de 2 tonos ~250 ms, quinta abierta (neutra)."""
    dur = 0.250
    buf = [0.0] * int(dur * SR)
    render_tone(buf, 0.0, 0.110, 523.25, "triangle", 0.9,
                env_sustain(0.110, a=0.008, r=0.025))
    render_tone(buf, 0.120, dur - 0.120, 783.99, "triangle", 1.0,
                env_perc(dur - 0.120, attack=0.008, curve=3.5))
    return buf


def sfx_daily():
    """Triada mayor alegre ~300 ms (C5-E5-G5 en strum rápido)."""
    dur = 0.300
    buf = [0.0] * int(dur * SR)
    for i, f in enumerate((523.25, 659.26, 783.99)):
        t0 = i * 0.045
        ring = dur - t0
        e = env_perc(ring, attack=0.004, curve=3.5)
        render_tone(buf, t0, ring, f, "square", 0.55, e)
        render_tone(buf, t0, ring, f, "sine", 0.4, e)
    return buf


def sfx_wheel_tick():
    """Tic de la ruleta ~35 ms: la lengüeta de plástico contra un clavo.
    Seco y corto a propósito, porque suena decenas de veces por giro."""
    dur = 0.035
    buf = [0.0] * int(dur * SR)
    render_tone(buf, 0.0, dur, glide(2400.0, 1800.0, dur), "triangle", 0.7,
                env_perc(dur, attack=0.0008, curve=9.0))
    render_tone(buf, 0.0, 0.020, 1100.0, "square", 0.3,
                env_perc(0.020, attack=0.0008, curve=7.0))
    render_noise(buf, 0.0, 0.006, 0.6, 0.0015, random.Random(77))
    return buf


def sfx_blackout():
    """Apagón ~1,2 s: salta la térmica (golpe grave) y todo lo eléctrico se
    apaga bajando de tono —el zumbido de la línea y el pito de los aparatos—,
    con un par de chispazos al principio."""
    dur = 1.200
    buf = [0.0] * int(dur * SR)
    # El golpe de la térmica.
    render_tone(buf, 0.0, 0.30, glide(140.0, 45.0, 0.12), "sine", 1.0,
                env_perc(0.30, attack=0.002, curve=5.0))
    rng = random.Random(1310)
    render_noise(buf, 0.0, 0.012, 0.8, 0.004, rng)
    # El zumbido de 120 Hz que se cae a 35 Hz mientras se apaga.
    hum = dur - 0.02
    hum_env = env_perc(hum, attack=0.01, curve=3.5)
    render_tone(buf, 0.02, hum, glide(120.0, 35.0, hum), "square", 0.32, hum_env)
    render_tone(buf, 0.02, hum, glide(60.0, 18.0, hum), "sine", 0.35, hum_env)
    # El pito de la electrónica, que baja más rápido.
    render_tone(buf, 0.02, 0.65, glide(1500.0, 160.0, 0.65), "triangle", 0.22,
                env_perc(0.65, attack=0.004, curve=3.0))
    # Chispazos sueltos.
    for t0, amp in ((0.07, 0.45), (0.16, 0.3), (0.31, 0.2)):
        render_noise(buf, t0, 0.018, amp, 0.005, rng)
    return buf


def sfx_elevator_ding():
    """Ding del ascensor ~1,4 s: una campana clara (Do6) con parciales de
    campana y una octava abajo que la abriga. Un solo golpe: llegó."""
    dur = 1.400
    buf = [0.0] * int(dur * SR)
    f = 1046.5
    for ratio, amp, curve in ((1.0, 1.0, 3.2), (2.0, 0.42, 4.5),
                              (3.0, 0.18, 6.0), (4.2, 0.10, 8.0),
                              (0.5, 0.28, 3.0)):
        render_tone(buf, 0.0, dur, f * ratio, "sine", amp,
                    env_perc(dur, attack=0.002, curve=curve))
    render_noise(buf, 0.0, 0.004, 0.25, 0.0012, random.Random(1046))
    return buf


def sfx_elevator_spring():
    """Resorte de la placa ~0,45 s: un "boing" metálico que baja de tono, con
    vibrato que se apaga y un roce de ruido filtrado al arrancar."""
    dur = 0.450
    buf = [0.0] * int(dur * SR)
    render_tone(buf, 0.0, dur, glide(420.0, 260.0, dur), "triangle", 0.9,
                env_perc(dur, attack=0.003, curve=4.0),
                vib_hz=8.0, vib_depth=0.05)
    render_tone(buf, 0.0, dur, glide(840.0, 520.0, dur), "sine", 0.18,
                env_perc(dur, attack=0.003, curve=6.0),
                vib_hz=8.0, vib_depth=0.05)
    render_noise_lp(buf, 0.0, 0.080, 0.35, random.Random(420), 0.25,
                    env_perc(0.080, attack=0.002, curve=4.0))
    return buf


def sfx_elevator_click():
    """Clic de botón de metal ~0,08 s: un chasquido de 6 ms y un tono corto
    de 2,2 kHz que lo cierra."""
    dur = 0.080
    buf = [0.0] * int(dur * SR)
    render_noise(buf, 0.0, 0.006, 0.9, 0.0015, random.Random(2200))
    render_tone(buf, 0.0, 0.030, 2200.0, "sine", 0.5,
                env_perc(0.030, attack=0.0005, curve=6.0))
    return buf


def sfx_elevator_doors():
    """Puertas ~0,6 s: corren con un roce que crece y chocan con un golpe
    grave al final."""
    dur = 0.600
    buf = [0.0] * int(dur * SR)
    rng = random.Random(900)
    render_noise_lp(buf, 0.0, 0.45, 0.55, rng, 0.12, env_swell(0.45, 0.40, 0.05))
    render_tone(buf, 0.48, 0.12, 90.0, "sine", 1.0,
                env_perc(0.12, attack=0.002, curve=5.0))
    render_noise(buf, 0.48, 0.030, 0.7, 0.008, rng)
    return buf


def sfx_elevator_motor():
    """Motor ~1,8 s: zumbido de 55 y 110 Hz con el roce grave de los cables
    que tiembla a 3 Hz."""
    dur = 1.800
    buf = [0.0] * int(dur * SR)
    env = env_sustain(dur, a=0.15, r=0.25)
    render_tone(buf, 0.0, dur, 55.0, "sine", 0.9, env)
    render_tone(buf, 0.0, dur, 110.0, "triangle", 0.45, env)
    shiver = env_sustain(dur, a=0.15, r=0.25)
    render_noise_lp(buf, 0.0, dur, 0.5, random.Random(55), 0.04,
                    lambda t: shiver(t) * (0.65 + 0.35 * math.sin(2 * math.pi * 3.0 * t)))
    return buf


def loop_seamless(buf, xfade):
    """Cierra un buffer de N+xfade muestras en un loop de N sin costura: los
    primeros `xfade` muestras se mezclan con la cola que sobra, así el final
    empalma con el principio sin salto (el ruido filtrado no cierra solo)."""
    n = len(buf) - xfade
    out = buf[:n]
    for i in range(xfade):
        w = i / xfade
        out[i] = buf[i] * w + buf[n + i] * (1.0 - w)
    return out


def sfx_package_rattle():
    """Paquete sacudido, ambiente en loop de 2 s: golpecitos secos de cartón
    y algo suelto que rebota adentro, repartidos sin patrón."""
    n, x = 2 * SR, int(0.25 * SR)
    buf = [0.0] * (n + x)
    rng = random.Random(7001)
    for t0, amp in ((0.05, 0.9), (0.21, 0.5), (0.52, 0.8), (0.64, 0.4),
                    (0.98, 0.9), (1.12, 0.55), (1.43, 0.7), (1.58, 0.35),
                    (1.81, 0.8)):
        render_noise_lp(buf, t0, 0.045, amp, rng, 0.35,
                        env_perc(0.045, attack=0.001, curve=5.0))
        render_tone(buf, t0, 0.06, 170.0 + 40.0 * rng.random(), "triangle",
                    amp * 0.5, env_perc(0.06, attack=0.001, curve=6.0))
    # Golpes secos y mucho silencio: sin comprimir, el pico manda y el
    # ambiente queda 7 dB abajo de lo pedido.
    peak = max(abs(v) for v in buf)
    buf = [math.tanh(4.0 * v / peak) for v in buf]
    return loop_seamless(buf, x)


def sfx_package_tape_rip():
    """Cinta que se arranca ~0,5 s: un raspado largo que sube de tono, con
    el temblor de los dientes de la cinta."""
    dur = 0.500
    buf = [0.0] * int(dur * SR)
    rng = random.Random(7002)
    swell = env_swell(dur, 0.06, 0.12)
    render_noise_lp(buf, 0.0, dur, 0.9, rng, 0.45,
                    lambda t: swell(t) * (0.55 + 0.45 * math.sin(TWO_PI * 52.0 * t)))
    render_noise(buf, 0.0, dur, 0.5, 0.2, rng,
                 env=lambda t: swell(t) * (0.3 + 0.7 * t / dur))
    return buf


def sfx_package_burst():
    """El paquete revienta ~0,45 s: un pop de cartón, el golpe grave de lo
    que sale y una chispa aguda que se apaga."""
    dur = 0.450
    buf = [0.0] * int(dur * SR)
    rng = random.Random(7003)
    render_noise(buf, 0.0, 0.040, 1.0, 0.010, rng)
    render_noise_lp(buf, 0.0, 0.12, 0.8, rng, 0.3, env_perc(0.12, attack=0.001, curve=5.0))
    render_tone(buf, 0.0, 0.22, glide(220.0, 70.0, 0.22), "sine", 1.0,
                env_perc(0.22, attack=0.002, curve=4.0))
    for i, f in enumerate((1568.0, 2093.0, 2637.0)):
        render_tone(buf, 0.04 + 0.03 * i, 0.30 - 0.03 * i, f, "sine", 0.22,
                    env_perc(0.30 - 0.03 * i, attack=0.002, curve=6.0))
    peak = max(abs(v) for v in buf)
    return [math.tanh(2.0 * v / peak) for v in buf]


def sfx_mattress_squeak():
    """Colchón que cruje, ambiente en loop de 2 s: dos chirridos de resorte
    que suben y bajan, y un roce de tela entre uno y otro."""
    n, x = 2 * SR, int(0.25 * SR)
    buf = [0.0] * (n + x)
    rng = random.Random(7004)
    for t0, f0, f1, amp in ((0.10, 620.0, 880.0, 0.8), (0.62, 760.0, 540.0, 0.6),
                            (1.12, 540.0, 820.0, 0.8), (1.58, 840.0, 600.0, 0.5)):
        d = 0.26
        render_tone(buf, t0, d, glide(f0, f1, d), "triangle", amp,
                    env_swell(d, 0.05, 0.12), vib_hz=14.0, vib_depth=0.03)
        render_tone(buf, t0, d, glide(f0 * 2, f1 * 2, d), "sine", amp * 0.18,
                    env_swell(d, 0.05, 0.12), vib_hz=14.0, vib_depth=0.03)
        render_noise_lp(buf, t0 + 0.3, 0.2, 0.25, rng, 0.08, env_swell(0.2, 0.08, 0.1))
    return loop_seamless(buf, x)


def sfx_mattress_rip():
    """Tela que se abre ~0,55 s: un desgarro más grave y áspero que el de la
    cinta, en tirones, y un golpe sordo de relleno al final."""
    dur = 0.550
    buf = [0.0] * int(dur * SR)
    rng = random.Random(7005)
    swell = env_swell(0.45, 0.04, 0.10)
    render_noise_lp(buf, 0.0, 0.45, 1.0, rng, 0.18,
                    lambda t: swell(t) * (0.5 + 0.5 * abs(math.sin(TWO_PI * 17.0 * t))))
    render_noise(buf, 0.0, 0.45, 0.3, 0.2, rng, env=lambda t: swell(t) * 0.6)
    render_tone(buf, 0.44, 0.10, 80.0, "sine", 0.9, env_perc(0.10, attack=0.002, curve=5.0))
    return buf


def sfx_cash_burst():
    """Lluvia de monedas ~0,7 s: un chasquido de billetes y veinte monedas
    que repican en tonos distintos, cada vez más ralas."""
    dur = 0.700
    buf = [0.0] * int(dur * SR)
    rng = random.Random(7006)
    render_noise(buf, 0.0, 0.050, 0.8, 0.012, rng)
    for i in range(20):
        t0 = 0.02 + 0.6 * (i / 20.0) ** 1.4
        f = rng.choice((1976.0, 2349.0, 2637.0, 3136.0))
        amp = 0.35 * (1.0 - i / 28.0)
        render_tone(buf, t0, 0.09, f, "sine", amp, env_perc(0.09, attack=0.001, curve=7.0))
        render_tone(buf, t0, 0.09, f * 1.5, "sine", amp * 0.4,
                    env_perc(0.09, attack=0.001, curve=9.0))
    return buf


def sfx_visitor_arrive():
    """Llegó alguien ~0,6 s: un timbre de dos notas (Mi6, Do6) de campanita."""
    dur = 0.600
    buf = [0.0] * int(dur * SR)
    for t0, f in ((0.0, 1318.5), (0.20, 1046.5)):
        d = dur - t0
        for ratio, amp, curve in ((1.0, 1.0, 4.0), (2.0, 0.3, 6.0), (2.76, 0.14, 9.0)):
            render_tone(buf, t0, d, f * ratio, "sine", amp,
                        env_perc(d, attack=0.002, curve=curve))
    return buf


def sfx_talk_blip():
    """Blip de voz ~0,07 s: un pulso redondo y corto. El tono por personaje
    lo pone `AudioManager.talkPitch`, no el archivo."""
    dur = 0.070
    buf = [0.0] * int(dur * SR)
    render_tone(buf, 0.0, dur, glide(520.0, 480.0, dur), "pulse25", 0.8,
                env_sustain(dur, a=0.004, r=0.03))
    render_tone(buf, 0.0, dur, glide(1040.0, 960.0, dur), "sine", 0.15,
                env_sustain(dur, a=0.004, r=0.03))
    return buf


def sfx_shop_shimmer():
    """Brillo de la tienda ~0,9 s: un arpegio de campanitas que sube
    (Sol5 a Re7), cada una con su cola."""
    dur = 0.900
    buf = [0.0] * int(dur * SR)
    for i, m in enumerate((79, 83, 86, 91, 95, 98)):
        t0 = 0.07 * i
        d = dur - t0
        f = midi_hz(m)
        render_tone(buf, t0, d, f, "sine", 0.7, env_perc(d, attack=0.002, curve=5.0))
        render_tone(buf, t0, d, f * 2.76, "sine", 0.12, env_perc(d, attack=0.002, curve=9.0))
    return buf


def sfx_reveal_whoosh():
    """Revelación ~0,7 s: un soplido que sube y se abre, con un tono que
    barre de grave a agudo por debajo."""
    dur = 0.700
    buf = [0.0] * int(dur * SR)
    rng = random.Random(7010)
    swell = env_swell(dur, 0.45, 0.22)
    render_noise_lp(buf, 0.0, dur, 0.8, rng, 0.06, swell)
    render_noise_lp(buf, 0.0, dur, 0.6, rng, 0.30,
                    lambda t: swell(t) * (t / dur) ** 2)
    render_tone(buf, 0.0, dur, glide(180.0, 900.0, dur), "sine", 0.35, swell)
    return buf


def sfx_merge_all_done():
    """Remate de Fusionar todo ~600 ms: acorde mayor que sube (C5-E5-G5-C6) y brillo."""
    dur = 0.600
    buf = [0.0] * int(dur * SR)
    for i, f in enumerate([523.25, 659.26, 783.99, 1046.5]):
        t0 = 0.06 * i
        render_tone(buf, t0, dur - t0, f, "square", 0.45,
                    env_perc(dur - t0, attack=0.004, curve=3.5),
                    detune_cents=(-6.0 if i % 2 else 6.0))
    render_tone(buf, 0.24, dur - 0.24, glide(2093.0, 2637.0, dur - 0.24), "sine", 0.25,
                env_perc(dur - 0.24, attack=0.01, curve=3.0))
    return buf


def sfx_elevator_cable():
    """Cable del ascensor ~1,2 s: el roce metálico de la roldana, que tirita
    a 14 Hz sobre un quejido grave de cable tenso."""
    dur = 1.200
    buf = [0.0] * int(dur * SR)
    rng = random.Random(7011)
    env = env_sustain(dur, a=0.2, r=0.3)
    render_tone(buf, 0.0, dur, glide(150.0, 190.0, dur), "triangle", 0.6, env,
                vib_hz=6.0, vib_depth=0.02)
    render_noise_lp(buf, 0.0, dur, 0.7, rng, 0.2,
                    lambda t: env(t) * (0.45 + 0.55 * abs(math.sin(TWO_PI * 7.0 * t))))
    return buf


# ---------------------------------------------------------------------------
# Música — loops perfectos (render con wrap-around)
# ---------------------------------------------------------------------------

# Earth: 96 BPM, 8 compases 4/4 → 882000 samples = 20.000 s exactos.
EARTH_BPM = 96
EARTH_BARS = 8

# Melodía en corcheas ('-' liga con la nota anterior). Am–F–C–G ×2.
EARTH_LEAD = [
    [69, 72, 76, '-', 81, '-', 79, 76],   # Am
    [77, '-', 72, 74, 77, 76, 74, 72],    # F
    [76, '-', 79, '-', 76, 74, 72, 74],   # C
    [71, 74, 79, '-', 74, 71, 67, '-'],   # G
    [76, '-', 72, 69, 76, '-', 81, '-'],  # Am (variación)
    [77, 81, 84, '-', 81, 79, 77, 76],    # F
    [79, '-', 76, 72, 74, 76, 79, '-'],   # C
    [74, 71, 67, '-', 71, 74, 79, '-'],   # G
]
EARTH_ROOTS = [45, 41, 48, 43, 45, 41, 48, 43]  # A2 F2 C3 G2 ×2
EARTH_BASS_PATTERN = [0, 0, 12, 0, 0, 12, 0, 12]  # corcheas, salto de octava


def music_earth_loop():
    beat = 60.0 / EARTH_BPM
    slot = beat / 2.0
    total = int(round(EARTH_BARS * 4 * beat * SR))  # 882000
    buf = [0.0] * total
    rng = random.Random(1987)

    # Lead: cuadrada con vibrato sutil.
    for bar, slots in enumerate(EARTH_LEAD):
        s = 0
        while s < 8:
            v = slots[s]
            if v == '-' or v == 0:
                s += 1
                continue
            length = 1
            while s + length < 8 and slots[s + length] == '-':
                length += 1
            t0 = (bar * 8 + s) * slot
            gate = length * slot * 0.92
            render_tone(buf, t0, gate, midi_hz(v), "square", 0.30,
                        env_sustain(gate, a=0.006, r=0.04),
                        vib_hz=5.5, vib_depth=0.004, wrap=True)
            s += length

    # Bajo: triangular en corcheas con saltos de octava.
    for bar, root in enumerate(EARTH_ROOTS):
        for s, jump in enumerate(EARTH_BASS_PATTERN):
            t0 = (bar * 8 + s) * slot
            gate = slot * 0.88
            render_tone(buf, t0, gate, midi_hz(root + jump), "triangle", 0.34,
                        env_sustain(gate, a=0.004, r=0.03), wrap=True)

    # Hi-hats: ruido blanco filtrado en corcheas, acento en contratiempo,
    # hat abierto en la última corchea del compás.
    for bar in range(EARTH_BARS):
        for s in range(8):
            t0 = (bar * 8 + s) * slot
            if s == 7:
                render_noise(buf, t0, 0.14, 0.10, 0.055, rng, wrap=True)
            else:
                amp = 0.085 if s % 2 == 1 else 0.055
                render_noise(buf, t0, 0.05, amp, 0.018, rng, wrap=True)
    return buf


# ---------------------------------------------------------------------------
# Música por piso (2.0) — un tema chiptune por piso de economy.json
# ---------------------------------------------------------------------------
#
# Cada tema es un loop con wrap-around, igual que el de la Tierra. Las líneas
# se escriben en texto ('D4', 'Bb3'; '-' liga con la nota anterior, '.' es
# silencio y '|' sólo separa compases para leer) así una melodía se lee y se
# corrige sin contar números MIDI. Cada línea tiene que cubrir el loop entero:
# `play_line` lo verifica, y una nota de más o de menos no compila el tema.

NOTE_PC = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def note(name):
    """'C#4' → 61, con A4 = 69 (octava científica)."""
    pc = NOTE_PC[name[0]]
    i = 1
    while i < len(name) and name[i] in "#b":
        pc += 1 if name[i] == "#" else -1
        i += 1
    return 12 * (int(name[i:]) + 1) + pc


def chord(text):
    return [note(n) for n in text.split()]


def parse_line(text):
    steps = []
    for token in text.split():
        if token == "|":
            continue
        if token == "-":
            steps.append("-")
        elif token == ".":
            steps.append(None)
        else:
            steps.append(note(token))
    return steps


class Grid:
    """El reloj de un tema: tempo, compases, pasos por compás y swing.

    El swing atrasa los pasos impares una fracción del paso (0,33 ≈ tresillo).
    """

    def __init__(self, bpm, bars, steps_per_bar=8, swing=0.0):
        self.bar = 4.0 * 60.0 / bpm
        self.beat = 60.0 / bpm
        self.bars = bars
        self.steps_per_bar = steps_per_bar
        self.step = self.bar / steps_per_bar
        self.swing = swing
        self.samples = int(round(bars * self.bar * SR))

    def t(self, index):
        """Segundo en que cae el paso absoluto `index`."""
        swung = self.swing * self.step if index % 2 == 1 else 0.0
        return index * self.step + swung

    def at(self, bar, step):
        return self.t(bar * self.steps_per_bar + step)


def play_line(buf, grid, text, instrument, gate=0.92, vel=1.0):
    """Toca una línea entera: cada nota dura hasta la siguiente, por el gate."""
    steps = parse_line(text)
    expected = grid.bars * grid.steps_per_bar
    assert len(steps) == expected, f"la línea tiene {len(steps)} pasos y el loop {expected}"
    i = 0
    while i < len(steps):
        value = steps[i]
        if value is None or value == "-":
            i += 1
            continue
        length = 1
        while i + length < len(steps) and steps[i + length] == "-":
            length += 1
        t0 = grid.t(i)
        instrument(buf, t0, (grid.t(i + length) - t0) * gate, value, vel)
        i += length


def hits(grid, pattern):
    """Un patrón de un compás ('x' golpe, 'X' acento, '.' nada; los espacios
    no cuentan), repetido en todos los compases → [(segundo, acento)]."""
    steps = pattern.replace(" ", "")
    assert len(steps) == grid.steps_per_bar, f"patrón de {len(steps)} pasos"
    out = []
    for bar in range(grid.bars):
        for step, mark in enumerate(steps):
            if mark in "xX":
                out.append((grid.at(bar, step), mark == "X"))
    return out


def harmony(grid, spec):
    """[(acorde, tiempos)] → [(segundo, duración, notas)]. Tiene que cubrir el
    loop exacto: una armonía corta dejaría un hueco antes de la costura."""
    out = []
    t = 0.0
    for text, beats in spec:
        out.append((t, beats * grid.beat, chord(text)))
        t += beats * grid.beat
    assert abs(t - grid.bars * grid.bar) < 1e-6, "la armonía no cubre el loop"
    return out


def fifth_of(root, high=50):
    """La quinta del bajo, en el registro que se oye en un teléfono."""
    up = root + 7
    return up if up <= high else root - 5


def tremolo(env, hz, depth):
    return lambda t: env(t) * (1.0 - depth * (0.5 + 0.5 * math.sin(TWO_PI * hz * t)))


# Instrumentos: cada uno es play(buf, t0, dur, midi, vel) y suma con wrap.

def lead(kind="square", amp=0.24, vib_hz=5.5, vib_depth=0.004, attack=0.006,
         release=0.04, detune=0.0):
    """Voz cantante sostenida. Con `detune`, dos osciladores abiertos en
    cents: más gorda, como el lead de la Tierra pero a dúo."""
    voices = (-detune, detune) if detune else (0.0,)
    gain = amp / math.sqrt(len(voices))

    def play(buf, t0, dur, m, vel=1.0):
        e = env_sustain(dur, a=min(attack, dur * 0.4), r=min(release, dur * 0.4))
        for cents in voices:
            render_tone(buf, t0, dur, midi_hz(m), kind, gain * vel, e,
                        vib_hz=vib_hz, vib_depth=vib_depth, detune_cents=cents,
                        wrap=True)

    return play


def bass(kind="triangle", amp=0.34, release=0.03):
    def play(buf, t0, dur, m, vel=1.0):
        render_tone(buf, t0, dur, midi_hz(m), kind, amp * vel,
                    env_sustain(dur, a=0.004, r=min(release, dur * 0.4)),
                    wrap=True)

    return play


def pluck(kind="triangle", amp=0.2, ring=0.5, curve=4.5):
    """Nota pulsada que suena `ring` segundos sin importar el largo escrito."""
    def play(buf, t0, dur, m, vel=1.0):
        render_tone(buf, t0, ring, midi_hz(m), kind, amp * vel,
                    env_perc(ring, attack=0.003, curve=curve), wrap=True)

    return play


BELL_PARTIALS = ((1.0, 1.0, 3.0), (2.0, 0.45, 4.5), (2.76, 0.3, 6.0),
                 (5.4, 0.12, 9.0))
# El steel drum: parciales armónicos que se apagan rápido, más una octava
# apenas desafinada que le da el batido del parche.
PAN_PARTIALS = ((1.0, 1.0, 4.0), (2.0, 0.5, 5.5), (3.0, 0.2, 7.0),
                (2.006, 0.18, 5.5))


def bell(amp=0.2, ring=1.8, partials=BELL_PARTIALS):
    def play(buf, t0, dur, m, vel=1.0):
        f = midi_hz(m)
        for ratio, gain, curve in partials:
            if f * ratio < 16000.0:
                render_tone(buf, t0, ring, f * ratio, "sine", amp * gain * vel,
                            env_perc(ring, attack=0.002, curve=curve), wrap=True)

    return play


def vibes(amp=0.22, ring=1.1):
    """Vibráfono: seno con trémolo de motor y un parcial agudo que se apaga
    enseguida (el golpe de la baqueta)."""
    def play(buf, t0, dur, m, vel=1.0):
        f = midi_hz(m)
        length = max(ring, dur)
        render_tone(buf, t0, length, f, "sine", amp * vel,
                    tremolo(env_perc(length, attack=0.003, curve=2.6), 5.5, 0.35),
                    wrap=True)
        render_tone(buf, t0, 0.25, f * 4.0, "sine", amp * 0.18 * vel,
                    env_perc(0.25, attack=0.002, curve=8.0), wrap=True)

    return play


def epiano(amp=0.12):
    """Piano eléctrico: fundamental con trémolo, octava que decae rápido y el
    'tine' agudo del ataque."""
    def play(buf, t0, dur, m, vel=1.0):
        f = midi_hz(m)
        render_tone(buf, t0, dur, f, "sine", amp * vel,
                    tremolo(env_perc(dur, attack=0.004, curve=2.2), 4.2, 0.25),
                    wrap=True)
        render_tone(buf, t0, dur, f * 2.0, "sine", amp * 0.3 * vel,
                    env_perc(dur, attack=0.003, curve=5.0), wrap=True)
        render_tone(buf, t0, 0.08, f * 7.0, "sine", amp * 0.06 * vel,
                    env_perc(0.08, attack=0.001, curve=8.0), wrap=True)

    return play


def organ(amp=0.05, attack=0.15, release=0.3):
    """Órgano de tiradores: los cuatro primeros armónicos en senos."""
    def play(buf, t0, dur, m, vel=1.0):
        f = midi_hz(m)
        e = env_swell(dur, a=min(attack, dur * 0.4), r=min(release, dur * 0.4))
        for ratio, gain in ((1.0, 1.0), (2.0, 0.5), (3.0, 0.28), (4.0, 0.16)):
            render_tone(buf, t0, dur, f * ratio, "sine", amp * gain * vel, e,
                        vib_hz=6.0, vib_depth=0.0015, wrap=True)

    return play


def pad(kind="triangle", amp=0.08, attack=0.6, release=0.8, detune=6.0,
        vib_hz=4.8, vib_depth=0.003):
    """Colchón: par desafinado que entra y sale suave (cuerdas, coro)."""
    def play(buf, t0, dur, m, vel=1.0):
        e = env_swell(dur, a=min(attack, dur * 0.45), r=min(release, dur * 0.45))
        for cents in (-detune, detune):
            render_tone(buf, t0, dur, midi_hz(m), kind, amp * vel, e,
                        detune_cents=cents, vib_hz=vib_hz, vib_depth=vib_depth,
                        wrap=True)

    return play


def stab(amp=0.07, ring=0.11):
    """Acorde cortado: triangular con un poco de cuadrada para el filo."""
    def play(buf, t0, dur, m, vel=1.0):
        e = env_perc(ring, attack=0.002, curve=5.0)
        render_tone(buf, t0, ring, midi_hz(m), "triangle", amp * vel, e, wrap=True)
        render_tone(buf, t0, ring, midi_hz(m), "square", amp * 0.35 * vel, e, wrap=True)

    return play


def layered(*instruments):
    def play(buf, t0, dur, m, vel=1.0):
        for instrument in instruments:
            instrument(buf, t0, dur, m, vel)

    return play


def echo(instrument, delay, taps=((1.0, 0), (0.45, 1), (0.2, 2))):
    def play(buf, t0, dur, m, vel=1.0):
        for gain, k in taps:
            instrument(buf, t0 + k * delay, dur, m, vel * gain)

    return play


def play_chords(buf, chords, instrument, overlap=0.0, vel=1.0):
    for t0, dur, notes in chords:
        for m in notes:
            instrument(buf, t0, dur + overlap, m, vel)


# Percusión: todo envuelve, así que un golpe en el último paso suena entero.

def kick(buf, t0, amp=0.5):
    # Cae hasta 60 Hz y no hasta 45 como un bombo de verdad: abajo de eso el
    # parlante de un teléfono no reproduce nada, pero el pico se come el
    # margen de toda la mezcla.
    render_tone(buf, t0, 0.2, glide(170.0, 60.0, 0.07), "sine", amp,
                env_perc(0.2, attack=0.002, curve=5.0), wrap=True)


def snare(buf, t0, rng, amp=0.4, tone=190.0, kind="triangle"):
    render_noise(buf, t0, 0.16, amp, 0.045, rng, wrap=True)
    render_tone(buf, t0, 0.09, tone, kind, amp * 0.6,
                env_perc(0.09, attack=0.001, curve=6.0), wrap=True)


def clap(buf, t0, rng, amp=0.35):
    for offset, gain in ((0.0, 0.7), (0.011, 0.8)):
        render_noise(buf, t0 + offset, 0.03, amp * gain, 0.008, rng, wrap=True)
    render_noise(buf, t0 + 0.022, 0.14, amp, 0.04, rng, wrap=True)


def hat(buf, t0, rng, amp=0.06, open_hat=False):
    if open_hat:
        render_noise(buf, t0, 0.14, amp * 1.2, 0.055, rng, wrap=True)
    else:
        render_noise(buf, t0, 0.05, amp, 0.018, rng, wrap=True)


def shaker(buf, t0, rng, amp=0.04):
    render_noise(buf, t0, 0.07, amp, 1.0, rng,
                 env=env_swell(0.07, a=0.025, r=0.04), wrap=True)


def rim(buf, t0, amp=0.18):
    render_tone(buf, t0, 0.025, 1750.0, "square", amp,
                env_perc(0.025, attack=0.0005, curve=8.0), wrap=True)
    render_tone(buf, t0, 0.04, 820.0, "triangle", amp * 0.7,
                env_perc(0.04, attack=0.0005, curve=7.0), wrap=True)


def clave(buf, t0, amp=0.16):
    render_tone(buf, t0, 0.07, 2500.0, "sine", amp,
                env_perc(0.07, attack=0.0005, curve=6.0), wrap=True)
    render_tone(buf, t0, 0.05, 5000.0, "sine", amp * 0.2,
                env_perc(0.05, attack=0.0005, curve=8.0), wrap=True)


def drum_tone(buf, t0, f, amp=0.35, dur=0.2, bend=1.3, curve=5.0):
    """Conga, tom o timbal: un seno que cae de `f·bend` a `f`."""
    render_tone(buf, t0, dur, glide(f * bend, f, min(0.08, dur * 0.3)), "sine",
                amp, env_perc(dur, attack=0.001, curve=curve), wrap=True)


def music_alley_loop():
    """Callejón: blues en Re menor arrastrando los pies. Shuffle a 84 BPM, un
    bajo que camina, una armónica (pulso 25 %) perezosa con la nota triste
    (Lab), acordes al contratiempo y una batería de lata: bombo, tacho y
    platillo sucio, con el crujido de un disco gastado."""
    g = Grid(84, 8, 8, swing=0.30)
    buf = [0.0] * g.samples
    rng = random.Random(1101)

    play_line(buf, g, """
        D2 - F2 - A2 - C3 -   | G2 - Bb2 - C3 - C#3 - | D3 - C3 - A2 - F2 -
        A2 - C#3 - E3 - C#3 - | D2 - F2 - A2 - C3 -   | G2 - F2 - G2 - A2 -
        Bb2 - D3 - F2 - Ab2 - | A2 - E2 - A1 - C#2 -
    """, bass(amp=0.36), gate=0.85)

    play_line(buf, g, """
        . . A4 C5 D5 - C5 A4   | G4 - - . F4 G4 Bb4 -  | A4 - - - . . . .
        . . E5 D5 C#5 - A4 -   | D5 - F5 - G5 Ab5 G5 F5 | D5 - - . Bb4 C5 D5 -
        F5 - D5 - Ab4 - Bb4 -  | A4 - - - . . . .
    """, lead("pulse25", amp=0.2, vib_hz=5.0, vib_depth=0.006, attack=0.025,
              release=0.06))

    # Acordes al contratiempo de 2 y 4 (pasos impares: el swing los empuja).
    comp = ["F3 A3 C4", "F3 Bb3 D4", "F3 A3 C4", "E3 G3 C#4",
            "F3 A3 C4", "F3 Bb3 D4", "F3 Ab3 D4", "E3 G3 C#4"]
    play_stab = stab(amp=0.075)
    for bar, voicing in enumerate(comp):
        for step in (3, 7):
            for m in chord(voicing):
                play_stab(buf, g.at(bar, step), 0.0, m)

    for t0, _ in hits(g, "x . . . x . . ."):
        kick(buf, t0, amp=0.45)
    for bar in (3, 7):
        kick(buf, g.at(bar, 7), amp=0.4)
    # El "tacho": ruido con un tono metálico de cuadrada.
    for t0, _ in hits(g, ". . x . . . x ."):
        snare(buf, t0, rng, amp=0.3, tone=330.0, kind="square")
    for t0, _ in hits(g, "x x x x x x x x"):
        hat(buf, t0, rng, amp=0.04)
    hat(buf, g.at(7, 7), rng, amp=0.07, open_hat=True)

    # Crujido de vinilo: chasquidos sueltos en lugares fijos (semilla fija).
    pops = random.Random(84)
    for _ in range(int(g.bars * g.bar * 2.5)):
        render_noise(buf, pops.uniform(0.0, g.bars * g.bar), 0.002,
                     pops.uniform(0.02, 0.06), 0.0006, rng, wrap=True)
    return buf


def music_urban_loop():
    """Ciudad: funk de avenida en Mi menor a 112 BPM. Bajo de octavas en
    semicorcheas, acordes cortados a contratiempo, palmas en 2 y 4, una
    melodía pegadiza de cuadrada y, al cerrar la vuelta, dos bocinazos."""
    g8 = Grid(112, 12, 8)
    g16 = Grid(112, 12, 16)
    buf = [0.0] * g8.samples
    rng = random.Random(1102)

    roots = ["E2", "C2", "G2", "D2", "E2", "C2", "G2", "D2", "A2", "B2", "C2", "D2"]
    voicings = ["G3 B3 D4 E4", "G3 B3 C4 E4", "G3 B3 D4", "F#3 A3 D4",
                "G3 B3 D4 E4", "G3 B3 C4 E4", "G3 B3 D4", "F#3 A3 D4",
                "G3 A3 C4 E4", "F#3 A3 B3 D4", "G3 B3 C4 E4", "F#3 A3 D4"]

    # Bajo: R = raíz, O = octava, F = quinta; semicorcheas cortas.
    play_bass = bass("pulse25", amp=0.2, release=0.02)
    for bar, root in enumerate(roots):
        r = note(root)
        for step, mark in enumerate("R..R..O.R.RO..F."):
            if mark == ".":
                continue
            m = {"R": r, "O": r + 12, "F": r + 7}[mark]
            play_bass(buf, g16.at(bar, step), g16.step * 0.7, m)

    play_stab = stab(amp=0.06, ring=0.09)
    for bar, voicing in enumerate(voicings):
        for step in (2, 6, 10, 13):
            for m in chord(voicing):
                play_stab(buf, g16.at(bar, step), 0.0, m)

    play_line(buf, g8, """
        E5 - G5 - B5 - A5 G5 | E5 - - - . . D5 E5 | D5 - B4 - G4 - A4 B4 | A4 - - - . . . .
        E5 - G5 - B5 - D6 -  | C6 - B5 - G5 - E5 - | D5 - G5 - B5 - A5 G5 | F#5 - - - . . A5 -
        G5 - E5 - C5 - E5 -  | F#5 - D5 - B4 - D5 - | E5 - G5 - E5 - C5 - | D5 - - - F#5 - . .
    """, lead("square", amp=0.2, vib_depth=0.003))

    # Dos bocinazos de auto en el último tiempo: una tercera mayor que cae.
    for step in (12, 14):
        t0 = g16.at(11, step)
        for f in (midi_hz(note("D4")), midi_hz(note("F#4"))):
            render_tone(buf, t0, 0.12, glide(f, f * 0.97, 0.12), "square", 0.07,
                        env_sustain(0.12, a=0.004, r=0.02), wrap=True)

    for t0, _ in hits(g16, "x . . . . . x . x . . . . . . ."):
        kick(buf, t0, amp=0.3)
    for t0, _ in hits(g16, ". . . . x . . . . . . . x . . ."):
        clap(buf, t0, rng, amp=0.2)
    for t0, accent in hits(g16, "X x X x X x X x X x X x X x X x"):
        hat(buf, t0, rng, amp=0.04 if accent else 0.025)
    for bar in range(1, g16.bars, 2):
        hat(buf, g16.at(bar, 14), rng, amp=0.05, open_hat=True)
    return buf


def music_corporate_loop():
    """Corporativo: bossa de ascensor en Do mayor a 90 BPM. Piano eléctrico
    con trémolo, un vibráfono amable, bajo de bossa, aro de redoblante en la
    clave y un teclado que tipea de fondo. Sala de espera: educada hasta la
    ironía."""
    g = Grid(90, 8, 8)
    g16 = Grid(90, 8, 16)
    buf = [0.0] * g.samples
    rng = random.Random(1103)

    roots = ["C3", "A2", "D3", "G2", "E2", "A2", "D3", "G2"]
    voicings = ["E3 G3 B3 D4", "E3 G3 C4", "F3 A3 C4 E4", "F3 B3 E4",
                "D3 G3 B3", "C#3 G3 B3", "F3 A3 C4 E4", "F3 B3 E4"]

    # Comping de bossa: la clave repartida en dos compases.
    play_ep = epiano(amp=0.085)
    for bar, voicing in enumerate(voicings):
        for step in ((0, 3, 6) if bar % 2 == 0 else (2, 5)):
            for m in chord(voicing):
                play_ep(buf, g.at(bar, step), g.step * 1.6, m)

    play_bass = bass(amp=0.34)
    for bar, root in enumerate(roots):
        r = note(root)
        for step, length, m in ((0, 3, r), (3, 3, fifth_of(r)), (6, 2, r)):
            play_bass(buf, g.at(bar, step), g.step * length * 0.9, m)

    play_line(buf, g, """
        E5 - - D5 E5 - G5 - | A5 - - - G5 - E5 - | F5 - - E5 F5 - A5 - | G5 - - - F5 - D5 -
        B4 - - - D5 - E5 -  | C#5 - - - E5 - G5 - | F5 - E5 - D5 - C5 - | B4 - - - D5 - . .
    """, vibes(amp=0.2))

    for bar in range(g.bars):
        for step in ((0, 3, 6) if bar % 2 == 0 else (2, 4)):
            rim(buf, g.at(bar, step), amp=0.12)
    for t0, _ in hits(g, "x . . x x . . x"):
        kick(buf, t0, amp=0.35)
    for t0, accent in hits(g16, "x x X x x x X x x x X x x x X x"):
        shaker(buf, t0, rng, amp=0.035 if accent else 0.02)

    # El teclado de la oficina: tecleo suelto en semicorcheas al azar fijo.
    typing = random.Random(1103)
    for index in range(g16.bars * g16.steps_per_bar):
        if typing.random() < 0.3:
            t0 = g16.t(index) + typing.uniform(0.0, g16.step * 0.5)
            render_tone(buf, t0, 0.012, 3200.0, "square", 0.025,
                        env_perc(0.012, attack=0.0005, curve=6.0), wrap=True)
            render_noise(buf, t0, 0.004, 0.04, 0.001, rng, wrap=True)
    return buf


def music_luxury_loop():
    """Lujo: lounge en Reb mayor a 76 BPM con swing. Arpa de triangulares al
    entrar cada acorde, cuerdas suaves, contrabajo en blancas, trompeta con
    sordina (pulso 25 % con vibrato lento), escobillas, ride y burbujas de
    champán."""
    g = Grid(76, 8, 8, swing=0.28)
    g16 = Grid(76, 8, 16)
    buf = [0.0] * g.samples
    rng = random.Random(1104)

    chords = harmony(g, [
        ("F3 Ab3 C4 Eb4", 4), ("Db3 F3 Ab3 C4", 4), ("Gb3 Bb3 Db4 F4", 4),
        ("Gb3 C4 F4", 4), ("F3 Ab3 C4 Eb4", 4), ("Bb3 Db4 F4 Ab4", 4),
        ("Eb3 Ab3 C4", 2), ("Db3 F3 Ab3", 2), ("Gb3 Bb3 Db4 F4", 2),
        ("Gb3 C4 F4", 2),
    ])
    roots = ["Db2", "Bb2", "Eb2", "Ab2", "Db2", "Gb2", "F2", "Bb2", "Eb2", "Ab2"]

    play_chords(buf, chords, pad("triangle", amp=0.05, attack=0.35, release=0.45,
                                 detune=5.0), overlap=0.25)

    play_bass = bass(amp=0.34)
    for (t0, dur, _), root in zip(chords, roots):
        r = note(root)
        if dur > 3 * g.beat:
            play_bass(buf, t0, 2 * g.beat * 0.9, r)
            play_bass(buf, t0 + 2 * g.beat, 2 * g.beat * 0.9, fifth_of(r))
        else:
            play_bass(buf, t0, dur * 0.9, r)

    # Arpa: el acorde subido en semicorcheas y su octava, con un eco corto.
    harp = echo(pluck("triangle", amp=0.09, ring=0.9, curve=3.5), g.beat * 0.75,
                taps=((1.0, 0), (0.35, 1)))
    for t0, _, notes in chords:
        for k, m in enumerate(notes + [n + 12 for n in notes[:2]]):
            harp(buf, t0 + k * g16.step, 0.0, m)

    play_line(buf, g, """
        F5 - - Eb5 F5 - Ab5 - | Db6 - - - C6 - Ab5 - | Gb5 - - F5 Gb5 - Bb5 - | Ab5 - - - F5 - - .
        C6 - Ab5 - F5 - Eb5 - | F5 - - - Db5 - Bb4 - | Ab4 - C5 - Db5 - F5 -   | Eb5 - - - . . . .
    """, lead("pulse25", amp=0.15, vib_hz=4.6, vib_depth=0.005, attack=0.035,
              release=0.08))

    for t0, _ in hits(g, ". . x . . . x ."):
        render_noise_lp(buf, t0, 0.2, 0.22, rng, 0.35,
                        env_swell(0.2, a=0.06, r=0.12), wrap=True)
    for t0, _ in hits(g, "x . x x x . x x"):
        render_noise(buf, t0, 0.18, 0.03, 0.09, rng, wrap=True)

    # Burbujas de champán: cuatro pings agudos subiendo, compás por medio.
    bubbles = bell(amp=0.05, ring=0.35)
    fizz = random.Random(76)
    for bar in (1, 3, 5, 7):
        for k in range(4):
            m = note("Ab6") + fizz.choice((0, 2, 4, 7)) + 2 * k
            bubbles(buf, g.at(bar, 6) + k * 0.07, 0.0, m)
    return buf


def music_island_loop():
    """Isla: calipso en Fa mayor a 108 BPM. Melodía de steel drum, acordes en
    los contratiempos, un bajo que salta, la clave 3-2, congas y shaker."""
    g = Grid(108, 12, 8)
    g16 = Grid(108, 12, 16)
    buf = [0.0] * g.samples
    rng = random.Random(1105)

    roots = ["F2", "Bb2", "C3", "F2", "F2", "Bb2", "C3", "F2", "D3", "Bb2", "C3", "C3"]
    voicings = {"F2": "A3 C4 F4", "Bb2": "Bb3 D4 F4", "C3": "Bb3 C4 E4",
                "D3": "A3 D4 F4"}

    play_bass = bass(amp=0.3)
    for bar, root in enumerate(roots):
        r = note(root)
        for step, length, m in ((0, 3, r), (3, 1, r), (4, 2, fifth_of(r)), (6, 1, r + 12)):
            play_bass(buf, g.at(bar, step), g.step * length * 0.85, m)

    # Un colchón muy bajo: el steel drum es todo ataque, y sin algo sostenido
    # el tema es puro pico y, con el techo de -9 dBFS, queda más bajo que el
    # resto de la torre.
    play_pad = pad("triangle", amp=0.035, attack=0.2, release=0.3, detune=6.0)
    play_stab = stab(amp=0.055, ring=0.09)
    for bar, root in enumerate(roots):
        for m in chord(voicings[root]):
            play_pad(buf, g.at(bar, 0), g.bar + 0.1, m)
        for step in (1, 3, 5, 7):
            for m in chord(voicings[root]):
                play_stab(buf, g.at(bar, step), 0.0, m)

    play_line(buf, g, """
        C6 - A5 C6 - A5 G5 F5   | D6 - Bb5 D6 - Bb5 A5 G5 | E5 - G5 Bb5 - G5 E5 C5 | F5 - - - . . A5 G5
        A5 - C6 - F6 - C6 A5    | Bb5 - D6 - F6 - D6 Bb5  | C6 - Bb5 - G5 - E5 -    | F5 - - - . . . .
        D6 - A5 D6 - A5 F5 -    | F5 - D5 F5 - D5 Bb4 -   | C5 - E5 G5 - Bb5 - -   | C6 - - . G5 - E5 -
    """, bell(amp=0.2, ring=0.6, partials=PAN_PARTIALS))

    for bar in range(g16.bars):
        for step in ((0, 6, 12) if bar % 2 == 0 else (4, 8)):
            clave(buf, g16.at(bar, step), amp=0.12)
    for t0, _ in hits(g16, ". . . x . . . . . . . x . . . ."):
        drum_tone(buf, t0, 290.0, amp=0.15)
    for t0, _ in hits(g16, ". . . . . . x x . . . . . . x x"):
        drum_tone(buf, t0, 200.0, amp=0.18)
    for t0, _ in hits(g16, "x . . . . . . . x . . . . . . ."):
        kick(buf, t0, amp=0.25)
    for t0, accent in hits(g16, "x x X x x x X x x x X x x x X x"):
        shaker(buf, t0, rng, amp=0.04 if accent else 0.025)
    return buf


def music_moon_loop():
    """Luna: Fa lidio a 64 BPM, ralo y flotando. Colchones que respiran,
    "bloops" de baja gravedad con eco, un latido grave por compás y el pitido
    de radio del Apolo (2525 Hz) bien al fondo."""
    g = Grid(64, 8, 8)
    buf = [0.0] * g.samples
    rng = random.Random(1106)

    chords = harmony(g, [
        ("F3 A3 C4 E4 B4", 8), ("F3 G3 B3 D4", 8), ("E3 G3 B3 D4", 8),
        ("E3 G3 A3 C4", 8),
    ])
    play_chords(buf, chords, pad("sine", amp=0.07, attack=1.3, release=1.3,
                                 detune=4.0))
    play_chords(buf, chords, pad("triangle", amp=0.025, attack=1.6, release=1.6,
                                 detune=7.0))

    # El latido: dos golpes graves al empezar cada compás.
    roots = ["F2", "F2", "G2", "G2", "E2", "E2", "A2", "A2"]
    for bar, root in enumerate(roots):
        f = midi_hz(note(root))
        for offset, amp in ((0.0, 0.22), (0.28, 0.14)):
            drum_tone(buf, g.at(bar, 0) + offset, f, amp=amp, dur=0.35, bend=1.15,
                      curve=4.0)

    def bloop(buf, t0, dur, m, vel=1.0):
        f = midi_hz(m)
        render_tone(buf, t0, 0.45, glide(f * 0.75, f, 0.05), "sine", 0.17 * vel,
                    env_perc(0.45, attack=0.003, curve=5.0), wrap=True)

    play_line(buf, g, """
        C5 . . E5 . . B5 .   | . . A5 . . G5 . .  | D5 . . F5 . . C6 . | . . B5 . . . . .
        E5 . . G5 . . B5 .   | . . D6 . . B5 . .  | A5 . . C6 . . E6 . | . . G5 . . . . .
    """, echo(bloop, g.step * 3))

    # Quindar: el tono de entrada (2525 Hz) y el de salida (2475 Hz).
    for bar, f in ((3, 2525.0), (7, 2475.0)):
        render_tone(buf, g.at(bar, 4), 0.25, f, "sine", 0.025,
                    env_sustain(0.25, a=0.01, r=0.02), wrap=True)

    # Polvo lunar: un soplo oscuro en cada cambio de acorde.
    for t0, _, _ in chords:
        render_noise_lp(buf, t0 - 1.0, 2.0, 0.12, rng, 0.04,
                        env_swell(2.0, a=1.2, r=0.8), wrap=True)
    return buf


def music_mars_loop():
    """Marte: Re menor frigio a 96 BPM, desierto rojo y aventura. Ostinato de
    bajo en corcheas (pulso), toms de expedición a medio tiempo, metales
    cuadrados, una melodía heroica con la segunda menor (Mib) que la vuelve
    rara, viento de polvo y un rayo láser al cerrar la vuelta."""
    g = Grid(96, 8, 8)
    g16 = Grid(96, 8, 16)
    buf = [0.0] * g.samples
    rng = random.Random(1107)

    roots = ["D2", "Eb2", "C2", "D2", "Bb2", "Eb2", "G2", "A2"]
    voicings = ["D3 F3 A3", "Eb3 G3 Bb3", "C3 E3 G3", "D3 F3 A3",
                "D3 F3 Bb3", "Eb3 G3 Bb3", "D3 G3 Bb3", "C#3 E3 A3"]

    play_bass = bass("pulse25", amp=0.26, release=0.02)
    for bar, root in enumerate(roots):
        r = note(root)
        for step, mark in enumerate("RROR RORF".replace(" ", "")):
            m = {"R": r, "O": r + 12, "F": r + 7}[mark]
            play_bass(buf, g.at(bar, step), g.step * 0.75, m)

    brass = pad("square", amp=0.03, attack=0.08, release=0.25, detune=4.0,
                vib_depth=0.0)
    for bar, voicing in enumerate(voicings):
        for m in chord(voicing):
            brass(buf, g.at(bar, 0), g.bar * 0.95, m)

    play_line(buf, g, """
        D5 - - - A4 - D5 Eb5 | G5 - - - F5 - Eb5 - | G5 - - - C5 - D5 - | F5 - - - D5 - - .
        F5 - - - D5 - F5 Bb5 | G5 - - - Bb5 - G5 - | D5 - - - Bb4 - G4 - | A4 - - - C#5 - E5 -
    """, lead("square", amp=0.2, detune=6.0, vib_hz=5.0, vib_depth=0.004))

    for t0, _ in hits(g16, "x . . . . . x . . . x . . . . ."):
        drum_tone(buf, t0, 82.0, amp=0.36, dur=0.35, bend=1.6, curve=4.5)
    for t0, _ in hits(g16, ". . . x . . . . . . . . x . x ."):
        drum_tone(buf, t0, 123.0, amp=0.26, dur=0.3, bend=1.6, curve=4.5)
    for t0, _ in hits(g16, ". . . . . . . . x . . . . . . ."):
        snare(buf, t0, rng, amp=0.3, tone=170.0)
    for t0, _ in hits(g16, "x . x . x . x . x . x . x . x ."):
        hat(buf, t0, rng, amp=0.03)

    # Viento de polvo: ruido oscuro que sube y baja cada cuatro compases.
    for bar in (0, 4):
        render_noise_lp(buf, g.at(bar, 0), 4 * g.bar, 0.5, rng, 0.03,
                        env_swell(4 * g.bar, a=2 * g.bar, r=2 * g.bar), wrap=True)

    # El láser: una cuadrada que cae al final de la vuelta.
    render_tone(buf, g.at(7, 6), 0.25, glide(1400.0, 180.0, 0.25), "square", 0.05,
                env_perc(0.25, attack=0.002, curve=3.0), wrap=True)
    return buf


def music_solar_loop():
    """Sistema solar: Do lidio a 116 BPM, todo brilla y gira. Dos arpegiadores
    con ciclos distintos (sube y baja en 16, y otro de 3 notas que no reinicia
    con el compás) se desfasan como órbitas; colchón ancho, bajo largo y una
    melodía de notas largas."""
    g8 = Grid(116, 12, 8)
    g16 = Grid(116, 12, 16)
    buf = [0.0] * g8.samples
    rng = random.Random(1108)

    tones = {
        "Cmaj7": "C4 E4 G4 B4", "D/C": "C4 D4 F#4 A4", "Em7": "E4 G4 B4 D5",
        "D": "D4 F#4 A4 D5", "Bm7": "D4 F#4 A4 B4", "Am7": "C4 E4 G4 A4",
    }
    progression = ["Cmaj7", "D/C", "Em7", "D", "Cmaj7", "D/C", "Bm7", "Em7",
                   "Am7", "Bm7", "Cmaj7", "D"]
    roots = ["C3", "C3", "E2", "D3", "C3", "C3", "B2", "E2", "A2", "B2", "C3", "D3"]

    orbit_a = pluck("pulse25", amp=0.07, ring=0.14, curve=5.0)
    orbit_b = echo(pluck("triangle", amp=0.07, ring=0.25, curve=4.0), g16.step * 3,
                   taps=((1.0, 0), (0.4, 1)))
    cycle_b = (0, 2, 4)
    shape_a = (0, 1, 2, 3, 4, 3, 2, 1, 0, 1, 2, 3, 4, 3, 2, 1)
    for bar, name in enumerate(progression):
        notes = chord(tones[name])
        notes = notes + [notes[0] + 12, notes[1] + 12]
        for step in range(16):
            orbit_a(buf, g16.at(bar, step), 0.0, notes[shape_a[step]])
            index = bar * 16 + step
            if index % 2 == 0:
                orbit_b(buf, g16.at(bar, step), 0.0,
                        notes[cycle_b[(index // 2) % 3]] + 12)

    warm = pad("triangle", amp=0.05, attack=0.3, release=0.4, detune=6.0)
    play_bass = bass(amp=0.32)
    for bar, (name, root) in enumerate(zip(progression, roots)):
        for m in chord(tones[name])[:3]:
            warm(buf, g8.at(bar, 0), g8.bar + 0.2, m - 12)
        play_bass(buf, g8.at(bar, 0), g8.bar * 0.95, note(root))

    play_line(buf, g8, """
        E5 - - - G5 - - -  | F#5 - - - A5 - - - | B5 - - - - - G5 - | A5 - - - - - - .
        E5 - - - G5 - B5 - | D6 - - - C6 - A5 - | B5 - - - F#5 - D5 - | E5 - - - - - . .
        C6 - - - B5 - A5 - | B5 - - - A5 - F#5 - | G5 - - - E5 - G5 - | F#5 - - - - - - .
    """, lead("square", amp=0.17, detune=4.0, vib_depth=0.004, attack=0.02,
              release=0.08))

    for t0, _ in hits(g8, "x . . . x . . ."):
        kick(buf, t0, amp=0.42)
    for t0, _ in hits(g8, ". . x . . . x ."):
        snare(buf, t0, rng, amp=0.25, tone=220.0)
    for t0, _ in hits(g8, "x x x x x x x x"):
        hat(buf, t0, rng, amp=0.03)
    # Una erupción solar cada cuatro compases.
    for bar in (3, 7, 11):
        render_noise_lp(buf, g8.at(bar, 4), 2 * g8.beat, 0.15, rng, 0.15,
                        env_swell(2 * g8.beat, a=1.6 * g8.beat, r=0.4 * g8.beat),
                        wrap=True)
    return buf


# La galaxia es el loop cósmico de la v1 (72 BPM, 8 compases ≈ 26,667 s), que
# se generaba pero nunca llegó a sonar: pads que respiran y estrellas con eco.
COSMIC_BPM = 72
COSMIC_BARS = 8

COSMIC_PADS = [  # 2 compases por acorde
    [57, 60, 64, 71],  # Am(add9)
    [53, 57, 60, 64],  # Fmaj7
    [55, 60, 64, 71],  # Cmaj7
    [55, 59, 62, 64],  # G6
]
COSMIC_ROOTS = [45, 41, 48, 43]  # A2 F2 C3 G2
COSMIC_STARS = [  # (compás, beat, midi, beats de duración)
    (0, 2.0, 76, 2.0),
    (1, 0.0, 83, 3.0),
    (2, 2.0, 81, 2.0),
    (3, 0.0, 84, 3.0),
    (4, 2.0, 76, 2.0),
    (5, 0.0, 83, 3.0),
    (6, 2.0, 86, 2.0),
    (7, 0.0, 83, 1.5),
    (7, 2.0, 81, 2.0),  # la cola envuelve al inicio del loop
]


def music_galaxy_loop():
    beat = 60.0 / COSMIC_BPM
    bar = 4.0 * beat
    total = int(round(COSMIC_BARS * bar * SR))  # 1176000
    buf = [0.0] * total
    rng = random.Random(2001)

    # Pads: pares de triangulares detuneadas por nota + capa de cuadrada
    # suave en la voz superior. Swell smoothstep que llega a 0 en el borde.
    for ci, chord_notes in enumerate(COSMIC_PADS):
        t0 = ci * 2 * bar
        dur = 2 * bar
        e = env_swell(dur, a=1.4, r=1.4)
        for m in chord_notes:
            for det in (-6.0, 6.0):
                render_tone(buf, t0, dur, midi_hz(m), "triangle", 0.16, e,
                            detune_cents=det, wrap=True)
        render_tone(buf, t0, dur, midi_hz(chord_notes[-1]), "square", 0.07, e,
                    detune_cents=-4.0, vib_hz=4.5, vib_depth=0.003, wrap=True)
        # Sub: seno en la raíz.
        render_tone(buf, t0, dur, midi_hz(COSMIC_ROOTS[ci]), "sine", 0.30,
                    env_swell(dur, a=0.9, r=0.9), wrap=True)

    # Estrellas: senos agudos sueltos con eco (las colas envuelven el loop).
    delay = 0.75 * beat
    for bar_i, beat_i, m, beats in COSMIC_STARS:
        t0 = (bar_i * 4 + beat_i) * beat
        dur = beats * beat
        for gain, offset in ((1.0, 0.0), (0.45, delay), (0.20, 2 * delay)):
            render_tone(buf, t0 + offset, dur, midi_hz(m), "sine",
                        0.16 * gain, env_perc(dur, attack=0.015, curve=3.0),
                        vib_hz=5.0, vib_depth=0.003, wrap=True)

    # Percusión mínima: hat suave en beats 2 y 4.
    for bar_i in range(COSMIC_BARS):
        for beat_i in (1.0, 3.0):
            t0 = (bar_i * 4 + beat_i) * beat
            render_noise(buf, t0, 0.10, 0.035, 0.035, rng, wrap=True)

    # Respiración espacial: swell de ruido entrando a los compases 0 y 4.
    for target_bar in (4, 8):
        dur = 2.0 * beat
        t0 = target_bar * bar - dur  # el de compás 8 envuelve al 0
        render_noise(buf, t0, dur, 0.030, 1.0, rng, wrap=True,
                     env=env_swell(dur, a=dur * 0.8, r=dur * 0.2))
    return buf


def music_god_realm_loop():
    """Reino divino: Re mayor a 66 BPM, solemne y luminoso. Órgano de senos,
    coro de triangulares con vibrato, un glissando de arpa al abrir cada
    frase, campanas en el primer tiempo, timbal suave y una voz angelical de
    notas largas."""
    g = Grid(66, 8, 8)
    buf = [0.0] * g.samples

    spec = [("D", 4), ("G/D", 4), ("D", 4), ("A/C#", 4), ("Bm", 4), ("G", 4),
            ("Em7", 4), ("Asus4", 2), ("A", 2)]
    low = {"D": "D3 A3 D4 F#4", "G/D": "D3 G3 B3 D4", "A/C#": "C#3 E3 A3 C#4",
           "Bm": "B2 F#3 B3 D4", "G": "G2 D3 G3 B3", "Em7": "E3 G3 B3 D4",
           "Asus4": "A2 D3 E3 A3", "A": "A2 C#3 E3 A3"}
    high = {"D": "A4 D5 F#5", "G/D": "B4 D5 G5", "A/C#": "A4 C#5 E5",
            "Bm": "B4 D5 F#5", "G": "B4 D5 G5", "Em7": "B4 E5 G5",
            "Asus4": "A4 D5 E5", "A": "A4 C#5 E5"}
    organ_chords = harmony(g, [(low[name], beats) for name, beats in spec])
    choir_chords = harmony(g, [(high[name], beats) for name, beats in spec])

    play_chords(buf, organ_chords, organ(amp=0.045), overlap=0.15)
    play_chords(buf, choir_chords, pad("triangle", amp=0.045, attack=0.5,
                                       release=0.6, detune=7.0, vib_hz=5.2,
                                       vib_depth=0.004), overlap=0.3)

    # Campanas al empezar cada acorde; la del principio de la frase, más fuerte.
    church = bell(amp=0.06, ring=2.2)
    for k, (t0, _, notes) in enumerate(organ_chords):
        church(buf, t0, 0.0, notes[0] + 36 if notes[0] + 36 <= 86 else notes[0] + 24,
               1.4 if k in (0, 4) else 1.0)

    # Glissando de arpa y timbal al abrir cada frase de cuatro compases.
    harp = pluck("triangle", amp=0.08, ring=1.2, curve=3.0)
    for bar in (0, 4):
        t0 = g.at(bar, 0)
        for k, name in enumerate("D4 F#4 A4 D5 F#5 A5 D6 F#6".split()):
            harp(buf, t0 + k * 0.06, 0.0, note(name))
        drum_tone(buf, t0, 73.4, amp=0.28, dur=0.9, bend=1.5, curve=3.5)

    play_line(buf, g, """
        F#5 - - - - - A5 - | B5 - - - A5 - G5 - | F#5 - - - - - D5 - | E5 - - - - - . .
        D5 - - - F#5 - B5 - | D6 - - - B5 - G5 - | A5 - - - G5 - F#5 - | D5 - - - C#5 - - .
    """, layered(
        lead("sine", amp=0.17, vib_hz=5.5, vib_depth=0.005, attack=0.08, release=0.15),
        lead("triangle", amp=0.06, vib_hz=5.5, vib_depth=0.005, attack=0.08,
             release=0.15),
    ))
    return buf


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
    "sfx_wheel_tick": sfx_wheel_tick,
    "sfx_blackout": sfx_blackout,
    "sfx_elevator_ding": sfx_elevator_ding,
    "sfx_elevator_spring": sfx_elevator_spring,
    "sfx_elevator_click": sfx_elevator_click,
    "sfx_elevator_doors": sfx_elevator_doors,
    "sfx_elevator_motor": sfx_elevator_motor,
    "sfx_package_rattle": sfx_package_rattle,
    "sfx_package_tape_rip": sfx_package_tape_rip,
    "sfx_package_burst": sfx_package_burst,
    "sfx_mattress_squeak": sfx_mattress_squeak,
    "sfx_mattress_rip": sfx_mattress_rip,
    "sfx_cash_burst": sfx_cash_burst,
    "sfx_visitor_arrive": sfx_visitor_arrive,
    "sfx_talk_blip": sfx_talk_blip,
    "sfx_shop_shimmer": sfx_shop_shimmer,
    "sfx_reveal_whoosh": sfx_reveal_whoosh,
    "sfx_elevator_cable": sfx_elevator_cable,
    "sfx_merge_all_done": sfx_merge_all_done,
}
# Los efectos de la 2.0 nivelan por RMS (pico a -3 dBFS como techo) y no sólo
# por pico: normalizar al pico dejó el motor del ascensor 8 dB arriba de los
# demás. Los de ambiente van sin fundido de bordes: son loops cerrados.
SFX_RMS_DB = {
    "sfx_package_rattle": -23.0,
    "sfx_package_tape_rip": -20.0,
    "sfx_package_burst": -18.0,
    "sfx_mattress_squeak": -23.0,
    "sfx_mattress_rip": -20.0,
    "sfx_cash_burst": -19.0,
    "sfx_visitor_arrive": -19.0,
    "sfx_talk_blip": -20.0,
    "sfx_shop_shimmer": -21.0,
    "sfx_reveal_whoosh": -21.0,
    "sfx_elevator_cable": -24.0,
    "sfx_merge_all_done": -20.0,
}
SFX_LOOPS = {"sfx_package_rattle", "sfx_mattress_squeak"}
MUSIC = {
    "music_earth_loop": music_earth_loop,
}
# Un tema por piso, con el id de `economy.json` en el nombre: es el contrato
# que lee `FloorMusicDirector.track(forFloor:)`.
FLOOR_MUSIC = {
    "music_alley_loop": music_alley_loop,
    "music_urban_loop": music_urban_loop,
    "music_corporate_loop": music_corporate_loop,
    "music_luxury_loop": music_luxury_loop,
    "music_island_loop": music_island_loop,
    "music_moon_loop": music_moon_loop,
    "music_mars_loop": music_mars_loop,
    "music_solar_loop": music_solar_loop,
    "music_galaxy_loop": music_galaxy_loop,
    "music_god_realm_loop": music_god_realm_loop,
}
FLOOR_MUSIC_RMS_DB = -20.0
FLOOR_MUSIC_PEAK_DB = -9.0
# Mono a 80 kbps. Medido sobre el loop de la Tierra: 64 kbps da 33,7 dB de
# SNR, 80 da 35,7 y 96 da 37,3; 80 es el margen sobre 64 por ~35 KB más por
# tema, y 96 sumaría peso sin que se note en el parlante de un teléfono.
FLOOR_MUSIC_BITRATE = 80000


def afconvert(wav_path, out_path):
    subprocess.run(
        ["/usr/bin/afconvert", wav_path, out_path, "-d", "LEI16", "-f", "caff"],
        check=True,
    )


def afconvert_aac(wav_path, out_path):
    subprocess.run(
        ["/usr/bin/afconvert", wav_path, out_path, "-d", "aac", "-f", "caff",
         "-b", str(FLOOR_MUSIC_BITRATE)],
        check=True,
    )


def check_aac_loop(name, caf_path, frames):
    """Decodifica el AAC de vuelta y verifica lo que podía romper el loop.

    1. El largo: si la tabla de paquetes del CAF no recorta el priming del
       encoder, el tema decodifica más largo y el loop tropieza en la costura.
    2. La costura: el salto entre la última muestra y la primera no puede ser
       más grande que el 99 % de los saltos entre muestras vecinas del propio
       tema. Un clic es justamente un salto que no aparece en otro lado.

    Devuelve la costura como fracción de ese percentil, para la tabla.
    """
    decoded_path = os.path.join(BUILD, f"{name}.decoded.wav")
    subprocess.run(
        ["/usr/bin/afconvert", caf_path, decoded_path, "-d", "LEI16", "-f", "WAVE"],
        check=True,
    )
    x = read_wav(decoded_path)
    assert len(x) == frames, f"{name}: decodifica {len(x)} muestras y el loop tiene {frames}"
    steps = sorted(abs(x[i + 1] - x[i]) for i in range(len(x) - 1))
    typical = steps[int(len(steps) * 0.99)]
    seam = abs(x[0] - x[-1])
    assert seam <= typical, f"{name}: la costura salta {seam:.4f} (p99 del tema: {typical:.4f})"
    return seam / typical


def main():
    convert = "--no-convert" not in sys.argv
    wanted = [arg for arg in sys.argv[1:] if not arg.startswith("--")]
    jobs = (
        [(n, f, "sfx") for n, f in SFX.items()]
        + [(n, f, "music") for n, f in MUSIC.items()]
        + [(n, f, "floor") for n, f in FLOOR_MUSIC.items()]
    )
    unknown = sorted(set(wanted) - {name for name, _, _ in jobs})
    if unknown:
        sys.exit(f"no conozco: {', '.join(unknown)}")
    if wanted:
        jobs = [job for job in jobs if job[0] in wanted]

    os.makedirs(BUILD, exist_ok=True)
    if convert:
        os.makedirs(DEST, exist_ok=True)

    floor_bytes = 0
    print(f"{'archivo':<22} {'dur':>8} {'pico':>9} {'RMS':>9} {'KB':>7} {'costura':>8}")
    for name, fn, kind in jobs:
        buf = fn()
        if kind == "sfx":
            if name not in SFX_LOOPS:
                edge_fades(buf)  # anti-click garantizado en los bordes
            if name in SFX_RMS_DB:
                buf = normalize_loudness(buf, SFX_RMS_DB[name], SFX_PEAK_DB)
            else:
                buf = normalize(buf, SFX_PEAK_DB)
            peak_db = SFX_PEAK_DB
        elif kind == "music":
            buf = normalize(buf, MUSIC_PEAK_DB)
            peak_db = MUSIC_PEAK_DB
        else:
            buf = normalize_loudness(buf, FLOOR_MUSIC_RMS_DB, FLOOR_MUSIC_PEAK_DB)
            peak_db = FLOOR_MUSIC_PEAK_DB
        peak, rms = measure(buf)
        limit = peak_db + 0.01
        assert peak <= limit, f"{name}: clipping ({peak:.2f} dBFS > {limit})"
        assert rms > RMS_FLOOR_DB, f"{name}: archivo casi mudo ({rms:.1f} dBFS)"
        wav_path = os.path.join(BUILD, f"{name}.wav")
        write_wav(wav_path, buf)
        size, seam = "", ""
        if convert:
            out_path = os.path.join(DEST, f"{name}.caf")
            if kind == "floor":
                afconvert_aac(wav_path, out_path)
                seam = f"{check_aac_loop(name, out_path, len(buf)):.2f}"
                floor_bytes += os.path.getsize(out_path)
            else:
                afconvert(wav_path, out_path)
            size = f"{os.path.getsize(out_path) / 1024:.0f}"
        print(f"{name:<22} {len(buf) / SR:>7.3f}s {peak:>8.2f}dB {rms:>8.2f}dB "
              f"{size:>7} {seam:>8}")

    if convert:
        print(f"\nfinales (.caf) en {DEST}")
        if floor_bytes:
            print(f"temas por piso (AAC {FLOOR_MUSIC_BITRATE // 1000} kbps): "
                  f"{floor_bytes / 1024:.0f} KB")


if __name__ == "__main__":
    main()
