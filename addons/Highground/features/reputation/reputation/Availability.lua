local _, ns = ...
local W, O = ns.Reputation, ns.Organizations
W.probes, W.watchers = {}, {}
local TTL, LIMIT = 180, 128

function W.Presence(id, name)
  local peer = W.peers[name]
  local presence = peer and peer.communities[id]
  return presence and GetTime() - presence.at < TTL and presence or nil
end

-- The game tracks community presence for at most one club at a time, so
-- members elsewhere often report "unknown". Such a member is reachable when
-- ns.Presence knows them online (recent addon traffic, an online friend,
-- another shared guild or community). Explicit offline or app-only is final.
function W.Gone(member)
  return not member or member.presence == "offline" or member.presence == "mobile"
end
function W.Reachable(member)
  if W.Gone(member) then return false end
  return member.online or ns.Presence.Online(member.name)
end

function W.ReviewerReady(id, name)
  local member = O.Member(id, name)
  local presence = W.Presence(id, name)
  return W.Reachable(member) and O.ModeratorRole(member.role) and presence and presence.enabled == true or false
end

-- Availability is session-only. The saved activation remains useful on alts
-- and while officers are offline, but never asserts that a receiver is online.
function W.ReconcilePresence()
  -- One sweep reads each guild rank's permission once (see O.Member).
  local memo = {}
  for name, peer in pairs(W.peers) do
    for id, presence in pairs(peer.communities) do
      if presence.announced then
        local member = O.Member(id, name, memo)
        if W.Gone(member) or not O.ModeratorRole(member.role) then peer.communities[id] = nil end
      end
    end
  end
  for key, probe in pairs(W.probes) do
    local member = O.Member(probe.community, probe.name, memo)
    -- Kept past UNKNOWN_EVERY: the record is what spaces an unknown member's probes.
    if W.Gone(member) or not O.ModeratorRole(member.role) or GetTime() - probe.at > W.UNKNOWN_EVERY then
      W.probes[key] = nil
      local peer = W.peers[probe.name]
      local presence = peer and peer.communities[probe.community]
      if presence and not presence.announced then peer.communities[probe.community] = nil end
    end
  end
  for key, watcher in pairs(W.watchers) do
    if GetTime() - watcher.at > 600 or not O.IsMember(watcher.community, watcher.name) then W.watchers[key] = nil end
  end
end

-- Moderators whose presence is unknown and not otherwise known online get a
-- slow, bounded probe: once per UNKNOWN_EVERY seconds each, and at most
-- UNKNOWN_BUDGET of them per 90 seconds, also on forced passes. Explicit
-- offline never is. Probes stop at PROBE_OUTBOX queued messages so the
-- rest of the outbox (96) stays free for proposals, sync requests and replies.
W.UNKNOWN_EVERY, W.UNKNOWN_BUDGET, W.PROBE_OUTBOX = 900, 3, 64
local budget = { at = -math.huge, left = 0 }
local function Unknown(now)
  if now - budget.at >= 90 then budget.at, budget.left = now, W.UNKNOWN_BUDGET end
  if budget.left <= 0 then return false end
  budget.left = budget.left - 1
  return true
end

local function Probe(id, member, force)
  if not member then return end
  local key = id .. ":" .. member.name
  if W.Gone(member) or not O.ModeratorRole(member.role) then
    local changed = W.probes[key] ~= nil
    W.probes[key] = nil
    local peer = W.peers[member.name]
    if peer and peer.communities[id] then peer.communities[id], changed = nil, true end
    return changed
  end
  if member.name == W.Me() then return end
  local now = GetTime()
  local old = W.probes[key]
  local presence = W.Presence(id, member.name)
  if presence and presence.announced then return end
  local reachable = W.Reachable(member)
  -- A forced pass (report form, Check for updates, sync) only shortens the
  -- interval for moderators known online.
  local interval = not reachable and W.UNKNOWN_EVERY or force and 5 or (presence and 90 or 300)
  if #W.outbox >= W.PROBE_OUTBOX then return end
  if (not old or now - old.at >= interval) and (old or W.Count(W.probes) < LIMIT)
    and (reachable or Unknown(now)) then
    local request = W.NewID()
    if W.Enqueue({ kind = "presence_query", community = id, request = request }, member.name, false, "presence_query:" .. id) then
      W.probes[key] = { community = id, name = member.name, request = request, at = now, sentAt = old and old.sentAt }
      return true
    end
  end
end

function W.Discover(id, force)
  if not W.ready or not O.IsMember(id) then return end
  local c = W.Get(id)
  if c and c.enabled == false then return end
  local guild, waiting = W.ScheduleGuild(id, force)
  if guild and waiting then return end
  -- Native roster events may wake discovery early; requests remain bounded.
  O.RequestRoster(id, force and 5 or 300)
  for _, member in ipairs(W.Moderators(id)) do Probe(id, member, force) end
