local _, ns = ...
local Timers = ns.Timers

local TEAM_NAME = ns.Localization.Define({}, { A = "shared.copy.alliance.a21193", H = "shared.copy.horde.cf9229" })

-- Row models and working lists reused on every refresh (Timers.RowPool).
local pool = Timers.RowPool()
local NONE = {}
local clicks, caps, phases = {}, {}, {}
-- Format arguments, refilled on every refresh (translated text is formatted
-- each time, so a language change shows on the next refresh).
local args = { from = {} }
local function ByCapFinish(a, b) return a.c.finish < b.c.finish end
local function ByCapEnd(a, b) return (a.capEnd or math.huge) < (b.capEnd or math.huge) end
local function ByPhaseEnd(a, b) return (a.holdEnd or a.resetEnd) < (b.holdEnd or b.resetEnd) end
local clickEntries = {}
local function Click(e, c)
  local k = clickEntries[#clicks + 1] or {}
  clickEntries[#clicks + 1] = k
  k.e, k.c = e, c
  clicks[#clicks + 1] = k
end

function Timers.ObjectiveRows(now)
  local out = pool:Begin()
  local rules = Timers.Rules()
  Timers.UpdateNodePhases(now)
  -- Enemies clicking a banner right now (their capture cast).
  wipe(clicks)
  for _, e in pairs(ns.enemies or NONE) do
    local c = ns.Capping and ns.Capping(e)
    if c then Click(e, c) end
  end
  table.sort(clicks, ByCapFinish)
  for _, k in ipairs(clicks) do
    local left = math.max(0, k.c.finish - now)
    local row = pool:Add()
    k.e.short = k.e.short or k.e.display:match("^[^-]+")
    Timers.Tag(row, "CAPPING").team = Timers.Other(Timers.MyTeam())
    row.color = Timers.TeamColor(row.team)
    row.text = k.c.node and (k.e.short .. "  " .. k.c.node) or k.e.short
    row.left, row.total, row.est = left, k.c.finish - k.c.start, k.c.est
    row.time = string.format("%s%.1fs", k.c.est and "~" or "", left)
  end
  -- Teammates (and you) clicking a banner.
  if ns.AllyCaptures then
    for _, a in ipairs(ns.AllyCaptures()) do
      local left = math.max(0, a.finish - now)
      local node = a.node or a.me and ns.NodeForArea and ns.MyArea and ns.NodeForArea(ns.MyArea()) or nil
      local row = pool:Add()
      Timers.Tag(row, "CAPPING").team = Timers.MyTeam()
      row.color = Timers.TeamColor(row.team)
      row.text = (a.me and ns.Locale:Get("battlegrounds.objectives.you.905cb3") or a.name) .. (node and ("  " .. node) or "")
      row.left, row.total, row.time = left, a.finish - a.start, string.format("%.1fs", left)
    end
  end
  -- Captures in progress.
  wipe(caps)
  for _, n in pairs(Timers.nodes) do
    -- (a capture 20s past its timer that the map never resolved: drop it)
    if n.assault and not (n.capEnd and now - n.capEnd > 20) then
      caps[#caps + 1] = n
    end
  end
  table.sort(caps, ByCapEnd)
  for _, n in ipairs(caps) do
    local row = pool:Add()
    Timers.Tag(row, "CAP").color, row.team, row.node = Timers.TeamColor(n.assault), n.assault, n
    args.from.value2 = n.owner and TEAM_NAME[n.owner]
    row.text = n.name .. (n.owner and n.owner ~= n.assault and ns.Locale:Format("battlegrounds.objectives.from_value2.47ce47", args.from) or "")
    row.left = n.capEnd and n.capEnd - now
    row.total = n.capEnd and n.capStart and (n.capEnd - n.capStart) or Timers.CapTime()
  end
  local capture = rules.capture or NONE
  wipe(phases)
  for _, n in pairs(Timers.nodes) do
    if n.holdEnd or n.resetEnd then phases[#phases + 1] = n end
  end
  table.sort(phases, ByPhaseEnd)
  for _, n in ipairs(phases) do
    local row = pool:Add()
    Timers.Tag(row, n.holdEnd and "LOCK" or "RESET")
    row.color, row.team = n.owner and Timers.TeamColor(n.owner) or ns.Theme.Rgb("textMuted"), n.owner
    row.text, row.left, row.est = n.name, (n.holdEnd or n.resetEnd) - now, true
    row.total = n.holdEnd and capture.holdSeconds or capture.resetSeconds
  end
  if ns.flagRespawnAt and ns.flagRespawnAt > now then
    local row = pool:Add()
    Timers.Tag(row, "FLAG")
    row.color, row.left, row.icon = ns.Theme.Rgb("white"), ns.flagRespawnAt - now, Timers.FLAG_ICON
    row.text = ns.Locale:Get("battlegrounds.objectives.respawn.1b63d8")
    row.total = Timers.FlagRespawnTime()
  end
  if Timers.AddOverview then Timers.AddOverview(out, now, pool) end
  if Timers.Mechanics then Timers.Mechanics.Append(out, now, pool) end
  return out
end

-- The resurrection and timers windows, made on first use (named
-- <prefix>TimersFrame and <prefix>BasesFrame: Highground or the folder).
-- The win forecast has its own panel (timers/Forecast.lua).
function Timers.Windows()
  if not Timers.resWin then
    local prefix = ns.FRAME_PREFIX or "Highground"
    Timers.resWin = Timers.MakeWindow(prefix .. "TimersFrame", ns.Locale:Get("battlegrounds.objectives.resurrection.b90edc"), "timersPoint", { "TOP", "TOP", 0, -150 })
    Timers.objWin = Timers.MakeWindow(prefix .. "BasesFrame", ns.Locale:Get("battlegrounds.objectives.timers.94baf9"), "basesPoint",
      { "TOP", "TOP", Timers.THEME.timers.spacing, -150 })
    -- Titles follow a language change.
    ns.Localization.Bind(Timers.resWin.title, "battlegrounds.objectives.resurrection.b90edc")
    ns.Localization.Bind(Timers.objWin.title, "battlegrounds.objectives.timers.94baf9")
  end
  return Timers.resWin, Timers.objWin
end

function Timers.UpdateWindow(now)
  local resWin, objWin = Timers.Windows()
  Timers.ShowRows(resWin, Timers.Rows(now))
  local db = Timers.DB()
  local rows = Timers.ObjectiveRows(now)
  if db and ns.Core.On("objectives") and #rows > 0 then
    Timers.ShowRows(objWin, rows)
  else
    objWin:Hide()
  end
  local forecast = db and ns.Core.On("forecast") and Timers.Forecast(now)
  if forecast then Timers.ShowForecast(forecast) elseif Timers.foreWin then Timers.foreWin:Hide() end
end
function Timers.HideWindows()
  -- Other plain HUD windows, such as quick callouts, own their visibility.
  if Timers.resWin then Timers.resWin:Hide() end
  if Timers.objWin then Timers.objWin:Hide() end
  if Timers.foreWin then Timers.foreWin:Hide() end
end
ns.Test = ns.Test or {}
ns.Test.timersRows = Timers.Rows
ns.Test.objectiveRows = Timers.ObjectiveRows
ns.Test.predict = function(now)
  local sc = Timers.Scores(now)
  return sc, Timers.Predict(sc, now, false), Timers.Predict(sc, now, true)
end
