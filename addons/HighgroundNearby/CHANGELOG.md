# Changelog

Release versions match both addon TOC files. The latest version is listed first.

## [0.9.0] - 2026-11-04

- **Live nearby enemy count:** the **NEARBY: N** header counts distinct visible, living hostile players and updates on sightings, departures and once a second, including during combat and beyond the row limit. Enable it with `/hgn on`.
- The enabled counter stays visible at zero. Old rows and combat-log-only sightings keep their normal history without increasing the live count; clearing recent sightings leaves the counter running.
- Target, focus and mouseover sightings now stay fresh while visible. Pending combat rows count every enemy, including those beyond the row limit, while existing click bindings stay fixed.
- Restart WoW after updating; this release adds an addon file, so `/reload` is not enough.

## [0.8.2] - 2026-11-04

- Maintenance release alongside Highground's marker update. This addon's features and saved settings are unchanged.
- Existing installations can use `/reload` after updating; this release adds no addon files.

## [0.8.1] - 2026-11-01

- Class Colors is now the default theme. Explicit saved theme choices are preserved; Highground, Ember, Parchment and Azeroth remain selectable.
- Updating from the previous release needs only `/reload`. Restart WoW if your installed version predates Class Colors.

## [0.8.0] - 2026-11-01

- New optional **Class Colors** theme: choose it in settings or use `/hgn theme classcolors`.
- Class colour now spans each nearby enemy row, with readable names, sighting details and bounty indicators.
- Custom class colors are respected. Class tints keep text readable, while target/focus cues and status indicators retain their meaning.
- Existing themes and saved layout, text-size and opacity settings remain available. The theme switches immediately, including in combat.
- Restart WoW after updating; this release adds a theme file, so `/reload` is not enough.

## [0.7.0] - 2026-11-01

- **Stealth sounds:** nearby enemies entering stealth use a lower-pitched version of the in-game stealth sound instead of the raid-warning cue. Leaving stealth now plays a higher-pitched version.
- The nearby sound switch, alert presets, muted enemies and sound priorities are respected. Vanish followed by Stealth produces one enter alert.
- Cataclysm Classic reads applications and removals from the combat log. Retail and WoW Forever use readable enemy casts and reappearance.
- Restart WoW after updating; this release adds addon files, so `/reload` is not enough.

## [0.6.1] - 2026-11-01

- Stronger standard class colors make Rogue yellow easier to distinguish from Priest white.
- Class-colored text keeps its hue when adjusted for contrast, including on the Parchment theme. Custom class colors remain respected.
- Existing installations can use `/reload` after updating; this release adds no addon files.

## [0.6.0] - 2026-10-31

- **Start with a target:** `/hgn bounty` opens a bounty workspace with a three-step guide, **Create first bounty** and **Browse rewards**. **How it works** brings the guide back.
- **One window:** creation, details, claims, shared alert settings and suggestion reports stay inside the board. **Back to board** preserves your search and position; numbered forms explain audiences and what happens after saving.
- **Simpler navigation:** My bounties, Guild board and Shared board are the main views. Suggestions and settings are under **More tools**.
- **Hunt and get paid:** shared reward details lead to **Report kill** or **Add a reward**. **Claims & payments** explains review and payment through the game; Highground never transfers gold.
- Long forms scroll at enlarged text sizes while save controls stay available. Empty history and claims lists no longer show blank rows.
- Existing installations can use `/reload` after updating. Keep **HighgroundBountyData** enabled; this release adds no addon files.

## [0.5.0] - 2026-10-30

- **Bounty suggestions:** `/hgn bounty suggestions` finds recurring open-world attackers. Enable suggestions under `/hgn config` → **More settings**; sharing your attributed deaths with guild addons is a separate switch. Both start off, and Bounties must also be enabled.
- Defaults are **3 deaths against you**, or **5 deaths across 3 guild characters**, within **30 minutes**. Thresholds, the rolling window and notification cooldown are adjustable.
- **Reports** shows victims, times, locations and attribution sources. **Review bounty** opens an existing listing or a draft with the target, reason and audience filled in and reward left blank. Saving is explicit, and guild submissions keep officer approval.
- Notifications wait until combat ends. **Dismiss 24h** suppresses a target for a day; **Ignore enemy** lasts until **Show ignored → Allow again**. Recent reports and dismissals survive reloads and switching between the three bounty clients.
- Enemy history and suggestions count only attributable open-world deaths. NPCs, environmental deaths, duels, instanced deaths and ambiguous identities are skipped; unavailable game data can leave a death uncounted. Guild reports come from participating players and are not verified kill proof.
- Restart the game after updating; this release adds files, so `/reload` is not enough. Keep **HighgroundBountyData** installed and enabled.

## [0.4.0] - 2026-10-30

- **Quieter first use:** five enemy rows and quieter sighting alerts on new installations. Rows show the essentials; hover reveals guild and encounter details.
- **Enemy journal:** Undo delete restores a removed encounter. Clear search and paging stay readable at larger text sizes.
- **Simpler settings:** the panel switch, row count and sound appear first; More settings reveals fade times, history, stealth alerts and appearance.
- Optional bounty boards explain empty views and guide creation from player name to audience and reward.
- Restart the game after updating; the settings now include an additional file. Keep HighgroundBountyData installed and enabled.

## [0.3.0] - 2026-10-30

- **Enemy journal:** `/hgn journal` searches encounters by name, class, guild, area or note. Add notes, mute an enemy’s alerts or start a bounty.
- **Optional bounties:** `/hgn bounty` opens personal and guild bounties. `/hgn bounty shared` adds separate receiving and publishing opt-ins, stacked contributions, individual expiry and a minimum gold threshold for alerts.
- **Funding and claims:** posters report carried gold against outstanding commitments. `/hgn bounty claims` keeps claims and payment records. Funding reports do not guarantee payment; posters review claims and pay gold manually.
- Shared bounties work with Highground and Highground Bounties on the same realm and faction. Nearby stays inactive when Bounties is loaded, since Bounties already includes the nearby list.
- Refreshed Highground, Ember and Parchment themes, plus the new Azeroth theme. Text size, clearer focus and status labels, and Reduced motion apply across the interface.
- Keep the included **HighgroundBountyData** folder installed and enabled; it saves shared contributions, claims and your contributor ID when switching between Highground, Bounties and Nearby.
- New files: after updating, restart the game instead of `/reload`.

## [0.2.1] - 2026-10-28

- Shared code updated with Highground 2.29.1; no change in this addon.

## [0.2.0] - 2026-10-28

- **Stealth alerts** on the nearby enemies list: a chat line when a nearby enemy uses Stealth, Prowl, Vanish, Invisibility, Shadowmeld or Camouflage, and when it fades. Cataclysm Classic sees both in the combat log; Retail and WoW Forever see casts by enemies you can see, and call it faded when you see them again.
- **Enemy history**, saved per account: every enemy you meet, how many times, how often they killed you and you them. Someone you met before gets a chat line when they show up, and their row shows `met 3x  K1 D2`. On Retail and WoW Forever kills come from honorable kills and the death recap, when the game names the enemy.
- `/hgn forget` or **Forget history** in settings clears the history. Both have a switch in settings.
- New file: after updating, restart the game instead of `/reload`.

## [0.1.0] - 2026-10-28

- First version: Highground's nearby enemies list on its own, with `/hgn` and a settings page.
- Stays off when Highground is installed, which has the same list.
