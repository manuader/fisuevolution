"""Síntesis y mezcla compartidas por las bandas de los reels (music.py = v1,
music2.py = v2). Instrumentos hechos con numpy, SFX reales del juego desde
out/sfx/*.wav y un master a −14 LUFS en finish.sh.
"""
import os
import wave
import numpy as np
from scipy.signal import butter, sosfilt, fftconvolve

SR = 48000
HERE = os.path.dirname(os.path.abspath(__file__))
rng = np.random.default_rng(7)


def t_arr(n):
    return np.arange(n) / SR


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


class Mixer:
    """Buses estéreo de una duración fija; place() suma, finish() masteriza."""

    def __init__(self, dur):
        self.N = int(SR * dur)
        self.bus = {k: np.zeros((2, self.N)) for k in ('drums', 'bass', 'music', 'fx', 'sfx', 'verb')}

    def place(self, name, sig, t, gain=1.0, pan=0.0, verb=0.0):
        N, bus = self.N, self.bus
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

    def finish(self, kick_times, out, silences=(), duck_depth=0.6, verb_gain=0.12):
        N, bus = self.N, self.bus
        # sidechain: bajo y música respiran con el kick
        duck = np.ones(N)
        for kt in kick_times:
            i = int(kt * SR)
            n = int(0.25 * SR)
            seg_ = 1 - duck_depth * np.exp(-t_arr(n) * 14)
            duck[i:i + n] = np.minimum(duck[i:i + n], seg_[:max(0, min(n, N - i))])
        for k in ('bass', 'music'):
            bus[k] *= duck

        # reverb: IR de ruido con decaimiento exponencial (estéreo decorrelado)
        irn = int(SR * 2.2)
        ir_t = t_arr(irn)
        ir = [lp(rng.standard_normal(irn), 6000) * np.exp(-ir_t * 3.0) for _ in range(2)]
        verb = np.stack([fftconvolve(bus['verb'][c], ir[c])[:N] for c in range(2)]) * verb_gain

        mix = (bus['drums'] * 0.9 + bus['bass'] * 0.9 + bus['music'] * 0.75 + bus['fx'] * 0.8 + bus['sfx'] * 0.85 + verb)
        mix = np.stack([hp(mix[c], 25) for c in range(2)])

        # silencios reales (el corte tiene que doler)
        for a, b in silences:
            i0, i1 = int(a * SR), int(b * SR)
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

        pcm = (np.clip(mix.T, -1, 1) * 32767).astype(np.int16)
        with wave.open(out, 'wb') as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        print('ok', out)
