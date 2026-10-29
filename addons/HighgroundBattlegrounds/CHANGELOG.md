# Changelog

Release versions match both addon TOC files. The latest version is listed first.

## [0.2.0] - 2026-10-29

- Map: enemies with no known position are no longer lined up at the left edge. Without even a rough spot, they are left off the map instead of guessed.
- Map: enemy pins turn greyer, fainter and smaller the longer it has been since they were seen there, fastest in the first half minute.
- Silvershard Mines (Retail): both graveyards are on the map with resurrection timers. The enemy's comes from their spirit guide, a shared clock, or enemies seen alive again after dying.
- Enemies seen alive again after dying now estimate the enemy wave on maps with one graveyard per faction, even without a position. A player's resurrection, Reincarnation or Feign Death is not counted.

## [0.1.2] - 2026-10-28

- Shared code updated with Highground 2.29.1; no change in this addon.

## [0.1.1] - 2026-10-28

- Shared code updated with Highground 2.29.0; no change in this addon.

## [0.1.0] - 2026-10-28

- First version on its own: Highground's battleground tools without the kill order. `/hgbg` shows its status, `/hgbg config` its settings.
- Runs on Retail, WoW Forever and Cataclysm Classic.
- **Resurrection timers** for both teams' graveyards and the resurrection alert, with its health and timing thresholds on the settings page.
- **Captures and win prediction** in the objective panel; on Cataclysm Classic, the capture alert and capture bars over nameplates.
- **Flag carrier panel** (target and focus in combat) and Blizzard's carrier frames hidden while it shows.
- **Enemy positions on the map** and sharing with teammates who run Highground or Highground Battlegrounds.
- Sap calls for rogues, the quest tracker hidden in battlegrounds, and switches for each battleground size.
- `/hgbg test` previews the windows so you can place them outside a battleground.
