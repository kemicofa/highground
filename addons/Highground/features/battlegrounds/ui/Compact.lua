local _, ns = ...
local Core = ns.Core

---------------------------------------------------------------------------
-- Panel layout, normal or compact (Compact layout setting).
-- Compact: single-line enemy rows and hero, no section labels or
-- footer, and the battleground windows (flags, resurrection, objectives)
-- docked under the main panel as one column, moved by dragging any of them
-- (ui/Dock.lua).
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
  -- A requested thick bar grows the row instead of running into the name.
  if Core.HealthStyle() == "bar" then
    local _, size = ns.Theme.Font(compact and "control" or "rowName")
    Core.ROW_H = math.max(Core.ROW_H, M("healthBar") + math.ceil(size * Core.FontScale() * 1.2) + (compact and 4 or 8))
  end
  local frameless = Core.Frameless()
  -- Bar style: the suggested-target card grows to fit its bar under the text.
  local heroBar = Core.HealthStyle() == "bar" and M("healthBar") + (compact and 3 or 6) or 0
  Core.HEAD_H, Core.HERO_H, Core.FOOT_H, Core.TILE_W = m.header, Core.ShowsElement("hero") and m.hero + heroBar or 0,
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
  barText = { "figure", "captionOutline" },
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
  local style = Core.HealthStyle()
  h.hp:ClearAllPoints()
  if style == "bar" then
    -- Inset on its track, percentage at the end.
    local inset = compact and 3 or 6
    h.hp:SetPoint("BOTTOMLEFT", 4 + inset, inset)
    h.hp:SetPoint("BOTTOMRIGHT", -inset, inset)
    h.hp:SetHeight(Core.Metric("healthBar", compact))
    Core.SetSurfaceAlpha(h.hp.bg, 1)
    Role(h.hpText, "barText", compact)
    Place(h.hpText, "RIGHT", h.hp, "RIGHT", -3, 0)
  else
    h.hp:SetPoint("BOTTOMLEFT", 4, 0)
    h.hp:SetPoint("BOTTOMRIGHT")
    h.hp:SetHeight(Core.HealthFill() and (compact and 4 or 6) or (compact and 2 or 3))
    Core.SetSurfaceAlpha(h.hp.bg, 0)
  end
  h.barMode = style == "bar"
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
-- Reserve the widest possible label once at layout time. Empty priority
-- tags keep the same track width as NOW/TOP/DEAD, so health remains comparable
-- between rows and never appears to change just because priority changes.
-- Measured on a hidden string in the label's font: a label that has shown
-- secret health keeps a secret width, even after plain text replaces it.
local measure
local function LabelWidth(fs, ...)
  measure = measure or (Core.frame or UIParent):CreateFontString(nil, "OVERLAY")
  measure:Hide()
  local font, size, flags = fs:GetFont()
  if font then measure:SetFont(font, size, flags) end
  local width = 0
  for i = 1, select("#", ...) do
    measure:SetText((select(i, ...)))
    width = math.max(width, measure:GetStringWidth())
  end
  return math.ceil(width) + 2
