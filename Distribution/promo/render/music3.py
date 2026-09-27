"""Banda del reel v3 («TOP 5 demasiado argentino»): cumbia a 100 BPM con
güiro, bajo, órgano y acordeón sintetizados, y los SFX del juego en cada chiste.

    python3 music3.py  →  out/audio_v3.wav  (48 kHz, estéreo, 34 s)
"""
import os
import numpy as np
from synth import *  # noqa: F401,F403

DUR = 34.0
BEAT = 0.6
BAR = BEAT * 4
T0 = 0.42  # la cumbia entra con el sello
mixer = Mixer(DUR)
place = mixer.place
S = dict(SFX)
S['error'] = load_sfx('sfx_error')

# Am – G – F – E (la vuelta andaluza de toda cumbia)
CH = [[57, 60, 64], [55, 59, 62], [53, 57, 60], [52, 56, 59]]
RT = [45, 43, 41, 40]
LEAD = [69, 72, 76, 74, 72, 71, 72, 69, 67, 71, 74, 72, 71, 69, 68, 71]  # 2 compases en corcheas


def guiro(length=0.16, bright=1.0):
    n = int(SR * length)
    t = t_arr(n)
    nz = bp(rng.standard_normal(n), 2500, 8000)
    ridges = 0.55 + 0.45 * np.sign(np.sin(2 * np.pi * 70 * t))
    return nz * ridges * np.minimum(t / 0.01, 1) * np.exp(-t * (8 / length)) * 0.4 * bright


def timbal():
    n = int(SR * 0.25)
    t = t_arr(n)
    f = 330 * (1 + 0.2 * np.exp(-t * 40))
    tone = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 14)
    return (tone * 0.6 + bp(rng.standard_normal(n), 1500, 6000) * np.exp(-t * 30) * 0.3) * 0.6


def organ(ms, length):
    n = int(SR * length)
    t = t_arr(n)
    s = sum(np.sin(2 * np.pi * note(m) * t) + 0.5 * np.sin(2 * np.pi * note(m) * 2 * t) + 0.25 * np.sin(2 * np.pi * note(m) * 3 * t) for m in ms)
    return s / len(ms) * np.minimum(t / 0.005, 1) * np.exp(-t * 18) * 0.35


def accordion(m, length):
    n = int(SR * length)
    t = t_arr(n)
    f = note(m) * (1 + 0.004 * np.sin(2 * np.pi * 6 * t))
    ph = np.cumsum(f) / SR
    s = (2 * (ph % 1) - 1) * 0.5 + (2 * ((ph * 1.004) % 1) - 1) * 0.5 + np.sign(np.sin(2 * np.pi * ph * 2)) * 0.25
    s = lp(s, 2800)
    return s * np.minimum(t / 0.02, 1) * np.minimum((length - t) / 0.03, 1).clip(0, 1) * 0.22


def sad_trombone():
    out = []
    for i, m in enumerate((58, 57, 56, 55)):
        ln = 0.18 if i < 3 else 0.6
        n = int(SR * ln)
        t = t_arr(n)
        f = note(m) * (1 + (0.02 * np.sin(2 * np.pi * 5 * t) if i == 3 else 0))
        s = saw(1, n) * 0  # placeholder de largo
        ph = np.cumsum(np.full(n, f) if np.isscalar(f) else f) / SR
        s = lp(2 * (ph % 1) - 1, 1200) * np.minimum(t / 0.02, 1) * np.minimum((ln - t) / 0.04, 1).clip(0, 1)
        out.append(s * 0.4)
    return np.concatenate(out)


def clank():
    n = int(SR * 0.35)
    t = t_arr(n)
    s = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * d) for f, d in ((2300, 12), (3400, 16), (5100, 20)))
    return (s / 3 + bp(rng.standard_normal(n), 3000, 9000) * np.exp(-t * 40) * 0.5) * 0.5


def shutter():
    n = int(SR * 0.09)
    t = t_arr(n)
    return hp(rng.standard_normal(n), 3000) * (np.exp(-t * 90) + 0.6 * np.exp(-np.maximum(t - 0.045, 0) * 120) * (t > 0.045)) * 0.35


def sizzle(length):
    n = int(SR * length)
    t = t_arr(n)
    crack = (rng.random(n) < 0.004) * rng.uniform(0.3, 1, n)
    return (hp(rng.standard_normal(n), 5000) * 0.12 + bp(crack, 2000, 9000) * 0.8) * np.minimum(t / 0.3, 1) * np.minimum((length - t) / 0.4, 1)


