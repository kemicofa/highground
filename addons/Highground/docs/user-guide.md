# User guide

[Documentation](README.md) · [Project overview](../README.md)

Commands are listed in [commands](commands.md).

## The Highground window

`/hg`, the minimap button, the **Open or close Highground** key binding or **Open Highground** in **Options → AddOns → Highground** open the Highground window. Its sidebar:

- **Home**: where you are, whether Highground is running there, which features are off, preview buttons and shortcuts.
- **Settings**: **Features** (the switches), **Appearance** and **Profiles**.
- **Targeting**: the scoring and tracking pages.
- **Battleground and world**: resurrection alerts, nearby enemies, **Guild bounties** and the bounty board.
- **Tools**: **Macros** and **Test and commands** (preview buttons and every command).

The Blizzard settings panel has the same pages, and the Features page is called **General** there. A change in either is the same setting. The window works in combat, moves by its header, closes with Escape and reopens on the page you left.

The **minimap button** opens the window on left-click. Right-click opens a menu: macros, bounty board, Test and commands, a main panel preview, the Highground window and the Blizzard settings. Drag it to move it around the minimap. On Retail and WoW Forever, Highground is also in the AddOns button beside the minimap. **Minimap button** on Features turns it off.

## Features

Every feature starts on except **Compact layout**. **Sounds** mutes every Highground sound. **Every battleground** also turns Highground on in unrated battlegrounds: off by default on Retail, on elsewhere. **10v10**, **15v15** and **Epic battlegrounds** switch it by team size; rated battlegrounds and Blitz count as 10v10, Ashran as epic. Indented switches need their parent; turning the parent off keeps their choices. Settings a client cannot use are hidden.

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

- **Target marker**: a crosshair below the nameplate of the recommended enemy, or of your own target when recommendations are off (**World target marker** on Features). Set colour, size, height and lock-on sound with `/hg sniper`.
- **Enemy healer markers**: a green cross above every enemy known to be a healer (spec from the scoreboard, a talent-tree cast on Cata, or a spec clue).
- **Enemy burst markers** (Cata): while an enemy has a big offensive cooldown up, its icon sits beside their nameplate with **PURGE** if your class can remove it, otherwise **CC**. The **Burst markers** page sets each spell to Auto, Purge only, CC or Off.
- **Sap calls** (rogues, Warsong Gulch and Twin Peaks): when the enemy flag carrier or a known enemy healer dies, a raid warning says **SAP name at their graveyard**, with their resurrection countdown when known.

## Target recommendations

Turn off **Target recommendations** on Features (or `/hg priority off`) to pick your own targets. This removes the enemy panel and card, the target, focus and mark keys, the GO sound and the map's kill-target mark. The target marker stays and follows your own target.

**Target behavior** sets:

- **Switch margin** (default 8 points): how far ahead another enemy must be before the recommendation switches or rows reorder. A GO candidate must also be within it.
- **GO alert** (default 12 seconds after a defensive ends; 0 turns GO off) and the **defensive-spent** bonus, which fades over 60 seconds.
- **Live sorting**, and on Cata the **execute threshold** and **Preserve breakable crowd control** (on by default).

Known full immunities never win, whatever the points. Retail reads only clear aura categories and does not guess immunity or breakable CC.

The other targeting pages set point values: **Target priority**, **Objectives**, **Live signals**, **Cooldowns**, **Spec ratings** and **Advanced multipliers**. Hover a value to see its range; multipliers show the effective value (points × your multiplier × battleground modifier, for example a flag bonus of 30 × 1 × 1.5 = 45 in capture-the-flag maps). On **Cooldowns**, **Show spell overrides** lists per-spell values: leave a field blank to use the general value, type a number to fix it, press **x** to clear it.

Spec ratings (0–15) are starting points, not measured odds. Only Retail Frost Death Knight has hand-written matchups; other specs use generic armor, protection and mobility modifiers.

**Reset tuning** restores points, multipliers, spec ratings and target behavior. It keeps feature switches, appearance and cooldown tracking.

### Cooldown tracking (Cata)

