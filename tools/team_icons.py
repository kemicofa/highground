"""Bake the team icons: a sheet of white symbols on dark discs, and their ring.

Run: python3 tools/team_icons.py
TeamIcons.tga is a 4x4 grid of 64 px cells in the order of ICONS (read by
core/TeamIcons.lua). TeamIconRing.tga is a white band between dark edges that
covers a disc's rim: tinting it gives teammates with the same icon their own
outline colour, and it frames class icons the same way.
Shapes use cell units: the centre is 0, the cell edge 1, y points up.
"""
from math import atan2, cos, degrees, hypot, radians, sin
from pathlib import Path
import struct

CELL, GRID, SAMPLES = 64, 4, 4
DISC = 28 / 32
DISC_GREY, DISC_ALPHA = 20, 0.9
ROOT = Path(__file__).resolve().parents[1] / "addons/Highground/assets/teamicons"


# Shapes: functions of (x, y) that say whether the point is inside.
def circle(cx, cy, r):
    return lambda x, y: (x - cx) ** 2 + (y - cy) ** 2 <= r * r


def rect(x0, y0, x1, y1):
    return lambda x, y: x0 <= x <= x1 and y0 <= y <= y1


def capsule(x0, y0, x1, y1, r):
    dx, dy = x1 - x0, y1 - y0
    length = dx * dx + dy * dy

    def inside(x, y):
        t = 0 if length == 0 else max(0, min(1, ((x - x0) * dx + (y - y0) * dy) / length))
        return hypot(x - x0 - t * dx, y - y0 - t * dy) <= r
    return inside


def path(points, r):
    """A stroke through several points with round joins."""
    parts = [capsule(*points[i], *points[i + 1], r) for i in range(len(points) - 1)]
    return lambda x, y: any(part(x, y) for part in parts)


def poly(points):
    def inside(x, y):
        hit, j = False, len(points) - 1
        for i, (xi, yi) in enumerate(points):
            xj, yj = points[j]
            if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
                hit = not hit
            j = i
        return hit
    return inside


def arc(cx, cy, r, width, start, stop):
    """A stroke along a circle, counterclockwise from start to stop degrees."""
    span = (stop - start) % 360 or 360

    def inside(x, y):
        if abs(hypot(x - cx, y - cy) - r) > width:
            return False
        return (degrees(atan2(y - cy, x - cx)) - start) % 360 <= span
    return inside


def union(*shapes):
    return lambda x, y: any(shape(x, y) for shape in shapes)


def minus(shape, *cuts):
    return lambda x, y: shape(x, y) and not any(cut(x, y) for cut in cuts)


def turn(shape, angle, scale=1):
    c, s = cos(radians(-angle)), sin(radians(-angle))
    return lambda x, y: shape((x * c - y * s) / scale, (x * s + y * c) / scale)


def sword():
    return union(poly([(-0.11, -0.2), (0.11, -0.2), (0.11, 0.4), (0, 0.6), (-0.11, 0.4)]),
                 rect(-0.3, -0.32, 0.3, -0.19), rect(-0.065, -0.52, 0.065, -0.3), circle(0, -0.55, 0.1))


def shield():
    return poly([(-0.45, 0.55), (0.45, 0.55), (0.45, 0.05), (0.38, -0.2), (0.22, -0.42), (0, -0.6),
                 (-0.22, -0.42), (-0.38, -0.2), (-0.45, 0.05)])


def star(points, outer, inner, cx=0, cy=0):
    corners = []
    for i in range(points * 2):
        r = outer if i % 2 == 0 else inner
        a = radians(90 + i * 180 / points)
        corners.append((cx + r * cos(a), cy + r * sin(a)))
    return poly(corners)


W = 0.085  # letter stroke
LETTERS = {
    "A": union(path([(-0.32, -0.45), (0, 0.45), (0.32, -0.45)], W), capsule(-0.17, -0.12, 0.17, -0.12, W)),
    "B": union(capsule(-0.26, -0.45, -0.26, 0.45, W), path([(-0.26, 0.45), (0.06, 0.45)], W),
               arc(0.06, 0.225, 0.225, W, -90, 90), path([(0.06, 0), (-0.26, 0)], W),
               path([(-0.26, 0), (0.1, 0)], W), arc(0.1, -0.225, 0.225, W, -90, 90),
               path([(0.1, -0.45), (-0.26, -0.45)], W)),
    "C": union(arc(0.04, 0, 0.42, W, 45, 315), circle(0.04 + 0.42 * cos(radians(45)), 0.42 * sin(radians(45)), W),
               circle(0.04 + 0.42 * cos(radians(45)), -0.42 * sin(radians(45)), W)),
    "D": union(capsule(-0.28, -0.45, -0.28, 0.45, W), path([(-0.28, 0.45), (-0.04, 0.45)], W),
               arc(-0.04, 0, 0.45, W, -90, 90), path([(-0.04, -0.45), (-0.28, -0.45)], W)),
}

