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
Options.AddAppearancePreview(page, owner)
local refreshers = {}
-- Put labels above their controls so translations and enlarged text keep
-- the full page width instead of competing with the value column.
local CONTROL_X = 24

local function Label(text)
  local fs = Theme.Text(P, "bodyLarge")
  fs:SetPoint("TOPLEFT", 24, page.y - S("sm"))
  fs:SetPoint("TOPRIGHT", -24, page.y - S("sm"))
  fs:SetJustifyH("LEFT"); fs:SetWordWrap(true)
  ns.Localization.Bind(fs, text)
  page.y = page.y - 30
  return fs
end

local function Next()
  page.y = page.y - 34
  P:SetHeight(-page.y + 10)
end

-- Label  [-] value [+]  [Default]. The value is read-only; shift-click
-- -/+ for bigger steps.
local function Stepper(text, get, set, step, format, def)
  local label = Label(text)
  local stepper = Options.Stepper(P, 56)
  stepper:SetPoint("TOPLEFT", CONTROL_X, page.y)
  stepper.box:EnableMouse(false) -- read-only: -/+ and Default only
  local reset = ns.Localization.Bind(Kit.Button(P, ns.Locale:Get("highground.appearance.default.808d7d"), 70, Z("control")), "highground.appearance.default.808d7d")
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
    Kit.FitButton(reset, 70, 20)
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
local function Pixels(v) return ns.Locale:Format("highground.appearance.v_px.1a6af9", { v = string.format("%d", v) }) end

-- Label  [current choice]: click for the next option, right-click for the
-- previous one.
local function Cycle(text, kind, list)
  local label = Label(text)
  local select = Kit.Select(P, { choices = list, width = 220, onChange = function(_, key)
    Core.SetStyleChoice(kind, key)
    Options.RefreshPage(page)
  end })
  select:SetPoint("TOPLEFT", CONTROL_X, page.y)
  select:SetPoint("TOPRIGHT", -24, page.y)
  select.kind = kind
  refreshers[#refreshers + 1] = { label = label, select = select,
    refresh = function() select:SetValue(Core.StyleChoice(kind).key, true) end }
  Next()
  return select
end

local function Check(text, desc, get, set)
  local cb = Options.Toggle(P, ns.Locale:Get(text), ns.Locale:Get(desc), function(_, on) set(on); Options.RefreshPage(page) end)
  ns.Localization.Bind(cb.label, text)
  if cb.note then ns.Localization.Bind(cb.note, desc) end
  Kit.Tooltip(cb, function() return { ns.Locale:Get(text), ns.Locale:Get(desc) } end)
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

