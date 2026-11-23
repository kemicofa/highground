# Getting started

[Documentation](README.md) · [Highground overview](../README.md)

Highground runs on Retail, WoW Forever and Cataclysm Classic. One download contains Highground, its two required data addons and six module folders: Battlegrounds, Arena, Nearby, Bounties, Reputation and Macros. The former standalone addons are deprecated and receive no releases.

## Install

**Addon manager:** search for **Highground** on [CurseForge](https://www.curseforge.com/projects/1749115) or [Wago](https://addons.wago.io/addons/b6Xy3OKp) and install it. The manager keeps it updated. All sources ship the same files.

**By hand:**

1. Download the ZIP from [GitHub Releases](https://github.com/kemicofa/highground/releases/latest).
2. Fully quit WoW.
3. Extract every folder from the ZIP into `Interface/AddOns/` in your game folder: `Highground`, `HighgroundBountyData`, `HighgroundReputationData` and the six `HighgroundModule*` folders. Keep each folder's name, with its TOC file directly inside.
4. To update, replace the old folders so removed files don't linger. Keep your `WTF/` folder: it holds your settings.
5. Start WoW.

Keep **Highground**, **HighgroundBountyData** and **HighgroundReputationData** enabled. Highground does not load without both data addons.

**From source:** see [source installation](../../../docs/monorepo.md#source-installation), or [build a ZIP](../../../docs/releases.md#local-build).

## Choose addons

The AddOn List groups the six modules under Highground. Turn them on or off there or in `/hg` → **Addons**, then reload. Switches apply to the current character and keep your settings and records. `/hg guide addons` explains the switches without changing them.

Only want macros? Disable the other modules in `/hg` → **Addons**, reload, then open `/hg macros`.

## First steps

1. **Join a battleground.** The enemy list, timers and flag-carrier panels appear on their own, in rated and unrated matches.
2. **Click an enemy's name** to target them. Right-click sets your *focus*, a second target you keep while selecting someone else. Highground suggests targets; it never casts for you.
3. **Open `/hg` when you want to change something.** On **Home**, **Preview and move panels** shows sample panels you can drag outside a match; **Done** returns to Home.

On your first login, Highground opens **Addons**, outside combat and instances. Each addon has a guide: **Start**, **Resume** or **Replay** it, or **Visit** the addon's settings. Guides use the real controls with sample data and never send messages or create real records. Reopen them with `/hg guide`, or jump to one with `/hg guide macros` or `/hg guide bounties`.

More places to start:

- `/hg setup`: choose a playstyle preset (Minimal, Damage, Healer, Flag carrier or Caller), adjust the sniper and healer markers, then place your panels.
- `/hg bg test`: preview the battleground panels with your settings. `/hg test` previews every enabled addon that has a sample; run it again or use `/hg test stop` to stop.
- **A first macro:** open `/hg macros` → **For my class**, choose a target, click **Use macro**, then **Open WoW macros** and drag the saved icon to an action bar.
- **Help:** **Home → Join Discord** shows the [Highground Discord](https://discord.gg/xu3VsxRjca) invite to copy. On WoW Forever, each character is offered it once; **Not now** dismisses it.

New installations show five enemies, include unrated battlegrounds, enable the target crosshair and Nearby enemies (five rows, sounds on), use the **Essentials** alert level and keep panels locked. Burst markers, pressure shields, sap calls, the objective overview and low-health resurrection reminders start off. Updates keep your existing choices.

Markers above players need visible nameplates: V for enemies, Shift+V for friends.

The [user guide](user-guide.md) explains every panel and setting; [commands](commands.md) lists every command.

## Supported clients

| Client | Manifest | Interfaces |
| --- | --- | --- |
| Retail | [Highground.toc](../Highground.toc) | 120100, 120105 |
| WoW Forever | [Highground.toc](../Highground.toc) | 16001 |
| Cataclysm Classic 4.4.2 | [Highground_Cata.toc](../Highground_Cata.toc) | 40402 |

WoW Forever runs the Retail client with its addon limits; Highground detects it from the interface number and loads Forever's classes and talent trees. Cataclysm shows more because addons can read enemy health, specs and the combat log there. On Cataclysm, Highground also hides a character-pane stat row while Death Knight rune or hit data is missing, which would otherwise break Blizzard's pane.

Battleground tools run in every battleground by default; **Include unrated battlegrounds** in **Battlegrounds → Settings** controls ordinary matches. Nearby enemies, bounties and macros also work outside battlegrounds. The Arena panel covers arenas and duels on Retail and Cataclysm, and duels on WoW Forever. Classic Era and TBC are not supported. See [battleground coverage](battlegrounds.md) for supported maps.

## Moving from a standalone addon

The six standalone addons are deprecated: `HighgroundBattlegrounds`, `HighgroundArena`, `HighgroundNearby`, `HighgroundBounties`, `HighgroundReputation` and `HighgroundMacros`. Their features ship only in Highground.

1. Fully quit WoW and keep your `WTF/` folder, including SavedVariables.
2. Remove the old standalone folders, or uninstall them in your addon manager. **Highground → Addons** names any it detects, including disabled copies.
3. Install the complete Highground bundle.
4. Start WoW. Open `/hg` → **Addons**, choose your modules, and reload when prompted.

In WoW's AddOn List, **(module)** entries belong to the bundle, **(required data)** entries hold shared records and **(standalone)** entries are old separate downloads. Disabling a module does not activate a standalone copy.

Shared bounty identity, contributions and claims stay in `HighgroundBountyData`; shared reputation reports, decisions and preferences stay in `HighgroundReputationData`. Standalone panel settings, profiles, private and guild bounties and enemy histories stay in the old addon's SavedVariables and are not imported. Set up Highground's settings again.

## Saved settings

| Variable | File | Contents |
| --- | --- | --- |
| `HighgroundDB` | `WTF/Account/<account>/SavedVariables/Highground.lua` | Account settings, profiles, personal/guild/community bounties and histories |
| `HighgroundCharDB` | `WTF/Account/<account>/<realm>/<character>/SavedVariables/Highground.lua` | This character's panel positions, automatic profiles and Discord invitation dismissal |
| `HighgroundBountyNetworkDB` | `WTF/Account/<account>/SavedVariables/HighgroundBountyData.lua` | Shared bounty identity, contributions and claims |
| `HighgroundReputationNetworkDB` | `WTF/Account/<account>/SavedVariables/HighgroundReputationData.lua` | Organization opt-ins, player reports and moderation history |

These survive addon updates. See [shared bounties](user-guide.md#shared-bounties) and [Reputation storage](reputation.md#sharing-and-storage).

## Coming from Warboard

Highground used to be called Warboard. It uses a new folder and new settings: delete `Interface/AddOns/Warboard/` and set your options again. Commands are `/hg` and `/highground`; macros that click its buttons use the new names, such as `/click HighgroundTargetButton`.
