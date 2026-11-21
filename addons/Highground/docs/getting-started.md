# Getting started

[Documentation](README.md) · [Highground overview](../README.md)

## Install

**CurseForge app:** search for **Highground** ([project page](https://www.curseforge.com/projects/1749115)) and install it. The app keeps it updated. CurseForge and GitHub ship the same files.

**By hand:**

1. Download the ZIP from [GitHub Releases](https://github.com/kemicofa/highground/releases/latest).
2. Open your game folder (the one with the game executable) and extract `Highground`, `HighgroundBountyData` and `HighgroundReputationData` from the ZIP into `Interface/AddOns/`.
3. To update, replace the old addon folders with the extracted folders so removed files do not linger. Keep your `WTF/` saved settings.

The folders must be named **Highground**, **HighgroundBountyData** and **HighgroundReputationData**, with their TOC files directly inside each folder. Keep all three addons enabled in the game's AddOns list.

**From source:** keep the repository intact and link all three addon folders into `Interface/AddOns/`. Highground's `libs/` and `features/` links need the rest of the repository. See the [source installation commands](../../../docs/monorepo.md#source-installation), or [build a ZIP](../../../docs/releases.md#local-build) containing ordinary files.

**Restart the game** after installing or updating so addon folders and manifest entries are loaded.

## Supported clients

| Client | Manifest | Declared interfaces | Default battleground scope |
| --- | --- | --- | --- |
| Retail | [Highground.toc](../Highground.toc) | 120100, 120105 | All battlegrounds |
| WoW Forever | [Highground.toc](../Highground.toc) | 16001 | All battlegrounds |
| Cataclysm 4.4.2 | [Highground_Cata.toc](../Highground_Cata.toc) | 40402 | All battlegrounds |

WoW Forever runs the Retail client, so it uses the Retail manifest and its addon limits. Highground detects it from the interface number and loads its own classes and talent trees. Cataclysm shows more, because it lets addons read enemy health, specs and the combat log.

On Cataclysm, Highground also guards Blizzard's character pane: missing Death Knight rune or hit data can make it fail, and Highground hides the affected stat row until the data returns.

See [battleground coverage](battlegrounds.md) for supported maps.

The scope above controls battleground tools. Nearby enemies, bounties and macros also work outside battlegrounds. The Arena panel covers arenas and duels on Retail and Cataclysm Classic, and duels on WoW Forever. **Include unrated battlegrounds** in **Panels and features → Battleground** controls ordinary matches. New installations enable it on every client. Upgrades also enable it once for the account and saved setups; later scope choices are kept.

**Only the macros?** [Highground Macros](../../HighgroundMacros/README.md) is the macros window on its own (`/hgm`), without the battleground board. It also runs on Classic Era and The Burning Crusade (Anniversary). Install it from [CurseForge](https://www.curseforge.com/projects/1769615). Highground already includes the macros, so you don't need both.

## First steps

On WoW Forever, each character's first login after installing the community-invite update offers an invitation to the **Highground** in-game community. Horde characters receive the **EU · Horde** invitation; Alliance characters receive the **EU · Alliance** invitation. Each faction's community works across rulesets, so your ruleset does not change the invitation. Choose **Join community** to see your faction's link selected for copying. Copy it with Ctrl+C (Cmd+C on Mac), click **Open join window**, paste the link into Blizzard's invite field and click its **Join** button. Blizzard does not expose a supported way for addons to prefill that field or accept the invitation. If the window cannot be opened, use WoW's **Guild & Communities → Join Community** menu and paste the same link. **Not now**, X or Escape dismisses the automatic offer for that character across reloads and later updates. Each other character gets its own offer. You can reopen it at any time from **`/hg` → Home → Join community**. The popup waits while you are in combat, in an instance or using another Highground window, and until your faction is known. This invitation is only available on WoW Forever.

Highground is ready after installation. On your first login, **Pick a guide** shows each available addon's logo with a small gold **Start** button: Highground, Macros, Bounties, Battlegrounds, Nearby, Arena & duels and Reputation. Pick just the one you want. **Resume** returns to your saved place; **Replay** starts a completed guide again. **More guides** includes the enemy map, Quick calls, match history, appearance, alerts and profiles. No setup or profile is required.

Each guide uses the actual addon controls, highlights the next action and saves its own place. **Guides**, **Replay**, **Back** and **Next** stay in one compact row. Required page changes happen when you click the highlighted opener. **Enable in game** checkboxes save your normal-play preference. Sample enemies, messages and records are isolated; settings pages and the Macros save button clearly identify real changes. Escape or **Back to game** closes the guide. Reopen it with `/hg guide`, or jump directly with `/hg guide macros` or `/hg guide bounties`. Upgrades do not launch the guide automatically.

Guides explain one highlighted element at a time, with an arrow and short instructions. Enemy rows and status labels use your actual battleground panel and appearance settings. Only the sniper crosshair and healer crosses use a separate nameplate scene, because their live versions need nearby units. Samples stop when combat or a match starts. **More guides → Enemy map** opens WoW's world map at Warsong Gulch with five example enemies, using the normal map pins and tooltips. Hover to compare fresh, older and approximate sightings and the suggested-target ring. These observations never enter live tracking or group sharing. Leaving the guide restores the previous map; an unavailable map is reported without substituting a schematic.

Nearby walks through **History**, notes and **Add bounty** using sample records in the real windows. Quick calls, bounties and Reputation also use native controls with isolated examples; they do not send messages or submit live reports. Macros uses your real catalog and explains the optional **Use macro** action before saving anything. Settings and panel positions you change are kept.

**Bounties** offers two paths: **Post a bounty** follows the same three steps as live creation—**Target → Reward → Review**—with one kill and any finish as defaults, then covers **Review report** and recording payment; **Hunt a bounty** covers tracking a target and opening its automatically created report. The standalone wanted popup leads with the target and reward without scrolling; View bounty contains the full details. The guide explains confirmed killing blows, honor credit that may include assists, and the separate screenshot status. Custom conditions, sharing, gold settings and imports are optional. Each path follows one sample target and saves its own progress. Click the highlighted control or use **Next** to perform that sample action. **Back** retraces your steps and returns to the path choices at the start. `/hg guide bounties` opens these choices; `bounty_post` and `bounty_hunt` start a path directly.

1. **Join a battleground.** Your enemy list, timers and relevant flag-carrier panels appear automatically. Ordinary, unrated matches work too.
2. **Click an enemy's name to select them**, then use your abilities as usual. Highground suggests targets; it does not cast abilities for you. Right-click sets a *focus*: a second target you can keep while selecting someone else.
3. **Open `/hg` only when you want to change something.** Home explains which panels are enabled. **Preview and move panels** lets you drag examples outside a match; **Done** returns to the game.

New installations show five enemies, enable the target crosshair and Nearby enemies, use the **Essentials** alert level and keep panels locked. Nearby starts with five rows and sighting/stealth sounds enabled; its **Sound: on/off** button changes that preference. Burst markers, pressure shields, sap calls and low-health resurrection reminders start off. The quest tracker stays visible. Existing installations keep their choices; use `/hg nearby on` if Nearby was previously disabled.

**Panels and features** contains the main switches. Choose a group; **More options** reveals its detailed controls. **Appearance → Enemies shown** changes the list length. Every setting saves automatically. **Feature guide** (also `/hg checklist`) covers panel placement, enemy rows, targeting and markers, battleground objectives, map intel, callouts, arena, Nearby, bounties, macros, histories, player reputation, features and appearance, alerts and profiles. **Saved setups** contains playstyle presets and reusable profiles.

In `/hg setup`, choose a playstyle, then adjust **World target marker** and **Healer markers** before applying it. Damage enables both by default. The target marker is a sniper crosshair; healer crosses are green for friendly healers with a known role and red for known enemy healers. Markers need visible nameplates (V for enemies, Shift+V for friends). `/hg test` uses your selected settings; `/hg sniper` toggles the crosshair later.

**For a first macro:** open **Macros → For my class**, choose a target from the written menu, and click **Use macro**. Click **Open WoW macros**, then drag the saved icon onto an action bar. Press that action-bar button to use it. A focus macro needs a focus first: select a player and type `/focus`.

Every command is listed in [commands](commands.md). The [user guide](user-guide.md) explains the panels and settings.

## Saved settings

| Variable | Storage | Contents |
| --- | --- | --- |
| `HighgroundDB` | `WTF/Account/<account>/SavedVariables/Highground.lua` | Account settings, profiles, personal/guild/community bounties and histories |
| `HighgroundCharDB` | `WTF/Account/<account>/<realm>/<character>/SavedVariables/Highground.lua` | This character's panel positions, automatic profiles and community invitation dismissal |
| `HighgroundBountyNetworkDB` | `WTF/Account/<account>/SavedVariables/HighgroundBountyData.lua` | Shared bounty identity, contributions and claims |
| `HighgroundReputationNetworkDB` | `WTF/Account/<account>/SavedVariables/HighgroundReputationData.lua` | Native organization opt-ins, player reports and moderation history |

These survive addon updates. Preserve HighgroundBountyData's saved variables when switching between Highground, Highground Nearby and Highground Bounties; preserve HighgroundReputationData's when switching between Highground and Highground Reputation. See [shared bounties](user-guide.md#shared-bounties) and [Reputation storage](../../HighgroundReputation/README.md#sharing-and-storage).

## Coming from Warboard

Highground was called Warboard. It is a new addon folder with new settings: delete the old `Interface/AddOns/Warboard/` folder, and set your options again. Commands are now `/hg` and `/highground`, and macros that click its buttons use the new names (`/click HighgroundTargetButton`).
