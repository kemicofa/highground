# User guide

[Documentation](README.md) · [Project overview](../README.md)

Commands are listed in [commands](commands.md).

## The Warboard window

`/wb`, the minimap button, the **Open or close Warboard** key binding or **Open Warboard** in **Options → AddOns → Warboard** open the Warboard window. Its sidebar:

- **Home**: where you are, whether Warboard is running there, which features are off, preview buttons and shortcuts.
- **Settings**: **Features** (the switches), **Appearance** and **Profiles**.
- **Targeting**: the scoring and tracking pages.
- **Battleground and world**: resurrection alerts, nearby enemies, **Guild bounties** and the bounty board.
- **Tools**: **PvP macros** and **Test and commands** (preview buttons and every command).

The Blizzard settings panel has the same pages, and the Features page is called **General** there. A change in either is the same setting. The window works in combat, moves by its header, closes with Escape and reopens on the page you left.

The **minimap button** opens the window on left-click. Right-click opens a menu: PvP macros, bounty board, Test and commands, a main panel preview, the Warboard window and the Blizzard settings. Drag it to move it around the minimap. On Retail and WoW Forever, Warboard is also in the AddOns button beside the minimap. **Minimap button** on Features turns it off.

## Features

Every feature starts on except **Compact layout**. **Sounds** mutes every Warboard sound. **Every battleground** also turns Warboard on in unrated battlegrounds: off by default on Retail, on elsewhere. **10v10**, **15v15** and **Epic battlegrounds** switch it by team size; rated battlegrounds and Blitz count as 10v10, Ashran as epic. Indented switches need their parent; turning the parent off keeps their choices. Settings a client cannot use are hidden.

## Main panel

The **kill-target card** at the top shows the recommended enemy: name, class, health and how many teammates are on them. Below it, each enemy row shows name and status, then spec, ally count, range and priority. Hover a row for spec and how it was found, location, cast, and cooldowns used, with the time until each is back. Scores stay out of the panel; **Target behavior → Refresh comparison** shows them.

| Status | Meaning |
| --- | --- |
| **IMMUNE** | Known full immunity; never recommended |
| **DEF** | Defensive active |
| **CC** | Crowd control |
| **STUN/SIL** | Stunned or silenced (Cata) |
| **FLAG** | Flag carrier |
| **SPENT** | Recently used a defensive |
| **BURST** | Offensive cooldown active |
| **PURGE** | Offensive cooldown your class can remove (Cata) |

