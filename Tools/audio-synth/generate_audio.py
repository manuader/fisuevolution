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
      * música → .caf LEI16 (NO m4a: AAC agrega padding de encoder que rompe
        el loop; AudioManager prueba caf antes que m4a, así que caf gana).

Loops perfectos: los dos music_* se renderizan con "wrap-around" — todo
evento cuya cola pasa el final del buffer se suma al principio (módulo N).
El largo cae exacto en frontera de compás (96 BPM → 8 compases = 882000
samples = 20.000 s; 72 BPM → 8 compases = 1176000 samples ≈ 26.667 s) y la
señal es continua en el punto de loop por construcción.

Normalización: SFX pico a -3 dBFS, música pico a -9 dBFS. Se verifica que no
haya clipping y que el RMS supere el piso de silencio (-60 dBFS).
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
        tab.append(v)
    peak = max(abs(s) for s in tab) or 1.0
    return [s / peak for s in tab]


def table_for(kind, freq):
    """Tabla del timbre pedido con armónicos limitados bajo ~18 kHz."""
    if kind == "sine":
        max_harm = 1
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


# Cosmic: 72 BPM, 8 compases 4/4 → 1176000 samples ≈ 26.667 s exactos.
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


def music_cosmic_loop():
    beat = 60.0 / COSMIC_BPM
    bar = 4.0 * beat
    total = int(round(COSMIC_BARS * bar * SR))  # 1176000
    buf = [0.0] * total
    rng = random.Random(2001)

    # Pads: pares de triangulares detuneadas por nota + capa de cuadrada
    # suave en la voz superior. Swell smoothstep que llega a 0 en el borde.
    for ci, chord in enumerate(COSMIC_PADS):
        t0 = ci * 2 * bar
        dur = 2 * bar
        e = env_swell(dur, a=1.4, r=1.4)
        for m in chord:
            for det in (-6.0, 6.0):
                render_tone(buf, t0, dur, midi_hz(m), "triangle", 0.16, e,
                            detune_cents=det, wrap=True)
        render_tone(buf, t0, dur, midi_hz(chord[-1]), "square", 0.07, e,
                    detune_cents=-4.0, vib_hz=4.5, vib_depth=0.003, wrap=True)
        # Sub: seno en la raíz.
        render_tone(buf, t0, dur, midi_hz(COSMIC_ROOTS[ci]), "sine", 0.30,
                    env_swell(dur, a=0.9, r=0.9), wrap=True)

    # Estrellas: senos agudos sueltos con eco (las colas envuelven el loop).
    echo = 0.75 * beat
    for bar_i, beat_i, m, beats in COSMIC_STARS:
        t0 = (bar_i * 4 + beat_i) * beat
        dur = beats * beat
        for gain, offset in ((1.0, 0.0), (0.45, echo), (0.20, 2 * echo)):
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


def afconvert(wav_path, out_path):
    subprocess.run(
        ["/usr/bin/afconvert", wav_path, out_path, "-d", "LEI16", "-f", "caff"],
        check=True,
    )


def main():
    convert = "--no-convert" not in sys.argv
    os.makedirs(BUILD, exist_ok=True)
    if convert:
        os.makedirs(DEST, exist_ok=True)

    print(f"{'archivo':<22} {'dur':>8} {'pico':>9} {'RMS':>9}")
    for name, fn, peak_db in (
        [(n, f, SFX_PEAK_DB) for n, f in SFX.items()]
        + [(n, f, MUSIC_PEAK_DB) for n, f in MUSIC.items()]
    ):
        buf = fn()
        is_sfx = name.startswith("sfx_")
        if is_sfx:
            edge_fades(buf)  # anti-click garantizado en los bordes
        buf = normalize(buf, peak_db)
        peak, rms = measure(buf)
        limit = peak_db + 0.01
        assert peak <= limit, f"{name}: clipping ({peak:.2f} dBFS > {limit})"
        assert rms > RMS_FLOOR_DB, f"{name}: archivo casi mudo ({rms:.1f} dBFS)"
        wav_path = os.path.join(BUILD, f"{name}.wav")
        write_wav(wav_path, buf)
        if convert:
            afconvert(wav_path, os.path.join(DEST, f"{name}.caf"))
        print(f"{name:<22} {len(buf) / SR:>7.3f}s {peak:>8.2f}dB {rms:>8.2f}dB")

    if convert:
        print(f"\nfinales (.caf) en {DEST}")


if __name__ == "__main__":
    main()
