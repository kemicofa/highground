<!-- HighgroundNearby 0.2.1 -->
<!-- CurseForge project text. Update for every release; the build fails when the version above does not match the TOCs. -->

# CurseForge description

## Summary

Paste into the project summary (plain text, at most 200 characters):

```
Track enemies you've seen, target or focus from the list, keep encounter notes and opt into shared bounties with funding reports and claims. Retail, WoW Forever, Cataclysm Classic.
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

### 🥷 Stealth alerts

- A chat line when a nearby enemy uses **Stealth, Prowl, Vanish, Invisibility, Shadowmeld or Camouflage**, and another when it fades.
- The row shows the spell while they're hidden.

### 📖 Enemy history

- Every enemy you meet is remembered, across sessions: how many times you met, how often they killed you and how often you killed them.
- When someone you met before shows up, chat says so: *seen 3 times before, last 2d ago; killed you 2, you killed 1*. Their row shows `met 3x  K1 D2`.
- `/hgn forget` or **Forget history** in settings wipes it.
- `/hgn journal` searches encounters by name, class, guild, area or note. Add notes, mute alerts or start a bounty.

### 🎯 One click

- **Left-click** a row to target the enemy, **right-click** to focus and go back to your target.
- In combat the rows keep their enemy; newcomers show as **+N new** until it ends.

### 💰 Shared bounties

- Open `/hgn bounty shared` and opt in to receiving and publishing separately. Both start off.
- Contributions from different account IDs stack on the exact target. Choose a duration from five minutes to thirty days; the alert threshold uses the combined reward with recent available-funds reports.
- The poster's addon checks carried gold against outstanding commitments and reports **Funds reported available**, **Insufficient funds** or **Funds status unknown**. These reports do not guarantee payment.
- Claims require the poster's review; players pay through the game. Works with Highground and Highground Bounties within the realm/faction chat boundary.
- The board also supports personal alerts and guild submissions. `/hgn bounty claims` opens the claims ledger.

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
| Personal, guild and shared bounties; manual claims | ✅ | ✅ | ✅ |
| Kills in the history | Honorable kills and death recap | Honorable kills and death recap | ✅ (combat log) |

Retail and WoW Forever hide most combat information from addons: stealth is caught only when you see the cast, and a kill counts only when the game names the enemy.

## Getting started

- Keep both included folders installed and enabled: **HighgroundNearby** and **HighgroundBountyData**, which preserves shared contributions and account IDs. Restart the game after installation or updates.
- The list appears on its own when you spot an enemy. `/hgn test` shows a preview to drag into place; `/hgn help` lists every command.
- Already using **Highground**? It has the same list built in (`/hg nearby`). Install Highground Nearby on its own if you only want the list.
- When Highground Bounties is loaded, Nearby stays inactive and directs you to `/hgb`, because Bounties already includes the list.

## Links

- [Join the Highground Discord](https://discord.gg/xu3VsxRjca) — addon discussions, help, bug reports and feature requests.
- [Guides, source code and issues](https://github.com/kemicofa/highground)
````
