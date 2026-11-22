local _, ns = ...
local Core, Theme, Kit = ns.Core, ns.Theme, ns.Kit
local Options = ns.Options
local S, Z = Theme.Space, Theme.Size

---------------------------------------------------------------------------
-- Settings page building blocks: value rows (get, set, -/box/+ wiring and
-- hover), toggles, steppers, pages and section titles.
---------------------------------------------------------------------------
Options.rows = {} -- every value row on every page
function Options.Get(row)
  if row.kind == "kitspell" then
    row.def = Core.P(row.kindKey) -- follows the type's value unless overridden
    local v = Core.db.points and Core.db.points[row.key]
    return v ~= nil and v or row.def
  end
  if row.kind == "spec" then
    return Core.Profile(row.specID)[row.stat]
  end
  if row.kind == "weight" then
    return (Core.db.weights and Core.db.weights[row.key]) or 1
  end
  if row.kind == "option" then return Core.O(row.key) end
  return Core.P(row.key)
end
function Options.Set(row, v)
  if row.kind == "kitspell" and v == nil then
    if Core.db.points then Core.db.points[row.key] = nil end
    Options.PointsChanged()
    return
  end
  local ok, err = Core.SetTuning(row.kind, row.stat or row.key, v, row.specID)
  if not ok then ns.Util.Say(err); return end
  Options.PointsChanged()
end
function Options.Refresh(row)
  local v = Options.Get(row)
  local overridden = row.kind == "kitspell" and Core.db.points and Core.db.points[row.key] ~= nil
  row.box:SetText(row.kind == "kitspell" and not overridden and "" or Options.Format(v))
  row.box:SetCursorPosition(0)
  local changed = row.kind == "kitspell" and overridden or v ~= row.def
  row.reset:SetShown(changed)
  if row.defaultLabel then
    row.defaultLabel:SetText((row.kind == "kitspell" and not overridden and "inherits " or "default ") .. Options.Format(row.def))
    local def = Core.SettingDefs[row.kind == "kitspell" and "point" or row.kind][row.key]
    local component = row.kind == "weight" and row.key or (def and def.component)
    if component and Core.W(component) ~= 1 then
      row.defaultLabel:SetText("effective " .. Options.Format(row.kind == "weight" and Core.W(component) or v * Core.W(component)))
    end
  end
  Theme.Paint(row.label, changed and "gold" or "text")
end
function Options.RefreshAllRows()
  for _, row in ipairs(Options.rows) do
    Options.Refresh(row)
  end
  for _, page in ipairs(Options.pages) do
    if page.RefreshOverrides then page.RefreshOverrides() end
    if page.RefreshTracking then page.RefreshTracking() end
    if page.RefreshBehavior then page.RefreshBehavior() end
    if page.RefreshGeneral then page.RefreshGeneral() end
    if page.RefreshAppearance then page.RefreshAppearance() end
  end
end
-- Hidden pages refresh when opened. A single edit should not redraw every
-- settings page (including all of their steppers, effects and edit boxes).
function Options.RefreshPage(page)
  if not page then return Options.RefreshAllRows() end
  for _, row in ipairs(page.rows or {}) do Options.Refresh(row) end
  if page.RefreshOverrides then page.RefreshOverrides() end
  if page.RefreshTracking then page.RefreshTracking() end
  if page.RefreshBehavior then page.RefreshBehavior() end
  if page.RefreshGeneral then page.RefreshGeneral() end
  if page.RefreshAppearance then page.RefreshAppearance() end
  if page.RefreshPreviews then page.RefreshPreviews() end
