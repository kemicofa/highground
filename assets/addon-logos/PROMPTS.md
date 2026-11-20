# Background-removal prompts

Mode: built-in `image_gen.imagegen`, with `transparent_background: true`.
Each addon was edited separately, using its original PNG as the sole edit target.

The shared prompt used for all seven files:

```text
Use case: background-extraction.
Asset type: existing World of Warcraft addon logo, transparent cutout for a guide card.
Input image 1 is the EDIT TARGET, not a style reference.
Primary request: remove ONLY the dark navy/black rectangular background outside the complete logo silhouette. Produce real alpha transparency around the crest, lettering, points and any protruding ornament.
Preserve the original logo artwork exactly: the full gold outer frame and spikes, all scene details INSIDE the crest, characters, icons, banners, colors, lighting, and all typography. Keep enclosed dark areas and shadows that belong to the emblem opaque. Preserve the original square composition, center position, scale, proportions and full uncropped silhouette.
Make a precise clean cutout with antialiased edges. No rectangular haze, no solid backdrop, no checkerboard painted into the image. Do not redraw, restyle, simplify, rearrange, add details, or change any lettering.
```

Each call appended:

```text
The logo is <name>. Keep every word exactly as printed in the input image.
```

| Input file | `<name>` | Saved transparent PNG |
| --- | --- | --- |
| `Highground.png` | Highground (main addon) | `transparent/Highground.png` |
| `Macros.png` | Highground Macros | `transparent/Macros.png` |
| `Bounties.png` | Highground Bounties | `transparent/Bounties.png` |
| `Battlegrounds.png` | Highground Battlegrounds | `transparent/Battlegrounds.png` |
| `Nearby.png` | Highground Nearby | `transparent/Nearby.png` |
| `Arena.png` | Highground Arena | `transparent/Arena.png` |
| `Reputation.png` | Highground Reputation | `transparent/Reputation.png` |

Game textures: `addons/Highground/assets/logos/<addon>.tga`.
Conversion and alpha-preservation instructions are in [README.md](README.md).

