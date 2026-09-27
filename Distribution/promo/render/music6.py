"""Sting de la placa BOFU (4,5 s): golpe, monedas y un remate de metales.

    python3 music6.py  →  out/audio_v6.wav
"""
import os
import numpy as np
from synth import *  # noqa: F401,F403

mixer = Mixer(4.5)
place = mixer.place
S = dict(SFX)


def brass(ms, length):
    n = int(SR * length)
    t = t_arr(n)
    s = sum(saw(note(m), n) + saw(note(m), n, 0.005) for m in ms)
    return lp(s / (2 * len(ms)), 2800) * np.minimum(t / 0.015, 1) * np.exp(-t * 2.2) * 0.5


place('fx', boom(1.5, 40), 0.0, 0.6)
place('music', brass([72, 76, 79], 0.4), 0.0, 0.8, verb=0.3)
place('sfx', S['rare'], 0.3, 0.7, verb=0.3)
for k in range(10):
    place('sfx', pitch(S['coin'], 0.8 + rng.random() * 0.7), 0.32 + k * 0.05, 0.3, pan=rng.uniform(-0.7, 0.7))
for k, tt in enumerate((0.7, 0.95, 1.2)):
    place('sfx', pitch(S['buy'], 1.0 + k * 0.12), tt, 0.7)
place('sfx', S['event'], 1.6, 0.6)
place('sfx', S['daily'], 2.0, 0.7)
place('music', brass([67, 72, 76, 79, 84], 1.8), 2.4, 0.8, verb=0.4)
for k in range(4):
    place('drums', kick(0.9), 2.4 + k * 0.5, 0.6)
    place('drums', clap(), 2.65 + k * 0.5, 0.35)
mixer.finish([], os.path.join(HERE, 'out', 'audio_v6.wav'))