end

function W.DiscoverMember(id, memberId)
  if not W.ready or not O.IsMember(id) then return end
  local c = W.Get(id)
  if c and c.enabled == false then return end
  local member = O.MemberByID(id, memberId)
  local guild = O.Guild()
  guild = guild and guild.id == id
  if member and guild then member = O.Member(id, member.name) end
  W.NoteModerator(id, member)
  -- Guild officers announce themselves when they log in. A whisper from
  -- every member at that moment would only crowd their queue; legacy
  -- officers are probed by periodic discovery after the announcement grace.
  if guild and member and member.online then return end
  return Probe(id, member)
end

local function Reply(watcher)
  local c = W.Get(watcher.community)
  W.NewID() -- Persisted sequence orders changed status even if packets reorder.
  return W.Enqueue({ kind = "presence", community = watcher.community, request = watcher.request,
    revision = W.db.sequence, enabled = W.CanModerate(c) }, watcher.name, false, "presence:" .. watcher.community)
end

function W.AnnounceAvailability(c)
  W.ScheduleGuild(c.id, true)
  for _, watcher in pairs(W.watchers) do
    if watcher.community == c.id then Reply(watcher) end
  end
end

function W.ReceiverDiscovered(id, enabled, old)
  local c = W.Get(id)
  if enabled then
    if not c then c = W.Follow(id, true) end
    if c then
      c.activated = true
      if W.Joined(c) and (not old or not old.enabled) then
        -- One scheduled sync chooses an authority. Twenty announcements must
        -- not start twenty snapshots or send the same proposal twenty times.
        W.nextSync = math.min(W.nextSync or math.huge, GetTime() + 2)
      end
    end
  end
  if not old or old.enabled ~= enabled then W.Changed(c) end
end

function W.HandlePresence(packet, sender)
  local id, now = packet.community, GetTime()
  if not O.IsMember(id) or not O.IsMember(id, sender) or not W.ID(packet.request) then return end
  local key = id .. ":" .. sender
  if packet.kind == "presence_query" then
    if not O.CanModerate(id) then return end
    local old = W.watchers[key]
    if old and now - old.at < 5 then return end
    local watcher = { community = id, name = sender, request = packet.request, at = now }
    -- Cache a bounded set for immediate change announcements. A full cache
    -- must not prevent another guild member receiving the current status.
    if old or W.Count(W.watchers) < LIMIT then W.watchers[key] = watcher end
    Reply(watcher)
  elseif packet.kind == "presence" then
    local probe = W.probes[key]
    if not probe or probe.request ~= packet.request or type(packet.enabled) ~= "boolean"
      or not W.Int(packet.revision, 1, 1000000000) or packet.revision <= (probe.revision or 0)
      or not O.CanModerate(id, sender) then return end
    probe.revision = packet.revision
    local old = W.Presence(id, sender)
    if old and old.announced then return end -- A delayed legacy reply cannot replace current guild status.
    W.Peer(sender, id, packet.enabled)
    W.ReceiverDiscovered(id, packet.enabled, old)
  end
end

local function Status(code, label, message, name)
  local warning = code == "not_enabled" or code == "not_detected" or code == "update"
  return { code = code, label = label, message = message, name = name, ready = code == "ready",
    tone = warning and "warning" or "textMuted" }
end