Highground tracks the cooldowns that decide fights: big defensives, offensive cooldowns, and long crowd control or silences (Blind, Smoke Bomb, Hammer of Justice, Strangulate). Kicks, short CC, escapes and utility are not tracked. The **Cooldown tracking** page turns single spells on or off; search by spell, class or type (`offensive`, `defensive`) and use **Track shown** / **Untrack shown**. An untracked spell loses its display, score bonus and spent alert; full immunities still block recommendations. Choices persist across reloads, **Reset tuning** and profiles.

## Profiles

The **Profiles** page saves tuning under a name: type it, then **Save**, **Load** or **Delete**. **Export** shows a base64 string of a profile or your current settings to copy. **Import** takes such a string: **Apply** uses it now, **Save as profile** stores it. An invalid import changes nothing.

## Appearance

The **Appearance** page:

- **Theme**: **Highground** (cool slate and teal, the default), **Ember** (smoked charcoal and copper), **Parchment** (muted linen and pine) or **Azeroth** (obsidian and antique gold, with Warcraft titles). A switch applies at once, also in combat, and never moves or resizes anything. Tooltips and chat stay dark in every theme; nameplate overlays, map pins and the target marker keep their colours. Also `/hg theme NAME`.
- **Accessibility**: **Reduced motion** replaces pulses, rank flashes and target zoom with steady indicators. **Font** and **Text size** let you choose a face and enlarge the text. All themes share the same text sizes.
- **Frameless**: no panel background, border or title bars.
- **Kill-target card**: hide it; the list moves up and the keys keep working.
- **Scale** per panel, on top of the UI scale.
- **Sizes and spacing** for the panels and rows. Normal and compact layouts keep their own sizes.
- **Enemy rows**: show or hide each element (rank, spec icon and text, health bar and percent, mana, trinket, status, distance, priority tag, teammates).
- **Text and bars**: health style (**Fill the row** or **Thin line**), bar texture and health colours (class, faction, or by health left).
- **Borders**: size (0 for none) and colour.

Sizes change out of combat; everything else at once. **Reset appearance** restores the layout and text defaults; your theme and Reduced motion preference are kept.

On **Features**, **UI scale** (50–200%, default 80%) sizes every panel, and **Background opacity** (0–100%, default 100%) sets how much of the world shows through. Scale changes made in combat apply when it ends.

**Compact layout** makes rows and the card one line and narrows the panels. In battlegrounds, the carrier, resurrection and objective panels dock under the main panel; drag any of them to move the column. The arena panel stays on its own.

## Battleground panels

Resurrection and objective panels show countdowns over thin progress bars. Amber marks the last five seconds, `~` an estimate and `--` unknown. **YOU**, **OURS** and **THEIRS** say whose graveyard it is; hover for details. The **flag carrier panel** lists carriers: left-click to target, right-click to focus. See [observations and timers](observations.md) for how positions and countdowns are worked out.

## Arena panel

