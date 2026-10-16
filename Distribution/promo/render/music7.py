"""Banda del reel v7 (TOFU «Pausá y descubrí qué fisura sos»): groove
juguetón de 100 BPM con un tic en cada carta de la ruleta, freno, y coro en
el giro de la carta dorada.

    python3 music7.py  →  out/audio_v7.wav  (22 s)
"""
import os
import numpy as np
from synth import *  # noqa: F401,F403

DUR = 22.0
BEAT = 0.6
mixer = Mixer(DUR)
place = mixer.place
S = dict(SFX)
REEL0, REEL1, STEP, HOLD = 3.0, 13.0, 0.45, 0.35
CH = [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]]
RT = [45, 41, 48, 43]


def tick():
    n = int(SR * 0.04)
    t = t_arr(n)
    return (np.sin(2 * np.pi * 2600 * t) * np.exp(-t * 150) * 0.6 + bp(rng.standard_normal(n), 3000, 9000) * np.exp(-t * 250) * 0.3)


def marimba(m, length=0.3):
    n = int(SR * length)
    t = t_arr(n)
    f = note(m)
    return (np.sin(2 * np.pi * f * t) + 0.3 * np.sin(2 * np.pi * f * 4 * t) * np.exp(-t * 30)) * np.exp(-t * 9) * 0.35


def groove(t0, t1, level=1.0):
    b = t0
    while b < t1 - 1e-6:
        bi = int(round(b / BEAT))
        ci = (bi // 4) % 4
        place('drums', kick(0.8), b, 0.7 * level)
        if bi % 2 == 1:
            place('drums', clap(), b, 0.4 * level, verb=0.2)
        place('drums', hat(), b + BEAT / 2, 0.3 * level, pan=0.3)
        place('bass', bass_note(RT[ci], BEAT * 0.45), b, 0.8 * level)
        tones = CH[ci] + [CH[ci][0] + 12]
        for k in range(2):
            place('music', marimba(tones[(bi * 2 + k) % 4] + 12), b + k * BEAT / 2, 0.6 * level, pan=(-0.3 if k else 0.3), verb=0.2)
        b += BEAT


# hook: suspenso liviano
place('music', pad([45, 57, 60, 64], 3.0, 1200, 0.4), 0.0, 0.3, verb=0.3)
place('fx', boom(0.8, 48), 0.0, 0.35)
for tt in (1.4, 2.2):
    place('sfx', S['tap'], tt, 0.8)
place('fx', whoosh(0.35, rev=True, lo=400, hi=8000), 2.65, 0.6)
# ruleta
groove(REEL0, REEL1, level=0.85)
k = 0
while REEL0 + k * STEP < REEL1:
    place('fx', tick(), REEL0 + k * STEP + HOLD, 0.8, pan=0.1)
    k += 1
for tt in (6.0, 10.0):
    place('sfx', S['event'], tt, 0.5)
place('fx', whoosh(0.5, lo=3000, hi=300), REEL1 - 0.5, 0.4)
place('music', chime := sum(bell(m, 1.0) for m in (84, 88, 91)), REEL1, 0.6, verb=0.3)
place('sfx', pitch(S['tap'], 0.9), REEL1 + 0.1, 0.6)
# giro
place('music', pad([38, 50, 57, 62], 4.0, 900, 0.8), 14.5, 0.3, verb=0.4)
for i in range(4):
    place('drums', kick(1.3), 14.7 + i * 0.6, 0.35 + i * 0.08)
place('fx', riser(1.0, 300, 8000), 15.8, 0.4)
place('fx', boom(1.8, 34), 16.9, 0.28, verb=0.1)
place('sfx', S['prestige'], 16.95, 0.3, verb=0.15)
place('music', pad([45, 57, 61, 64, 69], 1.6, 2600, 0.3), 16.95, 0.14, verb=0.2)
# "¿Quién es?" → "¿El Pepe?": scratch de disco y remate
def scratch():
    n = int(SR * 0.35)
    tt = t_arr(n)
    f = 1800 * np.exp(-tt * 9) + 150
    return bp(rng.standard_normal(n), 300, 5000) * np.abs(np.sin(2 * np.pi * np.cumsum(f) / SR)) * np.exp(-tt * 5) * 0.8


place('sfx', S['tap'], 15.65, 0.6)
place('fx', scratch(), 16.2, 0.8)
# CTA
place('fx', boom(1.4, 38), 18.5, 0.45)
groove(18.5, 21.6, level=0.85)
kicks = list(np.arange(REEL0, REEL1, BEAT)) + list(np.arange(18.5, 21.6, BEAT))
mixer.finish(kicks, os.path.join(HERE, 'out', 'audio_v7.wav'), duck_depth=0.3, verb_gain=0.12)
