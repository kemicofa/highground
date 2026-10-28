# Changelog

Release versions match both addon TOC files. The latest version is listed first.

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
