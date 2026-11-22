# Layered sniper marker

Recreated with the built-in imagegen tool from the supplied `Glowing Skull Emblem Variations.png`, using the circular variation. The original reference is unchanged. Full prompts and the layer layout are recorded in [PROMPTS.json](PROMPTS.json).

The PNG sources have genuine alpha transparency and neutral white artwork so the addon can tint them without multiplying an existing gold or red color. Dark contours remain part of the artwork. The game loads separate 256 × 256, 32-bit, uncompressed RGBA TGA exports from `addons/Highground/assets/sniper/`.

| Layer | Position in a 52 px frame | Default tint | Behavior |
| --- | --- | --- | --- |
| `SniperReticle` | 52 × 52, centered | Gold; follows the saved sniper color | Upright |
| `SniperSkull` | 30 × 30, visible artwork centered | Ivory | Optional; always upright |
| `SniperAim` | 16 × 16, centered | Red | Fixed aiming point |

The skull's visible bounds (alpha greater than 32) center at (126.5, 123) in the 256 px texture. Its layer is offset by (+0.17578125, -0.5859375) UI pixels to place the visible artwork at the ring center; the previous downward displacement is removed. The aim point does not move when the skull is hidden.

The whole marker gently pulses by default: 2.4 s cycles to 88% alpha above 50% health; 1.8 s cycles to 80% alpha at 50% or less; 1.2 s to 65% alpha at 30% or less; 0.8 s to 55% alpha at 15% or less or during a GO window. Unknown/restricted health uses the default gentle pulse without GO, and dead/immune enemies do not pulse. Recommendation score alone is not a finishing cue. Reduced motion or disabling animation keeps full alpha. There is no rotation or zoom. Native WoW animation groups handle playback; repeated updates in one health band do not restart them.

Settings: **Features → Targets → More options → Skull in target marker / Animate target marker**. Commands: `/hg sniper skull on|off`, `/hg sniper animate on|off`, `/hg sniper color gold`, and `/hg sniper test`. Existing colors and placement settings survive the upgrade. New textures require a full WoW restart.

Placement: **Appearance → Sniper marker** provides Head area (approximate, default), Body (raised from -62 to -40 px), Left, Right and Above nameplate, plus edge gap, X/Y and size. `/hg sniper place head|left|right|above|body`, `/hg sniper padding N`, `/hg sniper x N` and `/hg sniper y N` expose the same settings. New placement choices restore their default height. The gap applies to left/right/above frame edges and is independent of marker size. Head placement follows the nameplate, not a live model bone, and can shift with camera angle and stacking. Existing custom heights are retained; untouched old body defaults upgrade to head placement.

**Marker style** on the same page offers **New icon (default)** and **Legacy crosshair**. `/hg sniper style layered|legacy` switches instantly. A live mini preview to the right of the dropdown reflects style, colour and skull preference; its native animation stops when hidden. Legacy preserves the original four crosshair arms, center dot, corner brackets and black outlines, using built-in white textures without the new artwork. Both styles share colour, placement, size and the health-based pulse. The skull preference is retained while using Legacy and restored when returning to the new icon. Style is saved in profiles and across reloads.

The **Ring / crosshair**, **Skull** and **Aiming mark / dot** colour buttons open the native RGB picker and update both the marker and mini preview immediately. Each has its own **Default** button; Cancel restores the previous setting. Custom colours remain during kill windows and survive profiles/reloads. Legacy uses the ring colour for its strokes and a custom aim colour for its center dot; without a custom aim colour, the dot keeps the original crosshair colour. The skull colour control is disabled in Legacy. `/hg sniper color ring|skull|aim HEX|default` accepts six hex digits, with an optional `#`. The original named ring-colour command still works. Colours decode only when changed; the render loop reuses one cached RGB table per layer.

API review: Blizzard's [nameplate API](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/NamePlateDocumentation.lua) provides a frame for a unit. The documented [model actor methods](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameAPIModelSceneFrameActorDocumentation.lua) operate on UI model actors. No supported live-world head/helmet attachment was found in these interfaces; the head preset is an estimate.

Export each source from the repository root, preserving alpha:

```sh
magick assets/sniper/SniperReticle.png -resize 256x256 -depth 8 -type TrueColorAlpha -compress none addons/Highground/assets/sniper/SniperReticle.tga
magick assets/sniper/SniperSkull.png -resize 256x256 -depth 8 -type TrueColorAlpha -compress none addons/Highground/assets/sniper/SniperSkull.tga
magick assets/sniper/SniperAim.png -resize 256x256 -depth 8 -type TrueColorAlpha -compress none addons/Highground/assets/sniper/SniperAim.tga
```

The inline preview uses the exported texture pixels, placement and timings. It is an approximation of the in-game animation, not an in-client capture.
