# Changelog

Release versions match both addon TOC files. The latest version is listed first.

## [0.3.0] - 2026-10-30

- **Shared bounties:** `/hgb shared` has separate receiving and publishing opt-ins, both off initially. Contributions from different posters stack on the same target and last from five minutes to thirty days.
- **Funding and claims:** each poster reports carried gold against commitments. Your alert minimum uses rewards with recent available-funds reports. `/hgb claims` keeps claims and manual payment records; funding reports do not guarantee payment.
- **Bounty board:** My bounties, Guild board and Shared board views, search and an approval filter. Smaller rewards remain visible below those meeting your alert threshold. Guild and shared listings reuse one contribution and one claim history.
- **Chat sharing and previews:** Share in chat prepares a link for others to review and import. `/hgb test` runs local sighting and claim previews. Details open above the board, Use target fills the current target, and correcting an unaffordable reward clears its error.
- `/hgb journal` searches enemy encounters and lets you add notes or mute alerts. `/hgb alerts` offers category controls.
- Refreshed Highground, Ember and Parchment themes, plus the new Azeroth theme. Text size, clearer focus and status labels, and Reduced motion apply across the interface.
- Keep the included **HighgroundBountyData** folder installed and enabled; it saves shared contributions, claims and your contributor ID when switching between Highground, Bounties and Nearby.
- New files: after updating, restart the game instead of `/reload`.

## [0.2.1] - 2026-10-28

- Shared code updated with Highground 2.29.1; no change in this addon.

## [0.2.0] - 2026-10-28

- **Stealth alerts** on the nearby enemies list: a chat line when a nearby enemy uses Stealth, Prowl, Vanish, Invisibility, Shadowmeld or Camouflage, and when it fades. Cataclysm Classic sees both in the combat log; Retail and WoW Forever see casts by enemies you can see, and call it faded when you see them again.
- **Enemy history**, saved per account: every enemy you meet, how many times, how often they killed you and you them. Someone you met before gets a chat line when they show up, and their row shows `met 3x  K1 D2`. On Retail and WoW Forever kills come from honorable kills and the death recap, when the game names the enemy.
- `/hgb nearby forget` clears the history. Both have a switch in settings.
- New file: after updating, restart the game instead of `/reload`.

## [0.1.0] - 2026-10-28

- First version on its own: Highground's bounties without the rest of Highground. `/hgb` opens the bounty board.
- Runs on Retail, WoW Forever and Cataclysm Classic.
- **Personal bounties** alert you with a sound and a center-screen message when the target shows up, and put a gold coin beside their nameplate.
- **Guild bounties**: submissions, officer approval, shared sightings and kills, on the same guild messages as Highground.
- **Nearby enemies**: the open-world list of hostile players you have seen; `/hgb nearby` turns it on or off.
- Settings page (`/hgb config`) and a key binding for the board.
