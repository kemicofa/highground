local _, ns = ...
local Timers = ns.Timers

local Tip = Timers.TipLine
local MID = { { 0.5, 0.5 } }
local AddLayer = ns.AddMapLayer or function() end -- Pins.xml failed to load: timers still run

-- Items are reused between refreshes, per map (owner: the map's data
-- provider, map/Pins.lua): graveyards and bases by their record, flags by
-- spawn. One left out of a refresh is dropped. Tooltips read their item.
local KINDS = { "graveyard", "flag", "node" }
local pools = setmetatable({}, { __mode = "k" })
local function Pool(owner)
  local p = pools[owner]
  if not p then
    p = { out = {}, stamp = 0, graveyard = {}, flag = {}, node = {} }
    pools[owner] = p
  end
  return p
end

local function Item(p, kind, key, tooltip)
  local list = p[kind]
  local item = list[key]
  if not item then
    item = { tooltip = tooltip }
    list[key] = item
  end
  item.stamp = p.stamp
  p.out[#p.out + 1] = item
  return item
end

local function Sweep(p)
  for _, kind in ipairs(KINDS) do
    for key, item in pairs(p[kind]) do
      if item.stamp ~= p.stamp then p[kind][key] = nil end
    end
  end
end

local function Capping(team)
  return team == Timers.MyTeam() and ns.Locale:Get("battlegrounds.layer.your_team.80b301") or ns.Locale:Get("battlegrounds.layer.enemy.a25632")
end

local function GraveyardTip(tt, item)
  local g, c, nw, est, cap, now = item.g, item.ring, item.nw, item.est, item.cap, item.now
  Tip(tt, ns.Locale:Format("battlegrounds.layer.value1_graveyard_value3.8368c3", { value1 = (g.team == Timers.MyTeam() and ns.Locale:Get("battlegrounds.layer.your.ba596f") or ns.Locale:Get("battlegrounds.layer.enemy.a25632")), value3 = Timers.GYName(g) }), c)
  if nw then
    -- Name the clock's source: a capture or a teammate's report is
    -- estimated too, but not from enemy deaths.
    local source = g.conf == "cap" and "battlegrounds.layer.from_base_capture_time.8580e8"
      or g.conf == "shared" and "battlegrounds.layer.from_a_teammate.d2dd3b"
      or est and "battlegrounds.layer.estimated_from_enemy_deaths.71fbd2"
    Tip(tt, ns.Locale:Format("battlegrounds.layer.next_res_in_value1_value2.944c3a", { value1 = string.format("%s", Timers.Clock(nw - now)), value2 = source and ns.Locale:Get(source) or "" }), "white")
  else
    Tip(tt, ns.Locale:Get("battlegrounds.layer.res_timer_unknown_yet.39019e"), "textMuted")
  end
  if cap then
    Tip(tt, ns.Locale:Format("battlegrounds.layer.value1_capping_cap_name_value4.d9f5e0", { value1 = Capping(cap.assault), cap_name = cap.name, value4 = (cap.capEnd and (": " .. Timers.Clock(cap.capEnd - now)) or "") }), Timers.TeamColor(cap.assault))
  end
end

local function FlagTip(tt, item)
  Tip(tt, ns.Locale:Format("battlegrounds.layer.flag_respawns_in_value2.245d42", { value2 = Timers.Clock(ns.flagRespawnAt - item.now) }), "white")
end

local function NodeTip(tt, item)
  local n, now = item.n, item.now
  Tip(tt, n.name, "gold")
  Tip(tt, ns.Locale:Format("battlegrounds.layer.value1_capping_value3.18befe", { value1 = Capping(n.assault), value3 = (n.capEnd and (": " .. Timers.Clock(n.capEnd - now)) or "") }), item.labelColor)
end

-- A graveyard's label is built again only when a clock or its name changes.
local CAP_ARGS, FLAG_ARGS = {}, {}
local function GraveyardLabel(item, g, nw, est, cap, now)
  local clock = nw and Timers.Clock(nw - now)
  local capClock = cap and (cap.capEnd and Timers.Clock(cap.capEnd - now) or "?")
  local mark = nw and (est or g.conf == "cap") and "~" or ""
  local base, locale = Timers.GYName(g), ns.Locale:GetLocale()
  if item.clock == clock and item.capClock == capClock and item.mark == mark and item.base == base
    and item.locale == locale and item.label then return end
  item.clock, item.capClock, item.mark, item.base, item.locale = clock, capClock, mark, base, locale
  local label = clock and (mark .. clock) or "?"
  if cap then
    CAP_ARGS.label, CAP_ARGS.value3 = label, capClock
    label = ns.Locale:Format("battlegrounds.layer.label_cap_value3.2a8bda", CAP_ARGS)
  end
  local name = Timers.GYMapName(g)
  if name ~= "" and name ~= "?" then label = name .. "\n" .. label end
  item.label = label
end

local capOn = {} -- [node name] = true: its capture timer is on a graveyard marker
AddLayer(function(mapID, _, _, _, _, owner)
  local p = Pool(owner or Timers)
  local items = p.out
  wipe(items)
  p.stamp = p.stamp + 1
  if not (Timers.Enabled() and mapID == Timers.MapID() and ns.IsActive and ns.IsActive()) then
    Sweep(p)
    return items
  end
  local now = GetTime()
  local placed = Timers.LiveGYs(mapID, now)
  wipe(capOn)
  for _, it in ipairs(placed) do
    local g, nw, est = it.g, it.nw, it.est
    local c = Timers.TeamColor(g.team)
    local n = g.node and Timers.nodes[g.node]
    if not n then
      for _, nd in pairs(Timers.nodes) do
        if nd.assault and nd.x and (nd.x - g.x) ^ 2 + (nd.y - g.y) ^ 2 < 0.05 ^ 2 then
          n = nd
        end
      end
    end
    local cap = n and n.assault and n or nil
    if cap then capOn[cap.name] = true end
    local item = Item(p, "graveyard", g, GraveyardTip)
    -- A spot taken from the base icon sits below it; a known one is exact.
    item.x, item.y, item.size = g.x, g.y + ((g.configured or g.exact) and 0 or 0.025), 16
    item.ring, item.icon, item.labelColor, item.alpha = c, "Interface\\Icons\\Spell_Holy_Resurrection", c, nw and 1 or 0.6
    item.g, item.nw, item.est, item.cap, item.now = g, nw, est, cap, now
    GraveyardLabel(item, g, nw, est, cap, now)
  end
  if ns.flagRespawnAt and ns.flagRespawnAt > now then
    -- At each flag's spawn (Warsong Gulch: both rooms), else mid-map.
    local flags = Timers.Rules().flags
    FLAG_ARGS.value2 = Timers.Clock(ns.flagRespawnAt - now)
    local label = ns.Locale:Format("battlegrounds.layer.flag_value2.b526b8", FLAG_ARGS)
    for i, at in ipairs(flags and flags.spawns or MID) do
      local item = Item(p, "flag", i, FlagTip)
      item.x, item.y, item.size, item.ring, item.label, item.now = at[1], at[2], 14, ns.Theme.Rgb("white"), label, now
    end
  end
  for _, n in pairs(Timers.nodes) do
    if n.assault and not capOn[n.name] then
      local item = Item(p, "node", n, NodeTip)
      -- Timer text only, in the capturing team's color, above the base icon.
      item.x, item.y, item.size = n.x, n.y - 0.03, 12
      item.label, item.labelColor = n.capEnd and Timers.Clock(n.capEnd - now) or "?", Timers.TeamColor(n.assault)
      item.n, item.now = n, now
    end
  end
  Sweep(p)
  return items
end)
