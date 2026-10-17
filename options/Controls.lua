local _, ns = ...
local Core = ns.Core
local Options = ns.Options

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
  if not ok then print("|cffff5533Warboard|r " .. err); return end
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
  row.label:SetTextColor(changed and 1 or 0.85, changed and 0.82 or 0.85, changed and 0.3 or 0.85)
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

-- A sub-page: title, hint, its own scroll area.
function Options.MakePage(key)
  local config = ns.OptionsConfig.pages[key]
  local name, text = config.name, config.hint
  local page = { name = name, order = config.order, y = -4 }
  local f = CreateFrame("Frame", nil)
  f:Hide()
  page.frame = f
  local t = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  t:SetPoint("TOPLEFT", 16, -16)
  t:SetText("Warboard: " .. name)
  local h = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  h:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -6)
  h:SetPoint("RIGHT", -16, 0)
  h:SetJustifyH("LEFT")
  h:SetText(text .. (config.stepper == false and "" or "  Applies instantly; shift-click -/+ for bigger steps."))
  h:SetTextColor(0.7, 0.7, 0.75)
  local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  page.scroll = scroll
  scroll:SetPoint("TOPLEFT", 8, config.stepper == false and -112 or -78)
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
  local label = page.child:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  label:SetPoint("TOPLEFT", 16, page.y - 6)
  label:SetText(title)
  page.y = page.y - 28
  if hint then
    local note = page.child:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", 16, page.y)
    note:SetPoint("RIGHT", -16, 0)
    note:SetJustifyH("LEFT")
    note:SetText(hint)
    page.y = page.y - 32
  end
end

function Options.Row(page, row)
  local f = CreateFrame("Frame", nil, page.child)
  f:SetPoint("TOPLEFT", 8, page.y)
  f:SetPoint("RIGHT", page.child, "RIGHT", -8, 0)
  f:SetHeight(24)
  page.y = page.y - 26
  page.child:SetHeight(-page.y + 10)
  row.label = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  row.label:SetPoint("LEFT", 8, 0)
  row.label:SetText(row.desc)
  row.label:SetWordWrap(false)
  f:EnableMouse(true)
  f:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(row.desc, 1, 1, 1, true)
    if row.detail then GameTooltip:AddLine(row.detail, 0.8, 0.8, 0.8, true) end
    local def = Core.SettingDefs[row.kind == "kitspell" and "point" or row.kind][row.key]
    if def then
      if row.def then GameTooltip:AddLine("Default: " .. Options.Format(row.def), 0.7, 0.7, 0.75) end
      GameTooltip:AddLine(string.format("Allowed: %s–%s %s", def.min, def.max, def.unit), 0.7, 0.7, 0.75, true)
      local component = row.kind == "weight" and row.key or def.component
      if component then
        local user = (Core.db.weights or {})[component] or 1
        local bg = (Core.currentProfile or {})[component] or 1
        local value = row.kind == "weight" and 1 or Options.Get(row)
        GameTooltip:AddLine(string.format("%g × tuning %g × battleground %g = %g %s", value, user, bg,
          value * user * bg, row.kind == "weight" and "effective multiplier" or "effective points"), 0.5, 0.9, 0.65, true)
      end
    end
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", GameTooltip_Hide)
  local plus = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  plus:SetSize(24, 20)
  plus:SetPoint("RIGHT", -110, 0)
  plus:SetText("+")
  row.box = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  row.box:SetSize(52, 20)
  row.box:SetPoint("RIGHT", plus, "LEFT", -6, 0)
  row.box:SetAutoFocus(false)
  row.box:SetJustifyH("CENTER")
  local minus = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  minus:SetSize(24, 20)
  minus:SetPoint("RIGHT", row.box, "LEFT", -8, 0)
  minus:SetText("-")
  local dflt = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  row.defaultLabel = dflt
  dflt:SetPoint("LEFT", plus, "RIGHT", 8, 0)
  dflt:SetText("default " .. Options.Format(row.def))
  row.reset = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  row.reset:SetSize(20, 20)
  row.reset:SetPoint("RIGHT", 0, 0)
  row.reset:SetText("x")
  row.label:SetPoint("RIGHT", minus, "LEFT", -8, 0)
  row.label:SetJustifyH("LEFT")
  Options.Wire(row, minus, plus, row.step or 1)
end
