"""Banda sonora del reel: electrónica a 120 BPM sintetizada, sincronizada con
los cortes de scene.js, más los SFX reales del juego (Resources/Audio).

    python3 music.py  →  out/audio.wav  (48 kHz, estéreo, 30 s)

Requiere numpy + scipy. Los .caf del juego se pasan antes a out/sfx/*.wav
(ver README.md).
"""
import os
import wave
import numpy as np
from scipy.signal import butter, sosfilt, fftconvolve

SR = 48000
DUR = 30.0
N = int(SR * DUR)
BEAT = 0.5
HERE = os.path.dirname(os.path.abspath(__file__))
rng = np.random.default_rng(7)

L = np.zeros(N)
R = np.zeros(N)
# buses para procesar por separado
bus = {k: np.zeros((2, N)) for k in ('drums', 'bass', 'music', 'fx', 'sfx', 'verb')}


def t_arr(n):
    return np.arange(n) / SR


def place(name, sig, t, gain=1.0, pan=0.0, verb=0.0):
    i = int(round(t * SR))
    if i >= N or i + len(sig) <= 0:
        return
    s = sig
    if i < 0:
        s = s[-i:]
        i = 0
    s = s[:N - i]
    lg = gain * np.sqrt(0.5 * (1 - pan))
    rg = gain * np.sqrt(0.5 * (1 + pan))
    bus[name][0, i:i + len(s)] += s * lg
    bus[name][1, i:i + len(s)] += s * rg
    if verb:
        bus['verb'][0, i:i + len(s)] += s * lg * verb
        bus['verb'][1, i:i + len(s)] += s * rg * verb


def lp(x, f, order=2):
    return sosfilt(butter(order, f, 'low', fs=SR, output='sos'), x)


def hp(x, f, order=2):
    return sosfilt(butter(order, f, 'high', fs=SR, output='sos'), x)


def bp(x, lo, hi, order=2):
    return sosfilt(butter(order, [lo, hi], 'band', fs=SR, output='sos'), x)


def env(n, a=0.002, d=0.2, curve=4.0):
    t = t_arr(n)
    e = np.minimum(t / max(a, 1e-5), 1.0) * np.exp(-np.maximum(t - a, 0) / d * curve / 4)
    return e


