"""Bake the map heatmap's soft blob.

Run: python3 tools/heat_blob.py
White with a smooth falloff to transparent at the edge: tinting colours it,
and overlapping blobs blend into one shaded area.
"""
from math import exp, hypot
from pathlib import Path
import struct


def build():
    size = 64
    pixels = bytearray()
    for y in range(size):
        for x in range(size):
            # 0 at the centre, 1 at the edge; zero alpha from there out.
            d = hypot(x + 0.5 - size / 2, y + 0.5 - size / 2) / (size / 2)
            alpha = max(0.0, exp(-2.5 * d * d) - exp(-2.5)) / (1 - exp(-2.5)) if d < 1 else 0.0
            pixels.extend((255, 255, 255, round(255 * alpha)))
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, size, size, 32, 0x28)
    return header + pixels


if __name__ == "__main__":
    destination = Path(__file__).resolve().parents[1] / "libs/HighgroundKit/media/HeatBlob.tga"
    destination.write_bytes(build())
