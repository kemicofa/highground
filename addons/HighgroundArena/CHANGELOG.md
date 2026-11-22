# Changelog

Release versions match both addon TOC files. The latest version is listed first.

## [0.7.6] - 2026-11-22

- Label the separate download as standalone in WoW’s AddOn List and explain that it is unnecessary when using the complete Highground bundle.
- Show the Highground icon beside the addon in WoW's AddOn List.

## [0.7.5] - 2026-11-21

- Keep names without a realm suffix on the current Forever ruleset when the game does not provide a realm name.

## [0.7.4] - 2026-11-21

- Keep arena and battleground history with the current character, faction and realm or Forever ruleset. Switching characters restores their own results; duels remain excluded.
- Prevent match history and Undo delete from carrying stale actions into another character or context. Include the shared window-heading layout fix.
- Older match records without ownership information remain saved but are not assigned to the current character. New matches start a correctly attributed history.
- Restart WoW after updating to load the added shared module; /reload is not enough.

## [0.7.3] - 2026-11-21

- Keep duel requests, countdowns and active fights consistent through repeated notifications and leaving or returning to bounds.
- Clear duel state when changing worlds, cancelling or finishing a duel. Only unanswered challenges expire automatically.
- Use /reload after updating from 0.7.2; this release adds no addon files.

## [0.7.2] - 2026-11-20

- Update the shared UI package alongside the bounty workflow release. This maintenance update does not add or change arena or duel features.
- Restart WoW after updating to load the new shared UI files and artwork; /reload is not enough.

## [0.7.1] - 2026-11-20

- Reduce memory used by window controls and repeated UI updates while idle.
- Avoid repeatedly refreshing unchanged names, class colours and layout in arena and duel panels.
- Restart WoW after updating to load the new shared control texture; /reload is not enough.

## [0.7.0] - 2026-11-20

- Add shared dialog navigation, refreshed controls and optional idle panel transparency; text and combat clicks remain readable and usable.

- Activate for duel challenges and countdowns on WoW Forever, Retail and Cata; clear on cancellation or completion.
- Keep one named duel opponent through target changes and stealth, with secure target/focus clicks prepared before combat.
- Use a compact duel row, shorter labels and help, and a one-opponent Forever preview. Hide arena slot labels in duels.
- Replace the faint full-row health tint with a solid health bar and enlarge the class/spec/CC icon to 44 pixels. Layout follows text size; text beneath health appears only for casts or crowd control.
- Remove redundant class/spec text. Forever can infer spec icons from readable self-cast talent buffs and successful casts, using its own spell/rank data. Prefer deeper talent clues; equal conflicting clues retain the class icon. Tooltips distinguish estimates from confirmed arena specs.
- Show client-reported trinket timing when available, including for the exact duel opponent. Mark unavailable timing with **?** instead of implying readiness. WoW Forever duel tracking is not guaranteed.
- Restart WoW after installing this update to load the new modules.

## [0.6.1] - 2026-11-18

- Prevent false stealth-exit alerts while an opponent still has a hiding aura or aura data is unreadable.
- Use /reload after updating from 0.6.0; this release adds no addon files.

## [0.6.0] - 2026-11-18

- Redesigned Highground as the default theme: midnight blue steel, forged gold, ivory titles and persistent class colours.
- Added metal frame details, persistent opponent class surfaces and readable health lines. Ivory target and blue focus edges have separate labels, and unknown health stays faded.
- Class Colors remains available with stronger tinting. Explicit saved themes, custom class colours, fonts, opacity, positions and reduced motion are retained.
- Restart WoW after updating to load the bundled crest texture.

## [0.5.3] - 2026-11-08

- Keep the arena panel cogwheel reachable while locked and in Frameless mode, with lock/unlock, arrangement, match history and settings in one menu.
- Restart WoW after updating; this release adds panel-control files, so `/reload` is not enough.

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
