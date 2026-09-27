"""Banda del reel v8 (MOFU «Tomi vs. Sofi»): pulso de competencia a 110 BPM
que crece por etapa, quiebre en la reencarnación, arpegio que sube en la
remontada y fanfarria del ganador.

    python3 music8.py  →  out/audio_v8.wav  (36 s)
"""
import os
import numpy as np
from synth import *  # noqa: F401,F403

DUR = 36.0
BEAT = 60 / 110
mixer = Mixer(DUR)
place = mixer.place
S = dict(SFX)
S['error'] = load_sfx('sfx_error')
CH = [[50, 53, 57], [46, 50, 53], [48, 52, 55], [45, 49, 52]]  # Dm – B♭ – C – A
RT = [38, 34, 36, 33]
STAGES = [3.5, 10.0, 17.0, 24.0]


def race(t0, t1, level=1.0, hats16=False, arp=False, oct_=0):
    b = t0
    while b < t1 - 1e-6:
        bi = int(round(b / BEAT))
        ci = (bi // 4) % 4
        place('drums', kick(0.85), b, 0.8 * level)
        if bi % 2 == 1:
            place('drums', clap(), b, 0.45 * level, verb=0.2)
        place('drums', hat(), b + BEAT / 2, 0.32 * level, pan=0.3)
        if hats16:
            place('drums', hat(), b + BEAT / 4, 0.16 * level, pan=-0.3)
            place('drums', hat(), b + 3 * BEAT / 4, 0.16 * level, pan=-0.3)
        place('bass', bass_note(RT[ci], BEAT * 0.4), b, 0.85 * level)
        place('bass', bass_note(RT[ci] + 12, BEAT * 0.2), b + BEAT * 0.5, 0.5 * level)
        if arp:
            tones = CH[ci] + [CH[ci][0] + 12]
            for k in range(4):
                place('music', pluck(tones[(bi * 4 + k) % 4] + 12 + oct_, 0.16, 0.8), b + k * BEAT / 4, 0.35 * level, pan=(-0.3 if k % 2 else 0.3), verb=0.15)
        b += BEAT


# hook
place('fx', whoosh(0.5, lo=300, hi=6000), 0.0, 0.5)
place('fx', boom(1.0, 46), 0.5, 0.45)
place('sfx', S['event'], 0.9, 0.5)
for tt in (1.8, 1.95):
    place('sfx', S['tap'], tt, 0.6)
race(3.5, 24.0, level=0.8, hats16=False, arp=False)
for s0 in STAGES:
    place('fx', whoosh(0.3), s0 - 0.2, 0.45)
    place('music', bell(84, 0.8), s0, 0.4, verb=0.3)
# minuto 1: toques de Tomi (izq), fusión de Sofi (der)
for k in range(28):
    place('sfx', pitch(S['tap'], 0.95 + (k % 3) * 0.05), 3.7 + k * 0.22, 0.28, pan=-0.6)
place('sfx', S['buy'], 4.8, 0.7, pan=0.6)
place('sfx', S['merge'], 6.2, 0.8, pan=0.6)
place('sfx', S['evolution'], 6.35, 0.6, pan=0.6)
place('sfx', S['merge'], 8.45, 0.6, pan=0.6)
# día 2
for k in range(9):
    place('sfx', pitch(S['tap'], 1.1), 10.25 + k * 0.11, 0.3, pan=-0.6)
place('sfx', S['error'], 11.3, 0.8, pan=-0.6)
place('sfx', S['event'], 11.6, 0.6, pan=0.6)
place('sfx', S['merge'], 14.5, 0.5, pan=0.6)
# día 7: Tomi aprende
race(17.0, 24.0, level=0.9, hats16=True, arp=True)
for tt in (17.3, 17.8, 18.3):
    place('sfx', S['merge'], tt, 0.6, pan=-0.6)
place('sfx', S['buy'], 19.0, 0.6, pan=-0.6)
place('sfx', S['buy'], 19.6, 0.6, pan=-0.6)
for tt in (20.8, 22.4):
    place('sfx', S['event'], tt, 0.5, pan=-0.6)
for tt in (18.6, 21.6, 23.2):
    place('sfx', S['event'], tt, 0.45, pan=0.6)
# día 30: reencarna (quiebre)
place('music', pad([38, 50, 57, 62], 1.6, 1300, 0.3), 24.0, 0.3, verb=0.3)
place('sfx', S['tap'], 24.9, 0.6, pan=-0.6)
place('sfx', S['prestige'], 25.0, 0.55, verb=0.3)
place('fx', whoosh(0.8, lo=200, hi=10000), 25.0, 0.4)
place('fx', boom(1.2, 40), 25.6, 0.4)
race(25.6, 31.0, level=1.0, hats16=True, arp=True, oct_=12)
for k, tt in enumerate((26.4, 27.2, 28.0, 28.8, 29.6)):
    place('sfx', pitch(S['evolution'], 1.0 / (1 + k * 0.08)), tt, 0.6, pan=-0.5)
    place('fx', whoosh(0.25, lo=500, hi=9000), tt - 0.1, 0.35, pan=-0.4)
place('fx', riser(2.5, 300, 9000), 28.5, 0.4)
# victoria
place('fx', boom(1.5, 38), 31.1, 0.45)
place('fx', crash(1.8), 31.1, 0.35)
for k, m in enumerate((62, 66, 69, 74)):
    place('music', pluck(m + 12, 0.5, 1.0), 31.1 + k * 0.12, 0.8, verb=0.3)
place('music', pad([50, 54, 57, 62, 66], 2.2, 3000, 0.05), 31.6, 0.35, verb=0.3)
place('sfx', S['rare'], 31.15, 0.6)
# CTA
race(33.5, 35.7, level=0.8)
kicks = list(np.arange(3.5, 24.0, BEAT)) + list(np.arange(25.6, 31.0, BEAT)) + list(np.arange(33.5, 35.7, BEAT))
mixer.finish(kicks, os.path.join(HERE, 'out', 'audio_v8.wav'), duck_depth=0.3, verb_gain=0.12)
