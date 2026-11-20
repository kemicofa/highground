<!-- HighgroundBounties 0.12.1 -->
<!-- CurseForge project text. Update for every release; the build fails when the version above does not match the TOCs. -->

# CurseForge description

## Summary

Paste into the project summary (plain text, at most 200 characters):

```
Choose the hunt. Wanted posters, community boards, shared rewards per kill, account gold and tracked sightings. Review claims and record payments. Retail, Forever and Cata.
```

## Description

Paste everything in the block below into the project description (Markdown):

````markdown
# Highground Bounties — Personal, Guild, Community and Shared Bounties

Highground Bounties tracks personal, guild, community and shared bounties and alerts when a target is observed. Share a hunt with other addon users, review claims and record payments. It runs on Retail, WoW Forever and Cataclysm Classic.

**Performance:** Reduced memory use in controls; the bounty board pauses refreshes while hidden and refreshes less often when its contents are unchanged.

## Features

- **Window and control refresh:** Back/Forward navigation preserves supported page drafts and filters; dialogs return to the tool that opened them. Refreshed headers, rounded controls and focus effects follow text size and Reduced motion.
- **Panel transparency:** optionally fade idle HUD backgrounds and restore them on hover or while the panel menu is open. Text stays solid. Adjust Panel transparency and Background opacity in appearance settings.

### 💰 Bounty alerts

- Put a bounty on anyone, with or without gold: `/hgb add 500 target`.
- When the target shows up as your target, focus, mouseover or on a nameplate, you get a **sound** and a **wanted poster**, anywhere: open world, battlegrounds and arenas. The poster shows their portrait when available, otherwise a saved model likeness or class icon, plus the reward, note and location. Hover to pause, drag to move, or choose **View bounty**. Preview it with `/hgb test nearby`.
- A **gold coin** sits beside their nameplate with the reward under it, and their tooltip names the bounty.
- Optional: tell your party or raid when you spot one.

### 📜 The bounty board

- **Wanted posters and tracked hunts:** inspect captured portraits or saved likenesses, track targets, and share sightings with the bounty's audience. Screenshot reports distinguish a saved screenshot from proof of a kill or preferred finish.
- **Rewards per kill and added gold:** set a 1–20 kill goal and optional preferred finishes. Added gold follows the original poster's completion decision; each contributor records their own manual payments. Honor credit can include assists.
- **Offline bounty codes:** export a PRIVATE, GUILD, COMMUNITY or GLOBAL code and review imports before saving. Global imports do not verify funding or identity; community imports grant no membership or approval.
- **Account gold:** record balances across characters on the same server or Forever ruleset and account for outstanding commitments. Tracking starts on; Require enough gold starts off, so shortfalls warn while allowing creation.
- **Native community boards:** each existing guild or WoW character community has its own submissions, moderator approvals, sightings and claims. Membership and permissions come from the game.
- **Forever ruleset separation:** bounty lists and tracking stay within the active ruleset. Older unscoped lists remain saved but are not automatically assigned; review or recreate targets in the correct ruleset.

- **Bounty workspace:** a three-step guide offers **Create first bounty** or **Browse rewards**. Creation, claims, shared alert settings and suggestion reports stay in one window. Wanted-poster details open separately and return to the board; **Back/Forward** preserves drafts and filters, while **Back to board** discards a draft. Numbered forms explain audiences and next steps; long forms scroll at enlarged text sizes.
- **Bounty navigation:** **My bounties**, **Guild & communities** and **Shared board** are the main views. The **Suggestions** tab offers optional targets from repeated deaths; preferences stay under **More tools**; **Help** reopens the guide. Players from your realm appear without the realm name; other realms show `(*)`. Forever hides realm suffixes while preserving full character names.
- **Claims & payments:** open a shared bounty to **Report kill** or **Add gold**. Follow reviews and record manual payments in **Claims & payments**. Empty lists explain what to do next; unused history and claim rows stay hidden.
- Each row shows the reward, audience, approval status and last sighting. Open the wanted poster for details; closing it restores the board. Claims stay in the board window with **Back to board**. Smaller rewards stay visible below those meeting your alert minimum.
- **My bounties**, **Guild & communities** and **Shared board** have search, reward totals and labelled approval status. Suggestions have their own tab; preferences live under **More tools**.
- Add a bounty straight from your target. Open the board with `/hgb`, a key binding or a player's right-click menu (Retail and WoW Forever).
- **Clearer creation:** enter the player first, then choose the audience and reward. Optional gold, expiry and guild requirements stay readable at larger text sizes.
- **Helpful empty boards:** see whether a search, guild membership or a shared-bounty opt-in explains an empty view. **Refresh** appears when the selected board can receive updates.
- **Share in chat** prepares a link for other bounty-addon users to review and import as a personal copy; choose a channel and press Enter to send.
- `/hgb claims` opens the claims ledger for manual review and payment records. `/hgb test` opens an interactive tour of creating, tracking, sharing, account gold, screenshots and claims using isolated samples.

