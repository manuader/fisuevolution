"""Banda sonora del reel v2 («¿Qué hay en el último piso?»): 100 BPM, más
cálida y fluida que la v1. Intro de misterio, groove que crece con cada
sistema del juego, quiebre y drop en la reencarnación, y vuelta al misterio.
Cada toque, compra, fusión y popup de scene2.js tiene su SFX real del juego.

    python3 music2.py  →  out/audio_v2.wav  (48 kHz, estéreo, 45 s)
"""
import os
import numpy as np
from synth import *  # noqa: F401,F403

DUR = 45.0
BEAT = 0.6  # 100 BPM
BAR = BEAT * 4
mixer = Mixer(DUR)
place = mixer.place

SFX2 = dict(SFX)
for k in ('chest_shake_a', 'chest_shake_b', 'error'):
    SFX2[k] = load_sfx('sfx_' + k)

# Dm – B♭ – F – C
CHORDS = [[50, 53, 57], [46, 50, 53], [53, 57, 60], [48, 52, 55]]
ROOTS = [38, 34, 41, 36]


def chord_at(t):
    return int(t // BAR) % 4


def rim():
    n = int(SR * 0.08)
    t = t_arr(n)
    return (np.sin(2 * np.pi * 1700 * t) * 0.4 + bp(rng.standard_normal(n), 2000, 6000) * 0.6) * np.exp(-t * 70) * 0.5


def keys(ms, length, bright=2200):
    """Acorde tipo Rhodes: senos con leve trémolo, suave."""
    n = int(SR * length)
    t = t_arr(n)
    s = np.zeros(n)
    for m in ms:
        f = note(m)
        s += np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * f * 2 * t) * np.exp(-t * 4)
    s *= (1 + 0.15 * np.sin(2 * np.pi * 4.5 * t))
    s = lp(s / len(ms), bright)
    return s * np.minimum(t / 0.01, 1) * np.exp(-t * 1.1) * 0.35


def groove(t0, t1, level=1.0, hats16=False, arp=False, arp_oct=0, bass=True, clap_=True, keys_=True):
    b = t0
    while b < t1 - 1e-6:
        bi = int(round(b / BEAT))
        place('drums', kick(0.9), b, 0.8 * level)
        if clap_ and bi % 2 == 1:
            place('drums', clap(), b, 0.42 * level, verb=0.3)
            place('drums', rim(), b + BEAT * 0.75, 0.25 * level, pan=-0.3)
        # hats con swing
        place('drums', hat(), b + BEAT * 0.56, 0.42 * level, pan=0.3)
        if hats16:
            place('drums', hat(), b + BEAT * 0.27, 0.2 * level, pan=-0.3)
            place('drums', hat(), b + BEAT * 0.8, 0.2 * level, pan=-0.3)
        ci = chord_at(b)
        if bass:
            place('bass', bass_note(ROOTS[ci], BEAT * 0.45), b + BEAT * 0.5, 0.95 * level)
            if bi % 2 == 0:
                place('bass', bass_note(ROOTS[ci] + 12, BEAT * 0.2), b + BEAT * 0.78, 0.4 * level)
        if keys_ and bi % 4 == 0:
            place('music', keys(CHORDS[ci] + [CHORDS[ci][0] + 12], BAR * 0.95), b, 0.7 * level, verb=0.35)
        if arp:
            tones = CHORDS[ci] + [CHORDS[ci][0] + 12]
            for k in range(2):
                m = tones[(bi * 2 + k) % 4] + 12 + arp_oct
                place('music', pluck(m, 0.24, 0.6), b + k * BEAT / 2, 0.4 * level, pan=(-0.35 if k else 0.35), verb=0.3)
        b += BEAT


def ticks(t0, t1, gain=0.3):
    b = t0
    while b < t1:
        place('drums', rim(), b, gain, pan=0.2)
        b += BEAT


# ── 0–5,4: el misterio de la torre ──
place('music', pad([38, 50, 53, 57], 5.6, 700, 1.2), 0.0, 0.3, verb=0.3)
place('fx', boom(3.0, 30), 0.0, 0.35, verb=0.2)
ticks(0.6, 5.2, 0.18)
for k, (m, tt) in enumerate(((74, 0.6), (77, 1.2), (81, 1.8), (76, 3.0), (74, 3.6), (69, 4.2))):
    place('music', bell(m, 1.6), tt, 0.55, pan=(-0.4 if k % 2 else 0.4), verb=0.6)
place('fx', whoosh(1.8, lo=150, hi=1800), 2.0, 0.35)  # bajada por la torre
place('fx', riser(1.0, 200, 5000), 4.4, 0.6)
place('fx', whoosh(0.5, rev=True, lo=300, hi=9000), 4.9, 0.6)

