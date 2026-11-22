# Shared addon networking

Highground is the only supported distribution. Standalone references below document compatibility with legacy peers and retained test hosts.

[Documentation](README.md) · [Library source](../libs/HighgroundKit/core/Network.lua)

`ns.Network` transports bounded text messages between players. It is shared by HighgroundKit consumers and has no bounty dependency. Bounties use it for both legacy guild messages and fragmented global/community messages; other features can choose their own prefix and schema.

Load `core/Util.lua`, `core/Events.lua`, your `ns.Core`, `core/Names.lua`, `core/Scope.lua`, `core/Comms.lua`, `core/Presence.lua`, `core/Outbox.lua`, `core/Network.lua`, `core/Protocols.lua`, then `core/ProtocolTransport.lua` before feature listeners in the addon's TOCs. The existing networking consumers already include these. A feature still owns its audience, opt-in settings, peer discovery, payload validation and reconciliation. Native membership and role queries are available separately through `ns.Guild` and `ns.Organizations`.

## Protocol compatibility

`ns.Protocols` is the shared registry for Highground, Battlegrounds, Bounties, Nearby and Reputation. Transport and feature versions are independent of addon release numbers. Every registry entry lists explicit send and receive versions; support for a higher version never implies support for intervening or older versions. Registering a feature listener with `Comms.Listen` activates its registry entries. Only loaded decoders are advertised.

| Registry ID | Prefix / format | Send versions | Receive versions |
| --- | --- | --- | --- |
| `wire` | Shared fragmented transport | 1 | 1 |
| `users` | `HighgroundU` presence | 1 | 1 |
| `capture` | `HighgroundC` | 1 | 1 |
| `intel` | `HighgroundI` | 3 | 2, 3 |
| `timers` | `HighgroundT` | 2 | 2 |
| `guild` | `HighgroundB` | 1, 2, 4, 5, 6, 7 | 1, 2, 4, 5, 6, 7 |
| `offer`, `claim` | `HighgroundBP` payload kinds | 1, 2, 3 | 1, 2, 3 |
| `bounty` | Other `HighgroundBP` payloads | 1 | 1 |
| `deaths` | `HighgroundD` | 1 | 1 |
| `reputation` | `HighgroundRep` | 1 | 1 |
| `profiles` | `HighgroundP` | 1 | 1 |

Capabilities use a separate `HighgroundN` prefix and a bounded, single-frame envelope:

```text
1|<Scope.Social()>|intel=2,3;timers=2;wire=1
```

The announcement lists receive formats, not permissions or enabled sharing settings. Valid unknown feature IDs are ignored. Each message is a partial advertisement: records from different standalone addons on one character merge, and omitted features remain unknown. Transport support is associated with the features in that same advertisement, so another standalone's library revision cannot overwrite those features' transport capabilities. A cache of at most 500 characters expires each feature record after 15 minutes, clears on social/character scope changes, and is never saved. Malformed, foreign-scope and unsupported-envelope messages are ignored.

Announcements happen automatically after accepted feature sends, on the same route and recipient, at most once per route every 5–6 minutes and four times per ten-second window per active addon. Failed capability sends back off for a minute and never change the original send result. There is no announcement queue, channel join, request/reply fan-out, or handshake prerequisite. Idle clients send no additional heartbeat. Metadata is best effort: a dropped or throttled announcement leaves the peer unknown until later traffic supplies it. Custom-channel receipt requires membership in an enabled existing discovery channel. Cataclysm's `HighgroundUsers` presence has a readable `Highground capabilities <envelope>` companion in that same channel; bounty capabilities travel on the existing addon whispers. The readable companion is hidden in participating clients' chat windows.

Directed bounty offers and claims choose the highest explicitly shared encoding that preserves the message's required semantics. Custom completion terms require at least v2; audiences, contracts and decisions require v3. Profile and reputation transfers check their existing v1 formats, and shared fragmented whispers check transport v1. Already queued messages are checked again before sending. An explicit incompatible advertisement produces a compatibility error; it never grants membership or bypasses the feature's authorization checks. Group and realm broadcasts retain their existing encodings and legacy fallbacks.

