local _, ns = ...
local Core = ns.Core

Core.frame = CreateFrame("Frame", "WarboardFrame", UIParent, "BackdropTemplate")
Core.frame:SetSize(Core.WIDTH, Core.LIST_TOP + Core.PAD)
Core.frame:SetBackdrop({ bgFile = Core.WHITE, edgeFile = Core.WHITE, edgeSize = 1 })
Core.Backdrop(Core.frame)
Core.frame:SetMovable(true)
Core.frame:SetClampedToScreen(true)
Core.frame:EnableMouse(true)
Core.frame:RegisterForDrag("LeftButton")
Core.frame:SetScript("OnDragStart", function(self)
  if not Core.db.locked and not InCombatLockdown() then
    self:StartMoving()
  end
end)
Core.frame:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local p, _, rp, x, y = self:GetPoint()
  Core.pos.point = { p, rp, x, y }
end)
Core.head = {}
Core.frame:Hide()

-- Header: title and live state; battleground and roster count on the right.
local headBg = Core.Surface(Core.frame, "BORDER")
headBg:SetPoint("TOPLEFT", 1, -1)
headBg:SetPoint("TOPRIGHT", -1, -1)

local brand = Core.Fill(Core.frame, "ARTWORK", Core.ACCENT[1], Core.ACCENT[2], Core.ACCENT[3])

local title = Core.Text(Core.frame, "bold", 16)
Core.head.bg, Core.head.brand, Core.head.title = headBg, brand, title
title:SetPoint("LEFT", brand, "RIGHT", 6, 0)
title:SetText("WARBOARD")
title:SetTextColor(0.97, 0.97, 0.98)

Core.liveDot = Core.frame:CreateTexture(nil, "OVERLAY")
Core.liveDot:SetSize(6, 6)
Core.liveDot:SetTexture(Core.CIRCLE)
Core.liveDot:SetVertexColor(Core.ACCENT[1], Core.ACCENT[2], Core.ACCENT[3])
Core.liveDot:SetPoint("LEFT", title, "RIGHT", 8, 0)
Core.liveDotAnim = Core.Bounce(Core.liveDot, 1, 0.55, 1.5)
Core.liveText = Core.Text(Core.frame, "mono", 9)
Core.liveText:SetPoint("LEFT", Core.liveDot, "RIGHT", 4, 0)
Core.liveText:SetTextColor(Core.ACCENT[1], Core.ACCENT[2], Core.ACCENT[3])
Core.liveText:SetText("LIVE")

Core.subtitle = Core.Text(Core.frame, "semi", 11)
Core.subtitle:SetPoint("RIGHT", Core.frame, "TOPRIGHT", -Core.PAD - 1, -Core.HEAD_H / 2)
Core.subtitle:SetTextColor(Core.MUTED[1], Core.MUTED[2], Core.MUTED[3])
Core.subtitle:SetWidth(104)
Core.subtitle:SetJustifyH("RIGHT")

Core.lockIcon = Core.frame:CreateTexture(nil, "OVERLAY")
Core.lockIcon:SetSize(11, 11)
Core.lockIcon:SetPoint("RIGHT", Core.subtitle, "LEFT", -4, 0)
Core.lockIcon:SetTexture(Core.ICON_LOCK)
Core.lockIcon:Hide()
Core.Chrome(headBg, brand, title, Core.liveText, Core.subtitle)

