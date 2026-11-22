local _, ns = ...
local Locale, Localization = ns.Macros.Host.Messages, ns.Macros.Host.Localization
local M = ns.Macros
local Panel, Kit, Theme = M.BuildPanel, M.Host.Kit, M.Host.Theme

function Panel.Editor(p)
  local parent = p.right
  p.reviewTitle = Theme.Text(parent, "heading", "titleText")
  p.reviewTitle:SetPoint("TOPLEFT"); Localization.Bind(p.reviewTitle, "macros.buildeditor.3_review_save.70b2cd")
  p.name = Localization.BindWidget(Kit.Input(parent, 200, Locale:Get("macros.buildeditor.macro_name_up_to_16_characters.a18175")), { caption = "macros.buildeditor.macro_name_up_to_16_characters.a18175" })
  p.name:SetMaxLetters(M.NAME_MAX)
  p.name:SetScript("OnTextChanged", function(self)
    Panel.opts.name = self:GetText()
    Panel.saved = nil
    Panel.SaveState()
  end)
  Kit.Tooltip(p.name, function() return { Locale:Get("macros.buildeditor.macro_name.5b3a11"), Locale:Get("macros.buildeditor.leave_empty_to_use_the_spell_name.11db3f") } end)
  p.inputs[#p.inputs + 1] = p.name
  p.status = Theme.Text(parent, "caption", "textMuted")
  p.status:SetJustifyH("RIGHT")
  p.codeCaption = Localization.BindWidget(Kit.Caption(parent, Locale:Get("macros.buildeditor.macro_text.1b290b"), "text"), { [0] = "macros.buildeditor.macro_text.1b290b" })
  p.codeHelp = Theme.Text(parent, "caption", "textMuted")
  Localization.Bind(p.codeHelp, "macros.buildeditor.tab_complete.5906d4")
  p.well = Kit.Editor(parent)
  p.code, p.wellButton = p.well.code, p.well.catch
  Kit.ColorEditBox(p.code, M.Highlight, function() Panel.Analyze() end)
  M.Suggest.Attach(p.code, M.Suggest.CodeProvider, true)
  p.placeholder = Theme.Text(p.well, "body", "textMuted")
  p.placeholder:SetPoint("TOPLEFT", 16, -18)
  p.placeholder:SetPoint("RIGHT", -24, 0)
  p.placeholder:SetJustifyH("LEFT"); p.placeholder:SetWordWrap(true)
  Localization.Bind(p.placeholder, "macros.buildeditor.choose_a_spell_on_the_left_to.f86558")
  p.reportTitle = Localization.BindWidget(Kit.Section(parent, Locale:Get("macros.buildeditor.what_this_will_do.571e73")), { [0] = "macros.buildeditor.what_this_will_do.571e73" })
  p.report = Kit.ScrollArea(parent)
  p.problems = Theme.Text(p.report.body, "body")
  p.problems:SetPoint("TOPLEFT"); p.problems:SetPoint("RIGHT")
  p.problems:SetJustifyH("LEFT"); p.problems:SetWordWrap(true)
  p.explain = Theme.Text(p.report.body, "body", "text")
  p.explain:SetJustifyH("LEFT"); p.explain:SetWordWrap(true)
  p.saveNote = Theme.Text(parent, "body", "textMuted")
  p.saveNote:SetJustifyH("LEFT"); p.saveNote:SetWordWrap(true)
  p.destination = Kit.Select(parent, { width = 160, menu = true, value = "character",
    choices = { { key = "character", label = Locale:Get("highground.profileassignments.this_character.8dfadf") }, { key = "general", label = Locale:Get("macros.buildeditor.all_characters.ffda5f") } },
    onChange = function() Panel.saved = nil; Panel.SaveState() end })
  Kit.Tooltip(p.destination, function() return { Locale:Get("macros.buildeditor.save_destination.d82bba"), Locale:Get("macros.buildeditor.this_character_uses_wow_s_character_macro.4e6b1a") } end)
  p.save = Localization.Bind(Kit.Button(parent, Locale:Get("macros.buildeditor.save_macro.c0712c"), 126, 34, { tone = "accent", onClick = function()
    Panel.Copy(p.destination:GetValue() == "character")
  end }), "macros.buildeditor.save_macro.c0712c")
  p.saveRule = Theme.Fill(parent, "ARTWORK", "border")
  p.saveRule:SetHeight(1)

  -- Tab moves between visible text fields; an open completion list gets
  -- first refusal. Shift-Tab reverses. Folded fields are skipped.
  p.inputs[#p.inputs + 1] = p.code
  for i, field in ipairs(p.inputs) do
    field:SetScript("OnTabPressed", function()
      if Kit.Dropdown.IsShown() and Kit.Dropdown.Frame().box == field then return Kit.Dropdown.Accept() end
      local step = IsShiftKeyDown() and -1 or 1
      for n = 1, #p.inputs do
        local nextField = p.inputs[(i - 1 + step * n) % #p.inputs + 1]
        if nextField:IsVisible() then
          field:ClearFocus(); nextField:SetFocus(); return
        end
      end
    end)
  end
end

function Panel.LayoutReport()
  local p = Panel.frame
  if not p then return end
  local gap = p.problems:GetText() ~= "" and 12 or 0
  local ph = gap > 0 and p.problems:GetStringHeight() or 0
  p.problems:SetHeight(math.max(1, ph))
  p.explain:ClearAllPoints()
  p.explain:SetPoint("TOPLEFT", 0, -ph - gap)
  p.explain:SetPoint("RIGHT")
  local eh = p.explain:GetStringHeight()
  p.explain:SetHeight(math.max(1, eh))
  p.report.body:SetHeight(ph + gap + eh + 4)
  p.report:Refresh()
end

function Panel.LayoutEditor()
  local p = Panel.frame
  local scale, h, w = Panel.Scale(), p:GetHeight(), p.right:GetWidth()
  local function at(frame, point, x, y)
    frame:ClearAllPoints(); frame:SetPoint(point, p.right, point, x, y)
  end
  at(p.name, "TOPLEFT", 0, -48 * scale)
  p.name:SetSize(math.min(220 * scale, w * 0.57), 32 * scale)
  at(p.status, "TOPRIGHT", 0, -58 * scale)
  at(p.codeCaption, "TOPLEFT", 0, -94 * scale)
  at(p.codeHelp, "TOPRIGHT", 0, -94 * scale)
  local top = 114 * scale
  local editorHeight = math.max(144, math.min(224, h * 0.37, h - top - 38 - 184 * scale))
  at(p.well, "TOPLEFT", 0, -top)
  p.well:SetPoint("RIGHT", p.right, "RIGHT")
  p.well:SetHeight(editorHeight)
  p.well.scroll:Refresh()
  at(p.reportTitle, "TOPLEFT", 0, -top - editorHeight - 16)
  at(p.report, "TOPLEFT", 0, -top - editorHeight - 38)
  p.report:SetPoint("BOTTOMRIGHT", p.right, "BOTTOMRIGHT", 0, 94 * scale)
  p.report:Refresh()
  at(p.saveRule, "BOTTOMLEFT", 0, 84 * scale); p.saveRule:SetPoint("RIGHT", p.right, "RIGHT")
  at(p.saveNote, "BOTTOMLEFT", 0, 44 * scale)
  p.saveNote:SetWidth(w); p.saveNote:SetHeight(32 * scale)
  at(p.destination, "BOTTOMLEFT", 0, 0)
  p.destination:SetSize(math.min(180 * scale, w * 0.53), 34 * scale)
  at(p.save, "BOTTOMRIGHT", 0, 0)
  p.save:SetSize(math.min(142 * scale, w * 0.42), 34 * scale)
  Panel.LayoutReport()
end

function Panel.SaveState()
  local p = Panel.frame
  if not (p and p.save) then return end
  local name = Panel.Name()
  local perCharacter = p.destination:GetValue() == "character"
  local existing = M.Find(name, perCharacter)
  local destination = perCharacter and Locale:Get("macros.backups.character.ee9946") or Locale:Get("highground.hub.general.9239ee")
  p.save:SetText(existing and Locale:Get("macros.buildeditor.update_macro.43218c") or Locale:Get("macros.buildeditor.save_macro.c0712c"))
  local valid = Panel.result and Panel.result.errors == 0
  p.save:SetEnabled(valid and not InCombatLockdown())
  p.saveNote:SetText(InCombatLockdown() and Locale:Get("macros.buildeditor.leave_combat_to_save_your_macro.4efe08")
    or Panel.saved or (existing and (Locale:Format("macros.buildeditor.will_update_name_in_destination.eceaa2", { name = name, destination = destination }))
    or (perCharacter and Locale:Get("macros.buildeditor.available_to_this_character_only.f96f5c") or Locale:Get("macros.buildeditor.available_to_all_your_characters.831642"))))
end