# ── 5,4–13: arranca la partida ──
place('fx', boom(1.2, 44), 5.4, 0.5)
groove(5.4, 13.2, level=0.8, keys_=True)
TAPS = [6.4, 6.85, 7.25, 7.55, 7.8, 8.0, 8.2]
for i, tt in enumerate(TAPS):
    place('sfx', SFX2['tap'], tt, 0.75)
    place('sfx', pitch(SFX2['coin'], 0.9 + i * 0.04), tt + 0.5, 0.45, pan=-0.2)
place('sfx', SFX2['tap'], 8.55, 0.8)
place('sfx', SFX2['rare'], 8.57, 0.7, verb=0.3)
for k in range(5):
    place('sfx', pitch(SFX2['coin'], 0.8 + rng.random() * 0.5), 8.6 + k * 0.05, 0.3, pan=rng.uniform(-0.6, 0.6))
place('sfx', SFX2['tap'], 9.55, 0.7)
place('sfx', SFX2['buy'], 9.57, 0.9)
place('fx', whoosh(0.28, lo=2000, hi=300), 9.85, 0.4)
place('drums', kick(0.5), 10.13, 0.5)
place('fx', whoosh(0.8, lo=400, hi=2500), 10.35, 0.3)
place('fx', whoosh(0.35, rev=True, lo=500, hi=8000), 10.85, 0.5)
place('sfx', SFX2['merge'], 11.15, 1.0, verb=0.2)
place('fx', boom(1.0, 48), 11.2, 0.45)
place('sfx', SFX2['evolution'], 11.45, 0.9, verb=0.4)
for k, m in enumerate((81, 86, 89, 93)):
    place('music', bell(m, 1.2), 11.5 + k * 0.12, 0.6, verb=0.5)

# ── 13–25: la partida crece ──
groove(13.2, 25.3, level=0.95, hats16=True, arp=True)
for k, tt in enumerate((13.05, 13.2, 13.35, 13.5, 13.65, 13.8, 13.95)):
    place('sfx', pitch(SFX2['tap'], 1.0 - k * 0.05), tt, 0.5, pan=(-0.4 if k % 2 else 0.4))
for k in range(12):
    place('sfx', pitch(SFX2['coin'], 0.95 + rng.random() * 0.3), 13.3 + k * 0.11, 0.18, pan=rng.uniform(-0.7, 0.7))
place('fx', whoosh(0.55, lo=400, hi=2500), 14.45, 0.3)
place('sfx', SFX2['merge'], 15.0, 0.9)
place('sfx', SFX2['evolution'], 15.05, 0.7, verb=0.3)
place('fx', whoosh(0.5, lo=300, hi=9000), 15.45, 0.6)
place('sfx', SFX2['event'], 15.6, 0.8)
place('sfx', SFX2['tap'], 16.2, 0.7)
place('fx', whoosh(0.7, lo=200, hi=4000), 16.3, 0.55)
place('music', bell(84, 1.0), 16.95, 0.7, verb=0.4)  # ding del ascensor
place('music', bell(88, 1.0), 17.05, 0.5, verb=0.4)
place('sfx', SFX2['daily'], 17.0, 0.6)
for k in range(4):
    place('sfx', pitch(SFX2['tap'], 1.1 + k * 0.06), 17.2 + k * 0.12, 0.35)
place('sfx', SFX2['tap'], 18.9, 0.7)
place('sfx', SFX2['buy'], 18.93, 0.8)
place('sfx', SFX2['tap'], 19.95, 0.6)
place('fx', whoosh(0.6, lo=4000, hi=200), 20.0, 0.5)
place('sfx', SFX2['tap'], 20.75, 0.6)
place('fx', whoosh(0.3, lo=500, hi=4000), 20.85, 0.35)
for k in range(5):
    place('sfx', pitch(SFX2['tap'], 1.15 + k * 0.05), 21.0 + k * 0.08, 0.3)
place('sfx', SFX2['tap'], 21.75, 0.6)
place('sfx', SFX2['buy'], 21.78, 0.8)
place('music', bell(86, 1.0), 21.8, 0.5, verb=0.4)
place('sfx', SFX2['tap'], 22.95, 0.6)
place('sfx', SFX2['tap'], 23.25, 0.6)
place('sfx', SFX2['chest_shake_a'], 23.3, 0.9)
place('sfx', SFX2['chest_shake_b'], 23.65, 0.9)
place('fx', riser(0.7, 400, 8000), 23.35, 0.5)
place('sfx', SFX2['rare'], 24.05, 0.9, verb=0.4)
place('fx', crash(1.4), 24.05, 0.4)
place('sfx', SFX2['tap'], 24.75, 0.6)