end

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
  -- Health style: Bar = a thick bar on its track under the name (placed
  -- with the text below), percentage at its end; Fill = health behind the
  -- whole row, mana along its bottom; Line = thin health line with a
  -- thinner mana line above it.
  local style = Core.HealthStyle()
  local fill, bar = style == "fill", style == "bar"
  r.fillMode, r.barMode = fill, bar
  -- The solid bar already supplies its selected colour. Keep the class
  -- underline only for row fills, where it helps locate the health edge.
  r.classBg.healthLine:SetShown(fill)
  r.hp:ClearAllPoints()
  r.hp:SetPoint("BOTTOMLEFT", r.strip, "BOTTOMRIGHT", 0, 0)
  r.hp:SetPoint("BOTTOMRIGHT")
  r.mana:ClearAllPoints()
  if bar then
    r.hp:SetHeight(Core.Metric("healthBar", compact))
    Core.SetSurfaceAlpha(r.hp.bg, 1)
    r.mana:SetPoint("TOPLEFT", r.hp, "BOTTOMLEFT", 0, -1)
    r.mana:SetPoint("TOPRIGHT", r.hp, "BOTTOMRIGHT", 0, -1)
    r.mana:SetHeight(compact and 1 or 2)
  elseif fill then
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
  local hpText = S("healthText")
  r.hpText:SetShown(hpText)
  Role(r.pipText, "pip", compact)
  Role(r.dist, "dist", compact)
  Role(r.spec, "spec", compact)
  Role(r.hpText, bar and not compact and "barText" or "hpText", compact)
  Role(r.trinketText, "trinket", compact)
  Role(r.name, "name", compact)
  r.gap:SetShown(not compact and S("gap"))
  r.allyText:SetShown(not compact and S("allies"))
  r.allyText:ClearAllPoints()
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
    local hpW, trinketW = hpText and LabelWidth(r.hpText, "100%") or NONE, S("trinket") and 14 or NONE
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
    if bar then
      -- Under the name, up to the first right-side slot; the name rises.
      local barH = Core.Metric("healthBar", true)
      Place(r.name, "LEFT", r.icon, "RIGHT", 4, math.floor(barH / 2 + 0.5))
      r.hp:ClearAllPoints()
      r.hp:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 4, -2)
      r.hp:SetPoint("RIGHT", r.dist, "LEFT", -4, 0)
    end
    room.dist = 4 + distW
    room.pip = room.dist + (S("distance") and 4 or 0) + pipW
    room.spec = room.pip + (S("status") and 4 or 0) + specW
    room.hp = room.spec + 3 + hpW
    room.trinket = room.hp + 3 + trinketW
  elseif bar then
    -- Top line: name, then trinket, spec, teammates and status from the
    -- right. Bottom line: the bar, then distance and priority tag.
    local pipW, trinketW, specW, allyW = S("status") and 54 or NONE, S("trinket") and 16 or NONE,
      S("spec") and 54 or NONE, S("allies") and 24 or NONE
    r.pip:SetSize(pipW, 15)
    Place(r.pip, "TOPRIGHT", -5, -3)
    r.allyText:SetWidth(allyW)
    r.allyText:SetJustifyH("RIGHT")
    r.allyText:SetPoint("RIGHT", r.pip, "LEFT", S("status") and -4 or 0, 0)
    r.spec:SetWidth(specW)
    r.spec:SetJustifyH("RIGHT")
    Place(r.spec, "RIGHT", r.allyText, "LEFT", S("allies") and -3 or 0, 0)
    r.trinket:SetSize(trinketW, 16)
    Place(r.trinket, "RIGHT", r.spec, "LEFT", S("spec") and -3 or 0, 0)
    r.eye:SetSize(11, 11)
    Place(r.eye, "BOTTOMRIGHT", r.icon, "BOTTOMRIGHT", 2, -2)
    Place(r.name, "TOPLEFT", textX, -3)
    local gapW = S("gap") and LabelWidth(r.gap, ns.Locale:Get("highground.render.now.9841c4"),
      ns.Locale:Get("highground.render.top.b48813"), ns.Locale:Get("highground.render.dead.9d6c23")) or 0
    local distW = S("distance") and LabelWidth(r.dist, "100", "--", ns.Locale:Get("highground.render.far.dca1e7")) or 0
    r.gap:SetWidth(gapW > 0 and gapW or NONE)
    Place(r.gap, "BOTTOMRIGHT", -6, 4)
    r.dist:SetWidth(distW > 0 and distW or NONE)
    Place(r.dist, "RIGHT", r.gap, "LEFT", gapW > 0 and distW > 0 and -4 or 0, 0)
    local right = 6 + gapW + distW + (gapW > 0 and distW > 0 and 4 or 0)
      + ((gapW > 0 or distW > 0) and 4 or 0)
    r.hp:ClearAllPoints()
    r.hp:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", textX, 4)
    r.hp:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -right, 4)
    r.hpText:SetWidth(hpText and LabelWidth(r.hpText, "100%") or NONE)
    Place(r.hpText, "RIGHT", r.hp, "RIGHT", -3, 0)
    room.pip = 5 + pipW
    room.ally = room.pip + (S("status") and 4 or 0) + allyW
    room.spec = room.ally + (S("allies") and 3 or 0) + specW
    room.trinket = room.spec + (S("spec") and 3 or 0) + trinketW
  else
    r.gap:SetWidth(S("gap") and 42 or NONE)
    Place(r.gap, "BOTTOMRIGHT", -6, 5)
    r.dist:SetWidth(S("distance") and 28 or NONE)
    Place(r.dist, "RIGHT", r.gap, "LEFT", S("gap") and -10 or 0, 0)
    local pipW, trinketW, hpW = S("status") and 54 or NONE, S("trinket") and 18 or NONE, hpText and LabelWidth(r.hpText, "100%") or NONE
    r.pip:SetSize(pipW, 15)
    Place(r.pip, "TOPRIGHT", -5, -3)
    r.spec:SetWidth(80)
    r.spec:SetJustifyH("LEFT")
    Place(r.spec, "BOTTOMLEFT", textX, 5)
    -- Bar mode anchors spec to allyText. Detach it before reversing that
    -- dependency, or WoW rejects the temporary cycle and aborts layout.
    r.allyText:SetPoint("LEFT", r.spec, "RIGHT", 4, 0)
    r.allyText:SetWidth(30)
    r.allyText:SetJustifyH("LEFT")
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
  r.barRow = bar and not compact
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
  elseif r.barRow then
    -- The percentage sits on the bar: the top line ends at the first shown
    -- slot, as in the other layouts.
    edge = r.trinket:IsShown() and room.trinket or r.specText and r.spec:IsShown() and room.spec
      or r.hasAllies and r.allyText:IsShown() and room.ally or r.pip:IsShown() and room.pip
    edge = edge and edge + 4 or 14
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
  -- ui/Dock.lua; absent until a full restart after updating from a version
  -- without that file.
  if Core.Undock then Core.Undock(); Core.Dock() end
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

-- Refit translated columns on a live language switch; protected geometry
-- follows ApplyLayout's existing combat deferral. Standalone has no board.
ns.Localization.Watch(Core, function()
  if Core.frame then Core.ApplyStyle("layout") end
end)
