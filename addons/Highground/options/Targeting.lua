local _, ns = ...
local Core, Theme, Kit, Options = ns.Core, ns.Theme, ns.Kit, ns.Options
local S, Z = Theme.Space, Theme.Size
local page = Options.MakePage("behavior")
local toggles = {}

for _, def in ipairs(ns.OptionsConfig.behavior) do
  if ns.OptionAvailable(def) and not def.page then
    if def.type == "boolean" then
      local check = Options.Toggle(page.child, def.desc, nil, function(_, on)
        Options.Set({ kind = "option", key = def.key }, on)
        Options.RefreshAllRows()
      end)
      check:SetPoint("TOPLEFT", S("xl"), page.y - S("xs"))
      toggles[def.key] = check
      page.y = page.y - 28
    else
      Options.Row(page, { kind = "option", key = def.key, def = def.def, step = def.step,
        desc = def.desc, detail = "Unit: " .. def.unit })
    end
  end
end

Options.Section(page, "Current target comparison", "Scores below include your multipliers and this battleground's modifiers. Switch margin also defines how close a GO candidate may be to the leader.")
local refresh = Kit.Button(page.child, "Refresh comparison", 160, Z("control"))
refresh:SetPoint("TOPLEFT", S("xl"), page.y)
page.y = page.y - 30
local preview = Theme.Text(page.child, "body")
preview:SetPoint("TOPLEFT", S("xl"), page.y)
preview:SetPoint("RIGHT", -S("xl"), 0)
preview:SetJustifyH("LEFT")
preview:SetWordWrap(true)
page.preview = preview
local previewTop = -page.y
page.RefreshBehavior = function()
  for key, check in pairs(toggles) do check:SetChecked(Core.O(key), true) end
  preview:SetText(Core.TargetComparison())
  page.child:SetHeight(previewTop + (preview:GetStringHeight() or 300) + 20)
end
refresh:SetScript("OnClick", function()
  if Core.active then Core.Tick() end
  Options.RefreshAllRows()
end)