### 🛡️ Guild and community bounties

- Choose **Guild / community** and select an organization you belong to. Guild officers and community owners, leaders and moderators approve submissions; ordinary members submit for review. Each organization has its own board, sightings and claims, including communities spanning realms. Clients without native communities offer guilds only.
- Open-world sightings are shared with the guild, and on Cata your killing blow on a target tells the guild.
- Works with guild members who use **Highground**, **Highground Bounties** or **Highground Nearby**.
- A guild listing and its shared listing reuse the same contribution and claim history, so the reward is counted and paid once.
- Highground Bounties keeps the list; players pay the gold themselves.

### 🌍 Shared bounties

- Open `/hgb shared` and opt in to receiving and publishing separately. Both start off. Its hidden chat channel takes the last channel number, so General, Trade and your own channels keep theirs.
- Contributions from different account IDs stack on the exact target. Each lasts from five minutes to thirty days; the alert threshold uses the combined reward with recent available-funds reports.
- Account gold tracking is on by default: balances recorded across characters on the same server or Forever realmset cover commitments. **Require enough gold** is off by default; a low balance warns while you enter the reward and still allows creation. **Gold & settings** shows the breakdown and changes that requirement; hovering bag gold also shows the balances. Log into each alt to record its gold. The board reports **Funds reported available**, **Insufficient funds** or **Funds status unknown**; these reports cannot guarantee payment.
- Rewards pay per approved kill, up to a 1–20 kill goal. Independent originals keep their own reviewers; **Add gold** contributions follow the selected original poster's completion decision. Different hunters can earn different kills. Approved debts remain in the ledger after expiry, and each contributor records manual payments.
- Works with Highground and Highground Nearby within the realm/faction chat boundary. A saved contributor ID deduplicates ordinary account use, but is not a verified Blizzard identity.

### 🔎 Bounty suggestions

- Find recurring open-world attackers with `/hgb suggestions`. Enable **Bounty suggestions** under `/hgb config` → **More settings**. Suggestions and sharing your attributed deaths with guild addons have separate switches; both start off. Bounties must also be enabled.
- By default, suggest after **3 deaths against you**, or **5 deaths across 3 guild characters**, in **30 minutes**. Adjust the thresholds, distinct victim count, rolling window and notification cooldown. Exact names and realms stay separate; alts count as separate characters.
- **Reports** shows victims, times, locations and attribution sources. **Review bounty** opens an existing listing or a draft with the target, reason and audience filled in; the reward starts blank. You choose whether to save. Guild submissions still need officer approval.
- Notifications wait until combat ends. **Dismiss 24h** hides a target for one day; **Ignore enemy** lasts until you choose **Show ignored → Allow again**. Recent reports and dismissals survive reloads and switching between Highground, Bounties and Nearby.
- Only attributable open-world deaths count. NPCs, environmental deaths, duels, instanced deaths and ambiguous names are skipped. Retail and WoW Forever need a readable death recap; Cata uses fatal combat damage. Unavailable data can leave a death uncounted.
- Participating guildmates share only their own deaths through hidden addon messages while online. Reports are player-supplied evidence, not server-verified kill proof. Suggestions work independently of the nearby panel and lifetime history.

### 👀 Nearby enemies

- **Live nearby count:** **NEARBY: N** counts visible, living hostile players once across nameplates, target, focus and mouseover. It updates on sightings, departures and once a second, including during combat and beyond the row limit. The enabled header stays visible at **0**; remembered and combat-log-only sightings do not increase it.
- **Continuous sightings:** target, focus and mouseover rows stay fresh while the enemy remains visible. Clickable rows keep their bindings during combat; **+N after combat** includes every pending enemy. Clearing recent sightings leaves the live counter running.
- An open-world list of hostile players you have seen, most recent first: large class icon, name, level and sighting age. Hiding spells or an earlier location supply context; guild and full location stay in hover details.
- Left-click targets, right-click focuses and returns to your previous target. WoW Forever sightings and clicks keep the full player name, including its surname and space. Bounty targets get a gold frame.
- **Nearby sounds:** new enemies play a soft two-note chime. Sounds start enabled on new installations; **Sound: on/off** on the panel changes the preference. Existing preferences, global alert settings and muted enemies still apply.
- **Stealth alerts:** a chat line when a nearby enemy uses Stealth, Prowl, Vanish, Invisibility, Shadowmeld or Camouflage, and when it fades.
- **Stealth sounds:** when nearby sounds are enabled, a lower-pitched version of the game's stealth sound replaces the raid-warning cue on entry. Leaving stealth plays a higher-pitched version. Alert presets and muted enemies still apply; Vanish followed by Stealth produces one enter alert.
- **Stealth aura detection:** Cataclysm Classic reads applications and removals from the combat log. Retail and WoW Forever use readable enemy casts or hiding auras, and infer an exit from visible reappearance without a hiding aura. Unreadable data cannot confirm a transition.
- **Enemy history:** every enemy you meet is remembered, with kills both ways. Hover a row for encounter and kill totals; routine sightings follow your alert level. `/hgb nearby forget` wipes it.
- **Death attribution:** enemy history uses the same conservative death reports as bounty suggestions, avoiding guesses from an earlier nonfatal hit.
- **Encounter history controls:** **History** on the nearby panel opens saved enemies even when the live list is empty. Search or use **Previous/Next** to browse up to 1,000 enemies across sessions. `/hgb journal` opens the same journal, with notes and per-enemy muting.
- **Undo delete:** restore a removed encounter. Clear search and paging adapt to larger text sizes.
- **Alert controls:** `/hgb alerts` offers presets and separate text and sound controls by category.

