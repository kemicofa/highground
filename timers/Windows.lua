local _, ns = ...
local Timers = ns.Timers
local Core, Theme = ns.Core, ns.Theme

---------------------------------------------------------------------------
-- Small windows (res timers, bases): movable, position saved per window and character
-- (drag; /wb lock locks them with the main panel; /wb timers reset puts
-- them back). Rows: location and state, a readable clock and progress line.
---------------------------------------------------------------------------
Timers.THEME = ns.UIConfig
Timers.WIN_W, Timers.ROW_H, Timers.TOP = Timers.THEME.timers.width, Timers.THEME.timers.row, Timers.THEME.timers.header
Timers.WIN_PAD, Timers.WIN_GAP = Timers.THEME.timers.padding, Timers.THEME.timers.gap
Timers.windows, Timers.timerWindows = {}, {}

function Timers.Positions()
  return ns.GetPositions and ns.GetPositions()
end

-- UI scale times the window's own Appearance scale.
local PANEL = { timersPoint = "timers", basesPoint = "timers", flagsPoint = "flags", arenaPoint = "arena" }
function Timers.WinScale(w)
  local db = Timers.DB()
  local base = db and db.scale or Timers.THEME.scale.default
  return base * (ns.PanelScale and ns.PanelScale(PANEL[w.key] or "timers") or 1)
end

function Timers.PlaceWin(w)
  local pos = Timers.Positions()
  if ns.DockHead and ns.DockHead() and w.docks then
    -- Compact: docked windows hang under the column (ui/Compact.lua).
    w:SetScale(Timers.WinScale(w))
    w.dockedTo = nil
    ns.Dock()
    return
  end
  w:ClearAllPoints()
  local p = pos and pos[w.key]
  if p then
    w:SetPoint(p[1], UIParent, p[2], p[3], p[4])
  else
    w:SetPoint(w.def[1], UIParent, w.def[2], w.def[3], w.def[4])
  end
  w:SetScale(Timers.WinScale(w))
end

function ns.TimersApplyScale()
  if InCombatLockdown() then return end
  for _, w in ipairs(Timers.windows) do
    w:SetScale(Timers.WinScale(w))
  end
end

function ns.TimersWindowReset()
  local pos = Timers.Positions()
  for _, w in ipairs(Timers.windows) do
    if pos then
      pos[w.key] = nil
    end
    if not (w.secure and InCombatLockdown()) then Timers.PlaceWin(w) end
  end
end

-- Secure windows cannot be hidden or shown in combat. SecureHide fades
-- them out instead; SecureShow places and shows them once out of combat
-- (owners re-run their update on PLAYER_REGEN_ENABLED). SecureShow returns
-- true when it showed the window.
function Timers.SecureHide(w)
  if not (w and w:IsShown()) then return end
  if InCombatLockdown() then w:SetAlpha(0) else w:Hide() end
end

function Timers.SecureShow(w)
  if w:IsShown() or InCombatLockdown() then return false end
  Timers.PlaceWin(w)
  w:Show()
  return true
end

-- Window chrome comes from the UI kit (ui/kit/Dialog.lua).
function Timers.MakeWindow(name, title, key, def, secure)
  return ns.Kit and ns.Kit.HudWindow(name, title, key, def, secure)
end

-- Text helpers. font: a type role, or { face, size } where no role fits.
function Timers.Font(fs, font)
  if type(font) == "string" then Theme.SetRole(fs, font) else Core.SetFace(fs, font[1], font[2]) end
end

function Timers.Label(parent, font, color)
  if type(font) == "string" then return Theme.Text(parent, font, color) end
  return Theme.Paint(Core.Text(parent, font[1], font[2]), color or "text")
end

-- Row background: the surface colour, following Background opacity.
function Timers.Surface(parent, layer)
  return Theme.Paint(Core.Surface(parent, layer), "surface")
end

