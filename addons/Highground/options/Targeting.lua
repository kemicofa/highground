local _, ns = ...
local Core, Theme, Kit, Options = ns.Core, ns.Theme, ns.Kit, ns.Options
local S, Z = Theme.Space, Theme.Size
local page = Options.MakePage("behavior")
local toggles = {}

Options.resetAll = ns.Localization.Bind(Kit.Button(page.child, ns.Locale:Get("highground.targeting.reset_target_tuning.fcc84e"), 230, 32, { onClick = function()
  Core.ResetTuning(); Options.RefreshAllRows(); Options.PointsChanged()
  ns.Util.Say(ns.Locale:Get("highground.targeting.target_tuning_reset_features_appearance_and_cooldown.c74863"))
end }), "highground.targeting.reset_target_tuning.fcc84e")
Options.resetAll:SetPoint("TOPLEFT", S("xl"), page.y)
page.y = page.y - 44

for _, def in ipairs(ns.OptionsConfig.behavior) do
  if ns.OptionAvailable(def) and not def.page then
    if def.type == "boolean" then
      local check = Options.Toggle(page.child, def.desc, nil, function(_, on)
        Options.Set({ kind = "option", key = def.key }, on)
        Options.RefreshAllRows()
      end)
      ns.Localization.BindField(check.label, def, "desc")
      Kit.Tooltip(check, function() return { { def.desc, "text", true } } end, { anchor = "ANCHOR_RIGHT" })
      check:SetPoint("TOPLEFT", S("xl"), page.y - S("xs"))
      toggles[def.key] = check
      page.y = page.y - 28
    else
      Options.Row(page, { kind = "option", key = def.key, def = def.def, step = def.step,
        source = def, desc = def.desc })
    end
  end
end

Options.Section(page, ns.Locale:Get("highground.targeting.current_target_comparison.07aec6"), ns.Locale:Get("highground.targeting.scores_below_include_your_multipliers_and_this.41c036"), "highground.targeting.current_target_comparison.07aec6", "highground.targeting.scores_below_include_your_multipliers_and_this.41c036")
local refresh = ns.Localization.Bind(Kit.Button(page.child, ns.Locale:Get("highground.targeting.refresh_comparison.3c13d9"), 160, Z("control")), "highground.targeting.refresh_comparison.3c13d9")
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
