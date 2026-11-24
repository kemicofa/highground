local _, ns = ...
local Core = ns.Core

---------------------------------------------------------------------------
-- Panel layout, normal or compact (Compact layout setting).
-- Compact: single-line enemy rows and hero, no section labels or
-- footer, and the battleground windows (flags, resurrection, objectives)
-- docked under the main panel as one column, moved by dragging any of them.
-- Protected panels only change out of combat; a toggle in combat applies
-- when it ends.
---------------------------------------------------------------------------

function Core.IsCompact()
  return Core.db and Core.db.compact == true or false
end

-- Current metrics -> the shared Core / Timers / Flags layout constants.
-- Appearance overrides (ui/Appearance.lua) replace the theme values.
local function ApplyMetrics(compact)
  local m = compact and Core.THEME.compact.main or Core.THEME.main
  local M = function(key) return Core.Metric(key, compact) end
  Core.WIDTH, Core.ROW_H, Core.GAP, Core.PAD = M("width"), M("row"), M("gap"), M("padding")
  local frameless = Core.Frameless()
  Core.HEAD_H, Core.HERO_H, Core.FOOT_H, Core.TILE_W = m.header, Core.ShowsElement("hero") and m.hero or 0,
    frameless and 4 or m.footer, m.rankWidth
  Core.LIST_TOP = Core.HEAD_H + Core.HERO_H + Core.PAD + (frameless and 4 or m.section)
  local T, F = ns.Timers, ns.Flags
  if T then
    local t = compact and Core.THEME.compact.timers or Core.THEME.timers
    T.WIN_W = compact and Core.WIDTH or M("timerWidth")
    T.ROW_H, T.WIN_GAP, T.WIN_PAD, T.TOP = M("timerRow"), M("timerGap"), t.padding, t.header
  end
  if F and T then
    F.FROW_H = (compact and Core.THEME.compact.flags or Core.THEME.flags).row
    F.FTOP = T.TOP
  end
end

-- Type role of each main-panel text per layout: { normal, compact }.
local ROLES = {
  title = { "title", "titleSmall" }, live = { "label", "caption" }, subtitle = { "detail", "detailSmall" },
  heroName = { "number", "cardName" }, heroUnit = { "label", "caption" },
  heroDist = { "readout", "readoutSmall" }, heroEmpty = { "cardName", "titleSmall" },
  heroDetail = { "detail", "detail" },
  rank = { "figure", "code" }, pip = { "label", "caption" }, dist = { "code", "label" },
  spec = { "body", "note" }, hpText = { "figureLarge", "code" },
  trinket = { "labelOutline", "captionOutline" }, name = { "rowName", "control" },
}
local function Role(fs, key, compact)
  ns.Theme.SetRole(fs, ROLES[key][compact and 2 or 1])
end

local function Place(region, ...)
  region:ClearAllPoints()
  region:SetPoint(...)
end

function Core.LayoutHead(compact)
  local h = Core.head
  h.bg:SetHeight(Core.HEAD_H - 1)
  h.brand:SetSize(compact and 4 or 6, compact and 4 or 6)
  h.brand:SetRotation(math.pi / 4)
  Place(h.brand, "LEFT", Core.frame, "TOPLEFT", Core.PAD + 1, -Core.HEAD_H / 2)
  Role(h.title, "title", compact)
  Role(Core.liveText, "live", compact)
  if Core.gear then
    ns.PanelControls.Layout(Core.frame, Core.HEAD_H, Core.PAD + 1)
  end
  Role(Core.subtitle, "subtitle", compact)
  for _, fs in ipairs({ h.section, h.hint, h.footer }) do fs:SetShown(not compact and not Core.Frameless()) end
  Place(h.section, "TOPLEFT", Core.PAD + 2, -Core.LIST_TOP + 15)
  Place(h.hint, "TOPRIGHT", -Core.PAD - 2, -Core.LIST_TOP + 15)
end

function Core.LayoutHero(compact)
  local h = Core.hero
  Place(h, "TOPLEFT", Core.PAD, -Core.HEAD_H - Core.PAD)
  h:SetPoint("TOPRIGHT", -Core.PAD, -Core.HEAD_H - Core.PAD)
  h:SetHeight(Core.HERO_H)
  h.hp:SetHeight(Core.HealthFill() and (compact and 4 or 6) or (compact and 2 or 3))
  Role(h.name, "heroName", compact)
  Role(h.unitText, "heroUnit", compact)
  Role(h.dist, "heroDist", compact)
  Role(h.empty, "heroEmpty", compact)
  Role(h.detail, "heroDetail", compact)
  if compact then
    Place(h.name, "LEFT", 10, 1)
    Place(h.unitText, "RIGHT", -6, 0)
    Place(h.sub, "LEFT", h.name, "RIGHT", 6, -1)
    h.sub:SetPoint("RIGHT", h.dist, "LEFT", -6, 0)
    Place(h.clickNote, "LEFT", h.name, "RIGHT", 6, -1)
    Place(h.empty, "CENTER", 0, 0)
  else
    Place(h.name, "TOPLEFT", 11, -16)
    h.name:SetPoint("RIGHT", h, "RIGHT", -76, 0)
    Place(h.unitText, "TOPRIGHT", -9, -15)
    Place(h.sub, "TOPLEFT", 12, -41)
    h.sub:SetPoint("RIGHT", h, "RIGHT", -10, 0)
    Place(h.clickNote, "BOTTOMRIGHT", h, "BOTTOMRIGHT", -9, 5)
    Place(h.empty, "CENTER", 0, 7)
  end
  Place(h.dist, "BOTTOMRIGHT", h.unitText, "BOTTOMLEFT", -2, -2)
  h.emptySub:SetShown(not compact)
  -- Kill-target card switch (Appearance); its secure button goes with it.
  local on = Core.ShowsElement("hero")
  h:SetShown(on)
  if Core.heroBtn then Core.heroBtn:SetShown(on) end