-- Text in a class colour (game data, not themed), else the text token.
function Timers.PaintClass(fs, cc)
  if cc then
    Theme.Unpaint(fs)
    fs:SetTextColor(cc.r, cc.g, cc.b)
  else
    Theme.Paint(fs, "text")
  end
end

-- Health fill alpha of the carrier and arena rows: health known, not.
Timers.BAR_SEEN, Timers.BAR_UNSEEN = 0.4, 0.08

-- Status bar colour: a token name, a live token table, { r, g, b } or a
-- class colour { r =, g =, b = }. Repainted on a theme switch.
local bars = setmetatable({}, { __mode = "k" })
local function BarRGB(c)
  if type(c) == "string" then c = Theme.Rgb(c) end
  if c.r then return c.r, c.g, c.b end
  return c[1], c[2], c[3]
end
function Timers.BarColor(bar, color, alpha)
  bars[bar] = true
  bar.wbBarColor, bar.wbBarAlpha = color, alpha
  local r, g, b = BarRGB(color)
  bar:SetStatusBarColor(r, g, b, alpha)
end
Theme.OnChange(function()
  for bar in pairs(bars) do
    local r, g, b = BarRGB(bar.wbBarColor)
    bar:SetStatusBarColor(r, g, b, bar.wbBarAlpha)
  end
end)

local function Compact()
  return Core.compact or false
end
Timers.Compact = Compact

-- Header, width and rows for the current layout (normal or compact).
function Timers.LayoutWindow(w)
  local compact = Compact()
  w:SetWidth(Timers.WIN_W)
  w.head:SetHeight(Timers.TOP - (compact and 1 or 4))
  w.brand:SetSize(3, compact and 8 or 12)
  w.brand:ClearAllPoints()
  w.brand:SetPoint("TOPLEFT", Timers.WIN_PAD, compact and -4 or -7)
  Timers.Font(w.title, compact and { "bold", 10 } or "heading")
  Timers.Font(w.info, compact and "caption" or "label")
  w.info:ClearAllPoints()
  w.info:SetPoint("TOPRIGHT", -Timers.WIN_PAD, compact and -4 or -9)
  w.info:SetWidth(Timers.WIN_W - (compact and 100 or 128))
  for i, r in ipairs(w.rows) do Timers.LayoutRow(w, r, i) end
  if w.relayout then w.relayout() end
end

-- Normal: place over tag, clock on the right. Compact: one line.
function Timers.LayoutRow(w, r, i)
  local compact = Compact()
  r:ClearAllPoints()
  r:SetPoint("TOPLEFT", Timers.WIN_PAD, -Timers.TOP - (i - 1) * (Timers.ROW_H + Timers.WIN_GAP))
  r:SetPoint("RIGHT", -Timers.WIN_PAD, 0)
  r:SetHeight(Timers.ROW_H)
  r.tag:ClearAllPoints()
  r.time:ClearAllPoints()
  r.place:ClearAllPoints()
  if compact then
    Timers.Font(r.tag, "caption")
    r.tag:SetPoint("LEFT", 5, 0)
    r.tag:SetWidth(44)
    Timers.Font(r.time, { "mono", 11 })
    r.time:SetPoint("RIGHT", -5, 0)
    r.time:SetWidth(50)
    Timers.Font(r.place, { "semi", 11 })
    r.place:SetPoint("LEFT", r.tag, "RIGHT", 2, 0)
  else
    Timers.Font(r.tag, "label")
    r.tag:SetPoint("BOTTOMLEFT", 7, 5)
    r.tag:SetWidth(76)
    Timers.Font(r.time, { "mono", 16 })
    r.time:SetPoint("RIGHT", -7, 1)
    r.time:SetWidth(65)
    Timers.Font(r.place, { "semi", 14 })
    r.place:SetPoint("TOPLEFT", 7, -3)
  end
  r.place:SetPoint("RIGHT", r.time, "LEFT", -4, 0)
end

