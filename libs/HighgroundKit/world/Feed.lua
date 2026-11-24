local _, ns = ...
local Util, Core, Comms = ns.Util, ns.Core, ns.Comms
ns.WorldFeed = {}
local Feed = ns.WorldFeed

---------------------------------------------------------------------------
-- Kill feed (`nearbyFeed`): your honorable kills of enemy players and your
-- deaths to them (world/History.lua), sent to the same group and guild as
-- sightings (world/Share.lua), and theirs. Entries stay 30 minutes, at most
-- 50, for the World activity window (world/Activity.lua). Open world only.
-- HighgroundW v1 message; the sender must be the killer or the victim:
--   1K:<zone uiMapID>:Killer-Realm,Victim-Realm,age,area
---------------------------------------------------------------------------
Feed.KEEP, Feed.MAX = 1800, 50
Feed.list = {} -- newest first: { killer, victim, at, mapID, area, by, via }
Feed.stats = { sent = 0, recv = 0 }

local Clean = Util.Clean

function Feed.On()
  return ns.Nearby.Enabled() and Core.On("nearbyShare") and Core.On("nearbyFeed") or false
end

local function Add(entry)
  table.insert(Feed.list, 1, entry)
  for i = #Feed.list, Feed.MAX + 1, -1 do Feed.list[i] = nil end
  if ns.WorldActivity then ns.WorldActivity.Changed() end
end

-- History's kill counters: "killedThem" (you killed name) or "killedMe".
function Feed.Local(name, counter)
  if not ns.Nearby.InWorld() then return end
  local me, enemy = Core.CanonUnit("player"), Core.Canon(name)
  if not (me and enemy) then return end
  local map = ns.WorldShare and ns.WorldShare.Here()
  local area = Util.read(GetSubZoneText)
  local mine = counter == "killedThem"
  local e = { killer = mine and me or enemy, victim = mine and enemy or me, at = GetTime(), mapID = map, area = area }
  Add(e)
  if not (Feed.On() and map) or Comms.Blocked() then return end
  local text = string.format("1K:%d:%s,%s,0,%s", map, Clean(e.killer), Clean(e.victim), Clean(area)):sub(1, 250)
  local group, any = ns.WorldShare.GroupChannel(), false
  if group and Comms.Send(ns.WorldShare.PREFIX, text, group) then any = true end
  if Core.On("nearbyShareGuild") and Util.read(IsInGuild) and Comms.Send(ns.WorldShare.PREFIX, text, "GUILD") then any = true end
  if any then Feed.stats.sent = Feed.stats.sent + 1 end
end

function Feed.Receive(text, channel, sender)
  if not (Feed.On() and ns.Nearby.InWorld()) then return end
  local via = (channel == "PARTY" or channel == "RAID") and "group"
    or channel == "GUILD" and Core.On("nearbyShareGuild") and "guild" or nil
  local from = via and Core.Canon(sender)
  if not from or from == Core.CanonUnit("player") then return end
  local map, killer, victim, age, area = text:match("^1K:(%d+):([^,]+),([^,]+),(%d+),(.*)$")
  age = tonumber(age)
  if not (map and (killer == from or victim == from) and killer ~= victim and age <= Feed.KEEP) then return end
  local at = GetTime() - age
  -- Both sides of one fight can report it.
  for _, f in ipairs(Feed.list) do
    if f.killer == killer and f.victim == victim and math.abs(f.at - at) < 10 then return end
  end
  area = Clean(area)
  Feed.stats.recv = Feed.stats.recv + 1
  Add({ killer = killer, victim = victim, at = at, mapID = tonumber(map), area = area ~= "" and area or nil, by = from, via = via })
end

-- Entries in one zone, newest first, no older than KEEP.
function Feed.Zone(mapID, now, out)
  out = out or {}
  for _, f in ipairs(Feed.list) do
    if f.mapID == mapID and now - f.at <= Feed.KEEP then out[#out + 1] = f end
  end
  return out
end

ns.Scope.Listen(function() wipe(Feed.list) end)