# ── 25–33: economía, especiales, mejoras ──
groove(25.3, 33.3, level=1.0, hats16=True, arp=True, arp_oct=12)
place('sfx', SFX2['event'], 25.3, 0.9)
for k in range(22):
    place('sfx', pitch(SFX2['coin'], 0.8 + rng.random() * 0.7), 25.4 + k * 0.065, 0.28, pan=rng.uniform(-0.8, 0.8))
place('sfx', SFX2['error'], 26.95, 0.8)
place('sfx', SFX2['rare'], 27.65, 0.8, verb=0.3)
place('sfx', SFX2['tap'], 28.55, 0.6)
place('sfx', SFX2['buy'], 28.58, 0.8)
place('sfx', SFX2['tap'], 29.35, 0.6)
place('fx', whoosh(0.3, lo=500, hi=4000), 29.45, 0.35)
for k, tt in enumerate((30.1, 30.5, 30.9)):
    place('sfx', SFX2['tap'], tt, 0.55)
    place('sfx', pitch(SFX2['buy'], 1.0 / (1 + k * 0.12)), tt + 0.02, 0.8)
place('sfx', SFX2['daily'], 31.75, 0.7)
place('sfx', SFX2['tap'], 32.6, 0.6)
for k in range(10):
    place('sfx', pitch(SFX2['coin'], 0.85 + rng.random() * 0.5), 32.62 + k * 0.045, 0.3, pan=rng.uniform(-0.6, 0.6))

# ── 33–38: reencarnar ──
place('music', pad([50, 57, 60, 65], 2.2, 1500, 0.4), 33.1, 0.35, verb=0.3)
place('sfx', SFX2['event'], 33.0, 0.6)
place('sfx', SFX2['tap'], 33.5, 0.6)
place('fx', riser(1.6, 200, 6000), 33.5, 0.55)
place('sfx', SFX2['tap'], 34.95, 0.7)
place('sfx', SFX2['prestige'], 35.1, 0.8, verb=0.3)
place('fx', crash(1.2)[::-1] * np.linspace(0, 1, int(SR * 1.2)), 34.95, 0.5)
place('fx', whoosh(1.0, lo=200, hi=12000), 35.1, 0.45)
place('music', pad([38, 50, 57, 62, 65, 69], 3.0, 3000, 0.3), 35.1, 0.55, verb=0.4)
place('fx', boom(2.4, 34), 36.1, 0.5, verb=0.2)
place('fx', crash(2.0), 36.1, 0.3, verb=0.2)
for k, m in enumerate((74, 77, 81, 86, 89)):
    place('music', bell(m, 1.3), 36.15 + k * 0.1, 0.6, verb=0.5)
groove(36.0, 38.4, level=1.05, hats16=True, arp=True, arp_oct=12)
for i, tt in enumerate((36.55, 36.8, 37.05, 37.3, 37.55)):
    place('sfx', SFX2['tap'], tt, 0.6)
    place('sfx', pitch(SFX2['coin'], 0.9 + i * 0.06), tt + 0.5, 0.4)
for k, tt in enumerate((36.95, 37.35, 37.75)):
    place('sfx', pitch(SFX2['tap'], 1.0 - k * 0.05), tt, 0.4)

# ── 38–42: vuelve el misterio ──
place('fx', whoosh(0.9, lo=6000, hi=200), 38.0, 0.6)
place('music', pad([38, 50, 53, 57], 4.4, 900, 0.6), 38.2, 0.3, verb=0.3)
ticks(38.4, 41.4, 0.16)
for k, (m, tt) in enumerate(((74, 39.0), (77, 39.6), (81, 40.2), (76, 40.8), (86, 41.4))):
    place('music', bell(m, 1.6), tt, 0.55, pan=(-0.4 if k % 2 else 0.4), verb=0.6)
place('fx', riser(1.2, 300, 9000), 41.0, 0.8)

# ── 42–45: descarga ──
place('fx', boom(2.2, 36), 42.2, 0.5, verb=0.2)
place('fx', crash(2.0), 42.2, 0.3, verb=0.2)
place('sfx', SFX2['prestige'], 42.2, 0.5, verb=0.2)
groove(42.2, 44.6, level=0.85, hats16=False, arp=True)
place('sfx', SFX2['daily'], 43.2, 0.7)
place('music', keys([50, 53, 57, 62], 1.6), 44.4, 0.8, verb=0.6)

kick_times = []
for a, b in ((5.4, 13.2), (13.2, 25.3), (25.3, 33.3), (36.0, 38.4), (42.2, 44.6)):
    kick_times += list(np.arange(a, b, BEAT))
mixer.finish(kick_times, os.path.join(HERE, 'out', 'audio_v2.wav'), duck_depth=0.45, verb_gain=0.14)