# Sheet order; core/TeamIcons.lua reads the same list.
ICONS = [
    ("tank", shield()),
    ("healer", union(circle(-0.22, 0.17, 0.27), circle(0.22, 0.17, 0.27),
                     poly([(-0.475, 0.09), (0.475, 0.09), (0, -0.56)]))),
    ("melee", sword()),
    ("caster", union(star(4, 0.62, 0.15), star(4, 0.2, 0.05, 0.38, 0.38))),
    ("flag", union(capsule(-0.36, -0.58, -0.36, 0.58, 0.055),
                   poly([(-0.33, 0.56), (0.05, 0.48), (0.5, 0.56), (0.4, 0.26), (0.5, -0.02), (0.05, 0.06),
                         (-0.33, -0.02)]))),
    ("escort", union(path([(-0.42, -0.02), (0, 0.38), (0.42, -0.02)], 0.1),
                     path([(-0.42, -0.4), (0, 0), (0.42, -0.4)], 0.1))),
    ("defense", minus(union(rect(-0.32, -0.55, 0.32, 0.3), rect(-0.42, 0.18, 0.42, 0.32),
                            rect(-0.42, 0.3, -0.2, 0.55), rect(-0.11, 0.3, 0.11, 0.55), rect(0.2, 0.3, 0.42, 0.55)),
                      circle(0, -0.28, 0.13), rect(-0.13, -0.6, 0.13, -0.28))),
    ("offense", union(turn(sword(), 42), turn(sword(), -42))),
    ("caller", union(poly([(-0.55, 0.1), (-0.25, 0.14), (0.18, 0.4), (0.18, -0.4), (-0.25, -0.14), (-0.55, -0.1)]),
                     poly([(-0.25, -0.14), (-0.12, -0.2), (-0.18, -0.42), (-0.3, -0.42)]),
                     arc(0.2, 0, 0.2, 0.05, -50, 50), arc(0.2, 0, 0.36, 0.05, -50, 50))),
    ("peel", union(capsule(-0.24, 0.05, -0.24, 0.42, 0.075), capsule(-0.08, 0.05, -0.08, 0.55, 0.075),
                   capsule(0.08, 0.05, 0.08, 0.52, 0.075), capsule(0.24, 0.05, 0.24, 0.4, 0.075),
                   capsule(-0.28, -0.12, -0.5, 0.16, 0.08), rect(-0.31, -0.36, 0.31, 0.1),
                   capsule(-0.18, -0.38, 0.18, -0.38, 0.13))),
    ("scout", union(minus(lambda x, y: circle(0, -0.5, 0.85)(x, y) and circle(0, 0.5, 0.85)(x, y),
                          circle(0, 0, 0.25)), circle(0, 0, 0.12))),
    ("focus", union(arc(0, 0, 0.41, 0.05, 0, 360), capsule(0, 0.22, 0, 0.62, 0.055),
                    capsule(0, -0.22, 0, -0.62, 0.055), capsule(0.22, 0, 0.62, 0, 0.055),
                    capsule(-0.22, 0, -0.62, 0, 0.055), circle(0, 0, 0.08))),
    ("squadA", LETTERS["A"]),
    ("squadB", LETTERS["B"]),
    ("squadC", LETTERS["C"]),
    ("squadD", LETTERS["D"]),
]


def tga(size_x, size_y, pixels):
    return struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, size_x, size_y, 32, 0x28) + bytes(pixels)


def sheet():
    size = CELL * GRID
    pixels = bytearray(size * size * 4)
    for index, (_, glyph) in enumerate(ICONS):
        ox, oy = index % GRID * CELL, index // GRID * CELL
        for py in range(CELL):
            for px in range(CELL):
                grey = alpha = 0
                for sy in range(SAMPLES):
                    for sx in range(SAMPLES):
                        x = (px + (sx + 0.5) / SAMPLES) / (CELL / 2) - 1
                        y = 1 - (py + (sy + 0.5) / SAMPLES) / (CELL / 2)
                        if glyph(x, y):
                            grey, alpha = grey + 255, alpha + 1
                        elif x * x + y * y <= DISC * DISC:
                            grey, alpha = grey + DISC_GREY * DISC_ALPHA, alpha + DISC_ALPHA
                g = round(grey / alpha) if alpha else 0
                at = ((oy + py) * size + ox + px) * 4
                pixels[at:at + 4] = bytes((g, g, g, round(255 * alpha / SAMPLES ** 2)))
    return tga(size, size, pixels)


# (inner radius, outer radius, grey, alpha) in pixels of the 64 px ring.
BANDS = ((26.5, 27.5, 0, 0.5), (27.5, 30.5, 255, 1), (30.5, 31.5, 0, 0.6))


def ring():
    pixels = bytearray()
    for py in range(CELL):
        for px in range(CELL):
            grey = alpha = 0
            for sy in range(SAMPLES * 2):
                for sx in range(SAMPLES * 2):
                    d = hypot(px + (sx + 0.5) / (SAMPLES * 2) - CELL / 2, py + (sy + 0.5) / (SAMPLES * 2) - CELL / 2)
                    for inner, outer, g, a in BANDS:
                        if inner <= d < outer:
                            grey, alpha = grey + g * a, alpha + a
                            break
            g = round(grey / alpha) if alpha else 0
            pixels.extend((g, g, g, round(255 * alpha / (SAMPLES * 2) ** 2)))
    return tga(CELL, CELL, pixels)


if __name__ == "__main__":
    ROOT.mkdir(parents=True, exist_ok=True)
    (ROOT / "TeamIcons.tga").write_bytes(sheet())
    (ROOT / "TeamIconRing.tga").write_bytes(ring())