Missing or expired capability information preserves the caller's existing behavior. This includes older installations and installations with discovery disabled. It does not guarantee that a legacy receiver understands every current feature; that limitation already existed. Capabilities do not acknowledge receipt or negotiate packet-size limits. `/hg users why` includes supported formats, a recent-peer count and the last compatibility issue without character identities. Standalone bounty/reputation status and profile requests also report known incompatibilities.

### Adding a format

Register each stable protocol ID in `Protocols.lua` with its feature prefix, label and explicit encoder/decoder sets. Update those sets only when the implementation can actually produce or parse the corresponding formats. The current numeric feature versions are ordered by their required semantics; only use `Choose` where higher supported versions can preserve those semantics.

```lua
ns.Protocols.Register("myfeature", "MyPrefix", "my feature", "1,3", "1,2,3")
-- After Comms.Listen("MyPrefix", ...), the receive set is advertised.
local version, status, problem = ns.Protocols.Choose("myfeature", target, requiredVersion, legacyVersion)
if not version then return false, problem end
-- Encode using the selected format. For queued bytes, recheck their exact version:
local compatible, issue = ns.Protocols.Allows("myfeature", target, version)
```

`Choose` returns `compatible`, `incompatible`, `unknown`, or `broadcast` as its second result. A nil target preserves the legacy/broadcast version. `Allows` accepts unknown peers but rejects an explicitly unsupported exact version. Keep the feature's audience and consent checks, introduce new formats additively, and test both explicit incompatibility and absence of capability metadata against real decoders.

## Addon user discovery

### Reputation organizations

Reputation has its own discovery under `HighgroundRep`, shared by the bundled and standalone addon. Guild entry uses one `GUILD` announcement. Native officers/moderators announce readiness every 90–105 seconds; ordinary members have no periodic announcement. A member hello schedules one shared officer reply, coalesced across newcomers and limited to one announcement per officer per ten seconds. Broadcasts carry no reports or decisions. Their additive v1 frame is `1:H|<social scope>|<native guild ID>|<server timestamp.sequence>|<m/0/1>`: member, moderator disabled, or moderator ready. The native sender, current guild, role and scope are verified independently; the server timestamp and persisted sequence order changed status. The account reporting ID is not broadcast. Receiving a fresh enabled moderator schedules one synchronization pass instead of starting a snapshot for every announcement.

Communities retain roster-addressed whispers. Guilds allow announcements twelve seconds before trying the same legacy fallback. Fresh guild announcements suppress individual probes to that sender. Unknown or unanswered moderators are checked no more often than every 300 seconds (the periodic discovery pass can add up to 90 seconds); confirmed legacy receivers refresh every 90 seconds. Explicit refreshes have a five-second minimum. Discovery envelopes keep the legacy framing for interoperability, but no longer retain an acknowledgement/retry job after sending, and queued discovery expires after sixty seconds. Legacy peers still receive transport acknowledgements. Reports, snapshots and receipts retain their existing reliable delivery and live authorization checks.

Moderator scans omit ordinary-member records and sorting of the full roster. Up to 32 organizations retain at most 1,000 moderator identity hints each; the usual size is the number of native moderators. Hints refresh after five minutes, coalesce invalidations for five seconds, and clear on departure or scope change. Every use resolves current membership, role, identity and Forever ruleset eligibility. Peer/probe/watcher caches remain bounded at 128 entries each and the outgoing queue at 96. Ordinary members ignore other members' guild hellos before creating sender-rate records. Native roster requests have a 300-second background minimum; explicit requests and unavailable rosters can request sooner. Missing messages recover through heartbeats or later checks, and personal pause remains effective.