local function CustomColor(enemy)
  local label = Label("shared.ui.custom_color.34cfc6")
  local button = Kit.Button(P, "", enemy and 160 or 120, Z("control"))
  button:SetPoint("TOPLEFT", CONTROL_X, page.y)
  button.label:ClearAllPoints(); button.label:SetPoint("LEFT", 28, 0)
  local swatch = Theme.Fill(button, "OVERLAY", "white")
  swatch:SetSize(14, 14); swatch:SetPoint("LEFT", 8, 0)
  local reset = ns.Localization.Bind(Kit.Button(P, ns.Locale:Get("highground.appearance.default.808d7d"), 70, Z("control")), "highground.appearance.default.808d7d")
  reset:SetPoint("LEFT", button, "RIGHT", S("sm") + S("xs"), 0)
  local function Hex(c) return string.format("#%02X%02X%02X", c.r * 255 + 0.5, c.g * 255 + 0.5, c.b * 255 + 0.5) end
  button:SetScript("OnClick", function()
    local c, saved = Core.BarCustomColor(enemy), Core.StyleDB()[enemy and "enemyCustom" or "barCustom"]
    local previous = saved and { unpack(saved) }
    Options.PickColor({ c.r, c.g, c.b }, function(r, g, b) Core.SetBarCustomColor(r, g, b, enemy); Options.RefreshPage(page) end,
      function() Core.SetBarCustomColor(previous and previous[1], previous and previous[2], previous and previous[3], enemy); Options.RefreshPage(page) end,
      button)
  end)
  reset:SetScript("OnClick", function() Core.SetBarCustomColor(nil, nil, nil, enemy); Options.RefreshPage(page) end)
  button:HookScript("OnHide", function() Options.ClosePickerFor(button) end)
  Kit.Tooltip(button, function() return { ns.Locale:Get("shared.ui.custom_color.34cfc6"), ns.Locale:Get("shared.ui.bar_color_used_when_health_bar_color.56d2e5") } end)
  if enemy then page.enemyCustom = button else page.barCustom = button end
  refreshers[#refreshers + 1] = { label = label, refresh = function()
    local c, on = Core.BarCustomColor(enemy), Core.StyleChoice(enemy and "enemyColor" or "barColor").key == "custom"
    Theme.Paint(swatch, { c.r, c.g, c.b })
    button:SetText(Hex(c))
    Kit.FitButton(button, enemy and 160 or 120, 42)
    Kit.FitButton(reset, 70, 20)
    button:SetEnabled(on)
    reset:SetEnabled(on and Core.StyleDB()[enemy and "enemyCustom" or "barCustom"] ~= nil)
    label:SetAlpha(on and 1 or Theme.Alpha("disabled"))
  end }
  Next()
end

-- Theme: colours and type of every Highground window (config/Theme.lua).
-- Applies at once, also in combat; sizes never change.
local function ThemeChoices()
  local list = {}
  for i, name in ipairs(Theme.Names()) do list[i] = { key = name, label = Theme.Label(name) } end
  return list
end
if owner then
  page.shared = ns.Localization.Bind(Options.Link(page, "", function() ns.Hub.Open("appearance") end), "highground.appearance.shared_theme_and_accessibility.7f65ce")
  ns.Localization.Bind(Options.Link(page, "", function() ns.Hub.Open(Options.addonPages[owner].previews) end), "highground.hub.previews_and_guide.e53405")
else
Options.Section(page, ns.Locale:Get("highground.appearance.theme.a797e3"), nil, "highground.appearance.theme.a797e3", nil)
do
  local description = Theme.Text(P, "body", "textMuted")
  description:SetPoint("TOPLEFT", 24, page.y)
  description:SetPoint("TOPRIGHT", -24, page.y)
  description:SetJustifyH("LEFT"); description:SetJustifyV("TOP")
  description:SetWordWrap(true); description:SetHeight(52)
  page.themeDescription = description
  page.y = page.y - 60
  local label = Label("highground.appearance.theme.a797e3")
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

Options.Section(page, ns.Locale:Get("highground.appearance.accessibility.d66004"), nil, "highground.appearance.accessibility.d66004", nil)
Check("highground.appearance.reduced_motion.789804", "highground.appearance.steady_indicators_and_instant_transitions_no_flashes.fb18f6",
  Core.ReducedMotion, Core.SetReducedMotion)
page.y = page.y - S("lg")
page.font = Cycle("highground.appearance.font.b97c4d", "font", A.fonts)
refreshers[#refreshers + 1] = { refresh = function()
  local forced = ns.Localization.Font() ~= nil
  page.font:SetEnabled(not forced)
  page.hint:SetText(ns.OptionsConfig.pages.appearance.hint
    .. (forced and "\n" .. ns.Locale:Get("appearance.font.locale_fallback") or ""))
end }
Stepper("highground.appearance.text_size.3cc6e1", Core.FontScale, Core.SetFontScale, A.fontScale.step, Percent, function() return 1 end)

end

