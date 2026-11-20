local _, ns = ...
local Theme, Motion = ns.Theme, ns.Motion

---------------------------------------------------------------------------
-- UI kit (ns.Kit), Highground command style: buttons, inputs, tabs,
-- captions, chips and cards. Every colour, font and size is a token
-- (config/Theme.lua), so the kit follows theme switches. Plain frames (not
-- secure): usable in combat.
---------------------------------------------------------------------------
local Kit = ns.Kit or {}
ns.Kit = Kit
local S, Z = Theme.Space, Theme.Size

-- Control rims sit inside the hit area, above neighboring faces and glow
-- frames. They remain decorative and inherit their owner's clipping.
function Kit.BorderLayer(parent, inset)
  local layer = CreateFrame("Frame", nil, parent)
  layer:SetPoint("TOPLEFT", inset, -inset); layer:SetPoint("BOTTOMRIGHT", -inset, inset)
  layer:SetFrameLevel((parent:GetFrameLevel() or 0) + 2)
  layer:EnableMouse(false)
  return layer
end

-- Inset edges stay within the hit area and repaint with the palette.
function Kit.Outline(parent, token, inset)
  inset = inset or 0
  local edge = {}
  for i, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local t = Theme.Fill(parent, "OVERLAY", token)
    if i <= 2 then
      local y = i == 1 and -inset or inset
      t:SetPoint(side .. "LEFT", inset, y); t:SetPoint(side .. "RIGHT", -inset, y); t:SetHeight(Z("line"))
    else
      local x = i == 3 and inset or -inset
      t:SetPoint("TOP" .. side, x, -inset); t:SetPoint("BOTTOM" .. side, x, inset); t:SetWidth(Z("line"))
    end
    edge[i] = t
  end
  function edge:SetColor(color) for _, t in ipairs(self) do Theme.Paint(t, color) end end
  function edge:SetShown(on) for _, t in ipairs(self) do t:SetShown(on) end end
  return edge
end

-- Palette-controlled relief. Only the perimeter catches light; text and
-- icons keep a solid backing. Flat themes set both alpha tokens to zero.
function Kit.Bevel(parent, inset, radius)
  local edges = Kit.Outline(parent, "white", inset or 1)
  for i, edge in ipairs(edges) do
    local light = i == 1 or i == 3
    Theme.Paint(edge, light and "metalHighlight" or "metalShadow", light and "bevelLight" or "bevelShade")
    if radius then
      edge:ClearAllPoints()
      local side = ({ "TOP", "BOTTOM", "LEFT", "RIGHT" })[i]
      if i <= 2 then
        local y = i == 1 and -(inset or 1) or (inset or 1)
        edge:SetPoint(side .. "LEFT", radius, y); edge:SetPoint(side .. "RIGHT", -radius, y)
      else
        local x = i == 3 and (inset or 1) or -(inset or 1)
        edge:SetPoint("TOP" .. side, x, -radius); edge:SetPoint("BOTTOM" .. side, x, radius)
      end
    end
  end
  return edges
end

-- Button tones: fill token and label token.
Kit.TONES = {
  surface = { fill = "surface", text = "text" },
  panel = { fill = "bg", text = "text" },
  accent = { fill = "accent", text = "onAccent" },
  gold = { fill = "gold", text = "onAccent" },
  danger = { fill = "danger", text = "onAccent" },
  selected = { fill = "surfaceRaised", text = "accent" },
}

