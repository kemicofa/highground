# Which character owns the data?

Nearby History and Match History show the character currently logged in, on the current faction and realm or WoW Forever ruleset. Notes, mute choices, encounter counts and personal kill evidence follow the same boundary. Switching characters or rulesets restores that character's own records.

These rules apply to Highground and the standalone addons through the shared HighgroundKit library.

| Information | Boundary | Reason |
| --- | --- | --- |
| Nearby encounters, kills/deaths, notes and muted enemies | Character + faction + realm/ruleset | “You killed” and “killed you” describe the current character. Forget, delete and undo affect only that history. |
| Match results, statistics, timelines and unfinished matches | Character + faction + realm/ruleset | Win rates and personal performance belong to the participant. |
| Private bounties, private imports, tracking/ignore choices, arrival notices and kill evidence | Character + faction + realm/ruleset | Another character's personal target is not automatically yours. **My bounties** includes rewards posted by the current character. |
| Bounty suggestions and reply cooldowns | Character + faction + realm/ruleset | Personal deaths, dismissals and responses belong to the current character. Guild death reports also require current guild membership. |
| Shared bounty board, shared sightings and portraits | Realm/ruleset + faction | These are intentionally shared observations and rewards for that audience. |
| Claims and payment records | Shared reward audience; visible to the poster, claimant or authorized reviewer | Keep shared settlement and funding state without showing unrelated characters' claims. |
| Guild and community bounties; reputation reports and decisions | Native organization + game/region; Forever also separates rulesets | Current membership and native roles control access. Native guild/community IDs can span realms and factions. Name-only guild identities include realm and faction. |
| Gold balances and outstanding account commitments | Account within the current realm/ruleset economy, across factions | Account gold deliberately includes alts and prevents pledging the same recorded funds twice. Turning it off uses the current character's balance. |
| Previously observed enemy specializations | Game/region; Forever also separates rulesets | An exact enemy identity can help any character in the same environment. Unscoped external spec history is not used on Forever. |
| Learned capture times, graveyards, scoring rates and spec-inference samples | Game; Forever also separates rulesets, with map/mode keys where applicable | These describe game mechanics shared by characters and factions. |
| Character macro backups and automatic profile assignments | Character + faction + realm/ruleset | Undo and automatic switching must not use another character's changes. |
| General macro backups | Account + game/region, across rulesets | General macros use shared game storage. Their backups remain available to other characters. |
| Saved profiles, appearance, feature switches and alert preferences | Account, across rulesets | These are reusable user preferences. They exclude personal records. Existing per-character panel positions remain per character. |
| Highground Discord invitation | Same invite across clients, regions, factions and rulesets | Home copies the Discord invite. Forever's automatic-offer dismissal stays per character. Joining Discord does not change the scope of in-game Reputation or bounty data. |
| Live enemies, arena/duel state, peer detections and queued alerts | Current session/context | These are observations, not account history. Relevant caches and pending actions retire when context changes. |

The generated bounty contributor ID and reputation reporter ID remain account-wide. They prevent duplicate contributions and reports; they do not give an alt permission to change another character's reward or report.

## Existing saved records

Older tables without enough ownership/context information stay intact in SavedVariables but are excluded from the new scoped views. In particular, an old Nearby record names the enemy, not the character that encountered them. It cannot be safely assigned to whichever character logs in first. New encounters start a correctly attributed record. Old unscoped bounties can be recreated deliberately in the intended context.

Shared bounty identities, published contributions and their payment commitments, and reputation organization stores retain their existing storage. They are not cleared by forgetting a character's encounter history.

## Implementation and verification

`libs/core/Scope.lua` provides character, faction, realm/ruleset, social, mechanics and account stores. Character keys use the player's GUID where available, with an exact-name fallback while the GUID is unreadable. They include game, region, realm/ruleset and faction. A rename keeps GUID-owned records within that scope; a recreated character with a different GUID gets separate records.

Scope changes discard stale journal notes, delete callbacks, match state, bounty drafts, pending alerts and profile applications. Shared storage remains available through the corresponding audience checks.

`tests/data_scope.lua` runs against every public addon manifest. It covers alt login and reload, factions, regions, realms, games, all five Forever rulesets, GUID availability, legacy retention and live scope changes. Existing bounty gold, guild/community, reputation, macro and match simulations cover shared behavior and permissions.
