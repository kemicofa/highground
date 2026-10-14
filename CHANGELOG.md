# Changelog

Release versions match both addon TOC files. The latest version is listed first.

## [2.11.1] - 2026-10-14

- Fix team colors in cross-faction battlegrounds. Your side now comes from your own scoreboard row as soon as it appears, not from your character's faction, so ours/theirs colors, objectives, flag carriers and the map are right from the start. Graveyard spots are only saved once your side is confirmed, and Eye of the Storm start areas saved under the wrong team are cleared and relearned.
- Fix the enemy panel showing another class's icon at match start, before an enemy's spec is known.
- Weigh enemy defensives by your damage type. Cloak, Spell Reflect and Anti-Magic Shell matter only against magic; Evasion, Hand of Protection and Combat Readiness only against physical. Mixed-damage specs (Ret, Enhancement, Frost DK, Survival) count each half. Smaller defensives such as Barkskin weigh less than Pain Suppression.
- Count Berserker Rage, Tremor Totem, Camouflage and Soulshatter as utility rather than defensives. Raise Cata healer kill value.

## [2.11.0] - 2026-10-12

- Turning off **Target recommendations** (or `/wb priority off`) now disables every priority output: panel, hero card, kill-order keybinds, GO sound and map kill mark. The world target marker no longer depends on it and follows your own hostile target instead.

## [2.10.0] - 2026-10-12

- Add an arena enemy panel: one row per opponent with class, spec, health and target/focus markers. Left-click targets, right-click focuses, including in combat. Toggle in settings or with `/wb arena on|off`; preview with `/wb arena test`.

## [2.9.0] - 2026-10-12

- Place more enemies on the battleground map instead of in the unknown column. Combat from teammates in group range uses your area. Enemies seen on roads or in unanchored areas are placed near the area the observer just left (15 seconds, approximate). Add Cata Warsong Gulch flag-room anchors.
- Fix a Cata character pane error (`PaperDollFrame_SetMeleeHitChance`: attempt to perform arithmetic on a nil value) when the client has no hit modifier yet. Melee, ranged and spell hit rows hide until valid data returns.
- Use named node claim, assault and defense announcements as timestamped enemy sightings. Faction-only ownership announcements do not refresh a player's location.
- Space grouped enemy markers using the displayed map size, and wrap unknown-position markers with compact labels so they remain readable on the small battlefield map.
- Place Gilneas enemy sightings at configured capture points when live landmarks are unavailable, including Mine/Mines naming. Add Cata starting-area anchors for Gilnean Stronghold and Horde Landing.
- Keep concurrent unlocated combat events from overriding positioned enemy sightings. Add Cata Arathi Basin area fallbacks and refresh partial landmark caches when POIs update.
- Exclude known full immunities and preserved breakable CC from kill recommendations; compare GO candidates only with eligible enemies.
- Delay defensive cooldown bonuses until protection is no longer active. Remove Barkskin's separate bonus/cap and the obsolete CC penalty controls.
- Add Target behavior settings and a current-target comparison. Show effective tuning values, including battleground modifiers.
- Validate tuning consistently in controls, commands, saved variables and profiles. Invalid imports preserve current settings; retired keys are discarded.
- Restore generic matchup adjustments for opponents missing from a custom matchup table, and remove the unused duplicate score calculation.

## [2.8.2] - 2026-10-10

- Removed the duplicate PvP trinket setting. Existing spell overrides move to the single trinket control, preserving the effective value in current settings, saved profiles and imports.
- Combined Cooldowns and Defensives into one page. Optional spell overrides are collapsed unless already customized; blank fields inherit the general default, and clearing a field or pressing x restores inheritance.
- Clarified the separate Balance/Feral Barkskin rules and the Restoration spell override. Removed non-editable external spells from the options.
- Grouped feature switches, showed their dependencies, and hid settings that do not apply to the current client. Renamed secondary scoring controls to Advanced multipliers and Reset all to Reset tuning.
- Fixed crowded profile buttons and spec-rating controls; kept long row labels from overlapping, with full descriptions on hover.
- Moved the settings catalog, page names, client visibility and legacy aliases into `config/Options.lua`.

Restart WoW after updating to load the new settings configuration.

## [2.8.1] - 2026-10-10

- Reduced the default scale of all HUD panels to 80%. Existing installations at the previous 100% default move to 80% once; custom scales are retained.
- Shortened the target/waiting card from 100 to 72 pixels before scaling, reducing its screen height by about 42% at the new default.
- Added UI scale controls directly to the main options page: minus/plus, an editable percentage, and a reset to 80%, with a 50–200% range.
- Applied scale changes consistently to the main, resurrection, objective and carrier panels, including carrier panels already on screen. Changes requested in combat apply when combat ends.
- Made the feature list scrollable so all settings remain reachable in smaller options windows.
- Kept the combat click-target warning clear of tactical details in the shorter card.

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
