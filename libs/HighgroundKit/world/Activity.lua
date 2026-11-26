local _, ns = ...
local Util, Core, Kit = ns.Util, ns.Core, ns.Kit
ns.WorldActivity = {}
local A = ns.WorldActivity

---------------------------------------------------------------------------
-- World activity (`/hg activity`): one row per zone where you, your group
-- or your guild recently saw enemies (world/Nearby.lua, world/Share.lua),
-- placed map marks (world/Marks.lua) or traded kills (world/Feed.lua),
-- most recent first. Details count enemies, classes, guilds, marks and
-- kills; Show on map opens that zone. Built from what Nearby remembers:
-- nothing here is saved. A guide passes isolated sample zones.
---------------------------------------------------------------------------
A.RECENT = 60 -- seconds: "in the last minute"

local function Zone(zones, order, mapID)
  local z = zones[mapID]
  if not z then
    z = { mapID = mapID, enemies = 0, now = 0, classes = {}, guilds = {}, marks = {}, kills = {}, last = -math.huge }
    zones[mapID], order[#order + 1] = z, z
  end
  return z
end

local function Latest(a, b) return a.last > b.last end
local function Largest(a, b) return a[2] > b[2] or (a[2] == b[2] and a[1] < b[1]) end

-- The zones with activity, most recent first.
function A.Zones(now)
  now = now or GetTime()
  local zones, order = {}, {}
  local forget = Core.O("nearbyForget")
  for _, e in pairs(ns.Nearby.seen) do
    if e.mapID and now - e.last <= forget then
      local z = Zone(zones, order, e.mapID)
      z.enemies = z.enemies + 1
      if now - e.last <= A.RECENT then z.now = z.now + 1 end
      if e.class then z.classes[e.class] = (z.classes[e.class] or 0) + 1 end
      if e.guild and e.guild ~= "" then z.guilds[e.guild] = (z.guilds[e.guild] or 0) + 1 end
      z.last = math.max(z.last, e.last)
    end
  end
  local Marks = ns.WorldMarks
  for _, list in ipairs(Marks and { Marks.own, Marks.heard } or {}) do
    for _, m in pairs(list) do
      local z = Zone(zones, order, m.mapID)
      z.marks[m.type] = (z.marks[m.type] or 0) + 1
      z.last = math.max(z.last, m.at)
    end
  end
  for _, f in ipairs(ns.WorldFeed and ns.WorldFeed.list or {}) do
    if f.mapID and now - f.at <= ns.WorldFeed.KEEP then
      local z = Zone(zones, order, f.mapID)
      z.kills[#z.kills + 1] = f
      z.last = math.max(z.last, f.at)
    end
  end
  table.sort(order, Latest)
  return order
end

-- "Rogue 4, Mage 3": the largest counts first, at most five.
local function Top(counts, label)
  local list = {}
  for key, n in pairs(counts) do list[#list + 1] = { key, n } end
  table.sort(list, Largest)
  for i = 1, #list do list[i] = i <= 5 and (label(list[i][1]) .. " " .. list[i][2]) or nil end
  return table.concat(list, ", ")
end

local function Name(canon)
  if canon == Core.CanonUnit("player") then return ns.Locale:Get("activity.you") end
  return Core.DisplayName(canon)
end

local function MarkCount(z)
  local n = 0
  for _, c in pairs(z.marks) do n = n + c end
  return n
end

function A.Entry(z, now, name)
  local zone = name or ns.WorldShare.MapName(z.mapID) or ns.Locale:Get("shared.journal.unknown_zone.36ecb6")
  local lines = { zone }
  lines[#lines + 1] = ns.Locale:Format("activity.detail.enemies", { count = z.enemies, now = z.now })
  if next(z.classes) then lines[#lines + 1] = ns.Locale:Format("activity.detail.classes", { list = Top(z.classes, Util.ClassName) }) end
  if next(z.guilds) then lines[#lines + 1] = ns.Locale:Format("activity.detail.guilds", { list = Top(z.guilds, function(g) return "<" .. g .. ">" end) }) end
  if next(z.marks) then lines[#lines + 1] = ns.Locale:Format("activity.detail.marks", { list = Top(z.marks, ns.WorldMarks.Label) }) end
  if #z.kills > 0 then
    lines[#lines + 1] = ns.Locale:Get("activity.detail.kills")
    for i = 1, math.min(#z.kills, 10) do
      local f = z.kills[i]
      -- A bounty on the victim: its reward (bounty/).
      local bounty = ns.Bounty and ns.Bounty.Enabled() and ns.Bounty.Find(f.victim)
      lines[#lines + 1] = "  " .. ns.Locale:Format("activity.detail.kill", { killer = Name(f.killer), victim = Name(f.victim),
        where = f.area and (" · " .. f.area) or "", ago = Util.Ago(math.floor(now - f.at)) })
        .. (bounty and (" · " .. ns.Locale:Format("shared.journal.bounty_value2.b4abd7", { value2 = ns.Bounty.GoldText(bounty) })) or "")
    end
  end
  lines[#lines + 1] = ns.Locale:Format("activity.detail.last", { ago = Util.Ago(math.max(0, math.floor(now - z.last))) })
  return { key = tostring(z.mapID), mapID = z.mapID, title = zone, record = z,
    summary = ns.Locale:Format("activity.summary", { enemies = z.enemies, now = z.now, marks = MarkCount(z), kills = #z.kills }),
    detail = table.concat(lines, "\n") }
end

function A.Entries()
  local now, out = GetTime(), {}
  for i, z in ipairs(A.Zones(now)) do out[i] = A.Entry(z, now) end
  return out
end

-- Open the world map on a zone.
function A.ShowOnMap(mapID)
  if not (WorldMapFrame and mapID) then return false end
  if not WorldMapFrame:IsShown() then Util.call(ToggleWorldMap) end
  return Util.call(WorldMapFrame.SetMapID, WorldMapFrame, mapID) ~= nil or WorldMapFrame:IsShown()
end

function A.Build(provider)
  local owner = provider or A
  if owner.win then return owner.win end
  owner.win = Kit.Browser((ns.FRAME_PREFIX or "Highground") .. "WorldActivity" .. (provider and (provider.suffix or "Sample") or ""), {
    title = ns.Locale:Get("activity.title"), hint = ns.Locale:Get("activity.hint"),
    width = 760, height = 560, listRatio = 0.4, rowHeight = 52,
    data = provider and provider.entries or A.Entries, empty = ns.Locale:Get("activity.empty"),
    actions = {
      { label = ns.Locale:Get("activity.show_on_map"), tone = "accent", run = function(e)
        if provider then return true, ns.Locale:Get("activity.sample") end
        A.ShowOnMap(e.mapID)
        return true
      end },
    },
  })
  if not provider then
    local refresh = Util.Every(2, function() if A.win:IsShown() then A.win:Refresh() end end, "world activity", "nearby")
    refresh.Stop()
    A.win:HookScript("OnShow", refresh.Start)
    A.win:HookScript("OnHide", refresh.Stop)
  end
  return owner.win
end

function A.Open()
  local w = A.Build()
  if w:IsShown() then w:Hide() else w:Open() end
  return w
end

-- A new kill: refresh an open window.
function A.Changed()
  if A.win and A.win:IsShown() then A.win:Refresh() end
end

-- `/hg activity test`: the sample zones in their own window. A window, so
-- it has its own preview button and stays out of `/hg test`.
local preview = { suffix = "Preview", entries = function() return A.Samples() end }
function A.PreviewShown() return preview.win ~= nil and preview.win:IsShown() end
function A.Preview()
  if A.PreviewShown() then preview.win:Hide(); return false end
  A.Build(preview):Open()
  return true
end

-- Guide and preview samples: two zones, one with a mark and kills.
function A.Samples()
  local now = GetTime()
  local busy = { mapID = 0, enemies = 9, now = 6, classes = { ROGUE = 4, MAGE = 3, PRIEST = 2 }, guilds = { ["Night Watch"] = 5 },
    marks = { enemies = 2 }, kills = { { killer = "Guildmate", victim = "Sneakypete", at = now - 90, area = "Tarren Mill" } }, last = now - 5 }
  local quiet = { mapID = 0, enemies = 2, now = 0, classes = { WARRIOR = 2 }, guilds = {}, marks = {}, kills = {}, last = now - 240 }
  return { A.Entry(busy, now, ns.Locale:Get("shared.preview.tarren_mill.f2b545")),
    A.Entry(quiet, now, ns.Locale:Get("shared.nearby.hillsbrad_fields.ead610")) }
end
