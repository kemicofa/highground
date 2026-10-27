local _, ns = ...
local Core = ns.Core
local Theme = ns.Theme

Core.frame = CreateFrame("Frame", "WarboardFrame", UIParent, "BackdropTemplate")
Core.frame:SetSize(Core.WIDTH, Core.LIST_TOP + Core.PAD)
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

local brand = Theme.Fill(Core.frame, "ARTWORK", "accent")

local title = Theme.Text(Core.frame, "title")
Core.head.bg, Core.head.brand, Core.head.title = headBg, brand, title
title:SetPoint("LEFT", brand, "RIGHT", 6, 0)
title:SetText("WARBOARD")

Core.liveDot = Core.frame:CreateTexture(nil, "OVERLAY")
Core.liveDot:SetSize(6, 6)
Core.liveDot:SetTexture(Core.CIRCLE)
Theme.Tint(Core.liveDot, "accent")
Core.liveDot:SetPoint("LEFT", title, "RIGHT", 8, 0)
Core.liveDotAnim = Core.Bounce(Core.liveDot, 1, 0.55, 1.5)
Core.liveText = Theme.Text(Core.frame, "label", "accent")
Core.liveText:SetPoint("LEFT", Core.liveDot, "RIGHT", 4, 0)
Core.liveText:SetText("LIVE")

Core.subtitle = Theme.Text(Core.frame, "detail", "textMuted")
Core.subtitle:SetPoint("RIGHT", Core.frame, "TOPRIGHT", -Core.PAD - 1, -Core.HEAD_H / 2)
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
  Core.hero.strip = Theme.Fill(Core.hero, "ARTWORK", "border")
  Core.hero.strip:SetPoint("TOPLEFT")
  Core.hero.strip:SetPoint("BOTTOMLEFT")
  Core.hero.strip:SetWidth(4)

  Core.hero.label = Theme.Text(Core.hero, "label", "accent")
  Core.hero.label:SetPoint("TOPLEFT", 12, -5)
  Core.hero.name = Theme.Text(Core.hero, "number")
  Core.hero.name:SetJustifyH("LEFT")
  Core.hero.sub = Theme.Text(Core.hero, "body", "textMuted")
  Core.hero.sub:SetJustifyH("LEFT")
  Core.hero.detail = Theme.Text(Core.hero, "detail")
  Core.hero.detail:SetPoint("TOPLEFT", 12, -54)
  Core.hero.detail:SetPoint("RIGHT", -10, 0)
  Core.hero.detail:SetJustifyH("LEFT")

  Core.hero.unitText = Theme.Text(Core.hero, "label", "textMuted")
  Core.hero.unitText:SetText("YD")
  Core.hero.dist = Theme.Text(Core.hero, "readout")

  -- Proximity meter: more lit segments = closer (signal-strength style).
  Core.hero.meter = {}
  for s = 1, Core.METER_SEGS do
    local t = Theme.Fill(Core.hero, "ARTWORK", "overlaySelected")
    t:SetSize(9, 3)
    t:SetPoint("TOPRIGHT", Core.hero, "TOPRIGHT", -9 - (Core.METER_SEGS - s) * 11, -33)
    Core.hero.meter[s] = t
  end

  Core.hero.hp = CreateFrame("StatusBar", nil, Core.hero)
  Core.hero.hp:SetPoint("BOTTOMLEFT", 4, 0)
  Core.hero.hp:SetPoint("BOTTOMRIGHT")
  Core.StatusBar(Core.hero.hp)
  Core.hero.hp:SetMinMaxValues(0, 1)
  Core.hero.exec = Core.TokenBorder(Core.hero, "kill")
  Core.hero.exec:SetAlpha(0)

  Core.hero.goFill = Theme.Fill(Core.hero, "ARTWORK", "kill", nil, 7)
  Core.hero.goFill:SetAllPoints()
  Core.hero.goFill:SetBlendMode("ADD")
  Core.hero.goFill:SetAlpha(0)
  Core.hero.goAnim = Core.Bounce(Core.hero.goFill, 0.03, 0.16, 0.6)
  Core.hero.labelAnim = Core.Bounce(Core.hero.label, 1, 0.65, 0.6)

  Core.hero.empty = Theme.Text(Core.hero, "cardName")
  Core.hero.empty:SetText("Watching for an opening")
  Core.hero.emptySub = Theme.Text(Core.hero, "body", "textMuted")
  Core.hero.emptySub:SetPoint("TOP", Core.hero.empty, "BOTTOM", 0, -3)
  Core.hero.emptySub:SetText("No observed enemy in reach")
end

do
  local sectionLabel = Theme.Text(Core.frame, "label", "textMuted")
  sectionLabel:SetText("ENEMY PRIORITY")
  local sectionHint = Theme.Text(Core.frame, "label", "textMuted")
  sectionHint:SetText("RANGE / PRIORITY")
  local footer = Theme.Text(Core.frame, "body", "textMuted")
  footer:SetPoint("BOTTOMLEFT", Core.PAD + 2, 7)
  footer:SetText("Left-click target   /   Right-click focus")
  Core.head.section, Core.head.hint, Core.head.footer = sectionLabel, sectionHint, footer
end
Core.LayoutHead(false)

-- Shared look for older callers; new code uses ns.Theme and ns.Kit. The
-- colour fields are the live theme tokens.
ns.UI = {
  Text = Core.Text, SetFace = Core.SetFace, Fill = Core.Fill, Surface = Core.Surface, Backdrop = Core.Backdrop,
  Chrome = Core.Chrome, StatusBar = Core.StatusBar, BarColor = function(...) return Core.BarColor(...) end,
  IsCompact = function() return Core.compact or false end, WHITE = Core.WHITE,
  INK = Theme.Rgb("bg"), ACCENT = Theme.Rgb("accent"), MUTED = Theme.Rgb("textMuted"), theme = Core.THEME,
}
