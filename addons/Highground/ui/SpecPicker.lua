local _, ns = ...
local Core = ns.Core
local Theme = ns.Theme

-- Spec picker: hovering an enemy row whose spec the game hasn't identified
-- shows that class's talent-tree icons at the row's right edge. A click tags
-- the spec, a click on the tagged one removes it (core/SpecTags.lua shares
-- both with the team). Plain buttons over the secure row: they work in
-- combat and never touch the row's target and focus clicks.
local MAX = 4 -- talent trees per class
local picker = CreateFrame("Frame", nil, Core.frame)
picker:Hide()
picker.bg = Theme.Fill(picker, "BACKGROUND", "surface", 0.94)
picker.bg:SetAllPoints()
picker.buttons = {}
Core.specPicker = picker

local function ButtonTooltip(b)
  local e = picker.row and picker.row.entry
  local si = b.specID and Core.specInfo[b.specID]
  if not (e and si) then return end
  GameTooltip:SetOwner(b, "ANCHOR_TOP")
  Theme.TipLine(GameTooltip, si.name .. " " .. ns.Util.ClassName(e.class), "text")
  local tagged = e.specSrc == "tag" and e.specID == b.specID
  Theme.TipLine(GameTooltip, tagged and ns.Locale:Get("highground.specpicker.click_to_remove")
    or ns.Locale:Get("highground.specpicker.click_to_tag"), "textMuted", true)
  GameTooltip:Show()
end

for i = 1, MAX do
  local b = CreateFrame("Button", nil, picker)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetAllPoints()
  b.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
  b.ring = Core.TokenBorder(b, "accent")
  b.ring:Hide()
  b:SetScript("OnClick", function(self)
    local e = picker.row and picker.row.entry
    if e and self.tree then Core.SetSpecTag(e, self.tree) end
    Core.RefreshSpecPicker()
    ButtonTooltip(self)
  end)
  b:SetScript("OnEnter", ButtonTooltip)
  b:SetScript("OnLeave", GameTooltip_Hide)
  picker.buttons[i] = b
end

local function Hovered()
  local row = picker.row
  if not row then return false end
  if row:IsMouseOver() or picker:IsMouseOver() then return true end
  for _, b in ipairs(picker.buttons) do
    if b:IsShown() and b:IsMouseOver() then return true end
  end
  return false
end

function Core.HideSpecPicker()
  picker.row, picker.pinned = nil, nil
  picker:Hide()
end

-- Lay the picker over row r for its enemy, or hide it when there is
-- nothing to tag (no enemy, or the game already knows the spec).
function Core.ShowSpecPicker(r, pinned)
  local e = r and r.entry
  local specs = e and Core.SpecTaggable(e) and Core.classSpecs[e.class]
  if not specs then return Core.HideSpecPicker() end
  picker.row, picker.pinned = r, pinned or nil
  local size = math.max(12, math.min(20, (Core.ROW_H or 30) - 10))
  local n = math.min(#specs, MAX)
  picker:ClearAllPoints()
  picker:SetPoint("RIGHT", r, "RIGHT", -4, 0)
  picker:SetSize(n * (size + 3) + 3, size + 6)
  picker:SetFrameLevel(r:GetFrameLevel() + 12)
  for i, b in ipairs(picker.buttons) do
    local id = i <= n and specs[i]
    local si = id and Core.specInfo[id]
    b.tree, b.specID = si and i or nil, si and id or nil
    if si then
      b:SetSize(size, size)
      b:ClearAllPoints()
      b:SetPoint("LEFT", picker, "LEFT", 3 + (i - 1) * (size + 3), 0)
      b.icon:SetTexture(si.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    end
    b:SetShown(si and true or false)
  end
  picker:Show()
  Core.RefreshSpecPicker()
end

-- The tagged tree stands out; the others stay quiet until chosen.
function Core.RefreshSpecPicker()
  local r = picker.row
  local e = r and r.entry
  if not picker:IsShown() then return end
  if not (e and r:IsShown() and Core.SpecTaggable(e)) then return Core.HideSpecPicker() end
  local tagged = e.specSrc == "tag" and e.specID or nil
  for _, b in ipairs(picker.buttons) do
    local on = tagged ~= nil and b.specID == tagged
    b.ring:SetShown(on)
    b.icon:SetDesaturated(tagged ~= nil and not on)
    b:SetAlpha((tagged == nil or on) and 1 or 0.55)
  end
end

picker:SetScript("OnUpdate", function()
  if picker.pinned and Core.guidedTest then return end
  if not Hovered() then Core.HideSpecPicker() end
end)

for _, r in ipairs(Core.rows) do
  r:HookScript("OnEnter", function(self) Core.ShowSpecPicker(self) end)
end
