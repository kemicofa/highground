"""Compose the Twitch overlay from original 3D animation and editable SVG copy.

Requires ImageMagick, FFmpeg (libvpx-vp9) and rsvg-convert. Python only orchestrates
the native renderers; all original artwork remains separate and unchanged.
"""

from __future__ import annotations

import argparse
import base64
import os
from pathlib import Path
import subprocess
import tempfile
import zipfile
from xml.sax.saxutils import escape


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets/stream-banner"
SOURCE = ASSETS / "source"
NAME = "Highground-Twitch-Banner"
FPS = 25
FRAMES = 150


def configure(variant: str = "alliance") -> None:
    global ASSETS, SOURCE, NAME
    ASSETS = ROOT / "assets/stream-banner"
    NAME = "Highground-Twitch-Banner"
    if variant == "horde":
        ASSETS /= "horde"
        NAME += "-Horde"
    SOURCE = ASSETS / "source"


def run(*command: str, env: dict | None = None) -> None:
    subprocess.run([str(part) for part in command], check=True, env=env)


def ffmpeg(*arguments: str) -> None:
    run("ffmpeg", "-hide_banner", "-loglevel", "warning", "-y", *arguments)


def import_crest(renders: Path) -> None:
    """Preserve the 6-second Blender loop in a portable, lossless alpha master.

    The source has stationary author lettering below y=880; the overlay uses
    larger editable credit text instead. The crest, spin and glints are intact.
    """
    frames = list(renders.glob("crest_*.png"))
    if len(frames) != FRAMES:
        raise ValueError(f"Expected {FRAMES} original frames, found {len(frames)}")
    ffmpeg(
        "-framerate", str(FPS), "-start_number", "1",
        "-i", str(renders / "crest_%04d.png"),
        "-vf", "crop=960:880:0:0,scale=488:448:flags=lanczos,format=yuva420p",
        "-c:v", "libvpx-vp9", "-lossless", "1", "-b:v", "0",
        "-auto-alt-ref", "0", "-row-mt", "1", "-an",
        "-frames:v", str(FRAMES), str(SOURCE / "crest-spin.webm"),
    )
    # The roomier aspect ratios use a larger crest. Keep its source at the full
    # rendered resolution, and refresh it together with the slim animation.
    ffmpeg(
        "-framerate", str(FPS), "-start_number", "1",
        "-i", str(renders / "crest_%04d.png"),
        "-vf", "crop=960:880:0:0,format=yuva420p",
        "-c:v", "libvpx-vp9", "-lossless", "1", "-b:v", "0",
        "-auto-alt-ref", "0", "-row-mt", "1", "-an",
        "-frames:v", str(FRAMES), str(SOURCE / "crest-spin-hd.webm"),
    )


def plate(svg_path: Path | None = None, output: Path | None = None,
          width: int | None = None, height: int | None = None) -> None:
    # A task-local Fontconfig file exposes bundled fonts without installing them.
    with tempfile.TemporaryDirectory(prefix="highground-banner-fonts-") as temp:
        config = Path(temp) / "fonts.conf"
        fontdir = escape(str(ROOT / "libs/HighgroundKit/media"))
        config.write_text(
            '<?xml version="1.0"?><!DOCTYPE fontconfig SYSTEM "fonts.dtd">'
            '<fontconfig><include ignore_missing="yes">/etc/fonts/fonts.conf</include>'
            f'<dir>{fontdir}</dir><cachedir>{escape(temp)}/cache</cachedir></fontconfig>'
        )
        env = dict(os.environ, FONTCONFIG_FILE=str(config))
        options = []
        if width is not None:
            options += ["--width", str(width)]
        if height is not None:
            options += ["--height", str(height)]
        run("rsvg-convert", *options, "--output", str(output or SOURCE / "plate.png"),
            str(svg_path or SOURCE / "banner.svg"), env=env)