-- Recolour a Kit.Button. fill: a tone name, a colour token or a colour
-- table; text: a colour token or table (default: the tone's, else "text").
function Kit.Paint(b, fill, text)
  local tone = type(fill) == "string" and Kit.TONES[fill]
  b.tone = tone and fill or nil
  Kit.PaintFill(b.bg, tone and tone.fill or fill or "surface", "button")
  Theme.Paint(b.label, text or (tone and tone.text) or "text")
  if b.selectedMark then Motion.Mark(b.selectedMark, fill == "selected" and not b.choiceMark and not b.isTab) end
  if b.RefreshFinish then b:RefreshFinish() end
end

-- Disabled buttons are dimmed, ignore clicks and show no hover.
local disabled = setmetatable({}, { __mode = "k" })
local function SetEnabled(b, on)
  on = on ~= false and on ~= nil
  if on then b:wbEnable() else b:wbDisable() end
  b.wbDisabled, b.enabled = not on, on
  disabled[b] = not on or nil
  b:SetAlpha(on and 1 or Theme.Alpha("disabled"))
  if not on then b:ResetFeedback() end
  if b.RefreshFinish then b:RefreshFinish(true) end
end
local function Enable(b) SetEnabled(b, true) end
local function Disable(b) SetEnabled(b, false) end
local function IsEnabled(b) return not b.wbDisabled end
Theme.OnChange(function()
  for b in pairs(disabled) do b:SetAlpha(Theme.Alpha("disabled")) end
end)

-- Buttons and toggles use the same native, visual and interaction state,
-- including callers that use Enable/Disable instead of SetEnabled.
function Kit.EnableControl(b)
  b.wbEnable, b.wbDisable = b.Enable, b.Disable
  b.SetEnabled, b.Enable, b.Disable, b.IsEnabled = SetEnabled, Enable, Disable, IsEnabled
end

-- Raised button: bevel, illuminated edge, light sweep and a stable hit area.
-- opts: tone or fill (see Kit.Paint), text, onClick(self, button).
-- :SetEnabled(on), :Enable(), :Disable(), :IsEnabled().
function Kit.Button(parent, label, width, height, opts)
  opts = opts or {}
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(width or Z("tabWidth"), height or Z("control"))
  b.cornerRadius = Z("controlRadius")
  b.bg = Kit.RoundedFill(b, "surface", "button")
  b.hover = Kit.RoundedFill(b, "overlayHover", nil, "BORDER")
  b.edge = Kit.RoundedOutline(b, "controlBorder")
  b.bevel = Kit.Bevel(b, Z("line") * 2, b.cornerRadius)
  b.selectedMark = Theme.Fill(b, "ARTWORK", "accent")
  b.selectedMark:SetPoint("TOPLEFT", 2, -b.cornerRadius)
  b.selectedMark:SetPoint("BOTTOMLEFT", 2, b.cornerRadius)
  b.selectedMark:SetWidth(Z("strip"))
  b.selectedMark:Hide()
  b.label = Theme.Text(b, "control")
  b.label:SetPoint("CENTER")
  b.SetText = function(self, text) self.label:SetText(text); self.text = text end
  b:SetText(label)
  Kit.Paint(b, opts.tone or opts.fill or "surface", opts.text)
  Kit.Feedback(b, { press = true, edge = b.edge })
  if Kit.ButtonFinish then Kit.ButtonFinish(b) end
  b:SetScript("OnClick", opts.onClick)
  Kit.EnableControl(b)
  return b
end

-- Single-line input on a well, a two-pixel focus underline, small
-- caption above. opts: placeholder, onChange(self, text, userInput).
-- Use HookScript for additional text handlers to retain the placeholder.
function Kit.Input(parent, width, caption, opts)
  opts = opts or {}
  local e = CreateFrame("EditBox", nil, parent)
  e:SetSize(width, Z("input"))
  e:SetAutoFocus(false)
  pcall(e.SetTextInsets, e, S("md") - 1, S("md") - 1, 0, 0)
  Theme.SetRole(e, "input")
  Theme.Paint(e, "text")
  local well = Theme.Fill(e, "BACKGROUND", "well")
  well:SetAllPoints()
  e.edge = Kit.Outline(e, "controlBorder")
  local line = Theme.Fill(e, "OVERLAY", "focus")
  line:SetPoint("BOTTOMLEFT")
  line:SetPoint("BOTTOMRIGHT")
  line:SetHeight(Z("underline"))
  line:Hide()
  e.focusLine = line
  Kit.Focus(e, e.edge, line)
  e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  e.caption = Theme.Text(parent, "caption", "textMuted")
  e.caption:SetPoint("BOTTOMLEFT", e, "TOPLEFT", 1, S("xs") + 1)
  e.caption:SetText(caption)
  if opts.placeholder then
    e.hint = Theme.Text(e, "label", "textMuted")
    e.hint:SetPoint("LEFT", S("md"), 0); e.hint:SetPoint("RIGHT", -S("md"), 0)
    e.hint:SetJustifyH("LEFT"); e.hint:SetWordWrap(false)
    e.hint:SetText(opts.placeholder)
  end
  e:SetScript("OnTextChanged", function(self, userInput)
    local text = self:GetText() or ""
    if opts.placeholder then self.hint:SetShown(text == "") end
    if opts.onChange then opts.onChange(self, text, userInput) end
  end)
  return e
end

-- Choices are not actions: a diamond means one choice, a check means an
-- independent option. Selection has a shape as well as a colour.
function Kit.Choice(parent, label, width, kind, onClick)
  local b = Kit.Button(parent, label, width, 32, { onClick = onClick })
  b.label:ClearAllPoints()
  b.label:SetPoint("LEFT", 30, 0)
  b.label:SetPoint("RIGHT", -8, 0)
  b.label:SetJustifyH("LEFT")
  local box = CreateFrame("Frame", nil, b)
  box:SetSize(12, 12)
  box:SetPoint("LEFT", 10, 0)
  Kit.Outline(Kit.BorderLayer(box, Z("line")), "controlBorder")
  b.choiceMark = Theme.Fill(box, "ARTWORK", "accent")
  b.choiceMark:SetSize(6, 6)
  b.choiceMark:SetPoint("CENTER")
  if kind == "radio" then
    b.choiceMark:SetRotation(math.pi / 4)
  else
    b.choiceMark:ClearAllPoints()
    b.choiceMark:SetSize(7, 2)
    b.choiceMark:SetPoint("CENTER", 2, 1)
    b.choiceMark:SetRotation(math.pi / 4)
    b.checkTail = Theme.Fill(box, "ARTWORK", "accent")
    b.checkTail:SetSize(4, 2)
    b.checkTail:SetPoint("CENTER", -2, -1)
    b.checkTail:SetRotation(-math.pi / 4)
  end
  function b:SetSelected(on)
    self.selected = not not on
    Kit.Paint(self, on and "selected" or "surface")
    self.selectedMark:Hide()
    Motion.Mark(self.choiceMark, on)
    if self.checkTail then Motion.Mark(self.checkTail, on) end
  end
  b:SetSelected(false)
  return b
end

-- Tabs keep a visible boundary at rest; selection adds a raised face,
-- accent rim and underline. They share button hover/press/disabled states.
function Kit.Tab(parent, label, onClick)
  local t = Kit.Button(parent, label, Z("tabWidth"), Z("tab"), { onClick = onClick })
  t.isTab = true
  Theme.SetRole(t.label, "heading")
  t.label:ClearAllPoints()
  t.label:SetPoint("LEFT", S("md"), 1)
  t.count = Theme.Text(t, "label")
  t.count:SetPoint("LEFT", t.label, "RIGHT", S("sm"), 0)
  Theme.Unpaint(t.count) -- owners colour the count
  t.line = Theme.Fill(t, "ARTWORK", "accent")
  t.line:SetPoint("BOTTOMLEFT", S("md"), 2)
  t.line:SetPoint("BOTTOMRIGHT", -S("md"), 2)
  t.line:SetHeight(Z("underline"))
  function t:Select(on)
    self.selected = not not on
    Kit.Paint(self, on and "selected" or "surface")
    Motion.Mark(self.line, on)
  end
  t:Select(false)
  return t
end

-- Hover tooltip on frame (added to its own hover scripts). lines: a list
-- of strings or { text, token, wrap }, or a function(frame) returning one
-- (nothing to show: return nil). The first line is the title (gold unless
-- given); the rest wrap, in text colour. opts.anchor ("ANCHOR_TOP").
function Kit.Tooltip(frame, lines, opts)
  local anchor = opts and opts.anchor or "ANCHOR_TOP"
  frame:HookScript("OnEnter", function(self)
    local list = lines
    if type(lines) == "function" then list = lines(self) end
    if type(list) ~= "table" or #list == 0 then return end
    GameTooltip:SetOwner(self, anchor)
    for i, line in ipairs(list) do
      if type(line) == "string" then line = { line } end
      local token = line[2] or (i == 1 and "gold" or "text")
      local wrap = line[3]
      if wrap == nil then wrap = i > 1 end
      Theme.TipLine(GameTooltip, line[1], token, wrap)
    end
    GameTooltip:Show()
  end)
  frame:HookScript("OnLeave", function() GameTooltip_Hide() end)
end

-- SetAtlas can silently keep the previous texture when an atlas is absent.
-- Verify it first, then fall back to the class sheet on older clients.
function Kit.ClassIcon(texture, class)
  class = ns.Util.value(class)
  if type(class) == "string" then
    local atlas = "classicon-" .. class:lower()
    local lookup = C_Texture and C_Texture.GetAtlasInfo or GetAtlasInfo
    texture:SetTexCoord(0, 1, 0, 1)
    if ns.Util.call(lookup, atlas) and pcall(texture.SetAtlas, texture, atlas, false) then
      texture:Show()
      return true
    end
    local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    if coords then
      texture:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
      texture:SetTexCoord(unpack(coords))
      texture:Show()
      return true
    end
  end
  texture:SetTexture(nil)
  texture:Hide()
  return false
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

-- Status chip: opaque backing keeps labelled signals readable over bars.
function Kit.Chip(parent, text, color, width)
  local c = CreateFrame("Frame", nil, parent)
  c:SetSize(width or Z("chipWidth"), Z("chip"))
  c.bg = Theme.Fill(c, "BACKGROUND", "chipBg")
  c.bg:SetAllPoints()
  c.edge = Kit.Outline(c, color or "border")
  for _, edge in ipairs(c.edge) do edge:SetAlpha(0.5) end
  c.label = Theme.Text(c, "caption")
  c.label:SetPoint("CENTER", 0, 0)
  function c:Set(value, tint)
    self.text = value or ""
    self.label:SetText(self.text)
    if tint then
      Theme.Paint(self.label, tint)
      Theme.Paint(self.bg, "chipBg")
      self.edge:SetColor(tint)
    end
  end
  c:Set(text, color)
  return c
end

-- Base card: colour strip, optional portrait, title over sub line, and a
-- right-hand area (card.right) for numbers or buttons.
-- opts: strip (colour token, "accent"), icon (true: portrait at left),
-- titleRole ("heading"), rightWidth (0), featured, onEnter(self), onLeave(self).
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
  if Kit.CardFinish then Kit.CardFinish(r, opts.featured) end
  function r:SetStrip(color)
    Theme.Paint(self.strip, color)
    if self.glow then self.glow:SetColor(color) end
  end
  r:EnableMouse(true)
  Kit.Feedback(r, { onEnter = opts.onEnter, onLeave = opts.onLeave })
  return r
end
