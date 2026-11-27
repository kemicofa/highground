local _, ns = ...
local Core, Kit, Theme = ns.Core, ns.Kit, ns.Theme

---------------------------------------------------------------------------
-- Team icon picker: class, role and other icons, then No icon, Automatic
-- and Cancel. One at a time, beside a Team icons row or at the cursor
-- (ui/TeamIcons.lua). It only reports the choice: an icon, "none" (no icon
-- even with an automatic rule) or nil (back to the automatic icon, or no
-- icon without a rule).
---------------------------------------------------------------------------
local Picker = {}
ns.TeamIconPicker = Picker
local COLUMNS, CELL, PAD = 8, 30, 4
local P

local function Choose(icon)
  local pick = P and P.onPick
  P:Hide()
  if pick then pick(icon) end
end

local function IconButton(parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(CELL, CELL)
  b.badge = Core.MakeTeamIcon(b, CELL)
  b.badge:SetAllPoints()
  b.badge:Show()
  b.selected = Core.TokenBorder(b, "accent")
  b.selected:Hide()
  local hover = Theme.Fill(b, "HIGHLIGHT", "white", 0.18)
  hover:SetAllPoints()
  b:SetScript("OnClick", function(self) Choose(self.icon) end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    Theme.TipLine(GameTooltip, Core.TeamIconName(self.icon) or "", "text")
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  return b
end

local SECTIONS = {
  { title = "highground.teamicons.class.41ff35", icons = function() return Core.TeamIconClasses() end },
  { title = "highground.teamicons.role.c3f104", icons = function() return Core.TEAM_ICON_ROLES end },
  { title = "highground.teamicons.other.6e6a6f", icons = function() return Core.TEAM_ICON_OTHERS end },
}

local function Button(key, width, onClick)
  local b = Kit.Button(P, ns.Locale:Get(key), width)
  ns.Localization.Bind(b, key)
  b:SetScript("OnClick", onClick)
  return b
end

local function Build()
  if P then return P end
  P = CreateFrame("Frame", "HighgroundTeamIconPicker", UIParent)
  Picker.frame = P
  P:SetFrameStrata("DIALOG")
  P:SetClampedToScreen(true)
  P:EnableMouse(true)
  Theme.Backdrop(P)
  P:Hide()
  table.insert(UISpecialFrames, "HighgroundTeamIconPicker")
  local inner = COLUMNS * (CELL + PAD) - PAD
  local md = Theme.Space("md")
  P.title = Theme.Text(P, "label", "text")
  P.title:SetPoint("TOPLEFT", md, -md)
  P.title:SetPoint("RIGHT", -md, 0)
  P.title:SetJustifyH("LEFT")
  P.buttons = {}
  local y = -md - 20
  for _, section in ipairs(SECTIONS) do
    local caption = Kit.Caption(P, ns.Locale:Get(section.title))
    Kit.OnLocale(caption, function(fs) fs:SetText(ns.Text.Upper(ns.Locale:Get(section.title))) end)
    caption:SetPoint("TOPLEFT", md, y)
    y = y - 16
    local icons = section.icons()
    for i, icon in ipairs(icons) do
      local b = IconButton(P)
      b.icon = icon
      Core.PaintTeamIcon(b.badge, icon, 1)
      local col, row = (i - 1) % COLUMNS, math.floor((i - 1) / COLUMNS)
      b:SetPoint("TOPLEFT", md + col * (CELL + PAD), y - row * (CELL + PAD))
      P.buttons[#P.buttons + 1] = b
    end
    y = y - math.ceil(#icons / COLUMNS) * (CELL + PAD) - Theme.Space("xs")
  end
  local third = (inner - PAD * 2) / 3
  P.none = Button("highground.teamicons.no_icon.95553b", third, function() Choose(P.auto and "none" or nil) end)
  P.none:SetPoint("TOPLEFT", md, y - Theme.Space("xs"))
  P.automatic = Button("highground.teamicons.automatic.ac9041", third, function() Choose(nil) end)
  P.automatic:SetPoint("LEFT", P.none, "RIGHT", PAD, 0)
  P.cancel = Button("highground.teamicons.cancel.77dfd2", third, function() P.onPick = nil; P:Hide() end)
  P.cancel:SetPoint("LEFT", P.automatic, "RIGHT", PAD, 0)
  P:SetSize(inner + md * 2, -y + Theme.Space("xs") + P.none:GetHeight() + md)
  P:SetScript("OnHide", function() P.onPick = nil end)
  return P
end

-- Open for a teammate: name, their current icon, whether an automatic
-- rule is on (enables Automatic), and onPick(choice). Beside anchor, or
-- at the cursor without one.
function Picker.Open(name, current, auto, onPick, anchor)
  local p = Build()
  p.onPick, p.auto = onPick, auto and true or false
  p.title:SetText(name or "")
  for _, b in ipairs(p.buttons) do b.selected:SetShown(current ~= nil and current == b.icon) end
  p.automatic:SetEnabled(p.auto)
  p:ClearAllPoints()
  if anchor then
    p:SetPoint("TOPLEFT", anchor, "TOPRIGHT", Theme.Space("sm"), 0)
  else
    local x, y = ns.Util.call(GetCursorPosition)
    local scale = UIParent:GetEffectiveScale()
    if type(x) == "number" and type(y) == "number" and scale > 0 then
      p:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    else
      p:SetPoint("CENTER")
    end
  end
  p:Show()
end

function Picker.Shown() return P ~= nil and P:IsShown() end
function Picker.Hide() if P then P:Hide() end end
