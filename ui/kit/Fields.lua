local _, ns = ...
local Theme, Kit = ns.Theme, ns.Kit
local S, Z = Theme.Space, Theme.Size

---------------------------------------------------------------------------
-- Setting fields in the kit style: toggle, number stepper, choice select.
-- Each keeps its own value; Set* with silent = true skips onChange.
---------------------------------------------------------------------------

-- Checkbox look-alike with a label and an optional description below it.
-- opts: desc, checked, width, onChange(self, checked).
-- toggle:SetChecked(on, silent), toggle:GetChecked(), toggle:SetEnabled(on).
function Kit.Toggle(parent, label, opts)
  opts = opts or {}
  local t = CreateFrame("Button", nil, parent)
  t:SetSize(opts.width or 240, opts.desc and Z("control") + S("lg") or Z("toggle") + S("sm"))
  t.box = CreateFrame("Frame", nil, t)
  t.box:SetSize(Z("toggle"), Z("toggle"))
  t.box:SetPoint("TOPLEFT", 0, -S("xs"))
  t.edge = Theme.Fill(t.box, "BACKGROUND", "border")
  t.edge:SetAllPoints()
  t.well = Theme.Fill(t.box, "BORDER", "bg")
  t.well:SetPoint("TOPLEFT", Z("line"), -Z("line"))
  t.well:SetPoint("BOTTOMRIGHT", -Z("line"), Z("line"))
  t.mark = Theme.Fill(t.box, "ARTWORK", "accent")
  t.mark:SetPoint("TOPLEFT", S("xs") + 1, -(S("xs") + 1))
  t.mark:SetPoint("BOTTOMRIGHT", -(S("xs") + 1), S("xs") + 1)
  t.hover = Theme.Fill(t.box, "OVERLAY", "overlayHover")
  t.hover:SetAllPoints()
  t.hover:Hide()
  t.label = Theme.Text(t, "control")
  t.label:SetPoint("TOPLEFT", t.box, "TOPRIGHT", S("md"), 0)
  t.label:SetPoint("RIGHT", t, "RIGHT", 0, 0)
  t.label:SetJustifyH("LEFT")
  t.label:SetText(label or "")
  t.desc = Theme.Text(t, "body", "textMuted")
  t.desc:SetPoint("TOPLEFT", t.label, "BOTTOMLEFT", 0, -S("xs"))
  t.desc:SetPoint("RIGHT", t, "RIGHT", 0, 0)
  t.desc:SetJustifyH("LEFT")
  t.desc:SetText(opts.desc or "")
  t.desc:SetShown(opts.desc ~= nil)
  t.enabled = true
  function t:SetChecked(on, silent)
    on = not not on
    local changed = on ~= self.checked
    self.checked = on
    self.mark:SetShown(on)
    if changed and not silent and opts.onChange then opts.onChange(self, on) end
  end
  function t:GetChecked() return self.checked end
  function t:SetEnabled(on)
    self.enabled = not not on
    self:SetAlpha(on and 1 or Theme.Alpha("disabled"))
  end
  t:SetScript("OnClick", function(self)
    if self.enabled then self:SetChecked(not self.checked) end
  end)
  t:SetScript("OnEnter", function(self) self.hover:Show() end)
  t:SetScript("OnLeave", function(self) self.hover:Hide() end)
  t.checked = nil
  t:SetChecked(opts.checked, true)
  return t
end

local function Round(v, lo, hi, step)
  v = math.max(lo, math.min(hi, v))
  if step and step > 0 then v = lo + math.floor((v - lo) / step + 0.5) * step end
  v = math.min(hi, v)
  return tonumber(string.format("%.4f", v))
end

local function Format(v, step)
  if step and step % 1 ~= 0 then
    return (string.format("%.2f", v):gsub("0+$", ""):gsub("%.$", ""))
  end
  return string.format("%d", v)
end