function W.Availability(id)
  local c = W.Get(id)
  if not O.IsMember(id) then
    return Status("unavailable", ns.Locale:Get("reputation.availability.membership_unavailable.853a6f"), ns.Locale:Get("reputation.availability.waiting_for_the_game_to_confirm_your.c93791"))
  end
  if c and c.enabled == false then
    return Status("paused", ns.Locale:Get("highground.coachrecords.off_on_this_account.264e67"), ns.Locale:Get("reputation.availability.reputation_is_off_on_this_account_use.783a2b"))
  end
  if W.CanModerate(c) then
    return Status("ready", ns.Locale:Get("reputation.availability.enabled_you_can_review.17260a"), ns.Locale:Get("reputation.availability.you_can_review_proposals_and_publish_blacklist.867df7"), W.Me())
  end
  if not W.CanSend() then
    return Status("restricted", ns.Locale:Get("reputation.availability.sharing_paused_by_the_game.787b1d"),
      ns.Locale:Get("reputation.availability.the_game_is_blocking_addon_messages_you.ae771a"))
  end
  local members, roster = W.Moderators(id)
  local online, checking, disabled, addon, incompatible = 0, false
  for _, member in ipairs(members) do
    if member.name ~= W.Me() and W.Reachable(member) and O.ModeratorRole(member.role) then
      online = online + 1
      local presence, probe = W.Presence(id, member.name), W.probes[id .. ":" .. member.name]
      local compatible = not ns.Protocols or ns.Protocols.Allows("reputation", member.name, W.VERSION)
      if not compatible then incompatible = member.name
      elseif presence and presence.enabled then
        return Status("ready", ns.Locale:Get("highground.coachrecords.enabled_moderator_online.21d494"), ns.Locale:Get("reputation.availability.a_moderator_with_reputation_enabled_is_online.162290"), member.name)
      elseif presence and presence.enabled == false then disabled = member.name
      elseif not probe or not probe.sentAt or GetTime() - probe.sentAt < 15 then checking = true
      elseif ns.Protocols and ns.Protocols.Peer("reputation", member.name) then addon = member.name end
    end
  end
  if O.CanModerate(id) and not (c and c.activated) then
    return Status("setup", ns.Locale:Get("reputation.availability.you_can_enable_moderation.2cbe8e"), ns.Locale:Get("reputation.availability.open_this_organization_s_overview_to_enable.bed1a1"), W.Me())
  end
  if roster ~= "ready" then
    return Status("loading", c and c.activated and ns.Locale:Get("reputation.availability.enabled_checking_roster.84105f") or ns.Locale:Get("reputation.availability.checking_roster.bb8945"),
      ns.Locale:Get("reputation.availability.waiting_for_the_game_roster_you_can.72b4cd"))
  end
  if checking then
    return Status("checking", c and c.activated and ns.Locale:Get("reputation.availability.enabled_checking_moderators.104d20") or ns.Locale:Get("reputation.availability.checking_moderators.345da5"),
      ns.Locale:Get("reputation.availability.checking_online_moderators_you_can_queue_a.370b1e"))
  end
  if disabled then
    return Status("not_enabled", c and c.activated and ns.Locale:Get("reputation.availability.enabled_online_moderator_has_it_off.d8aeee") or ns.Locale:Get("reputation.availability.not_enabled_by_online_moderators.40af85"),
      ns.Locale:Format("reputation.availability.value1_has_reputation_turned_off_here_ask.94483d", { value1 = ns.Core.DisplayName(disabled, true) }), disabled)
  end
  if addon or incompatible then
    return Status("update", c and c.activated and ns.Locale:Get("reputation.availability.enabled_moderator_needs_setup.4d4f3d") or ns.Locale:Get("reputation.availability.addon_found_setup_unconfirmed.0d834f"),
      ns.Locale:Get("reputation.availability.a_moderator_has_the_addon_but_sharing.a50362"), addon or incompatible)
  end
  if online > 0 then
    return Status("not_detected", c and c.activated and ns.Locale:Get("reputation.availability.enabled_moderator_addon_not_detected.e298ff") or ns.Locale:Get("reputation.availability.moderator_online_addon_not_detected.aebce8"),
      ns.Locale:Get("reputation.availability.online_moderators_have_not_answered_the_addon.d12f23"))
  end
  return Status("offline", c and c.activated and ns.Locale:Get("reputation.availability.enabled_no_moderator_online.1516cf") or ns.Locale:Get("reputation.availability.no_moderator_online_setup_unconfirmed.a8dec2"),
    ns.Locale:Get("reputation.availability.no_moderator_is_online_proposals_are_saved.d660b6"))
end

function W.DeliveryText(c, report)
  if report.delivery ~= "queued" then
    local row = W.FindCase(c, report.target)
    if row and (row.reviewed[report.account] or 0) >= report.revision then return ns.Locale:Get("reputation.availability.reviewed.31ef85") end
    return ns.Locale:Get("highground.coachrecords.received_awaiting_review.ed989d")
  end
  if report.by ~= W.Me() then return ns.Locale:Format("reputation.availability.queued_log_into_value2_to_send.cdcf8a", { value2 = ns.Core.DisplayName(report.by) }) end
  local state = W.Availability(c.id)
  if state.ready then return ns.Locale:Get("reputation.availability.sending_awaiting_receipt.45a0a9") end
  if state.code == "restricted" then return ns.Locale:Get("reputation.availability.queued_sharing_paused_by_the_game.5ca070") end
  if state.code == "not_enabled" or state.code == "setup" then return ns.Locale:Get("reputation.availability.queued_waiting_for_reputation_to_be_enabled.9a9c21") end
  if state.code == "not_detected" or state.code == "update" then return ns.Locale:Get("reputation.availability.queued_waiting_for_moderator_setup.1af768") end
  return ns.Locale:Get("reputation.availability.queued_waiting_for_an_online_moderator.90f775")
end