**ARENA ENEMIES** has one row per opponent: class, name, spec when the client gives it, health, PvP trinket, and **TGT**/**FOC** for your target and focus. Left-click targets, right-click focuses; both work in combat, since each row is bound to `arena1`–`arena5`. Stealthed or unseen opponents keep their name and show **unseen**.

## Nearby enemies

Outside battlegrounds, arenas and dungeons, **Nearby enemies** lists hostile players you have seen, newest first: class, name, level, guild, where and how long ago. Left-click targets, right-click focuses and keeps your target. Sources are nameplates, your target and mouseover; on Cata the combat log adds enemies without a visible nameplate. The **Nearby enemies** page sets how many are listed and when rows fade and disappear, plus the new-enemy sound. Enemies first seen in combat show as **+N new** in the header until combat ends.

When a nearby enemy uses Stealth, Prowl, Vanish, Invisibility, Shadowmeld or Camouflage, chat says so, and again when it fades. On Cata the combat log gives both; on retail and WoW Forever only a cast by an enemy you can see counts, and it fades when you see them again.

The history (saved per account) remembers every enemy you meet: how many times, how often they killed you and you them. Someone you met before gets a chat line when they show up, and their row shows `met 3x  K1 D2` (you killed them once, they killed you twice). Kills count from the combat log on Cata; on retail and WoW Forever your honorable kills count, and a death counts when the game's death recap names the enemy. `/hg nearby forget` clears it.

## Bounties

Put a bounty on an enemy player, with or without gold. When the target shows up in the open world, a battleground or an arena, Highground plays a sound, shows a center-screen message and puts a gold coin beside their nameplate. Their Highground rows get a gold frame and their tooltip names the reward. Highground keeps the list; players pay the gold themselves.

The **bounty board** shows every bounty you can see: reward, status (**PERSONAL**, **PENDING**, **GUILD**), who placed and approved it, and where and when it was last seen. Tabs filter **ALL**, **MINE**, **GUILD** and **PENDING**; the header shows the guild purse. Open it with `/hg bounty`, its key binding, the **Guild bounties** page, or *Highground: put a bounty* in a player's right-click menu (Retail and WoW Forever). The name field starts with your target; gold and the note are optional.

- **Add** makes a personal bounty that alerts only you.
- **Share in chat** on a card prepares a chat message; choose your channel and press Enter to send. `/hg bounty share NAME` does the same. Anyone with Highground or Highground Bounties can click it to open the board and review the target, reward, original poster and note before importing a personal copy. An existing personal bounty is replaced only after confirmation. Guild submission remains a separate action. Players without the addon see a plain text bounty token.
- **Submit** sends it to your guild as **PENDING**. An officer approves it, then every member with Highground gets it as **GUILD**. Officers can reject or remove any bounty; the submitter can remove their own.
- Officers are the guild master and the ranks up to **Officers** on Guild bounties (default 1, the rank below the guild master).
- Guild bounties expire after 14 days by default. Members exchange the list when they log in.
- Open-world sightings of guild bounty targets are shared with the guild. On Cata, your killing blow on one tells the guild.
- WoW Forever first-and-last names work as typed (`Iron Fist`).

The **Guild bounties** page sets the sound, center-screen message, telling your group (off by default), sharing sightings, the re-alert delay, the officer rank, the expiry, and **Also alert for bounty targets you can't attack**. On Features, **Bounties** turns the feature off and **Bounty markers** hides the coin and row frames.

## Macros

**Macros** (`/hg macros`) holds ready-made PvP and PvE macros for your class and game, and a builder. Spell names are English. The same window ships on its own as [Highground Macros](../../HighgroundMacros/README.md) (`/hgm`).

- **PVP / PVE** (top right) switches the presets: PvP has arena focus, crowd control and burst macros; PvE has focus interrupts, mouseover taunts and dots, mouseover heals and dispels, battle resurrections and raid markers. `/hg macros pve` and `/hg macros pvp` open the window on either. **RANKS** appears in games with spell ranks ([below](#spell-ranks-wow-forever)).
- **MY CLASS**: your class's macros; **READY** ones (every spell in your spellbook) come first. **GENERAL**: macros for every class. **ALL CLASSES**: everything. The search box filters by name, description and class.

### Preset cards

- Variant buttons pick the unit: **F / A1 / A2 / A3** for enemies in PvP (focus, arena 1–3), **F / MO / T** for enemies in PvE (focus, mouseover, target), **MO / P1 / P2 / ME** for allies (mouseover, party 1–2, yourself). Some presets hit someone else's target and keep yours: **FT / MOT / P1T / P2T** (focus's, mouseover's, party 1's or party 2's target), for example the druid's **Starsurge**.
- **+** lists the other targets: party 3–4 (or their targets), and arena 4–5 in games with 5v5 arenas (Cataclysm, The Burning Crusade). Picking one shows that version.
- An outlined, raised variant is the target being previewed. The **Preview** label names it. Small bottom marks show saved scope; the status text and tooltip spell out General, Character or both. Saved variants do not look selected merely because they are saved.
- **Save: General** copies the shown version into the account-wide macro tab, **Save: Character** into this character's. A macro with the same name is updated. Macros cannot change in combat.
- **Copy & Edit** opens the preset, with the target you picked, in **CREATE / EDIT**, to change it and save it under a name of your own.
- Macro text on the cards is coloured: commands, conditions, units and values each have their own colour.

### CREATE / EDIT

The setup and editor scroll independently. Inside the Highground window, the builder reclaims the duplicate title area to leave more room for your macro.

1. **Choose an action**: **Cast spell**, **Use item**, **Sequence** (`/castsequence`) or **Random** (`/castrandom`), then the spell, item or slot. Separate several spells with commas. In games with spell ranks, **Rank** pins a rank.
2. **Choose a target**: a menu names each target in full, including party members and the arena enemies available in your game. **Normal spell targeting** restores ordinary targeting. **A named group member** reveals a player-name field. The checkbox directly below the selected unit changes the recipient to that unit's target: **Use your focus's target** produces `@focustarget`, for example. It also works with mouseover, party and arena units, your current target, or a named group member; your own target stays selected. The recipient summary updates with the choice. Ground-at-cursor and self casts do not offer this option.
3. **Review & save**: edit or paste macro text directly, read **What this will do**, then choose **This character** (Character slots) or **All characters** (General slots) and **Save macro**. An existing name changes the action to **Update macro** and identifies the destination before saving.

**Target conditions**, **Casting options**, **Use items first**, and **Utility action** unfold when needed. Their headers count active options even while folded. Target conditions offer living-enemy/ally checks and fallbacks. A fallback runs when the earlier macro conditions fail, including a missing recipient; range, line of sight and cooldowns do not trigger it. A self fallback is unavailable when the normal-target fallback already covers every remaining case. Casting options include stopping your cast, an explicit auto-attack choice, toggles and cancelling buffs. Items include both trinket slots and comma-separated names or slot numbers. Choosing a sequence reveals its reset settings.

Lines you type by hand survive recipe changes. **Manual edits** identifies text that differs from the recipe; the explanation always describes the text being saved, and warns that the form may not reflect those edits. An empty macro is a draft; errors appear once there is text to check. Validation and explanations have their own scroll area, and the save controls stay visible. Saving is disabled for errors or during combat, with a visible reason. Loading a different macro clears the old recipe and selects that macro's save destination.

### MY MACROS

Your existing macros, each checked (**OK**, warnings or errors). **Edit** opens one in **CREATE / EDIT**; saving to its tab updates it. **To General** / **To Character** copies it to the other tab. **EXPORT** shows that macro as a base64 string. **Export all** turns all your macros into one string; **Import** previews a string and shows which macros it would replace. **Open WoW macros** opens Blizzard's macro window.

### Spell ranks (WoW Forever)

Highground Macros has the same on Classic Era and The Burning Crusade. A spell name without a rank, like `/cast Frostbolt`, casts your highest rank. Every preset is written that way. Action buttons and macros that name a rank, like `Frostbolt(Rank 3)`, stay on it.

- **Highest spell rank** (Features, on by default): when you learn a new rank, action buttons on the rank it replaces move up to it. Buttons on lower ranks, kept on purpose to save mana, stay. **Also in macros** does the same for `Name(Rank N)` in your macros. Changes wait until you leave combat.
- **RANKS** (next to PVP and PVE) lists a preset for every spell in your spellbook that has ranks. Each casts the spell by name, so it always uses your highest rank, also after you learn a new one. Heals and buffs go to the ally under your mouse, then your target, then you; other spells to your target, with focus and mouseover variants. `/hg macros presets` opens it.
- `/hg macros ranks` moves every button and macro on a lower rank up to your highest rank.
- CREATE / EDIT has a **Rank** field: empty casts your highest rank; a number pins that rank. The checker warns when a macro pins a rank lower than one you know.

### Checks and autocomplete

Every macro is explained line by line in plain English. Problems are listed by line as you type, such as an unknown condition (`[@fokus]`), a missing `]`, more than 255 characters, a spell not in your spellbook, or a command your game lacks (`/ping` on Cataclysm). Macros with errors cannot be copied.

Autocomplete covers spells, items and slots, buffs to remove, commands, conditions and units, values such as `mod:shift`, raid markers (`/tm`), sequence resets (`reset=`) and `#showtooltip`. **Tab** accepts a suggestion; without an open list it moves between visible fields (Shift-Tab goes backwards). Completion appears beside the caret, above or below the current line, within the editor, so it does not cover the explanation. **Escape** dismisses completion first and leaves the editor on a second press. In the one-line fields, **Enter** also accepts and the arrow keys move through the list; in the macro box only **Tab** accepts, so **Enter** and the arrow keys keep their editing meaning.

## Teammate pressure shields (Cata)

Shield badges mark up to three teammates (`/hg pressure count N`, 1–3) with the most observed enemies targeting them. The number counts distinct enemies targeting that teammate, not damage. The shield turns from amber to red at three. Badges are private to you. Turn on friendly nameplates (usually Shift+V) to see them; your own badge sits left of the player frame when your nameplate is hidden.
