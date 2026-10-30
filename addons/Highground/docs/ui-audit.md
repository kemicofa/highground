# UI audit: start playing, add detail when needed

[Documentation](README.md) · [Getting started](getting-started.md)

This pass reviews the integrated Highground UI, the five standalone addons, shared controls and player documentation. The priorities are a quiet first login, readable actions for someone new to WoW, fewer decisions before playing, and recovery from common mistakes. Findings come from source inspection, full-addon simulations and rendered frame previews; they are not results from a player usability study.

## Findings and changes

| Area | Friction found | Changed experience |
| --- | --- | --- |
| First login | A setup checklist opens before the player has seen the addon work. Progress and profile prompts imply unfinished configuration. | One chat hint, no modal or deferred popup. Home says ready to play. The optional Quick guide stays available. |
| First battleground | Retail starts restricted to rated matches, so an ordinary battleground can appear unsupported. Forty enemy rows and many optional markers start enabled. | Fresh installs include unrated matches, show five enemies and use Essentials alerts. Extra overlays and low-health resurrection reminders start off. |
| Default layout | The enemy panel can intersect the objective panels at smaller resolutions. | An unpositioned normal enemy panel starts below them on the right. Explicit saved positions and compact placement are retained. Row count is visible in Appearance and the cogwheel menu. |
| Home and navigation | Setup progress, duplicate destinations and a large settings tree compete with the game. | Back to game and Preview and move panels are clear actions. Everyday settings stay visible; tuning, world tools and saved setups fold. The minimap menu has five entries. |
| Features | Detailed controls appear before a player understands the panels. Disabled children give little explanation. | One group at a time, primary switches first, More options for detail, and a reason beside disabled children. Values survive folding and group changes. |
| Playstyle presets | A role can enable unrelated features. Finishing placement opens another completion screen. | Presets change battleground tools and alerts, back up the current setup and preserve other choices. Done ends placement and returns to play. |
| Profiles | A persistent No named profile footer can make automatic saving seem incomplete. | Ordinary settings have no profile footer. Named, imported and pending profiles retain their context and recovery controls. |
| Macro presets | Raw code, abbreviated targets, two save destinations and editing compete on every card. Saving does not clearly explain how to use the result. | A short purpose, a full-name target menu and Use macro. A remembered Show macro code choice adds highlighted source, with scrolling for longer macros. The next step says to drag the icon from WoW macros to an action bar. More holds editing, account-wide copies and explicit replacement. |
| Existing macros | Reusing a preset can overwrite a player's manual edits. Search from one tab can hide useful results in another. | The primary action opens an existing character macro for editing. Tab switches clear search; empty states explain the next step. Undo changes stays available. |
| Combat panels | GOOD TIME TO DIE reads as tactical instruction; faction and shorthand labels require prior knowledge. | Resurrection reminders report timing. Flag rows say ALLY and ENEMY, and distinguish a dropped flag from no observed carrier. Suggested targets, protection ending, low mana, focus, trinkets and interrupt estimates get clearer wording. |
| Nearby enemies | Encounter totals and kills crowd combat rows; remembered sightings look current; pending combat rows say only new. | Names, level, location and age remain on rows. History and guild move to hover details. Pending rows say after combat. Standalone Nearby starts with five rows and routine sounds off; integrated Highground makes the panel optional. |
| Bounties | Empty lists do not distinguish search, guild membership, approval and receiving settings. Creation asks for audience before the player. | Contextual empty states, Refresh enabled when applicable, player-first form, optional rewards labeled, and an explanation when guild submission is unavailable. |
| Journals and history | Paging can leave details on an invisible selection. Deletion has no recovery. Fixed rows crowd enlarged text. | Details follow the visible page, clear search and helpful empty states are available, visible row count adapts, and Undo delete restores the last removal without replacing newer encounter data. |
| Standalone settings | Every tuning control and utility action is presented at once. | Main actions and a few panel choices first; More settings reveals behavior, appearance and occasional actions in a scrolling page. |
| Documentation | Guides describe required setup, old macro buttons and noisy defaults. | Installation, first-use, full user guide, command catalog, standalone READMEs and local project-description drafts match the new UI. |

## Compatibility and boundaries

New-install settings are applied only when no account settings table exists. Existing settings, named profiles, macros, bounty obligations, encounter history and explicit panel positions remain intact. The fallback location changes for a normal enemy panel that has never been positioned, including after resetting its position.

Detailed tuning, custom macros, per-category alerts, profile import/export and activity switching remain available. Bounty receiving and publishing remain independent opt-ins. Claims and payments retain their existing explicit actions; this pass does not change their rules or send messages.

WoW restricts protected actions in combat. Changes to enemy row count defer until combat ends. Suggested targets can change while the secure target button stays fixed; the card and tooltip explain this, and enemy rows/nameplates remain the alternative. Saving macros waits until combat ends.

## Verification

Run `bash tests/run.sh` from the repository root for validators, unit tests, full-addon scenarios, standalone client coverage and packaging/release tests. New scenarios explicitly distinguish fresh installs from existing installations, cover ordinary Retail battlegrounds, combat deferral, safe macro edits, hidden setting persistence, history recovery and large text. The `usability` group checks the default panels at 1280×720, 1280×820 and 1920×1080 in the geometry model.

`python3 tools/macro_preview.py --theme highground --scale 1.5 --state home` renders actual simulated frame trees into local HTML. States now also include features, alerts, guide, setup, journal, bounties, bounty-form and battleground, alongside the macro builder states and presets-code/hub-presets-code. These previews help inspect clipping and competing controls without a live match.

The geometry model approximates font metrics and does not reproduce native frame scaling, texture rendering, secure execution or taint. No live WoW client or human novice testing was available for this pass. Before release, verify normal and enlarged text in the supported clients, enter and leave combat with previews and menus open, and check the default layout against the player's Blizzard UI and other addons. Legacy 40-row lists and heavily customized layouts still depend on the player's chosen screen space.
