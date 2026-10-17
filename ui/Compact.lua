local _, ns = ...
local Core = ns.Core

---------------------------------------------------------------------------
-- Panel layout, normal or compact (Compact layout setting), and background
-- opacity. Compact: single-line enemy rows and hero, no section labels or
-- footer, and the battleground windows (flags, resurrection, objectives)
-- docked under the main panel as one column, moved by dragging any of them.
-- Protected panels only change out of combat; a toggle in combat applies
-- when it ends.
---------------------------------------------------------------------------

function Core.BgAlpha()
  local a = Core.db and tonumber(Core.db.bgAlpha)
  return a and math.max(0, math.min(1, a)) or Core.THEME.opacity.default
end

function Core.IsCompact()
  return Core.db and Core.db.compact == true or false
end

function ns.ApplyOpacity()
  local a = Core.BgAlpha()
  for _, t in ipairs(Core.surfaces) do t:SetAlpha(a) end
  local b = Core.THEME.colors.border
  for _, f in ipairs(Core.backdrops) do
    f:SetBackdropColor(Core.INK[1], Core.INK[2], Core.INK[3], a)
    f:SetBackdropBorderColor(b[1], b[2], b[3], math.min(1, a + 0.25))
  end
end

function ns.SetBgAlpha(value)
  value = tonumber(value)
  if not Core.db or not value or value ~= value then return false end
  local o = Core.THEME.opacity
  Core.db.bgAlpha = math.max(o.min, math.min(o.max, math.floor(value / o.step + 0.5) * o.step))
  ns.ApplyOpacity()
  if ns.RefreshOpacityOption then ns.RefreshOpacityOption() end
  return true
end

-- Current metrics -> the shared Core / Timers / Flags layout constants.
local function ApplyMetrics(compact)
  local m = compact and Core.THEME.compact.main or Core.THEME.main
  Core.WIDTH, Core.ROW_H, Core.GAP, Core.PAD = m.width, m.row, m.gap, m.padding
  Core.HEAD_H, Core.HERO_H, Core.FOOT_H, Core.TILE_W = m.header, m.hero, m.footer, m.rankWidth
  Core.LIST_TOP = Core.HEAD_H + Core.HERO_H + Core.PAD + m.section
  local T, F = ns.Timers, ns.Flags
  if T then
    local t = compact and Core.THEME.compact.timers or Core.THEME.timers
    T.WIN_W = compact and m.width or Core.THEME.timers.width
    T.ROW_H, T.WIN_GAP, T.WIN_PAD, T.TOP = t.row, t.gap, t.padding, t.header
  end
  if F and T then
    F.FROW_H = (compact and Core.THEME.compact.flags or Core.THEME.flags).row
    F.FTOP = T.TOP
  end
end

local function Place(region, ...)
  region:ClearAllPoints()
  region:SetPoint(...)
end

function Core.LayoutHead(compact)
  local h = Core.head
  h.bg:SetHeight(Core.HEAD_H - 1)
  h.brand:SetSize(3, compact and 9 or 12)
  Place(h.brand, "LEFT", Core.frame, "TOPLEFT", Core.PAD + 1, -Core.HEAD_H / 2)
  Core.SetFace(h.title, "bold", compact and 12 or 16)
  Core.SetFace(Core.liveText, "mono", compact and 8 or 9)
  if Core.gear then
    local g = compact and 14 or 20
    Core.gear:SetSize(g, g)
    Place(Core.gear, "RIGHT", Core.frame, "TOPRIGHT", -Core.PAD - 1, -Core.HEAD_H / 2)
  end
  Core.SetFace(Core.subtitle, "semi", compact and 10 or 11)
  for _, fs in ipairs({ h.section, h.hint, h.footer }) do fs:SetShown(not compact) end
  Place(h.section, "TOPLEFT", Core.PAD + 2, -Core.LIST_TOP + 15)
  Place(h.hint, "TOPRIGHT", -Core.PAD - 2, -Core.LIST_TOP + 15)
end