-- Number with - and + buttons and an edit box (Enter or leaving the box
-- commits; Escape restores). opts: label, min, max, step, value, width,
-- format(v) -> text, onChange(self, value).
-- stepper:SetValue(v, silent) -> accepted, stepper:GetValue().
function Kit.Stepper(parent, opts)
  opts = opts or {}
  local lo, hi, step = opts.min or 0, opts.max or 100, opts.step or 1
  local s = CreateFrame("Frame", nil, parent)
  local h = Z("control")
  s:SetSize(opts.width or 120, h)
  s.minus = Kit.Button(s, "-", h, h, { onClick = function() s:SetValue((s.value or lo) - step) end })
  s.minus:SetPoint("LEFT")
  s.plus = Kit.Button(s, "+", h, h, { onClick = function() s:SetValue((s.value or lo) + step) end })
  s.plus:SetPoint("RIGHT")
  s.box = CreateFrame("EditBox", nil, s)
  s.box:SetPoint("TOPLEFT", s.minus, "TOPRIGHT", S("xs"), 0)
  s.box:SetPoint("BOTTOMRIGHT", s.plus, "BOTTOMLEFT", -S("xs"), 0)
  s.box:SetAutoFocus(false)
  s.box:SetJustifyH("CENTER")
  Theme.SetRole(s.box, "input")
  Theme.Paint(s.box, "text")
  local well = Theme.Fill(s.box, "BACKGROUND", "bg")
  well:SetAllPoints()
  if opts.label then
    s.caption = Kit.Caption(parent, opts.label)
    s.caption:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 1, S("xs") + 1)
  end
  local function Show(self)
    self.box:SetText(self.value and (opts.format and opts.format(self.value) or Format(self.value, step)) or "")
  end
  function s:SetValue(v, silent)
    v = tonumber(v)
    if not v or v ~= v or math.abs(v) == math.huge then Show(self); return false end
    v = Round(v, lo, hi, step)
    local changed = v ~= self.value
    self.value = v
    Show(self)
    if changed and not silent and opts.onChange then opts.onChange(self, v) end
    return true
  end
  function s:GetValue() return self.value end
  local function Commit(box)
    if box.wbCommitting then return end
    box.wbCommitting = true
    s:SetValue(box:GetText())
    box.wbCommitting = nil
  end
  s.box:SetScript("OnEnterPressed", function(self) Commit(self); self:ClearFocus() end)
  s.box:SetScript("OnEditFocusLost", Commit)
  s.box:SetScript("OnEscapePressed", function(self) Show(s); self:ClearFocus() end)
  if opts.value ~= nil then s:SetValue(opts.value, true) end
  return s
end

-- Choice button: shows the current choice's label. Left click moves to the
-- next choice, right click to the previous; with opts.menu a click opens
-- Kit.Dropdown instead. opts: choices ({ key, label }), value, width,
-- label (caption), menu, onChange(self, key).
-- select:SetValue(key, silent) -> accepted, :GetValue(), :SetChoices(list).
function Kit.Select(parent, opts)
  opts = opts or {}
  local s = Kit.Button(parent, "", opts.width or 160, Z("control"))
  s.label:ClearAllPoints()
  s.label:SetPoint("LEFT", S("md"), 0)
  s.label:SetPoint("RIGHT", -(S("md") + S("lg")), 0)
  s.label:SetJustifyH("LEFT")
  s.arrow = Theme.Text(s, "caption", "textMuted")
  s.arrow:SetPoint("RIGHT", -S("md"), 0)
  s.arrow:SetText(opts.menu and "v" or "<>")
  if opts.label then
    s.caption = Kit.Caption(parent, opts.label)
    s.caption:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 1, S("xs") + 1)
  end
  s.choices = opts.choices or {}
  local function Index(key)
    for i, c in ipairs(s.choices) do if c.key == key then return i end end
  end
  function s:SetValue(key, silent)
    local i = Index(key)
    if not i then return false end
    local changed = key ~= self.value
    self.value = key
    self:SetText(self.choices[i].label or tostring(key))
    if changed and not silent and opts.onChange then opts.onChange(self, key) end
    return true
  end
  function s:GetValue() return self.value end
  function s:SetChoices(list)
    self.choices = list or {}
    if not Index(self.value) then
      self.value = nil
      if self.choices[1] then self:SetValue(self.choices[1].key, true) else self:SetText("") end
    end
  end
  s:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  s:SetScript("OnClick", function(self, button)
    local n = #self.choices
    if n == 0 then return end
    if opts.menu and Kit.Dropdown then
      local items = {}
      for i, c in ipairs(self.choices) do items[i] = { text = c.label or tostring(c.key), value = c.key } end
      Kit.Dropdown.Open(self, items, function(item) self:SetValue(item.value) end, { selected = Index(self.value) })
      return
    end
    local i = (Index(self.value) or 0) + (button == "RightButton" and -1 or 1)
    self:SetValue(self.choices[(i - 1) % n + 1].key)
  end)
  s:SetChoices(s.choices)
  if opts.value ~= nil then s:SetValue(opts.value, true) end
  return s
end