Reliable Reputation whispers back off instead of failing fast. A throttled or locked-down `HighgroundRep` prefix pauses all sending for 0.4–8 seconds and keeps queued items for up to two minutes; an offline recipient is dropped at once; other rejected sends retry with back-off and are dropped after four attempts spanning ten seconds. One sender holds at most four unfinished incoming messages; a newer one replaces its oldest. Nothing is whispered or retried to a recipient whose native presence is explicitly offline or app-only, which would print "No player named …" in chat; that recipient's queued items are cancelled and the next sync queues them again. Presence that has not loaded does not stop a send, and any message heard from the player in the last two minutes counts as online, covering a guild roster that is a few seconds stale after their login.

Snapshot transfers can resume. Packet 0 begins a transfer, 1..n are records and n + 1 ends it. A receiver whose session has made no progress for ten seconds sends an additive v1 `resend` packet naming up to 48 missing packet numbers for that transfer and request; after three requests without progress the session fails and the next sync starts a new one. Any new packet restarts that budget, so a long throttled transfer can stall several times. The sender keeps a finished transfer for two minutes and answers at most three resend requests, with the usual live authorization before every packet. Older peers ignore `resend`. Each sync request moves through `requested`, `receiving`, then `complete` or `failed`; packets for a finished request are ignored. A snapshot report record that is valid but older than the local revision, a duplicate vote or a record arriving at the 2,000-report cap is skipped while the rest of the snapshot applies; invalid or unauthorized records still reject it.

Other members' private reports are removed after you leave an organization. Only a native signal starts this (`CLUB_REMOVED`, or your own guild update with no guild), and a minute later the absence must be confirmed from live data the game can supply: a Battle.net outage, a loading roster or an unknown role never counts, and rejoining cancels it.

### General Highground users

On WoW Forever, dedicated discovery channels follow the active ruleset: `HighgroundUsersPvE`, `HighgroundUsersPvP`, `HighgroundUsersRP`, `HighgroundUsersRPPvP` or `HighgroundUsersHardcore`, with the same suffixes on `HighgroundBounties`. Highground and the standalone Bounties/Nearby hosts use the same bounty channel names. Retail and Cataclysm retain `HighgroundUsers` and `HighgroundBounties`.

Forever leaves the old unsuffixed channels and previous ruleset channels instead of bridging them. If the ruleset cannot be read, dedicated-channel discovery waits for it. Existing message-level scope validation remains in place. Players need an updated addon to discover each other on these channels; older releases stay on the unsuffixed channels. Bounty sharing and user discovery keep their separate opt-ins, so their member lists need not match.

Highground's addon-user discovery is owned by `addons/Highground/core/Peers.lua`, `PeerTransport.lua` and `PeerRoster.lua`, with its view in `hub/Users.lua`. It uses `Comms` directly for single-frame `HighgroundU` presence messages and `Network.CanSend()` for game restrictions. The wire is `1|<Scope.Social()>|<release version or ?>`; only bounded `x.y.z` releases are compared numerically. No identities or third-party version reports are forwarded.

Presence is announced separately to home party/raid, instance group, guild and the dedicated `HighgroundUsers` realm/faction channel. Classic's custom-channel fallback is `Highground users <wire>` in that channel only. Messages never solicit replies or whispers. One 15-second sleeping timer sends at most one presence message per tick, with 5–6 minute randomized heartbeat intervals, a minimum 60 seconds between attempts per route, coalesced group events and slow join/send retries. Accepted sends can also trigger the separately throttled capability announcement described above. Channel IDs are resolved at send time; receipt checks the channel, wire version and social scope. Peer receipt does constant work against a 500-character session cache; a minute timer pass prunes records after 15 minutes. Per-context timestamps expire independently. Native group rosters refresh on events, and scope or guild changes discard their old contexts. The page scans the bounded cache only when opened or every five seconds while visible; copying diagnostics also takes a fresh count snapshot.