if owner == "battlegrounds" then
Options.Section(page, ns.Locale:Get("enemy.appearance.style_section"), nil, "enemy.appearance.style_section")
page.enemyControls = {}
Label("enemy.appearance.preset")
page.enemyPreset = Kit.Select(P, { choices = A.enemyPresets, width = 220, menu = true })
page.enemyPreset:SetPoint("TOPLEFT", CONTROL_X, page.y)
page.enemyPreset:SetValue("readable", true)
page.applyEnemyPreset = ns.Localization.Bind(Kit.Button(P, ns.Locale:Get("enemy.appearance.apply"), 160, Z("control")), "enemy.appearance.apply")
page.applyEnemyPreset:SetPoint("LEFT", page.enemyPreset, "RIGHT", S("sm"), 0)
page.applyEnemyPreset:SetScript("OnClick", function()
  Core.SetEnemyPreset(page.enemyPreset:GetValue()); Options.RefreshPage(page)
end)
Next()
local hint = Theme.Text(P, "body", "textMuted")
hint:SetPoint("TOPLEFT", 24, page.y); hint:SetPoint("TOPRIGHT", -24, page.y)
hint:SetJustifyH("LEFT"); hint:SetWordWrap(true); hint:SetHeight(116)
page.enemyHint = hint
ns.Localization.Bind(hint, "enemy.appearance.hint")
page.y = page.y - 124
page.enemyControls.style = Cycle("highground.appearance.health_style.42b74a", "healthStyle", A.healthStyles)
page.enemyControls.texture = Cycle("highground.appearance.bar_texture.5592a1", "enemyBar", A.enemyBars)
page.enemyControls.color = Cycle("highground.appearance.health_bar_color.0e69b9", "enemyColor", A.enemyColors)
CustomColor(true)
for _, def in ipairs(A.enemyNumbers) do
  page.enemyControls[def.key] = Stepper(ns.Localization.Key(def, "label"), function() return Core.EnemyNumber(def.key) end,
    function(value) Core.SetEnemyNumber(def.key, value) end, 0.05, Percent, function() return def.default end)
