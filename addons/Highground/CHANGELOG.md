# Changelog

Release versions match both addon TOC files. The latest version is listed first.

## Unreleased

- Nearby: on WoW Forever and Retail, your killing blows on enemy players now count in your Nearby history, the enemy journal, World activity and the enemy heatmap's **Kills here**. They counted only when an honor message named the enemy, and WoW Forever players saw 0 kills. Your pet's killing blows count too, and a killing blow with its honor message counts once.

## [3.3.1] - 2026-11-27

- Arena: the Arena addon is now off by default on Retail and Cataclysm Classic. To use the Arena panel, turn on **Enable addon** in **Arena → Overview and enable** (or the **Addons** page, `/hg guide`) and reload. Characters that already have a saved Arena choice in WoW's AddOn List keep it.

## [3.3.0] - 2026-11-26

- Coming from 3.2 or earlier, restart the game after updating: 3.3.0 adds new addon folders. From the 3.3.0 alpha or beta, `/reload` is enough.
- Battlegrounds: shift-click the **Win forecast** or a resurrection or **Timers** countdown to share it in chat, such as "Horde res at Stables in 12s" or "Forecast: Alliance wins in 3:10 · Horde needs 3 bases". The line goes into your chat box on the callout channel (`/hg call s|i|raid|party|y`, say by default), or into the message you are typing; press Enter to send it, which works during matches. What the game already shows everyone, such as the score, base owners and flag carriers, is left out. Previews and the Objectives guide print the sample instead.
- Quick callouts: **Enemies going to** has an **All clear** button beside **1**, **2** and **3+**, which sends `All clear — Farm` for the chosen destination.
- **Match history** keeps every objective event of a match, up to 1,000 (enough for a long Alterac Valley), instead of the last 200. Full timelines move to a new bundled addon, **HighgroundMatchData**, whose saved data loads only when you open an older match or after a battleground once 20 new timelines wait. Logging in no longer loads every character's old timelines: in a simulated full 100-match history, about 74 KiB of memory instead of 4 MiB per character. Existing timelines move there the first time it loads. Keep the new folder with Highground; without it, Highground keeps 200 events per match as before.
- Highground uses less memory from login. Settings pages, the Profiles page and the profile export window are built the first time you open them instead of at login, and buttons add their hover and highlight effects the first time you use them. Logging in now creates about a fifth of the interface objects it did, and Nearby and Bounties settings are never built while those addons are off.
- Open maps use much less memory. The world map, the zone map and the battleground map updated every pin, circle, heat square and timer by building it again, every second in the open world and twice a second in battlegrounds; they now update them in place, for about nine tenths less garbage with both maps open in a simulated busy zone or match. Sightings, marks, kills and tracking reports that name a map your client doesn't know are ignored. Turning the enemy heatmap or World map sightings off discards the heat gathered so far.
- Battlegrounds make less garbage while you play. The enemy list reads an enemy's buffs and debuffs when the game reports a change instead of four times a second, the win forecast reads the score when it changes, and stealth alerts, Timers and arena activity share one read of each combat-log line: in a simulated 15v15 match Highground makes three quarters less garbage on Retail and a third to two thirds less on Cataclysm, depending on how often auras change. Saved team healer marks now follow the same limits as remembered specs (seen in the last 120 days, at most 4,000), and unused max mana and health records saved after each match are removed. In world fights, someone opening a chest or a mailbox is no longer taken for a base capture.
- Highground uses about 6 MB less memory. It kept the text of all eleven languages loaded; now English loads with Highground and each other language is its own folder in the download (`HighgroundLocale*`, listed as **Highground language: …** in WoW's AddOn List), loaded only when you choose it or **Use game language** needs it. Switching languages is still instant. If a language's folder is missing or turned off, Highground shows English and the language picker says how to get it back. Battleground announcements in other game languages are no longer kept either. Manual installs: copy the new `HighgroundLocale*` folders with the others.
- Guides with sample panels use much less memory. Starting and leaving their panel samples repainted every Highground window, which left tens of MB of garbage per Battlegrounds guide on Retail and WoW Forever. Quick callouts and the enemy list now stay on screen between steps instead of disappearing for a moment on each **Next**.
- **Enemy journal**: **All**, **Tracked** and **Bounty** beside the search show every enemy, only tracked enemies or only enemies with a bounty; `/hg journal tracked|bounty|all` opens it that way. Tracked enemies and bounty targets are never deleted: a full journal makes room with someone else, `/hg nearby forget` keeps them and **Delete entry** says why it can't.
- Guides: **Next** always works. When a step asks you to click something, Next clicks it for you, and if the sample refuses (a form you changed), it moves on anyway. Hints now say "Click History, or Next." Guide cards show **In progress** or **Completed**, finishing a guide says so, and when a guide can't start (in combat or a match, or with every panel off), the reason appears on its card instead of the window's footer. The Reputation guide is 13 steps instead of 20, and the step count leaves out steps your choices skip, such as payment after a rejected claim.
- Reputation: **Details** is a player card instead of a block of text. It shows the state, approved categories as badges, the public explanation and a timeline of decisions; moderators also get reporter and pending counts and each report with its note and review status. When your Nearby history knows the player, their class, guild and your encounters are listed. The History tab and Details name states such as **Awaiting review** instead of internal words.
- Arena: duels no longer open the Arena panel; it is for arena matches on Retail and Cataclysm Classic. WoW Forever has no arenas, so Highground there has no Arena addon: no pages, commands, guide chapter, previews or profile entries.
- Battlegrounds do less work while you play. The kill-order panel, Timers, the win forecast, map intel and bounty kill tracking reuse what they already know instead of rebuilding it several times a second: in a simulated 15v15 match Highground makes about two thirds less garbage on Cataclysm and a quarter less on WoW Forever. The panel also follows a focus change at once, as it does for your target, and a capture bar leaves a nameplate as soon as that nameplate goes away instead of up to a quarter second later over another unit.
- **World activity** has a sample: `/hg activity test`, or **World activity** on Nearby's Previews page. `/hg nearby guide` starts the Nearby walkthrough, like `/hg guide nearby`.
- **Enemy heatmap**: the world, zone and continent maps shade where enemies were seen and who won the fights there in the last hour, from your sightings and kills, your group's and guild's, and every Highground user's in any zone; newer data counts more. Heat is the enemy faction's colour, Horde red or Alliance blue, or yours where your side killed more, strongest where an enemy raid gathered. Squares with kills get a badge with the leading side's crest and both sides' kills (`5–2`); hover a square for details. Switch it under **Nearby → Settings** or with `/hg nearby heat on|off`; `/hg nearby test` shows sample heat, fights, marks and enemies around you, placed like real sightings on the zone, continent and world maps.
- **Share sightings with every Highground user** (on by default, `/hg nearby share world on|off`): Nearby sends the enemies you see to Highground users of your faction on the realm as a map square about 5% of the zone wide, never your spot, and lists theirs from your zone. Bounties now show their reward on world map tooltips and on World activity kills.
- **World activity** (`/hg activity`, or from Nearby's overview) shows the zones where you, your group or your guild recently saw enemies, marked the map or traded kills, with classes, guilds, marks and the last kills, and opens the map on a zone. Nearby now shares your kills of enemy players and your deaths to them with your group and guild for this list (**Share kills and deaths**).
- Nearby map marks: Alt+right-click a zone map to mark **Enemies here**, a **Ganker** or **Help needed**, or mark where you stand with `/hg nearby mark` or a key binding. Your group and guild see the marks on their maps; with an opt-in, every Highground user of your faction on the realm does. **World PvP calls** alert you in your zone when your group or guild spots an enemy who often kills you, when an enemy raid gathers, or when someone marks the map. Both have switches in Nearby's settings.
- Nearby can track enemies. Click **Track** on an enemy in the journal, or type `/hg nearby track NAME` (or `target`). When you, your group or your guild see a tracked enemy, an alert says where they are, they are listed from any zone and they get their own pin on the world map. **Watch for tracked enemies with every Highground user** (on by default, `/hg nearby watch on|off`) has Highground users of your faction on the realm watch for yours, and report theirs, with a rough location; everyone in that channel sees whom you track.
- **Kill order in world fights**: in a party or raid in the open world, Highground's kill order, health bars, healer markers and **on you** signals now run on the enemies you and your group see, as in a battleground. The board appears once an enemy is seen in your zone and leaves a minute after the last one. Switch it under Nearby or with `/hg nearby fights on|off`.
- Resurrection timers count an enemy's death from when it happened. Highground took a death you saw at its once-a-second map scan, up to a second late; it now uses the moment it saw the death. On Retail and Cataclysm, a teammate's shared death was timed when the message arrived, up to about three seconds late, which could put a wave in the wrong window; shared deaths now carry their age, and teammates on older versions still get the death, timed as before.
- Spec tags reach teammates who need them on Retail and Cataclysm. A tag that arrived before the scoreboard listed that enemy (it can lag several seconds) was dropped; it now applies once the enemy is listed. Joining a match or reloading in one asks the team to send their tags again, so a teammate who arrives late sees the tags set before they came.
- Nearby shares the enemies you see with your party or raid and your guild, and lists the ones they see: a shared row says who saw it. **World map sightings** shows your own and shared sightings on the world map and zone map, with a circle for how far away each enemy could be and one pin with a count for enemies close together. Battlegrounds stop addons from talking to each other; the open world doesn't. Switch each part under **Nearby → Settings**, or with `/hg nearby map on|off`, `/hg nearby share on|off` and `/hg nearby share guild on|off`. Shared sightings never sound or count as your own encounters.
- Battlegrounds: on WoW Forever, enemies targeting you are recognized again. The game hides whether you are their target, so only the row's eye lit; Highground now reads their target's name, and the card says **on you** and the reasons **targeting YOU** there too. An enemy targeting one of your team healers shows **on healer NAME** on the card and scores **Targeting one of your healers** (10 points, **Live signals**) so you can peel. The panel header counts the enemies in view targeting you (**· 3 ON YOU**). The Korean and Chinese **on you** text is readable again.
- Enemy Journal: on WoW Forever, enemies met before the game names your ruleset, right after logging in, no longer reset that enemy's saved encounters, kills and first meeting; they add up. A damaged saved entry no longer keeps the journal from opening or breaks sightings of that enemy, and a long note is cut at 500 bytes without breaking a character.
- Addon messages keep moving: bounty whispers and guild messages no longer wait behind a bounty channel the game can't join (for example at the ten-channel limit), and a message the game refuses for good is dropped instead of retried forever. The newer-version notice now needs a guild or group member, or two characters in the realm channel, to report a release at most one major version ahead.
- Bounties and Reputation are marked **Alpha**: they can still change and have more bugs. A small badge follows their names on their overview pages, the Addons guide cards, the Bounties board and the Reputation window; hover it for what that means. WoW's AddOn List names their modules "(module, alpha)".
- **Reset target tuning** (Target behavior) no longer resets the Nearby and Bounties settings or Nearby's **Enemies shown**: it resets scoring values, multipliers, spec ratings and Target behavior, as it says. Settings **-** and **+** stop at the lowest and highest value instead of printing an error, and Nearby's **Enemies shown** **Default** is the setting's default, 10 (new installations start at 5). Previews and Commands pages now change their titles with the language.
- The Highground window stays open on **Addons** when you enter combat or an instance, and this no longer dismisses the guide. Closing the window also clears the guide chapters from its Back history. `/hg` ignores spaces before and after a command: `/hg arena test ` starts the preview and `/hg profile load Name ` finds the profile.
- Macros: on non-English Cataclysm, WoW Forever and Classic clients, the priest's **Dispel MO** and **Dispel**, the druid's **Decurse** and the shaman's **Cure Disease** presets cast their own spell instead of Cure Disease or the mage's or priest's spell. **Save for all characters** and **Copy to all/this character** now ask before replacing a saved macro of the same name with other text, and the import preview says "replaces" only for a macro in the tab it names. **Quiet Trinket 1** no longer leaves sound effects off after two quick presses; a copy you saved earlier keeps the old text until you save the preset again.
- Arena: each Solo Shuffle round starts with the new opponents' rows, specs and trinkets instead of the last round's. When the game announces no specs before the gates, the panel shows a row for each opponent of your bracket before combat, so one revealed in combat can still be targeted from it.
- Reputation works on WoW Forever again. The game marks addon messages there as restricted even when they send, and Reputation took that at its word: it sent no proposals, decisions or updates. Now only chat lockdown pauses sharing, as for the rest of Highground. Reports, `/hgrep report NAME` and player menus also take a name without a realm (First Surname): WoW Forever no longer gives one, and Reputation asked for it.
- Reputation holds up in large, long-lived guilds and communities. A full moderation history drops decisions that no longer change anything instead of refusing new ones, and a decision on a player with hundreds of reports no longer stalls every update: reports it can't cover stay in **Proposals**. One character counts once per reported player and keeps at most 50 reports; reviewed reports leave after 180 days. Other members' reports also leave when you were removed from a guild or community while logged out.
- `/hg bounty submit`, `approve`, `reject`, `remove` and `claim` work again in languages other than English. They stopped with a Lua error.
- Bounties on WoW Forever no longer alert for another player with the same first name. Sharing a guild or private bounty with everyone keeps the kills already paid, a kill from before a bounty was posted no longer counts, and guild kill reports from a computer whose clock is off are no longer lost. Another player can no longer copy your account ID to mark your shared bounties unfunded or block your posts, or flood the shared board, and a target can no longer change its own wanted portrait. Unanswered claims and imported bounties now expire instead of filling the claims page and the board.
- The game no longer freezes when an enemy leaves a battleground just before Highground redraws the kill-order panel, such as when you leave combat: the panel kept laying out the departed enemy's row without end.
- Battleground fixes: burst markers no longer stay on screen after you leave a match or sit on another player's nameplate. Enemies seen dying on Retail and WoW Forever stay dead while out of view instead of reviving after 4 seconds, so a rogue's sap call no longer repeats. Enemies seen only through a teammate's target show when they target you. Your own capture in a raid shows as **You**. With **Battleground timers** off, capture alerts and capture nameplate bars stay off, as their greyed-out switches say. `/hg burst test` and `/hg sniper test` stop when a match starts, and `/hg cap why` works on WoW Forever. On WoW Forever, where battleground messages can give only a first name, a first name both teams use no longer marks a teammate as the enemy flag carrier or an enemy as you.
- Resurrection timers see your and your teammates' revivals again with **Enemy map positions** off; until now those timed no wave, shared nothing and taught no revive lag. In Alterac Valley, Isle of Conquest and other maps with landmarks named "… Graveyard", a revival with no known spot no longer adds a phantom graveyard on the first of them, which hid the real one's timer and came back every match; saved ones are removed. Match history no longer fills with time-left, reinforcement and cart counters, and counts a match once after a `/reload` on its final scoreboard. A disconnect of more than two minutes continues the same match instead of losing its first part; a match that ends while you are away is saved as **Left early**.
- The main panel and the Quick callout panel no longer stay stuck to the cursor, or set off a blocked-action error, when combat starts during a drag or a position reset: they stop or move once combat ends. A hovered map pin's tooltip no longer flickers twice a second; it updates in place. The Quick callout panel and the target marker do less work: messages are made again only when they change, and a target without a nameplate is no longer searched for among all nameplates.
- Battlegrounds take shared sightings, resurrection timers, captures and spec tags only from your group. Before, any player could whisper made-up ones to you, and whispered spec tags were kept for later matches. Base and area names from teammates show as plain text, and teammates' captures appear only in a match, not in `/hg bg test`.
- WoW Forever: **Share observations** is gone from Battlegrounds → Settings there, and `/hg intel share on` explains why. Forever blocks addon messages for a whole battleground match, so sightings, resurrection timers, base captures and spec tags never reached teammates; Highground no longer prepares them. Your own sightings and the game's base announcements still mark enemies on the map.
- Resurrection and Timers rows give names the room their clock does not use: "25s" no longer reserves space for "~1:25", so names such as Warsong Gulch's "Alliance Base Graveyard" are no longer cut off.
- WoW Forever estimates enemy druids from their forms. The game hides enemy specs there, but not whether a druid is on mana (caster or Moonkin form), rage (bear) or energy (cat). A druid mostly out of cat and bear form over about ten seconds in view shows **~Restoration** and gets the red healer cross; one mostly in cat or bear form shows **~Feral**. A druid seen in Moonkin form shows **~Balance** where the game lets addons read their model (unverified in a match); otherwise Balance also reads as Restoration until you tag it. Your tags, the scoreboard and earlier matches always win, and druids below level 20 are never guessed healers.
- Battleground maps read flag positions through the game's current API. Highground still asked the old one, which no longer exists, so it never got any on WoW Forever or Retail. On WoW Forever your own team's flag carrier has a position and the enemy carrier has none, even in view: while you carry a flag, Highground again learns where your part of the map is. Where a client gives the enemy carrier's position too, the map places that carrier on it.
- Green healer crosses now work on WoW Forever, where the game gives every teammate the damage role. Before the gates open, Highground inspects teammates whose class can heal, one at a time, and marks those with the most points in a healing tree; teammates out of range are inspected once they come close. Mark or unmark anyone yourself: hover over a teammate (nameplate, raid frame or character) and press the new **Mark team healer** key, type `/hg healer` (or `/hg healer NAME`), or open **Team healers** (`/hg healers`, or **Battlegrounds → Settings → Team healers**). Your mark beats an inspect. Marks are kept for later matches on this client; Forever's chat lockdown keeps them from being shared. The green cross also shows on Blizzard's raid and party frames. Turn inspecting off with **Inspect teammates for healers** under Healer markers. `/hg healers test` shows sample teammates.
- Healer markers and the target marker only appear on units with a nameplate, so the game's nameplate settings decide how far they reach. **Battlegrounds → Settings → Nameplates** now sets **Nameplate range** (20 to 60 yards; the game may cap it lower), **Always show nameplates** (every unit in range, not only your target and units in combat) and **Friendly player nameplates**, which green healer markers need. They are the game's own settings, so the game saves them and they can't change in combat. `/hg nameplates` shows them; `/hg nameplates range 60`, `/hg nameplates all on|off` and `/hg nameplates friends on|off` change them.
- WoW Forever shows **CC** again on an enemy that is stunned, feared, sapped or otherwise crowd-controlled. Forever refuses addons enemy buffs and debuffs, but still says how many loss-of-control effects an enemy in view has; Highground uses that count. It can't tell which kind of control or how long it lasts, so CC there doesn't protect breakable control or score as a stun. `/hg bg profiler start` records when each one starts and ends.
- WoW Forever doesn't let players put raid icons on enemy players, so Highground stops offering it there. `/hg mark icon` explains that the mark key pings instead, its Commands button is gone, and a mark key saved on a raid icon, also in an imported profile, pings again. The skull and cross scoring values are hidden on WoW Forever and `/hg bg test` no longer shows sample skull and cross markers there: no enemy can carry them.
- Enemy health is easier to read at a glance. The new default **Health style**, **Bar under the name**, draws a thick bar on a dark track with the percentage at its end; the suggested-target card grows to fit the same bar. Set its size with **Bar thickness**; **Fill the row** and **Thin line** remain (the thin line's size is now **Thin line height**). Retail and WoW Forever now show the health percentage too: the game formats its number without Highground reading it. **Green to red** works there as well, and **Health bar color** gains **Custom color** with a colour picker (Shared appearance).
- An enemy that leaves view keeps its last seen health, muted, for **Keep last seen health** (Target behavior, 15 seconds by default; 0 shows unknown health at once), instead of jumping to a full faded bar. A dead enemy's bar is empty. Enemies only a teammate targets get live health while your client can see them; addon messages can't share health in matches.
- WoW Forever: target priority settings that can never apply there are hidden. The game refuses addons enemy buffs and debuffs in a match, so **Defensive active**, **After a defensive expires**, **Bursting**, **GO alert after protection expires**, **Defensive-spent bonus fades over** and their multipliers had no effect; the orb values had none either (no Temple of Kotmogu). `/hg points`, `/hg weight` and **Edit a scoring value** on the Commands page now offer only values this game uses, on every client.
- Battlegrounds: who wins has its own **Win forecast** panel in Arathi Basin, Eye of the Storm, Battle for Gilneas, Deepwind Gorge and Darkspear Islands. It reads like "Horde wins 5:12" with the winner's score as its underline, the bases the trailing team needs below, and **If defended** when retaking contested bases would change the result; the live score is in its header. The Objectives panel is now **Timers** (captures, flag respawns, base list) without the WIN, HELD and NEED rows. Turn the forecast off in **Battlegrounds → Settings → Win forecast**; `/hg bg test` and the guide show it.
- Objectives panel: the plan row (**Hold bases to win**, **Hold 3 bases**, **Take another objective**) is gone; NEED already says how many bases the trailing team needs. Rows without a countdown (NEED, base names) use the clock's space, so "Alliance needs 3 bases" is no longer cut off. The flag row reads **Respawn** and shows a flag icon.
- Warsong Gulch counts down the flag respawn after a capture: **FLAG Respawn** on the objectives window and a pin at both flag rooms on the map, as Eye of the Storm already did. WoW Forever starts at 11 seconds (measured in a live match), Cata at 23; elsewhere the first capture teaches it. Highground learns each map's respawn from "The flags are now placed at their bases." and, after three captures, uses what it measured. The winning capture shows no countdown. `/hg bg test` shows a sample.
- Resurrection map pins sit on the spirit healer once Highground has seen your release position there, also in later matches. Saved spots were drawn a little below, as for a graveyard known only from its base icon: in WoW Forever's Darkspear Islands, Shipwreck Cove's pin was south of its graveyard. A graveyard first placed at its base icon moves to the spirit healer the first time you release there.
- WoW Forever: your specialization is the talent tree with the most points. It was always the first tree (Assassination, Arms, Balance...), so match history, automatic profiles and spec-based range used the wrong spec. Matches already recorded keep the spec they saved.
- Enemy map: during a fight, the circle sits on you, or on the teammate fighting, at your real position instead of the middle of the area. The game draws it itself, so it works where the map hides coordinates: a fight in Warsong Gulch's open middle no longer shows at the map's centre. It fades out 10 seconds after the last sighting. Turn it off with **Fight circles** in **Battlegrounds → Settings → Map and sharing**.
- Alerts: each alert's **Text** and **Sound** switches alone decide what it shows and plays. The target-lock sound no longer stays silent in battlegrounds while its Sound switch is ticked: the old **Essentials** level muted it behind the switch. **Everything**, **Critical only**, **Objectives** and **Text only** are now presets that set every switch at once; changing one afterwards shows **Custom**. Essentials is gone (it only muted target lock) and new installations start with Everything. Bounty and Nearby lose their separate sound options and the lock-on **Silent** choice: the alert's Sound switch does that, and the Nearby panel's **Sound: on/off** flips the same switch. While **Sounds** in Shared preferences is off, Sound switches are greyed out and say why. Target lock also plays straight after another alert sound instead of being skipped. Your saved alert level, sound options and profiles carry over as switch settings; Essentials becomes Everything.
- Arathi Basin and Darkspear Islands on WoW Forever show who is expected to win again (WIN and NEED). Highground now reads the modern double score bar these scoreboards use, as on Retail. WoW Forever's Arathi Basin starts from classic point rates; Darkspear Islands' rates are learned from the first few score ticks of a match and kept for later ones. Rates Highground measures replace the classic ones.
- WoW Forever resurrection timers end when you are actually back on your feet. The spirit healer counts down in whole seconds and players revive about a second after it ends; Highground now uses the latest countdown reading and adds that second, refined from your own resurrections. Teammates' timers no longer jump by a second while you wait at the healer.
- During WoW Forever's battleground chat lockdown, Highground no longer keeps retrying to share resurrection timers it cannot send.
- Resurrection timers no longer jump a few seconds when the game reports a teammate's resurrection late or they come back at their corpse or by a player's spell, as seen in WoW Forever Warsong Gulch and Darkspear Islands matches: a revival off the wave is set aside unless a later cycle confirms it. Coming back yourself off the spirit healer's countdown, such as at your corpse, and everyone coming back at the end of a match, no longer count as a wave. In Darkspear Islands, a death at a base no longer switches to your start's timer if the game stops giving your release position.
- Shared resurrection waves are timed to a tenth of a second, and your own resurrection is shared the moment you are back. Teammates need this version to read them; WoW Forever's battleground chat lockdown still blocks all sharing there.
- Reputation: a player's right-click menu shows **Add to blacklist** directly under a **Highground Reputation** heading. With several enabled guilds and communities it opens a list to pick one, or **All guilds and communities**. The report form offers the same **All** choice and saves a blacklist decision where you moderate and a proposal everywhere else.
- `/hg bg profiler start` records a battleground for troubleshooting: announcements, your deaths and the resurrection countdowns, each graveyard clock and how far its prediction was off, bases, flags and what the timer windows showed. Leaving the battleground stops it and offers a reload to save it; `/hg bg profiler stop` ends it early. Both are also on Battlegrounds → Commands.
- Match history shows each match like the enemy journal: a card with the result, map, your specialization, when you joined and how long it lasted, tiles for your scoreboard stats, and the latest objective events with their times in a separate column. Rows show the spec icon, result and date. Your name no longer shows WoW Forever's internal realm suffix or the game's id.
- **Hide quest tracker** also hides Questie's tracker in battlegrounds, including when Questie shows it again on a quest update, and restores it through Questie afterwards.
- Long enemy names, such as WoW Forever's first and last names, are cut off less often: a row's name now extends over empty slots on its right (no status chip, no spec text) and stops before anything the row shows. This helps most in Compact layout.
- Enemy map circles are a thin outline in your theme's colour around a faint fill, instead of a dark grey disc, and stay subtle when hovered. Hovering a circle shows its enemies at full strength.
- Class icons in a circle fade less with age. Hovering one shows only the enemy's name, class or spec icon, and how long ago they were seen.
- Objective overview: a base with no recent sightings shows only its name, without the "no recent sightings" note that was usually cut off.
- WoW Forever: enemy history and bounties count honorable kills when the kill message adds a realm to the enemy's name. These kills were missed, so history could show 0 kills.
- WoW Forever: resurrection timers no longer drift early. Its spirit healers count down 30 seconds, then wait about 1.6 seconds before the next countdown starts, so waves come every 31.6 seconds; timers counted 30 and fell further behind with each wave until the next resurrection was seen. `/hg timers` shows the wait as **30+1.6s**.
- On any server, a wait between countdowns is learned during the match from the waves Highground sees exactly.
- WoW Forever: your resurrection at a base no longer also resets your start's timer, which made both start rows show your base's countdown. Teammates coming back at an unknown base no longer switch timers to 45-second waves for a while. A newly captured base's estimated waves come about 4 seconds later, as measured in Arathi Basin.
- Enemy row tooltips are shorter. An unknown spec shows just the class, an enemy seen without a position gets no location line, and the click help is one line: **Shift-click: call in chat**. Left-click targets and right-click focuses, as before.

## [3.2.1] - 2026-11-23

- Enemy rows no longer repeat a known spec as text beside its icon; the row's tooltip names a favorable or unfavorable matchup instead of the text's colour. With **Spec icon** off in Battlegrounds → Appearance, the spec shows as text again.
- The battleground guide describes the faction crests on resurrection rows instead of OURS/THEIRS.
- WoW Forever, Arathi Basin: enemies seen in a named area (Stables, Farm, the starts…) are placed with the classic map's positions instead of Retail's, so their map pins land on the right spot.
- WoW Forever, Arathi Basin: dying at your start times **Alliance start** (Trollbane Hall) or **Horde start** (Defiler's Den), with its pin on the map, instead of an unnamed "spot unknown" row.
- Enemy map circles stay small (about 40 yards) and no longer grow over time; they fade with age like other pins.
- Several enemies seen in one place share a circle showing their number in the middle, with their class or spec icons around its edge.
- An enemy you can see only by its nameplate is no longer placed next to you: one of your spells must be in range, as nameplates show from much farther away.
- WoW Forever: starting graveyards share one resurrection clock, so dying at your start also times the enemy's start. A captured base's graveyard gets its own clock from the capture instead of joining every other graveyard's wave.
- The match history's resurrection notes name the graveyard.
- Cyrillic and Asian player names (flag carriers, enemy list) no longer show as boxes with the default font.

## [3.2.0] - 2026-11-23

- **Enemy map circles:** an enemy placed only by area shows as a faint circle where they can be, growing while they stay unseen. Enemies seen in one place share a circle, shrinking to fit with a **+N** for the rest; hover it to see who was seen there and when.
- **Faction crests:** resurrection and objective rows show the team's Alliance or Horde crest instead of OURS/THEIRS, and each flag carrier's class icon carries their crest.
- Quick callouts send as game macros, so they reach battleground chat in WoW Forever matches. In combat the panel keeps its area and destination until combat ends.
- The enemy list shows the whole team by default, and setups still on the old five- or ten-row default switch to all. Choose fewer under **Battlegrounds → Appearance → Enemies shown**.
- **Tag enemy specs:** when the game doesn't reveal an enemy's spec (always the case on WoW Forever, whose scoreboard only names the class), hover their row and click one of the spec icons on the right. Click the tagged icon again to remove it. Teammates with Highground see your tags while **Share observations** is on, and tags are remembered for later matches. A spec the game identifies replaces a tag.
- Enemy rows show a spec only once it is identified or tagged, never the class name. On WoW Forever, class names from the scoreboard are no longer saved as specs, and ones saved earlier are cleared at the end of your next match.
- Russian, Korean and Chinese player names display in Highground's panels.
- **Sound for each alert:** base capture, objective, resurrection and sap alerts have their own sounds, and every alert can use any Highground cue or a game sound from its addon's alert settings or `/hg alerts sound`. Feature guides offer the feature's switch on every step and let you try its sounds.
- WoW Forever: every battleground runs one resurrection clock, so your own countdown also times the enemy's graveyards. Warsong Gulch lists both base graveyards from the start.
- WoW Forever, Darkspear Islands: bases start neutral and show their real owner, the starts are named **Horde start** and **Alliance start**, a captured base shows one graveyard, and the flag gets a respawn countdown once its timing has been seen.
- The objectives panel drops its fixed goal line and lists a base under attack once, and the board header shows only the enemy count.
- Each death notes the next resurrection wave in the match history.
- Players' right-click menus no longer break in WoW Forever battlegrounds. Highground's **put a bounty** and **Highground Reputation** entries stay out of them in battlegrounds, arenas, combat and other restricted play.
- Sightings, resurrection waves and captures the game refuses to share with teammates are kept and sent with the next update.

## [3.1.0] - 2026-11-22

- **Dark theme:** near-black panels with violet accents, bounty buttons included. Choose it under **Shared preferences → Shared appearance → Theme** or with `/hg theme dark`.
- The target marker's ring takes your theme's colour: violet in Dark, copper in Ember, antique gold in Azeroth and gold in Highground. Custom ring colours and other presets are kept; a gold ring moves to the theme colour once, so choose **Gold** again to keep it.
- WoW Forever: Alterac Valley capture timers count down 300 seconds, matching Forever's tower and graveyard captures (Retail takes 240).
- WoW Forever: Darkspear Islands is recognized as a 15v15 battleground. Its four bases (Abandoned Tower, Shipwreck Cove, Ruins, Camp) get 60-second capture timers, graveyard waves every 30 seconds and enemy destination callouts, and the 15v15 switch, flag carrier tracking and resource trend apply.

## [3.0.1] - 2026-11-22

- Fix **Create Bounty** using CPU and memory on every frame while open, which made addon memory climb by hundreds of KB per second. The bounty board also checks your guilds and communities less often while the game is still loading them.
- Bounty pages (Create bounty, Claims & payments, Shared alert settings, Death reports) no longer pin the bounty board in place or double its shadow: drag a page's header to move the board. Pages shown inside the Highground window drop their own shadow too, and dragging them moves the window.
- Two players who blacklist each other no longer send Reputation auto-replies back and forth endlessly when their addon languages differ. Replies always start with the English `[Highground Reputation]` prefix, and the translated prefixes 3.0.0 sent are still recognized.
- All ten translations were reviewed again against English: nonsense wording is replaced, lost line breaks are restored and each language uses consistent game terms.
- Long sessions no longer build up memory: battleground casts and unfinished capture estimates clear between matches, Nearby sightings expire while a preview is shown, and bounty alerts save data only for targets they announce.
- Battleground timer tags, the flag respawn text and the yards unit are translated. Battleground names and the spell names in macro presets come from your game client.

## [3.0.0] - 2026-11-22

- **Highground speaks your language:** German, Spanish, French, Italian, Korean, Brazilian Portuguese, Russian and Simplified and Traditional Chinese join English. Choose one, or follow your game client, under **Shared preferences → General → Language** (`/hg config general`). Commands, macro text and saved data stay the same. Translations are machine-assisted; report wording that reads oddly.
- Translations use each language's plural forms (Russian "2 ошибки" but "5 ошибок") and its own way of listing items, and Home, panel lock, settings and spell-rank messages read as whole sentences. Translated battleground timer tags fit their columns, and Wintergrasp and PvP trinket names use the official translations.
- **Addons** is one directory: each addon's **Enable addon** switch (per character, with **Reload to apply**), **Visit** and its walkthroughs. Each addon's sidebar section, marked with its crest, holds its settings, appearance, alerts, previews and commands; panel cogwheels open it. Theme, fonts and master controls stay in **Shared preferences**.
- One Battlegrounds guide covers enemy rows and targeting, and objectives and flag carriers (`/hg guide battlegrounds`). Saved progress and direct shortcuts are kept.
- Arena and Nearby get their own panel scale and spacing. Existing layouts and imported profiles are kept.
- **Default** is now the fixed built-in baseline; **Restore Default** loads it, and earlier editable copies are kept as **Previous Default**. Profiles list your saved setups and activity assignments, compare each with Default in red/green columns, and apply or update only when you confirm.
- Reputation has an organization directory, an **Overview** for participation and updates, and separate **Preferences**. Members show readable roles (Guild master, Officer, Owner, Moderator, Member). Disabled organizations stay off while you browse; owners and guild masters can turn participation on or off without losing records.
- Reputation finds moderators in communities whose online status the game does not report, uses less discovery traffic, and finishes updates when the game throttles addon messages. Its chat filter no longer stalls chat in large guilds. Reports are kept while guild permissions load, and other members' private reports are removed once the game confirms you left.
- `/hg users` reads the discovery channel's member list; use **Refresh members**, or try the sample with `/hg guide users`.
- On WoW Forever, bounty and user discovery use a channel per ruleset. Everyone needs this update to find each other.
- Home's **Join Discord** replaces **Join community** and copies the Highground Discord invite.
- The Team callouts window, its commands and key bindings are removed. Quick callouts keep local help, all clear, enemy destinations and flag-carrier routes.
- Highground uses less CPU and memory in battlegrounds, arenas, large guilds and busy raids: combat tracking sleeps outside matches, bounty and Nearby checks skip players without a bounty, and open windows redraw only what changed. The download and texture memory are smaller.
- Ask for a second click before withdrawing a bounty reward, removing a bounty, rejecting a kill report, undoing a macro change or resetting a custom Reputation auto-reply. Try it on a personal sample in `/hg bounty test board`.
- The bounty board shows the result of card actions, including failures, and explains unavailable shared bounty data. Bounty details show changes made while a share or reward window was open. Notes and zone names keep accented and non-Latin letters whole.
- Bounty sharing no longer causes repeated "No player named … is currently playing" messages: claim reviews and status checks retry only while the other player seems online. Bounties from guilds or communities you left expire, and expired unpaid shared contributions free their slot after 90 days.
- **Macros → Create** shows save results next to **Save macro**; refused saves explain why and can be retried. Preset cards say **Saved with other text** when another macro uses their name. Buff suggestions work in every language.
- Fix **Sequence** and **Random** macros after choosing single-cast options. Ranked presets get distinct names, WoW Forever's two-part names work as macro targets, and item warnings work again on Retail and WoW Forever.
- The Bounties, Macros and Reputation windows use Highground's shared controls: page tabs become a page menu at large text sizes, choices use segmented buttons, action rows wrap and statuses use labelled badges.
- On WoW Forever, capture tracking learns your capture spell from your own assaults and credits teammates' assaults and flag pickups. Leaving a battleground mid-capture no longer leaves capture bars on screen.
- Set the execute threshold on Retail and WoW Forever too (**Target behavior** or `/hg exec PCT`).
- Battleground win predictions no longer name the Alliance when both teams would reach the score limit together. Graveyard tooltips name the clock's actual source.
- HUD windows have a short entrance, new timer rows flash once and new bounty posters slide in. Reduced motion keeps them steady.
- Home cards grow with larger text and scroll instead of clipping. Tooltips close when their control disappears.
- `/hg timers reset` in combat moves the panels back when combat ends, and `/hg reset` asks you to leave combat first. Damaged saved panel positions fall back to the default spot.
- Command syntax shows intact in `/hg help` and **Help and commands**. `/hg mark ping` explains when pings are unavailable, `/hg exec 29` reports 29%, `/hg points NAME` shows a value instead of resetting it, and commands given a non-number print their usage line.
- Damaged saved settings, profiles, histories and macro backups are repaired or reset instead of stopping Highground. Saved errors are capped at 64; `/hg err` reports how many more occurred and no longer lists missing functions on Retail and WoW Forever.
- The Feature guide says when its highlighted control is scrolled out of view. Player tooltips on a bounty target say "1 contribution" instead of "1 contributions".
- Fully restart WoW after updating: this release adds new files.

## [2.50.0] - 2026-11-22

- Explain redundant standalone installations on Home and Addons, with a guided cleanup checklist that keeps module folders and required data addons.
- Redesign bounty cards with larger portraits, aligned rewards and action footers, and ink-colored View bounty buttons. Give bounty details a full wanted-poster layout with a larger portrait and clearly separated reward terms.
- Populate `/hg bounty test board` with three distinct cards per audience, varied rewards, shared contributions and a pending guild submission. Editing, tracking, added gold and claim review stay with the selected sample target.
- Add optional **Stop casting after spell** under **Macros → Create → Casting options**, with a trailing `/stopcasting` and a warning that it cannot guarantee instant-only casting. Explain stop commands according to their position in the macro.
- Skip community members on other Forever rulesets when synchronizing bounties or discovering Reputation moderators. Leave unresolved member names unsent instead of adding your ruleset to their whisper address.
- Add a layered Sniper marker with an optional skull and separate sight, skull and aiming-mark colours. The new default uses approximate head placement; Legacy keeps the original crosshair.
- Adjust Sniper marker size, gap and X/Y offsets, or place it by the body or nameplate edges. Its gentle pulse speeds up at low health or during a kill window and respects Reduced motion. Saved profiles retain custom choices.
- Fix addon whispers on WoW Forever using an internal realm suffix, which caused repeated “No player named … is currently playing” messages during bounty and Reputation sharing.
- Choose which of the six included modules run from WoW's AddOn List or Highground → Addons. Switches apply to the current character after reload and preserve saved settings and records.
- Install every folder from the ZIP and fully quit and restart WoW to discover the new module entries. Keep both bundled data addons enabled.

## [2.49.1] - 2026-11-22

- Reduce background memory growth and stuttering caused by Reputation, guild and community updates, including with the main window closed or an organization paused.
- Reduce memory growth while the main window is open with a saved profile.
- Reduce extra work during busy bounty sharing.
- Add optional performance captures: /hg perf start records 60 seconds of FPS, memory and addon activity, then stops automatically. Keep WoW in the foreground; /hg perf shows results and /reload saves the report.
- Updating from 2.49.0 requires /reload after installing. Fully quit and restart WoW when upgrading from an older release; keep all bundled data addons enabled.

## [2.49.0] - 2026-11-21

- Count your own character immediately in Addon users while detection is enabled, including your realm, active groups, guild and version. Diagnostics distinguish your local count from other detected users.
- Improve Reputation setup and delivery: only native officers and community moderators can enable organizations, members discover enablement automatically, and alts remember it. Queue proposals until a moderator can receive them, with clear offline, addon-detection and setup guidance.
- Add live bounty previews with /hg bounty test: try poster, match, kill or board, and use test stop to close them. The interactive tour is now /hg bounty guide. Sample bounties stay separate from your saved records.
- Keep wanted popups compact without an internal scrollbar. View bounty shows full notes and reward terms, with one target header above multiple contributions; alert and screenshot controls remain reachable.
- Accept typed player names without selecting a target first, trim surrounding spaces, and use the current Forever ruleset when the game does not provide a realm name.
- Download Alliance and Horde streamer banner packs separately from this GitHub release; they are optional and are not included in the game addon.
- Fully quit and restart WoW after updating to load the new files; /reload is not enough. Keep every included addon folder enabled.

## [2.48.1] - 2026-11-21

- Fix Nearby missing visible enemy players on flight paths, including after targeting them. Flight passengers now appear in the list and live count even while they cannot be attacked.

## [2.48.0] - 2026-11-21

- Keep Nearby encounters, notes, muted enemies, match results and personal bounty tracking with the current character, faction and realm or Forever ruleset. My bounties and claims show records belonging to you or available for your review.
- Make empty Nearby History explain whether recording is enabled. Forget, delete and undo affect only the current character; changing context closes stale dialogs and pending actions.
- Keep character macro backups and automatic profile assignments with their owner. General macro backups remain shared; saved profiles and appearance preferences remain reusable.
- Keep learned graveyards, capture times, scoring rates and specialization clues in the correct game or Forever ruleset.
- Automatically check sharing compatibility with updated Highground and standalone addons. Preserve bounty completion terms when exchanging with different versions and explain known profile or reputation transfer incompatibilities. Older clients keep the existing sharing behavior.
- Fix Forever addon-user discovery staying paused outside combat and retry promptly when messaging becomes available. Use /hg users why or Copy diagnostics for connection, retry and compatibility details.
- Offer the EU Highground community invitation once per character on Forever, including after updating. Home lets you reopen the correct faction invite: copy it, choose Open join window, paste and join through WoW. The offer waits for combat, instances and other windows to clear.
- Keep community headings readable at larger text sizes and preserve the first-install feature guide after the invitation.
- Older records without enough ownership information remain saved but are not assigned to the current character. New histories start fresh; recreate private bounties and reassign automatic profiles as needed. Shared gold commitments and reputation organization records are retained.
- Restart WoW after updating and keep all three included addon folders enabled; /reload is not enough to load the added files.

## [2.47.0] - 2026-11-21

- Add **Addon users** (`/hg users`) with a deduplicated recent-user total, realm, party, raid, instance, guild and discovery-channel counts, and a version breakdown.
- Discover compatible Highground clients through small, staggered announcements with no reply fan-out, a bounded session cache and expiring records. Detection and realm discovery can be switched off independently.
- Show a local notice when a newer stable version is reported, limited to once per session and once per day; notices can be muted.
- Keep shared-profile success, cancellation and failures consistent when switching or retrying transfers. Completed or replaced transfers cannot show stale timeout notices.
- Keep queued spell-rank upgrades together while combat or an occupied cursor delays them, and explain which condition is blocking a requested upgrade. Automatic upgrades preserve deliberate lower ranks.
- Keep duel requests, countdowns and active fights consistent through repeated notifications and changes of bounds; clear the duel when changing worlds, cancelling or finishing.
- Restart WoW after updating to load the new discovery modules and page; /reload is not enough. Install every folder in the ZIP.

## [2.46.0] - 2026-11-20

- Create bounties through a connected Target, Reward and Review stepper. Preview the wanted poster, audience, kill goal, expiry and maximum reward before confirming.
- Open Share bounty, Edit reward and Claim reward directly from the bounty. Edit your own reward instead of adding gold to yourself; management actions stay visible without a More menu.
- Use narrower wanted posters with fixed action buttons. Reading or scrolling to the bottom keeps your place when rewards and sightings refresh.
- Follow the shorter onboarding flow and copy a bounty link directly for sharing. Drafts remain intact when going back or opening gold settings.
- Restart WoW after updating to load the new stepper files and artwork; /reload is not enough.

## [2.45.1] - 2026-11-20

- Reduce memory used by window controls and repeated UI updates while idle.
- Reduce ongoing memory allocations in /hg test, target scoring and cooldown displays.
- Keep equally ranked enemies in a consistent order when raid markers are removed.
- Load scoring settings and spell overrides when opened; appearance edits and profile checks avoid refreshing unrelated controls.
- Reduce repeated work in feature guides and pause bounty-board refreshes while hidden.
- Restart WoW after updating to load the new shared control texture; /reload is not enough.

## [2.45.0] - 2026-11-20

- Add Back/Forward navigation across the Highground window, bounty forms and macros; returning from a dialog keeps the previous draft, filters and scroll position.
- Add player reputation for existing guilds and WoW character communities. Use `/hg reputation` to enable an organization, submit reports and review moderator decisions, with optional chat filtering and whisper replies. Keep the bundled HighgroundReputationData folder enabled.
- Expand bounties with native community boards, wanted posters and portraits, shared sightings, tracked hunts, screenshot reports and offline import/export codes.
- Set rewards per approved kill for goals of 1–20 kills. Add gold to an existing bounty under its original poster's completion decision; each contributor records their own manual payments.
- View recorded account gold and outstanding commitments with `/hg bounty gold`. Insufficient funds warn by default; Require enough gold optionally blocks creation.
- Keep Forever bounty data separate by ruleset and preserve complete character identities while hiding internal realm suffixes. Older unscoped lists remain saved but are not automatically assigned; review or recreate targets in the correct ruleset.
- Open the arena panel for duels as well as arena matches, with a stable opponent, readable class/spec icons and solid health bars. Likely Forever specs use readable talent clues; unavailable trinket timing is marked ?.
- Add optional idle transparency for HUD backgrounds, stronger control outlines and focus effects, and transparent addon artwork. Text and secure click targets remain unchanged by fades; Reduced motion keeps effects steady.
- Keep reputation updates queued through intermittent send failures; only consecutive failures abandon an unreachable recipient.
- Restart WoW after updating and install every folder in the ZIP to load the new modules and bundled data addon.

- Show the real battleground panel and WoW world map in the feature guide, with sample observations rendered by the normal UI. Keep a separate scene only for sniper and healer nameplate markers.

- Replace unsupported arrow characters in guide summaries and Home hints so they do not display as squares.
- Scroll Appearance guide targets into view and keep guide commands in sync with the in-game help.
- Split bounty onboarding into posting/review and hunting/claiming paths with independent progress. Keep each path in task order, make Back follow visited steps, and let gold Next buttons demonstrate native sample actions.
- Replace the long feature-guide chapters with independent addon guide buttons, short instructions and one-row navigation.
- Present each main guide with its addon logo and a small gold Start, Resume or Replay button.
- Use native addon controls for Quick calls, Macros, Nearby history, bounties and Reputation. Highlight page openers and animate the next target; respect Reduced motion.
- Merge enemy rows and markers into one guide; point directly at status labels and explain DEF changing to SPENT. Fix clipped explanations and add quick Enable in game preferences.

- Enlarge Nearby class icons, shorten row details, and resize rows and footer controls with text size.
- Give flag carriers larger icons and separate, opaque health strips in normal and Compact layouts, with native restricted health percentages when available.
- Fix missing and stale class icons across combat panels, the journal and bounty cards when a client lacks the class atlas.

## [2.44.0] - 2026-11-18

- Open saved encounters from the Nearby panel with History, search and Previous/Next pages, even after players leave view. Up to 1,000 enemies are kept across sessions.
- New sightings play a soft two-note chime. Sound: on/off controls nearby sounds; new installations enable them, while existing preferences and muted enemies are kept. Bounty and urgent alerts retain priority.
- Readable hiding auras can reveal nearby stealth when a cast was missed. Distinct entry and exit sounds follow observed transitions; unreadable aura data cannot confirm an exit, and Cata uses confirmed combat-log removals.
- Keep the newest encounter when the saved history reaches its player limit.
- Restart WoW after updating to load the new detection sound.

## [2.43.0] - 2026-11-18

- **Macros: WoW Forever presets** for every class's new spells and talents, with Forever's renamed spells (Bane of Agony, Subjugate Demon) and without removed ones (Wyvern Sting, Blessing of Salvation).
- **Macros → Create** adds stance or form, an alternative action on Shift, Ctrl, Alt, right-click or out of combat (yourself, focus, cursor, another spell or a lower rank), pet orders, a channel guard, gear to equip first and an announce line.
- **Open WoW macros** now shows on Create, and preset cards show one line of description.
- Existing installations can use `/reload` after updating; this release adds no addon files.

## [2.42.0] - 2026-11-18

- Redesigned Highground as the default theme: midnight blue steel, forged gold, ivory titles and persistent class colours.
- Added the crest to the Highground window, metal frame details, persistent class identity and independent target/focus marks. Health lines remain readable with custom class colours and fade when health is unknown.
- Class Colors remains available with stronger tinting. Explicit saved themes, custom class colours, fonts, opacity, positions and reduced motion are retained.
- Restart WoW after updating to load the bundled crest texture.

## [2.41.3] - 2026-11-16

- The hidden shared-bounty chat channel now takes the last channel number. General, Trade and your own channels keep their numbers and order; if it took /1 before, it moves within a few seconds of logging in.
- `/reload` is enough after updating; this release adds no files.

## [2.41.2] - 2026-11-16

- Guild bounty officers now follow your guild's rank permissions. Ranks with officer permissions approve submissions, and their own submissions reach the guild at once. If the game doesn't provide rank permissions, the **Officers** setting under `/hg config` → **Guild bounties** decides.
- The bounty board shows players from your realm without the realm name. Players from other realms are marked `(*)`; hover the row or open the bounty to see the realm.
- `/reload` is enough after updating; this release adds no files.

## [2.41.1] - 2026-11-08

- Fix targeting and focus for players with surnames on WoW Forever. Nearby sightings, battleground roster matching and previews now keep the full player name.
- Enable Nearby on new installations with five rows and routine sighting sounds off. Existing choices are kept; use `/hg nearby on` if it was previously disabled.
- Keep panel cogwheels reachable while locked and in Frameless mode, with lock/unlock, arrangement and settings in one menu. Compact battleground columns share one cogwheel on the first visible panel.
- Restart WoW after updating; this release adds panel-control files, so `/reload` is not enough.

## [2.41.0] - 2026-11-04

- **Enemy destination callouts:** choose another area, then click **1**, **2** or **3+** to report enemies heading there, such as `2 enemies going to Farm` while at Lumber Mill.
- **EFC route callouts:** **Ramp**, **Graveyard** and **Tunnel** in Warsong Gulch; **Ramp**, **Graveyard** and **Water** in Twin Peaks. One click sends the selected route, including from midfield and during combat.
- Both new switches start off. Highground: `/hg config general` → **Battleground → Quick callout panel**. Enable the panel and the desired options; existing local help calls stay available, and all sends share the same brief cooldown. Previews cannot send messages.
- Destination selections reset between matches. Gilneas **Mine/Mines** appears once, using the game's observed name when available.
- Restart WoW after updating; this release adds an addon file, so `/reload` is not enough.

## [2.40.0] - 2026-11-04

- **Live nearby enemy count:** the **NEARBY: N** header counts distinct visible, living hostile players and updates on sightings, departures and once a second, including during combat and beyond the row limit. Enable it with `/hg nearby on`.
- The enabled counter stays visible at zero. Old rows and combat-log-only sightings keep their normal history without increasing the live count; clearing recent sightings leaves the counter running.
- Target, focus and mouseover sightings now stay fresh while visible. Pending combat rows count every enemy, including those beyond the row limit, while existing click bindings stay fixed.
- Restart WoW after updating; this release adds an addon file, so `/reload` is not enough.

Earlier releases: [2.20.0–2.39.0](docs/changelog-2.20-2.39.md) and [2.7.3–2.19.0](docs/changelog-2.7-2.19.md).
