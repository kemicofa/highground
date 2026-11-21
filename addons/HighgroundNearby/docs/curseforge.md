<!-- HighgroundNearby 0.14.0 -->
<!-- CurseForge project text. Update for every release; the build fails when the version above does not match the TOCs. -->

# CurseForge description

## Summary

Paste into the project summary (plain text, at most 200 characters):

```
Remember your own encounters. Nearby enemies, personal history, stealth alerts and compatible bounty sharing. Retail, Forever and Cata.
```

## Description

Paste everything in the block below into the project description (Markdown):

````markdown
# Highground Nearby — Open-World Enemy List

Highground Nearby keeps a list of the hostile players you have seen in the open world, most recent first. The rogue who walked past a minute ago, the mage on the hill: they're on the list, one click away. It runs on Retail, WoW Forever and Cataclysm Classic.

**Performance:** Reduced memory use in controls and fewer repeated enemy-row updates; optional bounty boards pause refreshes while hidden.

## Features

- **Window and control refresh:** Back/Forward navigation preserves supported page drafts and filters; dialogs return to the tool that opened them. Header spacing stays consistent when opening or reopening windows, including at larger text sizes. Rounded controls and focus effects follow text size and Reduced motion.
- **Panel transparency:** optionally fade idle HUD backgrounds and restore them on hover or while the panel menu is open. Text stays solid. Adjust Panel transparency and Background opacity in appearance settings.

### 👀 Who's around

- **Live nearby count:** **NEARBY: N** counts visible, living hostile players once across nameplates, target, focus and mouseover. It updates on sightings, departures and once a second, including during combat and beyond the row limit. The enabled header stays visible at **0**; remembered and combat-log-only sightings do not increase it.
- **Continuous sightings:** target, focus and mouseover rows stay fresh while the enemy remains visible. Clickable rows keep their bindings during combat; **+N after combat** includes every pending enemy. Clearing recent sightings leaves the live counter running.
- **Readable rows:** large class icon, name, level and sighting age, newest first. Row spacing and footer controls follow text size; missing class atlases use the game's class texture. Hiding spells or an earlier location supply context; hover for guild, full location and encounter details.
- Spotted from nameplates, your target, focus and mouseover. On Cataclysm Classic the combat log adds enemies hitting you without a visible nameplate.
- **Sighting sounds:** a soft two-note chime when a new enemy shows up, limited to one sighting sound per ten seconds. New installations start with five rows and nearby sounds enabled. **Sound: on/off** on the panel changes this preference; existing settings are kept.
- Rows fade once an enemy is out of sight and drop off the live list later.
- **Encounter history controls:** **History** stays available at the bottom of the panel: search or use **Previous/Next** to browse up to 1,000 saved enemies across sessions.

### 🥷 Stealth alerts

- A chat line when a nearby enemy uses **Stealth, Prowl, Vanish, Invisibility, Shadowmeld or Camouflage**, and another when it fades.
- The row shows the spell while they're hidden.
- **Stealth sounds:** when nearby sounds are enabled, a lower-pitched version of the game's stealth sound replaces the raid-warning cue on entry. Leaving stealth plays a higher-pitched version. Alert presets and muted enemies still apply; Vanish followed by Stealth produces one enter alert.
- **Stealth aura detection:** Cataclysm Classic reads applications and removals from the combat log. Retail and WoW Forever use readable enemy casts or hiding auras, and infer an exit from visible reappearance without a hiding aura. Unreadable data cannot confirm a transition.

### 📖 Enemy history

- Encounters, kills, deaths, notes and muted enemies belong to the current character, faction and realm or Forever ruleset. Switching characters restores their own records.
- Hover a row or open the journal to see encounter and kill totals. Routine sighting messages follow your alert level.
- `/hgn forget` wipes only the current character's saved history. **Undo delete** restores individual removals from the journal; Clear search and paging adapt to larger text sizes.
- **Death attribution:** enemy history uses the same conservative death reports as bounty suggestions, avoiding guesses from an earlier nonfatal hit.
- `/hgn journal` searches encounters by name, class, guild, area or note. Add notes, mute alerts or start a bounty.

### 🎯 One click

- **Left-click** a row to target the enemy, **right-click** to focus and go back to your target. WoW Forever names keep their surname and its space, so players sharing a first name remain distinct.
- In combat the rows keep their enemy; newcomers show as **+N after combat** until it ends.

### 💰 Shared bounties

