# Addon logos

The seven PNGs in this directory are the original supplied artwork. The six
subaddon logos appear in their guide cards; `Highground.png` is the wrapper's
branding artwork and has no separate feature-guide card.

`transparent/` holds the background-free PNGs produced with the built-in
imagegen tool. The outer navy/black background is transparent; the artwork,
lettering and dark details inside each crest remain. See [edit prompts](PROMPTS.md).

The game loads 512 × 512, 32-bit RGBA, uncompressed TGA copies from
`addons/Highground/assets/logos/`. Both Highground TOCs include these assets in
release packages. Keep the alpha channel when regenerating them.

To regenerate a game texture from the repository root with ImageMagick:

```sh
magick assets/addon-logos/transparent/Macros.png -resize 512x512 -depth 8 -type TrueColorAlpha -compress none addons/Highground/assets/logos/Macros.tga
```

Repeat for Bounties, Battlegrounds, Nearby, Arena, and Reputation.
Originals and transparent PNGs stay in the repository; only game textures ship
with the addon.
