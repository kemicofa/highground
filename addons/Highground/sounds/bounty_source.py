# Highground "bounty spotted" sound: coin jingle over a low bell toll, then a
# second toll. Pure synthesis -> original, royalty-free.
# python3 bounty_source.py && ffmpeg -i bounty.wav -c:a libvorbis -b:a 192k bounty.ogg
import numpy as np
from scipy.io import wavfile

SR = 44100
rng = np.random.default_rng(11)
LENGTH = 1.9


def t(sec):
    return np.arange(int(SR * sec)) / SR


def env(n, attack, decay):
    x = np.arange(n) / SR
    a = np.clip(x / max(attack, 1e-4), 0, 1)
    return a * np.exp(-x / decay)


def fade_tail(x, sec):
    f = min(len(x), int(SR * sec))
    x[-f:] *= np.linspace(1, 0, f) ** 2
    return x


def coin(f0, gain):
    # Inharmonic partials of a small struck disc.
    sec = 0.35
    tt = t(sec)
    x = np.zeros(len(tt))
    for ratio, g, d in [(1.0, 1.0, 0.09), (2.76, 0.5, 0.05), (5.4, 0.3, 0.03), (8.9, 0.15, 0.02)]:
        x += g * np.sin(2 * np.pi * f0 * ratio * tt) * env(len(tt), 0.0004, d)
    return fade_tail(gain * x / np.max(np.abs(x)), 0.01)


def bell(f0, sec, gain):
    # Church-bell partials (hum, prime, tierce, quint, nominal).
    tt = t(sec)
    x = np.zeros(len(tt))
    for ratio, g, d in [(0.5, 0.6, 1.1), (1.0, 1.0, 0.8), (1.19, 0.45, 0.5), (1.5, 0.3, 0.4), (2.0, 0.35, 0.3)]:
        x += g * np.sin(2 * np.pi * f0 * ratio * tt) * env(len(tt), 0.002, d)
    return fade_tail(gain * x / np.max(np.abs(x)), 0.05)


out = np.zeros((int(SR * LENGTH), 2))


def place(sig, at, pan=0.0):
    i = int(SR * at)
    j = min(len(out), i + len(sig))
    l, r = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
    out[i:j, 0] += sig[: j - i] * l
    out[i:j, 1] += sig[: j - i] * r


# Coin jingle: a handful of coins dropped on a counter, spread in stereo.
at = 0.0
for _ in range(7):
    place(coin(rng.uniform(3200, 4600), rng.uniform(0.25, 0.4)), at, rng.uniform(-0.6, 0.6))
    at += rng.uniform(0.03, 0.07)

# Bell tolls: low "wanted" bell, then a softer echo toll a fifth below.
place(bell(392, 1.4, 0.75), 0.18)
place(bell(262, 1.2, 0.5), 0.72)

# Short stereo echo for space.
for d, g, side in [(0.09, 0.22, 1), (0.18, 0.11, 0)]:
    k = int(SR * d)
    out[k:, side] += g * out[:-k, 1 - side]

fade = int(SR * 0.15)
out[-fade:] *= np.linspace(1, 0, fade)[:, None]
out /= np.max(np.abs(out))
out *= 10 ** (-1 / 20)
wavfile.write("bounty.wav", SR, (out * 32767).astype(np.int16))
print("ok", out.shape[0] / SR, "s")
