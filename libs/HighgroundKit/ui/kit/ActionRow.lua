local _, ns = ...
local Kit, Theme = ns.Kit, ns.Theme
local S, Z = Theme.Space, Theme.Size

-- One line of text with a trailing action. The owner calls Layout after
-- width or font changes; details yield space to the label on narrow views.
function Kit.ActionRow(parent, opts)
  local row = CreateFrame("Frame", nil, parent)
  row:EnableMouse(true)
  row.label = Theme.Text(row, opts.role or "body", opts.color or "text")
  row.detail = Theme.Text(row, "body", "textMuted")
  for _, text in ipairs({ row.label, row.detail }) do
    text:SetJustifyH("LEFT"); text:SetJustifyV("MIDDLE"); text:SetWordWrap(false)
  end
  row.label:SetText(opts.label or "")
  row.detail:SetText(opts.detail or "")
  row.button = Kit.Button(row, opts.action or "Open", nil, nil, { onClick = opts.onClick })
  row.button.label:SetWordWrap(false)
  row.button.label:ClearAllPoints()
  row.button.label:SetPoint("LEFT", S("lg"), 0); row.button.label:SetPoint("RIGHT", -S("lg"), 0)
  local lines = opts.tooltip or { { opts.label or "", opts.color or "text", true }, opts.detail or "", opts.action or "Open" }
  Kit.Tooltip(row, lines, { anchor = "ANCHOR_RIGHT" })
  Kit.Tooltip(row.button, lines, { anchor = "ANCHOR_RIGHT" })
  row:HookScript("OnHide", function(self)
    local owner = GameTooltip:GetOwner()
    if owner == self or owner == self.button then GameTooltip_Hide() end
  end)
  local divider = Theme.Fill(row, "BACKGROUND", "border")
  divider:SetPoint("BOTTOMLEFT"); divider:SetPoint("BOTTOMRIGHT"); divider:SetHeight(Z("line"))
  function row:Layout(width)
    width = math.max(1, width or self:GetWidth())
    local gap, padding = S("lg"), S("sm") * 2
    local height = math.ceil(math.max(Z("row"), self.label:GetStringHeight() + padding,
      self.detail:GetStringHeight() + padding, self.button.label:GetStringHeight() + padding))
    local actionWidth = math.min(width, math.max(Z("tabWidth"), self.button.label:GetStringWidth() + gap * 2))
    local available = math.max(1, width - actionWidth - gap)
    local detail = self.detail:GetText() ~= "" and available >= 260 * math.max(1, ns.Core.FontScale())
    local labelWidth = detail and math.floor(available * 0.52) or available
    if self.detail:IsShown() ~= detail then self.detail:SetShown(detail) end
    if math.abs(self:GetWidth() - width) > 0.001 or math.abs(self:GetHeight() - height) > 0.001 then self:SetSize(width, height) end
    Kit.Place(self.label, "LEFT", self, "LEFT", 0, 0, labelWidth, height)
    Kit.Place(self.detail, "LEFT", self, "LEFT", labelWidth + gap, 0, math.max(1, available - labelWidth - gap), height)
    Kit.Place(self.button, "RIGHT", self, "RIGHT", 0, 0, actionWidth, height)
    return height
  end
  return row
end