def cumbia(t0, t1, level=1.0, lead=False, keys_=True):
    b = t0
    while b < t1 - 1e-6:
        bi = int(round((b - T0) / BEAT))
        ci = (bi // 4) % 4
        # güiro: largo-corto-corto
        place('drums', guiro(0.2), b, 0.55 * level, pan=0.35)
        place('drums', guiro(0.06), b + BEAT * 0.5, 0.45 * level, pan=0.35)
        place('drums', guiro(0.06), b + BEAT * 0.75, 0.4 * level, pan=0.35)
        if bi % 2 == 0:
            place('drums', kick(0.8), b, 0.75 * level)
        else:
            place('drums', timbal(), b + BEAT * 0.5, 0.5 * level, pan=-0.3)
        m = RT[ci] if bi % 2 == 0 else RT[ci] + 7
        place('bass', bass_note(m, BEAT * 0.7), b, 1.0 * level)
        if keys_:
            place('music', organ(CH[ci], BEAT * 0.3), b + BEAT * 0.5, 0.8 * level, pan=-0.2)
        if lead:
            for k in range(2):
                idx = (bi * 2 + k) % len(LEAD)
                place('music', accordion(LEAD[idx], BEAT * 0.48), b + k * BEAT / 2, 0.8 * level, pan=0.15, verb=0.2)
        b += BEAT


# ── hook ──
for k in range(6):
    place('sfx', pitch(S['coin'], 1.2 + k * 0.08), 0.02 + k * 0.06, 0.3, pan=rng.uniform(-0.5, 0.5))
place('fx', whoosh(0.35, rev=True, lo=400, hi=9000), 0.07, 0.6)
place('fx', boom(1.6, 40), 0.42, 0.9)
place('drums', clap(), 0.42, 0.8, verb=0.3)
place('sfx', S['error'], 0.42, 0.9)
for k in range(8):
    place('sfx', pitch(S['coin'], 1.0 - k * 0.06), 0.47 + k * 0.05, 0.3)
cumbia(T0 + BEAT * 1, T0 + BEAT * 13, level=0.85, keys_=True)
cumbia(T0 + BEAT * 13, 22.9, level=0.9, lead=True)
place('fx', whoosh(0.3), 2.55, 0.6)

# ── #5 la economía ──
place('fx', boom(0.8, 50), 2.75, 0.5)
place('sfx', S['error'], 3.2, 0.8)
place('fx', clank(), 3.28, 0.9)
place('fx', clank(), 3.4, 0.6)
for tt in (3.55, 3.85, 4.1, 4.3):
    place('sfx', S['tap'], tt, 0.7)
    place('sfx', pitch(S['error'], 1.3), tt + 0.03, 0.35)
place('sfx', S['event'], 4.9, 0.8)
place('sfx', S['tap'], 5.45, 0.5)
place('sfx', pitch(S['buy'], 0.7), 5.6, 0.8)
place('sfx', S['rare'], 6.5, 0.8)
for k in range(18):
    place('sfx', pitch(S['coin'], 0.8 + rng.random() * 0.7), 6.6 + k * 0.05, 0.3, pan=rng.uniform(-0.8, 0.8))
place('fx', whoosh(0.35, lo=6000, hi=150), 7.72, 0.7)
place('music', sad_trombone(), 7.8, 0.9)

# ── #4 especiales ──
place('fx', whoosh(0.3), 8.05, 0.6)
place('fx', boom(0.8, 50), 8.25, 0.5)
for tt in (9.3, 10.75, 12.15):
    place('fx', whoosh(0.25, lo=800, hi=6000), tt - 0.05, 0.5)
    place('sfx', S['rare'], tt + 0.15, 0.7, verb=0.3)
for tt in (9.65, 12.5):
    place('sfx', pitch(S['tap'], 1.2), tt, 0.6)

# ── #3 bonus ──
place('fx', whoosh(0.3), 13.45, 0.6)
place('fx', boom(0.8, 50), 13.65, 0.5)
for tt in (13.9, 15.5, 17.1):
    place('sfx', S['buy'], tt, 0.8)
    place('music', bell(84, 0.8), tt + 0.05, 0.5, verb=0.3)
place('fx', sizzle(1.5), 15.5, 0.7)

# ── #2 pintas ──
place('fx', whoosh(0.3), 18.65, 0.6)
place('fx', boom(0.8, 50), 18.85, 0.5)
r = np.random.default_rng(3)
for i, t0 in enumerate((19.3, 20.5, 21.7, 22.9)):
    place('fx', whoosh(0.4, lo=300, hi=2500), t0, 0.25)
    for k in range(4):
        place('fx', shutter(), t0 + 0.5 + r.random() * 0.6, 0.8, pan=r.uniform(-0.7, 0.7))
place('fx', crash(1.6), 23.4, 0.5)
cumbia(T0 + BEAT * 38, 24.5, level=0.95, lead=True)
for k in range(10):
    place('sfx', pitch(S['coin'], 0.9 + rng.random() * 0.4), 23.4 + k * 0.05, 0.25)

# ── #1 ──
for k in range(28):  # redoble
    place('drums', snare(), 24.62 + k * 0.034, 0.06 + k * 0.007, verb=0.1)
place('fx', boom(2.4, 32), 25.6, 0.45, verb=0.15)
place('sfx', S['prestige'], 25.62, 0.5, verb=0.25)
place('music', pad([57, 61, 64, 69, 73], 3.3, 2600, 0.3), 25.6, 0.25, verb=0.25)
place('music', bell(88, 1.2), 27.0, 0.7, verb=0.4)
place('fx', whoosh(0.4), 27.95, 0.6)
place('fx', sizzle(2.4), 28.0, 0.5)
place('fx', boom(1.8, 36), 29.0, 0.5)
place('fx', crash(2.0), 29.0, 0.5)
cumbia(29.0, 33.6, level=1.0, lead=True)
place('sfx', S['daily'], 31.4, 0.6)

kicks = [T0 + BEAT * k for k in range(1, 200) if T0 + BEAT * k < 24.5 and k % 2 == 1] + \
        [29.0 + BEAT * k for k in range(0, 8, 2)]
mixer.finish(kicks, os.path.join(HERE, 'out', 'audio_v3.wav'), duck_depth=0.3, verb_gain=0.12)
