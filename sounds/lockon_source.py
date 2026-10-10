# KillOrder "lock-on" sound: bolt-action chk-chk, rising lock chirps, final
# lock tone with a short echo. Pure synthesis -> original, royalty-free.
import numpy as np
from scipy.signal import butter, sosfilt
from scipy.io import wavfile

SR = 44100
rng = np.random.default_rng(7)

def t(sec):
    return np.arange(int(SR * sec)) / SR

def env(n, attack, decay):
    x = np.arange(n) / SR
    a = np.clip(x / max(attack, 1e-4), 0, 1)
    return a * np.exp(-x / decay)

def bandnoise(sec, lo, hi):
    sos = butter(4, [lo, hi], btype="band", fs=SR, output="sos")
    return sosfilt(sos, rng.standard_normal(int(SR * sec)))

def click(sec, lo, hi, partials, decay, gain):
    n = int(SR * sec)
    x = bandnoise(sec, lo, hi) * env(n, 0.0005, decay * 0.5)
    tt = t(sec)
    for f, g in partials:  # metallic ring
        x += g * np.sin(2 * np.pi * f * tt) * env(n, 0.0003, decay)
    x = gain * x / np.max(np.abs(x))
    f = int(SR * 0.008)
    x[-f:] *= np.linspace(1, 0, f) ** 2
    return x

def chirp(sec, f0, f1, gain, decay):
    tt = t(sec)
    f = f0 + (f1 - f0) * (tt / sec) ** 0.6
    phase = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(phase) + 0.25 * np.sin(2 * phase) + 0.08 * np.sin(3 * phase)
    y = gain * x * env(len(tt), 0.003, decay)
    f = min(len(y), int(SR * 0.012))  # de-click: fade the tail to zero
    y[-f:] *= np.linspace(1, 0, f) ** 2
    return y

total = t(1.05)
out = np.zeros((len(total), 2))

def place(sig, at, pan=0.0):
    i = int(SR * at)
    j = min(i + len(sig), len(out))
    l, r = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
    out[i:j, 0] += sig[: j - i] * l
    out[i:j, 1] += sig[: j - i] * r

# Bolt action: pull back (higher) + push forward (lower, heavier) + low thump.
place(click(0.09, 1800, 7000, [(2350, 0.6), (3720, 0.4)], 0.035, 0.55), 0.00, -0.25)
place(click(0.12, 900, 4500, [(1480, 0.7), (2960, 0.3)], 0.05, 0.7), 0.11, 0.25)
thump = np.sin(2 * np.pi * 95 * t(0.12)) * env(int(SR * 0.12), 0.002, 0.03) * 0.5
thump[-400:] *= np.linspace(1, 0, 400)
place(thump, 0.11)

# Lock-on: two short rising chirps, then the held lock tone.
place(chirp(0.07, 1500, 2100, 0.35, 0.05), 0.27, -0.15)
place(chirp(0.07, 1900, 2600, 0.35, 0.05), 0.36, 0.15)
lock = chirp(0.32, 2637, 2637, 0.4, 0.14)
lock *= 1 + 0.15 * np.sin(2 * np.pi * 28 * t(0.32))  # slight tremolo "scanner" feel
place(lock, 0.46)

# Short stereo echo for space.
for d, g, side in [(0.085, 0.28, 1), (0.17, 0.14, 0)]:
    k = int(SR * d)
    out[k:, side] += g * out[:-k, 1 - side]

# Fade tail, normalize to -1 dBFS.
fade = int(SR * 0.08)
out[-fade:] *= np.linspace(1, 0, fade)[:, None]
out /= np.max(np.abs(out))
out *= 10 ** (-1 / 20)
wavfile.write("lockon.wav", SR, (out * 32767).astype(np.int16))
print("ok", out.shape[0] / SR, "s")
