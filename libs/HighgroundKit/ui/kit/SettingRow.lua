local _, ns = ...
local Kit, Theme = ns.Kit, ns.Theme
local S, Z = Theme.Space, Theme.Size

---------------------------------------------------------------------------
-- One switch in a list of related ones: its title and explanation, a
-- short status badge and room for trailing controls (a picker, an action).
-- Rows stack inside a card with a divider between them. The owner supplies
-- all copy and calls Layout(width) after width, text or font changes.
--
-- opts: label, detail, checked, onChange(self, on), actions (frames).
-- :SetChecked(on, silent), :GetChecked(), :SetEnabled(on), :SetLabel(text),
-- :SetDetail(text), :SetNote(text, tone) (a line below the detail that
-- stays readable while the switch is disabled, such as why; nil hides),
-- :SetBadge(text, tone) (nil hides), :SetActions(frames),
-- :SetDivider(shown), :Layout(width) -> height.
-- Actions sit on the right; on a narrow row they move below the text.
---------------------------------------------------------------------------
local function Near(a, b) return math.abs(a - b) < 0.001 end

-- Below this text width the actions take a line of their own.
local MIN_TEXT = 220

function Kit.SettingRow(parent, opts)
  opts = opts or {}
  local row = CreateFrame("Frame", nil, parent)
  row.toggle = Kit.Toggle(row, opts.label, { desc = opts.detail or "", checked = opts.checked,
    onChange = opts.onChange and function(_, on) opts.onChange(row, on) end })
  -- Text gets explicit widths so its height is measured at the new width.
  local label, desc = row.toggle.label, row.toggle.desc
  label:SetWordWrap(true); desc:SetWordWrap(true)
  label:ClearAllPoints(); label:SetPoint("TOPLEFT", row.toggle.box, "TOPRIGHT", S("md"), 0)
  desc:ClearAllPoints(); desc:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -S("xs"))
  row.note = Kit.Paragraph(row, "body", "warning")
  row.note:Hide()
  row.noteTone = "warning"
  row.badge = Kit.Badge(row, "", "accent")
  row.badge:Hide()
  row.divider = Theme.Fill(row, "BACKGROUND", "border")
  row.divider:SetPoint("BOTTOMLEFT"); row.divider:SetPoint("BOTTOMRIGHT"); row.divider:SetHeight(Z("line"))
  row.actions = opts.actions or {}

  function row:SetChecked(on, silent) self.toggle:SetChecked(on, silent) end
  function row:GetChecked() return self.toggle:GetChecked() end
  function row:SetEnabled(on) self.toggle:SetEnabled(on) end
  function row:SetLabel(text) self.toggle.label:SetText(text or "") end
  function row:SetDetail(text) self.toggle.desc:SetText(text or "") end
  function row:SetNote(text, tone)
    if text then
      self.note:SetText(text)
      tone = tone or "warning"
      if tone ~= self.noteTone then self.noteTone = tone; Theme.Paint(self.note, tone) end
    end
    if self.note:IsShown() ~= (text ~= nil) then self.note:SetShown(text ~= nil) end
  end
  function row:SetBadge(text, tone)
    if text then self.badge:Set(text, tone or "accent") end
    if self.badge:IsShown() ~= (text ~= nil) then self.badge:SetShown(text ~= nil) end
  end
  function row:SetActions(frames) self.actions = frames or {} end
  function row:SetDivider(shown) if self.divider:IsShown() ~= shown then self.divider:SetShown(shown) end end

  function row:Layout(width)
    width = math.max(1, width or self:GetWidth())
    local gap, pad = S("md"), S("md")
    local badge = self.badge:IsShown() and self.badge:Layout() + gap or 0
    local actionsWidth, actionsHeight = 0, 0
    for _, frame in ipairs(self.actions) do
      if frame:IsShown() then
        actionsWidth = actionsWidth + frame:GetWidth() + gap
        actionsHeight = math.max(actionsHeight, frame:GetHeight())
      end
    end
    local beside = width - badge - actionsWidth >= Kit.Scale(MIN_TEXT)
    local textWidth = math.max(1, width - badge - (beside and actionsWidth or 0))
    local t = self.toggle
    if not Near(t:GetWidth(), textWidth) then t:SetWidth(textWidth) end
    local lineWidth = math.max(1, textWidth - Z("toggle") - S("md"))
    for _, text in ipairs({ t.label, t.desc, self.note }) do
      if not Near(text:GetWidth(), lineWidth) then text:SetWidth(lineWidth) end
    end
    local hasDetail = (t.desc:GetText() or "") ~= ""
    local textHeight = math.ceil(t.label:GetStringHeight() + (hasDetail and t.desc:GetStringHeight() + S("xs") or 0))
    local toggleHeight = math.max(Z("toggle") + S("xs"), textHeight)
    if not Near(t:GetHeight(), toggleHeight) then t:SetHeight(toggleHeight) end
    Kit.Place(t, "TOPLEFT", self, "TOPLEFT", 0, -pad)
    if badge > 0 then Kit.Place(self.badge, "TOPRIGHT", self, "TOPRIGHT", beside and -actionsWidth or 0, -pad) end
    local height = pad + math.max(toggleHeight, badge > 0 and self.badge:GetHeight() or 0)
    if self.note:IsShown() then
      Kit.Place(self.note, "TOPLEFT", self, "TOPLEFT", Z("toggle") + S("md"), -(pad + toggleHeight + S("xs")))
      height = math.max(height, pad + toggleHeight + S("xs") + math.ceil(self.note:GetStringHeight()))
    end
    local x, y = beside and width or Z("toggle") + S("md"), beside and -pad or -(height + gap)
    for _, frame in ipairs(self.actions) do
      if frame:IsShown() then
        if beside then
          x = x - frame:GetWidth()
          Kit.Place(frame, "TOPLEFT", self, "TOPLEFT", x, y)
          x = x - gap
        else
          Kit.Place(frame, "TOPLEFT", self, "TOPLEFT", x, y)
          x = x + frame:GetWidth() + gap
        end
      end
    end
    if beside then height = math.max(height, pad + actionsHeight)
    elseif actionsHeight > 0 then height = height + gap + actionsHeight end
    height = math.ceil(height + pad)
    if not Near(self:GetWidth(), width) or not Near(self:GetHeight(), height) then self:SetSize(width, height) end
    return height
  end
  Kit.Tooltip(row.toggle, function()
    local lines = { { row.toggle.label:GetText(), "text", true }, { row.toggle.desc:GetText(), "textMuted", true } }
    if row.note:IsShown() then lines[3] = { row.note:GetText(), row.noteTone, true } end
    return lines
  end, { anchor = "ANCHOR_RIGHT" })
  return row
end
