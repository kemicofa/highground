local _, ns = ...
local Core = ns.Core
local Options = ns.Options

---------------------------------------------------------------------------
-- Appearance page: panel scales, sizes and spacing for the current layout,
-- enemy row elements, font, bars and borders. Values live in
-- WarboardDB.style (ui/Appearance.lua); every control applies instantly,
-- sizes out of combat.
---------------------------------------------------------------------------
local A = Core.THEME.appearance
local page = Options.MakePage("appearance")
local P = page.child
local refreshers = {}

local function Label(text, x)
  local fs = P:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  fs:SetPoint("TOPLEFT", x or 24, page.y - 4)
  fs:SetText(text)
  return fs
end

local function Button(text, width, anchor, rel, x)
  local b = CreateFrame("Button", nil, P, "UIPanelButtonTemplate")
  b:SetSize(width, 20)
  b:SetPoint("LEFT", anchor, rel or "RIGHT", x or 6, 0)
  b:SetText(text)
  return b
end

local function SetEnabled(b, on)
  if on then b:Enable() else b:Disable() end
end

local function Next()
  page.y = page.y - 26
  P:SetHeight(-page.y + 10)
end

-- Label  [-] value [+]  [Default]
local function Stepper(text, get, set, step, format, def)
  local label = Label(text)
  local anchor = P:CreateFontString(nil, "ARTWORK")
  anchor:SetPoint("TOPLEFT", 250, page.y - 4)
  anchor:SetSize(1, 14)
  local minus = Button("-", 24, anchor, "LEFT", 0)
  local value = P:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  value:SetPoint("LEFT", minus, "RIGHT", 4, 0)
  value:SetWidth(56)
  value:SetJustifyH("CENTER")
  local plus = Button("+", 24, value, "RIGHT", 4)
  local reset = Button("Default", 70, plus)
  local row = { label = label, value = value, buttons = { minus, plus, reset } }
  minus:SetScript("OnClick", function() set(get() - step * (IsShiftKeyDown() and 5 or 1)); Options.RefreshAllRows() end)
  plus:SetScript("OnClick", function() set(get() + step * (IsShiftKeyDown() and 5 or 1)); Options.RefreshAllRows() end)
  reset:SetScript("OnClick", function() set(def()); Options.RefreshAllRows() end)
  row.refresh = function()
    value:SetText(format(get()))
    SetEnabled(reset, math.abs(get() - def()) > 0.0001)
  end
  refreshers[#refreshers + 1] = row
  Next()
  return row
end

local function Percent(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end
local function Pixels(v) return string.format("%d px", v) end

-- Label  [current choice]: click for the next option.
local function Cycle(text, kind, list)
  local label = Label(text)
  local anchor = P:CreateFontString(nil, "ARTWORK")
  anchor:SetPoint("TOPLEFT", 250, page.y - 4)
  anchor:SetSize(1, 14)
  local b = Button("", 160, anchor, "LEFT", 0)
  b:SetScript("OnClick", function()
    local current = Core.StyleChoice(kind)
    for i, o in ipairs(list) do
      if o == current then
        Core.SetStyleChoice(kind, list[i % #list + 1].key)
        break
      end
    end
    Options.RefreshAllRows()
  end)
  refreshers[#refreshers + 1] = { label = label, refresh = function() b:SetText(Core.StyleChoice(kind).label) end }
  Next()
end

local function Check(text, desc, get, set)
  local cb = CreateFrame("CheckButton", nil, P, "UICheckButtonTemplate")
  cb:SetSize(24, 24)
  cb:SetPoint("TOPLEFT", 20, page.y)
  local label = P:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
  label:SetText(text .. (desc and ("  |cff888888" .. desc .. "|r") or ""))
  cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false); Options.RefreshAllRows() end)
  cb.label = label
  refreshers[#refreshers + 1] = { refresh = function() cb:SetChecked(get()) end }
  Next()
  return cb
end

Options.Section(page, "Panels")
Check("Frameless", "no background, border or title bars: only the rows and their bars",
  Core.Frameless, Core.SetFrameless)
for _, p in ipairs(A.panels) do
  Stepper(p.label .. " scale", function() return Core.PanelScale(p.key) end,
    function(v) Core.SetPanelScale(p.key, v) end, A.panelScale.step, Percent, function() return 1 end)
end

Options.Section(page, "Sizes and spacing")
local layoutNote = Label("")
layoutNote:SetTextColor(0.7, 0.7, 0.75)
Next()
local metricRows = {}
for _, m in ipairs(A.metrics) do
  local row = Stepper(m.label, function() return Core.Metric(m.key, Core.compact) end,
    function(v) Core.SetMetric(m.key, v, Core.compact) end, m.step, Pixels,
    function() return Core.MetricDefault(m.key, Core.compact) end)
  row.def = m
  metricRows[#metricRows + 1] = row
end

Options.Section(page, "Enemy rows")
local elementBoxes = {}
for _, el in ipairs(A.elements) do
  if ns.OptionAvailable(el) then
    elementBoxes[#elementBoxes + 1] = Check(el.label, el.desc,
      function() return Core.ShowsElement(el.key) end, function(on) Core.SetElement(el.key, on) end)
    elementBoxes[#elementBoxes].key = el.key
  end
end

Options.Section(page, "Text and bars")
Cycle("Font", "font", A.fonts)
Stepper("Text size", Core.FontScale, Core.SetFontScale, A.fontScale.step, Percent, function() return 1 end)
Cycle("Health style", "healthStyle", A.healthStyles)
Cycle("Bar texture", "bar", A.bars)
Cycle("Health bar color", "barColor", A.barColors)

Options.Section(page, "Borders")
Stepper("Border size", Core.BorderSize, Core.SetBorderSize, A.border.step, Pixels, function() return A.border.default end)
Cycle("Border color", "borderColor", A.borderColors)

page.y = page.y - 8
do
  local reset = CreateFrame("Button", nil, P, "UIPanelButtonTemplate")
  reset:SetSize(150, 22)
  reset:SetPoint("TOPLEFT", 24, page.y)
  reset:SetText("Reset appearance")
  reset:SetScript("OnClick", function() Core.ResetStyle(); Options.RefreshAllRows() end)
  Options.resetAppearance = reset
  Next()
end

page.elementBoxes = elementBoxes
page.RefreshAppearance = function()
  local compact = Core.compact
  for _, r in ipairs(refreshers) do r.refresh() end
  layoutNote:SetText((compact and "Compact layout" or "Normal layout")
    .. (InCombatLockdown() and ": sizes apply after combat" or ": each layout keeps its own sizes"))
  for _, row in ipairs(metricRows) do
    local off = compact and row.def.normalOnly
    for _, b in ipairs(row.buttons) do SetEnabled(b, not off) end
    row.label:SetAlpha(off and 0.45 or 1)
  end
end
Options.appearance = page
