# Wanted poster artwork

The One Piece theme follows the supplied wanted-poster reference: weathered cream paper, condensed serif capitals, a wide portrait, tightly stacked lettering and side scroll ornaments. All player names, rewards and controls remain live addon text. The original Classic theme remains selectable in bounty settings.

`source/paper.png` was generated with the built-in image-generation tool using the supplied poster only as a paper-style reference. The exact final prompt is in [source/imagegen-prompt.txt](source/imagegen-prompt.txt). It contains no character artwork or lettering. `source/scroll.svg` is the editable vector source for the side ornaments.

The three Wanted fonts are renamed, modified derivatives of [Bodoni Moda from Google Fonts](https://github.com/google/fonts/tree/main/ofl/bodonimoda), copyright 2020 the Bodoni Moda Project Authors, under the SIL Open Font License. The original variable font, metadata and license are retained in `source/`. The derivatives use weight 800, optical size 6, compressed widths and cap-height metrics. Lowercase characters map to capitals in the font, so the underlying player names retain their original spelling and case.

Rebuild with `python tools/build_wanted_assets.py` from the repository root. This requires fontTools and ImageMagick locally; neither is a runtime dependency. The script produces these assets in `libs/HighgroundKit/bounty/media/`:

- `WantedDisplay.ttf`, `WantedName.ttf`, `WantedCaption.ttf`
- `WantedPaper.tga`, `WantedScroll.tga`
- `OFL-wanted.txt`

Only Highground, Highground Bounties and Highground Nearby package this folder. The font advances in `tools/wowsim/poster_fonts.lua` are generated for local layout previews and are not shipped.

Fully quit and restart WoW after installing these new files. A UI reload cannot discover new fonts and textures. Browser previews use simulated frame geometry and approximate native text/portrait rendering; confirm the final appearance in the client.

## Next visual pass

Work was checkpointed on 2026-11-22 before implementing the latest screenshot feedback. `Pictures/shot-2026-11-22_01-07-09.png` shows the new assets loaded, but the client truncates the heading to `WAN...` and the player name to `SANNY HIGHGR...`. The browser preview did not reproduce this. The issue remains unresolved in this checkpoint.

Investigate `Print` in `PosterStyle.lua`: it measures with `GetStringWidth` after setting width to zero, which can measure constrained text rather than the complete label. Use unbounded measurement where the client provides it and a safe unconstrained measurement fallback for older clients. Reset previous height/anchor constraints and leave a small allowance for native font rounding. Add a regression that simulates constrained native measurements; recheck the actual client before claiming the truncation is fixed.

Once text fits, compare proportions against `Downloads/180px-SB_Ruffy_1Mrd.jpg`: the reference portrait occupies about 80% of the paper width, with a height of about 74% of that portrait width. Its heading has more top margin than the current client screenshot. Keep One Piece as the default and preserve the Classic choice.
