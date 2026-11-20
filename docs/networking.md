# Shared addon networking

[Documentation](README.md) · [Library source](../libs/HighgroundKit/core/Network.lua)

`ns.Network` transports bounded text messages between players. It is shared by HighgroundKit consumers and has no bounty dependency. Bounties use it for both legacy guild messages and fragmented global/community messages; other features can choose their own prefix and schema.

Load `core/Util.lua`, your `ns.Core`, `core/Names.lua`, `core/Comms.lua`, then `core/Network.lua` in the addon's TOCs. The existing networking consumers already include these. A feature still owns its audience, opt-in settings, peer discovery, payload validation and reconciliation. Native membership and role queries are available separately through `ns.Guild` and `ns.Organizations`.

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
| `Flush()` | Recheck authorization, discard invalid routes, then attempt at most one frame. Returns API acceptance when a send was attempted. |
| `Receive(text, channel, sender, ...eventArgs)` | Validate and assemble frames; normally called by the automatically registered listener. |
| `Clean()` | Expire abandoned receive buffers and sender rate windows. Also runs on receive. |
| `Clear()` | Empty pending sends, partial receives and rate windows. |

The route's `channel` is one of `WHISPER`, `GUILD`, `PARTY`, `RAID`, `INSTANCE_CHAT`, or `CHANNEL`. Whispers require `target`, normalized to `Name-Realm`. A custom `CHANNEL` accepts a name or local numeric ID; prefer its name so channel renumbering is resolved at send time. Joining channels and choosing a group distribution are feature responsibilities; `ns.Comms.GroupChannel()` can choose the current group distribution.

Guild queues capture the current native guild ID where available, otherwise its guild/realm identity. Pending data is discarded when that identity changes. Features must recheck community membership, group membership, roles and consent through their authorization hooks, including for directed whispers.

## Hooks and limits

`New(prefix, options)` accepts:

- `enabled()`: whether this feature can exchange data; disabled transports reject incoming/enqueued data and clear pending work on flush.
- `accept(channel, sender, ...eventArgs)`: inbound route/sender check before any allocation or dispatch, including raw messages. The extra arguments are the original `CHAT_MSG_ADDON` event arguments after the sender, so custom-channel consumers can check the local channel ID/name.
- `authorize(item)`: outbound permission check at enqueue and every flush. `item.route` is the normalized destination and `item.context` is feature-owned metadata. Copy mutable authorization data when constructing the context.
- `onMessage(text, sender, channel)`: receives a complete reassembled message.
- `onRaw(text, sender, channel)`: optional handler for messages outside the fragment envelope, such as legacy discovery.
- `onSend(accepted, item)`: per-frame API result, including rejected attempts. Acceptance does not acknowledge remote receipt.
- `canSend()`: optional send availability function; the default checks the chat API and game messaging restrictions.
- `newID()`: optional ID generator; otherwise session seed plus sequence. IDs must be 8–64 ASCII alphanumeric, dot or hyphen characters and unique for each transfer/restart from this sender and prefix.
- `maxFailures`: consecutive rejected attempts before discarding a message, default 3; `0` retains it until successful or invalidated. Successful frames reset the counter.
- `listen = false`: keep an existing prefix listener; it must call `Receive` itself after any feature-specific discovery handling.

Each transport permits 128 queued messages, 64 incomplete incoming messages and 128 tracked senders. Messages are at most 3,840 bytes, split into at most 24 parts of 160 bytes. Each sender may send 90 frames per 30-second window. Incoming assemblies expire after 30 seconds. A transfer paused that long restarts at part one with a new ID. The sender should flush frequently enough to finish its largest transfer within that window.

A coalescing `key` is scoped to its destination. An in-flight snapshot finishes; at most one unsent successor with the same key is retained. Omit the key for messages that must not be coalesced. Duplicate and reordered parts within an assembly are supported; completed message replays are possible, so features must reconcile by stable record IDs and revisions.

The fragment format remains `1:<id>:<part>:<count>:<chunk>`. Serialized text must contain no NUL bytes; `ns.Codec.Pack` is suitable. The transport does not select a serializer, authenticate application fields, persist queues, discover offline peers or acknowledge delivery. Features need refresh/query behavior to recover missed messages.

## Bounty adapters

`bounty/Sync.lua` sends the existing `HighgroundB` guild protocol through `SendRaw`. Absolute expiry uses a version 7 entry plus a legacy fallback. Updated recipients preserve the original lifetime even when packets arrive in reverse order; older recipients retain their existing local-expiry behavior. Version 6 pot contracts retain their established format and reviewer rules.

Guild publication and settlement retries retain references to their saved records when the wire queue is full. List and settlement replies resume as capacity becomes available, so a large board is not truncated at the transport's queue limit. Deferred work also retains the originating guild identity and is discarded after a guild change.

`bounty/PublicWire.lua` adapts `HighgroundBP` to `Network`; `PublicMessages.lua` owns append-only schemas. Offers include exact target/author identity, contribution and contract IDs, reward, funding status, timestamps, expiry, kill terms/progress, audience, sightings and portrait metadata. Claims include evidence, cause, reviewer, progress, decisions and the recorded manual-payment timestamp. Wallet scope, private history and local-observation bookkeeping stay local.

Global discovery stays in the opted-in realm/faction channel (plus realmset on Forever). Cataclysm uses a readable discovery hello and directed addon whispers; clients supporting addon channels send data there. Guild payloads use the native guild identity and social scope, allowing cross-realm/faction guilds. Communities use native club identity and roster-addressed whispers with current membership/role checks at enqueue, send and receive. A community contribution that arrives before its approved original is held briefly in a bounded buffer and revalidated when the original arrives.

Schemas append fields without shifting existing positions. Payloads exceeding the old 16-part bound and cross-realm native-guild metadata require updated recipients; the transport retains the existing envelope rather than silently truncating their contents. Global sharing still requires explicit opt-in. These are live addon exchanges; an offline player obtains current data through later synchronization with online participants.

## Verification

Run `luajit tests/network_test.lua` from `addons/Highground` for transport tests without bounty dependencies. `tests/bounty_network.lua` runs through wrapper tests in all three bounty consumers and exercises actual addon events, discovery, failures, claim/payment round trips and client builds. `tests/bounty_organizations.lua` covers community authorization, guild identities and reordered contributions. `bash tests/run.sh` also validates manifests and packaged library copies.
