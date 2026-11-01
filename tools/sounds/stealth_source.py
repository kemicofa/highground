"""Make the stealth enter/exit cues from WoW's original Stealth.ogg.

Run from any directory: python3 tools/sounds/stealth_source.py [source.ogg]
Without a source argument, download FileDataID 569423 from Wowhead's CDN.
Requires ffmpeg with libvorbis. The source audio belongs to Blizzard
Entertainment; see libs/HighgroundKit/sounds/stealth.txt.
"""
import hashlib
from pathlib import Path
import subprocess
import sys
import tempfile
import urllib.request

SOURCE = "https://wow.zamimg.com/sound-ids/live/enus/79/569423/Stealth.ogg"
SHA256 = "15f43cf9a83e616eb6ffc2bf30d94b235d9116bd88e3c16a44040961ce588fa5"
OUTPUT = Path(__file__).resolve().parents[2] / "libs/HighgroundKit/sounds"


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="highground-stealth-") as folder:
        if len(sys.argv) > 1:
            source = Path(sys.argv[1])
        else:
            source = Path(folder) / "Stealth.ogg"
            with urllib.request.urlopen(SOURCE, timeout=30) as response:
                source.write_bytes(response.read())
        if hashlib.sha256(source.read_bytes()).hexdigest() != SHA256:
            raise ValueError("Expected the original Stealth.ogg (FileDataID 569423)")
        for name, semitones in (("enter", -3), ("exit", 3)):
            # Keep the recognizable attack and duration. A small pitch shift
            # distinguishes enemies entering stealth from stealth breaking.
            ratio = 2 ** (semitones / 12)
            filters = (f"asetrate={44100 * ratio:.6f},aresample=44100,atempo={1 / ratio:.9f},"
                       "highpass=f=90,lowpass=f=10000,volume=0.8,"
                       "afade=t=in:d=0.008,afade=t=out:st=1.65:d=0.25,apad,atrim=duration=1.9")
            path = OUTPUT / f"stealth-{name}.ogg"
            subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(source),
                            "-map_metadata", "-1", "-af", filters, "-ac", "1", "-ar", "44100",
                            "-c:a", "libvorbis", "-q:a", "5", str(path)], check=True)
            print(path.relative_to(OUTPUT.parent.parent.parent))


if __name__ == "__main__":
    main()
