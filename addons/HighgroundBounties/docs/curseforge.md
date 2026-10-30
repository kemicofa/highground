<!-- HighgroundBounties 0.5.0 -->
<!-- CurseForge project text. Update for every release; the build fails when the version above does not match the TOCs. -->

# CurseForge description

## Summary

Paste into the project summary (plain text, at most 200 characters):

```
Track repeat attackers. Optional bounty suggestions, personal and guild bounties, shared rewards and nearby alerts. Gold is paid manually. Retail, Forever, Cata.
```

## Description

Paste everything in the block below into the project description (Markdown):

````markdown
# Highground Bounties — Personal, Guild and Shared Bounties

Highground Bounties tracks personal, guild and shared bounties and alerts when a target is observed. Share a hunt with other addon users, review claims and record payments. It runs on Retail, WoW Forever and Cataclysm Classic.

## Features

### 💰 Bounty alerts

- Put a bounty on anyone, with or without gold: `/hgb add 500 target`.
- When the target shows up as your target, your mouseover or on a nameplate, you get a **sound** and a **center-screen alert**, anywhere: open world, battlegrounds and arenas.
- A **gold coin** sits beside their nameplate with the reward under it, and their tooltip names the bounty.
- Optional: tell your party or raid when you spot one.

### 📜 The bounty board

- Each row shows the reward, audience, approval status and last sighting. Open details or claims above the board. Smaller rewards stay visible below those meeting your alert minimum.
- Separate **My bounties**, **Guild board**, **Shared board** and **Suggestions** views, with search, reward totals and labelled approval status.
- Add a bounty straight from your target. Open the board with `/hgb`, a key binding or a player's right-click menu (Retail and WoW Forever).
- **Clearer creation:** enter the player first, then choose the audience and reward. Optional gold, expiry and guild requirements stay readable at larger text sizes.
- **Helpful empty boards:** see whether a search, guild membership or a shared-bounty opt-in explains an empty view. **Refresh** is enabled when the selected board can receive updates.
- **Share in chat** prepares a link for other bounty-addon users to review and import as a personal copy; choose a channel and press Enter to send.
- `/hgb claims` opens the claims ledger for manual review and payment records. `/hgb test` runs local sighting and claim previews.

### 🛡️ Guild bounties

- Submit a bounty to your guild. An officer approves it, then members using a compatible bounty addon receive it.
- Open-world sightings are shared with the guild, and on Cata your killing blow on a target tells the guild.
- Works with guild members who use **Highground**, **Highground Bounties** or **Highground Nearby**.
- A guild listing and its shared listing reuse the same contribution and claim history, so the reward is counted and paid once.
- Highground Bounties keeps the list; players pay the gold themselves.

### 🌍 Shared bounties

- Open `/hgb shared` and opt in to receiving and publishing separately. Both start off.
- Contributions from different account IDs stack on the exact target. Each lasts from five minutes to thirty days; the alert threshold uses the combined reward with recent available-funds reports.
- Carried gold is checked against outstanding commitments. The board shows **Funds reported available**, **Insufficient funds** or **Funds status unknown**; these reports cannot guarantee payment.
- Each contribution has one winner, chosen by its poster after reviewing claims. Approved debts remain in the ledger after expiry; payments are recorded manually.
- Works with Highground and Highground Nearby within the realm/faction chat boundary. A saved contributor ID deduplicates ordinary account use, but is not a verified Blizzard identity.

### 🔎 Bounty suggestions (new)