function Core.LayoutHero(compact)
  local h = Core.hero
  Place(h, "TOPLEFT", Core.PAD, -Core.HEAD_H - Core.PAD)
  h:SetPoint("TOPRIGHT", -Core.PAD, -Core.HEAD_H - Core.PAD)
  h:SetHeight(Core.HERO_H)
  h.hp:SetHeight(compact and 2 or 3)
  if compact then
    Core.SetFace(h.name, "bold", 15)
    Place(h.name, "LEFT", 10, 1)
    Core.SetFace(h.unitText, "mono", 8)
    Place(h.unitText, "RIGHT", -6, 0)
    Core.SetFace(h.dist, "mono", 15)
    Place(h.sub, "LEFT", h.name, "RIGHT", 6, -1)
    h.sub:SetPoint("RIGHT", h.dist, "LEFT", -6, 0)
    Place(h.clickNote, "LEFT", h.name, "RIGHT", 6, -1)
    Core.SetFace(h.empty, "bold", 12)
    Place(h.empty, "CENTER", 0, 0)
  else
    Core.SetFace(h.name, "bold", 22)
    Place(h.name, "TOPLEFT", 11, -16)
    h.name:SetPoint("RIGHT", h, "RIGHT", -76, 0)
    Core.SetFace(h.unitText, "mono", 9)
    Place(h.unitText, "TOPRIGHT", -9, -15)
    Core.SetFace(h.dist, "mono", 24)
    Place(h.sub, "TOPLEFT", 12, -41)
    h.sub:SetPoint("RIGHT", h, "RIGHT", -10, 0)
    Place(h.clickNote, "BOTTOMRIGHT", h, "BOTTOMRIGHT", -9, 5)
    Core.SetFace(h.empty, "bold", 15)
    Place(h.empty, "CENTER", 0, 7)
  end
  Place(h.dist, "BOTTOMRIGHT", h.unitText, "BOTTOMLEFT", -2, -2)
  h.emptySub:SetShown(not compact)
end

-- One enemy row: two lines (name over spec, ally pressure, distance and
-- score gap) or compact (one line: name, spec, state, distance).
function Core.LayoutRow(r, i, compact)
  r:SetSize(Core.WIDTH - Core.PAD * 2, Core.ROW_H)
  Place(r, "TOPLEFT", Core.PAD, -Core.LIST_TOP - (i - 1) * (Core.ROW_H + Core.GAP))
  r.tile:SetWidth(Core.TILE_W)
  Core.SetFace(r.rank, "mono", compact and 10 or 13)
  r.icon:SetSize(compact and 14 or 20, compact and 14 or 20)
  Place(r.icon, "LEFT", r.strip, "RIGHT", compact and 4 or 5, compact and 0 or 1)
  r.marker:SetSize(compact and 8 or 10, compact and 8 or 10)
  r.hp:SetHeight(compact and 2 or 3)
  Core.SetFace(r.pipText, "mono", compact and 8 or 9)
  r.gap:SetShown(not compact)
  r.allyText:SetShown(not compact)
  Place(r.arrow, "RIGHT", r, "LEFT", -Core.PAD - 1, 0)
  if compact then
    Core.SetFace(r.dist, "mono", 9)
    r.dist:SetWidth(22)
    Place(r.dist, "RIGHT", -4, 0)
    r.pip:SetSize(40, 12)
    Place(r.pip, "RIGHT", r.dist, "LEFT", -4, 0)
    Core.SetFace(r.spec, "medium", 10)
    r.spec:SetWidth(54)
    r.spec:SetJustifyH("RIGHT")
    Place(r.spec, "RIGHT", r.pip, "LEFT", -4, 0)
    r.eye:SetSize(9, 9)
    Place(r.eye, "BOTTOMRIGHT", r.icon, "BOTTOMRIGHT", 2, -2)
    r.trinket:SetSize(14, 14)
    Place(r.trinket, "RIGHT", r.spec, "LEFT", -3, 0)
    Core.SetFace(r.trinketText, "mono", 8, "OUTLINE")
    Core.SetFace(r.name, "semi", 12)
    Place(r.name, "LEFT", r.icon, "RIGHT", 4, 0)
    r.name:SetPoint("RIGHT", r.trinket, "LEFT", -3, 0)
  else
    r.gap:SetWidth(42)
    Place(r.gap, "BOTTOMRIGHT", -6, 5)
    Core.SetFace(r.dist, "mono", 10)
    r.dist:SetWidth(28)
    Place(r.dist, "RIGHT", r.gap, "LEFT", -10, 0)
    r.pip:SetSize(54, 15)
    Place(r.pip, "TOPRIGHT", -5, -3)
    Core.SetFace(r.spec, "medium", 11)
    r.spec:SetWidth(80)
    r.spec:SetJustifyH("LEFT")
    Place(r.spec, "BOTTOMLEFT", 60, 5)
    r.eye:SetSize(11, 11)
    Place(r.eye, "LEFT", r.allyText, "RIGHT", 2, 0)
    -- Vertically centred between the two lines, left of the distance column.
    r.trinket:SetSize(18, 18)
    Place(r.trinket, "RIGHT", r, "RIGHT", -92, 0)
    Core.SetFace(r.trinketText, "mono", 9, "OUTLINE")
    Core.SetFace(r.name, "semi", 15)
    Place(r.name, "TOPLEFT", 60, -3)
    r.name:SetPoint("RIGHT", r.trinket, "LEFT", -6, 0)
  end
