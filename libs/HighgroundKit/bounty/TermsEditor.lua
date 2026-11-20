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
  w.customizeButton = Kit.Button(parent, "Customize hunt", 160, 28, { onClick = function()
    w.customize = not w.customize
    w.kills:ClearFocus()
    if w.LayoutPage then w:LayoutPage() end
  end })
  w.huntSummary = Theme.Text(parent, "bodySmall", "textMuted")
  w.huntSummary:SetJustifyH("LEFT"); w.huntSummary:SetWordWrap(true)
  w.kills = Kit.Input(parent, 120, "NUMBER OF KILLS (1–20)")
  w.kills:SetMaxLetters(2)
  w.killBudget = Theme.Text(parent, "bodySmall", "textMuted")
  w.killBudget:SetJustifyH("LEFT"); w.killBudget:SetJustifyV("TOP"); w.killBudget:SetWordWrap(true)
  w.methodLabel = Theme.Text(parent, "heading", "text"); w.methodLabel:SetText("Preferred finish (optional)")
  w.methodHint = Theme.Text(parent, "bodySmall", "textMuted")
  w.methodHint:SetJustifyH("LEFT"); w.methodHint:SetJustifyV("TOP"); w.methodHint:SetWordWrap(true)
  w.methodHint:SetText("Any finish works by default. Choose a challenge if you want one; the poster reviews its evidence.")
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
  w.customizeButton:SetText(w.customize and "Hide hunt options" or "Customize hunt")
  w.customizeButton:SetSize(w.customizeButton.label:GetStringWidth() + 24, 28 + extra * 12)
  w.huntSummary:ClearAllPoints(); w.huntSummary:SetPoint("TOPLEFT", w.customizeButton, "TOPRIGHT", 14, 0)
  w.huntSummary:SetWidth(width - w.customizeButton:GetWidth() - 14)
  local terms = E.Read(w)
  local count = terms.killsRequired or 1
  w.huntSummary:SetText(count .. (count == 1 and " kill" or " kills") .. " · "
    .. (terms.killMethods ~= "" and "Preferred finish selected" or "Any finish")
    .. (count > 1 and ("\n" .. ns.Util.Gold((B.Terms.Gold(w.gold:GetText()) or 0) * count) .. " total reward") or ""))
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
