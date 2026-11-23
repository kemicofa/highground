local _, ns = ...
local Core, U, P = ns.Core, ns.Util, ns.Profiler

---------------------------------------------------------------------------
-- Battleground profiler probes (see core/Profiler.lua). Once a second they
-- compare game and Highground state with the last reading and record what
-- changed: graveyard clocks, bases, map POIs, widgets, vignettes, flags,
-- chat lockdown and your subzone. Every 30 s a summary row. While recording,
-- hooks note each resurrection wave with the error of the prediction it
-- replaced, the rows the timer windows show, guarded stage times and errors.
---------------------------------------------------------------------------
local SUMMARY_EVERY, SCORE_EVERY, WIDGET_EVERY = 30, 10, 15
local last = {} -- [probe key] = last recorded signature
local gyLast = setmetatable({}, { __mode = "k" }) -- [graveyard] = { phase, est, conf }
local nextSummary, nextRows = 0, {}

local function Changed(key, sig)
  if last[key] == sig then return false end
  last[key] = sig
  return true
end

local function Num(v, places) return P.Num(v, places) end
local function Team(t) return (t == "A" or t == "H") and t or "-" end

---------------------------------------------------------------------------
-- Resurrection clocks
---------------------------------------------------------------------------
-- Seconds between two waves of one clock: the countdown plus any downtime.
local function Cycle(T)
  return T.WaveCycle and T.WaveCycle() or T.WavePeriod and T.WavePeriod()
end

local function Graveyards(T, now)
  local period, downtime = T.WavePeriod and T.WavePeriod(), T.Downtime and T.Downtime()
  local cycle = Cycle(T)
  local shared = T.SharedClock and U.call(T.SharedClock)
  local start = T.startClock and T.startClock.g and T.GYName(T.startClock.g)
  local samples = type(T.downtimes) == "table" and #T.downtimes or 0
  local lag = T.ReviveLag and U.call(T.ReviveLag)
  if Changed("clock", table.concat({ tostring(period), tostring(downtime), tostring(shared), tostring(start), samples, tostring(lag) }, "|")) then
    P.Add("clock", string.format("period=%s downtime=%s shared=%s start=%s downtimeSamples=%d reviveLag=%s", tostring(period),
      tostring(downtime or 0), tostring(shared), tostring(start or "-"), samples, Num(lag)))
  end
  for _, g in ipairs(T.gys or {}) do
    if T.Available(g) then
      local nw, est = T.NextWave(g, now)
      local phase = nw and cycle and nw % cycle
      local was = gyLast[g]
      local moved = not was or (phase == nil) ~= (was.phase == nil)
        or phase and math.abs(((phase - was.phase + cycle / 2) % cycle) - cycle / 2) > 1
      if moved or was.est ~= est or was.conf ~= g.conf then
        gyLast[g] = { phase = phase, est = est, conf = g.conf }
        P.Add("gy", string.format("%s %s next=%s est=%s conf=%s votes=%s", Team(g.team), T.GYName(g),
          Num(nw and nw - now), tostring(est == true), tostring(g.conf or "-"), Num(g.votes)))
      end
    end
  end
  if Changed("die", tostring(T.dieAlertedFor)) and T.dieAlertedFor then
    P.Add("advice", "die-now wave=" .. Num(T.dieAlertedFor - now))
  end
end

---------------------------------------------------------------------------
-- Bases, raw map POIs, widgets and vignettes
---------------------------------------------------------------------------
local function Nodes(T, now)
  for name, n in pairs(T.nodes or {}) do
    local icon = U.value(n.atlasName) or U.value(n.textureIndex)
    local sig = table.concat({ tostring(n.owner), tostring(n.assault), Num(n.capEnd, 0), Num(n.holdEnd, 0),
      Num(n.resetEnd, 0), tostring(icon) }, "|")
    if Changed("node:" .. name, sig) then
      P.Add("node", string.format("%s owner=%s assault=%s capLeft=%s icon=%s gy=%s", name, Team(n.owner),
        Team(n.assault), Num(n.capEnd and n.capEnd - now), tostring(icon), tostring(n.hasGraveyard == true)))
    end
  end
end