end
page.y = page.y - S("md")
Options.Section(page, ns.Locale:Get("highground.appearance.sniper_marker.2ac0d6"), nil, "highground.appearance.sniper_marker.2ac0d6", nil)
do
  Label("highground.appearance.marker_style.a15069")
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
  Label("highground.appearance.placement.ab89d0")
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
  ns.Localization.Bind(note, "highground.appearance.head_area_is_approximate_and_follows_the.2efb31")
  page.y = page.y - 56
  page.sniperRows = {}
  for _, def in ipairs({
    { key = "sniperPadding", label = "highground.appearance.gap_from_nameplate.fc5321", step = 2 },
    { key = "sniperX", label = "highground.appearance.horizontal_offset.2cfb8a", step = 2 },
    { key = "sniperY", label = "highground.appearance.vertical_offset.669530", step = 2 },
    { key = "sniperScale", label = "highground.appearance.marker_size.56315e", step = 0.05 },
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

Options.Section(page, ns.Locale:Get("highground.appearance.panels.8dfeed"), nil, "highground.appearance.panels.8dfeed", nil)
if not owner then
page.transparency = Check("highground.appearance.panel_transparency.239297", "highground.appearance.fade_backgrounds_until_hovered.40a300",
  Core.PanelTransparency, Core.SetPanelTransparency)
page.opacity = Stepper("highground.appearance.background_opacity.f12e36", Core.BgAlpha, ns.SetBgAlpha, Core.THEME.opacity.step, Percent,
  function() return Core.THEME.opacity.default end)
Check("highground.appearance.frameless.d60b06", "highground.appearance.no_background_or_border_title_bars_hide.141944",
  Core.Frameless, Core.SetFrameless)
elseif owner == "battlegrounds" then
Stepper("highground.appearance.enemies_shown.f77aae", function() return Core.db.rows end,
  function(value) Core.SetRows(value) end, 1, function(value) return tostring(value) end, function() return Core.MAX_ROWS end)
elseif owner == "nearby" then
  local rows = Core.SettingDefs.option.nearbyRows -- -/+ stop at its limits; Default is its default
  page.nearbyRows = Stepper("highground.appearance.enemies_shown.f77aae", function() return Core.O("nearbyRows") end,
    function(value) Options.Set({ kind = "option", key = "nearbyRows" }, math.max(rows.min, math.min(rows.max, value))) end,
    1, tostring, function() return rows.def end)
elseif owner == "bounties" then
  page.markers = Check("highground.appearance.bounty_markers.0e2414", "highground.appearance.coin_on_nameplates_and_highlights_on_enemy.38a9d9",
    function() return Core.On("bountyMarks") end, function(on) Core.SetFeature("bountyMarks", on) end)
  page.markers.key, page.markers.page = "bountyMarks", page
  Options.featureBoxes[#Options.featureBoxes + 1] = page.markers
  page.posters = Check("highground.appearance.wanted_posters.c55fce", "highground.appearance.sightings_and_new_matching_bounties.d5be08",
    function() return Core.O("bountyAnnounce") end,
    function(on) Options.Set({ kind = "option", key = "bountyAnnounce" }, on) end)
end
for _, panel in ipairs(A.panels) do
  if owner and panel.module == owner then
    Stepper(panel.key == "timers" and "highground.appearance.timer_panels_scale.621a38" or { key = "highground.appearance.panel_label_scale.87b0f5",
      values = function() return { panel_label = panel.label } end }, function() return Core.PanelScale(panel.key) end,
      function(v) Core.SetPanelScale(panel.key, v) end, A.panelScale.step, Percent, function() return 1 end)
  end
end
local metricRows, elementBoxes, layoutNote = {}, {}, nil
local function Compact()
  if owner == "arena" or owner == "nearby" then return Core.PanelCompact(owner) end
  return Core.compact
end
if owner == "arena" or owner == "nearby" then
  Check("highground.appearance.compact_spacing.b241f3", "highground.appearance.this_panel_keeps_separate_normal_and_compact.5f213a",
    function() return Core.PanelCompact(owner) end, function(on) Core.SetPanelCompact(owner, on) end)
end
if owner ~= "bounties" then
-- Detailed controls continue below the panel choices in the same scroll area.
local basic, detailsTop = P, page.y - 12
page.detailHeading = ns.Localization.Bind(Kit.Section(basic, ""), owner and "highground.appearance.sizes_and_spacing.8d69d8" or "highground.appearance.text_and_bars.5c20f9")
page.detailHeading:SetPoint("TOPLEFT", 24, detailsTop)
page.detailHeading:SetPoint("RIGHT", -24, 0)
page.detailBody = CreateFrame("Frame", nil, basic)
page.detailBody:SetPoint("TOPLEFT", 0, detailsTop - 46)
page.detailBody:SetPoint("TOPRIGHT", 0, detailsTop - 46)
P, page.child, page.y = page.detailBody, page.detailBody, -4

if owner then
  layoutNote = Label(""); Theme.Paint(layoutNote, "textMuted"); Next()
  for _, m in ipairs(A.metrics) do
    if m.module == owner then
      local row = Stepper(ns.Localization.Key(m, "label"), function() return Core.Metric(m.key, Compact()) end,
        function(v) Core.SetMetric(m.key, v, Compact()) end, m.step, Pixels,
        function() return Core.MetricDefault(m.key, Compact()) end)
      row.metric = m; metricRows[#metricRows + 1] = row
    end
  end
end
if owner == "battlegrounds" then
  Options.Section(page, ns.Locale:Get("highground.appearance.enemy_rows.26dea1"), nil, "highground.appearance.enemy_rows.26dea1", nil)
  -- The hero card heads the row switches; it uses hide.hero but is opt-in.
  page.heroCard = Check("enemy.appearance.hero_card", "highground.appearance.off_by_default_show_the_recommended_enemy.cff9f5",
    function() return Core.ShowsElement("hero") end, function(on) Core.SetElement("hero", on) end)
  for _, el in ipairs(A.elements) do
    if ns.OptionAvailable(el) then
      local box = Check(ns.Localization.Key(el, "label"), ns.Localization.Key(el, "desc"), function() return Core.ShowsElement(el.key) end,
        function(on) Core.SetElement(el.key, on) end)
      box.key = el.key; elementBoxes[#elementBoxes + 1] = box
    end
  end
elseif not owner then
  Cycle("highground.appearance.bar_texture.5592a1", "bar", A.bars)
  Cycle("highground.appearance.health_bar_color.0e69b9", "barColor", A.barColors)
  CustomColor(false)
  Options.Section(page, ns.Locale:Get("highground.appearance.borders.685f23"), nil, "highground.appearance.borders.685f23", nil)
  Stepper("highground.appearance.border_size.544ebf", Core.BorderSize, Core.SetBorderSize, A.border.step, Pixels, function() return A.border.default end)
  Cycle("highground.appearance.border_color.06186d", "borderColor", A.borderColors)
end
page.y = page.y - S("md")
page.reset = ns.Localization.Bind(Kit.Button(P, ns.Locale:Get("highground.appearance.reset_panel_styling.744a3e"), 230, Z("control")), "highground.appearance.reset_panel_styling.744a3e")
page.reset:SetPoint("TOPLEFT", 24, page.y)
page.reset:SetPoint("TOPRIGHT", -24, page.y)
page.reset:SetScript("OnClick", function() Core.ResetStyle(owner or "shared"); Options.RefreshPage(page) end)
if not owner then ns.Localization.Bind(page.reset, "highground.appearance.reset_shared_fonts_and_styling.6a7cd9"); Options.resetAppearance = page.reset end
Next()
local detailsHeight = -page.y + 10
P, page.child = basic, basic
page.detailBody:SetHeight(detailsHeight)
basic:SetHeight(-detailsTop + 46 + detailsHeight)
else P:SetHeight(-page.y + 12) end
page.elementBoxes, page.metricRows = elementBoxes, metricRows
page.RefreshAppearance = function()
  local compact = Compact()
  for _, r in ipairs(refreshers) do
    -- Health sizes apply to their own Health style only.
    r.off = r.metric and (compact and r.metric.normalOnly or r.metric.style and r.metric.style ~= Core.HealthStyle())
    if r.sniperGap then
      local placement = Core.SniperPlacement()
      r.off = not (placement.gapX or placement.gapY)
      r.label:SetAlpha(r.off and Theme.Alpha("disabled") or 1)
    end
    r.refresh(r.off)
  end
  if layoutNote then
    layoutNote:SetText((compact and ns.Locale:Get("highground.appearance.compact_layout.755c0b") or ns.Locale:Get("highground.appearance.normal_layout.a076b8"))
      .. (InCombatLockdown() and ns.Locale:Get("highground.appearance.sizes_apply_after_combat.ac90e2") or ns.Locale:Get("highground.appearance.each_layout_keeps_its_own_sizes.646a75")))
  end
  for _, row in ipairs(metricRows) do row.label:SetAlpha(row.off and Theme.Alpha("disabled") or 1) end
  if page.markers then page.markers:SetEnabled(Core.On("bounty")) end
  if page.RefreshSniperColors then page.RefreshSniperColors() end
  page.RefreshPreview()
end
end
page.build = Populate
return page
end

Options.appearance = Build("appearance")
for _, owner in ipairs({ "battlegrounds", "arena", "nearby", "bounties" }) do
  if Options.addonPages[owner] then Build(Options.addonPages[owner].appearance, owner) end
end
ns.RefreshOpacityOption = function()
  if Options.appearance.RefreshAppearance then Options.appearance.RefreshAppearance() end
end
