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
local function Build(key, owner)
local page = Options.MakePage(key)
local function Populate()
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
    Options.RefreshPage(page)
  end
  stepper.minus:SetScript("OnClick", function() Step(-1) end)
  stepper.plus:SetScript("OnClick", function() Step(1) end)
  reset:SetScript("OnClick", function() set(def()); Options.RefreshPage(page) end)
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
    Options.RefreshPage(page)
  end })
  select:SetPoint("TOPLEFT", CONTROL_X, page.y)
  select.kind = kind
  refreshers[#refreshers + 1] = { label = label, select = select,
    refresh = function() select:SetValue(Core.StyleChoice(kind).key, true) end }
  Next()
end

local function Check(text, desc, get, set)
  local cb = Options.Toggle(P, text, desc, function(_, on) set(on); Options.RefreshPage(page) end)
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
if owner then
  page.shared = Options.Link(page, "Shared theme and accessibility", function() ns.Hub.Open("appearance") end)
  Options.Link(page, "Previews and guide", function() ns.Hub.Open(Options.addonPages[owner].previews) end)
else
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
    Options.RefreshPage(page)
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

end

if owner == "battlegrounds" then
Options.Section(page, "Sniper marker")
do
  Label("Marker style")
  page.sniperStyle = Kit.Select(P, { choices = Core.SNIPER_STYLES, width = 220, menu = true,
    onChange = function(_, key) Core.SetSniperStyle(key) end })
  page.sniperStyle:SetPoint("TOPLEFT", CONTROL_X, page.y)
  page.sniperPreview = Core.MakeScope(P)
  page.sniperPreview:SetScale(0.65)
  page.sniperPreview:SetPoint("LEFT", page.sniperStyle, "RIGHT", 14 / 0.65, 0)
  page.sniperPreview:Show()
  refreshers[#refreshers + 1] = { refresh = function()
    page.sniperStyle:SetValue(Core.db.sniperStyle, true)
  end }
  Next()
  page.y = page.y - 12
  Options.SniperColorControls(page, CONTROL_X)
  refreshers[#refreshers + 1] = { refresh = page.RefreshSniperColors }
  Label("Placement")
  page.sniperPlacement = Kit.Select(P, { choices = Core.SNIPER_PLACEMENTS, width = 220, menu = true,
    onChange = function(_, key) Core.SetSniperPlacement(key) end })
  page.sniperPlacement:SetPoint("TOPLEFT", CONTROL_X, page.y)
  refreshers[#refreshers + 1] = { refresh = function()
    page.sniperPlacement:SetValue(Core.db.sniperPlacement, true)
  end }
  Next()
  local note = Theme.Text(P, "body", "textMuted")
  note:SetPoint("TOPLEFT", 24, page.y); note:SetPoint("TOPRIGHT", -24, page.y)
  note:SetJustifyH("LEFT"); note:SetWordWrap(true); note:SetHeight(48)
  note:SetText("Head area is approximate and follows the nameplate. "
    .. "Placement changes reset height. Positive offsets move right / up.")
  page.y = page.y - 56
  page.sniperRows = {}
  for _, def in ipairs({
    { key = "sniperPadding", label = "Gap from nameplate", step = 2 },
    { key = "sniperX", label = "Horizontal offset", step = 2 },
    { key = "sniperY", label = "Vertical offset", step = 2 },
    { key = "sniperScale", label = "Marker size", step = 0.05 },
  }) do
    local row = Stepper(def.label, function() return Core.db[def.key] end,
      function(value) Core.SetSniperNumber(def.key, value) end, def.step,
      def.key == "sniperScale" and Percent or Pixels,
      function() return def.key == "sniperY" and Core.SniperPlacement().y or Core.DEFAULTS[def.key] end)
    row.sniperGap = def.key == "sniperPadding"
    page.sniperRows[def.key] = row
  end
end

end

Options.Section(page, "Panels")
if not owner then
page.transparency = Check("Panel transparency", "fade backgrounds until hovered",
  Core.PanelTransparency, Core.SetPanelTransparency)
page.opacity = Stepper("Background opacity", Core.BgAlpha, ns.SetBgAlpha, Core.THEME.opacity.step, Percent,
  function() return Core.THEME.opacity.default end)
Check("Frameless", "no background or border; title bars hide when panels are locked",
  Core.Frameless, Core.SetFrameless)
elseif owner == "battlegrounds" then
Check("Suggested target card", "off by default; show the recommended enemy above the list",
  function() return Core.ShowsElement("hero") end, function(on) Core.SetElement("hero", on) end)
Stepper("Enemies shown", function() return Core.db.rows end,
  function(value) Core.SetRows(value) end, 1, function(value) return tostring(value) end, function() return 5 end)
elseif owner == "nearby" then
  Stepper("Enemies shown", function() return Core.O("nearbyRows") end,
    function(value) Options.Set({ kind = "option", key = "nearbyRows" }, value) end,
    1, tostring, function() return 5 end)
elseif owner == "bounties" then
  page.markers = Check("Bounty markers", "coin on nameplates and highlights on enemy rows",
    function() return Core.On("bountyMarks") end, function(on) Core.SetFeature("bountyMarks", on) end)
  page.markers.key, page.markers.page = "bountyMarks", page
  Options.featureBoxes[#Options.featureBoxes + 1] = page.markers
  page.posters = Check("Wanted posters", "sightings and new matching bounties",
    function() return Core.O("bountyAnnounce") end,
    function(on) Options.Set({ kind = "option", key = "bountyAnnounce" }, on) end)
end
for _, panel in ipairs(A.panels) do
  if owner and panel.module == owner then
    Stepper(panel.key == "timers" and "Timer panels scale" or panel.label .. " scale", function() return Core.PanelScale(panel.key) end,
      function(v) Core.SetPanelScale(panel.key, v) end, A.panelScale.step, Percent, function() return 1 end)
  end
end
local metricRows, elementBoxes, layoutNote = {}, {}, nil
local function Compact()
  if owner == "arena" or owner == "nearby" then return Core.PanelCompact(owner) end
  return Core.compact
end
if owner == "arena" or owner == "nearby" then
  Check("Compact spacing", "this panel keeps separate normal and compact dimensions",
    function() return Core.PanelCompact(owner) end, function(on) Core.SetPanelCompact(owner, on) end)
end
if owner ~= "bounties" then
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

if owner then
  Options.Section(page, "Sizes and spacing")
  layoutNote = Label(""); Theme.Paint(layoutNote, "textMuted"); Next()
  for _, m in ipairs(A.metrics) do
    if m.module == owner then
      local row = Stepper(m.label, function() return Core.Metric(m.key, Compact()) end,
        function(v) Core.SetMetric(m.key, v, Compact()) end, m.step, Pixels,
        function() return Core.MetricDefault(m.key, Compact()) end)
      row.metric = m; metricRows[#metricRows + 1] = row
    end
  end
end
if owner == "battlegrounds" then
  Options.Section(page, "Enemy rows")
  for _, el in ipairs(A.elements) do
    if ns.OptionAvailable(el) then
      local box = Check(el.label, el.desc, function() return Core.ShowsElement(el.key) end,
        function(on) Core.SetElement(el.key, on) end)
      box.key = el.key; elementBoxes[#elementBoxes + 1] = box
    end
  end
  Cycle("Health style", "healthStyle", A.healthStyles)
elseif not owner then
  Options.Section(page, "Text and bars")
  Cycle("Bar texture", "bar", A.bars)
  Cycle("Health bar color", "barColor", A.barColors)
  Options.Section(page, "Borders")
  Stepper("Border size", Core.BorderSize, Core.SetBorderSize, A.border.step, Pixels, function() return A.border.default end)
  Cycle("Border color", "borderColor", A.borderColors)
end
page.y = page.y - S("md")
page.reset = Kit.Button(P, "Reset panel styling", 230, Z("control"))
page.reset:SetPoint("TOPLEFT", 24, page.y)
page.reset:SetPoint("TOPRIGHT", -24, page.y)
page.reset:SetScript("OnClick", function() Core.ResetStyle(owner or "shared"); Options.RefreshPage(page) end)
if not owner then page.reset:SetText("Reset shared fonts and styling"); Options.resetAppearance = page.reset end
Next()
local detailsHeight = -page.y + 10
P, page.child = basic, basic
function page.LayoutDetails()
  page.detailBody:SetShown(page.detailsOpen == true)
  page.detailBody:SetHeight(detailsHeight)
  page.details:SetText(page.detailsOpen and "Hide fine-tuning" or "Fine-tune appearance")
  basic:SetHeight(-detailsTop + 46 + (page.detailsOpen and detailsHeight or 0))
end
page.LayoutDetails()
else P:SetHeight(-page.y + 12) end
page.elementBoxes = elementBoxes
page.RefreshAppearance = function()
  local compact = Compact()
  for _, r in ipairs(refreshers) do
    r.off = r.metric and compact and r.metric.normalOnly
    if r.sniperGap then
      local placement = Core.SniperPlacement()
      r.off = not (placement.gapX or placement.gapY)
      r.label:SetAlpha(r.off and Theme.Alpha("disabled") or 1)
    end
    r.refresh(r.off)
  end
  if layoutNote then
    layoutNote:SetText((compact and "Compact layout" or "Normal layout")
      .. (InCombatLockdown() and ": sizes apply after combat" or ": each layout keeps its own sizes"))
  end
  for _, row in ipairs(metricRows) do row.label:SetAlpha(row.off and Theme.Alpha("disabled") or 1) end
  if page.markers then page.markers:SetEnabled(Core.On("bounty")) end
  if page.RefreshSniperColors then page.RefreshSniperColors() end
end
end
if owner then page.build = Populate else Populate() end
return page
end

Options.appearance = Build("appearance")
for _, owner in ipairs({ "battlegrounds", "arena", "nearby", "bounties" }) do
  Build(Options.addonPages[owner].appearance, owner)
end
ns.RefreshOpacityOption = Options.appearance.RefreshAppearance
