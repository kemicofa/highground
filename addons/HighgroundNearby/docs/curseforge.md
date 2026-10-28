<!-- HighgroundNearby 0.2.0 -->
<!-- CurseForge project text. Update for every release; the build fails when the version above does not match the TOCs. -->

# CurseForge description

## Summary

Paste into the project summary. CurseForge cuts it off past about 200 characters, so it must be catchy and short:

```
Never get ganked blind. Every enemy nearby, one click to target, a warning when a rogue stealths, and a saved record of who killed you. Retail, WoW Forever, Cataclysm Classic.
```

## Description

Paste everything in the block below into the project description (Markdown):

````markdown
# Highground Nearby — Open-World Enemy List

Highground Nearby keeps a list of the hostile players you have seen in the open world, most recent first. The rogue who walked past a minute ago, the mage on the hill: they're on the list, one click away. It runs on Retail, WoW Forever and Cataclysm Classic.

## Features

### 👀 Who's around

- Name, class, level, guild, zone and how long ago, newest first.
- Spotted from nameplates, your target and mouseover. On Cataclysm Classic the combat log adds enemies hitting you without a visible nameplate.
- A sound when a new enemy shows up (at most one every ten seconds).
- Rows fade once an enemy is out of sight and drop off the list later.

### 🥷 Stealth alerts (new)

- A chat line when a nearby enemy uses **Stealth, Prowl, Vanish, Invisibility, Shadowmeld or Camouflage**, and another when it fades.
- The row shows the spell while they're hidden.

### 📖 Enemy history (new)

- Every enemy you meet is remembered, across sessions: how many times you met, how often they killed you and how often you killed them.
- When someone you met before shows up, chat says so: *seen 3 times before, last 2d ago; killed you 2, you killed 1*. Their row shows `met 3x  K1 D2`.
- `/hgn forget` or **Forget history** in settings wipes it.

### 🎯 One click

- **Left-click** a row to target the enemy, **right-click** to focus and go back to your target.
- In combat the rows keep their enemy; newcomers show as **+N new** until it ends.

### ⚙️ Your way

- How many enemies to list, when to fade and when to forget, sound, stealth alerts and history on or off: `/hgn config`.
- Drag the list anywhere, then `/hgn lock` it. Hidden in battlegrounds, arenas, dungeons and raids.
- **Highground** (dark navy and teal), **Ember** (charcoal, crimson and amber) or **Parchment** (light paper with the classic WoW font): `/hgn theme NAME`.

## Supported game versions

| | Retail | WoW Forever | Cataclysm Classic |
|---|---|---|---|
| Nearby enemies list | ✅ | ✅ | ✅ |
| Stealth alerts | Enemies you can see | Enemies you can see | ✅ (combat log) |
| Enemy history | ✅ | ✅ | ✅ |
| Kills in the history | Honorable kills and death recap | Honorable kills and death recap | ✅ (combat log) |

Retail and WoW Forever hide most combat information from addons: stealth is caught only when you see the cast, and a kill counts only when the game names the enemy.

## Getting started

- The list appears on its own when you spot an enemy. `/hgn test` shows a preview to drag into place; `/hgn help` lists every command.
- Already using **Highground**? It has the same list built in (`/hg nearby`). Install Highground Nearby on its own if you only want the list.

## Links

- Source code and issues: https://github.com/kemicofa/highground
````
