local _, ns = ...
local Timers, Theme, Hud, Motion = ns.Timers, ns.Theme, ns.Hud, ns.Motion

---------------------------------------------------------------------------
-- Win forecast, in base battlegrounds whose rules predict: who wins and
-- when if the score continues and captures in progress land, the bases the
-- trailing team must hold to win instead, and the result if the contested
-- bases are defended (only when that changes the winner or the time by more
-- than 5s). Hidden where nothing can be predicted (flag maps, epics).
---------------------------------------------------------------------------
local TEAM_NAME = ns.Localization.Define({}, { A = "shared.copy.alliance.a21193", H = "shared.copy.horde.cf9229" })
local hn, nn, outQ, outHeld, outNeed = {}, {}, {}, {}, {}
local model, NONE = {}, {}
-- Format arguments, refilled on every refresh (a language change shows on
-- the next one).
local args = { info = {}, wins = {}, held = {}, need = {}, chat = {} }

-- The panel's model (one reused table), or nil when nothing is predicted:
-- winner, left, frac (winner's score / max), A, H, max, need + needTeam +
-- noun, heldWinner + heldLeft.
function Timers.Forecast(now)
  local scoring = Timers.Rules().scoring or NONE
  local sc = scoring.predict and Timers.Scores(now)
  local q = sc and Timers.Predict(sc, now, true, nil, outQ)
  if not q then return nil end
  local m = model
  m.winner, m.left, m.frac = q.winner, q.at - now, sc[q.winner].s / sc.max
  m.A, m.H, m.max = sc.A.s, sc.H.s, sc.max
  m.need, m.needTeam, m.noun, m.heldWinner, m.heldLeft = nil, nil, nil, nil, nil
  if not sc.n then return m end
  -- Defended: the defenders retake every contested base now.
  local any = false
  hn.A, hn.H = sc.n.A, sc.n.H
  for _, nd in pairs(Timers.nodes) do
    if nd.hasGraveyard and nd.assault and nd.owner then hn[nd.owner], any = hn[nd.owner] + 1, true end
  end
  local held = any and Timers.Predict(sc, now, false, hn, outHeld)
  if held and (held.winner ~= q.winner or math.abs(held.at - q.at) > 5) then
    m.heldWinner, m.heldLeft = held.winner, held.at - now
  end
  -- The fewest bases the trailing team must hold to win instead.
  local total, lose = scoring.bases or 0, Timers.Other(q.winner)
  for k = (sc.n[lose] or 0) + 1, total do
    wipe(nn)
    nn[lose], nn[q.winner] = k, math.min(sc.n[q.winner] or 0, total - k)
    local r = Timers.Predict(sc, now, false, nn, outNeed)
    if r and r.winner == lose then
      m.need, m.needTeam, m.noun = k, lose, scoring.noun or "base"
      break
    end
  end
  return m
end

-- The three lines' text, also used by the tooltip.
local function WinsText(m)
  args.wins.team = TEAM_NAME[m.winner]
  return ns.Locale:Format("battlegrounds.forecast.team_wins.494649", args.wins)
end
local function NeedText(m)
  if not m.need then return "" end
  local a = args.need
  a.value1, a.k, a.word, a.value4 = TEAM_NAME[m.needTeam], string.format("%d", m.need), m.noun, m.need > 1 and "s" or ""
  return ns.Locale:Format("battlegrounds.objectives.value1_needs_k_word_value4.34ded4", a)
end
local function HeldText(m)
  if m.heldWinner == m.winner then return ns.Locale:Get("battlegrounds.forecast.if_defended.0f21c1") end
  args.held.team = TEAM_NAME[m.heldWinner]
  return ns.Locale:Format("battlegrounds.forecast.if_defended_team_wins.9af8aa", args.held)
end
local function Info(m)
  local a = args.info
  a.value1, a.sc_A_s, a.value3 = Timers.Hex(Timers.TeamColor("A")), string.format("%d", m.A), Timers.Hex(Timers.TeamColor("H"))
  a.sc_H_s, a.value5, a.value6 = string.format("%d", m.H), Theme.Hex("textMuted"), tostring(m.max or "?")
  return ns.Locale:Format("battlegrounds.objectives.value1_sc_a_s_r_value3_sc.03c152", a)
end

-- One chat line for shift-click (Timers.Share): the forecast, then the
-- bases needed and the defended result when the panel shows them. Everyone
-- sees the score already.
local function ChatText(m)
  local a = args.chat
  a.team, a.time = TEAM_NAME[m.winner], Timers.Clock(m.left)
  local text = ns.Locale:Format("battlegrounds.share.forecast", a)
  if m.need then text = text .. " · " .. NeedText(m) end
  if m.heldWinner then
    a.team, a.time = TEAM_NAME[m.heldWinner], Timers.Clock(m.heldLeft)
    text = text .. " · " .. ns.Locale:Format("battlegrounds.share.held", a)
  end
  return text
end

local function ShowTip(b)
  local m = b.data
  if not m then return end
  GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
  Timers.TipLine(GameTooltip, WinsText(m) .. "  " .. Timers.Clock(m.left), "white")
  Timers.TipLine(GameTooltip, ns.Locale:Get("shared.windows.projected_win_if_current_captures_complete.f1bd30"), "info")
  if m.need then
    Timers.TipLine(GameTooltip, NeedText(m), "white")
    Timers.TipLine(GameTooltip, ns.Locale:Get("shared.windows.bases_required_for_the_trailing_team_to.4074ab"), "info")
  end
  if m.heldWinner then
    Timers.TipLine(GameTooltip, HeldText(m) .. "  " .. Timers.Clock(m.heldLeft), "white")
    Timers.TipLine(GameTooltip, ns.Locale:Get("shared.windows.projection_if_contested_bases_are_defended.bdf5c7"), "info")
  end
  Timers.TipLine(GameTooltip, ns.Locale:Get("shared.windows.share_hint"), "textMuted")
  GameTooltip:Show()
end

-- Normal: crest, "Horde wins" over the NEED line, clock on the right, like a
-- timer row. Compact: one line each. "If defended" adds a line below; the
-- winner's progress is the underline.
local function Layout(w)
  local b, compact = w.block, Timers.Compact()
  local h, inset, x = Timers.ROW_H, compact and 5 or 7, compact and 20 or 33
  local line = compact and 13 or 16
  local needLine = compact and b.hasNeed and line or 0
  b:ClearAllPoints()
  b:SetPoint("TOPLEFT", Timers.WIN_PAD, -Timers.TOP)
  b:SetPoint("RIGHT", -Timers.WIN_PAD, 0)
  local height = h + needLine + (b.hasHeld and line or 0)
  b:SetHeight(height)
  for _, part in ipairs(b.parts) do part:ClearAllPoints() end
  b.crest:SetSize(compact and 12 or 20, compact and 12 or 20)
  b.crest:SetPoint("LEFT", b, "TOPLEFT", inset, -h / 2)
  Timers.Font(b.time, compact and "timerSmall" or "timer")
  b.time:SetPoint("RIGHT", b, "TOPRIGHT", -inset, -h / 2 + (compact and 0 or 1))
  Timers.Font(b.winner, compact and "detail" or "rowNameSmall")
  Timers.Font(b.need, "caption")
  Timers.Font(b.held, "caption")
  Timers.Font(b.heldTime, compact and "caption" or "timerSmall")
  if compact then
    b.winner:SetPoint("LEFT", b, "TOPLEFT", x, -h / 2)
    b.need:SetPoint("LEFT", b, "TOPLEFT", x, -h - line / 2)
  else
    b.winner:SetPoint("TOPLEFT", x, -3)
    b.need:SetPoint("BOTTOMLEFT", b, "TOPLEFT", x, -h + 5)
  end
  b.winner:SetPoint("RIGHT", b.time, "LEFT", -4, 0)
  b.need:SetPoint("RIGHT", b, "RIGHT", -inset, 0)
  b.heldTime:SetPoint("RIGHT", b, "TOPRIGHT", -inset, -h - needLine - line / 2)
  b.held:SetPoint("LEFT", b, "TOPLEFT", x, -h - needLine - line / 2)
  b.held:SetPoint("RIGHT", b.heldTime, "LEFT", -4, 0)
  w:SetHeight(Timers.TOP + height + Timers.WIN_PAD)
end

-- The panel, made on first use (<prefix>ForecastFrame), left of the
-- resurrection panel and docked under it in the compact layout.
function Timers.ForecastWindow()
  if Timers.foreWin then return Timers.foreWin end
  local w = Timers.MakeWindow((ns.FRAME_PREFIX or "Highground") .. "ForecastFrame", ns.Locale:Get("battlegrounds.forecast.forecast.1c77ff"),
    "forecastPoint", { "TOP", "TOP", -Timers.THEME.timers.spacing, -150 })
  ns.Localization.Bind(w.title, "battlegrounds.forecast.forecast.1c77ff")
  local b = CreateFrame("Frame", nil, w)
  Hud.Surface(b, "BACKGROUND"):SetAllPoints()
  b.edge = ns.Kit.Outline(b, "border")
  b.crest = b:CreateTexture(nil, "ARTWORK")
  b.winner, b.time = Theme.Text(b, "rowNameSmall"), Theme.Text(b, "timer", "text")
  b.need, b.held, b.heldTime = Theme.Text(b, "caption"), Theme.Text(b, "caption", "textMuted"), Theme.Text(b, "timerSmall", "textMuted")
  for _, text in ipairs({ b.winner, b.need, b.held }) do text:SetJustifyH("LEFT"); text:SetWordWrap(false) end
  b.time:SetJustifyH("RIGHT"); b.heldTime:SetJustifyH("RIGHT")
  b.parts = { b.crest, b.winner, b.time, b.need, b.held, b.heldTime }
  b.bar = CreateFrame("StatusBar", nil, b)
  b.bar:SetPoint("BOTTOMLEFT"); b.bar:SetPoint("BOTTOMRIGHT")
  b.bar:SetHeight(Theme.Size("underline"))
  ns.Core.StatusBar(b.bar)
  b.bar:SetMinMaxValues(0, 1)
  Theme.Fill(b.bar, "BACKGROUND", "overlaySubtle"):SetAllPoints()
  b:EnableMouse(true)
  b:SetScript("OnEnter", ShowTip)
  b:SetScript("OnLeave", GameTooltip_Hide)
  b:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" and IsShiftKeyDown() and self.data then Timers.Share(ChatText(self.data)) end
  end)
  w.block = b
  w.relayout = function() Layout(w) end
  Layout(w)
  Timers.foreWin = w
  return w
