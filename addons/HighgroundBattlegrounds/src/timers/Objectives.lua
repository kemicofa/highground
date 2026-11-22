local _, ns = ...
local Timers = ns.Timers

local TEAM_NAME = ns.Localization.Define({}, { A = "shared.copy.alliance.a21193", H = "shared.copy.horde.cf9229" })
-- Bases that score, per battleground (the map also lists other points,
-- e.g. Eye of the Storm's flag), and what to call them.
function Timers.Round10(v)
  return math.floor(v / 10 + 0.5) * 10
end

-- Row models and working lists reused on every refresh (Timers.RowPool).
local pool = Timers.RowPool()
local hn, nn, clicks, caps, phases = {}, {}, {}, {}, {}
local outQ, outHeld, outNeed = {}, {}, {}
-- Format arguments, refilled on every refresh (translated text is formatted
-- each time, so a language change shows on the next refresh).
local args = { info = {}, score = {}, need = {}, from = {} }
local function Score(p)
  local a = args.score
  a.value1, a.value2, a.value3 = TEAM_NAME[p.winner], string.format("%d", Timers.Round10(p.A)), string.format("%d", Timers.Round10(p.H))
  return a
end
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
  local scoring = rules.scoring or {}
  Timers.UpdateNodePhases(now)
  -- Predictable: score grows with bases held (not reinforcements, not
  -- flag captures).
  local sc = scoring.predict and Timers.Scores(now) or nil
  local info
  if sc then
    local cA, cH = Timers.TeamColor("A"), Timers.TeamColor("H")
    local a = args.info
    a.value1, a.sc_A_s, a.value3 = Timers.Hex(cA), string.format("%d", sc.A.s), Timers.Hex(cH)
    a.sc_H_s, a.value5, a.value6 = string.format("%d", sc.H.s), ns.Theme.Hex("textMuted"), tostring(sc.max or "?")
    info = ns.Locale:Format("battlegrounds.objectives.value1_sc_a_s_r_value3_sc.03c152", a)
    -- WIN: every capture in progress lands (what happens if nobody stops
    -- it). HELD: the defenders retake them all now (shown if it changes
    -- the winner or the time by more than 5s).
    local q = Timers.Predict(sc, now, true, nil, outQ)
    local held
    if sc.n then
      local any = false
      hn.A, hn.H = sc.n.A, sc.n.H
      for _, nd in pairs(Timers.nodes) do
        if nd.hasGraveyard and nd.assault and nd.owner then
          hn[nd.owner], any = hn[nd.owner] + 1, true
        end
      end
      held = any and Timers.Predict(sc, now, false, hn, outHeld) or nil
    end
    if q then
      local row = pool:Add()
      Timers.Tag(row, "WIN").team = q.winner -- the overview reads kind/team, not the translated text
      row.color, row.frac, row.time = Timers.TeamColor(q.winner), sc[q.winner].s / sc.max, Timers.Clock(q.at - now)
      row.text = ns.Locale:Format("battlegrounds.objectives.value1_value2_value3.26df03", Score(q))
    end
    if held and (not q or held.winner ~= q.winner or math.abs(held.at - q.at) > 5) then
      local row = pool:Add()
      Timers.Tag(row, "HELD").team = held.winner
      row.color, row.frac, row.time = Timers.TeamColor(held.winner), sc[held.winner].s / sc.max, Timers.Clock(held.at - now)
      row.est = true
      row.text = ns.Locale:Format("battlegrounds.objectives.if_defended_value1_value2_value3.4318ba", Score(held))
    end
    -- How many bases the side that's behind must hold to win instead.
    local ref = q
    local total = scoring.bases or 0
    local word = scoring.noun or "base"
    if ref and sc.n and total > 0 then
      local lose = Timers.Other(ref.winner)
      for k = (sc.n[lose] or 0) + 1, total do
        wipe(nn)
        nn[lose], nn[ref.winner] = k, math.min(sc.n[ref.winner] or 0, total - k)
        local r = Timers.Predict(sc, now, false, nn, outNeed)
        if r and r.winner == lose then
          local row = pool:Add()
          Timers.Tag(row, "NEED")
          row.team, row.count, row.noun = lose, k, word -- the overview's plan
          row.color, row.time = Timers.TeamColor(lose), ""
          local a = args.need
          a.value1, a.k, a.word, a.value4 = TEAM_NAME[lose], string.format("%d", k), word, k > 1 and "s" or ""
          row.text = ns.Locale:Format("battlegrounds.objectives.value1_needs_k_word_value4.34ded4", a)
          break
        end
      end
    end
  end
  -- Enemies clicking a banner right now (their capture cast).
  wipe(clicks)
  for _, e in pairs(ns.enemies or {}) do
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
  local capture = rules.capture or {}
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
    row.color, row.left = ns.Theme.Rgb("white"), ns.flagRespawnAt - now
    row.text = ns.Locale:Get("battlegrounds.objectives.respawn.5a0bd4")
    row.total = Timers.FlagRespawnTime()
  end
  if Timers.AddOverview then Timers.AddOverview(out, now, pool) end
  if Timers.Mechanics then Timers.Mechanics.Append(out, now, pool) end
  return out, info
end

-- The resurrection and objective windows, made on first use (named
-- <prefix>TimersFrame and <prefix>BasesFrame: Highground or the folder).
function Timers.Windows()
  if not Timers.resWin then
    local prefix = ns.FRAME_PREFIX or "Highground"
    Timers.resWin = Timers.MakeWindow(prefix .. "TimersFrame", ns.Locale:Get("battlegrounds.objectives.resurrection.b90edc"), "timersPoint", { "TOP", "TOP", 0, -150 })
    Timers.objWin = Timers.MakeWindow(prefix .. "BasesFrame", ns.Locale:Get("battlegrounds.objectives.objectives.e64e22"), "basesPoint",
      { "TOP", "TOP", Timers.THEME.timers.spacing, -150 })
  end
  return Timers.resWin, Timers.objWin
end

function Timers.UpdateWindow(now)
  local resWin, objWin = Timers.Windows()
  Timers.ShowRows(resWin, Timers.Rows(now))
  local db = Timers.DB()
  local rows, info = Timers.ObjectiveRows(now)
  if db and ns.Core.On("objectives") and #rows > 0 then
    Timers.ShowRows(objWin, rows, info)
  else
    objWin:Hide()
  end
end
function Timers.HideWindows()
  -- Other plain HUD windows, such as quick callouts, own their visibility.
  if Timers.resWin then Timers.resWin:Hide() end
  if Timers.objWin then Timers.objWin:Hide() end
end
ns.Test = ns.Test or {}
ns.Test.timersRows = Timers.Rows
ns.Test.objectiveRows = Timers.ObjectiveRows
ns.Test.predict = function(now)
  local sc = Timers.Scores(now)
  return sc, Timers.Predict(sc, now, false), Timers.Predict(sc, now, true)
end