`PeerRoster` requests the active discovery channel's native member list after joining, on opening `/hg users`, and through **Refresh members**. Background requests are at least 300 seconds apart; explicit requests have a 30-second minimum. It resolves display indexes separately from send-channel numbers, supports `C_ChatInfo.GetChannelRosterInfo` and the legacy global, and waits for `CHANNEL_ROSTER_UPDATE`. One sleeping one-second timer runs only while a request or coalesced event is pending. Row scans run at most once per five seconds, inspect at most 501 members, and never send addon messages or create request/reply fan-out. Display-index searches inspect at most 64 entries.

Requests defer while the native Channels/Communities UI is visible or combat/chat lockdown is active. They retain the previous selected channel and restore it after completion or a six-second timeout only while still owning the selection; another user's/addon's selection is never overwritten. Channel UI changes revalidate the display mapping without treating UI selection as a fresh roster response. Missing APIs, errors, unreadable values, duplicate names, missing rows, a missing local member and oversized lists cannot replace a complete snapshot. A complete list remains usable for six minutes; after that the page uses recent announcements. Scope, channel identity and preference changes discard roster state. Live Forever roster completeness and native update/selection behavior still require in-client verification.

The page unions the complete roster with recent announcements, deduplicating characters. A complete snapshot removes channel-only observations absent from that list, but preserves other contexts and announcements received after the request began. Channel membership never creates a version or capability advertisement: **Channel members without an announcement** is a separate count. Group/guild discovery and the existing presence cadence remain unchanged for compatibility. Two bounded member-name buffers hold the published list and a candidate scan; incomplete scans do not mutate the published list. The announcement cache holds up to 500 other characters and the complete roster up to 500 others, so the deduplicated total can be at most 1,001 including yourself.

`/hg guide users` uses the real Addon users page with isolated rendering data. **Refresh members** cycles through a full list, a departure and fallback; Replay, Back, closing, combat and instance entry clean up the sample. Preferences and diagnostics are disabled only in the sample. These interactions never request a live roster, change the live caches or send messages. Standalone addons do not load the users page or this roster reader; bounty discovery keeps its existing consent and transport.

While detection is enabled, counts include the local character immediately in the total, realm or realmset, installed version and active contexts. This known local presence does not require a successful send or an echoed announcement and does not expire. Self echoes are still rejected by receipt, and the local character consumes no peer-cache capacity: the local character is deduplicated against the roster and every announcement context. Disabling realm discovery removes channel membership from the count but preserves the known local realm count; disabling all discovery clears every count.

Discovery settings and the last local update-notice time are the only saved state. A reported newer release is an observation, not verification against a release service. Only the full Highground addon loads these modules; standalone addon versions are not interchangeable.

`/hg users why` (also **Copy diagnostics** on the page) opens a copyable, read-only snapshot with the client/build, social scope, local and other-user counts, both game messaging restriction flags, actual channel ID, prefix registration, join attempts and retry timing, the last discovery-channel notice, the last announcement's API acceptance, and roster request/scan counts, status, member count and snapshot age. Missing, failed and unreadable checks are reported separately from `false`. No probe is sent, and character names, rosters and message contents are omitted. The page distinguishes a realm restriction, chat messaging lockdown and a missing sending API. A paused join check does not consume the 5–6 minute retry delay; only a real join attempt starts that delay.

`Network.CanSend()` also returns a reason when false: `missing_api`, `outgoing_restricted` or `chat_lockdown`. Existing callers can keep using its boolean first result. These correspond to the sending API and Blizzard's `AreOutgoingAddonChatMessagesRestricted` / `InChatMessagingLockdown` checks; see the [generated game API documentation](https://github.com/BigWigsMods/WoWUI/blob/live/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua). Incoming delivery is controlled separately. API acceptance is not proof of remote receipt.

