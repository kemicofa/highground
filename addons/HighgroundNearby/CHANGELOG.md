# Changelog

Release versions match both addon TOC files. The latest version is listed first.

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