function Timers.RowFrame(w, i)
  local r = w.rows[i]
  if r then
    return r
  end
  r = CreateFrame("Frame", nil, w)
  Timers.Surface(r, "BACKGROUND"):SetAllPoints()
  r.tag = Timers.Label(r, "label")
  r.tag:SetJustifyH("LEFT")
  r.bar = CreateFrame("StatusBar", nil, r)
  r.bar:SetPoint("BOTTOMLEFT")
  r.bar:SetPoint("BOTTOMRIGHT")
  r.bar:SetHeight(Theme.Size("underline"))
  Core.StatusBar(r.bar)
  r.bar:SetMinMaxValues(0, 1)
  Theme.Fill(r.bar, "BACKGROUND", "overlaySubtle"):SetAllPoints()
  r.time = Timers.Label(r, { "mono", 16 })
  r.time:SetJustifyH("RIGHT")
  r.place = Timers.Label(r, { "semi", 14 })
  r.place:SetJustifyH("LEFT")
  Timers.LayoutRow(w, r, i)
  r:EnableMouse(true)
  r.ShowTip = function(self)
    local row = self.data
    if not row then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    Timers.TipLine(GameTooltip, row.text or "", "white")
    local meanings = { YOU = "Your resurrection destination", OURS = "Friendly graveyard",
      THEIRS = "Enemy graveyard", DIE = "Your next resurrection wave is close",
      CAP = "Capture in progress", LOCK = "Timed node ownership", RESET = "Node resetting",
      WIN = "Projected win if current captures complete", HELD = "Projection if contested bases are defended",
      NEED = "Bases required for the trailing team to win", FLAG = "Flag respawn countdown",
      RES = "Awaiting graveyard observations" }
    if meanings[row.tag] then Timers.TipLine(GameTooltip, meanings[row.tag], "info") end
    if row.left then
      Timers.TipLine(GameTooltip, (row.est and "Estimated: " or "Remaining: ") .. Timers.Clock(row.left), "text")
    elseif not row.time and not row.frac then
      Timers.TipLine(GameTooltip, "Countdown not observed yet", "textMuted")
    end
    GameTooltip:Show()
  end
  r:SetScript("OnEnter", r.ShowTip)
  r:SetScript("OnLeave", GameTooltip_Hide)
  w.rows[i] = r
  return r
end

local BAR_LIVE, BAR_EST = 0.85, 0.45 -- progress line alpha: observed, estimated

-- row = { tag, color, text, left + total (bar fills as it runs out) |
--         frac (bar as given), time (text, else from left), est, die }
function Timers.ShowRows(w, rows, info)
  for i, row in ipairs(rows) do
    local r, c = Timers.RowFrame(w, i), row.color
    r.data = row
    r.tag:SetText(row.tag)
    Theme.Paint(r.tag, c)
    local frac = row.frac
    if not frac and row.left then
      frac = math.max(0, math.min(1, 1 - row.left / math.max(row.total or 1, 1)))
    end
    r.bar:SetValue(frac or 0)
    Timers.BarColor(r.bar, c, row.est and BAR_EST or BAR_LIVE)
    r.time:SetText(row.time or (row.left and ((row.est and "~" or "") .. Timers.Clock(row.left))) or "--")
    local urgent = row.die or (row.left and row.left > 0 and row.left <= 5)
    Theme.Paint(r.time, urgent and "warning" or (not row.left and not row.time and "textMuted") or "text")
    r.place:SetText(row.text or "")
    r:Show()
    -- An open tooltip follows the live countdown.
    if GameTooltip:IsShown() and GameTooltip:GetOwner() == r then r.ShowTip(r) end
  end
  for i = #rows + 1, #w.rows do
    w.rows[i]:Hide()
  end
  w.info:SetText(info or "")
  w:SetHeight(Timers.TOP + #rows * (Timers.ROW_H + Timers.WIN_GAP) - Timers.WIN_GAP + Timers.WIN_PAD)
  if not InCombatLockdown() and w:GetScale() ~= Timers.WinScale(w) then
    w:SetScale(Timers.WinScale(w))
  end
  w:Show()
  if w.docks and ns.Dock then ns.Dock() end
end
