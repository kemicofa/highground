local _, ns = ...
local B, U, Core = ns.Bounty, ns.Util, ns.Core
local P = B.Public
local S = { FRESH = 120, GAP = 60, MOVE_GAP = 10 }
B.Sightings = S
local sent, notified = {}, {}

local function Text(value)
  return type(value) == "string" and #value <= 96 and not value:find("[%c|]")
end

function S.Validate(a)
  if type(a) ~= "table" or P.Name(a.by) ~= a.by or not P.Integer(a.at, 1, P.Now() + 30)
    or not Text(a.zone) or a.zone == "" or not Text(a.area) or not P.Integer(a.mapID, 0, 1000000)
    or type(a.world) ~= "boolean" or type(a.guid) ~= "string" or #a.guid > 64
    or a.guid ~= "" and not a.guid:match("^Player%-%w[%w%-]*$") then return end
  return { by = a.by, at = a.at, zone = a.zone, area = a.area, mapID = a.mapID, world = a.world, guid = a.guid }
end

function S.Pack(b)
  local data = b and b.intel
  if type(data) ~= "table" then return end
  local origin, latest = S.Validate(data.origin), S.Validate(data.latest)
  if origin or latest then return { origin = origin, latest = latest } end
end

local function Compatible(b, a)
  return a and (not b.guid or b.guid == "" or a.guid == "" or b.guid == a.guid)
end

function S.Merge(b, data)
  if type(data) ~= "table" then return false end
  local intel, changed = S.Pack(b) or {}, false
  for _, key in ipairs({ "origin", "latest" }) do
    local a, old = S.Validate(data[key]), intel[key]
    if Compatible(b, a) and (not old or key == "origin" and a.at < old.at or key == "latest" and a.at > old.at) then
      intel[key], changed = a, true
    end
  end
  if intel.origin or intel.latest then b.intel = intel end
  return changed
end

function S.Copy(to, from, localInfo)
  if not from then return end
  S.Merge(to, from.intel)
  local own = localInfo and S.Validate(from.localSighting)
  if Compatible(to, own) then to.localSighting = own end
end

function S.Current()
  local zone, area = U.read(GetZoneText) or "", U.read(GetSubZoneText) or ""
  if zone == "" then zone = area end
  return zone, area, U.read(C_Map and C_Map.GetBestMapForUnit, "player") or 0
end

function S.Near(a)
  if not a or not a.world or B.Where() ~= "world" or P.Now() - a.at > S.FRESH then return false end
  local zone, _, mapID = S.Current()
  if a.mapID > 0 and mapID > 0 then return a.mapID == mapID end
  return zone ~= "" and a.zone:lower() == zone:lower()
end

function S.Place(a)
  return a.area ~= "" and a.area ~= a.zone and (a.area .. " · " .. a.zone) or a.zone
end

function S.Describe(a)
  return S.Place(a) .. " · " .. Core.DisplayName(a.by) .. " · " .. B.Widgets.Ago(math.max(0, P.Now() - a.at)):lower()
end

function S.Combined(b)
  local out = {}
  S.Copy(out, b)
  for _, source in ipairs(b.contributions or b.pot and b.pot.contributions or {}) do S.Copy(out, source) end
  if b.personal then S.Copy(out, b.personal) end
  if b.guild then S.Copy(out, b.guild) end
  if b.offer then S.Copy(out, b.offer) end
  return out.intel or {}
end