end

-- Draws a model (live, or the preview's sample) and shows the panel.
function Timers.ShowForecast(m)
  local w = Timers.ForecastWindow()
  local b, opening = w.block, not w:IsShown()
  b.data = m
  Timers.FactionIcon(b.crest, m.winner)
  local color = Timers.TeamColor(m.winner)
  b.winner:SetText(WinsText(m))
  Theme.Paint(b.winner, color)
  local clock = Timers.Clock(m.left)
  if b.timeText ~= clock then b.timeText = clock; b.time:SetText(clock) end -- changes once a second
  b.bar:SetValue(math.max(0, math.min(1, m.frac or 0)))
  Timers.BarColor(b.bar, color, 0.85)
  b.need:SetText(NeedText(m))
  Theme.Paint(b.need, m.needTeam and Timers.TeamColor(m.needTeam) or "textMuted")
  b.held:SetText(m.heldWinner and HeldText(m) or "")
  b.heldTime:SetText(m.heldWinner and Timers.Clock(m.heldLeft) or "")
  if (m.need ~= nil) ~= b.hasNeed or (m.heldWinner ~= nil) ~= b.hasHeld then
    b.hasNeed, b.hasHeld = m.need ~= nil, m.heldWinner ~= nil
    Layout(w)
  end
  Hud.SetInfo(w, Info(m))
  if not InCombatLockdown() and w:GetScale() ~= Timers.WinScale(w) then w:SetScale(Timers.WinScale(w)) end
  w:Show()
  if opening then Motion.Reveal(w) end
  if w.docks and ns.Dock then ns.Dock() end
  if GameTooltip:IsShown() and GameTooltip:GetOwner() == b then ShowTip(b) end
end
