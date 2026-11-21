# Highground Twitch overlay

A slim navy-and-gold stream banner with the original 3D crest rotation and
sparkle glints. The text stays still for readability. The exterior is transparent;
the dark plate keeps the copy readable over gameplay.

[Download the streamer package](Highground-Twitch-Banner-Pack.zip), including
five aspect ratios, three sizes per ratio, and PNG, GIF and WebM for every size.
The pack contains **45 banner files**, OBS instructions and visual guides.

[Browse the unpacked Alliance files](formats/) or open the
[format comparison image](formats/Format-Guide.png). The original exports below
are still available separately.

A [Horde crimson version](horde/README.md) is available separately, including
unpacked GIF, PNG and OBS WebM exports with the same dimensions and layout.

| Aspect ratio | Three resolutions |
| --- | --- |
| 20:3, original slim overlay | 960 × 144 · 1600 × 240 · 1920 × 288 |
| 5:1, requested wide banner | 1400 × 280 · 1600 × 320 · 1920 × 384 |
| 8:1, extra-thin strip | 960 × 120 · 1440 × 180 · 1920 × 240 |
| 4:1, compact banner | 960 × 240 · 1440 × 360 · 1920 × 480 |
| 3:1, promo or intermission | 960 × 320 · 1440 × 480 · 1920 × 640 |

Use **Highground-Twitch-Banner-960.webm** at **960 × 144** on a 1920 × 1080 scene.
This is a **20:3** ratio and covers **6.7%** of the screen's area. Suggested
bottom-right position: **936, 912**, leaving a 24-pixel margin. Place it opposite
the webcam. See [streamer setup](START-HERE.txt) and
[placement preview](previews/Placement-1080p.png).

Both WebM sizes use VP9 with alpha, 25 fps, six seconds and no audio. Enable Loop
in the [OBS Media Source](https://obsproject.com/kb/media-sources). The GIF loops
automatically and has binary transparency; WebM and PNG preserve smooth alpha.

| Deliverable | Size | Use |
| --- | --- | --- |
| Highground-Twitch-Banner-960.webm | 960 × 144 | Recommended OBS overlay |
| Highground-Twitch-Banner-1600.webm | 1600 × 240 | Larger scenes |
| Highground-Twitch-Banner-960.gif | 960 × 144 | Animated fallback and sharing |
| Highground-Twitch-Banner-960.png | 960 × 144 | Static overlay |
| Highground-Twitch-Banner-1600.png | 1600 × 240 | High-resolution static overlay |

The copy describes the main Highground addon: World of Warcraft PvP,
battlegrounds, arenas and duels, bounties, macros, Retail, WoW Forever,
Cataclysm Classic, free on CurseForge, made by kemicofa. It is based on the
[addon README](../../addons/Highground/README.md) and
[CurseForge listing](https://www.curseforge.com/wow/addons/highground).

## Source and rebuilding

Artwork, animations and ZIP exports are stored with Git LFS. After cloning the
repository, run `git lfs pull` to download the full assets before using or
rebuilding them.

- [banner.svg](source/banner.svg): editable layout, copy, tags and gold trim.
- [backdrop.png](source/backdrop.png): texture generated with the built-in
  **imagegen** tool; [exact prompt](source/imagegen-prompt.txt).
- [crest-spin.webm](source/crest-spin.webm): lossless VP9 alpha master derived
  from the original 150 Blender render frames in
  `/home/kemicofa/Downloads/highground-spin/renders/`. The original scene and
  exports remain unchanged. The old lettering below the crest was cropped out;
  the author credit now appears as larger, stationary banner copy.
- Typography: the repository's Barlow Condensed fonts and their existing
  [SIL Open Font License](../../libs/HighgroundKit/media/OFL-barlow.txt).

From the repository root, with Python 3, FFmpeg, ImageMagick and librsvg:

```sh
python3 tools/export_stream_banner.py
python3 tools/export_stream_banner.py --variant horde
```

To regenerate both complete format packs:

```sh
python3 tools/export_banner_formats.py --variant both
```

The format exporter uses `gifsicle` for compact GIFs when available, with
ImageMagick as a fallback. `--gifsicle /path/to/gifsicle` selects a local binary.
The full-resolution `source/crest-spin-hd.webm` supplies the larger crest layouts.
The original slim exporter rebuilds the small legacy pack; run the format
exporter last to deliver all 45 files per color.

For layout work, add `--stills-only`. To recreate the portable crest master from
the original Blender renders, add `--import-renders /path/to/renders`.
Fontconfig exposes the repository fonts only during export; no system fonts are
installed. The large intermediate `source/master.mkv` and rendered `plate.png`
are ignored by Git.

The stream assets live outside the addon folders and are not included in game
release packages. No addon code or release metadata was changed.

## Export validation

The [format-pack verification](formats/verification.json) checks all 45 Alliance
exports; the [Horde report](horde/formats/verification.json) covers its 45 files.
Each ratio has exactly three sizes, with every animation decoded and checked
for six-second duration, 150 frames, transparency, stationary copy and looping.

The [verification report](source/export-verification.json) records dimensions,
sizes, alpha decoding and six-second duration. Both videos decode to 150 frames
at 25 fps and contain no audio. The GIF has 150 frames, an infinite loop and
unchanged copy throughout. Front, edge-on, reverse and closing poses were
visually inspected, along with the banner at its intended 960 × 144 size.