local seenPOI = {}
local function POIs(mapID)
  local A = C_AreaPoiInfo
  local ids = mapID and A and U.call(A.GetAreaPOIForMap, mapID)
  if type(ids) ~= "table" then return end
  local now = {}
  for _, id in ipairs(ids) do
    id = U.value(id)
    local info = id and U.call(A.GetAreaPOIInfo, mapID, id)
    if type(info) == "table" then
      now[id] = true
      local pos, x, y = U.value(info.position), nil, nil
      if type(pos) == "table" then
        x, y = U.call(pos.GetXY, pos)
        if not x then x, y = U.value(pos.x), U.value(pos.y) end
      end
      local sig = table.concat({ tostring(U.value(info.name)), tostring(U.value(info.atlasName)),
        tostring(U.value(info.textureIndex)) }, "|")
      if Changed("poi:" .. id, sig) then
        P.Add("poi", string.format("%s %s at=%s,%s", tostring(id), sig, Num(x and x * 100), Num(y and y * 100)))
      end
    end
  end
  for id in pairs(seenPOI) do
    if not now[id] then last["poi:" .. id] = nil; P.Add("poi", tostring(id) .. " gone") end
  end
  seenPOI = now
end

local GETTERS = { "GetIconAndTextWidgetVisualizationInfo", "GetTextWithStateWidgetVisualizationInfo",
  "GetDoubleIconAndTextWidgetVisualizationInfo", "GetDoubleStatusBarWidgetVisualizationInfo", "GetStatusBarWidgetVisualizationInfo",
  "GetCaptureBarWidgetVisualizationInfo", "GetDoubleStateIconRowVisualizationInfo", "GetScenarioHeaderTimerWidgetVisualizationInfo" }
local FIELDS = { "text", "leftText", "rightText", "overrideBarText", "leftBarValue", "rightBarValue", "leftBarMax", "rightBarMax",
  "barValue", "barMax", "barMaxValue", "timerValue", "shownState" }
