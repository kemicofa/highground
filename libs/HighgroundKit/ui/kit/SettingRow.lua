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
-- :SetDetail(text, tone), :SetBadge(text, tone) (nil hides),
-- :SetActions(frames), :SetDivider(shown), :Layout(width) -> height.
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
  row.toggle.label:SetWordWrap(true); row.toggle.desc:SetWordWrap(true)
  row.badge = Kit.Badge(row, "", "accent")
  row.badge:Hide()
  row.divider = Theme.Fill(row, "BACKGROUND", "border")
  row.divider:SetPoint("BOTTOMLEFT"); row.divider:SetPoint("BOTTOMRIGHT"); row.divider:SetHeight(Z("line"))
  row.actions = opts.actions or {}
  row.detailTone = "textMuted"

  function row:SetChecked(on, silent) self.toggle:SetChecked(on, silent) end
  function row:GetChecked() return self.toggle:GetChecked() end
  function row:SetEnabled(on) self.toggle:SetEnabled(on) end
  function row:SetLabel(text) self.toggle.label:SetText(text or "") end
  function row:SetDetail(text, tone)
    self.toggle.desc:SetText(text or "")
    tone = tone or "textMuted"
    if tone ~= self.detailTone then self.detailTone = tone; Theme.Paint(self.toggle.desc, tone) end
  end
  function row:SetBadge(text, tone)
    if text then self.badge:Set(text, tone or "accent") end
    if self.badge:IsShown() ~= (text ~= nil) then self.badge:SetShown(text ~= nil) end
  end
  function row:SetActions(frames) self.actions = frames or {} end
  function row:SetDivider(shown) if self.divider:IsShown() ~= shown then self.divider:SetShown(shown) end end

  function row:Layout(width)
    width = math.max(1, width or self:GetWidth())
    local gap, pad = S("md"), S("sm")
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
    local textHeight = math.ceil(t.label:GetStringHeight() + (t.desc:GetText() ~= "" and t.desc:GetStringHeight() + S("xs") or 0))
    local toggleHeight = math.max(Z("toggle") + S("xs"), textHeight)
    if not Near(t:GetHeight(), toggleHeight) then t:SetHeight(toggleHeight) end
    Kit.Place(t, "TOPLEFT", self, "TOPLEFT", 0, -pad)
    if badge > 0 then Kit.Place(self.badge, "TOPRIGHT", self, "TOPRIGHT", beside and -actionsWidth or 0, -pad) end
    local height = pad + math.max(toggleHeight, badge > 0 and self.badge:GetHeight() or 0)
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
    return { { row.toggle.label:GetText(), "text", true }, { row.toggle.desc:GetText(), "textMuted", true } }
  end, { anchor = "ANCHOR_RIGHT" })
  return row
end
