"""Highground "GO" kill-window sting.

A noise riser, then two punchy stabs over a sub boom, with a short stereo
echo. Pure synthesis: original and royalty-free.
Needs numpy and scipy. Writes go.wav to the current folder; from the
repository root:

  python3 tools/sounds/go_source.py
  ffmpeg -i go.wav -c:a libvorbis -b:a 192k addons/Highground/sounds/go.ogg
"""
import numpy as np
from scipy.signal import butter, sosfilt
from scipy.io import wavfile

SR = 44100
rng = np.random.default_rng(11)

def t(sec):
    return np.arange(int(SR * sec)) / SR

def env(n, attack, decay):
    x = np.arange(n) / SR
    return np.clip(x / max(attack, 1e-4), 0, 1) * np.exp(-x / decay)

def fade_tail(y, sec=0.012):
    f = min(len(y), int(SR * sec))
    y[-f:] *= np.linspace(1, 0, f) ** 2
    return y

def saw(phase):
    return 2 * ((phase / (2 * np.pi)) % 1.0) - 1

def stab(sec, root, gain):
    # Detuned power chord (root, fifth, octave) through a closing low-pass.
    tt = t(sec)
    x = np.zeros_like(tt)
    for mult in (1.0, 1.5, 2.0):
        for det in (-0.006, 0.006):
            f = root * mult * (1 + det)
            x += saw(2 * np.pi * f * tt)
    sos = butter(2, 3200, btype="low", fs=SR, output="sos")
    x = sosfilt(sos, x)
    x = np.tanh(1.8 * x / np.max(np.abs(x)))  # grit
    return fade_tail(gain * x * env(len(tt), 0.002, 0.09))

def boom(sec, gain):
    tt = t(sec)
    f = 110 * np.exp(-tt / 0.06) + 42  # pitch-drop kick
    ph = 2 * np.pi * np.cumsum(f) / SR
    return fade_tail(gain * np.sin(ph) * env(len(tt), 0.001, 0.12))

def riser(sec, gain):
    # Smooth sweep: narrow low-passed noise ring-modulated by a rising sine,
    # i.e. a noise band that glides 600 Hz -> 7 kHz with no block seams.
    n = int(SR * sec)
    sos = butter(4, 900, btype="low", fs=SR, output="sos")
    noise = sosfilt(sos, rng.standard_normal(n))
    tt = np.arange(n) / SR
    f = 600 * (12 ** (tt / sec))
    carrier = np.sin(2 * np.pi * np.cumsum(f) / SR)
    out = noise * carrier
    out /= np.max(np.abs(out))
    ramp = np.linspace(0, 1, n) ** 2
    return fade_tail(gain * out * ramp, 0.004)

total = t(0.95)
out = np.zeros((len(total), 2))

def place(sig, at, pan=0.0):
    i = int(SR * at)
    j = min(i + len(sig), len(out))
    l, r = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
    out[i:j, 0] += sig[: j - i] * l
    out[i:j, 1] += sig[: j - i] * r

place(riser(0.22, 0.45), 0.0)
place(boom(0.35, 0.9), 0.22)
place(stab(0.16, 220.0, 0.55), 0.22, -0.2)  # A3 power chord
place(boom(0.35, 0.8), 0.40)
place(stab(0.28, 293.66, 0.6), 0.40, 0.2)  # D4 power chord: resolves up

for d, g, side in [(0.09, 0.3, 0), (0.18, 0.15, 1)]:
    k = int(SR * d)
    out[k:, side] += g * out[:-k, 1 - side]

fade = int(SR * 0.08)
out[-fade:] *= np.linspace(1, 0, fade)[:, None]
out /= np.max(np.abs(out))
out *= 10 ** (-1 / 20)
wavfile.write("go.wav", SR, (out * 32767).astype(np.int16))
print("ok", out.shape[0] / SR, "s")
