# Changelog

Release versions match both addon TOC files. The latest version is listed first.

## [0.5.2] - 2026-11-04

- Maintenance release alongside Highground's marker update. This addon's features and saved settings are unchanged.
- Existing installations can use `/reload` after updating; this release adds no addon files.

## [0.5.1] - 2026-11-01

- Class Colors is now the default theme. Explicit saved theme choices are preserved; Highground, Ember, Parchment and Azeroth remain selectable.
- Updating from the previous release needs only `/reload`. Restart WoW if your installed version predates Class Colors.

## [0.5.0] - 2026-11-01

- New optional **Class Colors** theme: choose it in settings or use `/hga theme classcolors`.
- Class colour now spans each arena enemy row and stays visible as health falls or an opponent goes unseen.
- Custom class colors are respected. Class tints keep text readable, while target/focus cues and status indicators retain their meaning.
- Existing themes and saved layout, text-size and opacity settings remain available. The theme switches immediately, including in combat.
- Restart WoW after updating; this release adds a theme file, so `/reload` is not enough.

## [0.4.0] - 2026-11-01

- **Enemy stealth alerts:** observed opponents entering and leaving stealth now produce chat notices and distinct versions of the in-game stealth sound: lower-pitched on entry, higher-pitched on exit.
- Use `/hga alerts` → **Customize categories** → **Enemy stealth** to control text and sound. Alert presets and the arena panel switch are respected; Vanish followed by Stealth produces one enter alert.
- Cataclysm Classic reads applications and removals from the combat log. Retail uses readable enemy casts and reappearance; WoW Forever has no arenas.
- Restart WoW after updating; this release adds addon files, so `/reload` is not enough.

## [0.3.2] - 2026-11-01

- Stronger standard class colors make Rogue yellow easier to distinguish from Priest white.
- Class-colored text keeps its hue when adjusted for contrast, including on the Parchment theme. Custom class colors remain respected.
- Existing installations can use `/reload` after updating; this release adds no addon files.

## [0.3.1] - 2026-10-31

- Fixed blank rows in match history, including empty lists and enlarged text sizes. Only available records are shown.
- Existing installations can use `/reload` after updating; this release adds no addon files.

## [0.3.0] - 2026-10-30

- **Simpler settings:** the arena panel and preview are easy to find; More settings reveals detailed controls and match history.
- **Match history:** Undo delete restores a removed match. Clear search and improved paging keep records readable at larger text sizes.
- Tooltips explain focus, trinkets and estimated diminishing-return and interrupt timers in plain language.
- Restart the game after updating; the settings now include an additional file.

## [0.2.0] - 2026-10-30

- **Arena activity:** fixed A1–A3 labels on Retail and up to A1–A5 on Cata match macro targets. Rows now show casts and crowd control; Retail restricted durations go straight to the display.
- **Cata:** observed diminishing returns and interrupt cooldown estimates. Talents and resets can change the base interrupt cooldowns.
- **Trinkets:** ready and expired cooldown sweeps stay hidden instead of being shown again by row refreshes.
- `/hga history` saves observed match results and available personal stats. `/hga alerts` opens alert presets and category controls.
- Refreshed Highground, Ember and Parchment themes, plus the new Azeroth theme. Text size, clearer focus and status labels, and Reduced motion apply across the interface.
- New files: after updating, restart the game instead of `/reload`.

## [0.1.2] - 2026-10-28

- Shared code updated with Highground 2.29.1; no change in this addon.

## [0.1.1] - 2026-10-28

- Shared code updated with Highground 2.29.0; no change in this addon.

## [0.1.0] - 2026-10-28

- First version on its own: Highground's arena enemy panel without the rest of Highground. `/hga` controls it.
- One row per opponent: left-click targets, right-click focuses, also in combat. Class, spec, health and target/focus marks.
- Each opponent's **PvP trinket** with its cooldown sweep.
- `/hga test` places the panel outside an arena; `/hga on` and `/hga off` switch it.
- Runs on Retail and Cataclysm Classic; loads on WoW Forever, which has no arenas.
