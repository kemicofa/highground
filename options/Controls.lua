local _, ns = ...
local Core, Theme, Kit = ns.Core, ns.Theme, ns.Kit
local Options = ns.Options
local S, Z = Theme.Space, Theme.Size

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
-- -/box/+ behaviour shared by both row styles.
function Options.Wire(row, minus, plus, step)
  minus:SetScript("OnClick", function()
    Options.Set(row, Options.Get(row) - step * (IsShiftKeyDown() and 5 or 1))
    Options.RefreshAllRows()
  end)
  plus:SetScript("OnClick", function()
    Options.Set(row, Options.Get(row) + step * (IsShiftKeyDown() and 5 or 1))
    Options.RefreshAllRows()
  end)
  row.reset:SetScript("OnClick", function()
    if row.kind == "kitspell" then Options.Set(row, nil) else Options.Set(row, row.def) end
    Options.RefreshAllRows()
  end)
  row.box:SetScript("OnEnterPressed", function(self)
    local v = tonumber(self:GetText())
    if v then
      Options.Set(row, v)
    elseif row.kind == "kitspell" and self:GetText():match("^%s*$") then
      Options.Set(row, nil)
    end
    Options.RefreshAllRows()
    self:ClearFocus()
  end)
  row.box:SetScript("OnEscapePressed", function(self)
    Options.Refresh(row)
    self:ClearFocus()
  end)
  row.box:SetScript("OnEditFocusLost", function()
    Options.Refresh(row)
  end)
  Options.rows[#Options.rows + 1] = row
end

-- GameTooltip line in a colour token.
function Options.TipLine(text, token, wrap)
  local r, g, b = Theme.Color(token or "text")
  GameTooltip:AddLine(text, r, g, b, wrap)
end

-- Kit buttons have no disabled look of their own.
function Options.SetEnabled(b, on)
  if on then b:Enable() else b:Disable() end
  b:SetAlpha(on and 1 or Theme.Alpha("disabled"))
end

-- Tooltip with a title and a muted line, added to a Kit control's hover.
function Options.Tip(frame, title, text)
  frame:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    Options.TipLine(title, "text")
    if text then Options.TipLine(text, "textMuted", true) end
    GameTooltip:Show()
  end)
  frame:HookScript("OnLeave", GameTooltip_Hide)
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
  return Kit.Stepper(parent, { width = 2 * (h + S("xs")) + boxWidth })
end

-- A sub-page: title, hint, its own scroll area.
function Options.MakePage(key)
  local config = ns.OptionsConfig.pages[key]
  local name, text = config.name, config.hint
  local page = { name = name, order = config.order, y = -4 }
  local f = CreateFrame("Frame", nil)
  f:Hide()
  page.frame = f
  local t = Theme.Text(f, "title")
  t:SetPoint("TOPLEFT", S("xl"), -S("xl"))
  t:SetText("Warboard: " .. name)
  page.title = t
  local h = Theme.Text(f, "body", "textMuted")
  h:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -(S("sm") + S("xs")))
  h:SetPoint("RIGHT", -S("xl"), 0)
  h:SetJustifyH("LEFT")
  h:SetText(text .. (config.stepper == false and "" or "  Applies instantly; shift-click -/+ for bigger steps."))
  page.hint = h
  -- The template is used for scrolling only.
  local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  page.scroll = scroll
  scroll:SetPoint("TOPLEFT", S("md"), config.stepper == false and -112 or -78)
  scroll:SetPoint("BOTTOMRIGHT", -30, 10)
  page.child = CreateFrame("Frame", nil, scroll)
  page.child:SetSize(560, 10)
  scroll:SetScrollChild(page.child)
  f:SetScript("OnSizeChanged", function(_, w)
    page.child:SetWidth(math.max(400, (w or 600) - 50))
  end)
  f:SetScript("OnShow", function()
    if page.build then
      page.build()
      page.build = nil
    end
    Options.RefreshAllRows()
  end)
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

local function RowTooltip(self, row)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  Options.TipLine(row.desc, "text", true)
  if row.detail then Options.TipLine(row.detail, "textMuted", true) end
  local def = Core.SettingDefs[row.kind == "kitspell" and "point" or row.kind][row.key]
  if def then
    if row.def then Options.TipLine("Default: " .. Options.Format(row.def), "textMuted") end
    Options.TipLine(string.format("Allowed: %s–%s %s", def.min, def.max, def.unit), "textMuted", true)
    local component = row.kind == "weight" and row.key or def.component
    if component then
      local user = (Core.db.weights or {})[component] or 1
      local bg = (Core.currentProfile or {})[component] or 1
      local value = row.kind == "weight" and 1 or Options.Get(row)
      Options.TipLine(string.format("%g × tuning %g × battleground %g = %g %s", value, user, bg,
        value * user * bg, row.kind == "weight" and "effective multiplier" or "effective points"), "success", true)
    end
  end
  GameTooltip:Show()
end

-- Label, [-] value [+], default note, x (reset).
function Options.Row(page, row)
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
  f:SetScript("OnEnter", function(self) RowTooltip(self, row) end)
  f:SetScript("OnLeave", GameTooltip_Hide)
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

