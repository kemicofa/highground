# Commands

[Documentation](README.md) · [Highground overview](../README.md)

Generated from the addon-owned command catalogs by `luajit ../../tools/command_docs.lua`. Each addon's **Commands** page shows its entries and UI controls; **Help and commands** combines them. `/hg help` prints the same catalog. `/highground` works like `/hg`.

Words in capitals are values; `a|b` means a choice. UI links open the relevant settings or editor. Action buttons run the same handlers as chat commands, with labeled fields when needed. Disabled addons keep their reference visible in the combined list, but actions are unavailable until enabled and reloaded.

`/hg config PAGE` accepts page keys or sidebar labels, including `nearby-commands`, `bounties-commands` and `tools`. Unknown commands print help. Standalone addons are deprecated; these are the supported Highground commands. Shared-bounty examples are in the [user guide](user-guide.md#shared-bounties).

## Highground

| Command | What it does | UI equivalent |
| --- | --- | --- |
| `/hg` | Open or close Highground configuration. | Open / close Highground |
| `/hg help` | List available commands and your detected specialization in chat. | Print command help |
| `/hg test` · `/hg test all` | Toggle available previews across enabled addons, keeping existing samples when starting the set. | Toggle all addon previews |
| `/hg test stop` | Stop all addon previews, including samples started individually. | Stop all previews |
| `/hg config [PAGE\|blizzard]` · `/hg options` | Open a configuration page; config blizzard opens Blizzard settings. | Browse Highground → `home` |
| `/hg config blizzard` | Open the native Blizzard addon settings panel. | Open Blizzard settings |
| `/hg setup` | Choose playstyle presets and place panels. | Open playstyle presets → `setup` |
| `/hg guide [FEATURE]` · `/hg checklist` | Browse Addons or start and resume a specific walkthrough. | Open Addons and guides → `addons` |
| `/hg alerts` | Choose alert presets and text/sound preferences. | Open alert controls → `alerts` |
| `/hg alerts sound ALERT [SOUND]` | Choose and hear the sound an alert plays. | Choose an alert sound |
| `/hg alerts preset NAME` | Set every alert's text and sound switches to a preset. | Choose an alert preset |
| `/hg users` | Inspect channel members, addon versions and discovery status. | Open addon users → `users` |
| `/hg users why` | Copy discovery diagnostics, channel membership and retry state. | Copy discovery diagnostics |
| `/hg guide users` | Explore channel discovery with isolated sample members. | Start addon users guide |
| `/hg lock` | Lock all HUD panels in place. | Lock panels |
| `/hg unlock` | Show panel headers for dragging outside combat. | Unlock panels |
| `/hg scale N` | Set the master HUD scale. | Adjust master scale → `general` |
| `/hg opacity PCT` | Set the background opacity of HUD panels, in percent. | Adjust background opacity → `appearance` |
| `/hg sound` | Toggle the master Highground sound preference. | Master sound control → `general` |
| `/hg theme [NAME]` | List themes or select a theme by name. | Choose a theme → `appearance` |
| `/hg profile [ADDON]` | Open Profiles and list the profiles for an addon: battlegrounds, arena, nearby, bounties, macros or general. | Profiles → `profiles` |
| `/hg profile copy ADDON NAME` | Copy another character's or an import's settings for an addon into this character. | Copy a profile → `profiles` |
| `/hg profile delete NAME` | Delete another character's settings or an import. | Delete a profile → `profiles` |
| `/hg profile share [ADDON]` | Prepare a chat link to this character's settings for an addon. | Share in chat → `profiles` |
| `/hg export [ADDON]` | Show this character's settings for an addon as a code. | Export → `profiles` |
| `/hg import [CODE]` | Keep a profile code in Profiles without applying it. | Import → `profiles` |
| `/hg err` | Print recorded errors and diagnostic counters in chat. | Show errors in chat |
| `/hg clearerr` | Clear recorded errors. | Clear recorded errors |
| `/hg perf` | Print the latest performance capture in chat. | Show performance report |
| `/hg perf start` | Capture callback allocations, time and FPS for 60 seconds. | Start performance capture |
| `/hg perf stop` | Finish the current performance capture early. | Stop performance capture |
| `/hg probe` | Print the information Highground can read from your target. | Inspect target in chat |

## Battlegrounds

| Command | What it does | UI equivalent |
| --- | --- | --- |
| `/hg guide battlegrounds` · `/hg checklist battlegrounds` | Choose the targeting or objectives walkthrough. | Choose a battleground guide |
| `/hg guide enemies` · `/hg guide targeting` · `/hg checklist enemies` · `/hg checklist targeting` | Learn enemy rows, target markers and status labels. | Start enemy targeting guide |
| `/hg guide objectives` · `/hg checklist objectives` | Learn resurrection waves, captures and flag carriers. | Start objectives guide |
| `/hg priority [on\|off]` | Show or change target recommendations. | Target recommendation switch → `battlegrounds-settings` |
| `/hg call` | Prepare a kill-target chat message; press Enter to send. | Prepare target call |
| `/hg call s\|i\|raid\|party\|y` | Choose the chat channel for target calls and shift-click shares. | Choose call channel |
| `/hg mark` | Print the current mark mode and the secure button macro. | Show mark instructions |
| `/hg mark icon 1-8` | Choose the raid icon used by the mark key. (not WoW Forever) | Choose raid icon |
| `/hg mark ping TYPE` | Choose the ping used by the mark key. (requires pings) | Choose ping type |
| `/hg why` | Print why the kill target was chosen. | Explain target choice |
| `/hg live` | Toggle live-priority row sorting. | Live sorting controls → `behavior` |
| `/hg all` | Toggle participation in unrated battlegrounds. (not WoW Forever) | Battleground scope controls → `battlegrounds-settings` |
| `/hg sizes [10\|15\|40\|world] [on\|off]` | Show which size the Battlegrounds settings edit, pick one, or switch where Highground runs. | Battleground sizes → `battlegrounds-settings` |
| `/hg sizes copy SIZE [SIZE...]` | Copy the edited size's settings over other sizes. | Copy to other sizes… → `battlegrounds-settings` |
| `/hg sizes preview` | Start or stop sample panels for the size you edit. | Preview → `battlegrounds-settings` |
| `/hg kit` | Print tracked cooldowns for your target or kill target. (Cata) | Show target cooldowns |
| `/hg exec PCT` | Set the execute health threshold. | Execute threshold → `behavior` |
| `/hg history` | Review saved PvP results and observed objective timelines. | Open match history (separate window) |
| `/hg bg test` | Start or stop battleground enemy rows, timers, objectives and flag carrier samples. | Battleground panel preview controls → `battlegrounds-previews` |
| `/hg bg test stop` | Stop the battleground panel previews. | Stop battleground previews |
| `/hg bg profiler start` | Record a battleground for analysis: events, timers and what Highground concluded. Stops when you leave. | Start battleground profiler |
| `/hg bg profiler stop` | Stop the battleground profiler; /reload then saves the recording. | Stop battleground profiler |
| `/hg intel` | Show enemy map and sharing status. | Show map sharing status |
| `/hg intel on` · `/hg intel off` | Enable or disable enemy map positions. | Map position switch → `battlegrounds-settings` |
| `/hg intel share on\|off` | Enable or disable sharing map positions with teammates. (not WoW Forever) | Map sharing switch → `battlegrounds-settings` |
| `/hg intel circles on\|off` | Enable or disable circles around you or a teammate during a fight. | Fight circles switch → `battlegrounds-settings` |
| `/hg intel test` | Start or stop a sample world-map pin. | Map preview controls → `battlegrounds-previews` |
| `/hg timers` | Show battleground timer status. | Show timer status |
| `/hg timers on` · `/hg timers off` | Enable or disable battleground timers. | Battleground timer switch → `battlegrounds-settings` |
| `/hg timers reset` | Restore battleground panel positions and spacing. | Reset battleground positions |
| `/hg reset` | Restore the main enemy panel position. | Reset enemy panel position |
| `/hg enemy` | Enemy appearance | Enemy appearance → `battlegrounds-appearance` |
| `/hg enemy preset readable\|compact\|default` | Enemy row preset | Enemy row preset → `battlegrounds-appearance` |
| `/hg enemy style bar\|fill\|line` | Health style | Health style → `battlegrounds-appearance` |
| `/hg enemy color shared\|theme\|class\|faction\|health\|custom` | Health bar color | Health bar color → `battlegrounds-appearance` |
| `/hg enemy texture shared\|flat\|blizzard\|raid` | Bar texture | Bar texture → `battlegrounds-appearance` |
| `/hg enemy custom HEX\|default` | Custom color | Custom color → `battlegrounds-appearance` |
| `/hg enemy height PX` | Bar thickness | Bar thickness → `battlegrounds-appearance` |
| `/hg enemy line PX` | Thin line height | Thin line height → `battlegrounds-appearance` |
| `/hg enemy row PX` | Enemy row height | Enemy row height → `battlegrounds-appearance` |
| `/hg enemy width PX` | Main panel width | Main panel width → `battlegrounds-appearance` |
| `/hg enemy background PCT` | Row background opacity | Row background opacity → `battlegrounds-appearance` |
| `/hg enemy opacity PCT` | Health bar opacity | Health bar opacity → `battlegrounds-appearance` |
| `/hg enemy names PCT` | Unseen name brightness | Unseen name brightness → `battlegrounds-appearance` |
| `/hg enemy hero on\|off` | Hero card | Hero card → `battlegrounds-appearance` |
| `/hg rows N` | Set the number of enemies shown. | Choose enemy row count → `battlegrounds-appearance` |
| `/hg compact [on\|off]` | Toggle the slim one-line enemy layout. | Compact layout switch → `battlegrounds-settings` |
| `/hg nameplates` | Show the game's nameplate settings that healer marks need. | Nameplate settings → `battlegrounds-settings` |
| `/hg nameplates range YARDS` | Set how far away nameplates appear, in yards. | Nameplate range → `battlegrounds-settings` |
| `/hg nameplates all on\|off` | Show nameplates for all units in range, or only your target and units in combat. | Always show nameplates → `battlegrounds-settings` |
| `/hg nameplates friends on\|off` | Show or hide friendly player nameplates. | Friendly player nameplates → `battlegrounds-settings` |
| `/hg sniper` | Toggle the target marker. | Target marker switch → `battlegrounds-settings` |
| `/hg sniper why` | Explain why the target marker is hidden. | Diagnose target marker |
| `/hg sniper color ring\|skull\|aim HEX\|default` | Choose a ring, skull or aim color; default restores the component color. | Target marker colors → `battlegrounds-appearance` |
| `/hg sniper color NAME` | Choose a named ring preset and restore its automatic kill-window colors. | Choose marker color preset |
| `/hg sniper size X` | Set target marker scale. | Target marker size → `battlegrounds-appearance` |
| `/hg sniper x N` | Set the horizontal marker offset. | Target marker horizontal offset → `battlegrounds-appearance` |
| `/hg sniper y N` | Set the vertical marker offset. | Target marker vertical offset → `battlegrounds-appearance` |
| `/hg sniper padding N` | Set the nameplate edge gap. | Target marker edge gap → `battlegrounds-appearance` |
| `/hg sniper sound N` | Choose and preview a lock-on sound; zero disables it. | Choose target marker sound |
| `/hg sniper place body\|head\|left\|right\|above` | Choose marker placement; head placement follows the nameplate approximately. | Target marker placement → `battlegrounds-appearance` |
| `/hg sniper style layered\|legacy` | Choose the layered marker or original crosshair. | Target marker style → `battlegrounds-appearance` |
| `/hg sniper skull [on\|off]` | Show or hide the marker skull. | Target marker skull → `battlegrounds-settings` |
| `/hg sniper animate [on\|off]` | Toggle marker animation; Reduced motion keeps it steady. | Target marker animation → `battlegrounds-settings` |
| `/hg sniper test` | Start or stop a marker preview on a visible nameplate. | Target marker preview controls → `battlegrounds-previews` |
| `/hg go` | Preview the kill-window look and sound with a sample active. | Kill-window preview controls → `battlegrounds-previews` |
| `/hg burst` | Print recent observed burst buffs. (Cata) | Show burst diagnostics |
| `/hg burst test` | Start or stop a burst marker sample. (Cata) | Burst preview controls → `battlegrounds-previews` |
| `/hg pressure` · `/hg pressure status` | Print teammate pressure status and observed targeting counts. (Cata) | Show pressure status |
| `/hg pressure on` · `/hg pressure off` | Enable or disable teammate pressure shields. (Cata) | Pressure shield switch → `battlegrounds-settings` |
| `/hg pressure count N` | Set the maximum number of teammates with pressure shields. (Cata) | Choose pressure shield count |
| `/hg pressure test` | Start or stop the pressure-shield sample. (Cata) | Pressure preview controls → `battlegrounds-previews` |
| `/hg healer [NAME]` | Mark or unmark a teammate as a healer: the named one, else the one under your mouse, else your target | Mark team healer |
| `/hg healers` | Open Team healers to see and change which teammates get the green healer cross | Open Team healers (separate window) |
| `/hg healers test` | Start or stop the Team healers sample | Team healers preview controls → `battlegrounds-previews` |
| `/hg icon [NAME] [ICON\|none\|clear]` | Give a group member a team icon: the one named, else under your mouse, else your target. none hides their icon; clear gives back the automatic icon, or none without a rule. Without an icon, opens the icon picker. Group leader only, outside matches. | Set a team icon |
| `/hg icons` | Open Team icons to see every group member's icon; the group leader changes them there. | Open Team icons (separate window) |
| `/hg icons auto off\|class\|role` | Give every teammate without an icon from the leader their class or role icon automatically, or turn it off. Group leader only, outside matches. | Choose automatic team icons |
| `/hg icons panel` | Show or hide the Team icons quick panel: class icons, role icons or remove all, in one click. | Toggle the quick panel |
| `/hg icons clear` | Clear every team icon in your group. Group leader only, outside matches. | Clear team icons |
| `/hg icons test` | Start or stop the Team icons sample. | Team icons preview controls → `battlegrounds-previews` |
| `/hg points` | Print overridden scoring values in chat. | Show scoring overrides |
| `/hg points NAME VALUE\|reset` | Set or reset any scoring value. | Edit a scoring value |
| `/hg weights` | Inspect all score multipliers. | Inspect score multipliers → `multipliers` |
| `/hg weight [NAME X]` | Set a score multiplier. | Edit score multipliers → `multipliers` |
| `/hg weight reset` | Reset every score multiplier to 1.0. | Reset all score multipliers |
| `/hg map` | Print the current map and battleground weighting profile. | Inspect current map |
| `/hg cap why` | Explain capture detection for your current target. | Explain capture detection |
| `/hg cap probe` | Start or stop recording capture diagnostics. (Cata) | Toggle capture recording |
| `/hg cap clear` | Clear capture diagnostics while preserving learned capture spells. | Clear capture diagnostics |

## Arena

| Command | What it does | UI equivalent |
| --- | --- | --- |
| `/hg arena` | Show Arena panel status in chat. (not WoW Forever) | Show Arena status |
| `/hg arena on` · `/hg arena off` | Enable or disable the Arena panel. (not WoW Forever) | Arena panel switch → `arena-settings` |
| `/hg arena test` | Start or stop a sample opponent panel. (not WoW Forever) | Arena preview controls → `arena-previews` |

## Nearby

| Command | What it does | UI equivalent |
| --- | --- | --- |
| `/hg nearby` | Show the nearby enemy list status and remembered count. | Show Nearby status |
| `/hg nearby on` · `/hg nearby off` | Enable or disable the nearby enemy list. | Nearby list switch → `nearby` |
| `/hg nearby map on` · `/hg nearby map off` | Show or hide Nearby's enemy sightings on the world map. | World map sightings switch → `nearby` |
| `/hg nearby heat on` · `/hg nearby heat off` | Shade the map where enemies were seen in the last hour and mark who is winning the fights there. | Enemy heatmap switch → `nearby` |
| `/hg nearby layers all` · `/hg nearby layers mine` | Show enemies seen on other layers too, or only your layer's and those whose layer is unknown. (requires layers) | Other layers switch → `nearby` |
| `/hg nearby share on` · `/hg nearby share off` | Share nearby enemies with your party or raid and list theirs. | Group sharing switch → `nearby` |
| `/hg nearby share guild on` · `/hg nearby share guild off` | Also share nearby enemies with your guild and list theirs. | Guild sharing switch → `nearby` |
| `/hg nearby share world on` · `/hg nearby share world off` | Share coarse sightings with every Highground user of your faction on this realm. | Sightings with everyone switch → `nearby` |
| `/hg nearby tracking on` · `/hg nearby tracking off` | Turn tracked enemy alerts on or off. | Tracked enemy alerts switch → `nearby` |
| `/hg nearby track NAME` | Track an enemy by name, or your target: you're alerted with where they are when they're seen. | Track an enemy |
| `/hg nearby untrack NAME` | Stop tracking an enemy by name, or your target. | Stop tracking an enemy |
| `/hg nearby tracked` | List tracked enemies and where they were last reported. | Open tracked enemies (separate window) |
| `/hg nearby watch on` · `/hg nearby watch off` | Watch for tracked enemies with every Highground user of your faction on this realm. | Watch with everyone switch → `nearby` |
| `/hg nearby mark enemies\|ganker\|help` | Mark enemies, a ganker or a call for help at your position, for your group and guild. | Mark the map |
| `/hg nearby mark clear` | Remove your map marks for everyone. | Clear my marks |
| `/hg nearby marks on` · `/hg nearby marks off` | Show and share map marks, or turn them off. | Map marks switch → `nearby` |
| `/hg nearby marks world on` · `/hg nearby marks world off` | Share map marks with every Highground user of your faction on this realm. | Marks with everyone switch → `nearby` |
| `/hg nearby calls on` · `/hg nearby calls off` | Turn World PvP calls on or off: known gankers, enemy raids and others' map marks. | World PvP calls switch → `nearby` |
| `/hg nearby fights on` · `/hg nearby fights off` | Run the kill order in open-world group fights, or stop. | World fights switch → `battlegrounds-settings` |
| `/hg guide nearby` · `/hg nearby guide` · `/hg checklist nearby` | Start or resume the Nearby walkthrough: sightings, sharing, marks, tracking and the journal, with sample data. | Start Nearby guide |
| `/hg nearby test` | Start or stop the nearby enemy sample list. | Nearby preview controls → `nearby-previews` |
| `/hg nearby clear` | Clear current nearby sightings. | Clear nearby sightings |
| `/hg nearby forget` | Forget saved enemy encounter history, except tracked enemies and bounty targets. | Forget enemy history |
| `/hg nearby feed on` · `/hg nearby feed off` | Share kills and deaths with your group and guild, or stop. | Kill feed switch → `nearby` |
| `/hg activity` | Open World activity: zones with recent enemies, marks and kills. | Open world activity (separate window) |
| `/hg activity test` | Start or stop the World activity sample: two zones with enemies, a mark and kills. | World activity preview controls → `nearby-previews` |
| `/hg journal` · `/hg journal all` | Search encounters, write notes, mute alerts or place a bounty. | Open enemy journal (separate window) |
| `/hg journal tracked` | Open the enemy journal showing only tracked enemies. | Journal: tracked enemies (separate window) |
| `/hg journal bounty` | Open the enemy journal showing only enemies with a bounty. | Journal: bounty targets (separate window) |

## Bounties

| Command | What it does | UI equivalent |
| --- | --- | --- |
| `/hg bounty` · `/hg bounty board` | Open or close the bounty board. | Open bounty board (separate window) |
| `/hg bounty shared` · `/hg bounty shared board` | Open shared realm/faction bounties. | Open shared bounties |
| `/hg bounty add [GOLD] NAME [; note]` | Create a personal bounty, optionally with gold and a note. | Create a bounty (separate window) |
| `/hg bounty shared add GOLD DURATION NAME [; note]` | Publish a shared pledge with an expiry and optional note; publishing must be enabled. | Create a shared bounty (separate window) |
| `/hg bounty shared receive on\|off` | Enable or disable receiving shared bounties. | Shared bounty receiving → `bounty` |
| `/hg bounty shared publish on\|off` | Enable or disable publishing shared bounties. | Shared bounty publishing → `bounty` |
| `/hg bounty shared threshold GOLD` | Set the minimum shared bounty gold value for alerts. | Shared bounty alert threshold → `bounty` |
| `/hg bounty share NAME` | Prepare a bounty chat link; review it before sending. | Prepare bounty share |
| `/hg bounty export NAME` | Prepare a bounty code and post to copy outside the game. | Export a bounty |
| `/hg bounty import [CODE]` | Review a bounty link, code or complete post before importing. | Import a bounty |
| `/hg bounty submit NAME` | Submit a personal bounty to your guild. | Submit bounty to guild |
| `/hg bounty remove NAME` | Remove a bounty you can manage. | Remove a bounty |
| `/hg bounty claim NAME` | Report a bounty kill for review. | Report bounty kill |
| `/hg bounty approve NAME` | Officers: approve a pending bounty submission. | Approve bounty submission |
| `/hg bounty reject NAME` | Officers: reject a pending bounty submission. | Reject bounty submission |
| `/hg bounty shared claim NAME` | Report a shared bounty kill. | Report shared bounty kill |
| `/hg bounty shared withdraw NAME` | Withdraw your shared bounty contribution. | Withdraw shared contribution |
| `/hg bounty claims` · `/hg bounty shared claims` | Review kill claims and record approval or manual payment. | Review claims and payments |
| `/hg bounty gold` | Inspect account gold and funding settings. | Open gold and funding |
| `/hg bounty suggestions` | Review attackers, death reports and bounty drafts. | Open bounty suggestions |
| `/hg bounty test [FEATURE\|stop]` | Start a named sample scene or stop all bounty previews. | Bounty preview controls → `bounties-previews` |
| `/hg bounty guide [CHAPTER\|stop]` | Open a sample chapter of the bounty feature tour, or stop it. | Choose bounty sample chapter |
| `/hg guide bounties` | Choose the posting or hunting guide, each with its own saved place. | Choose bounty guide |
| `/hg guide bounty_post` | Start or resume posting and claim review lessons. | Start posting guide |
| `/hg guide bounty_hunt` | Start or resume hunting and claiming lessons. | Start hunting guide |
| `/hg bounty list` | Print current bounties in chat. | Print bounty list |
| `/hg bounty sync` | Request current guild bounties. | Request guild bounties |
| `/hg bounty shared sync` | Request shared realm/faction bounties. | Request shared bounties |
| `/hg bounty on` · `/hg bounty off` | Enable or disable bounty alerts. | Bounty alert switch → `bounty` |

## Reputation

| Command | What it does | UI equivalent |
| --- | --- | --- |
| `/hg reputation` | Reports, moderation and chat filtering for guilds and communities. | Open player reputation (separate window) |
| `/hg reputation communities` · `/hg reputation organizations` | Open the organization directory and account enable/disable controls. | Open organizations |
| `/hg reputation manage` | Open Blizzard's Guild & Communities UI. | Manage native organizations |
| `/hg reputation report [target\|NAME]` | Open a report for your target or a full player name. | Prepare player report |
| `/hg reputation sync` | Request updates from online native moderators. | Request reputation updates |
| `/hg reputation status` | Print the selected organization's sharing status. | Show sharing status |
| `/hg reputation on` · `/hg reputation off` | Enable or disable reputation chat filtering. | Chat filtering switch → `reputation-settings` |
| `/hg reputation help` | Print Reputation command help. | Print Reputation help |

## Macros

| Command | What it does | UI equivalent |
| --- | --- | --- |
| `/hg macros` | Open the macro browser and builder. | Open macros (separate window) |
| `/hg macros pvp` | Browse PvP macros for your class. | Browse PvP macros |
| `/hg macros pve` | Browse PvE macros for your class. | Browse PvE macros |
| `/hg macros build` | Build a macro with labeled controls. | Build a macro |
| `/hg macros mine` | Browse your existing macros. | Open your macros |
| `/hg macros export` | Export your macros as a shareable code. | Export macros |
| `/hg macros import` | Review and import a macro code. | Import macros |
| `/hg macros history` | Review backups and undo Highground macro edits. | Open macro backups |
| `/hg macros presets` | Browse presets for spells with ranks on WoW Forever. (WoW Forever) | Browse ranked spell presets |
| `/hg macros ranks` | Review action buttons and macros for highest-rank upgrades. (WoW Forever) | Review spell rank upgrades |

## Previews

Use each addon's **Previews and guide** page to start and stop samples. Open it from the addon's sidebar section, or choose **Visit** in **Addons**, then **Previews and guide**. Bounties also offers each sample scene there. Preview records stay separate from real records; panel positions can intentionally be saved.

`/hg bg test` toggles the battleground enemy list, target card, timers, objectives and flag carrier samples using your settings; `/hg bg test stop` ends them. `/hg test` and `/hg test all` start the catalogued previews across enabled addons, keeping existing samples on. Repeat either command to stop the set, or use `/hg test stop` to stop all samples. **Help and commands** provides **Toggle all addon previews** and **Stop all previews**. Start outside combat, matches and active guides or panel placement. Managed samples stop on combat, PvP instances and guide/placement handoffs. Bounties starts its wanted-poster scene unless another bounty sample is already running. Macros and Reputation use their guides and real tools instead of test toggles.

| Preview | Command | What it shows |
| --- | --- | --- |
| Battleground panels | `/hg bg test` | Enemy list, kill-target card, timers, objectives and flag carriers with sample data |
| Target marker | `/hg sniper test` | Crosshair on any target with a visible nameplate |
| Kill window | `/hg go` | GO look and sound (with Battleground panels or Target marker on) |
| Map pin | `/hg intel test` | Sample enemy pin on the world map |
| Burst marker | `/hg burst test` | Marker beside your target's nameplate (Cata) |
| Pressure shields | `/hg pressure test` | Shield badge on a targeted teammate or yourself (Cata) |
| Arena panel | `/hg arena test` | Preview opponents (not WoW Forever) |
| Nearby enemies | `/hg nearby test` | Open-world enemy list |
| Wanted poster | `/hg bounty test` | Toggle a live-style bounty sighting with sample data |
| Bounty board | `/hg bounty` | Open or close the bounty board |
| Macros | `/hg macros` | Ready-made PvP and PvE macros for your class, and a macro builder |

## Key bindings

Under **Key Bindings → AddOns → Highground**, bind targeting, focus, ping/mark, preparing a target call, opening Highground or toggling the bounty board. Secure target/mark actions remain on their existing buttons and key bindings.
