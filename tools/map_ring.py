"""Bake the map circle's antialiased outline.

Run: python3 tools/map_ring.py
A white band between two dark edges: tinting colours the band while the edges
stay dark, so the outline reads on light and dark map art alike.
"""
from math import hypot
from pathlib import Path
import struct

# (inner radius, outer radius, grey, alpha) in pixels of the 128 px texture.
BANDS = ((55.5, 57.5, 0, 0.3), (57.5, 61, 255, 1), (61, 63, 0, 0.5))


def build():
    size, samples = 128, 8
    pixels = bytearray()
    for y in range(size):
        for x in range(size):
            grey = alpha = 0
            for sy in range(samples):
                for sx in range(samples):
                    d = hypot(x + (sx + 0.5) / samples - size / 2, y + (sy + 0.5) / samples - size / 2)
                    for inner, outer, g, a in BANDS:
                        if inner <= d < outer:
                            grey, alpha = grey + g * a, alpha + a
                            break
            g = round(grey / alpha) if alpha else 0
            pixels.extend((g, g, g, round(255 * alpha / samples ** 2)))
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, size, size, 32, 0x28)
    return header + pixels


if __name__ == "__main__":
    destination = Path(__file__).resolve().parents[1] / "libs/HighgroundKit/media/MapRing.tga"
    destination.write_bytes(build())