def master() -> None:
    # Explicit libvpx decoder is required: the native VP9 decoder ignores alpha.
    ffmpeg(
        "-loop", "1", "-framerate", str(FPS), "-i", str(SOURCE / "plate.png"),
        "-c:v", "libvpx-vp9", "-i", str(SOURCE / "crest-spin.webm"),
        "-filter_complex",
        "[0:v]format=rgba[bg];[1:v]scale=244:224:flags=lanczos,format=rgba[crest];"
        "[bg][crest]overlay=4:3:format=auto:shortest=1,format=rgba[out]",
        "-map", "[out]", "-frames:v", str(FRAMES),
        "-c:v", "ffv1", "-level", "3", "-pix_fmt", "bgra", "-an",
        str(SOURCE / "master.mkv"),
    )


def stills() -> None:
    ffmpeg("-i", str(SOURCE / "master.mkv"), "-frames:v", "1", "-update", "1",
           str(ASSETS / f"{NAME}-1600.png"))
    ffmpeg("-i", str(SOURCE / "master.mkv"), "-vf", "scale=960:144:flags=lanczos",
           "-frames:v", "1", "-update", "1", str(ASSETS / f"{NAME}-960.png"))


def animations() -> None:
    raw_gif = SOURCE / "raw.gif"
    for width, height in [(1600, 240), (960, 144)]:
        ffmpeg(
            "-i", str(SOURCE / "master.mkv"),
            "-vf", f"scale={width}:{height}:flags=lanczos,format=yuva420p",
            "-c:v", "libvpx-vp9", "-b:v", "0", "-crf", "16", "-deadline", "good",
            "-cpu-used", "3", "-auto-alt-ref", "0", "-row-mt", "1", "-an",
            str(ASSETS / f"{NAME}-{width}.webm"),
        )
    ffmpeg(
        "-i", str(SOURCE / "master.mkv"),
        "-filter_complex",
        "[0:v]fps=25,scale=960:144:flags=lanczos,split[video][stats];"
        "[stats]palettegen=max_colors=256:reserve_transparent=1:stats_mode=diff[palette];"
        "[video][palette]paletteuse=dither=bayer:bayer_scale=3:"
        "diff_mode=rectangle:alpha_threshold=96[out]",
        "-map", "[out]", "-loop", "0", "-final_delay", "4", "-an",
        str(raw_gif),
    )
    # Preserve full alpha clearing while storing static text just once where
    # possible. This makes the GIF roughly 80% smaller than FFmpeg's export.
    run("magick", str(raw_gif), "-coalesce", "-layers", "Optimize",
        str(ASSETS / f"{NAME}-960.gif"))
    raw_gif.unlink()


def placement() -> None:
    # librsvg restricts parent-directory references; inline the exported image.
    preview = ASSETS / "previews"
    svg = (preview / "placement.svg").read_text()
    png = base64.b64encode((ASSETS / f"{NAME}-960.png").read_bytes()).decode()
    svg = svg.replace(f"../{NAME}-960.png", f"data:image/png;base64,{png}")
    subprocess.run(
        ["rsvg-convert", "--output", str(preview / "Placement-1080p.png")],
        input=svg.encode(), check=True,
    )


def package() -> None:
    files = [
        ASSETS / f"{NAME}-{size}.{extension}"
        for size, extension in [(960, "webm"), (1600, "webm"), (960, "gif"),
                                (960, "png"), (1600, "png")]
    ]
    files.extend([ASSETS / "START-HERE.txt", ASSETS / "previews/Placement-1080p.png"])
    with zipfile.ZipFile(ASSETS / f"{NAME}-Pack.zip", "w", zipfile.ZIP_DEFLATED) as archive:
        for path in files:
            archive.write(path, f"{NAME}/{path.name}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--variant", choices=["alliance", "horde"], default="alliance",
                        help="Select the independently stored banner colorway")
    parser.add_argument("--import-renders", type=Path,
                        help="Import the original 150 Blender PNG renders once")
    parser.add_argument("--stills-only", action="store_true")
    args = parser.parse_args()
    configure(args.variant)
    if args.import_renders:
        import_crest(args.import_renders)
    if not (SOURCE / "crest-spin.webm").is_file():
        parser.error("Missing crest-spin.webm; use --import-renders /path/to/renders")
    plate()
    master()
    stills()
    placement()
    if not args.stills_only:
        animations()
        package()
    print(f"Banner exported to {ASSETS}")


if __name__ == "__main__":
    main()