def note(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def saw(f, n, detune=0.0, phase=0.0):
    t = t_arr(n)
    ph = (f * (1 + detune) * t + phase) % 1.0
    return 2 * ph - 1


# ───────────────────────── instrumentos ─────────────────────────
def kick(big=1.0):
    n = int(SR * 0.45)
    t = t_arr(n)
    f = 45 + 110 * np.exp(-t * 32)
    ph = 2 * np.pi * np.cumsum(f) / SR
    body = np.sin(ph) * np.exp(-t * (7 / big))
    click = hp(rng.standard_normal(n), 3000) * np.exp(-t * 300) * 0.35
    return np.tanh((body + click) * 1.6) * 0.9


def clap():
    n = int(SR * 0.3)
    t = t_arr(n)
    nz = bp(rng.standard_normal(n), 900, 5000)
    e = np.zeros(n)
    for k, o in enumerate((0, 0.009, 0.018)):
        i = int(o * SR)
        e[i:] += np.exp(-(t[:n - i]) * (160 if k < 2 else 22))
    return nz * e * 0.6


def hat(open_=False):
    n = int(SR * (0.22 if open_ else 0.05))
    t = t_arr(n)
    nz = hp(rng.standard_normal(n), 7000, 4)
    return nz * np.exp(-t * (14 if open_ else 90)) * 0.35


def snare():
    n = int(SR * 0.25)
    t = t_arr(n)
    tone = np.sin(2 * np.pi * 190 * t) * np.exp(-t * 30) * 0.5
    nz = bp(rng.standard_normal(n), 1500, 8000) * np.exp(-t * 18) * 0.6
    return tone + nz


def boom(length=2.5, f0=38):
    n = int(SR * length)
    t = t_arr(n)
    f = f0 + 90 * np.exp(-t * 9)
    ph = 2 * np.pi * np.cumsum(f) / SR
    sub = np.sin(ph) * np.exp(-t * 1.6)
    crack = lp(rng.standard_normal(n), 2500) * np.exp(-t * 7) * 0.5
    return np.tanh((sub + crack) * 1.8)


def crash(length=2.0):
    n = int(SR * length)
    t = t_arr(n)
    nz = hp(rng.standard_normal(n), 4000, 2)
    return nz * np.exp(-t * 2.2) * 0.35


def whoosh(length=0.35, rev=False, lo=300, hi=6000):
    n = int(SR * length)
    t = t_arr(n) / length
    nz = rng.standard_normal(n)
    # barrido de banda por bloques
    out = np.zeros(n)
    blocks = 24
    for b in range(blocks):
        a, z = b * n // blocks, (b + 1) * n // blocks
        fc = lo * (hi / lo) ** (b / blocks)
        out[a:z] = bp(nz[max(0, a - 2000):z], fc * 0.6, min(fc * 1.6, SR / 2 - 100))[-(z - a):]
    e = np.sin(np.pi * t) ** 2
    s = out * e * 0.9
    return s[::-1] if rev else s


def riser(length, lo=200, hi=4000):
    n = int(SR * length)
    t = t_arr(n) / length
    f = lo * (hi / lo) ** (t ** 2)
    ph = 2 * np.pi * np.cumsum(f) / SR
    tone = (2 * ((ph / (2 * np.pi)) % 1) - 1) * 0.15
    nz = hp(rng.standard_normal(n), 1500) * 0.25
    return (lp(tone, 5000) + nz) * t ** 2


def pluck(m, length=0.22, bright=1.0):
    n = int(SR * length)
    f = note(m)
    s = saw(f, n) * 0.5 + saw(f, n, 0.006) * 0.5
    s = lp(s, 1800 + 3500 * bright)
    return s * env(n, 0.002, length * 0.5) * 0.35


def pad(ms, length, bright=2500, attack=0.4):
    n = int(SR * length)
    t = t_arr(n)
    s = np.zeros(n)
    for m in ms:
        for d in (-0.008, -0.003, 0.003, 0.008):
            s += saw(note(m), n, d, rng.random())
    s = lp(s / (len(ms) * 4), bright, 2)
    e = np.minimum(t / attack, 1) * np.minimum((length - t) / 0.3, 1)
    return s * np.clip(e, 0, 1)


def bass_note(m, length):
    n = int(SR * length)
    t = t_arr(n)
    f = note(m)
    s = np.sin(2 * np.pi * f * t) * 0.8 + saw(f, n) * 0.25
    s = lp(s, 700)
    return np.tanh(s * 1.5) * env(n, 0.004, length * 0.9) * 0.55


def bell(m, length=1.2):
    n = int(SR * length)
    t = t_arr(n)
    f = note(m)
    s = np.sin(2 * np.pi * f * t) + 0.4 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t * 3)
    return s * np.exp(-t * 3) * 0.18


def load_sfx(name):
    path = os.path.join(HERE, 'out', 'sfx', name + '.wav')
    with wave.open(path) as w:
        d = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(float) / 32768
        if w.getnchannels() == 2:
            d = d.reshape(-1, 2).mean(axis=1)
    return d


def pitch(sig, ratio):
    idx = np.arange(0, len(sig) - 1, ratio)
    return np.interp(idx, np.arange(len(sig)), sig)


SFX = {k: load_sfx('sfx_' + k) for k in ('coin', 'merge', 'evolution', 'tap', 'buy', 'prestige', 'rare', 'daily', 'event')}

# ───────────────────────── arreglo ─────────────────────────
# progresión Am – F – C – G (un compás = 2 s)
CHORDS = [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]]
ROOTS = [45, 41, 48, 43]