On Cata, a `~` before a spec means it is estimated (see [estimated specs](observations.md#estimated-specs-cata)). Rows also show health percent (red under the execute threshold), a mana bar for mana users, and the PvP trinket: bright when ready or not seen used, grey with the seconds left when on cooldown (combat log, base 2-minute cooldown). Retail hides enemy health values and power, so rows show the health fill only.

Left-click an enemy row to target, right-click to focus. The card's name is its click target; shift-click calls it in chat. Outside combat, the card and the target key follow the recommendation. In combat, click bindings cannot change: if the recommendation changes, the card shows **COMBAT TARGET** with **RECOMMENDED: name** below it, so use that enemy's row or nameplate. With no target bound before combat, the card shows **Target click unavailable** until combat ends.

A **GO** window opens when an enemy's defensive ends: the card highlights and a sound plays.

### Markers over the world

- **Target marker**: a crosshair below the nameplate of the recommended enemy, or of your own target when recommendations are off (**World target marker** on Features). Set colour, size, height and lock-on sound with `/wb sniper`.
- **Enemy healer markers**: a green cross above every enemy known to be a healer (spec from the scoreboard, a talent-tree cast on Cata, or a spec clue).
- **Enemy burst markers** (Cata): while an enemy has a big offensive cooldown up, its icon sits beside their nameplate with **PURGE** if your class can remove it, otherwise **CC**. The **Burst markers** page sets each spell to Auto, Purge only, CC or Off.
- **Sap calls** (rogues, Warsong Gulch and Twin Peaks): when the enemy flag carrier or a known enemy healer dies, a raid warning says **SAP name at their graveyard**, with their resurrection countdown when known.

## Target recommendations

Turn off **Target recommendations** on Features (or `/wb priority off`) to pick your own targets. This removes the enemy panel and card, the target, focus and mark keys, the GO sound and the map's kill-target mark. The target marker stays and follows your own target.

**Target behavior** sets:

- **Switch margin** (default 8 points): how far ahead another enemy must be before the recommendation switches or rows reorder. A GO candidate must also be within it.
- **GO alert** (default 12 seconds after a defensive ends; 0 turns GO off) and the **defensive-spent** bonus, which fades over 60 seconds.
- **Live sorting**, and on Cata the **execute threshold** and **Preserve breakable crowd control** (on by default).

Known full immunities never win, whatever the points. Retail reads only clear aura categories and does not guess immunity or breakable CC.

The other targeting pages set point values: **Target priority**, **Objectives**, **Live signals**, **Cooldowns**, **Spec ratings** and **Advanced multipliers**. Hover a value to see its range; multipliers show the effective value (points × your multiplier × battleground modifier, for example a flag bonus of 30 × 1 × 1.5 = 45 in capture-the-flag maps). On **Cooldowns**, **Show spell overrides** lists per-spell values: leave a field blank to use the general value, type a number to fix it, press **x** to clear it.

Spec ratings (0–15) are starting points, not measured odds. Only Retail Frost Death Knight has hand-written matchups; other specs use generic armor, protection and mobility modifiers.

**Reset tuning** restores points, multipliers, spec ratings and target behavior. It keeps feature switches, appearance and cooldown tracking.

### Cooldown tracking (Cata)

Warboard tracks the cooldowns that decide fights: big defensives, offensive cooldowns, and long crowd control or silences (Blind, Smoke Bomb, Hammer of Justice, Strangulate). Kicks, short CC, escapes and utility are not tracked. The **Cooldown tracking** page turns single spells on or off; search by spell, class or type (`offensive`, `defensive`) and use **Track shown** / **Untrack shown**. An untracked spell loses its display, score bonus and spent alert; full immunities still block recommendations. Choices persist across reloads, **Reset tuning** and profiles.

## Profiles

The **Profiles** page saves tuning under a name: type it, then **Save**, **Load** or **Delete**. **Export** shows a base64 string of a profile or your current settings to copy. **Import** takes such a string: **Apply** uses it now, **Save as profile** stores it. An invalid import changes nothing.

## Appearance

The **Appearance** page:

- **Theme**: **Warboard** (dark navy and teal, the default), **Ember** (charcoal, crimson and amber) or **Parchment** (light: paper, dark ink, the game's Friz Quadrata font). A switch applies at once, also in combat, and never moves or resizes anything. Tooltips and chat stay dark in every theme; nameplate overlays, map pins and the target marker keep their colours. Also `/wb theme NAME`.
- **Frameless**: no panel background, border or title bars.
- **Kill-target card**: hide it; the list moves up and the keys keep working.
- **Scale** per panel, on top of the UI scale.
- **Sizes and spacing** for the panels and rows. Normal and compact layouts keep their own sizes.
- **Enemy rows**: show or hide each element (rank, spec icon and text, health bar and percent, mana, trinket, status, distance, priority tag, teammates).
- **Text and bars**: font, text size, health style (**Fill the row** or **Thin line**), bar texture and health colours (class, faction, or by health left).
- **Borders**: size (0 for none) and colour.

Sizes change out of combat; everything else at once. **Reset appearance** restores these defaults and keeps the theme.

On **Features**: **UI scale** (50–200%, default 80%) sizes every panel, and **Background opacity** (0–100%, default 45%) sets how much of the world shows through. Scale changes made in combat apply when it ends.

**Compact layout** makes rows and the card one line and narrows the panels. In battlegrounds, the carrier, resurrection and objective panels dock under the main panel; drag any of them to move the column. The arena panel stays on its own.

## Battleground panels

Resurrection and objective panels show countdowns over thin progress bars. Amber marks the last five seconds, `~` an estimate and `--` unknown. **YOU**, **OURS** and **THEIRS** say whose graveyard it is; hover for details. The **flag carrier panel** lists carriers: left-click to target, right-click to focus. See [observations and timers](observations.md) for how positions and countdowns are worked out.

## Arena panel

**ARENA ENEMIES** has one row per opponent: class, name, spec when the client gives it, health, PvP trinket, and **TGT**/**FOC** for your target and focus. Left-click targets, right-click focuses; both work in combat, since each row is bound to `arena1`–`arena5`. Stealthed or unseen opponents keep their name and show **unseen**.

## Nearby enemies

Outside battlegrounds, arenas and dungeons, **Nearby enemies** lists hostile players you have seen, newest first: class, name, level, guild, where and how long ago. Left-click targets, right-click focuses and keeps your target. Sources are nameplates, your target and mouseover; on Cata the combat log adds enemies without a visible nameplate. The **Nearby enemies** page sets how many are listed and when rows fade and disappear, plus the new-enemy sound. Enemies first seen in combat show as **+N new** in the header until combat ends. Nothing is saved between sessions.

## Bounties

Put a bounty on an enemy player, with or without gold. When the target shows up in the open world, a battleground or an arena, Warboard plays a sound, shows a center-screen message and puts a gold coin beside their nameplate. Their Warboard rows get a gold frame and their tooltip names the reward. Warboard keeps the list; players pay the gold themselves.

The **bounty board** shows every bounty you can see: reward, status (**PERSONAL**, **PENDING**, **GUILD**), who placed and approved it, and where and when it was last seen. Tabs filter **ALL**, **MINE**, **GUILD** and **PENDING**; the header shows the guild purse. Open it with `/wb bounty`, its key binding, the **Guild bounties** page, or *Warboard: put a bounty* in a player's right-click menu (Retail and WoW Forever). The name field starts with your target; gold and the note are optional.

- **Add** makes a personal bounty that alerts only you.
- **Submit** sends it to your guild as **PENDING**. An officer approves it, then every member with Warboard gets it as **GUILD**. Officers can reject or remove any bounty; the submitter can remove their own.
- Officers are the guild master and the ranks up to **Officers** on Guild bounties (default 1, the rank below the guild master).
- Guild bounties expire after 14 days by default. Members exchange the list when they log in.
- Open-world sightings of guild bounty targets are shared with the guild. On Cata, your killing blow on one tells the guild.
- WoW Forever first-and-last names work as typed (`Iron Fist`).

The **Guild bounties** page sets the sound, center-screen message, telling your group (off by default), sharing sightings, the re-alert delay, the officer rank, the expiry, and **Also alert for bounty targets you can't attack**. On Features, **Bounties** turns the feature off and **Bounty markers** hides the coin and row frames.

## PvP macros

**PvP macros** (`/wb macros`) holds ready-made macros for your class and game, and a builder. Spell names are English.

- **MY CLASS**: your class's macros; **READY** ones (every spell in your spellbook) come first. **GENERAL**: macros for every class. **ALL CLASSES**: everything.
- Variant buttons pick the unit: **F / A1 / A2 / A3** for enemies (focus, arena 1–3), **MO / P1 / P2 / ME** for allies (mouseover, party 1–2, yourself). Their colour shows where that variant is saved: teal General, violet Character, both, or dark for not saved.
- **General** copies a macro into the account-wide macro tab, **Character** into this character's. A macro with the same name is updated. Macros cannot change in combat.
- **BUILD**: pick a spell or item, who it lands on, and what runs first (`/stopcasting`, `/startattack`, trinkets, `/cancelaura` on a buff that blocks the spell). Sequence and Random build `/castsequence` and `/castrandom`. The macro text is editable.
- **MY MACROS**: your existing macros, each checked. **Edit** opens one in BUILD; **To General** / **To Character** copies it.
- **Export all** turns your macros into one base64 string; **Import** previews a string and shows which macros it would replace.

Every macro is explained line by line in plain English. Problems are listed by line as you type, such as an unknown condition (`[@fokus]`), a missing `]`, more than 255 characters, a spell not in your spellbook, or a command your game lacks (`/ping` on Cataclysm). Macros with errors cannot be copied. Spell, item, command and condition names autocomplete: **Tab** or **Enter** accepts, arrow keys move.

## Teammate pressure shields (Cata)

Shield badges mark up to three teammates (`/wb pressure count N`, 1–3) with the most observed enemies targeting them. The number counts distinct enemies targeting that teammate, not damage. The shield turns from amber to red at three. Badges are private to you. Turn on friendly nameplates (usually Shift+V) to see them; your own badge sits left of the player frame when your nameplate is hidden.