end
-- -/box/+ behaviour shared by both row styles.
function Options.Wire(row, minus, plus, step)
  minus:SetScript("OnClick", function()
    Options.Set(row, Options.Get(row) - step * (IsShiftKeyDown() and 5 or 1))
    Options.RefreshPage(row.page)
  end)
  plus:SetScript("OnClick", function()
    Options.Set(row, Options.Get(row) + step * (IsShiftKeyDown() and 5 or 1))
    Options.RefreshPage(row.page)
  end)
  row.reset:SetScript("OnClick", function()
    if row.kind == "kitspell" then Options.Set(row, nil) else Options.Set(row, row.def) end
    Options.RefreshPage(row.page)
  end)
  row.box:SetScript("OnEnterPressed", function(self)
    local v = tonumber(self:GetText())
    if v then
      Options.Set(row, v)
    elseif row.kind == "kitspell" and self:GetText():match("^%s*$") then
      Options.Set(row, nil)
    end
    Options.RefreshPage(row.page)
    self:ClearFocus()
  end)
  row.box:SetScript("OnEscapePressed", function(self)
    Options.Refresh(row)
    self:ClearFocus()
  end)
  row.box:HookScript("OnEditFocusLost", function()
    Options.Refresh(row)
  end)
  Options.rows[#Options.rows + 1] = row
  if row.page then
    row.page.rows = row.page.rows or {}
    row.page.rows[#row.page.rows + 1] = row
  end
end

-- Title and an optional muted line on a control's hover (Kit.Tooltip).
function Options.Tip(frame, title, text)
  Kit.Tooltip(frame, { { title, "text" }, text and { text, "textMuted", true } or nil },
    { anchor = "ANCHOR_RIGHT" })
end

-- One-line Kit.Toggle as wide as its parent: label, then an optional muted
-- note after it (cut to fit; the tooltip shows both).
-- onChange(self, on) runs on clicks only.
function Options.Toggle(parent, label, note, onChange)
  local t = Kit.Toggle(parent, label, { width = 400, onChange = onChange })
  t:SetPoint("RIGHT", parent, "RIGHT", -S("md"), 0)
  Options.Tip(t, label, note)
  t.label:ClearAllPoints()
  t.label:SetPoint("TOPLEFT", t.box, "TOPRIGHT", S("md"), 0)
  t.label:SetWordWrap(false)
  if note then
    t.note = Theme.Text(t, "body", "textMuted")
    t.note:SetPoint("BOTTOMLEFT", t.label, "BOTTOMRIGHT", S("md"), 0)
    t.note:SetPoint("RIGHT", t, "RIGHT", 0, 0)
    t.note:SetJustifyH("LEFT")
    t.note:SetWordWrap(false)
    t.note:SetText(note)
  end
  return t
end

-- Kit.Stepper look; the caller owns the value (Options.Wire or its own
-- scripts on .minus, .plus and .box).
function Options.Stepper(parent, boxWidth)
  local h = Z("control")
  return Kit.Stepper(parent, { width = 2 * (h + S("xs")) + boxWidth, manual = true })
end

-- A sub-page: title, hint, its own scroll area.
function Options.MakePage(key)
  local config = ns.OptionsConfig.pages[key]
  local name, text = config.name, config.hint
  local page = { key = key, name = name, module = config.module, order = config.order, y = -4 }
  local f = CreateFrame("Frame", nil)
  f:Hide()
  Options.PageFill(f)
  page.frame = f
  local t = Theme.Text(f, "title", "titleText")
  t:SetPoint("TOPLEFT", S("xl"), -S("xl"))
  t:SetPoint("RIGHT", -S("xl"), 0)
  t:SetJustifyH("LEFT"); t:SetWordWrap(true)
  t:SetText(config.module and name or ("Highground: " .. name))
  page.title = t
  local h = Theme.Text(f, "body", "textMuted")
  h:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -(S("sm") + S("xs")))
  h:SetPoint("RIGHT", -S("xl"), 0)
  h:SetJustifyH("LEFT"); h:SetWordWrap(true)
  h:SetText(text .. (config.stepper == false and "" or "  Applies instantly; shift-click -/+ for bigger steps."))
  page.hint = h
  -- A themed scroll area; page.scroll also answers the native ScrollFrame
  -- calls (Get/SetVerticalScroll) that guides and routes use.
  local scroll = Kit.ScrollArea(f)
  page.scroll = scroll
  scroll:SetPoint("TOPLEFT", S("md"), config.stepper == false and -112 or -78)
  scroll:SetPoint("BOTTOMRIGHT", -S("md"), S("md") + S("xs"))
  page.child = scroll.body
  page.content = page.child
  -- Narrow hosts keep the minimum content width and clip, as before.
  scroll.onLayout = function(_, width)
    if width < 400 then page.child:SetWidth(400) end
  end
  local function FinishLayout()
    f:SetScript("OnUpdate", nil)
    if not f:IsVisible() then return end
    page.settlingLayout = true
    page.LayoutHeader()
    Options.RefreshPage(page)
    scroll:Refresh() -- recomputes the range and clamps the offset
    page.settlingLayout = nil
  end
  function page.LayoutHeader()
    t:SetHeight(t:GetStringHeight())
    h:SetHeight(h:GetStringHeight())
    scroll:SetPoint("TOPLEFT", S("md"), -(S("xl") + t:GetHeight() + S("sm") + S("xs")
      + h:GetHeight() + 18 + (page.toolbarHeight or 0)))
    scroll:Refresh() -- the viewport moved: resize the body before pages lay out
    -- Reparenting and wrapped text can settle after OnShow. Finish once on
    -- the next visible frame; repeated size events share this same callback.
    if f:IsShown() and not page.settlingLayout then f:SetScript("OnUpdate", FinishLayout) end
  end
  f:SetScript("OnSizeChanged", page.LayoutHeader)
  f:HookScript("OnHide", function() f:SetScript("OnUpdate", nil) end)
  Core.OnFontScaleChange(function() if f:IsVisible() then page.LayoutHeader() end end)
  f:SetScript("OnShow", function()
    if config.module and ns.Modules and not ns.Modules.Active(config.module) then
      f:Hide()
      if ns.Hub then ns.Hub.Open("module-" .. config.module) end
      return
    end
    if page.build then
      local build = page.build
      page.build = nil
      build()
    end
    page.LayoutHeader()
    Options.RefreshPage(page)
  end)
  Options.byKey = Options.byKey or {}
  Options.byKey[key] = page
  Options.pages[#Options.pages + 1] = page
  return page
end

function Options.Section(page, title, hint)
  local label = Kit.Section(page.child, title)
  label:SetPoint("TOPLEFT", S("xl"), page.y - S("md"))
  page.y = page.y - 28
  if hint then
    local note = Theme.Text(page.child, "body", "textMuted")
    note:SetPoint("TOPLEFT", S("xl"), page.y)
    note:SetPoint("RIGHT", -S("xl"), 0)
    note:SetJustifyH("LEFT")
    note:SetText(hint)
    page.y = page.y - 32
  end
end

-- Hover lines of a value row: what it sets, its default and range, and how
-- the tuning and battleground multipliers combine.
local function RowLines(row)
  local lines = { { row.desc, "text", true } }
  local function Add(text, token, wrap) lines[#lines + 1] = { text, token, wrap } end
  if row.detail then Add(row.detail, "textMuted", true) end
  local def = Core.SettingDefs[row.kind == "kitspell" and "point" or row.kind][row.key]
  if def then
    if row.def then Add("Default: " .. Options.Format(row.def), "textMuted", false) end
    Add(string.format("Allowed: %s–%s %s", def.min, def.max, def.unit), "textMuted", true)
    local component = row.kind == "weight" and row.key or def.component
    if component then
      local user = (Core.db.weights or {})[component] or 1
      local bg = (Core.currentProfile or {})[component] or 1
      local value = row.kind == "weight" and 1 or Options.Get(row)
      Add(string.format("%g × tuning %g × battleground %g = %g %s", value, user, bg,
        value * user * bg, row.kind == "weight" and "effective multiplier" or "effective points"), "success", true)
    end
  end
  return lines
end

-- Label, [-] value [+], default note, x (reset).
function Options.Row(page, row)
  row.page = page.owner or page
  local f = CreateFrame("Frame", nil, page.child)
  f:SetPoint("TOPLEFT", S("md"), page.y)
  f:SetPoint("RIGHT", page.child, "RIGHT", -S("md"), 0)
  f:SetHeight(Z("input"))
  page.y = page.y - 26
  page.child:SetHeight(-page.y + 10)
  row.label = Theme.Text(f, "bodyLarge")
  row.label:SetPoint("LEFT", S("md"), 0)
  row.label:SetText(row.desc)
  row.label:SetWordWrap(false)
  f:EnableMouse(true)
  Kit.Tooltip(f, function() return RowLines(row) end, { anchor = "ANCHOR_RIGHT" })
  local stepper = Options.Stepper(f, 52)
  stepper:SetPoint("RIGHT", -110, 0)
  row.stepper, row.box = stepper, stepper.box
  local dflt = Theme.Text(f, "label", "textDim")
  row.defaultLabel = dflt
  dflt:SetPoint("LEFT", stepper, "RIGHT", S("md"), 0)
  dflt:SetText("default " .. Options.Format(row.def))
  row.reset = Kit.Button(f, "x", Z("row"), Z("row"))
  row.reset:SetPoint("RIGHT", 0, 0)
  row.label:SetPoint("RIGHT", stepper, "LEFT", -S("md"), 0)
  row.label:SetJustifyH("LEFT")
  Options.Wire(row, stepper.minus, stepper.plus, row.step or 1)
end

