"""Generate Highground's original battleground alert cues.

  alert-capture.ogg       base capture: a quick two-tone siren
  alert-objective.ogg     objective changes: a falling horn call
  alert-resurrection.ogg  resurrection: a rising bell arpeggio
  alert-sap.ogg           sap opportunity: two muted plucks and a tick

Pure synthesis with Python 3, numpy and ffmpeg: no game audio or
third-party samples, so the results are covered by the MIT license. Run
from any directory; the files are written to libs/HighgroundKit/sounds.
"""
from pathlib import Path
import subprocess
import sys
import tempfile
import wave

import numpy as np

RATE = 44100
DESTINATION = Path(__file__).resolve().parents[2] / "libs/HighgroundKit/sounds"
rng = np.random.default_rng(7)


def seconds(length):
    return np.arange(int(RATE * length)) / RATE


def envelope(n, attack, decay):
    at = np.arange(n) / RATE
    return np.clip(at / max(attack, 1e-4), 0, 1) * np.exp(-at / decay)


def fade(signal, length=0.015):
    n = min(len(signal), int(RATE * length))
    signal[-n:] *= np.linspace(1, 0, n) ** 2
    return signal


def tone(frequency, length, harmonics, attack=0.004, decay=0.2, vibrato=0.0):
    at = seconds(length)
    frequency = frequency * (1 + vibrato * np.sin(2 * np.pi * 5.5 * at))
    phase = 2 * np.pi * np.cumsum(frequency) / RATE
    wave_ = sum(gain * np.sin(index * phase) for index, gain in enumerate(harmonics, 1))
    return fade(wave_ * envelope(len(at), attack, decay))


def place(out, signal, at):
    start = int(RATE * at)
    end = min(start + len(signal), len(out))
    out[start:end] += signal[: end - start]


def finish(out, peak):
    out = fade(out, 0.04)
    return out / np.max(np.abs(out)) * peak


def capture():
    # High/low siren pairs: urgent, but short enough to stay out of the way.
    out = np.zeros(int(RATE * 0.78))
    bright = (1, 0.0, 0.33, 0.0, 0.2, 0.0, 0.14)  # odd harmonics: a soft square
    for index, at in enumerate((0.0, 0.19, 0.38, 0.57)):
        frequency = 1046.5 if index % 2 == 0 else 783.99  # C6 / G5
        place(out, tone(frequency, 0.17, bright, 0.003, 0.11), at)
    return finish(out, 0.36)


def objective():
    # Two horn notes falling a fourth (A3 to E3): something was lost.
    out = np.zeros(int(RATE * 1.05))
    horn = (1, 0.7, 0.5, 0.35, 0.22, 0.12, 0.06)
    place(out, tone(220.0, 0.34, horn, 0.02, 0.5, 0.004), 0.0)
    place(out, tone(164.81, 0.7, horn, 0.025, 0.42, 0.006), 0.3)
    return finish(out, 0.7)


def resurrection():
    # C5 E5 G5 C6 bells rising into a soft shimmer: the wave is coming.
    out = np.zeros(int(RATE * 1.15))
    bell = (1, 0.0, 0.18, 0.0, 0.0, 0.08)
    for index, frequency in enumerate((523.25, 659.25, 783.99, 1046.5)):
        place(out, tone(frequency, 0.75, bell, 0.003, 0.32), index * 0.085)
    shimmer = rng.standard_normal(int(RATE * 0.5))
    shimmer = np.convolve(shimmer, np.ones(6) / 6, mode="same") * envelope(len(shimmer), 0.2, 0.15)
    place(out, 0.04 * fade(shimmer), 0.25)
    return finish(out, 0.66)


def pluck(frequency, length, damping):
    # Karplus-Strong string: a muted, wooden pluck.
    period = int(RATE / frequency)
    buffer = np.convolve(rng.uniform(-1, 1, period), np.ones(4) / 4, mode="same")
    out = np.zeros(int(RATE * length))
    for index in range(len(out)):
        sample = buffer[index % period]
        out[index] = sample
        buffer[index % period] = damping * 0.5 * (sample + buffer[(index + 1) % period])
    return fade(out * envelope(len(out), 0.001, 0.12))


def sap():
    # Low then high pluck, closed by a quiet woodblock tick: sneak in now.
    out = np.zeros(int(RATE * 0.55))
    place(out, pluck(196.0, 0.25, 0.985), 0.0)  # G3
    place(out, pluck(293.66, 0.3, 0.985), 0.12)  # D4
    place(out, 0.35 * tone(1760.0, 0.05, (1, 0.3), 0.0005, 0.012), 0.3)
    out = np.tanh(1.6 * out / np.max(np.abs(out)))  # gentle saturation: audible plucks
    return finish(out, 0.68)


SOUNDS = {
    "alert-capture": capture,
    "alert-objective": objective,
    "alert-resurrection": resurrection,
    "alert-sap": sap,
}


def write(name, samples):
    pcm = (np.clip(samples, -1, 1) * 32767).astype("<i2")
    with tempfile.TemporaryDirectory(prefix="highground-alerts-") as directory:
        source = Path(directory) / f"{name}.wav"
        with wave.open(str(source), "wb") as output:
            output.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
            output.writeframes(pcm.tobytes())
        target = DESTINATION / f"{name}.ogg"
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(source), "-map_metadata", "-1",
                        "-fflags", "+bitexact", "-c:a", "libvorbis", "-q:a", "5", str(target)], check=True)
    return target


def main():
    names = sys.argv[1:] or list(SOUNDS)
    for name in names:
        print(write(name, SOUNDS[name]()))


if __name__ == "__main__":
    main()
