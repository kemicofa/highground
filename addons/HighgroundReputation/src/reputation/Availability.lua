local _, ns = ...
local W, O = ns.Reputation, ns.Organizations
W.probes, W.watchers = {}, {}
local TTL, LIMIT = 180, 128

function W.Presence(id, name)
  local peer = W.peers[name]
  local presence = peer and peer.communities[id]
  return presence and GetTime() - presence.at < TTL and presence or nil
end

function W.ReviewerReady(id, name)
  local member = O.Member(id, name)
  local presence = W.Presence(id, name)
  return member and member.online and O.ModeratorRole(member.role) and presence and presence.enabled == true or false
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
        if not member or not member.online or not O.ModeratorRole(member.role) then peer.communities[id] = nil end
      end
    end
  end
  for key, probe in pairs(W.probes) do
    local member = O.Member(probe.community, probe.name, memo)
    if not member or not member.online or not O.ModeratorRole(member.role) or GetTime() - probe.at > 600 then
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

local function Probe(id, member, force)
  if not member then return end
  local key = id .. ":" .. member.name
  if not member.online or not O.ModeratorRole(member.role) then
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
  local interval = force and 5 or (presence and 90 or 300)
  if (not old or now - old.at >= interval) and (old or W.Count(W.probes) < LIMIT) then
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
  if member and guild and guild.id == id then member = O.Member(id, member.name) end
  W.NoteModerator(id, member)
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
    return Status("unavailable", "Membership unavailable", "Waiting for the game to confirm your membership. Your draft is kept.")
  end
  if c and c.enabled == false then
    return Status("paused", "Off on this account", "Reputation is off on this account. Use Enable on this account in Overview to turn it back on.")
  end
  if W.CanModerate(c) then
    return Status("ready", "Enabled · You can review", "You can review proposals and publish blacklist decisions.", W.Me())
  end
  if not W.CanSend() then
    return Status("restricted", "Sharing paused by the game",
      "The game is blocking addon messages. You can queue a proposal now; it will send automatically when sharing resumes and a moderator is ready.")
  end
  local members, roster = W.Moderators(id)
  local online, checking, disabled, addon, incompatible = 0, false
  for _, member in ipairs(members) do
    if member.name ~= W.Me() and member.online and O.ModeratorRole(member.role) then
      online = online + 1
      local presence, probe = W.Presence(id, member.name), W.probes[id .. ":" .. member.name]
      local compatible = not ns.Protocols or ns.Protocols.Allows("reputation", member.name, W.VERSION)
      if not compatible then incompatible = member.name
      elseif presence and presence.enabled then
        return Status("ready", "Enabled · Moderator online", "A moderator with Reputation enabled is online. Proposals are sent privately for review.", member.name)
      elseif presence and presence.enabled == false then disabled = member.name
      elseif not probe or not probe.sentAt or GetTime() - probe.sentAt < 15 then checking = true
      elseif ns.Protocols and ns.Protocols.Peer("reputation", member.name) then addon = member.name end
    end
  end
  if O.CanModerate(id) and not (c and c.activated) then
    return Status("setup", "You can enable moderation", "Open this organization's Overview to enable Reputation and review proposals.", W.Me())
  end
  if roster ~= "ready" then
    return Status("loading", c and c.activated and "Enabled · Checking roster…" or "Checking roster…",
      "Waiting for the game roster. You can queue a proposal now; it will send when a moderator is available.")
  end
  if checking then
    return Status("checking", c and c.activated and "Enabled · Checking moderators…" or "Checking moderators…",
      "Checking online moderators. You can queue a proposal now; it will send automatically when ready.")
  end
  if disabled then
    return Status("not_enabled", c and c.activated and "Enabled · Online moderator has it off" or "Not enabled by online moderators",
      ns.Core.DisplayName(disabled, true) .. " has Reputation turned off here. Ask them to enable it in Overview; queued proposals will then send automatically.", disabled)
  end
  if addon or incompatible then
    return Status("update", c and c.activated and "Enabled · Moderator needs setup" or "Addon found · Setup unconfirmed",
      "A moderator has the addon, but sharing could not be confirmed. Ask them to update and enable Reputation. Proposals stay queued.", addon or incompatible)
  end
  if online > 0 then
    return Status("not_detected", c and c.activated and "Enabled · Moderator addon not detected" or "Moderator online · Addon not detected",
      "Online moderators have not answered the addon check. Proposals stay queued until an officer or community moderator has Reputation installed and enabled.")
  end
  return Status("offline", c and c.activated and "Enabled · No moderator online" or "No moderator online · Setup unconfirmed",
    "No moderator is online. Proposals are saved here and sent automatically when you and a moderator with Reputation enabled are online.")
end

function W.DeliveryText(c, report)
  if report.delivery ~= "queued" then
    local row = W.FindCase(c, report.target)
    if row and (row.reviewed[report.account] or 0) >= report.revision then return "Reviewed" end
    return "Received · Awaiting review"
  end
  if report.by ~= W.Me() then return "Queued · Log into " .. ns.Core.DisplayName(report.by) .. " to send" end
  local state = W.Availability(c.id)
  if state.ready then return "Sending · Awaiting receipt" end
  if state.code == "restricted" then return "Queued · Sharing paused by the game" end
  if state.code == "not_enabled" or state.code == "setup" then return "Queued · Waiting for Reputation to be enabled" end
  if state.code == "not_detected" or state.code == "update" then return "Queued · Waiting for moderator setup" end
  return "Queued · Waiting for an online moderator"
end
