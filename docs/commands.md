# Commands

[Documentation](README.md) · [Project overview](../README.md)

This page mirrors [config/Commands.lua](../config/Commands.lua): the same list `/wb help` prints and the **Test and commands** page shows. `/warboard` works like `/wb`. An unknown command prints the help. Words in capitals are values you type; `a|b` means one of them. Rows marked (Cata) exist only on Cataclysm.

`/wb config PAGE` takes a page name from the Warboard window sidebar, such as `appearance` or `features`.

## General

| Command | What it does |
| --- | --- |
| `/wb` | Open or close the Warboard window |
| `/wb help` | Every command in chat, with your detected spec |
| `/wb config [PAGE] \| config blizzard` | Warboard window on a page; the Blizzard settings panel |
| `/wb options` | Same as /wb config |
| `/wb lock \| unlock` | Keep panels in place, or drag them by their headers |
| `/wb reset \| timers reset` | Move the main panel back; restore battleground panel spacing |
| `/wb scale 0.8 \| opacity 45 \| rows 8` | Panel scale, background opacity, enemy rows shown |
| `/wb compact [on\|off]` | Slim one-line layout |
| `/wb sound` | Mute or unmute every Warboard sound |
| `/wb theme [NAME]` | List the themes, or switch to one (also on the Appearance page) |

## Targets

| Command | What it does |
| --- | --- |
| `/wb priority on\|off` | Target recommendations |
| `/wb call [s\|i\|raid\|party\|y]` | Call the kill target in chat, or pick the channel |
| `/wb mark icon 1-8 \| mark ping TYPE` | What the mark key does: a raid icon or a ping |
| `/wb why` | Why the kill target was chosen |
| `/wb live` | Reorder rows by live priority |
| `/wb all` | Also turn on in unrated battlegrounds |
| `/wb kit` | Tracked cooldowns of your target (Cata) |
| `/wb exec PCT` | Execute health threshold (Cata) |

## Panels and previews

| Command | What it does |
| --- | --- |
| `/wb test` | Main panel preview |
| `/wb arena on\|off\|test` | Arena enemy panel |
| `/wb nearby on\|off\|test\|clear` | Open-world nearby enemies |
| `/wb intel on\|off\|test \| intel share on\|off` | Enemy map positions and sharing |
| `/wb timers on\|off` | Battleground timers and capture tracking |
| `/wb sniper \| sniper why` | Target marker on or off; why it is not showing |
| `/wb sniper color NAME\|size X\|y N\|sound N` | Target marker colour, size, height and lock-on sound |
| `/wb sniper test \| go` | Target marker and kill-window previews |
| `/wb burst [test]` | Burst marker preview and recent burst buffs (Cata) |
| `/wb pressure on\|off\|test\|count N` | Teammate pressure shields (Cata) |

## Bounties

| Command | What it does |
| --- | --- |
| `/wb bounty` | Open the bounty board |
| `/wb bounty add [GOLD] NAME [; note]` | Personal bounty; NAME can be "target" |
| `/wb bounty submit\|remove\|claim NAME` | Send to your guild, take down, or report a kill |
| `/wb bounty approve\|reject NAME` | Officers: review submissions |
| `/wb bounty list\|sync\|test\|on\|off` | Print, ask the guild, preview, switch alerts |

## Macros

| Command | What it does |
| --- | --- |
| `/wb macros \| macros build\|mine` | PvP macros for your class and game; build your own; your macros |
| `/wb macros export \| macros import` | Share your macros as a base64 string |

## Tuning and profiles

| Command | What it does |
| --- | --- |
| `/wb profile save\|load\|delete NAME` | Named settings profiles |
| `/wb export [NAME] \| import` | Share settings or a saved profile as a base64 string |
| `/wb points [NAME VALUE]` | Show or set a scoring value |
| `/wb weights \| weight NAME X` | Score multipliers |

## Troubleshooting

| Command | What it does |
| --- | --- |
| `/wb err \| clearerr` | Show or clear recorded errors |
| `/wb probe \| map` | What the addon reads from your target and this map |
| `/wb cap why\|probe\|clear` | Capture tracking diagnostics |

## Preview buttons

The **Test and commands** page has one button per preview. Each runs its command; click it again to stop.

| Button | Command | What it shows |
| --- | --- | --- |
| Main panel | `/wb test` | Enemy list and kill-target card with sample enemies |
| Target marker | `/wb sniper test` | Crosshair on any target with a visible nameplate |
| Kill window | `/wb go` | GO look and sound (with Main panel or Target marker on) |
| Arena panel | `/wb arena test` | Arena enemy team with trinkets |
| Nearby enemies | `/wb nearby test` | Open-world enemy list |
| Map pin | `/wb intel test` | Sample enemy pin on the world map |
| Burst marker | `/wb burst test` | Marker beside your target's nameplate (Cata) |
| Pressure shields | `/wb pressure test` | Shield badge on a targeted teammate or yourself (Cata) |
| Bounty alert | `/wb bounty test` | Bounty sound and center-screen message |
| Bounty board | `/wb bounty` | Open or close the bounty board |
| PvP macros | `/wb macros` | Ready-made macros for your class, and a macro builder |

## Key bindings

Under **Key Bindings → AddOns → Warboard**:

| Binding | Action |
| --- | --- |
| Target kill-order #1 | Target the recommended enemy |
| Focus kill target | Focus the recommended enemy |
| Ping/mark kill target | Ping or raid-mark it, as set by `/wb mark`; in a macro: `/click WarboardMarkButton` |
| Call kill target in chat (press Enter to send) | Fill your chat box with a call, like `/wb call` |
| Open or close Warboard | Same as `/wb` |
| Toggle the bounty board | Same as `/wb bounty` |
