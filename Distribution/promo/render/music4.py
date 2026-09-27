"""Banda del reel v4 («DÍA 1 → DÍA 365»): lofi de vlog a 90 BPM, vinilo,
Rhodes y batería con swing; pop en cada globo, ding en cada logro, glitch
antes del día 365 y un drone de misterio para la silueta.

    python3 music4.py  →  out/audio_v4.wav  (48 kHz, estéreo, 35 s)
"""
import os
import numpy as np
from synth import *  # noqa: F401,F403

DUR = 35.0
BEAT = 60 / 90
BAR = BEAT * 4
mixer = Mixer(DUR)
place = mixer.place
S = dict(SFX)

# Fmaj7 – Em7 – Dm7 – Cmaj7 (bajada lofi)
CH = [[53, 57, 60, 64], [52, 55, 59, 62], [50, 53, 57, 60], [48, 52, 55, 59]]
RT = [41, 40, 38, 36]
DAYS_T = [3.2, 6.2, 10.2, 13.6, 18.4, 22.0]
BUBBLES = [2.05, 3.5, 4.85, 7.3, 10.55, 11.8, 14.2, 16.0, 18.8, 19.95, 22.35, 23.45]
ACH = [4.3, 8.4, 12.0, 16.4, 20.2, 23.6]


def rhodes(ms, length):
    n = int(SR * length)
    t = t_arr(n)
    s = np.zeros(n)
    for m in ms:
        f = note(m)
        s += np.sin(2 * np.pi * f * t + 0.6 * np.sin(2 * np.pi * f * t) * np.exp(-t * 6))
    s *= 1 + 0.12 * np.sin(2 * np.pi * 4 * t)
    return lp(s / len(ms), 1800) * np.minimum(t / 0.01, 1) * np.exp(-t * 0.8) * 0.35


def dusty_kick():
    return lp(kick(1.0), 3000) * 0.9


def dusty_snare():
    return lp(snare(), 5000) * 0.7


def crackle(length):
    n = int(SR * length)
    pops = (rng.random(n) < 0.0015) * rng.uniform(0.2, 1, n)
    return hp(pops, 1500) * 0.25 + lp(rng.standard_normal(n), 900) * 0.012


def pop():
    n = int(SR * 0.08)
    t = t_arr(n)
    f = 900 * np.exp(-t * 25) + 300
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 45) * 0.5


def page_flip():
    n = int(SR * 0.22)
    t = t_arr(n)
    return bp(rng.standard_normal(n), 1500, 7000) * np.sin(np.pi * t / t[-1]) ** 2 * (1 + np.sign(np.sin(2 * np.pi * 40 * t))) * 0.25


def glitch(length):
    n = int(SR * length)
    out = np.zeros(n)
    i = 0
    while i < n:
        ln = int(SR * rng.uniform(0.02, 0.08))
        kind = rng.integers(0, 3)
        tt = t_arr(ln)
        if kind == 0:
            seg_ = np.sign(np.sin(2 * np.pi * rng.uniform(80, 1200) * tt)) * 0.3
        elif kind == 1:
            seg_ = rng.standard_normal(ln) * 0.35
        else:
            seg_ = np.zeros(ln)
        out[i:i + ln] = seg_[:max(0, min(ln, n - i))]
        i += ln
    return out


def lofi(t0, t1, level=1.0, drums=True):
    b = t0
    while b < t1 - 1e-6:
        bi = int(round(b / BEAT))
        ci = (bi // 4) % 4
        if drums:
            if bi % 4 in (0, 2) or (bi % 4 == 3):
                place('drums', dusty_kick(), b + (BEAT * 0.5 if bi % 4 == 3 else 0), 0.8 * level)
            if bi % 2 == 1:
                place('drums', dusty_snare(), b + 0.02, 0.55 * level, verb=0.2)
            for k in range(2):
                place('drums', hat(), b + k * BEAT * 0.58, 0.28 * level, pan=0.3)
        if bi % 4 == 0:
            place('music', rhodes(CH[ci], BAR), b, 0.9 * level, verb=0.3)
            place('bass', bass_note(RT[ci], BEAT * 1.6), b, 0.9 * level)
            place('bass', bass_note(RT[ci] + 7, BEAT * 0.8), b + BEAT * 2.5, 0.6 * level)
        b += BEAT


place('fx', crackle(DUR), 0.0, 1.0)
lofi(0.0, 25.2, level=0.9)
place('fx', boom(0.8, 50), 0.0, 0.35)
for tt in DAYS_T:
    place('fx', whoosh(0.25, lo=600, hi=8000), tt - 0.15, 0.55)
    place('fx', page_flip(), tt - 0.05, 0.6)
for tt in BUBBLES:
    place('sfx', pop(), tt, 0.7)
for tt in ACH:
    place('sfx', S['daily'], tt, 0.7)
    place('music', bell(88, 0.8), tt + 0.05, 0.35, verb=0.3)
# glitch
place('fx', glitch(1.2), 25.2, 0.3)
place('fx', riser(1.1, 300, 9000), 25.25, 0.35)
# día 365: drone y latido
place('music', pad([38, 45, 50, 53], 4.4, 700, 0.8), 26.4, 0.22, verb=0.25)
place('fx', boom(2.5, 30), 26.4, 0.3, verb=0.15)
for k in range(5):
    place('drums', kick(1.4), 26.9 + k * 0.8, 0.45)
    place('drums', kick(1.4), 27.1 + k * 0.8, 0.3)
place('sfx', pop(), 26.9, 0.6)
place('fx', boom(1.2, 40), 28.0, 0.5)
place('sfx', S['rare'], 28.7, 0.6)
place('fx', whoosh(0.4, rev=True), 30.2, 0.6)
# CTA
place('fx', boom(1.5, 36), 30.6, 0.5)
place('sfx', S['prestige'], 30.6, 0.45, verb=0.3)
lofi(30.6, 34.7, level=0.9)

kicks = [b for b in np.arange(0, 25.2, BEAT)] + [b for b in np.arange(30.6, 34.7, BEAT)]
mixer.finish(kicks, os.path.join(HERE, 'out', 'audio_v4.wav'), duck_depth=0.35, verb_gain=0.14)
