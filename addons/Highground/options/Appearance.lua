local _, ns = ...
local Core, Theme, Kit = ns.Core, ns.Theme, ns.Kit
local Options = ns.Options
local S, Z = Theme.Space, Theme.Size

---------------------------------------------------------------------------
-- Appearance page: theme, panel scales, sizes and spacing for the current
-- layout, enemy row elements, font, bars and borders. Values live in
-- HighgroundDB.style (ui/Appearance.lua), the theme in HighgroundDB.theme;
-- every control applies instantly, sizes out of combat.
---------------------------------------------------------------------------
local A = Core.THEME.appearance
local page = Options.MakePage("appearance")
local P = page.child
local refreshers = {}
local CONTROL_X = 250

local function Label(text)
  local fs = Theme.Text(P, "bodyLarge")
  fs:SetPoint("TOPLEFT", 24, page.y - S("sm"))
  fs:SetText(text)
  return fs
end

local function Next()
  page.y = page.y - 26
  P:SetHeight(-page.y + 10)
end

-- Label  [-] value [+]  [Default]. The value is read-only; shift-click
-- -/+ for bigger steps.
local function Stepper(text, get, set, step, format, def)
  local label = Label(text)
  local stepper = Options.Stepper(P, 56)
  stepper:SetPoint("TOPLEFT", CONTROL_X, page.y)
  stepper.box:EnableMouse(false) -- read-only: -/+ and Default only
  local reset = Kit.Button(P, "Default", 70, Z("control"))
  reset:SetPoint("LEFT", stepper, "RIGHT", S("sm") + S("xs"), 0)
  local row = { label = label, stepper = stepper, reset = reset }
  local function Step(dir)
    set(get() + dir * step * (IsShiftKeyDown() and 5 or 1))
    Options.RefreshAllRows()
  end
  stepper.minus:SetScript("OnClick", function() Step(-1) end)
  stepper.plus:SetScript("OnClick", function() Step(1) end)
  reset:SetScript("OnClick", function() set(def()); Options.RefreshAllRows() end)
  row.refresh = function(off)
    stepper.box:SetText(format(get()))
    stepper.minus:SetEnabled(not off)
    stepper.plus:SetEnabled(not off)
    reset:SetEnabled(not off and math.abs(get() - def()) > 0.0001)
  end
  stepper.box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  stepper.box:HookScript("OnEditFocusLost", function() row.refresh(row.off) end)
  refreshers[#refreshers + 1] = row
  Next()
  return row
end

local function Percent(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end
local function Pixels(v) return string.format("%d px", v) end

-- Label  [current choice]: click for the next option, right-click for the
-- previous one.
local function Cycle(text, kind, list)
  local label = Label(text)
  local select = Kit.Select(P, { choices = list, width = 160, onChange = function(_, key)
    Core.SetStyleChoice(kind, key)
    Options.RefreshAllRows()
  end })
  select:SetPoint("TOPLEFT", CONTROL_X, page.y)
  select.kind = kind
  refreshers[#refreshers + 1] = { label = label, select = select,
    refresh = function() select:SetValue(Core.StyleChoice(kind).key, true) end }
  Next()
end

local function Check(text, desc, get, set)
  local cb = Options.Toggle(P, text, desc, function(_, on) set(on); Options.RefreshAllRows() end)
  cb:ClearAllPoints()
  cb:SetPoint("TOPLEFT", 24, page.y - S("xs"))
  cb:SetPoint("TOPRIGHT", -S("md"), page.y - S("xs"))
  if cb.note then
    cb.note:ClearAllPoints()
    cb.note:SetPoint("TOPLEFT", cb.label, "TOPRIGHT", S("md"), 0)
    cb.note:SetPoint("TOPRIGHT", cb, "TOPRIGHT", 0, -(Z("control") - Z("toggle")) / 2)
  end
  refreshers[#refreshers + 1] = { refresh = function() cb:SetChecked(get(), true) end }
  Next()
  return cb
end

-- Theme: colours and type of every Highground window (config/Theme.lua).
-- Applies at once, also in combat; sizes never change.
local function ThemeChoices()
  local list = {}
  for i, name in ipairs(Theme.Names()) do list[i] = { key = name, label = Theme.Label(name) } end
  return list
end
Options.Section(page, "Theme")
do
  local description = Theme.Text(P, "body", "textMuted")
  description:SetPoint("TOPLEFT", 24, page.y)
  description:SetPoint("TOPRIGHT", -24, page.y)
  description:SetJustifyH("LEFT"); description:SetJustifyV("TOP")
  description:SetWordWrap(true); description:SetHeight(52)
  page.themeDescription = description
  page.y = page.y - 60
  local label = Label("Theme")
  local select = Kit.Select(P, { choices = ThemeChoices(), width = 160, menu = true, onPreview = function(_, key)
    description:SetText(Theme.Description(key))
  end, onChange = function(_, key)
    Theme.Use(key)
    Options.RefreshAllRows()
  end })
  select:SetPoint("TOPLEFT", CONTROL_X, page.y)
  page.themeSelect = select
  local function Refresh()
    select:SetChoices(ThemeChoices()) -- themes registered later join the list
    select:SetValue(Theme.Current(), true)
    description:SetText(Theme.Description())
  end
  Theme.OnChange(Refresh) -- /hg theme and saved themes too
  refreshers[#refreshers + 1] = { label = label, select = select, refresh = Refresh }
  Next()
  page.y = page.y - 12
end

Options.Section(page, "Accessibility")
Check("Reduced motion", "steady indicators and instant transitions; no flashes or target zoom",
  Core.ReducedMotion, Core.SetReducedMotion)
page.y = page.y - S("lg")
Cycle("Font", "font", A.fonts)
Stepper("Text size", Core.FontScale, Core.SetFontScale, A.fontScale.step, Percent, function() return 1 end)

Options.Section(page, "Panels")
Check("Frameless", "no background or border; title bars hide when panels are locked",
  Core.Frameless, Core.SetFrameless)
Check("Suggested target card", "the recommended enemy above the list; click to target, then use your abilities",
  function() return Core.ShowsElement("hero") end, function(on) Core.SetElement("hero", on) end)
Stepper("Enemies shown", function() return Core.db.rows end,
  function(value) Core.SetRows(value) end, 1, function(value) return tostring(value) end, function() return 5 end)
for _, p in ipairs(A.panels) do
  Stepper(p.label .. " scale", function() return Core.PanelScale(p.key) end,
    function(v) Core.SetPanelScale(p.key, v) end, A.panelScale.step, Percent, function() return 1 end)
end

-- Keep pixel-level tuning and individual row elements out of the first
-- view. The same controls remain available when the player wants them.
local basic, detailsTop = P, page.y - 12
page.details = Kit.Button(basic, "Fine-tune appearance", 240, 30, { onClick = function()
  page.detailsOpen = not page.detailsOpen
  page.LayoutDetails()
end })
page.details:SetPoint("TOPLEFT", 24, detailsTop)
page.detailBody = CreateFrame("Frame", nil, basic)
page.detailBody:SetPoint("TOPLEFT", 0, detailsTop - 46)
page.detailBody:SetPoint("TOPRIGHT", 0, detailsTop - 46)
P, page.child, page.y = page.detailBody, page.detailBody, -4

Options.Section(page, "Sizes and spacing")
local layoutNote = Label("")
Theme.Paint(layoutNote, "textMuted")
Next()
local metricRows = {}
for _, m in ipairs(A.metrics) do
  local row = Stepper(m.label, function() return Core.Metric(m.key, Core.compact) end,
    function(v) Core.SetMetric(m.key, v, Core.compact) end, m.step, Pixels,
    function() return Core.MetricDefault(m.key, Core.compact) end)
  row.metric = m
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
Cycle("Health style", "healthStyle", A.healthStyles)
Cycle("Bar texture", "bar", A.bars)
Cycle("Health bar color", "barColor", A.barColors)

Options.Section(page, "Borders")
Stepper("Border size", Core.BorderSize, Core.SetBorderSize, A.border.step, Pixels, function() return A.border.default end)
Cycle("Border color", "borderColor", A.borderColors)

page.y = page.y - S("md")
do
  local reset = Kit.Button(P, "Reset appearance", 150, Z("control"))
  reset:SetPoint("TOPLEFT", 24, page.y)
  reset:SetScript("OnClick", function() Core.ResetStyle(); Options.RefreshAllRows() end)
  Options.resetAppearance = reset
  Next()
end

local detailsHeight = -page.y + 10
P, page.child = basic, basic
function page.LayoutDetails()
  page.detailBody:SetShown(page.detailsOpen == true)
  page.detailBody:SetHeight(detailsHeight)
  page.details:SetText(page.detailsOpen and "Hide fine-tuning" or "Fine-tune appearance")
  basic:SetHeight(-detailsTop + 46 + (page.detailsOpen and detailsHeight or 0))
end
page.LayoutDetails()
page.elementBoxes = elementBoxes
page.RefreshAppearance = function()
  local compact = Core.compact
  for _, r in ipairs(refreshers) do
    r.off = r.metric and compact and r.metric.normalOnly
    r.refresh(r.off)
  end
  layoutNote:SetText((compact and "Compact layout" or "Normal layout")
    .. (InCombatLockdown() and ": sizes apply after combat" or ": each layout keeps its own sizes"))
  for _, row in ipairs(metricRows) do
    row.label:SetAlpha(row.off and Theme.Alpha("disabled") or 1)
  end
end
Options.appearance = page
