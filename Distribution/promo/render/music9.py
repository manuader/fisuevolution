"""Banda del reel v9 (BOFU «Tu primer minuto»): tic-tac de cronómetro, un
toque por moneda, compra, fusión, ¡NUEVO!, la grilla de siluetas y el
remate de la placa.

    python3 music9.py  →  out/audio_v9.wav  (20 s)
"""
import os
import numpy as np
from synth import *  # noqa: F401,F403

DUR = 20.0
BEAT = 0.5
mixer = Mixer(DUR)
place = mixer.place
S = dict(SFX)
TAPS = [3.3 + k * 0.16 for k in range(25)]
T_HIRE, T_DRAG0, T_NEW, T_GRID, T_CARD = 7.75, 8.25, 9.0, 13.2, 15.6
CH = [[60, 64, 67], [57, 60, 64], [65, 69, 72], [67, 71, 74]]
RT = [48, 45, 53, 55]


def tick(hi=True):
    n = int(SR * 0.04)
    t = t_arr(n)
    return np.sin(2 * np.pi * (2400 if hi else 1800) * t) * np.exp(-t * 140) * 0.5


def groove(t0, t1, level=1.0, arp=True):
    b = t0
    while b < t1 - 1e-6:
        bi = int(round(b / BEAT))
        ci = (bi // 4) % 4
        place('drums', kick(0.85), b, 0.75 * level)
        if bi % 2 == 1:
            place('drums', clap(), b, 0.4 * level, verb=0.2)
        place('drums', hat(), b + BEAT / 2, 0.3 * level, pan=0.3)
        place('bass', bass_note(RT[ci] - 12, BEAT * 0.45), b, 0.8 * level)
        if arp:
            tones = CH[ci] + [CH[ci][0] + 12]
            for k in range(2):
                place('music', pluck(tones[(bi * 2 + k) % 4] + 12, 0.2, 0.8), b + k * BEAT / 2, 0.4 * level, pan=(-0.3 if k else 0.3), verb=0.2)
        b += BEAT


# el cronómetro: tic-tac hasta el ¡NUEVO!
for k in range(int((T_NEW - 0.2) / 0.5)):
    place('fx', tick(k % 2 == 0), 0.2 + k * 0.5, 0.7)
place('music', pad([48, 55, 60, 63], 2.6, 1200, 0.3), 0.0, 0.25, verb=0.3)
place('fx', whoosh(0.6, lo=200, hi=4000), 2.4, 0.5)
groove(3.0, T_NEW, level=0.7, arp=False)
for i, tt in enumerate(TAPS):
    place('sfx', pitch(S['tap'], 1.0 + (i % 4) * 0.03), tt, 0.5)
    place('sfx', pitch(S['coin'], 0.9 + i * 0.012), tt + 0.35, 0.3, pan=-0.2)
place('sfx', S['buy'], T_HIRE, 0.9)
place('fx', whoosh(0.7, lo=400, hi=2500), T_DRAG0, 0.3)
place('sfx', S['merge'], T_NEW, 1.0)
place('sfx', S['evolution'], T_NEW + 0.05, 0.8, verb=0.3)
place('music', sum(bell(m, 1.0) for m in (84, 88, 91)), T_NEW + 0.05, 0.5, verb=0.3)
groove(T_NEW + 0.5, 12.6, level=0.9)
for k in range(8):
    place('sfx', pitch(S['coin'], 1.0), 10.9 + k * 0.2, 0.25)
# la grilla: misterio
place('fx', whoosh(0.6, lo=6000, hi=300), 12.6, 0.5)
place('music', pad([38, 50, 53, 57], 2.6, 900, 0.5), T_GRID, 0.3, verb=0.4)
for k in range(37):
    place('sfx', pitch(S['tap'], 1.3 - k * 0.012), T_GRID + 0.05 + k * 0.022, 0.12)
place('sfx', S['rare'], T_GRID + 1.0, 0.45, verb=0.3)
# placa
place('fx', boom(1.4, 38), T_CARD, 0.5)
for k, tt in enumerate((T_CARD + 0.6, T_CARD + 0.8, T_CARD + 1.0)):
    place('sfx', pitch(S['buy'], 1.0 + k * 0.12), tt, 0.7)
place('sfx', S['daily'], T_CARD + 1.3, 0.7)
groove(T_CARD, 19.7, level=0.85)
kicks = list(np.arange(3.0, T_NEW, BEAT)) + list(np.arange(T_NEW + 0.5, 12.6, BEAT)) + list(np.arange(T_CARD, 19.7, BEAT))
mixer.finish(kicks, os.path.join(HERE, 'out', 'audio_v9.wav'), duck_depth=0.3, verb_gain=0.12)