-- Hero card: target details remain live; the main name follows the secure
-- click binding, with changed combat recommendations shown separately.
Core.hero = CreateFrame("Frame", nil, Core.frame)
do
  local bg = Core.Surface(Core.hero, "BACKGROUND")
  bg:SetAllPoints()
  Core.hero.strip = Core.Fill(Core.hero, "ARTWORK", 1, 1, 1)
  Core.hero.strip:SetPoint("TOPLEFT")
  Core.hero.strip:SetPoint("BOTTOMLEFT")
  Core.hero.strip:SetWidth(4)

  Core.hero.label = Core.Text(Core.hero, "mono", 9)
  Core.hero.label:SetPoint("TOPLEFT", 12, -5)
  Core.hero.name = Core.Text(Core.hero, "bold", 22)
  Core.hero.name:SetJustifyH("LEFT")
  Core.hero.sub = Core.Text(Core.hero, "medium", 11)
  Core.hero.sub:SetJustifyH("LEFT")
  Core.hero.sub:SetTextColor(Core.MUTED[1], Core.MUTED[2], Core.MUTED[3])
  Core.hero.detail = Core.Text(Core.hero, "semi", 11)
  Core.hero.detail:SetPoint("TOPLEFT", 12, -54)
  Core.hero.detail:SetPoint("RIGHT", -10, 0)
  Core.hero.detail:SetJustifyH("LEFT")
  Core.hero.detail:SetTextColor(0.8, 0.87, 0.93)

  Core.hero.unitText = Core.Text(Core.hero, "mono", 9)
  Core.hero.unitText:SetTextColor(Core.MUTED[1], Core.MUTED[2], Core.MUTED[3])
  Core.hero.unitText:SetText("YD")
  Core.hero.dist = Core.Text(Core.hero, "mono", 24)

  -- Proximity meter: more lit segments = closer (signal-strength style).
  Core.hero.meter = {}
  for s = 1, Core.METER_SEGS do
    local t = Core.Fill(Core.hero, "ARTWORK", 1, 1, 1)
    t:SetSize(9, 3)
    t:SetPoint("TOPRIGHT", Core.hero, "TOPRIGHT", -9 - (Core.METER_SEGS - s) * 11, -33)
    Core.hero.meter[s] = t
  end

  Core.hero.hp = CreateFrame("StatusBar", nil, Core.hero)
  Core.hero.hp:SetPoint("BOTTOMLEFT", 4, 0)
  Core.hero.hp:SetPoint("BOTTOMRIGHT")
  Core.StatusBar(Core.hero.hp)
  Core.hero.hp:SetMinMaxValues(0, 1)
  Core.hero.exec = Core.Border(Core.hero, 1, 0.15, 0.1, 1, 1)
  Core.hero.exec:SetAlpha(0)

  Core.hero.goFill = Core.Fill(Core.hero, "ARTWORK", 1, 0.1, 0.05, 1, 7)
  Core.hero.goFill:SetAllPoints()
  Core.hero.goFill:SetBlendMode("ADD")
  Core.hero.goFill:SetAlpha(0)
  Core.hero.goAnim = Core.Bounce(Core.hero.goFill, 0.03, 0.16, 0.6)
  Core.hero.labelAnim = Core.Bounce(Core.hero.label, 1, 0.65, 0.6)

  Core.hero.empty = Core.Text(Core.hero, "bold", 15)
  Core.hero.empty:SetTextColor(unpack(Core.THEME.colors.text))
  Core.hero.empty:SetText("Watching for an opening")
  Core.hero.emptySub = Core.Text(Core.hero, "medium", 11)
  Core.hero.emptySub:SetPoint("TOP", Core.hero.empty, "BOTTOM", 0, -3)
  Core.hero.emptySub:SetTextColor(unpack(Core.MUTED))
  Core.hero.emptySub:SetText("No observed enemy in reach")
end

do
  local sectionLabel = Core.Text(Core.frame, "mono", 9)
  sectionLabel:SetText("ENEMY PRIORITY")
  sectionLabel:SetTextColor(unpack(Core.MUTED))
  local sectionHint = Core.Text(Core.frame, "mono", 9)
  sectionHint:SetText("RANGE / PRIORITY")
  sectionHint:SetTextColor(unpack(Core.MUTED))
  local footer = Core.Text(Core.frame, "medium", 11)
  footer:SetPoint("BOTTOMLEFT", Core.PAD + 2, 7)
  footer:SetText("Left-click target   /   Right-click focus")
  footer:SetTextColor(unpack(Core.MUTED))
  Core.head.section, Core.head.hint, Core.head.footer = sectionLabel, sectionHint, footer
end
Core.LayoutHead(false)

-- Shared look for the other Warboard windows (the resurrection timers).
ns.UI = { Text = Core.Text, SetFace = Core.SetFace, Fill = Core.Fill, Surface = Core.Surface, Backdrop = Core.Backdrop, Chrome = Core.Chrome, StatusBar = Core.StatusBar, BarColor = function(...) return Core.BarColor(...) end, IsCompact = function() return Core.compact or false end, WHITE = Core.WHITE, INK = Core.INK, ACCENT = Core.ACCENT, MUTED = Core.MUTED, theme = Core.THEME }
