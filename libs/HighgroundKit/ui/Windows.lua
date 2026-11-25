local _, ns = ...
ns.Timers = ns.Timers or {}
local Timers = ns.Timers
local Core, Theme, Hud, Motion = ns.Core, ns.Theme, ns.Hud, ns.Motion
local S = Theme.Space

---------------------------------------------------------------------------
-- HUD windows (res timers, bases, forecast, flags, arena, nearby): movable, position
-- saved per window and character (drag; /hg lock locks them with the main
-- panel; /hg timers reset puts them back). Timer rows: location and state,
-- a readable clock and progress line.
---------------------------------------------------------------------------
Timers.THEME = ns.UIConfig
Timers.WIN_W, Timers.ROW_H, Timers.TOP = Timers.THEME.timers.width, Timers.THEME.timers.row, Timers.THEME.timers.header
Timers.WIN_PAD, Timers.WIN_GAP = Timers.THEME.timers.padding, Timers.THEME.timers.gap
Timers.windows, Timers.timerWindows = {}, {}

-- Saved settings and positions (ns.GetDB / ns.GetPositions: Highground's
-- core, or standalone/Core.lua).
function Timers.DB()
  return ns.GetDB and ns.GetDB()
end

local ROUND = { round = true }
function Timers.Clock(sec)
  return ns.Util.Clock(sec, ROUND)
end

function Timers.Positions()
  return ns.GetPositions and ns.GetPositions()
end

-- A saved { point, relativePoint, x, y }, else nil: the kit's dialog check.
-- Entries damaged by an older version or an edited saved file fall back to
-- the default spot.
Timers.ValidPoint = ns.Kit.ValidPoint

-- UI scale times the window's own Appearance scale.
local PANEL = { timersPoint = "timers", basesPoint = "timers", forecastPoint = "timers", flagsPoint = "flags", arenaPoint = "arena", nearbyPoint = "nearby" }
function Timers.WinScale(w)
  local db = Timers.DB()
  local base = db and db.scale or Timers.THEME.scale.default
  return base * (ns.PanelScale and ns.PanelScale(PANEL[w.key] or "timers") or 1)
end

-- Non-docked addons own their geometry when hosted by Highground. Standalone
-- hosts without the HUD style module retain their existing dimensions.
function Timers.Geometry(w)
  local owner = PANEL[w.key]
  if Core.PanelGeometry and (owner == "arena" or owner == "nearby") then return Core.PanelGeometry(owner) end
  return Timers.WIN_W, Timers.TOP, Timers.WIN_PAD, Timers.WIN_GAP, Core.compact or false
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
  local p = pos and Timers.ValidPoint(pos[w.key])
  if pos and not p then pos[w.key] = nil end
  p = p or w.def
  w:SetPoint(p[1], UIParent, p[2], p[3], p[4])
  w:SetScale(Timers.WinScale(w))
end

-- Secure windows cannot move in combat. A placement asked for then (a
-- position reset) waits for PLAYER_REGEN_ENABLED; nothing listens otherwise.
local deferred, regen = {}, nil
local function PlaceDeferred()
  if InCombatLockdown() then return end
  regen:UnregisterEvent("PLAYER_REGEN_ENABLED")
  for _, w in ipairs(Timers.windows) do
    if deferred[w] then deferred[w] = nil; Timers.PlaceWin(w) end
  end
  if ns.PanelControls then ns.PanelControls.Refresh() end
end

function Timers.PlaceWhenSafe(w)
  if not (w.secure and InCombatLockdown()) then deferred[w] = nil; Timers.PlaceWin(w); return true end
  if not regen then
    regen = CreateFrame("Frame")
    regen:SetScript("OnEvent", function() ns.Util.RunGuarded("HUD placement", PlaceDeferred) end)
  end
  deferred[w] = true
  regen:RegisterEvent("PLAYER_REGEN_ENABLED")
  return false
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
    Timers.PlaceWhenSafe(w)
  end
end

-- Secure windows cannot be hidden or shown in combat. SecureHide makes
-- them transparent instead; SecureShow places and shows them once out of
-- combat (owners re-run their update on PLAYER_REGEN_ENABLED) with a short
-- entrance; hiding cancels it. A shown window becomes opaque again only if
-- SecureHide made it transparent, so refreshes never cut the entrance short:
-- owners leave alpha to these two. SecureShow returns true when it showed.
function Timers.SecureHide(w)
  if not (w and w:IsShown()) then return end
  Motion.Stop(w)
  if InCombatLockdown() then w.wbSecureHidden = true; w:SetAlpha(0) else w:Hide() end
  ns.PanelControls.Refresh()
end

