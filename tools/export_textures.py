"""Export the game textures from their source artwork at their budgeted sizes.

Run from any directory with ImageMagick 7 (`magick`):
    python3 tools/export_textures.py            # every texture
    python3 tools/export_textures.py Macros     # names containing "Macros"
    python3 tools/export_textures.py --check    # verify sizes without exporting

Sizes are powers of two, at least twice the default draw size in UI units, so
the art stays sharp at 2x UI scale. The sniper marker also keeps 1.5x headroom
at its 3x maximum marker size. Every runtime TGA under addons/ and libs/
must be listed here or in GENERATED (tests/test_textures.py).
"""
from __future__ import annotations

import argparse
from pathlib import Path
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
LOGOS = ("Arena", "Battlegrounds", "Bounties", "Macros", "Nearby", "Reputation")

# Game texture -> (source artwork, square size, largest draw size and where).
TEXTURES = {
    **{f"addons/Highground/assets/logos/{name}.tga":
       (f"assets/addon-logos/transparent/{name}.png", 256, "120 guide card (hub/TourView.lua)")
       for name in LOGOS},
    "libs/HighgroundKit/media/HighgroundCrest.tga":
        ("assets/brand/HighgroundCrest.png", 256, "104 Home welcome card (hub/Home.lua)"),
    "libs/HighgroundKit/media/HighgroundIcon.tga":
        ("assets/brand/HighgroundIcon.png", 64, "24 minimap button (ui/Minimap.lua)"),
    # Default marker sizes; sniperScale enlarges them up to 3x.
    "addons/Highground/assets/sniper/SniperReticle.tga":
        ("assets/sniper/SniperReticle.png", 256, "52, up to 156 at 3x marker size (ui/Sniper.lua)"),
    "addons/Highground/assets/sniper/SniperSkull.tga":
        ("assets/sniper/SniperSkull.png", 256, "30, up to 90 at 3x marker size (ui/Sniper.lua)"),
    "addons/Highground/assets/sniper/SniperAim.tga":
        ("assets/sniper/SniperAim.png", 128, "16, up to 48 at 3x marker size (ui/Sniper.lua)"),
}

# Procedural textures with their own generators: (generator, width, height).
GENERATED = {
    "libs/HighgroundKit/media/ControlCorners.tga": ("tools/control_corners.py", 32, 16),
    "libs/HighgroundKit/media/ProgressCircle.tga": ("tools/progress_circle.py", 64, 64),
    "libs/HighgroundKit/media/MapRing.tga": ("tools/map_ring.py", 128, 128),
    "libs/HighgroundKit/media/HeatBlob.tga": ("tools/heat_blob.py", 64, 64),
    # 4x4 sheet of 64 px cells; drawn at 28 on nameplates (ui/TeamIconMarks.lua).
    "addons/Highground/assets/teamicons/TeamIcons.tga": ("tools/team_icons.py", 256, 256),
    "addons/Highground/assets/teamicons/TeamIconRing.tga": ("tools/team_icons.py", 64, 64),
}


def header(path: Path) -> tuple[int, int, int, int, int]:
    """(image type, width, height, bits per pixel, alpha bits) of a TGA."""
    data = path.read_bytes()[:18]
    width, height, bits, flags = struct.unpack_from("<HHBB", data, 12)
    return data[2], width, height, bits, flags & 15


def export(destination: str) -> None:
    source, size, _ = TEXTURES[destination]
    subprocess.run(["magick", str(ROOT / source), "-resize", f"{size}x{size}", "-depth", "8",
                    "-type", "TrueColorAlpha", "-compress", "none", str(ROOT / destination)], check=True)


def problems() -> list[str]:
    found = []
    expected = {path: (size, size) for path, (_, size, _) in TEXTURES.items()}
    expected.update({path: (width, height) for path, (_, width, height) in GENERATED.items()})
    for path, (width, height) in expected.items():
        kind, actual_width, actual_height, bits, alpha = header(ROOT / path)
        if (kind, bits, alpha) != (2, 32, 8):
            found.append(f"{path}: expected an uncompressed 32-bit TGA with 8 alpha bits")
        if (actual_width, actual_height) != (width, height):
            found.append(f"{path}: {actual_width}x{actual_height}, expected {width}x{height}")
    return found


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("names", nargs="*", help="export only textures whose path contains one of these")
    parser.add_argument("--check", action="store_true", help="verify sizes and formats only")
    args = parser.parse_args(argv)
    if not args.check:
        for destination in TEXTURES:
            if not args.names or any(name in destination for name in args.names):
                export(destination)
                print(f"exported {destination}")
    found = problems()
    for problem in found:
        print(problem, file=sys.stderr)
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main())
