# Addon logos

The seven PNGs in this directory are the original supplied artwork. The six
subaddon logos appear in their guide cards; `Highground.png` is the wrapper's
branding artwork and has no separate feature-guide card.

`transparent/` holds the background-free PNGs produced with the built-in
imagegen tool. The outer navy/black background is transparent; the artwork,
lettering and dark details inside each crest remain. See [edit prompts](PROMPTS.md).

The game loads 256 × 256, 32-bit RGBA, uncompressed TGA copies from
`addons/Highground/assets/logos/`, about twice their largest 120-unit draw
size. Both Highground TOCs include these assets in release packages.

Regenerate them from the transparent PNGs with ImageMagick:

```sh
python3 tools/export_textures.py logos
```
Originals and transparent PNGs stay in the repository; only game textures ship
with the addon.