- **Wanted posters and tracked hunts:** inspect captured portraits or saved likenesses, track targets, and share sightings with the bounty's audience. Screenshot reports distinguish a saved screenshot from proof of a kill or preferred finish.
- **Rewards per kill and added gold:** set a 1–20 kill goal and optional preferred finishes. Added gold follows the original poster's completion decision; each contributor records their own manual payments. Honor credit can include assists.
- **Offline bounty codes:** export a PRIVATE, GUILD, COMMUNITY or GLOBAL code and review imports before saving. Global imports do not verify funding or identity; community imports grant no membership or approval.
- **Account gold:** record balances across characters on the same server or Forever ruleset and account for outstanding commitments. Tracking starts on; Require enough gold starts off, so shortfalls warn while allowing creation.
- **Native community boards:** each existing guild or WoW character community has its own submissions, moderator approvals, sightings and claims. Membership and permissions come from the game.
- **Personal bounty records:** private lists, imports, tracking, suggestions and kill evidence stay with the current character, faction and realm or Forever ruleset. **My bounties** and claims show your records and claims you may review. Shared gold commitments remain shared.
- **Compatible sharing (new):** updated addons automatically check sharing compatibility. Bounty exchanges keep kill goals, preferred finishes and the original completion decision intact. Older clients retain the existing sharing behavior, with no setup step.

- **Wanted posters:** spotting a bounty target opens a poster with their portrait when available, otherwise a saved model likeness or class icon, reward and location. Hover to pause, drag to move, or choose **View bounty**. Alert filters and journal mutes still apply. Preview it with `/hgn bounty test nearby`.
- **Guided bounty creation:** follow the connected **Target → Reward → Review** stepper. The final step previews your wanted poster beside a clear audience, kill goal, expiry and maximum-reward summary. Go back to edit without losing the draft; nothing publishes until you confirm.
- **Bounty navigation:** **My bounties**, **Guild & communities** and **Shared board** are the main views. The **Suggestions** tab offers optional targets from repeated deaths; preferences stay under **Settings**; **Help** reopens the guide. Players from your realm appear without the realm name; other realms show `(*)`. Forever hides realm suffixes while preserving full character names.
- **Direct bounty actions:** **Share bounty**, **Edit reward** and **Claim reward** are visible in the wanted-poster window. Change your own reward with **Edit reward**; **Add gold** contributes to another player’s reward. **Manage bounty** exposes tracking, audience and withdrawal actions directly.
- **Compact posters and fixed controls:** wanted popups fit without an internal scrollbar. View bounty keeps full notes and terms in a compact details view, with one target header for multiple contributions. Actions stay outside the details scroll area, and background updates preserve your reading position.
- **Simpler sharing and onboarding:** copy a bounty link directly, or choose **Share in chat**. The shorter interactive guide follows the same creation, sharing and claim-review flow.
- Open `/hgn bounty shared` and opt in to receiving and publishing separately. Both start off. Its hidden chat channel takes the last channel number, so General, Trade and your own channels keep theirs.
- Contributions from different account IDs stack on the exact target. Choose a duration from five minutes to thirty days; the alert threshold uses the combined reward with recent available-funds reports.
- Account gold tracking starts on and checks recorded balances on the same server or Forever realmset against outstanding commitments. **Require enough gold** starts off, so a shortfall warns but permits creation; `/hgn bounty gold` changes this and shows the balances. Funding reports show **Funds reported available**, **Insufficient funds** or **Funds status unknown**. These reports do not guarantee payment.
- Claims require the poster's review; players pay through the game. Works with Highground and Highground Bounties within the realm/faction chat boundary.
- The board also supports personal alerts and submissions to your guild or native WoW communities. Guild officers and community owners, leaders and moderators approve submissions; each organization keeps its own board. `/hgn bounty claims` opens the claims ledger.

### 🔎 Bounty suggestions

- Find recurring open-world attackers with `/hgn bounty suggestions`. Enable **Bounty suggestions** under `/hgn config` → **More settings**. Suggestions and sharing your attributed deaths with guild addons have separate switches; both start off. Bounties must also be enabled.
- By default, suggest after **3 deaths against you**, or **5 deaths across 3 guild characters**, in **30 minutes**. Adjust the thresholds, distinct victim count, rolling window and notification cooldown. Exact names and realms stay separate; alts count as separate characters.
- **Reports** shows victims, times, locations and attribution sources. **Review bounty** opens an existing listing or a draft with the target, reason and audience filled in; the reward starts blank. You choose whether to save. Guild submissions still need officer approval.
- Notifications wait until combat ends. **Dismiss 24h** hides a target for one day; **Ignore enemy** lasts until you choose **Show ignored → Allow again**. Recent reports and dismissals survive reloads and switching between Highground, Bounties and Nearby.
- Only attributable open-world deaths count. NPCs, environmental deaths, duels, instanced deaths and ambiguous names are skipped. Retail and WoW Forever need a readable death recap; Cata uses fatal combat damage. Unavailable data can leave a death uncounted.
- Participating guildmates share only their own deaths through hidden addon messages while online. Reports are player-supplied evidence, not server-verified kill proof. Suggestions work independently of the nearby panel and lifetime history.