WoW Forever's `addonRestrictionAdvisory` capability keeps the outgoing-restriction flag in diagnostics without treating it as a send veto. Forever can report that flag as `true` outside chat lockdown while guild and custom-channel addon messages work, as documented by [Campkeeper's in-game testing and transport](https://github.com/Vikquick/Campkeeper/blob/main/Campkeeper/Comm/Comm.lua). A Highground diagnostic report from build 71037 showed the same flags: the old guard skipped every join/send attempt. Forever still pauses during `InChatMessagingLockdown`, requires the sending API and backs off on actual send failures. Other clients retain their outgoing-restriction check.

## Directed messages: presence and outbox

A whisper to an offline player prints "No player named … is currently playing". Retry directed addon messages only while the recipient seems online, using two core libraries loaded after `core/Comms.lua` in every host.

`ns.Presence` ([libs/core/Presence.lua](../libs/HighgroundKit/core/Presence.lua)) holds no saved state and at most `MAX` (256) names:

| API | Use |
| --- | --- |
| `Presence.Seen(who[, source])` | Record activity: call it for every inbound addon message, channel hello or other observation. A first sighting, or one after `WINDOW` (600 s) of silence, starts a new session |
| `Presence.Online(who)` | Seen within `WINDOW`, an online friend-list entry (with or without the local realm), native guild/community presence, or a feature source |
| `Presence.Session(who)` | Start (`GetTime`) of the current session, or 0 |
| `Presence.Recent(who)` | Seen within `WINDOW` only |
| `Presence.Listen(fn)` | `fn(name, source)` when a player starts a new session |
| `Presence.AddSource(fn)` | `fn(name)` returns true when the feature knows the player is online |

Names are canonical (`Name-Realm`, or WoW Forever's `First Last-Ruleset`); malformed, secret and the player's own names are ignored.

`ns.Outbox` ([libs/core/Outbox.lua](../libs/HighgroundKit/core/Outbox.lua)) tracks keyed directed sends. Create one per feature with `Outbox.New({ records = fn, now = fn, ready = fn, base = 120, cap = 3600, attempts = 8, keep = 604800, max = 2000 })`. `records()` returns the table holding its records, usually inside the feature's SavedVariables, so retries and acknowledgements survive reloads. `now()` is the clock for expiries and records (default `time`).

| Method | Use |
| --- | --- |
| `box:Send(key, who, expires, send[, force])` | Calls `send()` (which queues the message and returns acceptance) only when `who` is online, the backoff has passed (`base` doubling up to `cap`), fewer than `attempts` sends happened in the recipient's current session, it has not expired and was not delivered. `force = true` (a user action) sends at once; `"first"` does so only for a new key. Returns whether it sent |
| `box:Delivered(key)` | The recipient acknowledged the message: never send it again |
| `box:First(key)` | True the first time a key is offered: send each revision once at once, then repeat it only to online players |
| `box:State(key)` | Attempts and acknowledgement, for diagnostics and tests |
| `box:Prune([now])` | Forget records untouched for `keep` seconds once their message has expired, and keep at most `max` |

Use one key per message revision and recipient, and acknowledge with a reply the sender can match (bounty hunters echo stored reviews; decision recipients echo decisions). Keep the first send of a user action forced. `Comms.Send` remembers addon-whisper recipients for `Comms.NOTICE_SECONDS` (5) and installs, on the first whisper, a `CHAT_MSG_SYSTEM` filter that hides a recipient's offline notice only when the latest whisper to that name was an addon message; the player's own whispers keep theirs. Bounty sharing is the first consumer (`bounty/PublicWire.lua`); coverage is in `addons/Highground/tests/presence_test.lua`.

## Using a transport

```lua
local wire = ns.Network.New("MyFeature", {
  enabled = function() return MyFeature.Enabled() end,
  accept = function(channel, sender)
    return MyFeature.AllowedSender(channel, sender)
  end,
  authorize = function(item)
    return MyFeature.AllowedRecipient(item.route, item.context)
  end,
  onMessage = function(text, sender, channel)
    -- Decode a versioned schema and validate identity, fields and permissions.
    MyFeature.Receive(text, sender, channel)
  end,
})

-- Use a stable key to replace an unsent snapshot for this recipient.
local queued = wire:Send(serializedText,
  { channel = "WHISPER", target = "Friend-Realm" }, recordID, context)

ns.Util.Every(1, function()
  wire:Flush()
  wire:Clean()
end, "my feature network")
```

`Send` returns whether the message was queued, not whether another player received it. Handle `false` by retaining the authoritative local state and scheduling a later synchronization. Callbacks run inside the caller's event/timer guard. Choose a unique prefix of 1–16 bytes; `ns.Comms` permits one listener per prefix and registers it with the game.

| Operation | Behavior |
| --- | --- |
| `Send(text, route, key?, context?)` | Queue a fragmented text snapshot; reject invalid destinations, empty/NUL-containing text, oversized messages and a full queue. |
| `SendRaw(text, route, key?, context?)` | Queue an existing wire format or discovery hello unchanged, up to 255 bytes. |
| `Flush()` | Recheck authorization, discard invalid routes, then attempt at most one data frame, which may trigger a separately throttled capability announcement. Returns API acceptance when a send was attempted. |
| `Receive(text, channel, sender, ...eventArgs)` | Validate and assemble frames; normally called by the automatically registered listener. |
| `Clean()` | Expire abandoned receive buffers and sender rate windows. Also runs on receive. |
| `Clear()` | Empty pending sends, partial receives and rate windows. |

The route's `channel` is one of `WHISPER`, `GUILD`, `PARTY`, `RAID`, `INSTANCE_CHAT`, or `CHANNEL`. Whispers require `target`, normalized to `Name-Realm`. A custom `CHANNEL` accepts a name or local numeric ID; prefer its name so channel renumbering is resolved at send time. Joining channels and choosing a group distribution are feature responsibilities; `ns.Comms.GroupChannel()` can choose the current group distribution.

On WoW Forever, `Comms.Send` passes only the full character name (including surname) to the native whisper API: its internal realm/ruleset suffix is not a valid whisper address and causes “No player named … is currently playing” messages. Queues, payloads, permission checks and protocol callbacks keep the canonical identity. Retail and Classic retain their cross-realm whisper addresses.

Guild queues capture the current native guild ID where available, otherwise its guild/realm identity. Pending data is discarded when that identity changes. Features must recheck community membership, group membership, roles and consent through their authorization hooks, including for directed whispers.

## Hooks and limits

`New(prefix, options)` accepts:

- `enabled()`: whether this feature can exchange data; disabled transports reject incoming/enqueued data and clear pending work on flush.
- `accept(channel, sender, ...eventArgs)`: inbound route/sender check before any allocation or dispatch, including raw messages. The extra arguments are the original `CHAT_MSG_ADDON` event arguments after the sender, so custom-channel consumers can check the local channel ID/name.
- `authorize(item)`: outbound permission check at enqueue and every flush. `item.route` is the normalized destination and `item.context` is feature-owned metadata. Copy mutable authorization data when constructing the context.
- `onMessage(text, sender, channel)`: receives a complete reassembled message.
- `onRaw(text, sender, channel)`: optional handler for messages outside the fragment envelope, such as legacy discovery.
- `onSend(accepted, item, problem?)`: per-frame API result, including rejected attempts. A queued whisper discarded because of an explicit transport mismatch supplies `false` and the compatibility problem without calling the game API. Acceptance does not acknowledge remote receipt.
- `canSend()`: optional send availability function; the default checks the chat API and game messaging restrictions.
- `newID()`: optional ID generator; otherwise session seed plus sequence. IDs must be 8–64 ASCII alphanumeric, dot or hyphen characters and unique for each transfer/restart from this sender and prefix.
- `maxFailures`: consecutive rejected attempts before discarding a message, default 3; `0` retains it until successful or invalidated. Successful frames reset the counter.
- `listen = false`: keep an existing prefix listener; it must call `Receive` itself after any feature-specific discovery handling.

Each transport permits 128 queued messages, 64 incomplete incoming messages and 128 tracked senders. Messages are at most 3,840 bytes, split into at most 24 parts of 160 bytes. Each sender may send 90 frames per 30-second window. Incoming assemblies expire after 30 seconds. A transfer paused that long restarts at part one with a new ID. The sender should flush frequently enough to finish its largest transfer within that window.

A coalescing `key` is scoped to its destination. An in-flight snapshot finishes; at most one unsent successor with the same key is retained. Omit the key for messages that must not be coalesced. Duplicate and reordered parts within an assembly are supported; completed message replays are possible, so features must reconcile by stable record IDs and revisions.

The fragment format remains `1:<id>:<part>:<count>:<chunk>`. Serialized text must contain no NUL bytes; `ns.Codec.Pack` is suitable. The transport does not select a serializer, authenticate application fields, persist queues, discover offline peers or acknowledge delivery. Features need refresh/query behavior to recover missed messages.

## Bounty adapters

`bounty/Sync.lua` sends the existing `HighgroundB` guild protocol through `SendRaw`. Absolute expiry uses a version 7 entry plus a legacy fallback. Updated recipients preserve the original lifetime even when packets arrive in reverse order; older recipients retain their existing local-expiry behavior. Version 6 pot contracts retain their established format and reviewer rules.

Sync requests (`1:Q`) arriving within one randomized reply window share one answer, including the requester's audience of own shared offers. A reply refreshes only funding older than the two-minute heartbeat; it does not republish offers to other audiences. Communities are asked again every two minutes; idle ticks skip the native organization list until a request is due or a club event arrives. Received entries, sightings and settlements with escape codes, control characters or invalid names are ignored.

Directed whispers to offline players print "No player named … is currently playing", so directed retries use the shared `ns.Presence` and `ns.Outbox` libraries ([API](#directed-messages-presence-and-outbox)) and wait until the recipient seems online: an addon message from them within ten minutes, a channel hello, an online friend-list entry, or native guild/community presence. Each message backs off from two minutes to an hour, sends at most eight times per online session of its recipient and stops at its expiry (a week for claim reviews, the contract lifetime for pot decisions, the claim window for kill reports). Hunters echo each review they store and recipients echo each decision, which ends that message's retries; older clients ignore the echo. Hunters keep asking for the status of an unsettled claim while its poster is online. Contribution snapshots send each revision once, then repeat funding heartbeats only to recipients who seem online. `Comms.Send` remembers addon-whisper recipients for five seconds and a `CHAT_MSG_SYSTEM` filter hides only their offline notices.

Guild publication and settlement retries retain references to their saved records when the wire queue is full. List and settlement replies resume as capacity becomes available, so a large board is not truncated at the transport's queue limit. Deferred work also retains the originating guild identity and is discarded after a guild change.

`bounty/PublicWire.lua` adapts `HighgroundBP` to `Network`; `PublicMessages.lua` owns append-only schemas. Offers include exact target/author identity, contribution and contract IDs, reward, funding status, timestamps, expiry, kill terms/progress, audience, sightings and portrait metadata. Claims include evidence, cause, reviewer, progress, decisions and the recorded manual-payment timestamp. Wallet scope, private history and local-observation bookkeeping stay local.

Global discovery stays in the opted-in realm/faction channel (plus realmset on Forever). Cataclysm uses a readable discovery hello and directed addon whispers; clients supporting addon channels send data there. Guild payloads use the native guild identity and social scope, allowing cross-realm/faction guilds. Communities use native club identity and roster-addressed whispers with current membership/role checks at enqueue, send and receive. A community contribution that arrives before its approved original is held briefly in a bounded buffer and revalidated when the original arrives.

Forever communities can contain members from other rulesets. Before normalizing a roster name, the shared organization service checks its native GUID using [`C_PlayerInfo.UnitIsSameServer`](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/PlayerLocationDocumentation.lua). A native rejection excludes the member; when that lookup is unavailable, only an explicit matching realm/ruleset suffix is accepted. Unresolved bare names are skipped instead of receiving the local ruleset suffix. Native self membership remains available. Bounties and Reputation use this filtered membership for discovery, moderator selection, receipt and queued-send authorization; normal Retail cross-realm community access is unchanged.

Schemas append fields without shifting existing positions. Payloads exceeding the old 16-part bound and cross-realm native-guild metadata require updated recipients; the transport retains the existing envelope rather than silently truncating their contents. Global sharing still requires explicit opt-in. These are live addon exchanges; an offline player obtains current data through later synchronization with online participants.

## Directed messages: presence and outbox

A whisper to an offline player prints "No player named … is currently playing". Retry directed addon messages only while the recipient seems online, using two core libraries loaded after `core/Comms.lua` in every host.

`ns.Presence` ([libs/core/Presence.lua](../libs/HighgroundKit/core/Presence.lua)) holds no saved state and at most `MAX` (256) names:

| API | Use |
| --- | --- |
| `Presence.Seen(who[, source])` | Record activity: call it for every inbound addon message, channel hello or other observation. A first sighting, or one after `WINDOW` (600 s) of silence, starts a new session |
| `Presence.Online(who)` | Seen within `WINDOW`, an online friend-list entry (with or without the local realm), native guild/community presence, or a feature source |
| `Presence.Session(who)` | Start (`GetTime`) of the current session, or 0 |
| `Presence.Recent(who)` | Seen within `WINDOW` only |
| `Presence.Listen(fn)` | `fn(name, source)` when a player starts a new session |
| `Presence.AddSource(fn)` | `fn(name)` returns true when the feature knows the player is online |

Names are canonical (`Name-Realm`, or WoW Forever's `First Last-Ruleset`); malformed, secret and the player's own names are ignored.

`ns.Outbox` ([libs/core/Outbox.lua](../libs/HighgroundKit/core/Outbox.lua)) tracks keyed directed sends. Create one per feature with `Outbox.New({ records = fn, now = fn, ready = fn, base = 120, cap = 3600, attempts = 8, keep = 604800, max = 2000 })`. `records()` returns the table holding its records, usually inside the feature's SavedVariables, so retries and acknowledgements survive reloads. `now()` is the clock for expiries and records (default `time`).

| Method | Use |
| --- | --- |
| `box:Send(key, who, expires, send[, force])` | Calls `send()` (which queues the message and returns acceptance) only when `who` is online, the backoff has passed (`base` doubling up to `cap`), fewer than `attempts` sends happened in the recipient's current session, it has not expired and was not delivered. `force = true` (a user action) sends at once; `"first"` does so only for a new key. Returns whether it sent |
| `box:Delivered(key)` | The recipient acknowledged the message: never send it again |
| `box:First(key)` | True the first time a key is offered: send each revision once at once, then repeat it only to online players |
| `box:State(key)` | Attempts and acknowledgement, for diagnostics and tests |
| `box:Prune([now])` | Forget records untouched for `keep` seconds and keep at most `max` |

Use one key per message revision and recipient, and acknowledge with a reply the sender can match (bounty hunters echo stored reviews; decision recipients echo decisions). Keep the first send of a user action forced. `Comms.Send` remembers addon-whisper recipients for `Comms.NOTICE_SECONDS` (5) and installs, on the first whisper, a `CHAT_MSG_SYSTEM` filter that hides only those recipients' offline notices. Bounty sharing is the first consumer (`bounty/PublicWire.lua`); coverage is in `tests/presence_test.lua`.

## Verification

Run `luajit tests/network_test.lua` and `luajit tests/protocols_test.lua` from `addons/Highground` for isolated transport and compatibility tests. `tests/protocol_features_test.lua` checks actual package loading, bounty encoders/decoders, legacy peers, queued compatibility changes and profile requests; Reputation also has `tests/protocols_test.lua`. `tests/bounty_network.lua` runs through wrapper tests in all three bounty consumers and exercises actual addon events, discovery, failures, claim/payment round trips and client builds. `tests/bounty_organizations.lua` covers community authorization, guild identities and reordered contributions. `bash tests/run.sh` also validates manifests and packaged library copies.
