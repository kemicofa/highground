"""Generate the original nearby-enemy cue: two soft, ascending bell notes.

Run from any directory with Python 3 and ffmpeg installed. No game audio
or third-party samples are used; the result is covered by the MIT license.
"""
from array import array
from math import exp, pi, sin
from pathlib import Path
import subprocess
import sys
import tempfile
import wave


RATE = 44100
DESTINATION = Path(__file__).resolve().parents[2] / "libs/HighgroundKit/sounds/nearby.ogg"


def samples():
    values = []
    for index in range(int(RATE * 0.6)):
        at = index / RATE
        value = 0.0
        for start, frequency in ((0.0, 660), (0.13, 880)):
            elapsed = at - start
            if 0 <= elapsed < 0.4:
                envelope = min(1, elapsed / 0.008) * exp(-elapsed / 0.085)
                envelope *= min(1, (0.4 - elapsed) / 0.03)
                phase = 2 * pi * frequency * elapsed
                value += envelope * (sin(phase) + 0.15 * sin(2 * phase))
        values.append(value)
    peak = max(abs(value) for value in values)
    pcm = array("h", (round(value / peak * 0.3 * 32767) for value in values))
    if sys.byteorder != "little":
        pcm.byteswap()
    return pcm.tobytes()


def main():
    with tempfile.TemporaryDirectory(prefix="highground-nearby-") as directory:
        source = Path(directory) / "nearby.wav"
        with wave.open(str(source), "wb") as output:
            output.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
            output.writeframes(samples())
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(source),
                        "-c:a", "libvorbis", "-q:a", "5", str(DESTINATION)], check=True)
    print(DESTINATION)


if __name__ == "__main__":
    main()
