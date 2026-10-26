local _, ns = ...
local Core, Bounty = ns.Core, ns.Bounty

---------------------------------------------------------------------------
-- Bounty board widgets in the Warboard HUD style: flat buttons, inputs,
-- tabs and wanted cards. Plain frames (not secure): usable in combat.
---------------------------------------------------------------------------
local W = {}
Bounty.Widgets = W
ns.Widgets = W -- shared with the macros window

W.GOLD = Bounty.GOLD
W.STATE = {
  personal = { "PERSONAL", 0.58, 0.67, 0.76 },
  pending = { "PENDING", 1, 0.62, 0.2 },
  approved = { "GUILD", 1, 0.82, 0.1 },
}
local C = Core.THEME.colors

local function Fill(parent, layer, color, a, sub)
  return Core.Fill(parent, layer, color[1], color[2], color[3], a or 1, sub)
end

-- Flat button: color fill, brighter on hover, label in the HUD font.
function W.Button(parent, label, width, height, color, onClick)
  color = color or C.surface
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(width, height or 22)
  b.bg = Fill(b, "BACKGROUND", color, 0.9)
  b.bg:SetAllPoints()
  b.hover = Core.Fill(b, "BORDER", 1, 1, 1, 0.08)
  b.hover:SetAllPoints()
  b.hover:Hide()
  b.label = Core.Text(b, "semi", 12)
  b.label:SetPoint("CENTER")
  b.SetText = function(self, text) self.label:SetText(text); self.text = text end
  b:SetText(label)
  b:SetScript("OnEnter", function(self) self.hover:Show() end)
  b:SetScript("OnLeave", function(self) self.hover:Hide() end)
  b:SetScript("OnClick", onClick)
  return b
end

-- Recolor a flat button (fill and label).
function W.Paint(b, color, text)
  b.bg:SetColorTexture(color[1], color[2], color[3], 0.9)
  b.label:SetTextColor(unpack(text or C.text))
end

-- Single-line input on a dark well with a small caption above.
function W.Input(parent, width, caption)
  local e = CreateFrame("EditBox", nil, parent)
  e:SetSize(width, 24)
  e:SetAutoFocus(false)
  pcall(e.SetTextInsets, e, 7, 7, 0, 0)
  Core.SetFace(e, "semi", 13)
  e:SetTextColor(unpack(C.text))
  local well = Fill(e, "BACKGROUND", C.panel, 1)
  well:SetAllPoints()
  local line = Fill(e, "BORDER", C.border, 1)
  line:SetPoint("BOTTOMLEFT")
  line:SetPoint("BOTTOMRIGHT")
  line:SetHeight(1)
  e.focusLine = line
  e:SetScript("OnEditFocusGained", function() line:SetColorTexture(W.GOLD[1], W.GOLD[2], W.GOLD[3], 1) end)
  e:SetScript("OnEditFocusLost", function() line:SetColorTexture(C.border[1], C.border[2], C.border[3], 1) end)
  e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  e.caption = Core.Text(parent, "mono", 8)
  e.caption:SetPoint("BOTTOMLEFT", e, "TOPLEFT", 1, 3)
  e.caption:SetTextColor(unpack(C.muted))
  e.caption:SetText(caption)
  return e
end

-- Tab: label with a count and a gold underline when selected.
function W.Tab(parent, label, onClick)
  local t = CreateFrame("Button", nil, parent)
  t:SetSize(84, 26)
  t.label = Core.Text(t, "bold", 13)
  t.label:SetPoint("LEFT", 2, 1)
  t.count = Core.Text(t, "mono", 9)
  t.count:SetPoint("LEFT", t.label, "RIGHT", 4, 0)
  t.line = Fill(t, "ARTWORK", W.GOLD, 1)
  t.line:SetPoint("BOTTOMLEFT")
  t.line:SetPoint("BOTTOMRIGHT")
  t.line:SetHeight(2)
  t.label:SetText(label)
  t.text = label
  t:SetScript("OnClick", onClick)
  function t:Select(on)
    self.selected = on
    self.line:SetShown(on)
    if on then self.label:SetTextColor(unpack(C.text)) else self.label:SetTextColor(unpack(C.muted)) end
  end
  return t