### 🎨 Themes

- **Reachable panel controls:** the Nearby cogwheel offers lock/unlock, arrangement, enemy journal and settings. It remains faintly visible while locked, brightens on hover and stays accessible in Frameless mode. Move panels outside combat.

- **Highground by default:** Obsidian steel, luminous gold and sculpted borders, with persistent class identity wherever player data is available. Class Colors offers stronger row tinting. Explicit saved themes and appearance preferences are kept.
- **Identity and frame details:** Added metal frame details, gold primary actions and class-coloured names for observed bounty targets. Nearby rows and the enemy journal retain class identity.
- **Stronger class colors:** more saturated standard colors make Rogue yellow easier to distinguish from Priest white. Class-colored text stays readable across all themes, including Parchment; custom class colors remain respected.
- Clearer text and focus indicators, labelled status chips, adjustable text size and **Reduced motion**. Buttons, menus and windows animate; Reduced motion keeps tactical cues steady and transitions instant.
- **Highground** (obsidian steel, gold and class colours), **Ember** (charcoal and copper), **Parchment** (muted linen and pine), **Azeroth** (obsidian, antique gold and Warcraft titles) or **Class Colors** (Highground with stronger class tinting; theme name `classcolors`): `/hgb theme NAME`.

## Supported game versions

| | Retail | WoW Forever | Cataclysm Classic |
|---|---|---|---|
| Live nearby enemy count | ✅ | ✅ | ✅ |
| Bounty suggestions | Readable death recap | Readable death recap | Fatal combat damage |
| Bounty alerts, nameplate coins, bounty board | ✅ | ✅ | ✅ |
| Guild bounties | ✅ | ✅ | ✅ |
| Right-click menu entry | ✅ | ✅ | — |
| Manual claims and payment records | ✅ | ✅ | ✅ |
| Automatic kill reports | Named honor credit (may include assists) | Named honor credit (may include assists) | Observed killing blow |
| Shared contributions and funding reports | ✅ | ✅ | ✅ |
| Nearby enemies and enemy history | ✅ | ✅ | ✅ |
| Stealth alerts and sounds | Readable casts or hiding auras, then reappearance | Readable casts or hiding auras, then reappearance | Combat log |

## Getting started

- Nearby starts enabled on new installations with five rows and sighting/stealth sounds enabled. Use **Sound: on/off** on the panel to change this. Existing choices are kept: use `/hgb nearby on` to enable it or `/hgb nearby off` to hide it. The enabled header stays visible at zero in the open world.
- Highground is the default; select it with `/hgb theme highground`, or use `/hgb theme classcolors` for stronger class tinting.
- Open `/hgb`. Choose **Create first bounty** for a private target, or **Browse rewards** to visit the shared board.
- Optional suggestions: enable **Bounty suggestions** under `/hgb config` → **More settings**, then open `/hgb suggestions`. **Bounties** must also be on; choose separately whether to share your deaths.
- Keep both included folders installed and enabled: **HighgroundBounties** and **HighgroundBountyData**, which preserves shared contributions, account IDs, recent suggestion reports and dismissals. Restart WoW after updating to load the new modules and textures; `/reload` is not enough.
- Type `/hgb` to open the bounty board, `/hgb config` for settings and `/hgb help` for every command. Main choices appear first; **More settings** reveals detailed controls.
- With **Highground**, use `/hg config` → **Guild bounties** to enable suggestions and `/hg bounty suggestions` to review them.
- Already using **Highground**? It has bounties built in (`/hg bounty`). Install Highground Bounties on its own if you only want the bounties.
- Highground Nearby stays inactive while Bounties is loaded, because Bounties includes the nearby list.

## Links

- [Join the Highground Discord](https://discord.gg/xu3VsxRjca) — addon discussions, help, bug reports and feature requests.
- [Guides, source code and issues](https://github.com/kemicofa/highground)
````
