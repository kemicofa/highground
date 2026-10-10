# Changelog

Release versions match both addon TOC files. The latest version is listed first.

## [2.8.0] - 2026-10-10

- Redesigned the tactical HUD with a shared dark palette, clearer spacing and two-line enemy rows.
- Gave the kill-target card separate lines for identity, health, ally pressure and tactical details.
- Replaced single-letter status dots with readable labels including DEF, STUN/SIL, FLAG, BURST and NO TRNK.
- Rebuilt resurrection and objective rows with larger countdowns, subtle progress lines, urgent-time highlights and explanatory tooltips.
- Restyled flag carriers, teammate shields and map labels to match; your own shield remains left of your portrait.
- Added `config/UI.lua` for shared panel dimensions, spacing and colors. Saved panel positions and scale are retained; `/wb timers reset` applies the wider default spacing to the timer and flag panels.
- Reduced kill-window flashing while retaining the existing alerts and secure target/focus controls.

Restart WoW after updating to load the new UI configuration. Use `/wb test` to preview the main panel and `/wb pressure test` to preview a teammate shield.

## [2.7.6] - 2026-10-10

- Moved your enemy-focus shield to the left of your character portrait, keeping it on-screen when the portrait is near the edge.

## [2.7.5] - 2026-10-10

- Shortened graveyard map labels across battlegrounds, with full names on hover.
- Added battleground-specific abbreviations such as LH, WW, BS, LM, and FR.
- Added GitHub CI, installable addon ZIPs, checksums, and versioned releases with changelog notes.

Download `Warboard-2.7.5.zip` and extract its `Warboard` folder into `Interface/AddOns/`.
The package includes both Retail and Cataclysm configurations. Restart WoW after installation.

## [2.7.4] - 2026-10-10

- Added private shield markers for up to three teammates drawing the most observed enemy targets on Cata.
- Corrected Gilneas' two permanent starting graveyards and three ownership-controlled node graveyards.
- Made YOU identify a reported resurrection destination independently of whether its wave timer is known.

## [2.7.3] - 2026-10-10

- Corrected enemy map projections and separated exact positions from approximate or unknown sightings.
- Added four distinct, named Cata Twin Peaks graveyards with independent resurrection clocks.
- Prevented ambiguous observations and old learned positions from creating misleading graveyard pins.
