local _, ns = ...
local Theme = ns.Theme

---------------------------------------------------------------------------
-- UI kit (ns.Kit), Warboard flat HUD style: buttons, inputs, tabs,
-- captions, chips and cards. Every colour, font and size is a token
-- (config/Theme.lua), so the kit follows theme switches. Plain frames (not
-- secure): usable in combat.
---------------------------------------------------------------------------
local Kit = ns.Kit or {}
ns.Kit = Kit
local S, Z = Theme.Space, Theme.Size

-- Button tones: fill token and label token.
Kit.TONES = {
  surface = { fill = "surface", text = "text" },
  panel = { fill = "bg", text = "text" },
  accent = { fill = "accent", text = "onAccent" },
  gold = { fill = "gold", text = "onAccent" },
  danger = { fill = "danger", text = "onAccent" },
}

-- Recolour a Kit.Button. fill: a tone name, a colour token or a colour
-- table; text: a colour token or table (default: the tone's, else "text").
function Kit.Paint(b, fill, text)
  local tone = type(fill) == "string" and Kit.TONES[fill]
  b.tone = tone and fill or nil
  Theme.Paint(b.bg, tone and tone.fill or fill or "surface", "button")
  Theme.Paint(b.label, text or (tone and tone.text) or "text")
end

-- Disabled buttons are dimmed, ignore clicks and show no hover.
local disabled = setmetatable({}, { __mode = "k" })
local function SetEnabled(b, on)
  on = on ~= false and on ~= nil
  if on then b:wbEnable() else b:wbDisable() end
  b.wbDisabled = not on
  disabled[b] = not on or nil
  b:SetAlpha(on and 1 or Theme.Alpha("disabled"))
  if not on then b.hover:Hide() end
end
local function Enable(b) SetEnabled(b, true) end
local function Disable(b) SetEnabled(b, false) end
local function IsEnabled(b) return not b.wbDisabled end
Theme.OnChange(function()
  for b in pairs(disabled) do b:SetAlpha(Theme.Alpha("disabled")) end
end)

-- Flat button: fill, lighter on hover, label in the control font.
-- opts: tone or fill (see Kit.Paint), text, onClick(self, button).
-- :SetEnabled(on), :Enable(), :Disable(), :IsEnabled().
function Kit.Button(parent, label, width, height, opts)
  opts = opts or {}
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(width or Z("tabWidth"), height or Z("control"))
  b.bg = Theme.Fill(b, "BACKGROUND", "surface")
  b.bg:SetAllPoints()
  b.hover = Theme.Fill(b, "BORDER", "overlayHover")
  b.hover:SetAllPoints()
  b.hover:Hide()
  b.label = Theme.Text(b, "control")
  b.label:SetPoint("CENTER")
  b.SetText = function(self, text) self.label:SetText(text); self.text = text end
  b:SetText(label)
  Kit.Paint(b, opts.tone or opts.fill or "surface", opts.text)
  b:SetScript("OnEnter", function(self) if not self.wbDisabled then self.hover:Show() end end)
  b:SetScript("OnLeave", function(self) self.hover:Hide() end)
  b:SetScript("OnClick", opts.onClick)
  b.wbEnable, b.wbDisable = b.Enable, b.Disable
  b.SetEnabled, b.Enable, b.Disable, b.IsEnabled = SetEnabled, Enable, Disable, IsEnabled
  return b
end

-- Single-line input on a dark well, gold underline while focused, small
-- caption above.
function Kit.Input(parent, width, caption)
  local e = CreateFrame("EditBox", nil, parent)
  e:SetSize(width, Z("input"))
  e:SetAutoFocus(false)
  pcall(e.SetTextInsets, e, S("md") - 1, S("md") - 1, 0, 0)
  Theme.SetRole(e, "input")
  Theme.Paint(e, "text")
  local well = Theme.Fill(e, "BACKGROUND", "bg")
  well:SetAllPoints()
  local line = Theme.Fill(e, "BORDER", "border")
  line:SetPoint("BOTTOMLEFT")
  line:SetPoint("BOTTOMRIGHT")
  line:SetHeight(Z("line"))
  e.focusLine = line
  e:SetScript("OnEditFocusGained", function() Theme.Paint(line, "gold") end)
  e:SetScript("OnEditFocusLost", function() Theme.Paint(line, "border") end)
  e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  e.caption = Theme.Text(parent, "caption", "textMuted")
  e.caption:SetPoint("BOTTOMLEFT", e, "TOPLEFT", 1, S("xs") + 1)
  e.caption:SetText(caption)
  return e
end

-- Tab: label with a count and a gold underline when selected.
function Kit.Tab(parent, label, onClick)
  local t = CreateFrame("Button", nil, parent)
  t:SetSize(Z("tabWidth"), Z("tab"))
  t.label = Theme.Text(t, "heading")
  t.label:SetPoint("LEFT", S("xs"), 1)
  t.count = Theme.Text(t, "label")
  t.count:SetPoint("LEFT", t.label, "RIGHT", S("sm"), 0)
  Theme.Unpaint(t.count) -- owners colour the count
  t.line = Theme.Fill(t, "ARTWORK", "gold")
  t.line:SetPoint("BOTTOMLEFT")
  t.line:SetPoint("BOTTOMRIGHT")
  t.line:SetHeight(Z("underline"))
  t.label:SetText(label)
  t.text = label
  t:SetScript("OnClick", onClick)
  function t:Select(on)
    self.selected = on
    self.line:SetShown(on)
    Theme.Paint(self.label, on and "text" or "textMuted")
  end
  return t
end

-- Uppercase mono caption (field labels, group titles).
function Kit.Caption(parent, text, color)
  local fs = Theme.Text(parent, "caption", color or "textMuted")
  fs:SetJustifyH("LEFT")
  fs:SetText(text and text:upper() or "")
  return fs
end

-- Section title: uppercase label with a rule to its right (fs.rule; it
-- reaches the parent's right edge, re-anchor it if needed).
function Kit.Section(parent, text)
  local fs = Theme.Text(parent, "label", "textMuted")
  fs:SetJustifyH("LEFT")
  fs:SetText(text and text:upper() or "")
  fs.rule = Theme.Fill(parent, "ARTWORK", "border")
  fs.rule:SetHeight(Z("line"))
  fs.rule:SetPoint("LEFT", fs, "RIGHT", S("md"), 0)
  fs.rule:SetPoint("RIGHT", parent, "RIGHT", -S("md"), 0)
  return fs
end

-- Status chip: tinted backing and caption in one colour. chip:Set(text, color).
function Kit.Chip(parent, text, color, width)
  local c = CreateFrame("Frame", nil, parent)
  c:SetSize(width or Z("chipWidth"), Z("chip"))
  c.bg = Theme.Fill(c, "BACKGROUND", "overlayStrong")
  c.bg:SetAllPoints()
  c.label = Theme.Text(c, "caption")
  c.label:SetPoint("CENTER", 0, 0)
  function c:Set(value, tint)
    self.text = value or ""
    self.label:SetText(self.text)
    if tint then
      Theme.Paint(self.label, tint)
      Theme.Paint(self.bg, tint, "chip")
    end
  end
  c:Set(text, color)
  return c
end

-- Base card: colour strip, optional portrait, title over sub line, and a
-- right-hand area (card.right) for numbers or buttons.
-- opts: strip (colour token, "accent"), icon (true: portrait at left),
-- titleRole ("heading"), rightWidth (0), onEnter(self), onLeave(self).
function Kit.Card(parent, height, opts)
  opts = opts or {}
  local r = CreateFrame("Frame", nil, parent)
  r:SetHeight(height)
  r.bg = Theme.Fill(r, "BACKGROUND", "surface", "card")
  r.bg:SetAllPoints()
  r.hover = Theme.Fill(r, "BORDER", "overlaySubtle")
  r.hover:SetAllPoints()
  r.hover:Hide()
  r.strip = Theme.Fill(r, "ARTWORK", opts.strip or "accent")
  r.strip:SetPoint("TOPLEFT")
  r.strip:SetPoint("BOTTOMLEFT")
  r.strip:SetWidth(Z("strip"))
  local x = S("lg")
  if opts.icon then
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(Z("portrait"), Z("portrait"))
    r.icon:SetPoint("LEFT", S("lg"), 0)
    x = S("lg") + Z("portrait") + S("md")
  end
  r.right = CreateFrame("Frame", nil, r)
  r.right:SetPoint("TOPRIGHT", -S("md"), 0)
  r.right:SetPoint("BOTTOMRIGHT", -S("md"), 0)
  r.right:SetWidth(opts.rightWidth or 0)
  r.title = Theme.Text(r, opts.titleRole or "heading")
  r.title:SetPoint("TOPLEFT", x, -(S("sm") + S("xs")))
  r.title:SetJustifyH("LEFT")
  r.sub = Theme.Text(r, "label", "textMuted")
  r.sub:SetPoint("BOTTOMLEFT", x, S("md"))
  r.sub:SetPoint("RIGHT", r.right, "LEFT", -S("md"), 0)
  r.sub:SetJustifyH("LEFT")
  function r:SetStrip(color) Theme.Paint(self.strip, color) end
  r:EnableMouse(true)
  r:SetScript("OnEnter", function(self)
    self.hover:Show()
    if opts.onEnter then opts.onEnter(self) end
  end)
  r:SetScript("OnLeave", function(self)
    self.hover:Hide()
    if opts.onLeave then opts.onLeave(self) end
  end)
  return r
end
