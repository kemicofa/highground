local _, ns = ...
local Core, Theme, Kit, Options = ns.Core, ns.Theme, ns.Kit, ns.Options
local pages, byKey = {}, {}
Options.featureBoxes, Options.featurePages = {}, {}
for _, def in ipairs(ns.OptionsConfig.features) do if def.key then byKey[def.key] = def end end

-- Each switch has one real control in its addon's page. The following body
-- holds that addon's detailed preferences below its full list of switches.
function Options.FeaturePage(key, owner)
  local page = Options.MakePage(key)
  local root, items = page.child, {}
  page.featureGroups = {}
  Options.featurePages[owner or "shared"] = page
  pages[#pages + 1] = page
  local list = CreateFrame("Frame", nil, root)
  list:SetPoint("TOPLEFT", 24, -4); list:SetPoint("RIGHT", -24, 0)
  local group
  for _, def in ipairs(ns.OptionsConfig.features) do
    if def.group then
      group = nil
      if def.module == owner and ns.OptionAvailable(def) then
        group = { key = def.group, rows = {} }
        local heading = Kit.Section(list, def.group)
        group.heading = heading; page.featureGroups[#page.featureGroups + 1] = group
        items[#items + 1] = { frame = heading, group = group }
      end
    elseif def.module == owner and def.key ~= "bountyMarks" and ns.OptionAvailable(def) then
      local cb = Kit.Toggle(list, def.label, { desc = def.desc, onChange = function(_, on)
        Core.SetFeature(def.key, on)
      end })
      cb.label:SetWordWrap(true); cb.desc:SetWordWrap(true)
      cb.key, cb.option, cb.page = def.key, def, page
      Options.Tip(cb, def.label, def.desc)
      Options.featureBoxes[#Options.featureBoxes + 1] = cb
      if group then group.rows[#group.rows + 1] = cb end
      items[#items + 1] = { frame = cb, option = def }
    end
  end
  local body = CreateFrame("Frame", nil, root)
  body:SetPoint("TOPLEFT", list, "BOTTOMLEFT", -24, -12)
  body:SetPoint("TOPRIGHT", list, "BOTTOMRIGHT", 24, -12)
  body:SetHeight(1)
  page.child, page.y = body, -4
  function page.LayoutFeatures()
    if page.layingOut then return end
    page.layingOut = true
    local y = 0
    for _, item in ipairs(items) do
      local f, def = item.frame, item.option
      f:ClearAllPoints(); f:SetPoint("TOPLEFT", def and def.parent and 18 or 0, -y)
      f:SetPoint("RIGHT", -12, 0)
      local height = def and math.max(52, f.label:GetStringHeight() + f.desc:GetStringHeight() + 18) or 32
      f:SetHeight(height)
      if item.group then item.group.offset = y end
      y = y + height + 8
    end
    list:SetHeight(math.max(1, y)); root:SetHeight(y + body:GetHeight() + 28)
    page.layingOut = nil
  end
  function page.SelectGroup(name)
    for _, g in ipairs(page.featureGroups) do
      if g.key == name then page.scroll:SetVerticalScroll(g.offset or 0); return true end
    end
    return false
  end
  page.RefreshGeneral = function()
    for _, item in ipairs(items) do
      local cb, def = item.frame, item.option
      if def then
        cb:SetChecked(Core.db[def.key] ~= false, true)
        local parent, enabled = def.parent, ns.Modules.FeatureEnabled(def.key)
        while parent do
          if Core.db[parent] == false then enabled = false end
          parent = byKey[parent] and byKey[parent].parent
        end
        cb:SetEnabled(enabled)
        local parentDef = def.parent and byKey[def.parent]
        cb.desc:SetText(def.desc .. (not ns.Modules.FeatureEnabled(def.key) and " Enable this addon and reload."
          or not enabled and parentDef and (" Enable " .. parentDef.label .. " first.") or ""))
      end
    end
    page.LayoutFeatures()
  end
  root:HookScript("OnSizeChanged", page.LayoutFeatures)
  body:HookScript("OnSizeChanged", page.LayoutFeatures)
  Core.OnFontScaleChange(function() if page.frame:IsVisible() then page.LayoutFeatures() end end)
  page.LayoutFeatures()
  return page
end

function Options.RefreshFeatures()
  for _, page in ipairs(pages) do page.RefreshGeneral() end
  for _, destinations in pairs(Options.addonPages) do
    local page = destinations.appearance and Options.byKey[destinations.appearance]
    if page and page.RefreshAppearance and page.frame:IsVisible() then page.RefreshAppearance() end
  end
end

local general = Options.FeaturePage("general")
Options.general = general
Options.Section(general, "All HUD panels", "Master scale multiplies the individual scales on each addon's Appearance page.")
local scale = Core.THEME.scale
local row = Options.Stepper(general.child, 60)
row:SetPoint("TOPLEFT", 24, general.y)
local reset = Kit.Button(general.child, "Default scale", 160, 26)
reset:SetPoint("LEFT", row, "RIGHT", 12, 0)
local scaleHint = Theme.Text(general.child, "body", "textMuted")
scaleHint:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, -10)
ns.RefreshUIScaleOption = function()
  row.box:SetText(math.floor((Core.db.scale or scale.default) * 100 + 0.5) .. "%")
  scaleHint:SetText(InCombatLockdown() and "Applies after combat"
    or string.format("All HUD panels · %d–%d%%", scale.min * 100, scale.max * 100))
end
row.minus:SetScript("OnClick", function() ns.SetUIScale(Core.db.scale - scale.step) end)
row.plus:SetScript("OnClick", function() ns.SetUIScale(Core.db.scale + scale.step) end)
row.box:SetScript("OnEnterPressed", function(self)
  local value = tonumber((self:GetText():gsub("%%", "")))
  if value then ns.SetUIScale(value / 100) end
  ns.RefreshUIScaleOption(); self:ClearFocus()
end)
row.box:SetScript("OnEscapePressed", function(self) ns.RefreshUIScaleOption(); self:ClearFocus() end)
row.box:HookScript("OnEditFocusLost", ns.RefreshUIScaleOption)
reset:SetScript("OnClick", function() ns.SetUIScale(scale.default) end)
general.y = general.y - 70
general.child:SetHeight(-general.y + 12)
local refresh = general.RefreshGeneral
general.RefreshGeneral = function() refresh(); ns.RefreshUIScaleOption() end

-- Old guide/internal callers can still name a feature group. Route to its
-- owner instead of maintaining a second hidden set of global controls.
local sharedGroup = general.SelectGroup
function general.SelectGroup(name)
  if name == "Guild" then name = "Bounties" end
  for _, page in ipairs(pages) do
    for _, group in ipairs(page.featureGroups) do
      if group.key == name then
        ns.Hub.Open(page.key); if page == general then sharedGroup(name) else page.SelectGroup(name) end; return true
      end
    end
  end
  return false
end

for _, owner in ipairs({ "battlegrounds", "arena", "macros" }) do
  local page = Options.FeaturePage(Options.addonPages[owner].settings, owner)
  Options.AddAlertControls(page, owner)
  if owner == "battlegrounds" then
    page.review = Options.Link(page, "Use these features", function()
      if ns.Onboarding then ns.Onboarding.Reviewed("features") end
    end)
  end
end