function S.Location(b, compact)
  local intel, lines = S.Combined(b), {}
  if intel.origin then lines[#lines + 1] = ns.Locale:Format("shared.sightings.first_spotted_value2.8403c4", { value2 = (compact and S.Place(intel.origin) or S.Describe(intel.origin)) }) end
  if intel.latest then
    local a = intel.latest
    lines[#lines + 1] = (S.Near(a) and ns.Locale:Get("shared.sightings.in_your_zone.37159c") or "")
      .. (a.by == B.Me() and ns.Locale:Get("shared.sightings.last_seen_by_you.1d337e") or ns.Locale:Get("shared.sightings.latest_report.0595ed")) .. (compact and S.Place(a) or S.Describe(a))
  elseif b.seenAt then
    lines[#lines + 1] = (b.seenBy == B.Me() and ns.Locale:Get("shared.sightings.last_seen_by_you.1d337e")
      or b.seenBy and (ns.Locale:Format("shared.sightings.reported_by_value2.0ed337", { value2 = Core.DisplayName(b.seenBy) })) or ns.Locale:Get("shared.sightings.last_recorded_sighting.01cb7f"))
      .. (b.seenZone or ns.Locale:Get("shared.sightings.unknown_location.4f20e4")) .. " · " .. B.Widgets.Ago(math.max(0, time() - b.seenAt)):lower()
  end
  local own = not compact and S.Validate(b.localSighting)
  if own and own.by == B.Me() and intel.latest and own.at < intel.latest.at and intel.latest.by ~= B.Me() then
    lines[#lines + 1] = ns.Locale:Format("shared.sightings.last_seen_by_you_value2.286b1f", { value2 = S.Describe(own) })
  end
  return table.concat(lines, "\n")
end

local function Sources(name)
  local key, out, seen = B.Key(name), {}, {}
  local lists = B.Organizations.Lists(true)
  lists[#lists + 1], lists[#lists + 2] = P.Data().offers, B.Pot.Originals()
  for _, list in ipairs(lists) do
    for _, b in pairs(list) do
      if B.Key(b.name) == key and not seen[b] and B.Pot.Live(b) and (not b.id or B.Pot.Visible(b)) then
        out[#out + 1], seen[b] = b, true
      end
    end
  end
  return out
end

local function Muted(name)
  return B.Matches.State(name) == "ignored" or ns.NearbyHistory and ns.NearbyHistory.Muted(name)
end

local function Audience(b, channel, organization)
  if channel == "ORGANIZATION" then
    return b.organization == organization and B.Organizations.Member(organization)
      and (b.id and B.Pot.Visible(b) or b.state == "approved" and B.Visible(b))
  end
  if channel == "GUILD" then
    return not b.organization and B.InGuild() and B.Pot.Audience(b) ~= "private"
      and (b.id and P.GuildOffer(b) or b.state == "approved" and B.Visible(b))
  end
  return B.Pot.Audience(b) == "global" and (P.Receiving() or b.id and P.Mine(b))
end

function S.Broadcast(b, a)
  if not a.world or Muted(b.name) then return end
  local targets = {}
  if b.organization and Audience(b, "ORGANIZATION", b.organization) and Core.O("bountyShare") then
    targets[#targets + 1] = b.organization
  end
  if Audience(b, "GUILD") and Core.O("bountyShare") then targets[#targets + 1] = "@guild" end
  if B.Pot.Audience(b) == "global" and P.Connected()
    and (B.Matches.State(b.name) == "tracking" or P.CanManage(b) and P.Publishing()) then targets[#targets + 1] = "global" end
  for _, audience in ipairs(targets) do
    local key, now = B.Key(b.name) .. ":" .. audience, GetTime()
    local old = sent[key]
    local gap = old and old.zone ~= a.zone and S.MOVE_GAP or S.GAP
    if not old or now - old.at >= gap then
      local value = { id = B.Pot.ID(b), name = b.name, report = a }
      local queued
      if B.Organizations.ValidID(audience) then queued = B.Organizations.Broadcast("sighting", value, audience)
      elseif audience == "@guild" then queued = P.Enqueue("sighting", value, audience)
      elseif ns.Caps.addonChannel then queued = P.Enqueue("sighting", value)
      else for peer in pairs(P.peers) do queued = P.Enqueue("sighting", value, peer) or queued end end
      if queued then sent[key] = { at = now, zone = a.zone } end
    end
  end
end

function S.Observe(name, unit)
  if not P.ready or not B.Enabled() or not B.Known(name) or not B.Portraits.Matches(unit, name)
    or U.read(UnitIsDeadOrGhost, unit) then return end
  local zone, area, mapID = S.Current()
  local a = S.Validate({ by = B.Me(), at = P.Now(), zone = zone, area = area, mapID = mapID,
    world = B.Where() == "world", guid = U.read(UnitGUID, unit) or "" })
  if not a then return end
  local changed = false
  for _, b in ipairs(Sources(name)) do
    if Compatible(b, a) then
      changed = S.Merge(b, { origin = a, latest = a }) or changed
      b.localSighting = a
      S.Broadcast(b, a)
    end
  end
  if changed then B.Emit("updated") end
end

function S.Seed(b, prior)
  S.Copy(b, prior, true)
  S.Observe(b.name, B.Portraits.FindUnit(b.name))
end

function S.Notify(b, a)
  local near, now = S.Near(a), GetTime()
  if P.Now() - a.at > S.FRESH or Muted(b.name) or not B.Enabled() or not Core.O("bountyAnnounce")
    or not near and B.Matches.State(b.name) ~= "tracking" then return end
  local key = B.Key(b.name)
  if now - (notified[key] or -math.huge) < S.GAP then return end
  notified[key] = now
  local text = (near and ns.Locale:Get("shared.sightings.bounty_reported_in_your_zone.43fcda") or ns.Locale:Get("shared.sightings.bounty_sighting.b9479a")) .. Core.DisplayName(b.name) .. " · " .. S.Describe(a)
  U.Notify("bounty", "sighting:" .. key, text, near and B.PlaySound or nil, function()
    B.Say(text)
    if near then B.Poster.Show(b, S.Place(a), nil, false, a) end
  end)
end

function S.Receive(value, sender, channel, organization)
  if type(value) ~= "table" or not P.ID(value.id) or P.Name(value.name) ~= value.name then return end
  local a = S.Validate(value.report)
  local source = B.Pot.Source(value.id)
  if not a or a.by ~= sender or not a.world or P.Now() - a.at > S.FRESH or not source
    or B.Key(source.name) ~= B.Key(value.name) or not B.Pot.Live(source) or not Audience(source, channel, organization)
    or not Compatible(source, a) then return end
  local changed = false
  for _, b in ipairs(Sources(value.name)) do
    if Audience(b, channel, organization) then changed = S.Merge(b, { origin = a, latest = a }) or changed end
  end
  if not changed then return end
  B.Emit("updated")
  local b = B.Find(value.name, true)
  if b then S.Notify(b, a) end
end

-- Repeat the entry inside the chunked attachment so it works even if the
-- ordinary guild packet and the metadata arrive in the opposite order.
function S.SendGuild(b)
  local intel = S.Pack(b)
  if intel and b.state ~= "removed" then
    local value = { id = B.Pot.ID(b), name = b.name, payload = B.Scope.Wrap(B.Encode(b)), intel = intel }
    if b.organization then return B.Organizations.Broadcast("guildentry", value, b.organization) end
    return P.Enqueue("guildentry", value, "@guild")
  end
  return true
end

function S.ReceiveGuild(value, sender, organization)
  local b = type(value.name) == "string" and B.Guild(organization)[B.Key(value.name)]
  if not b or B.Pot.ID(b) ~= value.id or not B.Visible(b) or b.state == "removed"
    or sender ~= b.by and not B.IsOfficer(sender, organization) then return end
  if S.Merge(b, value.intel) then B.Emit("updated") end
end

B.Listen("added", function(b) S.Seed(b) end)
B.Listen("scope", function() wipe(sent); wipe(notified) end)