function Timers.SecureShow(w)
  if w:IsShown() and w.wbSecureHidden then
    w.wbSecureHidden = nil
    Motion.Stop(w, 1)
    ns.PanelControls.Refresh()
  end
  if w:IsShown() or InCombatLockdown() then return false end
  deferred[w] = nil
  Timers.PlaceWin(w)
  w:Show()
  Motion.Reveal(w)
  return true
end

-- Battleground HUD window (resurrection timers, bases, flags, arena,
-- nearby): movable, position saved per character under key (default
-- def = { point, relativePoint, x, y }), docked in the compact layout
-- unless noDock, title and info line in the header. secure: it holds
-- secure buttons, so it doesn't move in combat.
function Timers.MakeWindow(name, title, key, def, secure, noDock)
  local w = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
  w.key, w.def, w.rows, w.secure = key, def, {}, secure
  w.docks = not noDock
  w:SetSize(Timers.WIN_W, Timers.TOP + Timers.ROW_H + S("sm"))
  Theme.Backdrop(w)
  w.inlay = ns.Kit.Inlay(w, true)
  w:SetMovable(true)
  w:SetClampedToScreen(true)
  w:EnableMouse(true)
  w:RegisterForDrag("LeftButton")
  w:SetScript("OnDragStart", function(self)
    local db = Timers.DB()
    if self.docks and ns.DockDrag and ns.DockDrag(self, true) then
      return -- compact: the whole column moves
    end
    if self.secure and InCombatLockdown() then
      return -- holds secure buttons: can't move in combat
    end
    if not (db and db.locked) then self.wbMoving = true; self:StartMoving() end
  end)
  -- Only a drag that moved the window saves it: a locked or refused drag
  -- must not turn the default spot into a saved one.
  w:SetScript("OnDragStop", function(self)
    if self.docks and ns.DockDrag and ns.DockDrag(self, false) then return end
    if not self.wbMoving then return end
    self.wbMoving = nil
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    local pos = Timers.Positions()
    if pos and p then pos[self.key] = { p, rp, x, y } end
  end)
  -- A later opening starts from a clean, opaque state. Hiding UIParent
  -- (Alt-Z, cinematics) must not reveal a window made transparent in combat.
  w:HookScript("OnHide", function(self)
    if not self:IsShown() then self.wbSecureHidden = nil; Motion.Stop(self, 1) end
  end)
  w.head = Core.Surface(w, "BORDER")
  Theme.Paint(w.head, "surface")
  w.head:SetPoint("TOPLEFT", 1, -1)
  w.head:SetPoint("TOPRIGHT", -1, -1)
  w.brand = Theme.Fill(w, "ARTWORK", "accent")
  w.title = Theme.Text(w, "heading", "titleText")
  w.title:SetPoint("LEFT", w.brand, "RIGHT", S("sm"), 0)
  w.title:SetText(title)
  w.info = Theme.Text(w, "label", "textMuted")
  w.info:SetJustifyH("RIGHT")
  Core.Chrome(w.head, w.brand, w.title, w.info)
  ns.PanelControls.Register(w)
  Timers.windows[#Timers.windows + 1] = w
  if not secure then Timers.timerWindows[#Timers.timerWindows + 1] = w end
  Timers.LayoutWindow(w)
  Timers.PlaceWin(w)
  w:Hide()
  return w
end

-- Text helpers: font is a type role.
Timers.Font = Theme.SetRole

-- Legacy row-fill alpha aliases. Carrier and arena health strips use
-- opaque fills; these values continue to follow the current theme.
local function BarAlpha()
  Timers.BAR_SEEN, Timers.BAR_UNSEEN = Theme.Alpha("healthFill"), Theme.Alpha("healthUnseen")
end
BarAlpha()
Theme.OnChange(BarAlpha)

-- Status bar colour: a token name, a live token table (both repainted on a
-- theme switch), { r, g, b } or a class colour { r =, g =, b = }.
function Timers.BarColor(bar, color, alpha)
  Theme.Paint(bar, color, alpha)
end

local function Compact()
  return Core.compact or false
end
Timers.Compact = Compact

-- Header, width and rows for the current layout (normal or compact).
function Timers.LayoutWindow(w)
  local width, top, pad, _, compact = Timers.Geometry(w)
  w:SetWidth(width)
  w.head:SetHeight(top - (compact and 1 or 4))
  w.brand:SetSize(compact and 4 or 6, compact and 4 or 6)
  w.brand:SetRotation(math.pi / 4)
  w.brand:ClearAllPoints()
  w.brand:SetPoint("LEFT", w, "TOPLEFT", pad, -top / 2)
  Timers.Font(w.title, compact and "headingSmall" or "heading")
  Timers.Font(w.info, compact and "caption" or "label")
  ns.PanelControls.Layout(w, top, pad)
  w.info:ClearAllPoints()
  w.info:SetPoint("RIGHT", w.gear, "LEFT", -S("sm"), 0)
  w.infoMax = math.max(40, width - (compact and 100 or 128) - w.gear:GetWidth() - S("sm"))
  w.title:SetPoint("RIGHT", w.info, "LEFT", -S("sm"), 0)
  w.title:SetWordWrap(false)
  w.info:SetWordWrap(false)
  Hud.SetInfo(w, w.info:GetText())
  for i, r in ipairs(w.rows) do Timers.LayoutRow(w, r, i) end
  if w.relayout then w.relayout() end
end

-- Normal: crest, place over tag, clock on the right. Compact: one line.
function Timers.LayoutRow(w, r, i)
  local compact = Compact()
  r:ClearAllPoints()
  r:SetPoint("TOPLEFT", Timers.WIN_PAD, -Timers.TOP - (i - 1) * (Timers.ROW_H + Timers.WIN_GAP))
  r:SetPoint("RIGHT", -Timers.WIN_PAD, 0)
  r:SetHeight(Timers.ROW_H)
  r.faction:ClearAllPoints()
  r.tag:ClearAllPoints()
  r.time:ClearAllPoints()
  r.place:ClearAllPoints()
  if compact then
    r.faction:SetSize(12, 12)
    r.faction:SetPoint("LEFT", 5, 0)
    Timers.Font(r.tag, "caption")
    r.tag:SetPoint("LEFT", r.faction, "RIGHT", 3, 0)
    r.tag:SetWidth(44)
    Timers.Font(r.time, "timerSmall")
    r.time:SetPoint("RIGHT", -5, 0)
    Timers.Font(r.place, "detail")
    r.place:SetPoint("LEFT", r.tag, "RIGHT", 2, 0)
  else
    r.faction:SetSize(20, 20)
    r.faction:SetPoint("LEFT", 7, 0)
    Timers.Font(r.tag, "label")
    r.tag:SetPoint("BOTTOMLEFT", 33, 5)
    r.tag:SetWidth(76)
    Timers.Font(r.time, "timer")
    r.time:SetPoint("RIGHT", -7, 1)
    Timers.Font(r.place, "rowNameSmall")
    r.place:SetPoint("TOPLEFT", 33, -3)
  end
  -- The clock has no set width: it fits its text, and the place text
  -- runs up to it (a row without a clock uses the whole row).
  r.place:SetPoint("RIGHT", r.time, "LEFT", -4, 0)
end

-- What each row tag means, for its tooltip. Define keeps the table in the
-- current language, so an open tooltip redrawing with each update reads it.
local MEANINGS = ns.Localization.Define({}, {
  YOU = "shared.windows.your_resurrection_destination.e4788f", OURS = "shared.windows.friendly_objective_or_graveyard.db4a27",
  THEIRS = "shared.windows.enemy_objective_or_graveyard.304835", SOON = "shared.windows.your_graveyard_revives_players_soon_this_is.ba3bdc",
  CAP = "shared.windows.capture_in_progress.2e15da", LOCK = "shared.windows.timed_node_ownership.aac8d0", RESET = "shared.windows.node_resetting.c67e3a",
  FLAG = "shared.windows.flag_respawn_countdown.819f0d", CONTEST = "shared.windows.contested_objective.79f8ef",
  STATUS = "shared.windows.observed_game_status.0f8c50", GATE = "shared.windows.gate_status_from_the_game.f3b238", CART = "shared.windows.observed_cart_or_delivery_objective.11cdb7",
  ROUND = "shared.windows.round_information_from_the_game.49309c", CONTROL = "shared.windows.observed_control_progress.2ff37b",
  EVENT = "shared.windows.recent_battleground_announcement.aad5da", OBJECTIVE = "shared.windows.observed_map_objective.3c3cd9",
  RES = "shared.windows.awaiting_graveyard_observations.a5654e" })

function Timers.RowFrame(w, i)
  local r = w.rows[i]
  if r then return r end
  r = CreateFrame("Frame", nil, w)
  Hud.Surface(r, "BACKGROUND"):SetAllPoints()
  r.flash = Theme.Fill(r, "BORDER", "accent")
  r.flash:SetAllPoints()
  r.flash:SetAlpha(0)
  r.edge = ns.Kit.Outline(r, "border")
  r.glow = ns.Kit.Glow(r, "warning", 4)
  r.faction = r:CreateTexture(nil, "ARTWORK")
  r.tag = Theme.Text(r, "label")
  r.tag:SetJustifyH("LEFT")
  r.bar = CreateFrame("StatusBar", nil, r)
  r.bar:SetPoint("BOTTOMLEFT")
  r.bar:SetPoint("BOTTOMRIGHT")
  r.bar:SetHeight(Theme.Size("underline"))
  Core.StatusBar(r.bar)
  r.bar:SetMinMaxValues(0, 1)
  Theme.Fill(r.bar, "BACKGROUND", "overlaySubtle"):SetAllPoints()
  r.time = Theme.Text(r, "timer")
  r.time:SetJustifyH("RIGHT")
  r.place = Theme.Text(r, "rowNameSmall")
  r.place:SetJustifyH("LEFT")
  Timers.LayoutRow(w, r, i)
  r:EnableMouse(true)
  r.ShowTip = function(self)
    local row = self.data
    if not row then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    Timers.TipLine(GameTooltip, row.detail or row.text or "", "white")
    local meaning = MEANINGS[row.kind or row.tag] -- kind: the id behind a translated tag
    if meaning then Timers.TipLine(GameTooltip, meaning, "info") end
    if row.left then
      Timers.TipLine(GameTooltip, (row.est and ns.Locale:Get("shared.windows.estimated.21ab00") or ns.Locale:Get("shared.windows.remaining.5c9d2e")) .. Timers.Clock(row.left), "text")
    elseif not row.time and not row.frac then
      Timers.TipLine(GameTooltip, ns.Locale:Get("shared.windows.countdown_not_observed_yet.dc953b"), "textMuted")
    end
    GameTooltip:Show()
  end
  r:SetScript("OnEnter", r.ShowTip)
  r:SetScript("OnLeave", GameTooltip_Hide)
  w.rows[i] = r
  return r
end

local BAR_LIVE, BAR_EST = 0.85, 0.45 -- progress line alpha: observed, estimated
local CREST_TAGS = { OURS = true, THEIRS = true }

-- A row whose tag is newer than the last update (a capture starting, a
-- graveyard changing hands) flashes once. Counting tags survives reordering
-- and changing scores; opening the window flashes nothing.
local function Fresh(w, tag, opening)
  local seen, counts = w.tagSeen, w.tagCounts
  local n = (counts[tag] or 0) + 1
  counts[tag] = n
  return not opening and n > (seen[tag] or 0)
end

-- row = { tag, color, text, left + total (bar fills as it runs out) |
--         frac (bar as given), time (text, else from left), est, die, icon }
function Timers.ShowRows(w, rows, info)
  local opening = not w:IsShown()
  if not w.tagSeen then w.tagSeen, w.tagCounts = {}, {} end
  for tag in pairs(w.tagCounts) do w.tagCounts[tag] = nil end
  for i, row in ipairs(rows) do
    local r, c = Timers.RowFrame(w, i), row.color
    if Fresh(w, row.tag or "", opening) then
      Theme.Paint(r.flash, c or "accent")
      Motion.Flash(r.flash)
    end
    r.data = row
    -- The crest says whose row it is; OURS / THEIRS would repeat it.
    local crest = Timers.FactionIcon(r.faction, row.team, row.icon)
    r.tag:SetText(crest and CREST_TAGS[row.kind] and "" or row.tag)
    Theme.Paint(r.tag, c)
    local frac = row.frac
    if not frac and row.left then
      frac = math.max(0, math.min(1, 1 - row.left / math.max(row.total or 1, 1)))
    end
    r.bar:SetValue(frac or 0)
    Timers.BarColor(r.bar, c, row.est and BAR_EST or BAR_LIVE)
    local time = row.time or (row.left and ((row.est and "~" or "") .. Timers.Clock(row.left))) or "--"
    if r.timeText ~= time then r.timeText = time; r.time:SetText(time) end -- the clock changes once a second
    local urgent = row.die or (row.left and row.left > 0 and row.left <= 5)
    r.edge:SetColor(urgent and "warning" or "border")
    r.glow:SetActive(urgent, urgent)
    Theme.Paint(r.time, urgent and "warning" or (not row.left and not row.time and "textMuted") or "text")
    r.place:SetText(row.text or "")
    r:Show()
    -- An open tooltip follows the live countdown.
    if GameTooltip:IsShown() and GameTooltip:GetOwner() == r then r.ShowTip(r) end
  end
  for i = #rows + 1, #w.rows do
    w.rows[i]:Hide()
  end
  w.tagSeen, w.tagCounts = w.tagCounts, w.tagSeen
  Hud.SetInfo(w, info)
  w:SetHeight(Timers.TOP + #rows * (Timers.ROW_H + Timers.WIN_GAP) - Timers.WIN_GAP + Timers.WIN_PAD)
  if not InCombatLockdown() and w:GetScale() ~= Timers.WinScale(w) then
    w:SetScale(Timers.WinScale(w))
  end
  w:Show()
  if opening then Motion.Reveal(w) end
  if w.docks and ns.Dock then ns.Dock() end
end
