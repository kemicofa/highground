"""Bake the UI kit's default rounded corners into one shared 32x16 RGBA TGA.

Run from any directory: python3 tools/control_corners.py
The Lua fallback handles custom theme radii. The default fill (radius 5),
rim (radius 4, width 1) and halo (radius 5, spread 4) use four cropped copies
of these masks instead of allocating a texture for every pixel row.
"""
from math import hypot
from pathlib import Path
import struct


def build():
    width, height = 32, 16
    pixels = bytearray(b"\xff\xff\xff\x00" * width * height)

    def mask(x_offset, radius, size, alpha):
        # Supersampling integrates coverage at the actual on-screen size.
        for y in range(size):
            for x in range(size):
                coverage = 0
                for sy in range(8):
                    for sx in range(8):
                        distance = hypot(radius - x - (sx + 0.5) / 8,
                                         radius - y - (sy + 0.5) / 8)
                        coverage += alpha(distance)
                pixels[((y * width) + x_offset + x) * 4 + 3] = round(coverage * 255 / 64)
        # Extrude the edge texels into a gutter so fractional UI scales do
        # not blend against unrelated transparent pixels at slice seams.
        for y in range(-1, size + 1):
            for x in range(-1, size + 1):
                if 0 <= x < size and 0 <= y < size:
                    continue
                if 0 <= x_offset + x < width and 0 <= y < height:
                    source = (min(size - 1, max(0, y)) * width + x_offset + min(size - 1, max(0, x))) * 4 + 3
                    pixels[(y * width + x_offset + x) * 4 + 3] = pixels[source]

    mask(0, 5, 5, lambda d: float(d <= 5))
    mask(8, 4, 4, lambda d: float(3 <= d <= 4))
    mask(16, 9, 9, lambda d: max(0, min(1, (9 - d) / 4)) if d >= 5 else 0)
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, width, height, 32, 0x28)
    return header + pixels


if __name__ == "__main__":
    destination = Path(__file__).resolve().parents[1] / "libs/HighgroundKit/media/ControlCorners.tga"
    destination.write_bytes(build())
