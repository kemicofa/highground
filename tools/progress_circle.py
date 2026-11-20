"""Bake the progress stepper's shared, antialiased circle mask.

Run: python3 tools/progress_circle.py
One texture supplies filled circles, outlined circles and the current-step halo.
"""
from math import hypot
from pathlib import Path
import struct


def build():
    size, samples = 64, 8
    pixels = bytearray()
    for y in range(size):
        for x in range(size):
            covered = sum(
                hypot(x + (sx + 0.5) / samples - size / 2,
                      y + (sy + 0.5) / samples - size / 2) <= size / 2 - 1
                for sy in range(samples) for sx in range(samples)
            )
            pixels.extend((255, 255, 255, round(255 * covered / samples ** 2)))
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, size, size, 32, 0x28)
    return header + pixels


if __name__ == "__main__":
    destination = Path(__file__).resolve().parents[1] / "libs/HighgroundKit/media/ProgressCircle.tga"
    destination.write_bytes(build())
