<!-- HighgroundNearby 0.5.0 -->
<!-- CurseForge project text. Update for every release; the build fails when the version above does not match the TOCs. -->

# CurseForge description

## Summary

Paste into the project summary (plain text, at most 200 characters):

```
Remember who attacked. Nearby enemies, stealth alerts and encounter history, plus optional bounty suggestions for repeat attackers. Retail, Forever, Cata.
```

## Description

Paste everything in the block below into the project description (Markdown):

````markdown
# Highground Nearby — Open-World Enemy List

Highground Nearby keeps a list of the hostile players you have seen in the open world, most recent first. The rogue who walked past a minute ago, the mage on the hill: they're on the list, one click away. It runs on Retail, WoW Forever and Cataclysm Classic.

## Features

### 👀 Who's around

- Name, class, level, zone and how long ago, newest first. Hover for guild and encounter details.
- Spotted from nameplates, your target and mouseover. On Cataclysm Classic the combat log adds enemies hitting you without a visible nameplate.
- Optional sound when a new enemy shows up. **Quieter first use:** five rows and quiet sighting alerts on new installations.
- Rows fade once an enemy is out of sight and drop off the list later.

### 🥷 Stealth alerts

- A chat line when a nearby enemy uses **Stealth, Prowl, Vanish, Invisibility, Shadowmeld or Camouflage**, and another when it fades.
- The row shows the spell while they're hidden.

### 📖 Enemy history

- Every enemy you meet is remembered, across sessions: how many times you met, how often they killed you and how often you killed them.
- Hover a row or open the journal to see encounter and kill totals. Routine sighting messages follow your alert level.
- `/hgn forget` wipes the saved history. **Undo delete** restores individual removals from the journal; Clear search and paging adapt to larger text sizes.
- **Death attribution (new):** enemy history uses the same conservative death reports as bounty suggestions, avoiding guesses from an earlier nonfatal hit.
- `/hgn journal` searches encounters by name, class, guild, area or note. Add notes, mute alerts or start a bounty.

### 🎯 One click

- **Left-click** a row to target the enemy, **right-click** to focus and go back to your target.
- In combat the rows keep their enemy; newcomers show as **+N after combat** until it ends.

### 💰 Shared bounties

- Open `/hgn bounty shared` and opt in to receiving and publishing separately. Both start off.
- Contributions from different account IDs stack on the exact target. Choose a duration from five minutes to thirty days; the alert threshold uses the combined reward with recent available-funds reports.
- The poster's addon checks carried gold against outstanding commitments and reports **Funds reported available**, **Insufficient funds** or **Funds status unknown**. These reports do not guarantee payment.
- Claims require the poster's review; players pay through the game. Works with Highground and Highground Bounties within the realm/faction chat boundary.
- The board also supports personal alerts and guild submissions. `/hgn bounty claims` opens the claims ledger.
- **Guided bounty workspace:** a first-use guide explains private tracking and hunting for rewards. Creation, details and claims stay in the same window; empty views explain searches, guild membership and shared-bounty opt-ins.

### 🔎 Bounty suggestions (new)

- Find recurring open-world attackers with `/hgn bounty suggestions`. Enable **Bounty suggestions** under `/hgn config` → **More settings**. Suggestions and sharing your attributed deaths with guild addons have separate switches; both start off. Bounties must also be enabled.
- By default, suggest after **3 deaths against you**, or **5 deaths across 3 guild characters**, in **30 minutes**. Adjust the thresholds, distinct victim count, rolling window and notification cooldown. Exact names and realms stay separate; alts count as separate characters.
- **Reports** shows victims, times, locations and attribution sources. **Review bounty** opens an existing listing or a draft with the target, reason and audience filled in; the reward starts blank. You choose whether to save. Guild submissions still need officer approval.
- Notifications wait until combat ends. **Dismiss 24h** hides a target for one day; **Ignore enemy** lasts until you choose **Show ignored → Allow again**. Recent reports and dismissals survive reloads and switching between Highground, Bounties and Nearby.
- Only attributable open-world deaths count. NPCs, environmental deaths, duels, instanced deaths and ambiguous names are skipped. Retail and WoW Forever need a readable death recap; Cata uses fatal combat damage. Unavailable data can leave a death uncounted.
- Participating guildmates share only their own deaths through hidden addon messages while online. Reports are player-supplied evidence, not server-verified kill proof. Suggestions work independently of the nearby panel and lifetime history.

### ⚙️ Your way

- **Simpler settings:** `/hgn config` starts with the panel switch, row count and sound. **More settings** reveals fade times, stealth, history and appearance.
- Drag the list anywhere, then `/hgn lock` it. Hidden in battlegrounds, arenas, dungeons and raids.
- Clearer text and focus indicators, text-size controls and **Reduced motion** are available in settings.
- **Highground** (cool slate and teal), **Ember** (charcoal and copper), **Parchment** (muted linen and pine) or **Azeroth** (obsidian, antique gold and Warcraft titles): `/hgn theme NAME`.

## Supported game versions

| | Retail | WoW Forever | Cataclysm Classic |
|---|---|---|---|
| Bounty suggestions | Readable death recap | Readable death recap | Fatal combat damage |
| Nearby enemies list | ✅ | ✅ | ✅ |
| Stealth alerts | Enemies you can see | Enemies you can see | ✅ (combat log) |
| Enemy history | ✅ | ✅ | ✅ |
| Personal, guild and shared bounties; manual claims | ✅ | ✅ | ✅ |
| Kills in the history | Honorable kills and death recap | Honorable kills and death recap | ✅ (combat log) |

Retail and WoW Forever hide most combat information from addons: stealth is caught only when you see the cast, and a kill counts only when the game names the enemy.

## Getting started

- Optional suggestions: enable **Bounty suggestions** under `/hgn config` → **More settings**, then open `/hgn bounty suggestions`. **Bounties** must also be on; choose separately whether to share your deaths.
- Keep both included folders installed and enabled: **HighgroundNearby** and **HighgroundBountyData**, which preserves shared contributions, account IDs, recent suggestion reports and dismissals. Restart the game after installation or updates.
- The list appears on its own when you spot an enemy. `/hgn test` shows a preview to drag into place; `/hgn help` lists every command.
- With **Highground**, use `/hg config` → **Guild bounties** to enable suggestions and `/hg bounty suggestions` to review them.
- Already using **Highground**? It has the same list built in (`/hg nearby`). Install Highground Nearby on its own if you only want the list.
- When Highground Bounties is loaded, Nearby stays inactive and directs you to `/hgb`, because Bounties already includes the list.

## Links

- [Join the Highground Discord](https://discord.gg/xu3VsxRjca) — addon discussions, help, bug reports and feature requests.
- [Guides, source code and issues](https://github.com/kemicofa/highground)
````