end

-- One enemy row: two lines (name over spec, ally pressure, distance and
-- score gap) or compact (one line: name, spec, state, distance). Elements
-- switched off in Appearance collapse to nothing so the rest moves up.
local NONE = 0.001
function Core.LayoutRow(r, i, compact)
  local S = Core.ShowsElement
  r:SetSize(Core.WIDTH - Core.PAD * 2, Core.ROW_H)
  Place(r, "TOPLEFT", Core.PAD, -Core.LIST_TOP - (i - 1) * (Core.ROW_H + Core.GAP))
  r.tile:SetWidth(S("rank") and Core.TILE_W or NONE)
  r.rank:SetShown(S("rank"))
  Role(r.rank, "rank", compact)
  Place(r.rank, "CENTER", r.tile, "CENTER", 0, compact and 0 or 4)
  r.marks:SetShown(not compact and S("rank"))
  local icon = S("icon") and math.max(10, compact and Core.ROW_H - 6 or Core.ROW_H - 14) or NONE
  r.icon:SetSize(icon, icon)
  r.icon:SetShown(S("icon"))
  Place(r.icon, "LEFT", r.strip, "RIGHT", S("icon") and (compact and 4 or 5) or 0, compact and 0 or 1)
  r.marker:SetSize(compact and 8 or 10, compact and 8 or 10)
  -- Health style: Fill = health behind the whole row, mana along its
  -- bottom; Line = thin health line with a thinner mana line above it.
  local fill = Core.HealthFill()
  r.fillMode = fill
  r.hp:ClearAllPoints()
  r.hp:SetPoint("BOTTOMLEFT", r.strip, "BOTTOMRIGHT", 0, 0)
  r.hp:SetPoint("BOTTOMRIGHT")
  r.mana:ClearAllPoints()
  if fill then
    r.hp:SetPoint("TOPLEFT", r.strip, "TOPRIGHT", 0, 0)
    Core.SetSurfaceAlpha(r.hp.bg, 0)
    r.mana:SetPoint("BOTTOMLEFT", r.strip, "BOTTOMRIGHT", 0, 0)
    r.mana:SetPoint("BOTTOMRIGHT")
    r.mana:SetHeight(math.max(3, math.floor(Core.ROW_H * 0.15 + 0.5)))
  else
    r.hp:SetHeight(Core.Metric("health", compact))
    Core.SetSurfaceAlpha(r.hp.bg, 1)
    r.mana:SetPoint("BOTTOMLEFT", r.hp, "TOPLEFT", 0, 0)
    r.mana:SetPoint("BOTTOMRIGHT", r.hp, "TOPRIGHT", 0, 0)
    r.mana:SetHeight(math.max(1, math.floor(Core.Metric("health", compact) * 2 / 3 + 0.5)))
  end
  r.hp:SetShown(S("health"))
  local hpText = S("healthText") and ns.Caps.enemyStats
  r.hpText:SetShown(hpText)
  Role(r.pipText, "pip", compact)
  Role(r.dist, "dist", compact)
  Role(r.spec, "spec", compact)
  Role(r.hpText, "hpText", compact)
  Role(r.trinketText, "trinket", compact)
  Role(r.name, "name", compact)
  r.gap:SetShown(not compact and S("gap"))
  r.allyText:SetShown(not compact and S("allies"))
  r.spec:SetShown(S("spec"))
  r.dist:SetShown(S("distance"))
  r.rangeDot:SetShown(S("distance"))
  Place(r.arrow, "RIGHT", r, "LEFT", -Core.PAD - 1, 0)
  local textX = (S("rank") and Core.TILE_W or 0) + 3 + (S("icon") and icon + 11 or 6)
  -- Left edge of each right-side slot, measured from the row's right edge.
  local room = r.nameRoom or {}
  r.nameRoom, r.compactRow = room, compact
  if compact then
    local distW, pipW, specW = S("distance") and 22 or NONE, S("status") and 40 or NONE, S("spec") and 54 or NONE
    local hpW, trinketW = hpText and 30 or NONE, S("trinket") and 14 or NONE
    r.dist:SetWidth(distW)
    Place(r.dist, "RIGHT", -4, 0)
    r.pip:SetSize(pipW, 12)
    Place(r.pip, "RIGHT", r.dist, "LEFT", S("distance") and -4 or 0, 0)
    r.spec:SetWidth(specW)
    r.spec:SetJustifyH("RIGHT")
    Place(r.spec, "RIGHT", r.pip, "LEFT", S("status") and -4 or 0, 0)
    r.eye:SetSize(9, 9)
    Place(r.eye, "BOTTOMRIGHT", r.icon, "BOTTOMRIGHT", 2, -2)
    r.hpText:SetWidth(hpW)
    Place(r.hpText, "RIGHT", r.spec, "LEFT", -3, 0)
    r.trinket:SetSize(trinketW, 14)
    Place(r.trinket, "RIGHT", r.hpText, "LEFT", -3, 0)
    Place(r.name, "LEFT", r.icon, "RIGHT", 4, 0)
    room.dist = 4 + distW
    room.pip = room.dist + (S("distance") and 4 or 0) + pipW
    room.spec = room.pip + (S("status") and 4 or 0) + specW
    room.hp = room.spec + 3 + hpW
    room.trinket = room.hp + 3 + trinketW
  else
    r.gap:SetWidth(S("gap") and 42 or NONE)
    Place(r.gap, "BOTTOMRIGHT", -6, 5)
    r.dist:SetWidth(S("distance") and 28 or NONE)
    Place(r.dist, "RIGHT", r.gap, "LEFT", S("gap") and -10 or 0, 0)
    local pipW, trinketW, hpW = S("status") and 54 or NONE, S("trinket") and 18 or NONE, hpText and 42 or NONE
    r.pip:SetSize(pipW, 15)
    Place(r.pip, "TOPRIGHT", -5, -3)
    r.spec:SetWidth(80)
    r.spec:SetJustifyH("LEFT")
    Place(r.spec, "BOTTOMLEFT", textX, 5)
    r.eye:SetSize(11, 11)
    Place(r.eye, "LEFT", r.allyText, "RIGHT", 2, 0)
    -- Vertically centred between the two lines, left of the distance column.
    local trinketX = (S("gap") and 54 or 6) + (S("distance") and 38 or 0)
    r.trinket:SetSize(trinketW, 18)
    Place(r.trinket, "RIGHT", r, "RIGHT", -trinketX, 0)
    r.hpText:SetWidth(hpW)
    Place(r.hpText, "RIGHT", r.trinket, "LEFT", -4, 0)
    Place(r.name, "TOPLEFT", textX, -3)
    room.pip = 5 + pipW
    room.trinket = trinketX + trinketW
    room.hp = room.trinket + 4 + hpW
  end
  r.nameEdge = nil
  Core.FitRowName(r)
