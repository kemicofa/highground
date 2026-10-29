# Commands

[Documentation](README.md) · [Highground overview](../README.md)

This page mirrors [config/Commands.lua](../config/Commands.lua): the same list `/hg help` prints and the **Test and commands** page shows. `/highground` works like `/hg`. An unknown command prints the help. Words in capitals are values you type; `a|b` means one of them. Rows marked (Cata) exist only on Cataclysm.

`/hg config PAGE` takes a page name from the Highground window sidebar, such as `appearance` or `features`.

Standalone addons use their own command prefixes; see their [README command lists](../../../docs/README.md#players).

## General

| Command | What it does |
| --- | --- |
| `/hg` | Open or close the Highground window |
| `/hg help` | Every command in chat, with your detected spec |
| `/hg config [PAGE] \| config blizzard` | Highground window on a page; the Blizzard settings panel |
| `/hg options` | Same as /hg config |
| `/hg setup` | Guided role selection and panel placement |
| `/hg checklist` | Open or resume your setup checklist |
| `/hg alerts` | Alert presets and separate text and sound controls by category |
| `/hg lock \| unlock` | Lock panels, or show headers to drag outside combat |
| `/hg reset \| timers reset` | Move the main panel back; restore battleground panel spacing |
| `/hg scale 0.8 \| opacity 45 \| rows 8` | Panel scale, background opacity, enemy rows shown |
| `/hg compact [on\|off]` | Slim one-line layout |
| `/hg sound` | Mute or unmute every Highground sound |
| `/hg theme [NAME]` | List the themes, or switch to one (also on the Appearance page) |

The main panel's cogwheel, Home and the minimap's right-click menu also offer **Unlock panels** / **Lock panels**. Unlocking shows draggable headers, including in Frameless mode. Move panels outside combat; locking hides Frameless headers again.

## Targets

| Command | What it does |
| --- | --- |
| `/hg priority on\|off` | Target recommendations |
| `/hg call [s\|i\|raid\|party\|y]` | Call the kill target in chat, or pick the channel |
| `/hg mark icon 1-8 \| mark ping TYPE` | What the mark key does: a raid icon or a ping |
| `/hg why` | Why the kill target was chosen |
| `/hg live` | Reorder rows by live priority |
| `/hg all` | Also turn on in unrated battlegrounds |
| `/hg kit` | Tracked cooldowns of your target (Cata) |
| `/hg exec PCT` | Execute health threshold (Cata) |

## Panels and previews

| Command | What it does |
| --- | --- |
| `/hg calls [incoming\|help\|clear\|escort] [COUNT] [LOCATION]` | Prepare an objective callout; press Enter to send |
| `/hg history` | Saved PvP results, personal stats and observed objective timelines |
| `/hg journal` | Search enemy encounters, add notes, mute alerts or place a bounty |
| `/hg test` | Main panel preview |
| `/hg arena on\|off\|test` | Arena enemy panel |
| `/hg nearby on\|off\|test\|clear\|forget` | Open-world nearby enemies; forget clears their saved history |
| `/hg intel on\|off\|test \| intel share on\|off` | Enemy map positions and sharing |
| `/hg timers on\|off` | Battleground timers and capture tracking |
| `/hg sniper \| sniper why` | Target marker on or off; why it is not showing |
| `/hg sniper color NAME\|size X\|y N\|sound N` | Target marker colour, size, height and lock-on sound |
| `/hg sniper test \| go` | Target marker and kill-window previews |
| `/hg burst [test]` | Burst marker preview and recent burst buffs (Cata) |
| `/hg pressure on\|off\|test\|count N` | Teammate pressure shields (Cata) |

## Bounties

| Command | What it does |
| --- | --- |
| `/hg bounty` | Open or close the bounty board |
| `/hg bounty add [GOLD] NAME [; note]` | Personal bounty; NAME can be "target" |
| `/hg bounty share NAME` | Prepare a bounty chat link for others to preview and import |
| `/hg bounty submit\|remove\|claim NAME` | Send to your guild, take down, or report a kill |
| `/hg bounty approve\|reject NAME` | Officers: review submissions |
| `/hg bounty claims` | Review kill claims and record approval or manual payment |
| `/hg bounty list\|sync\|test\|on\|off` | Print, ask the guild, preview, switch alerts |

## Macros

| Command | What it does |
| --- | --- |
| `/hg macros \| macros pvp\|pve\|build\|mine` | PvP or PvE macros for your class and game; build your own; your macros |
| `/hg macros export \| macros import` | Share your macros as a base64 string |
| `/hg macros history` | Review macro backups and undo changes made by Highground |
| `/hg macros presets` | WoW Forever: a preset for every spell you know with ranks, always cast at the highest rank |
| `/hg macros ranks` | WoW Forever: move every action button and macro up to your highest spell ranks |

## Tuning and profiles

| Command | What it does |
| --- | --- |
| `/hg profile save\|load\|delete NAME` | Named settings profiles |
| `/hg profile share [NAME]` | Draft a chat link to a saved profile or your current setup |
| `/hg export [NAME] \| import` | Share settings or a saved profile as a base64 string |
| `/hg points [NAME VALUE]` | Show or set a scoring value |
| `/hg weights \| weight NAME X` | Score multipliers |

## Troubleshooting

| Command | What it does |
| --- | --- |
| `/hg err \| clearerr` | Show or clear recorded errors |
| `/hg probe \| map` | What the addon reads from your target and this map |
| `/hg cap why\|probe\|clear` | Capture tracking diagnostics |

## Preview buttons

The **Test and commands** page has one button per preview. Each runs its command; click it again to stop.

| Button | Command | What it shows |
| --- | --- | --- |
| Main panel | `/hg test` | Enemy list and kill-target card with sample enemies |
| Target marker | `/hg sniper test` | Crosshair on any target with a visible nameplate |
| Kill window | `/hg go` | GO look and sound (with Main panel or Target marker on) |
| Arena panel | `/hg arena test` | Arena enemy team with trinkets |
| Nearby enemies | `/hg nearby test` | Open-world enemy list |
| Map pin | `/hg intel test` | Sample enemy pin on the world map |
| Burst marker | `/hg burst test` | Marker beside your target's nameplate (Cata) |
| Pressure shields | `/hg pressure test` | Shield badge on a targeted teammate or yourself (Cata) |
| Bounty alert | `/hg bounty test` | Bounty sound and center-screen message |
| Bounty board | `/hg bounty` | Open or close the bounty board |
| Macros | `/hg macros` | Ready-made PvP and PvE macros for your class, and a macro builder |

## Key bindings

Under **Key Bindings → AddOns → Highground**:

| Binding | Action |
| --- | --- |
| Target kill-order #1 | Target the recommended enemy |
| Focus kill target | Focus the recommended enemy |
| Ping/mark kill target | Ping or raid-mark it, as set by `/hg mark`; in a macro: `/click HighgroundMarkButton` |
| Call kill target in chat (press Enter to send) | Fill your chat box with a call, like `/hg call` |
| Open or close Highground | Same as `/hg` |
| Toggle the bounty board | Same as `/hg bounty` |
| Incoming / Help / Clear / Escort (press Enter to send) | Prepare the matching callout at your current location |