end

-- Normal or compact everywhere. Out of combat only (protected panels).
function Core.ApplyLayout()
  if not Core.db then return false end
  if InCombatLockdown() then
    Core.layoutModePending = true
    return false
  end
  Core.layoutModePending = false
  local compact = Core.IsCompact()
  Core.compact = compact
  ApplyMetrics(compact)
  Core.frame:SetWidth(Core.WIDTH)
  Core.LayoutHead(compact)
  Core.LayoutHero(compact)
  for i, r in ipairs(Core.rows) do Core.LayoutRow(r, i, compact) end
  local T, F = ns.Timers, ns.Flags
  if T and T.LayoutWindow then
    for _, w in ipairs(T.windows) do T.LayoutWindow(w) end
  end
  if F and F.LayoutRows then F.LayoutRows() end
  Core.layoutPending = true -- panel height follows the new row size
  if Core.Layout then Core.Layout() end
  Core.Undock()
  Core.Dock()
  return true
end

function ns.SetCompact(on)
  if not Core.db then return false end
  Core.db.compact = on and true or false
  local applied = Core.ApplyLayout()
  if ns.Options and ns.Options.RefreshFeatures then ns.Options.RefreshFeatures() end
  return applied
end

---------------------------------------------------------------------------
-- Docking (compact): main panel, flag carriers, resurrection, objectives.
-- The first shown one sits at the main panel's saved position; each next one
-- hangs under the previous. The arena panel stays on its own.
---------------------------------------------------------------------------
Core.DOCK = { "WarboardFrame", "WarboardFlagsFrame", "WarboardTimersFrame", "WarboardBasesFrame" }

local function Protected(w)
  return w == Core.frame or w.secure
end

local function DockFrames()
  local list = {}
  for _, name in ipairs(Core.DOCK) do
    local w = _G[name]
    if w and w:IsShown() then list[#list + 1] = w end
  end
  return list
end

-- The frame that moves the column: the first shown one.
function Core.DockHead()
  if not Core.compact then return nil end
  return DockFrames()[1]
end
ns.DockHead = Core.DockHead

function Core.PlaceDockHead(w)
  local point = Core.pos and Core.pos.point
  w:ClearAllPoints()
  if point then
    w:SetPoint(point[1], UIParent, point[2], point[3], point[4])
  else
    w:SetPoint("RIGHT", UIParent, "RIGHT", -260, 80)
  end
end

function Core.Dock()
  if Core.layoutModePending and not InCombatLockdown() then
    Core.ApplyLayout()
    return
  end
  if not Core.compact then return end
  local combat = InCombatLockdown()
  local prev
  for _, w in ipairs(DockFrames()) do
    local want = prev or "head"
    if w.dockedTo ~= want and not (combat and Protected(w)) then
      if prev then
        w:ClearAllPoints()
        w:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -Core.THEME.compact.dockGap)
      else
        Core.PlaceDockHead(w)
      end
      w.dockedTo = want
    end
    prev = w
  end
end
ns.Dock = Core.Dock

-- Leaving compact: every window back to its own saved spot.
function Core.Undock()
  if Core.compact then return end
  local T = ns.Timers
  for _, name in ipairs(Core.DOCK) do
    local w = _G[name]
    if w and w.dockedTo then
      w.dockedTo = nil
      if w == Core.frame then
        Core.PlaceDockHead(w)
      elseif T then
        T.PlaceWin(w)
      end
    end
  end
end

-- Dragging a docked window moves the whole column.
function Core.DockDrag(w, start)
  local head = Core.DockHead()
  if not head then return false end
  if start then
    if not (Core.db.locked or (InCombatLockdown() and Protected(head))) then head:StartMoving() end
  else
    head:StopMovingOrSizing()
    local p, _, rp, x, y = head:GetPoint()
    Core.pos.point = { p, rp, x, y }
  end
  return true
end
ns.DockDrag = Core.DockDrag