### ⚙️ Your way

- **Reachable panel controls:** the Nearby cogwheel offers lock/unlock, arrangement, enemy journal and settings. It remains faintly visible while locked, brightens on hover and stays accessible in Frameless mode. Move panels outside combat.

- **Highground by default:** Obsidian steel, luminous gold and sculpted borders, with persistent class identity wherever player data is available. Class Colors offers stronger row tinting. Explicit saved themes and appearance preferences are kept.
- **Identity and frame details:** Added metal frame details and class identity across nearby rows and enemy journal names. Bounty rewards and alert states retain their separate colours.
- **Stronger class colors:** more saturated standard colors make Rogue yellow easier to distinguish from Priest white. Class-colored text stays readable across all themes, including Parchment; custom class colors remain respected.
- **Simpler settings:** `/hgn config` starts with the panel switch, row count and sound. **More settings** reveals fade times, stealth, history and appearance.
- Drag the list anywhere, then `/hgn lock` it. Hidden in battlegrounds, arenas, dungeons and raids.
- Clearer text and focus indicators, text-size controls and **Reduced motion** are available in settings.
- **Highground** (obsidian steel, gold and class colours), **Ember** (charcoal and copper), **Parchment** (muted linen and pine), **Azeroth** (obsidian, antique gold and Warcraft titles) or **Class Colors** (Highground with stronger class tinting; theme name `classcolors`): `/hgn theme NAME`.

## Supported game versions

| | Retail | WoW Forever | Cataclysm Classic |
|---|---|---|---|
| Live nearby enemy count | ✅ | ✅ | ✅ |
| Bounty suggestions | Readable death recap | Readable death recap | Fatal combat damage |
| Nearby enemies list | ✅ | ✅ | ✅ |
| Stealth alerts and sounds | Readable casts or hiding auras, then reappearance | Readable casts or hiding auras, then reappearance | Combat log |
| Enemy history | ✅ | ✅ | ✅ |
| Personal, guild and shared bounties; manual claims | ✅ | ✅ | ✅ |
| Kills in the history | Honorable kills and death recap | Honorable kills and death recap | ✅ (combat log) |

Retail and WoW Forever hide most combat information from addons: stealth needs a readable cast or hiding aura on a visible enemy, and a kill counts only when the game names the enemy.

## Updating existing records

Older histories and bounty lists without enough ownership information remain saved but are not assigned automatically. New encounters start fresh; recreate private bounties on the intended character and ruleset. Empty History explains whether Nearby or history recording is disabled. Changing context closes stale notes, undo actions, alerts and bounty dialogs. Shared gold commitments and audience permissions are preserved.

## Getting started

- Nearby starts enabled on new installations with five rows and sighting/stealth sounds enabled. Use **Sound: on/off** on the panel to change this. Existing choices are kept: use `/hgn on` to enable it or `/hgn off` to hide it. The enabled header stays visible at zero in the open world.
- Highground is the default; select it with `/hgn theme highground`, or use `/hgn theme classcolors` for stronger class tinting.
- Open `/hgn bounty`. Choose **Create first bounty** and follow **Target → Reward → Review**, or **Browse shared bounties** to receive shared offers. Choose **Only me** for private tracking.
- Optional suggestions: enable **Bounty suggestions** under `/hgn config` → **More settings**, then open `/hgn bounty suggestions`. **Bounties** must also be on; choose separately whether to share your deaths.
- Keep both included folders installed and enabled: **HighgroundNearby** and **HighgroundBountyData**, which preserves shared contributions, account IDs, recent suggestion reports and dismissals. Restart WoW after updating to load the added sharing modules; `/reload` is not enough.
- The counter appears in the open world while enabled, including at zero; rows appear when you spot enemies. `/hgn test` shows a preview to drag into place; `/hgn help` lists every command.
- With **Highground**, use `/hg config` → **Guild bounties** to enable suggestions and `/hg bounty suggestions` to review them.
- Already using **Highground**? It has the same list built in (`/hg nearby`). Install Highground Nearby on its own if you only want the list.
- When Highground Bounties is loaded, Nearby stays inactive and directs you to `/hgb`, because Bounties already includes the list.

## Links

- [Join the Highground Discord](https://discord.gg/xu3VsxRjca) — addon discussions, help, bug reports and feature requests.
- [Guides, source code and issues](https://github.com/kemicofa/highground)
````