local function WidgetText(W, id)
  for _, key in ipairs(GETTERS) do
    local data = U.call(W[key], id)
    if type(data) == "table" then
      local parts = {}
      for _, field in ipairs(FIELDS) do
        local v = U.value(data[field])
        if v ~= nil and v ~= "" then parts[#parts + 1] = field .. "=" .. tostring(v) end
      end
      return key:gsub("^Get", ""):gsub("WidgetVisualizationInfo$", "") .. " " .. table.concat(parts, " ")
    end
  end
end

-- Score widgets change every tick: a change of wording is recorded at once,
-- numbers alone once per WIDGET_EVERY seconds.
local widgetAt = {}
local function Widgets(now)
  local W = C_UIWidgetManager
  if not W then return end
  for _, set in ipairs({ "GetTopCenterWidgetSetID", "GetBelowMinimapWidgetSetID" }) do
    local setID = U.read(W[set])
    local list = setID and U.call(W.GetAllWidgetsBySetID, setID)
    for _, w in ipairs(type(list) == "table" and list or {}) do
      local id = U.value(w.widgetID)
      local text = id and WidgetText(W, id)
      if text then
        local shape = text:gsub("%d+", "#")
        local key = "widget:" .. id
        if last[key] ~= text and (last[key .. ":shape"] ~= shape or now - (widgetAt[id] or 0) >= WIDGET_EVERY) then
          last[key], last[key .. ":shape"], widgetAt[id] = text, shape, now
          P.Add("widget", id .. " " .. text)
        end
      end
    end
  end
end

local seenVignette = {}
local function Vignettes()
  local V = C_VignetteInfo
  local list = V and U.call(V.GetVignettes)
  if type(list) ~= "table" then return end
  local now = {}
  for _, guid in ipairs(list) do
    local info = U.value(guid) and U.call(V.GetVignetteInfo, guid)
    if type(info) == "table" then
      local sig = string.format("%s %s %s", tostring(U.value(info.vignetteID)), tostring(U.value(info.name)), tostring(U.value(info.atlasName)))
      now[sig] = true
      if not seenVignette[sig] then P.Add("vignette", "+ " .. sig) end
    end
  end
  for sig in pairs(seenVignette) do
    if not now[sig] then P.Add("vignette", "- " .. sig) end
  end
  seenVignette = now
end

---------------------------------------------------------------------------
-- Flags, lockdown, your subzone and the 30 s summary
---------------------------------------------------------------------------
local function Flags(now)
  local F = ns.Flags
  for _, team in ipairs({ "A", "H" }) do
    local c = F and F.carriers and F.carriers[team]
    local sig = type(c) ~= "table" and "none" or c.dropped and "dropped" or tostring(c.name)
    if Changed("flag:" .. team, sig) then P.Add("flag", team .. " carrier=" .. sig) end
  end
  if Changed("respawn", Num(ns.flagRespawnAt, 0)) and ns.flagRespawnAt then
    P.Add("flag", "respawn in=" .. Num(ns.flagRespawnAt - now))
  end
end

local function Lockdown()
  local lockdown = C_ChatInfo and U.read(C_ChatInfo.InChatMessagingLockdown)
  local blocked = ns.Comms and ns.Comms.Blocked and U.call(ns.Comms.Blocked)
  if Changed("lockdown", tostring(lockdown) .. tostring(blocked)) then
    P.Add("comms", string.format("lockdown=%s blocked=%s", tostring(lockdown), tostring(blocked or false)))
  end
  local area = U.read(GetSubZoneText)
  if Changed("area", tostring(area)) then P.Add("area", tostring(area)) end
end

local function Summary(T)
  local enemies, specs, sources = 0, 0, {}
  for _, e in pairs(Core.enemies or {}) do
    enemies = enemies + 1
    if e.specID or e.specLive then specs = specs + 1 end
    if e.specSrc then sources[e.specSrc] = (sources[e.specSrc] or 0) + 1 end
  end
  local src = {}
  for k, v in pairs(sources) do src[#src + 1] = k .. ":" .. v end
  table.sort(src)
  local st = T and T.stats or {}
  local heap = U.call(collectgarbage, "count")
  P.Add("summary", string.format("tracked=%s enemies=%d specs=%d(%s) group=%s waves=%s votes=%s guide=%s sent=%s recv=%s unsent=%s heapKB=%s fps=%s combat=%s",
    tostring(ns.IsActive and ns.IsActive() or false), enemies, specs, table.concat(src, ","), tostring(U.read(GetNumGroupMembers)),
    Num(st.waves, 0), Num(st.votes, 0), Num(st.guide, 0), Num(st.sent, 0), Num(st.recv, 0), Num(st.unsent, 0),
    Num(heap, 0), Num(U.read(GetFramerate), 0), tostring(U.read(InCombatLockdown) == true)))
end

-- The player's map can be unknown for a moment after entering; the
-- battleground's configured map stands in.
local function MapID(bg)
  local id = ns.CurrentMapID and ns.CurrentMapID()
  return id or bg and type(bg.ui) == "table" and bg.ui[1] or nil
end

local function Poll()
  local s, now, T = P.Session(), GetTime(), ns.Timers
  if not s then return end
  local bg = ns.GetBG and ns.GetBG()
  local live = ns.CurrentMapID and ns.CurrentMapID()
  if bg and Changed("map", tostring(bg.id) .. tostring(live)) then
    s.map.id, s.map.kind, s.map.mode, s.map.size, s.map.rulesKey = bg.id, bg.kind, bg.mode, bg.size, bg.rulesKey
    P.Add("map", string.format("%s kind=%s mode=%s size=%s rules=%s ui=%s", tostring(bg.id), tostring(bg.kind),
      tostring(bg.mode), tostring(bg.size), tostring(bg.rulesKey), tostring(live)))
  end
  P.PollMe(now)
  Lockdown()
  if T and T.gys then Graveyards(T, now); Nodes(T, now) end
  POIs(MapID(bg))
  Widgets(now)
  Vignettes()
  Flags(now)
  if now >= nextSummary then nextSummary = now + SUMMARY_EVERY; Summary(T) end
end
local ticker = U.Every(1, Poll, "bg profiler", "battlegrounds")
ticker.Stop()

---------------------------------------------------------------------------
-- Hooks, installed while recording. A wrapper someone else replaced stays
-- in place and passes calls through once recording ends.
---------------------------------------------------------------------------
local hooks = {}
local function Install(owner, key, make)
  if type(owner) ~= "table" or type(owner[key]) ~= "function" then return end
  local original = owner[key]
  local wrapper = make(original)
  hooks[#hooks + 1] = { owner = owner, key = key, original = original, wrapper = wrapper }
  owner[key] = wrapper
end

-- What a timer window shows: on a change of rows, else every SCORE_EVERY s.
local function RowsText(rows)
  local parts = {}
  for i, r in ipairs(type(rows) == "table" and rows or {}) do
    if i > 10 then break end
    parts[#parts + 1] = string.format("%s:%s:%s:%s%s", tostring(r.kind), Team(r.team), P.Clean(r.text),
      Num(r.left), r.est and "~" or "")
  end
  return table.concat(parts, " | ")
end
local function Shown(kind, rows)
  if not (P.Recording() and ns.IsActive and ns.IsActive()) then return end
  local now, text = GetTime(), RowsText(rows)
  local shape = text:gsub("%-?%d+%.?%d*", "#")
  if last["rows:" .. kind] ~= shape or text ~= "" and now >= (nextRows[kind] or 0) then
    last["rows:" .. kind], nextRows[kind] = shape, now + SCORE_EVERY
    P.Add(kind, text)
  end
end

local function Stage(s, stage, ms)
  local label = type(stage) == "string" and stage:sub(1, 80) or "unknown"
  local row = s.stages[label]
  if not row then
    if s.stageKeys >= P.MAX_STAGES then label = "other" end
    row = s.stages[label] or { calls = 0, ms = 0, maxMS = 0 }
    if not s.stages[label] then s.stages[label], s.stageKeys = row, s.stageKeys + 1 end
  end
  row.calls, row.ms, row.maxMS = row.calls + 1, row.ms + ms, math.max(row.maxMS, ms)
end

local clock = debugprofilestop or function() return GetTime() * 1000 end
local inside = false
local function Timed(s, stage, started, ...)
  Stage(s, stage, math.max(0, clock() - started))
  inside = false
  return ...
end

local function InstallHooks()
  local T = ns.Timers
  Install(T, "SetWave", function(original)
    return function(g, t, conf, ...)
      if not (P.Recording() and g and type(t) == "number") then return original(g, t, conf, ...) end
      local cycle = Cycle(T)
      local predicted = cycle and T.Available(g) and U.call(T.NextWave, g, t - cycle / 2)
      local was, before = g.conf, g.wave
      original(g, t, conf, ...)
      -- The same wave again: a ghost's whole-second countdown four times a
      -- second, or teammates coming back up to ~1.5 s apart.
      if was == conf and before and math.abs(t - before) <= 1.5 then return end
      P.Add("wave", string.format("%s %s %s at=%s err=%s kept=%s was=%s", tostring(conf), Team(g.team), T.GYName(g),
        Num(t - GetTime()), Num(predicted and t - predicted), tostring(g.wave == t), tostring(was or "-")))
    end
  end)
  Install(T, "SetPeriod", function(original)
    return function(p, ...)
      if P.Recording() then P.Add("clock", string.format("period %s -> %s", tostring(T.WavePeriod()), tostring(p))) end
      return original(p, ...)
    end
  end)
  Install(T, "Rows", function(original)
    return function(...)
      local rows = original(...)
      Shown("res", rows)
      return rows
    end
  end)
  Install(T, "ObjectiveRows", function(original)
    return function(...)
      local rows, info = original(...)
      Shown("obj", rows)
      return rows, info
    end
  end)
  for _, key in ipairs({ "Guard", "RunGuarded" }) do
    Install(U, key, function(original)
      return function(stage, fn, ...)
        local s = P.Session()
        if not s or inside then return original(stage, fn, ...) end
        inside = true
        return Timed(s, stage, clock(), original(stage, fn, ...))
      end
    end)
  end
  Install(U, "RecordError", function(original)
    return function(stage, err, ...)
      local s = P.Session()
      if s and #s.errors < P.MAX_ERRORS then
        s.errors[#s.errors + 1] = string.format("%s %s: %s", Num(GetTime() - s.t0), tostring(stage), P.Clean(err))
      end
      return original(stage, err, ...)
    end
  end)
end

local function RemoveHooks()
  for i = #hooks, 1, -1 do
    local h = hooks[i]
    if h.owner[h.key] == h.wrapper then h.owner[h.key] = h.original end
    hooks[i] = nil
  end
end

function P.SetProbes(on)
  wipe(last); wipe(gyLast); wipe(seenPOI); wipe(seenVignette); wipe(widgetAt); wipe(nextRows)
  nextSummary, inside = 0, false
  RemoveHooks()
  if on then
    InstallHooks()
    ticker.Start()
    Poll()
  else
    ticker.Stop()
  end
end
