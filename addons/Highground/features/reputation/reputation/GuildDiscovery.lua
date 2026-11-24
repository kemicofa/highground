local _, ns = ...
local W, O = ns.Reputation, ns.Organizations
local GAP, HEARTBEAT, GRACE = 10, 90, 12

local function State(id)
  if O.CanModerate(id) then return W.CanModerate(W.Get(id)) and "1" or "0" end
  return "m"
end

function W.ScheduleGuild(id, force)
  local org = O.Get(id)
  if not org or org.kind ~= "guild" then return false end
  local now, g = GetTime(), W.guildDiscovery
  local state = State(id)
  if not g or g.id ~= id then
    g = { id = id, started = now, due = now + 1 + math.random() * 3, state = state }
    W.guildDiscovery = g
    W.nextDiscovery = math.min(W.nextDiscovery or math.huge, now + GRACE)
  elseif force or g.state ~= state then
    g.state, g.due = state, math.max(now, (g.sent or -GAP) + GAP)
  end
  return true, now - g.started < GRACE
end

-- Members say hello on entry or explicit refresh. Only native moderators
-- heartbeat. A burst of member hellos schedules one shared reply per officer,
-- never a whisper per newcomer. The next heartbeat recovers dropped packets.
function W.GuildDiscoveryTick()
  local g, now = W.guildDiscovery, GetTime()
  if not g or not g.due or now < g.due then return end
  local org = O.Guild()
  if not org or org.id ~= g.id then W.guildDiscovery = nil; return end
  if not W.CanSend() then g.due = now + GAP; return end
  local state, c = State(g.id), W.Get(g.id)
  if state == "m" and c and c.enabled == false then g.due = nil; return end
  W.NewID()
  -- Order status changes without broadcasting the account's reporting ID.
  local revision = W.Now() .. "." .. W.db.sequence
  local text = table.concat({ "1:H", W.Scope(), g.id, revision, state }, "|")
  if #text <= 255 and W.SendRaw(text, "GUILD") then
    g.sent, g.state = now, state
    g.due = state ~= "m" and now + HEARTBEAT + math.random() * 15 or nil
  else g.due = now + 60 end
end

function W.ReceiveGuildHello(text, sender)
  local scope, id, revision, state = text:match("^1:H|([^|]+)|([^|]+)|([^|]+)|([m01])$")
  if scope ~= W.Scope() or not W.OrganizationID(id) or not W.ID(revision) then return end
  local stamp, sequence = revision:match("^(%d+)%.(%d+)$")
  stamp, sequence = tonumber(stamp), tonumber(sequence)
  if not W.Int(stamp, 1, 10000000000) or not W.Int(sequence, 1, 1000000000) then return end
  local org = O.Guild()
  if not org or org.id ~= id then return end
  local c = W.Get(id)
  if c and c.enabled == false then return end
  if state == "m" then
    if not O.CanModerate(id) or not O.IsMember(id, sender) then return end
    if W.CanModerate(c) then W.Peer(sender, id) end
    if not W.guildDiscovery or W.guildDiscovery.id ~= id then W.ScheduleGuild(id) end
    local g, now = W.guildDiscovery, GetTime()
    g.due = math.min(g.due or math.huge, math.max(now + 1 + math.random() * 2, (g.sent or -GAP) + GAP))
    return
  end
  local member = O.Member(id, sender)
  if not W.Reachable(member) or not O.ModeratorRole(member.role) then return end
  local old = W.Presence(id, sender)
  if old and old.announced and (stamp < old.stamp or stamp == old.stamp and sequence <= old.sequence) then return end
  W.Peer(sender, id, state == "1")
  local presence = W.Presence(id, sender)
  presence.stamp, presence.sequence, presence.announced = stamp, sequence, true
  W.NoteModerator(id, member)
  W.ReceiverDiscovered(id, state == "1", old)
end
