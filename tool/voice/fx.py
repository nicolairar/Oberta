"""The "godfather" chain: warm, dark, in a smoky room.

Low-shelf warmth, a dip in the harsh highs, gentle tape saturation, a small
room reverb and a faint vinyl crackle. Every random choice is seeded, so the
same input always gives the same clip.
"""

import numpy as np
from scipy import signal


def peak(x, sr, f, gain_db, q=1.0):
    a_gain = 10 ** (gain_db / 40)
    w0 = 2 * np.pi * f / sr
    alpha = np.sin(w0) / (2 * q)
    b = [1 + alpha * a_gain, -2 * np.cos(w0), 1 - alpha * a_gain]
    a = [1 + alpha / a_gain, -2 * np.cos(w0), 1 - alpha / a_gain]
    return signal.lfilter(np.array(b) / a[0], np.array(a) / a[0], x)


def sat(x, drive):
    return np.tanh(x * drive) / np.tanh(drive)


def reverb(x, sr, seconds=1.2, wet=0.25, damp=3500, seed=3):
    rng = np.random.default_rng(seed)
    n = int(sr * seconds)
    ir = rng.standard_normal(n) * np.exp(-np.linspace(0, 6.5, n))
    ir = signal.sosfilt(signal.butter(2, damp, btype="low", fs=sr, output="sos"), ir)
    ir[: int(sr * 0.012)] = 0
    ir /= np.abs(ir).sum() ** 0.5 * 4
    return x + wet * signal.fftconvolve(x, ir)[: len(x)]


def crackle(n, sr, level=0.012, seed=5):
    rng = np.random.default_rng(seed)
    out = rng.standard_normal(n) * level * 0.15
    clicks = int(n / sr * 14)
    if clicks:
        for i in rng.choice(n, size=min(clicks, n), replace=False):
            out[i : i + 3] += rng.choice([-1, 1]) * level * rng.uniform(1, 4)
    return signal.sosfilt(signal.butter(2, 800, btype="high", fs=sr, output="sos"), out)


def norm(x, level=0.89):
    return x / (np.abs(x).max() + 1e-9) * level


def godfather(x, sr, tail=0.45, seed=5):
    """The owner's chosen voice colour. [tail] is the room's ring-out kept
    after the last word: short, because the app strings clips together."""
    x = np.concatenate([x, np.zeros(int(sr * tail))])
    x = peak(x, sr, 140, 4.5, 0.9)
    x = peak(x, sr, 3200, -3, 0.8)
    x = sat(x * 1.4, 1.8)
    x = reverb(x, sr, 1.1, 0.22, 2800)
    return norm(x + crackle(len(x), sr, 0.004, seed=seed))
