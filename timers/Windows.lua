local _, ns = ...
local Timers = ns.Timers

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

function Timers.PlaceWin(w)
  local db = Timers.DB()
  local pos = Timers.Positions()
  if ns.DockHead and ns.DockHead() and w.docks then
    -- Compact: docked windows hang under the column (ui/Compact.lua).
    w:SetScale(db and db.scale or Timers.THEME.scale.default)
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
  w:SetScale(db and db.scale or Timers.THEME.scale.default)
end

function ns.TimersApplyScale()
  if InCombatLockdown() then return end
  local db = Timers.DB()
  for _, w in ipairs(Timers.windows) do
    w:SetScale(db and db.scale or Timers.THEME.scale.default)
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

function Timers.MakeWindow(name, title, key, def, secure)
  local UI = ns.UI
  if not UI then
    return nil
  end
  local w = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
  w.key, w.def, w.rows, w.secure = key, def, {}, secure
  w.docks = name ~= "WarboardArenaFrame"
  w:SetSize(Timers.WIN_W, Timers.TOP + Timers.ROW_H + 4)
  w:SetBackdrop({ bgFile = UI.WHITE, edgeFile = UI.WHITE, edgeSize = 1 })
  UI.Backdrop(w)
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
    if not (db and db.locked) then
      self:StartMoving()
    end
  end)
  w:SetScript("OnDragStop", function(self)
    if self.docks and ns.DockDrag and ns.DockDrag(self, false) then
      return
    end
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    local pos = Timers.Positions()
    if pos then
      pos[self.key] = { p, rp, x, y }
    end
  end)
  w.head = UI.Surface(w, "BORDER")
  w.head:SetPoint("TOPLEFT", 1, -1)
  w.head:SetPoint("TOPRIGHT", -1, -1)
  w.brand = UI.Fill(w, "ARTWORK", UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3])
  w.title = UI.Text(w, "bold", 13)
  w.title:SetPoint("LEFT", w.brand, "RIGHT", 4, 0)
  w.title:SetTextColor(unpack(Timers.THEME.colors.text))
  w.title:SetText(title)
  w.info = UI.Text(w, "mono", 9)
  w.info:SetJustifyH("RIGHT")
  w.info:SetTextColor(unpack(Timers.THEME.colors.muted))
  Timers.windows[#Timers.windows + 1] = w
  if not secure then Timers.timerWindows[#Timers.timerWindows + 1] = w end
  Timers.LayoutWindow(w)
  Timers.PlaceWin(w)
  w:Hide()
  return w
end

local function Compact()
  return ns.UI and ns.UI.IsCompact and ns.UI.IsCompact() or false
end

-- Header, width and rows for the current layout (normal or compact).
function Timers.LayoutWindow(w)
  local UI, compact = ns.UI, Compact()
  w:SetWidth(Timers.WIN_W)
  w.head:SetHeight(Timers.TOP - (compact and 1 or 4))
  w.brand:SetSize(3, compact and 8 or 12)
  w.brand:ClearAllPoints()
  w.brand:SetPoint("TOPLEFT", Timers.WIN_PAD, compact and -4 or -7)
  UI.SetFace(w.title, "bold", compact and 10 or 13)
  UI.SetFace(w.info, "mono", compact and 8 or 9)
  w.info:ClearAllPoints()
  w.info:SetPoint("TOPRIGHT", -Timers.WIN_PAD, compact and -4 or -9)
  w.info:SetWidth(Timers.WIN_W - (compact and 100 or 128))
  for i, r in ipairs(w.rows) do Timers.LayoutRow(w, r, i) end
  if w.relayout then w.relayout() end
end

-- Normal: place over tag, clock on the right. Compact: one line.
function Timers.LayoutRow(w, r, i)
  local UI, compact = ns.UI, Compact()
  r:ClearAllPoints()
  r:SetPoint("TOPLEFT", Timers.WIN_PAD, -Timers.TOP - (i - 1) * (Timers.ROW_H + Timers.WIN_GAP))
  r:SetPoint("RIGHT", -Timers.WIN_PAD, 0)
  r:SetHeight(Timers.ROW_H)
  r.tag:ClearAllPoints()
  r.time:ClearAllPoints()
  r.place:ClearAllPoints()
  if compact then
    UI.SetFace(r.tag, "mono", 8)
    r.tag:SetPoint("LEFT", 5, 0)
    r.tag:SetWidth(44)
    UI.SetFace(r.time, "mono", 11)
    r.time:SetPoint("RIGHT", -5, 0)
    r.time:SetWidth(50)
    UI.SetFace(r.place, "semi", 11)
    r.place:SetPoint("LEFT", r.tag, "RIGHT", 2, 0)
  else
    UI.SetFace(r.tag, "mono", 9)
    r.tag:SetPoint("BOTTOMLEFT", 7, 5)
    r.tag:SetWidth(76)
    UI.SetFace(r.time, "mono", 16)
    r.time:SetPoint("RIGHT", -7, 1)
    r.time:SetWidth(65)
    UI.SetFace(r.place, "semi", 14)
    r.place:SetPoint("TOPLEFT", 7, -3)
  end
  r.place:SetPoint("RIGHT", r.time, "LEFT", -4, 0)
end

function Timers.RowFrame(w, i)
  local r = w.rows[i]
  if r then
    return r
  end
  local UI = ns.UI
  r = CreateFrame("Frame", nil, w)
  local surface = UI.Surface(r, "BACKGROUND")
  surface:SetAllPoints()
  r.tag = UI.Text(r, "mono", 9)
  r.tag:SetJustifyH("LEFT")
  r.bar = CreateFrame("StatusBar", nil, r)
  r.bar:SetPoint("BOTTOMLEFT")
  r.bar:SetPoint("BOTTOMRIGHT")
  r.bar:SetHeight(2)
  r.bar:SetStatusBarTexture(UI.WHITE)
  r.bar:SetMinMaxValues(0, 1)
  local bg = UI.Fill(r.bar, "BACKGROUND", 1, 1, 1, 0.05)
  bg:SetAllPoints()
  r.time = UI.Text(r, "mono", 16)
  r.time:SetJustifyH("RIGHT")
  r.place = UI.Text(r, "semi", 14)
  r.place:SetJustifyH("LEFT")
  Timers.LayoutRow(w, r, i)
  r.place:SetTextColor(unpack(Timers.THEME.colors.text))
  r:EnableMouse(true)
  r:SetScript("OnEnter", function(self)
    local row = self.data
    if not row then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(row.text or "", 1, 1, 1)
    local meanings = { YOU = "Your resurrection destination", OURS = "Friendly graveyard",
      THEIRS = "Enemy graveyard", DIE = "Your next resurrection wave is close",
      CAP = "Capture in progress", LOCK = "Timed node ownership", RESET = "Node resetting",
      WIN = "Projected win if current captures complete", HELD = "Projection if contested bases are defended",
      NEED = "Bases required for the trailing team to win", FLAG = "Flag respawn countdown",
      RES = "Awaiting graveyard observations" }
    if meanings[row.tag] then GameTooltip:AddLine(meanings[row.tag], 0.65, 0.8, 0.9) end
    if row.left then
      GameTooltip:AddLine((row.est and "Estimated: " or "Remaining: ") .. Timers.Clock(row.left), 0.85, 0.85, 0.85)
    elseif not row.time and not row.frac then
      GameTooltip:AddLine("Countdown not observed yet", 0.65, 0.7, 0.75)
    end
    GameTooltip:Show()
  end)
  r:SetScript("OnLeave", GameTooltip_Hide)
  w.rows[i] = r
  return r
end

-- row = { tag, color, text, left + total (bar fills as it runs out) |
--         frac (bar as given), time (text, else from left), est, die }
function Timers.ShowRows(w, rows, info)
  for i, row in ipairs(rows) do
    local r, c = Timers.RowFrame(w, i), row.color
    r.data = row
    r.tag:SetText(row.tag)
    r.tag:SetTextColor(c[1], c[2], c[3])
    local frac = row.frac
    if not frac and row.left then
      frac = math.max(0, math.min(1, 1 - row.left / math.max(row.total or 1, 1)))
    end
    r.bar:SetValue(frac or 0)
    r.bar:SetStatusBarColor(c[1], c[2], c[3], row.est and 0.45 or 0.85)
    r.time:SetText(row.time or (row.left and ((row.est and "~" or "") .. Timers.Clock(row.left))) or "--")
    local urgent = row.die or (row.left and row.left > 0 and row.left <= 5)
    local color = urgent and Timers.THEME.colors.warning or (not row.left and not row.time and Timers.THEME.colors.muted) or Timers.THEME.colors.text
    r.time:SetTextColor(unpack(color))
    r.place:SetText(row.text or "")
    r:Show()
  end
  for i = #rows + 1, #w.rows do
    w.rows[i]:Hide()
  end
  w.info:SetText(info or "")
  w:SetHeight(Timers.TOP + #rows * (Timers.ROW_H + Timers.WIN_GAP) - Timers.WIN_GAP + Timers.WIN_PAD)
  local db = Timers.DB()
  if db and db.scale and not InCombatLockdown() and w:GetScale() ~= db.scale then
    w:SetScale(db.scale)
  end
  w:Show()
  if w.docks and ns.Dock then ns.Dock() end
end
