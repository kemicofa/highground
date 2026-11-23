local _, ns = ...
local Timers = ns.Timers

---------------------------------------------------------------------------
-- Bases window: captures in progress + who wins, and when.
-- Like Capping's bars and score predictor, plus:
--   * the max score is read from the scoreboard (not assumed 1600), as
--     "Bases: 3  Resources: 1210/1600" text or a modern double score bar
--   * points per second for each base count are measured live (and saved
--     per battleground), seeded with Arathi Basin's known table
--   * "IF" = the result if every capture in progress lands
--   * "NEED" = how many bases the losing side must hold to turn it
---------------------------------------------------------------------------

do
  local SCORE_WIDGETS = { { 1893, 1894 }, { 3116, 3117 } } -- Alliance, Horde (AB; EotS / Gilneas)
  local function WidgetText(id)
    local W = C_UIWidgetManager
    local f = W and W.GetIconAndTextWidgetVisualizationInfo
    if not f then
      return nil
    end
    local ok, info = pcall(f, id)
    local t = ok and type(info) == "table" and info.text
    if Timers.plain(t) and type(t) == "string" and t ~= "" then
      return (t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
    end
  end
  -- "Bases: 3  Resources: 1210/1600" -> 1210, 1600, 3 ; "1210/1600" -> 1210, 1600
  local function Parse(text)
    if not text then
      return nil
    end
    local b, s, m = text:match("(%d+)[^%d/]+(%d+)%s*/%s*(%d+)")
    if not b then
      s, m = text:match("(%d+)%s*/%s*(%d+)")
    end
    if s then
      return tonumber(s), tonumber(m), tonumber(b)
    end
  end
  -- Modern scoreboards (retail, and WoW Forever's client): one double
  -- status bar, Alliance left and Horde right, out of leftBarMax. It has no
  -- base counts; the map's bases give those. 1671 on most maps.
  local BAR_WIDGETS = { 1671, 2074, 5153, 1689 }
  local function Number(v) return Timers.plain(v) and type(v) == "number" and v or nil end
  local function Bar(id)
    local W = C_UIWidgetManager
    local f = W and W.GetDoubleStatusBarWidgetVisualizationInfo
    if not f then return nil end
    local ok, info = pcall(f, id)
    if not (ok and type(info) == "table") then return nil end
    local a, h, m = Number(info.leftBarValue), Number(info.rightBarValue), Number(info.leftBarMax)
    if a and h and m and m > 0 then return a, h, m end
  end
  -- One reused reading: Scores runs four times a second while the
  -- objectives window is open; callers use it before the next refresh.
  local reading, counts = { A = {}, H = {} }, {}
  local function Fill(side, s, m, b) side.s, side.m, side.b = s, m, b; return side end
  local function FillBar(a, h, m)
    reading.A, reading.H = Fill(reading.A, a, m, nil), Fill(reading.H, h, m, nil)
    return reading
  end
  local function Read()
    for _, pair in ipairs(SCORE_WIDGETS) do
      local as, am, ab = Parse(WidgetText(pair[1]))
      local hs, hm, hb = Parse(WidgetText(pair[2]))
      if as and hs then
        reading.A, reading.H = Fill(reading.A, as, am, ab), Fill(reading.H, hs, hm, hb)
        return reading
      end
    end
    for _, id in ipairs(BAR_WIDGETS) do
      local a, h, m = Bar(id)
      if a then return FillBar(a, h, m) end
    end
    -- Any other scoreboard: a score bar at the top of the screen, else the
    -- first two "x/y" widgets there.
    local W = C_UIWidgetManager
    if W and W.GetTopCenterWidgetSetID and W.GetAllWidgetsBySetID then
      local okS, set = pcall(W.GetTopCenterWidgetSetID)
      local okL, list = pcall(W.GetAllWidgetsBySetID, okS and set or 0)
      list = okL and type(list) == "table" and list or {}
      for _, wi in ipairs(list) do
        local a, h, m = Bar(wi.widgetID)
        if a then return FillBar(a, h, m) end
      end
      local found = {}
      for _, wi in ipairs(list) do
        local s, m, b = Parse(WidgetText(wi.widgetID))
        if s then
          found[#found + 1] = { id = wi.widgetID, s = s, m = m, b = b }
        end
      end
      table.sort(found, function(x, y)
        return x.id < y.id
      end)
      if #found >= 2 then
        reading.A, reading.H = found[1], found[2]
        return reading
      end
    end
  end

  -- Bases scoring right now: map nodes owned and not under assault (an
  -- assaulted base scores for nobody) when the map knows who owns them,
  -- else the scoreboard's count.
  local function Bases(sc)
    local cA, cH, known = 0, 0, 0
    for _, nd in pairs(Timers.nodes) do
      -- The configured scoring maps attach a graveyard to each resource
      -- base. Other POIs (notably the central flag) do not generate income.
      if nd.hasGraveyard and (nd.owner or nd.assault) then
        known = known + 1
      end
      if nd.hasGraveyard and not nd.assault then
        if nd.owner == "A" then
          cA = cA + 1
        elseif nd.owner == "H" then
          cH = cH + 1
        end
      end
    end
    local wA, wH = sc.A.b, sc.H.b
    local n = counts
    if wA and wH and known < wA + wH then
      n.A, n.H = wA, wH
      return n
    end
    if known > 0 or not (wA and wH) then
      if known == 0 then return nil end
      n.A, n.H = cA, cH
      return n
    end
    n.A, n.H = wA, wH
    return n
  end

  local function Learned()
    local db, key = Timers.LearnedDB(), Timers.RulesKey()
    local scoring = Timers.Rules().scoring
    if not (db and key and scoring) then
      return nil
    end
    db.rates = db.rates or {}
    db.rates[key] = db.rates[key] or {}
    return db.rates[key], scoring.seedRates
  end

  local function Rate(n)
    if n == 0 then
      return 0
    end
    local learned, seed = Learned()
    local r = (learned and learned[n]) or (seed and seed[n])
    if r then
      return r
    end
    -- unknown count: scale the nearest known one
    local bestK, bestR
    for _, t in ipairs({ learned or {}, seed or {} }) do
      for k, v in pairs(t) do
        if k > 0 and v > 0 and (not bestK or math.abs(k - n) < math.abs(bestK - n)) then
          bestK, bestR = k, v
        end
      end
    end
    return bestR and bestR * n / bestK or nil
  end

  -- Watch score ticks: steady ticks at an unchanged base count -> rate,
  -- measured from one tick to a later one (whole ticks only).
  local function Track(team, s, n, now)
    local tr = Timers.track[team]
    if not tr or tr.n ~= n or s < tr.s1 or s - tr.s1 > 60 then
      Timers.track[team] = { n = n, s1 = s, ticks = 0 }
      return
    end
    if s ~= tr.s1 then
      tr.ticks = tr.ticks + 1
      tr.t1, tr.s1 = now, s
      if tr.ticks == 1 then
        tr.t0, tr.s0 = now, s
      elseif tr.ticks >= 3 and n and n > 0 and tr.t1 > tr.t0 then
        local r = (tr.s1 - tr.s0) / (tr.t1 - tr.t0)
        local learned = Learned()
        if learned then
          learned[n] = learned[n] and (learned[n] * 0.7 + r * 0.3) or r
        end
      end
    end
  end

  function Timers.Scores(now)
    Timers.UpdateNodePhases(now)
    local scoring = Timers.Rules().scoring
    if not (scoring and scoring.predict) then return nil end
    local sc = Read()
    if not sc then return nil end
    sc.n = Bases(sc)
    sc.max = sc.A.m or sc.H.m
    if sc.n then
      Track("A", sc.A.s, sc.n.A, now)
      Track("H", sc.H.s, sc.n.H, now)
    end
    return sc
  end

  -- Who reaches max first. withCaps: captures in progress land at their
  -- timers. nOverride: what-if base counts. out: a table to fill (else a new
  -- one). -> { winner, at, A, H } or nil. The scratch below is reused.
  local s, n, events, stored = {}, {}, {}, {}
  local function ByTime(a, b) return a.t < b.t end
  function Timers.Predict(sc, now, withCaps, nOverride, out)
    if not (sc and sc.max and (sc.n or nOverride)) then
      return nil
    end
    s.A, s.H = sc.A.s, sc.H.s
    local base = nOverride or sc.n
    n.A, n.H = base.A, base.H
    wipe(events)
    if withCaps then
      for _, nd in pairs(Timers.nodes) do
        if nd.hasGraveyard and nd.assault and nd.capEnd and nd.capEnd > now then
          local e = stored[#events + 1] or {}
          stored[#events + 1] = e
          e.t, e.to = nd.capEnd, nd.assault
          events[#events + 1] = e
        end
      end
      table.sort(events, ByTime)
    end
    local t = now
    for i = 1, #events + 1 do
      local e = events[i]
      local te = e and e.t or math.huge
      local ra, rh = Rate(n.A), Rate(n.H)
      if not (ra and rh) then
        return nil
      end
      local ta = ra > 0 and (sc.max - s.A) / ra or math.huge
      local th = rh > 0 and (sc.max - s.H) / rh or math.huge
      local tw = math.min(ta, th)
      if t + tw <= te then
        -- Nobody scores, or both reach the limit together: no winner to name.
        if tw == math.huge or ta == th then
          return nil
        end
        out = out or {}
        out.winner, out.at = ta <= th and "A" or "H", t + tw
        out.A = math.min(sc.max, s.A + ra * tw)
        out.H = math.min(sc.max, s.H + rh * tw)
        return out
      end
      local dt = te - t
      s.A, s.H, t = s.A + ra * dt, s.H + rh * dt, te
      n[e.to] = n[e.to] + 1
    end
  end
end