end

-- The name runs up to the first right-side slot the row shows, so long
-- names (WoW Forever's first and last names) get the room of empty slots.
-- Slots keep their places. Normal rows keep the name clear of the bounty
-- coin in the top-right corner.
function Core.FitRowName(r)
  local room, edge = r.nameRoom
  if r.compactRow then
    edge = r.trinket:IsShown() and room.trinket or r.hpText:IsShown() and room.hp
      or r.specText and r.spec:IsShown() and room.spec or r.pip:IsShown() and room.pip
      or r.dist:IsShown() and room.dist
    edge = edge and edge + 3 or 4
  else
    edge = r.hpText:IsShown() and room.hp or r.trinket:IsShown() and room.trinket
      or r.pip:IsShown() and room.pip
    edge = edge and edge + 4 or 14
  end
  if edge ~= r.nameEdge then
    r.nameEdge = edge
    r.name:SetPoint("RIGHT", r, "RIGHT", -edge, 0)
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
  if Core.frame then -- the kill-order panel (Highground only)
    Core.frame:SetWidth(Core.WIDTH)
    Core.LayoutHead(compact)
    Core.LayoutHero(compact)
  end
  for i, r in ipairs(Core.rows or {}) do Core.LayoutRow(r, i, compact) end
  local T, F = ns.Timers, ns.Flags
  if T and T.LayoutWindow then
    for _, w in ipairs(T.windows) do T.LayoutWindow(w) end
  end
  if F and F.LayoutRows then F.LayoutRows() end
  Core.layoutPending = true -- panel height follows the new row size
  if Core.Layout then Core.Layout() end
  Core.Undock()
  Core.Dock()
  if ns.PanelControls then ns.PanelControls.Refresh() end
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
-- Docking (compact): main panel, flag carriers, resurrection, forecast, timers.
-- The first shown one sits at the main panel's saved position; each next one
-- hangs under the previous. The arena panel stays on its own. Without the
-- main panel (Highground Battlegrounds) the first window takes its place.
---------------------------------------------------------------------------
local PREFIX = ns.FRAME_PREFIX or "Highground"
Core.DOCK = { PREFIX .. "Frame", PREFIX .. "FlagsFrame", PREFIX .. "TimersFrame", PREFIX .. "ForecastFrame", PREFIX .. "BasesFrame" }

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
  elseif not Core.compact and w == Core.frame then
    -- Keep the initial enemy list below the top-center objective panels,
    -- including at smaller UI resolutions. Explicit player positions win.
    w:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -24, -320)
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
