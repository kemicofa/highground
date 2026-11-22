# Commands

[Documentation](README.md) · [Highground overview](../README.md)

This page mirrors [config/Commands.lua](../config/Commands.lua): the same list `/hg help` prints and the **Help and previews** page shows. `/highground` works like `/hg`. An unknown command prints the help. Words in capitals are values you type; `a|b` means one of them. Rows marked (Cata) exist only on Cataclysm.

`/hg config PAGE` takes a page name from the Highground window sidebar, such as `appearance` or `features`.

Standalone addons are deprecated; use the Highground commands below. Shared bounty subcommands and examples are explained in the [user guide](user-guide.md#shared-bounties).

## General

| Command | What it does |
| --- | --- |
| `/hg` | Open or close the Highground window |
| `/hg help` | Every command in chat, with your detected spec |
| `/hg config [PAGE] \| config blizzard` | Highground window on a page; the Blizzard settings panel |
| `/hg options` | Same as /hg config |
| `/hg setup` | Optional playstyle presets and panel placement |
| `/hg guide [FEATURE]` | Choose an addon guide, or start one directly (for example macros, bounties or nearby) |
| `/hg guide bounties` | Choose Post a bounty or Hunt a bounty, each with its own saved place |
| `/hg guide bounty_post` | Start or resume the posting and claim review guide |
| `/hg guide bounty_hunt` | Start or resume the hunting and claiming guide |
| `/hg checklist` | Alias for the feature guide |
| `/hg alerts` | Alert presets and separate text and sound controls by category |
| `/hg users` | Channel members and recent Highground announcements, versions and discovery status |
| `/hg guide users` | Try channel membership, departures and announcement fallback with sample data |
| `/hg users why` | Copy discovery diagnostics: messaging restrictions, channel membership and retry state |
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
| `/hg history` | Saved PvP results, personal stats and observed objective timelines |
| `/hg journal` | Search enemy encounters, add notes, mute alerts or place a bounty |
| `/hg test` | Main panel preview |
| `/hg arena on\|off\|test` | Arena and duel panel |
| `/hg nearby on\|off\|test\|clear\|forget` | Open-world nearby enemies; forget clears their saved history |
| `/hg intel on\|off\|test \| intel share on\|off` | Enemy map positions and sharing |
| `/hg timers on\|off` | Battleground timers and capture tracking |
| `/hg sniper \| sniper why` | Target marker on or off; why it is not showing |
| `/hg sniper color NAME\|size X\|y N\|sound N` | Target marker colour, size, height and lock-on sound |
| `/hg sniper color ring\|skull\|aim HEX\|default` | Set a component colour using six hex digits, or restore its default |
| `/hg sniper place body\|head\|left\|right\|above` | Choose marker placement; head is approximate and follows the nameplate |
| `/hg sniper style layered\|legacy` | New layered marker (default) or original legacy crosshair |
| `/hg sniper padding N\|x N\|y N` | Nameplate edge gap and horizontal/vertical offsets in UI pixels |
| `/hg sniper skull on\|off` | Show or hide the skull; the outer sight and aiming mark remain |
| `/hg sniper animate on\|off` | Gentle pulse by default, faster for low health or a kill window; Reduced motion overrides animation |
| `/hg sniper test \| go` | Target marker and kill-window previews |
| `/hg burst [test]` | Burst marker preview and recent burst buffs (Cata) |
| `/hg pressure on\|off\|test\|count N` | Teammate pressure shields (Cata) |

## Bounties

| Command | What it does |
| --- | --- |
| `/hg bounty` | Open or close the bounty board |
| `/hg bounty shared` | Shared realm/faction bounties, opt-ins, contribution durations and gold threshold |
| `/hg bounty shared add GOLD DURATION NAME` | Publish a pledge, for example 500 2h target; enable publishing first |
| `/hg bounty add [GOLD] NAME [; note]` | Personal bounty; NAME can be "target" |
| `/hg bounty share NAME` | Prepare a bounty chat link for others to preview and import |
| `/hg bounty export NAME` | Prepare a bounty link and post to copy outside the game |
| `/hg bounty import [CODE]` | Review a bounty link, code or complete post before importing |
| `/hg bounty submit\|remove\|claim NAME` | Send to your guild, take down, or report a kill |
| `/hg bounty approve\|reject NAME` | Officers: review submissions |
| `/hg bounty claims` | Review kill claims and record approval or manual payment |
| `/hg bounty gold` | Account gold breakdown and funding settings |
| `/hg bounty suggestions` | Review recurring attackers, death reports and bounty drafts |
| `/hg bounty test [FEATURE\|stop]` | Toggle a live-style preview; poster, match, kill, board or other sample UI |
| `/hg bounty guide [CHAPTER\|stop]` | Interactive bounty feature tour with guided sample actions |
| `/hg bounty list\|sync\|on\|off` | Print, ask the guild, switch alerts |

`/hg bounty test board` starts with three distinct sample cards per audience, varied rewards, shared contributions and a pending guild submission. Search, details and sample actions work on the populated board.

Tour chapters are `nearby`, `board`, `create`, `gold`, `guild`, `shared`, `pot`, `exchange`, `kill`, `claims` and `suggestions`. `world` remains an alias for `shared`. See the [bounty guide](user-guide.md#bounties) for sample actions and cleanup.

## Player reputation

| Command | What it does |
| --- | --- |
| `/hg reputation` | Player reports, moderation and chat filtering for your guild and WoW communities |
| `/hg reputation communities` | Open the organization directory; each Overview has explicit account enable/disable controls |
| `/hg reputation manage` | Open Blizzard's Guild & Communities UI |
| `/hg reputation report target` | Submit or queue a proposal for your guild or community |
| `/hg reputation sync` | Request updates from online native moderators |
| `/hg reputation status` | Show the selected organization's sharing status |
| `/hg reputation on\|off` | Enable or disable reputation chat filtering |

See [Player reputation](reputation.md) for membership, moderation and sharing rules.

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
| `/hg perf start\|stop \| perf` | Capture 60 seconds of callback allocations, time and FPS; show the report |
| `/hg probe \| map` | What the addon reads from your target and this map |
| `/hg cap why\|probe\|clear` | Capture tracking diagnostics |

## Preview buttons

The **Help and previews** page has one button per preview. Each runs its command; click it again to stop.

| Button | Command | What it shows |
| --- | --- | --- |
| Main panel | `/hg test` | Enemy list and kill-target card with sample enemies |
| Target marker | `/hg sniper test` | Crosshair on any target with a visible nameplate |
| Kill window | `/hg go` | GO look and sound (with Main panel or Target marker on) |
| Arena & duels | `/hg arena test` | Preview opponents; Forever shows one duelist |
| Nearby enemies | `/hg nearby test` | Open-world enemy list |
| Map pin | `/hg intel test` | Sample enemy pin on the world map |
| Burst marker | `/hg burst test` | Marker beside your target's nameplate (Cata) |
| Pressure shields | `/hg pressure test` | Shield badge on a targeted teammate or yourself (Cata) |
| Wanted poster | `/hg bounty test` | Toggle a live-style bounty sighting with sample data |
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
