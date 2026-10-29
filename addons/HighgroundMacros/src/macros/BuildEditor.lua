local _, ns = ...
local M = ns.Macros
local Panel, Kit, Theme = M.BuildPanel, M.Host.Kit, M.Host.Theme

function Panel.Editor(p)
  local parent = p.right
  p.reviewTitle = Theme.Text(parent, "heading", "titleText")
  p.reviewTitle:SetPoint("TOPLEFT"); p.reviewTitle:SetText("3. Review & save")
  p.name = Kit.Input(parent, 200, "Macro name (up to 16 characters)")
  p.name:SetMaxLetters(M.NAME_MAX)
  p.name:SetScript("OnTextChanged", function(self)
    Panel.opts.name = self:GetText()
    Panel.saved = nil
    Panel.SaveState()
  end)
  Kit.Tooltip(p.name, { "Macro name", "Leave empty to use the spell name. Saving with an existing name updates "
    .. "that macro in the chosen destination." })
  p.inputs[#p.inputs + 1] = p.name
  p.status = Theme.Text(parent, "caption", "textMuted")
  p.status:SetJustifyH("RIGHT")
  p.codeCaption = Kit.Caption(parent, "Macro text", "text")
  p.codeHelp = Theme.Text(parent, "caption", "textMuted")
  p.codeHelp:SetText("TAB: COMPLETE")
  p.well = Kit.Editor(parent)
  p.code, p.wellButton = p.well.code, p.well.catch
  Kit.ColorEditBox(p.code, M.Highlight, function() Panel.Analyze() end)
  M.Suggest.Attach(p.code, M.Suggest.CodeProvider, true)
  p.placeholder = Theme.Text(p.well, "body", "textMuted")
  p.placeholder:SetPoint("TOPLEFT", 16, -18)
  p.placeholder:SetPoint("RIGHT", -24, 0)
  p.placeholder:SetJustifyH("LEFT"); p.placeholder:SetWordWrap(true)
  p.placeholder:SetText("Choose a spell on the left to begin.\n\nAlready have a macro? Paste it here.\nSuggestions appear beside the line you are editing.")
  p.reportTitle = Kit.Section(parent, "What this will do")
  p.report = Kit.ScrollArea(parent)
  p.problems = Theme.Text(p.report.body, "body")
  p.problems:SetPoint("TOPLEFT"); p.problems:SetPoint("RIGHT")
  p.problems:SetJustifyH("LEFT"); p.problems:SetWordWrap(true)
  p.explain = Theme.Text(p.report.body, "body", "text")
  p.explain:SetJustifyH("LEFT"); p.explain:SetWordWrap(true)
  p.saveNote = Theme.Text(parent, "body", "textMuted")
  p.saveNote:SetJustifyH("LEFT"); p.saveNote:SetWordWrap(true)
  p.destination = Kit.Select(parent, { width = 160, menu = true, value = "character",
    choices = { { key = "character", label = "This character" }, { key = "general", label = "All characters" } },
    onChange = function() Panel.saved = nil; Panel.SaveState() end })
  Kit.Tooltip(p.destination, { "Save destination", "This character uses WoW's Character macro slots. "
    .. "All characters uses its General slots." })
  p.save = Kit.Button(parent, "Save macro", 126, 34, { tone = "accent", onClick = function()
    Panel.Copy(p.destination:GetValue() == "character")
  end })
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
  local destination = perCharacter and "Character" or "General"
  p.save:SetText(existing and "Update macro" or "Save macro")
  local valid = Panel.result and Panel.result.errors == 0
  p.save:SetEnabled(valid and not InCombatLockdown())
  p.saveNote:SetText(InCombatLockdown() and "Leave combat to save your macro."
    or Panel.saved or (existing and ("Will update " .. name .. " in " .. destination .. ".")
    or (perCharacter and "Available to this character only." or "Available to all your characters.")))
end
