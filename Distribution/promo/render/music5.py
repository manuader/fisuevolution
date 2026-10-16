"""Banda del reel v5 («QUIZ: ¿en qué se convierte?»): música de programa de
TV a 120 BPM, tic-tac del reloj, redoble antes de cada respuesta, campanita
de acierto con aplausos, y apagón con silencio en la pregunta final.

    python3 music5.py  →  out/audio_v5.wav  (48 kHz, estéreo, 33 s)
"""
import os
import numpy as np
from synth import *  # noqa: F401,F403

DUR = 33.0
BEAT = 0.5
mixer = Mixer(DUR)
place = mixer.place
S = dict(SFX)
ROUNDS = [2.5, 8.5, 14.5]
FINAL, BLACKOUT, CTA = 20.5, 25.1, 29.0
TICK = 0.8

CH = [[60, 64, 67], [65, 69, 72], [67, 71, 74], [65, 69, 72]]  # C – F – G – F
RT = [48, 53, 55, 53]


def brass(ms, length=0.22):
    n = int(SR * length)
    t = t_arr(n)
    s = np.zeros(n)
    for m in ms:
        f = note(m)
        s += saw(f, n) + saw(f, n, 0.005)
    env_ = np.minimum(t / 0.015, 1) * np.exp(-t * 7)
    return lp(s / (2 * len(ms)), 2600) * env_ * 0.5


def tick(hi=True):
    n = int(SR * 0.05)
    t = t_arr(n)
    return np.sin(2 * np.pi * (2200 if hi else 1600) * t) * np.exp(-t * 120) * 0.5 + bp(rng.standard_normal(n), 3000, 9000) * np.exp(-t * 200) * 0.3


def chime():
    return sum(bell(m, 1.0) for m in (84, 88, 91)) * 1.2


def applause(length=1.6):
    n = int(SR * length)
    out = np.zeros(n)
    for _ in range(int(length * 90)):
        i = int(rng.random() * (n - 2000))
        c = clap()[:1800] * rng.uniform(0.2, 0.6)
        out[i:i + len(c)] += c
    t = t_arr(n)
    return out * np.minimum(t / 0.1, 1) * np.minimum((length - t) / 0.5, 1).clip(0, 1) * 0.6


def show(t0, t1, level=1.0):
    b = t0
    while b < t1 - 1e-6:
        bi = int(round(b / BEAT))
        ci = (bi // 4) % 4
        place('drums', kick(0.8), b, 0.8 * level)
        if bi % 2 == 1:
            place('drums', snare(), b, 0.45 * level, verb=0.2)
        place('drums', hat(), b + BEAT / 2, 0.35 * level, pan=0.3)
        place('bass', bass_note(RT[ci] - 12, BEAT * 0.4), b, 0.9 * level)
        place('bass', bass_note(RT[ci], BEAT * 0.3), b + BEAT * 0.5, 0.6 * level)
        if bi % 4 in (0, 3):
            place('music', brass([m + 12 for m in CH[ci]]), b + (BEAT * 0.5 if bi % 4 == 3 else 0), 0.7 * level, verb=0.2)
        b += BEAT


# hook + rondas: la música baja mientras corre el reloj
place('fx', boom(1.2, 44), 0.0, 0.5)
place('music', brass([72, 76, 79], 0.5), 0.0, 0.9, verb=0.3)
show(0.0, 2.5, level=0.8)
place('fx', whoosh(0.3, rev=True), 1.6, 0.5)
place('music', brass([67, 72, 76, 79], 0.6), 1.95, 0.9, verb=0.3)
for i, t0 in enumerate(ROUNDS):
    tstart = t0 + 1.3
    reveal = tstart + 3 * TICK
    show(t0, tstart, level=0.8)
    place('fx', whoosh(0.3), t0 - 0.15, 0.5)
    for k in range(3):
        place('sfx', pitch(S['tap'], 1.2 + k * 0.05), t0 + 0.6 + k * 0.12, 0.5)
    for k in range(3):
        place('fx', tick(True), tstart + k * TICK, 1.4)
        place('fx', tick(False), tstart + k * TICK + TICK / 2, 1.0)
    # cama de suspenso bajo el reloj
    place('music', pad([48, 55, 60, 63], 3 * TICK, 1400, 0.1), tstart, 0.35, verb=0.2)
    for k in range(12):
        place('bass', bass_note(36, 0.18), tstart + k * TICK / 4, 0.7)
        place('drums', hat(), tstart + k * TICK / 4 + 0.1, 0.2, pan=0.3)
    for k in range(12):
        place('drums', snare(), reveal - 0.5 + k * 0.04, 0.08 + k * 0.02)
    place('fx', boom(0.8, 50), reveal, 0.5)
    place('music', chime(), reveal, 0.7, verb=0.3)
    place('sfx', S['merge'], reveal + 0.15, 0.9)
    place('sfx', S['evolution'], reveal + 0.45, 0.8, verb=0.3)
    place('fx', applause(1.6), reveal + 0.3, 0.7)
    place('music', brass([72, 76, 79, 84], 0.4), reveal + 0.45, 0.7)
    show(reveal + 0.45, (ROUNDS[i + 1] if i + 1 < len(ROUNDS) else FINAL), level=0.9)

# pregunta final
place('fx', whoosh(0.3), FINAL - 0.15, 0.6)
place('fx', boom(1.6, 34), FINAL + 0.05, 0.6)
place('music', pad([45, 57, 60, 63], 4.6, 900, 0.3), FINAL + 0.1, 0.35, verb=0.3)
for k in range(9):
    place('drums', kick(1.3), FINAL + 0.2 + k * 0.5, 0.55)
    place('drums', kick(1.3), FINAL + 0.4 + k * 0.5, 0.35)
tstart = FINAL + 2.2
for k in range(3):
    place('fx', tick(True), tstart + k * TICK, 1.0)
    place('fx', tick(False), tstart + k * TICK + TICK / 2, 0.7)
place('fx', riser(1.2, 200, 7000), BLACKOUT - 1.2, 0.5)
# apagón: golpe y silencio
place('fx', boom(1.8, 32), BLACKOUT, 0.7)
place('music', pad([38, 50, 57, 62], 3.4, 1200, 0.8), BLACKOUT + 0.6, 0.3, verb=0.4)
place('sfx', S['prestige'], BLACKOUT + 1.4, 0.5, verb=0.4)
place('fx', boom(1.0, 44), BLACKOUT + 2.5, 0.45)
place('sfx', S['rare'], BLACKOUT + 2.5, 0.6)
# CTA
place('fx', boom(1.4, 38), CTA, 0.5)
place('music', brass([72, 76, 79, 84], 0.8), CTA, 0.9, verb=0.3)
show(CTA, 32.7, level=0.9)

kicks = list(np.arange(0, 2.5, BEAT))
for i, t0 in enumerate(ROUNDS):
    kicks += list(np.arange(t0, t0 + 1.3, BEAT)) + list(np.arange(t0 + 1.3 + 2.4 + 0.45, (ROUNDS[i + 1] if i + 1 < 3 else FINAL), BEAT))
kicks += list(np.arange(CTA, 32.7, BEAT))
mixer.finish(kicks, os.path.join(HERE, 'out', 'audio_v5.wav'), silences=[(BLACKOUT + 0.35, BLACKOUT + 0.6)], duck_depth=0.35, verb_gain=0.12)
