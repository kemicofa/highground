local _, ns = ...
local Core, Options = ns.Core, ns.Options
local page = Options.MakePage("behavior")
local toggles = {}

for _, def in ipairs(ns.OptionsConfig.behavior) do
  if ns.OptionAvailable(def) then
    if def.type == "boolean" then
      local check = CreateFrame("CheckButton", nil, page.child, "UICheckButtonTemplate")
      check:SetSize(24, 24)
      check:SetPoint("TOPLEFT", 16, page.y)
      local label = page.child:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
      label:SetPoint("LEFT", check, "RIGHT", 4, 0)
      label:SetText(def.desc)
      check:SetScript("OnClick", function(self)
        Options.Set({ kind = "option", key = def.key }, self:GetChecked() and true or false)
        Options.RefreshAllRows()
      end)
      toggles[def.key] = check
      page.y = page.y - 28
    else
      Options.Row(page, { kind = "option", key = def.key, def = def.def, step = def.step,
        desc = def.desc, detail = "Unit: " .. def.unit })
    end
  end
end

Options.Section(page, "Current target comparison", "Scores below include your multipliers and this battleground's modifiers. Switch margin also defines how close a GO candidate may be to the leader.")
local refresh = CreateFrame("Button", nil, page.child, "UIPanelButtonTemplate")
refresh:SetSize(160, 22)
refresh:SetPoint("TOPLEFT", 16, page.y)
refresh:SetText("Refresh comparison")
page.y = page.y - 30
local preview = page.child:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
preview:SetPoint("TOPLEFT", 16, page.y)
preview:SetPoint("RIGHT", -16, 0)
preview:SetJustifyH("LEFT")
preview:SetWordWrap(true)
page.preview = preview
local previewTop = -page.y
page.RefreshBehavior = function()
  for key, check in pairs(toggles) do check:SetChecked(Core.O(key)) end
  preview:SetText(Core.TargetComparison())
  page.child:SetHeight(previewTop + (preview:GetStringHeight() or 300) + 20)
end
refresh:SetScript("OnClick", function()
  if Core.active then Core.Tick() end
  Options.RefreshAllRows()
end)