- Find recurring open-world attackers with `/hgb suggestions`. Enable **Bounty suggestions** under `/hgb config` → **More settings**. Suggestions and sharing your attributed deaths with guild addons have separate switches; both start off. Bounties must also be enabled.
- By default, suggest after **3 deaths against you**, or **5 deaths across 3 guild characters**, in **30 minutes**. Adjust the thresholds, distinct victim count, rolling window and notification cooldown. Exact names and realms stay separate; alts count as separate characters.
- **Reports** shows victims, times, locations and attribution sources. **Review bounty** opens an existing listing or a draft with the target, reason and audience filled in; the reward starts blank. You choose whether to save. Guild submissions still need officer approval.
- Notifications wait until combat ends. **Dismiss 24h** hides a target for one day; **Ignore enemy** lasts until you choose **Show ignored → Allow again**. Recent reports and dismissals survive reloads and switching between Highground, Bounties and Nearby.
- Only attributable open-world deaths count. NPCs, environmental deaths, duels, instanced deaths and ambiguous names are skipped. Retail and WoW Forever need a readable death recap; Cata uses fatal combat damage. Unavailable data can leave a death uncounted.
- Participating guildmates share only their own deaths through hidden addon messages while online. Reports are player-supplied evidence, not server-verified kill proof. Suggestions work independently of the nearby panel and lifetime history.

### 👀 Nearby enemies

- An open-world list of hostile players you have seen, most recent first, with level, guild and zone.
- Left-click targets, right-click focuses. Bounty targets get a gold frame.
- **Stealth alerts:** a chat line when a nearby enemy uses Stealth, Prowl, Vanish, Invisibility, Shadowmeld or Camouflage, and when it fades.
- **Enemy history:** every enemy you meet is remembered, with kills both ways. Hover a row for encounter and kill totals; routine sightings follow your alert level. `/hgb nearby forget` wipes it.
- **Death attribution (new):** enemy history uses the same conservative death reports as bounty suggestions, avoiding guesses from an earlier nonfatal hit.
- `/hgb journal` searches encounters and lets you add notes or mute an enemy's alerts.
- **Undo delete:** restore a removed encounter. Clear search and paging adapt to larger text sizes.
- **Alert controls:** `/hgb alerts` offers presets and separate text and sound controls by category.

### 🎨 Themes

- Clearer text and focus indicators, labelled status chips, adjustable text size and **Reduced motion**. Buttons, menus and windows animate; Reduced motion keeps tactical cues steady and transitions instant.
- **Highground** (cool slate and teal), **Ember** (charcoal and copper), **Parchment** (muted linen and pine) or **Azeroth** (obsidian, antique gold and Warcraft titles): `/hgb theme NAME`.

## Supported game versions

| | Retail | WoW Forever | Cataclysm Classic |
|---|---|---|---|
| Bounty suggestions | Readable death recap | Readable death recap | Fatal combat damage |
| Bounty alerts, nameplate coins, bounty board | ✅ | ✅ | ✅ |
| Guild bounties | ✅ | ✅ | ✅ |
| Right-click menu entry | ✅ | ✅ | — |
| Manual claims and payment records | ✅ | ✅ | ✅ |
| Automatic killing-blow reports | — | — | ✅ |
| Shared contributions and funding reports | ✅ | ✅ | ✅ |
| Nearby enemies and enemy history | ✅ | ✅ | ✅ |
| Stealth alerts | Enemies you can see | Enemies you can see | ✅ |

## Getting started

- Optional suggestions: enable **Bounty suggestions** under `/hgb config` → **More settings**, then open `/hgb suggestions`. **Bounties** must also be on; choose separately whether to share your deaths.
- Keep both included folders installed and enabled: **HighgroundBounties** and **HighgroundBountyData**, which preserves shared contributions, account IDs, recent suggestion reports and dismissals. Restart the game after installation or updates.
- Type `/hgb` to open the bounty board, `/hgb config` for settings and `/hgb help` for every command. Main choices appear first; **More settings** reveals detailed controls.
- With **Highground**, use `/hg config` → **Guild bounties** to enable suggestions and `/hg bounty suggestions` to review them.
- Already using **Highground**? It has bounties built in (`/hg bounty`). Install Highground Bounties on its own if you only want the bounties.
- Highground Nearby stays inactive while Bounties is loaded, because Bounties includes the nearby list.

## Links

- [Join the Highground Discord](https://discord.gg/xu3VsxRjca) — addon discussions, help, bug reports and feature requests.
- [Guides, source code and issues](https://github.com/kemicofa/highground)
````