end

-- Wanted card: state strip, portrait, name and realm, who placed it, note,
-- reward, status chip, last sighting and up to two action buttons.
function W.Card(parent, height)
  local r = CreateFrame("Frame", nil, parent)
  r:SetHeight(height)
  r.bg = Fill(r, "BACKGROUND", C.surface, 0.85)
  r.bg:SetAllPoints()
  r.hover = Core.Fill(r, "BORDER", 1, 1, 1, 0.04)
  r.hover:SetAllPoints()
  r.hover:Hide()
  r.strip = Fill(r, "ARTWORK", W.GOLD, 1)
  r.strip:SetPoint("TOPLEFT")
  r.strip:SetPoint("BOTTOMLEFT")
  r.strip:SetWidth(3)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(32, 32)
  r.icon:SetPoint("LEFT", 12, 0)
  r.name = Core.Text(r, "bold", 17)
  r.name:SetPoint("TOPLEFT", 52, -6)
  r.realm = Core.Text(r, "medium", 12)
  r.realm:SetPoint("BOTTOMLEFT", r.name, "BOTTOMRIGHT", 4, 1)
  r.realm:SetTextColor(unpack(C.muted))
  r.sub = Core.Text(r, "mono", 9)
  r.sub:SetPoint("BOTTOMLEFT", 52, 7)
  r.sub:SetPoint("RIGHT", r, "RIGHT", -330, 0)
  r.sub:SetJustifyH("LEFT")
  r.sub:SetTextColor(unpack(C.muted))

  r.chip = CreateFrame("Frame", nil, r)
  r.chip:SetSize(62, 15)
  r.chip:SetPoint("TOPRIGHT", r, "TOPRIGHT", -150, -8)
  r.chipBg = Core.Fill(r.chip, "BACKGROUND", 1, 1, 1, 0.15)
  r.chipBg:SetAllPoints()
  r.tag = Core.Text(r.chip, "mono", 8)
  r.tag:SetPoint("CENTER", 0, 0)
  r.seen = Core.Text(r, "mono", 8)
  r.seen:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -150, 8)
  r.seen:SetJustifyH("RIGHT")

  r.gold = Core.Text(r, "bold", 22)
  r.gold:SetPoint("RIGHT", r, "RIGHT", -170 - 62 - 6, 2)
  r.gold:SetTextColor(W.GOLD[1], W.GOLD[2], W.GOLD[3])
  r.coin = r:CreateTexture(nil, "ARTWORK")
  r.coin:SetSize(14, 14)
  r.coin:SetPoint("LEFT", r.gold, "RIGHT", 3, 0)
  r.coin:SetTexture(Bounty.ICON)
  r.coin:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  r.buttons = {}
  for j = 1, 2 do
    local b = W.Button(r, "", 66, 20, C.panel, function(self) if self.run then self.run() end end)
    b:SetPoint("RIGHT", r, "RIGHT", -8 - (2 - j) * 70, 0)
    r.buttons[j] = b
  end
  r:EnableMouse(true)
  r:SetScript("OnEnter", function(self)
    self.hover:Show()
    if W.CardTooltip then W.CardTooltip(self) end
  end)
  r:SetScript("OnLeave", function(self) self.hover:Hide(); GameTooltip_Hide() end)
  r:Hide()
  return r
end

function W.Ago(seconds)
  seconds = math.max(0, math.floor(seconds))
  if seconds < 60 then return "NOW" end
  if seconds < 3600 then return math.floor(seconds / 60) .. "M AGO" end
  if seconds < 86400 then return math.floor(seconds / 3600) .. "H AGO" end
  return math.floor(seconds / 86400) .. "D AGO"
end