def chord_at(t):
    return int(t // 2.0) % 4


def groove(t0, t1, level=1.0, hats16=False, arp=False, arp_oct=0, bass=True, claps=True):
    b = t0
    while b < t1 - 1e-6:
        beat_i = int(round(b / BEAT))
        place('drums', kick(), b, 0.95 * level)
        if claps and beat_i % 2 == 1:
            place('drums', clap(), b, 0.55 * level, verb=0.25)
        # hats
        place('drums', hat(), b + BEAT / 2, 0.5 * level, pan=0.3)
        if hats16:
            place('drums', hat(), b + BEAT / 4, 0.28 * level, pan=-0.3)
            place('drums', hat(), b + 3 * BEAT / 4, 0.28 * level, pan=-0.3)
        if bass:
            ci = chord_at(b)
            place('bass', bass_note(ROOTS[ci], BEAT / 2 * 0.95), b + BEAT / 2, 1.0 * level)
            place('bass', bass_note(ROOTS[ci] + 12, BEAT / 4 * 0.9), b + BEAT * 0.75, 0.5 * level)
        if arp:
            ci = chord_at(b)
            tones = CHORDS[ci] + [CHORDS[ci][0] + 12]
            for k in range(4):
                m = tones[(beat_i * 4 + k) % 4] + 12 + arp_oct
                place('music', pluck(m, 0.2, 0.8 + 0.2 * arp_oct / 12), b + k * BEAT / 4, 0.55 * level,
                      pan=(-0.4 if k % 2 else 0.4), verb=0.2)
        b += BEAT


# Acto 1 · Hook (0–3)
place('fx', boom(2.8, 34), 0.0, 1.0, verb=0.3)
place('fx', crash(2.5), 0.0, 0.7, verb=0.3)
for k in range(26):
    tt = 0.02 + (k / 26) ** 1.4 * 1.6 + rng.random() * 0.05
    place('sfx', pitch(SFX['coin'], 0.8 + rng.random() * 0.7), tt, 0.35, pan=rng.uniform(-0.8, 0.8), verb=0.2)
place('fx', boom(1.2, 44), 0.8, 0.55)
place('fx', whoosh(0.3), 0.66, 0.5)
place('music', pad([45, 57, 60, 64], 3.0, 900, 0.05), 0.0, 0.9, verb=0.4)
place('drums', kick(1.3), 1.0, 0.8)
place('drums', kick(1.3), 1.5, 0.7)
place('drums', kick(), 2.0, 0.85)
for k in range(8):  # redoble que acelera hacia la mecánica
    place('drums', snare(), 2.0 + k * 0.125, 0.18 + k * 0.05, verb=0.2)
place('fx', riser(1.3, 300, 5000), 1.7, 0.8)
place('fx', whoosh(0.35, lo=500, hi=9000), 2.65, 0.7)

# Acto 2 · Mecánica (3–8)
groove(3.0, 7.9, level=0.9)
for tt in (3.0, 3.25, 3.5, 3.75):
    place('sfx', SFX['tap'], tt, 0.8)
    place('sfx', pitch(SFX['coin'], 0.95 + (tt - 3) * 0.3), tt + 0.02, 0.55, pan=0.3)
MERGES = [(4.0, 4.75), (5.55, 6.25), (6.8, 7.25), (7.45, 7.75)]
for i, (sp, hit) in enumerate(MERGES):
    place('fx', whoosh(0.18), sp, 0.35, pan=-0.5)
    place('fx', whoosh(0.18), sp, 0.35, pan=0.5)
    wl = min(0.45, hit - sp - 0.05)
    place('fx', whoosh(wl, rev=True, lo=400, hi=8000), hit - wl, 0.7)
    place('sfx', pitch(SFX['merge'], 1.0 / (1 + i * 0.12)), hit, 1.0, verb=0.2)
    place('sfx', pitch(SFX['evolution'], 1.0 / (1 + i * 0.1)), hit + 0.03, 0.8, verb=0.3)
    place('fx', boom(1.0, 46), hit, 0.6)
    place('fx', crash(1.2), hit, 0.35)
    for k in range(4):
        place('sfx', pitch(SFX['coin'], 0.9 + rng.random() * 0.6), hit + 0.05 + k * 0.06, 0.3, pan=rng.uniform(-0.7, 0.7))
place('music', pad([57, 60, 64, 69], 3.0, 1800, 0.2), 4.75, 0.45, verb=0.3)
place('fx', riser(0.9, 400, 7000), 7.1, 0.7)
place('fx', whoosh(0.28, lo=300, hi=10000), 7.85, 0.9)

# Acto 3 · Montaje (8–17): todo acelera
groove(8.0, 10.5, level=1.0, hats16=True, arp=True)
MONTAGE_T = [8.0, 8.5, 9.0, 9.5, 10.0, 12.0, 12.5, 12.75, 13.0, 13.25, 13.5, 13.75, 14.0, 14.25, 14.5, 14.75,
             15.0, 15.5, 15.75, 16.0, 16.125, 16.25, 16.375, 16.5, 16.625, 16.75, 16.8125, 16.875, 16.9375]
for k, tt in enumerate(MONTAGE_T):
    place('fx', whoosh(0.16, lo=800, hi=9000), tt - 0.08, 0.35, pan=(-0.5 if k % 2 else 0.5))
    place('sfx', pitch(SFX['coin'], 1.0 / (1 + k * 0.035)), tt, 0.42, pan=(0.4 if k % 2 else -0.4))
    place('drums', kick(0.7), tt, 0.35)
# carrera: stabs
for k, tt in enumerate((10.5, 10.57, 10.64, 10.71)):
    place('sfx', pitch(SFX['tap'], 1 - k * 0.08), tt + 0.02, 0.6)
groove(10.5, 11.5, level=0.8, hats16=False, arp=False, bass=True)
for k, tt in enumerate((10.5, 11.0)):
    place('music', pad(CHORDS[chord_at(tt)], 0.45, 3000, 0.01), tt, 0.7)
place('sfx', SFX['daily'], 11.3, 0.8)
place('fx', riser(0.5, 500, 9000), 11.5, 0.9)
place('fx', whoosh(0.3, rev=True, lo=500, hi=10000), 11.7, 0.8)
place('fx', boom(1.2, 44), 12.0, 0.8)
place('fx', crash(1.5), 12.0, 0.5)
groove(12.0, 15.0, level=1.0, hats16=True, arp=True, arp_oct=0)
place('fx', riser(3.0, 200, 6000), 12.0, 0.45)
place('fx', whoosh(0.3, lo=200, hi=12000), 14.9, 0.9)
place('fx', boom(1.2, 40), 15.0, 0.8)
place('fx', crash(1.5), 15.0, 0.4)
groove(15.0, 17.0, level=1.05, hats16=True, arp=True, arp_oct=12)
for k in range(16):  # redoble a 16avos hacia el silencio
    place('drums', snare(), 16.0 + k * 0.0625, 0.12 + k * 0.03, verb=0.15)
place('fx', riser(2.0, 400, 12000), 15.0, 0.8)

# Acto 4 · Silencio + Dios (17–23)
# 17.0: corte seco. Sólo aire.
wind = lp(rng.standard_normal(int(SR * 1.6)), 500) * 0.25
wind *= np.sin(np.linspace(0, np.pi, len(wind))) ** 2
place('fx', wind, 17.2, 0.22)
place('fx', crash(1.0)[::-1] * np.linspace(0, 1, SR)[:SR], 18.0, 1.0)
place('music', pad([57, 61, 64], 1.0, 1200, 0.9), 18.0, 0.35, verb=0.5)
place('fx', boom(3.5, 30), 19.0, 1.1, verb=0.4)
place('fx', crash(3.0), 19.0, 0.55, verb=0.4)
place('sfx', SFX['prestige'], 19.0, 0.9, verb=0.5)
# coral: acorde mayor abierto, largo
place('music', pad([45, 57, 61, 64, 69, 73], 4.0, 2600, 0.25), 19.0, 0.9, verb=0.6)
for k, m in enumerate((81, 85, 88, 93, 88, 85, 81, 88)):
    place('music', bell(m, 1.4), 19.1 + k * 0.25, 0.8, pan=(-0.5 if k % 2 else 0.5), verb=0.6)
# pulso que vuelve de a poco
for k, tt in enumerate(np.arange(21.0, 23.0, BEAT)):
    place('drums', kick(), tt, 0.45 + k * 0.1)
for k in range(8):
    place('drums', snare(), 22.0 + k * 0.125, 0.1 + k * 0.05, verb=0.2)
place('fx', riser(1.2, 300, 9000), 21.8, 0.9)
place('fx', whoosh(0.4, rev=True, lo=400, hi=12000), 22.6, 0.9)

# Acto 5 · Logo + juego + CTA (23–30)
place('fx', boom(2.0, 36), 23.0, 1.0, verb=0.3)
place('fx', crash(2.0), 23.0, 0.6, verb=0.3)
place('sfx', SFX['rare'], 23.0, 0.8, verb=0.3)
for k in range(10):
    place('sfx', pitch(SFX['coin'], 0.8 + rng.random() * 0.6), 23.05 + k * 0.05, 0.35, pan=rng.uniform(-0.8, 0.8))
groove(23.0, 29.0, level=1.0, hats16=True, arp=True)
place('fx', whoosh(0.3), 24.15, 0.6)
for tt in (24.6, 24.78):
    place('sfx', SFX['tap'], tt, 0.7)
    place('sfx', SFX['coin'], tt + 0.02, 0.45)
place('sfx', SFX['buy'], 24.95, 0.9)
place('fx', whoosh(0.4, lo=300, hi=3000), 25.15, 0.35)
place('sfx', SFX['merge'], 25.6, 1.0)
place('sfx', SFX['evolution'], 25.63, 0.8)
place('sfx', SFX['tap'], 26.05, 0.7)
place('sfx', pitch(SFX['coin'], 0.9), 26.07, 0.5)
place('fx', whoosh(0.3, rev=True), 26.5, 0.7)
place('fx', boom(1.8, 38), 26.8, 0.9, verb=0.3)
place('fx', crash(1.8), 26.8, 0.5)
place('sfx', SFX['event'], 27.2, 0.7)
place('sfx', SFX['daily'], 27.5, 0.8)
# golpe final con acorde que queda sonando
place('fx', boom(1.5, 36), 29.0, 0.9)
place('music', pad([45, 57, 60, 64, 69], 1.0, 3500, 0.01), 29.0, 0.8, verb=0.5)
place('drums', kick(1.5), 29.0, 1.0)
place('fx', crash(1.0), 29.0, 0.5)

# ───────────────────────── mezcla ─────────────────────────
# sidechain: bajo y música respiran con el kick
kick_times = []
tt = 3.0
for a, b in ((3.0, 7.9), (8.0, 11.5), (12.0, 17.0), (21.0, 29.0)):
    kick_times += list(np.arange(a, b, BEAT))
duck = np.ones(N)
for kt in kick_times:
    i = int(kt * SR)
    n = int(0.25 * SR)
    seg_ = 1 - 0.6 * np.exp(-t_arr(n) * 14)
    duck[i:i + n] = np.minimum(duck[i:i + n], seg_[:max(0, min(n, N - i))])
for k in ('bass', 'music'):
    bus[k] *= duck

# reverb: IR de ruido con decaimiento exponencial (estéreo decorrelado)
irn = int(SR * 2.2)
ir_t = t_arr(irn)
ir = [lp(rng.standard_normal(irn), 6000) * np.exp(-ir_t * 3.0) for _ in range(2)]
verb = np.stack([fftconvolve(bus['verb'][c], ir[c])[:N] for c in range(2)]) * 0.12

mix = (bus['drums'] * 0.9 + bus['bass'] * 0.9 + bus['music'] * 0.75 + bus['fx'] * 0.8 + bus['sfx'] * 0.85 + verb)
mix = np.stack([hp(mix[c], 25) for c in range(2)])

# silencio real en 17.0–17.2 (el corte tiene que doler)
i0, i1 = int(17.0 * SR), int(17.2 * SR)
fade = int(0.01 * SR)
mix[:, i0 - fade:i0] *= np.linspace(1, 0, fade)
mix[:, i0:i1] = 0

# master: compresión suave + limitador
peak_target = 0.97
mix /= max(1e-9, np.percentile(np.abs(mix), 99.7))
mix = np.tanh(mix * 0.85)
mix *= peak_target / max(1e-9, np.max(np.abs(mix)))
# fade final corto
fo = int(0.35 * SR)
mix[:, -fo:] *= np.linspace(1, 0, fo) ** 1.5

out = os.path.join(HERE, 'out', 'audio.wav')
pcm = (np.clip(mix.T, -1, 1) * 32767).astype(np.int16)
with wave.open(out, 'wb') as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())
print('ok', out)
