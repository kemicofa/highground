local _, ns = ...
local B, Kit, Theme = ns.Bounty, ns.Kit, ns.Theme
local E = {}
B.TermsEditor = E

function E.Read(w)
  local methods = {}
  for _, method in ipairs(B.Terms.methods) do
    if w.selectedMethods[method.id] then methods[#methods + 1] = method.id end
  end
  return { killsRequired = tonumber(w.kills:GetText()), killMethods = table.concat(methods, ".") }
end

function E.Set(w, b)
  w.kills:SetText(tostring(B.Terms.Count(b)))
  w.selectedMethods = {}
  for id in (b and b.killMethods or ""):gmatch("[^.]+") do w.selectedMethods[id] = true end
  for id, button in pairs(w.methodButtons) do button:SetSelected(w.selectedMethods[id] == true) end
  w.customize = B.Terms.Custom(b) == true
end

function E.Build(w, parent)
  w.selectedMethods, w.methodButtons = {}, {}
  w.customizeButton = ns.Localization.Bind(Kit.Button(parent, ns.Locale:Get("shared.termseditor.customize_hunt.86b1e7"), 160, 28, { onClick = function()
    w.customize = not w.customize
    w.kills:ClearFocus()
    if w.LayoutPage then w:LayoutPage() end
  end }), "shared.termseditor.customize_hunt.86b1e7")
  w.huntSummary = Theme.Text(parent, "bodySmall", "textMuted")
  w.huntSummary:SetJustifyH("LEFT"); w.huntSummary:SetWordWrap(true)
  w.kills = ns.Localization.BindWidget(Kit.Input(parent, 120, ns.Locale:Get("shared.termseditor.number_of_kills_1_20.665199")), { caption = "shared.termseditor.number_of_kills_1_20.665199" })
  w.kills:SetMaxLetters(2)
  w.killBudget = Theme.Text(parent, "bodySmall", "textMuted")
  w.killBudget:SetJustifyH("LEFT"); w.killBudget:SetJustifyV("TOP"); w.killBudget:SetWordWrap(true)
  w.methodLabel = Theme.Text(parent, "heading", "text"); ns.Localization.Bind(w.methodLabel, "shared.termseditor.preferred_finish_optional.511b37")
  w.methodHint = Theme.Text(parent, "bodySmall", "textMuted")
  w.methodHint:SetJustifyH("LEFT"); w.methodHint:SetJustifyV("TOP"); w.methodHint:SetWordWrap(true)
  ns.Localization.Bind(w.methodHint, "shared.termseditor.any_finish_works_by_default_choose_a.c55a03")
  for _, method in ipairs(B.Terms.methods) do
    local button = Kit.Choice(parent, method.label, 200, "check", function()
      w.selectedMethods[method.id] = not w.selectedMethods[method.id]
      w.methodButtons[method.id]:SetSelected(w.selectedMethods[method.id])
      w.error:SetText("")
      if w.LayoutPage then w:LayoutPage() end
    end)
    Kit.Tooltip(button, { method.label, method.hint })
    w.methodButtons[method.id] = button
  end
  w.kills:HookScript("OnTextChanged", function() w.error:SetText(""); B.Form.Funding(w); if w.LayoutPage then w:LayoutPage() end end)
  w.kills:SetScript("OnEnterPressed", function(self) self:ClearFocus(); w.note:SetFocus() end)
end

function E.Layout(w, width, y, extra)
  w.customizeButton:ClearAllPoints(); w.customizeButton:SetPoint("TOPLEFT", 0, -y)
  w.customizeButton:SetText(w.customize and ns.Locale:Get("shared.termseditor.hide_hunt_options.1621eb") or ns.Locale:Get("shared.termseditor.customize_hunt.86b1e7"))
  w.customizeButton:SetSize(w.customizeButton.label:GetStringWidth() + 24, 28 + extra * 12)
  w.huntSummary:ClearAllPoints(); w.huntSummary:SetPoint("TOPLEFT", w.customizeButton, "TOPRIGHT", 14, 0)
  w.huntSummary:SetWidth(width - w.customizeButton:GetWidth() - 14)
  local terms = E.Read(w)
  local count = terms.killsRequired or 1
  w.huntSummary:SetText(count .. (count == 1 and ns.Locale:Get("shared.termseditor.kill.fab24c") or ns.Locale:Get("shared.termseditor.kills.e2a521")) .. " · "
    .. (terms.killMethods ~= "" and ns.Locale:Get("shared.termseditor.preferred_finish_selected.eefa81") or ns.Locale:Get("shared.claimview.any_finish.36e00e"))
    .. (count > 1 and (ns.Locale:Format("shared.termseditor.value2_total_reward.191eda", { value2 = ns.Util.Gold((B.Terms.Gold(w.gold:GetText()) or 0) * count) })) or ""))
  w.huntSummary:SetHeight(w.huntSummary:GetStringHeight())
  y = y + math.max(w.customizeButton:GetHeight(), w.huntSummary:GetHeight()) + 32
  for _, control in ipairs({ w.kills, w.kills.caption, w.killBudget, w.methodLabel, w.methodHint }) do control:SetShown(w.customize == true) end
  for _, button in pairs(w.methodButtons) do button:SetShown(w.customize == true) end
  if not w.customize then return y end
  w.kills:ClearAllPoints(); w.kills:SetPoint("TOPLEFT", 0, -y); w.kills:SetWidth(width * 0.42)
  w.killBudget:ClearAllPoints(); w.killBudget:SetPoint("TOPLEFT", w.kills, "TOPRIGHT", 14, 0)
  w.killBudget:SetWidth(width * 0.58 - 14); w.killBudget:SetHeight(w.killBudget:GetStringHeight())
  y = y + math.max(w.kills:GetHeight(), w.killBudget:GetHeight()) + 24
  w.methodLabel:ClearAllPoints(); w.methodLabel:SetPoint("TOPLEFT", 0, -y); w.methodLabel:SetWidth(width)
  y = y + w.methodLabel:GetStringHeight() + 10
  w.methodHint:ClearAllPoints(); w.methodHint:SetPoint("TOPLEFT", 0, -y); w.methodHint:SetWidth(width)
  w.methodHint:SetHeight(w.methodHint:GetStringHeight()); y = y + w.methodHint:GetHeight() + 12
  local height = 30 + extra * 12
  -- The left column must leave room for its rim and hover halo inside the
  -- scroll viewport, just as the gap between columns does.
  local gutter = Theme.Space("sm")
  local choiceWidth = width - gutter * 2
  for i, method in ipairs(B.Terms.methods) do
    local button = w.methodButtons[method.id]
    button:ClearAllPoints(); button:SetPoint("TOPLEFT", gutter + (i - 1) % 2 * (choiceWidth + 8) / 2,
      -y - math.floor((i - 1) / 2) * (height + 8))
    button:SetSize((choiceWidth - 8) / 2, height)
  end
  return y + math.ceil(#B.Terms.methods / 2) * (height + 8) + 30
end
