# Highground Horde Twitch overlay

A crimson-and-gold version of the slim Highground banner. The crest has a red
cloak and banners with gold Horde insignia, a red enamel reverse and warm rim
lighting. The backdrop, glow and tags use the same red palette. Gold lettering,
copy, layout, six-second spin and sparkle timing match the blue version.

All exports are unpacked in this folder:

**[Browse all five ratios and three sizes](formats/)** or open the
**[format comparison image](formats/Format-Guide.png)**. There are **45 banner
files**: 15 sizes, each as PNG, GIF and WebM.

| Ratio | Resolutions |
| --- | --- |
| 20:3 | 960 × 144 · 1600 × 240 · 1920 × 288 |
| 5:1 | 1400 × 280 · 1600 × 320 · 1920 × 384 |
| 8:1 | 960 × 120 · 1440 × 180 · 1920 × 240 |
| 4:1 | 960 × 240 · 1440 × 360 · 1920 × 480 |
| 3:1 | 960 × 320 · 1440 × 480 · 1920 × 640 |

The original slim exports are also available directly:

- [Animated GIF](Highground-Twitch-Banner-Horde-960.gif)
- [Static PNG, 1600 × 240](Highground-Twitch-Banner-Horde-1600.png)
- [Static PNG, 960 × 144](Highground-Twitch-Banner-Horde-960.png)
- [OBS WebM, 960 × 144](Highground-Twitch-Banner-Horde-960.webm)
- [OBS WebM, 1600 × 240](Highground-Twitch-Banner-Horde-1600.webm)
- [1080p placement preview](previews/Placement-1080p.png)

Use 960 × 144 on a 1080p stream, on the opposite side to the webcam. The banner
covers 6.7% of that frame. Both WebM exports have smooth alpha edges, 25 fps and
no audio; enable Loop in OBS. See [setup instructions](START-HERE.txt).
The [optional ZIP](Highground-Twitch-Banner-Horde-Pack.zip) is for sending to a
streamer; the images and videos above can be opened directly.

## Editable sources

- [Banner layout](source/banner.svg): the original layout with crimson colors.
- [Crest artwork](source/Highground-Horde-Artwork.png) and
  [backdrop](source/backdrop.png): edited using built-in **imagegen**;
  [exact prompts](source/imagegen-prompts.txt).
- [Packed Blender scene](source/Highground-Horde-Coin.blend): the original
  geometry and animation, retextured for Horde. Source artwork is packed.
- [Portable animation master](source/crest-spin.webm): lossless VP9 with alpha,
  used by the banner exporter without requiring Blender.
- [Export verification for all 45 files](formats/verification.json).

From the repository root:

```sh
python3 tools/export_banner_formats.py --variant horde
```

To rerender the 3D crest from the existing original rig:

```sh
blender -b /path/to/Highground_Coin.blend --python tools/render_horde_crest.py
python3 tools/export_stream_banner.py --variant horde --import-renders assets/stream-banner/horde/source/renders
python3 tools/export_banner_formats.py --variant horde
```

The blue exports and original Blender scene remain unchanged. Horde assets are
stored separately and are not included in the addon release ZIPs.
