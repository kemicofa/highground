# Highground Arena

[Repository overview](../../README.md) · [Documentation](../../docs/README.md)

An opponent panel for arenas and duels. On **WoW Forever**, Arena mode means **dueling**: the panel opens as soon as you send or receive a challenge, or the duel countdown starts.

- **Left-click targets; right-click focuses**, including during combat when the row was prepared beforehand.
- **Duels:** one compact row with a large class/spec icon, solid health bar, challenge/countdown status and casts. Crowd control temporarily replaces the icon. Changing targets keeps the same opponent. The panel clears on completion or cancellation.
- **Arena matches:** fixed **A1–A3** labels on Retail, up to **A1–A5** on Cata, with specs and PvP trinket cooldowns.
- **Stealth alerts:** distinct entry and exit sounds. Configure them in `/hga alerts`.

Names and classes stay visible when the opponent is unseen. Cata arena matches add diminishing returns and interrupt estimates. `/hga history` keeps arena and battleground results; duels are not recorded there.

**Spec icons:** confirmed arena specs take priority. On Forever, readable talent buffs and successful casts can identify a likely tree; deeper talent clues take priority, while equal conflicting clues keep the class icon. Only the duel opponent's own buffs and casts count. The tooltip explains the estimate; no class/spec text clutters the row. Without a usable clue, the class icon remains.

**Trinkets:** a cooldown sweep appears only when the client supplies timing. A dim icon with **?** means timing is unavailable, not ready. Duel tracking is not guaranteed on WoW Forever; the panel does not invent cooldowns from missing data.

## Install

**Using full Highground? This separate download is not needed.** We recommend uninstalling this standalone addon while using Highground. Keep Highground, its module folders and both required data addons. Close WoW before cleanup, then reinstall the complete Highground bundle and restart.

Install **Highground Arena** from [CurseForge](https://www.curseforge.com/projects/1770527), or extract its ZIP from [GitHub Releases](https://github.com/kemicofa/highground/releases) into `Interface/AddOns/`, then restart the game. The folder must be named `HighgroundArena`. When Highground is loaded, this addon stays inactive; use `/hg arena`. For a source checkout, follow [source installation](../../docs/monorepo.md#source-installation).

Settings, panel position and match history are saved per account in `HighgroundArenaDB`.

## Commands

| Command | What it does |
| --- | --- |
| `/hga` | Whether the panel is on. `/hgarena` works too |
| `/hga on`, `/hga off` | Enable or disable automatic arena and duel display |
| `/hga test` | Preview and move; again to hide. Forever previews one duel opponent |
| `/hga config` | Settings page |
| `/hga history` | Saved match results, stats and observed events |
| `/hga alerts` | Alert presets and category controls |
| `/hga theme NAME` | Highground, Ember, Parchment, Azeroth or Class Colors (`classcolors`) |
| `/hga help` | Command help in chat |

## Documentation and development

Its code is in `src/`; `libs/` links to the HighgroundKit library (packages get copies). Highground imports `src/` too. See [monorepo](../../docs/monorepo.md), the [arena guide](../Highground/docs/user-guide.md#arena-panel) and the [changelog](CHANGELOG.md).

If the first duel signal arrives during combat lockdown, secure rows appear when combat permits. Restart WoW after installing this update to load the new modules.

[MIT](LICENSE). Bundled font licenses are in [libs/media/](libs/media/); game-audio attribution is in [libs/sounds/stealth.txt](libs/sounds/stealth.txt).
