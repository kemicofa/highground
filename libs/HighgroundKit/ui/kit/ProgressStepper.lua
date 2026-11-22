local _, ns = ...
local Kit, Theme, Core = ns.Kit, ns.Theme, ns.Core

local function Circle(parent, layer, color, alpha)
  local texture = parent:CreateTexture(nil, layer)
  texture:SetTexture(Core.PROGRESS_CIRCLE)
  texture:SetPoint("CENTER")
  return Theme.Tint(texture, color, alpha)
end

-- Connected workflow steps, distinct from the numeric Kit.Stepper input.
-- opts: steps (labels), current (1-based), tone, width, onSelect(self, index).
-- :SetCurrent(index) updates presentation only; count + 1 marks all complete.
-- Only completed steps call onSelect. Validation and navigation stay with the owner.
function Kit.ProgressStepper(parent, opts)
  opts = opts or {}
  assert(type(opts.steps) == "table" and #opts.steps > 0, "ProgressStepper needs step labels")
  local w = CreateFrame("Frame", nil, parent)
  w.buttons, w.connectors, w.current = {}, {}, 0
  w:SetWidth(opts.width or 540)
  local tone = opts.tone or "accent"
  for i, label in ipairs(opts.steps) do
    local index = i
    local button = CreateFrame("Button", nil, w)
    w.buttons[i] = button
    button.marker = CreateFrame("Frame", nil, button)
    button.marker:EnableMouse(false)
    button.halo = Circle(button.marker, "BACKGROUND", tone, 0.18)
    button.ring = Circle(button.marker, "BORDER", "controlBorder")
    button.face = Circle(button.marker, "ARTWORK", "well")
    button.hover = Circle(button.marker, "OVERLAY", tone, 0.18)
    button.number = Theme.Text(button.marker, "heading", "textMuted")
    button.number:SetPoint("CENTER", 0, 0); button.number:SetText(tostring(i))
    button.check = CreateFrame("Frame", nil, button.marker)
    button.check:SetAllPoints(); button.check:EnableMouse(false)
    button.check.long = Theme.Fill(button.check, "OVERLAY", "onAccent")
    button.check.long:SetRotation(math.pi / 4)
    button.check.short = Theme.Fill(button.check, "OVERLAY", "onAccent")
    button.check.short:SetRotation(-math.pi / 4)
    button.label = Kit.Paragraph(button, "heading", "textMuted")
    button.label:SetJustifyH("CENTER"); button.label:SetText(label)
    button.status = Kit.Paragraph(button, "caption", "textMuted")
    button.status:SetJustifyH("CENTER")
    button.GetText = function(self) return self.label:GetText() end
    Kit.Feedback(button)
    if button.SetMotionScriptsWhileDisabled then button:SetMotionScriptsWhileDisabled(true) end
    button:SetScript("OnClick", function()
      if index < w.current and opts.onSelect then opts.onSelect(w, index) end
    end)
    Kit.Tooltip(button, function()
      return { index .. ". " .. label, button.state == "complete" and (opts.onSelect and ns.Locale:Get("shared.progressstepper.complete_click_to_return_to_this_step.24dd12") or ns.Locale:Get("shared.progressstepper.complete.33b361"))
        or button.state == "current" and ns.Locale:Get("shared.progressstepper.you_are_here_finish_this_step_to.5c19a4") or ns.Locale:Get("shared.progressstepper.coming_next_complete_the_current_step_first.8410dc") }
    end)
    if i > 1 then w.connectors[i - 1] = Theme.Fill(w, "BACKGROUND", "controlBorder") end
  end

  function w:Layout()
    if self.layingOut then return end
    self.layingOut = true
    local scale = math.max(1, Core.FontScale())
    local width, diameter = self:GetWidth() / #self.buttons, 40 * scale
    local labelY, labelHeight, statusHeight = diameter + 16 * scale, 0, 0
    for i, button in ipairs(self.buttons) do
      Kit.Place(button, "TOPLEFT", self, "TOPLEFT", (i - 1) * width, 0, width, self:GetHeight())
      Kit.Place(button.marker, "TOP", button, "TOP", 0, -5 * scale, diameter, diameter)
      button.halo:SetSize(50 * scale, 50 * scale)
      button.ring:SetSize(diameter, diameter); button.face:SetSize(diameter - 4 * scale, diameter - 4 * scale)
      button.hover:SetSize(diameter, diameter)
      Kit.Place(button.check.long, "CENTER", button.check, "CENTER", 3 * scale, 0, 17 * scale, 3 * scale)
      Kit.Place(button.check.short, "CENTER", button.check, "CENTER", -5 * scale, -3 * scale, 9 * scale, 3 * scale)
      Kit.Place(button.label, "TOP", button, "TOP", 0, -labelY, math.max(1, width - 12 * scale), 0)
      button.label:SetHeight(math.ceil(button.label:GetStringHeight()) + 2)
      labelHeight = math.max(labelHeight, button.label:GetHeight())
      button.status:SetWidth(math.max(1, width - 12 * scale)); button.status:SetHeight(0)
      button.status:SetHeight(math.ceil(button.status:GetStringHeight()) + 2)
      statusHeight = math.max(statusHeight, button.status:GetHeight())
    end
    local statusY = labelY + labelHeight + 5 * scale
    local height = statusY + statusHeight
    for _, button in ipairs(self.buttons) do
      button:SetHeight(height)
      Kit.Place(button.status, "TOP", button, "TOP", 0, -statusY)
    end
    for i, line in ipairs(self.connectors) do
      line:ClearAllPoints()
      line:SetPoint("LEFT", self.buttons[i].marker, "RIGHT", 8 * scale, 0)
      line:SetPoint("RIGHT", self.buttons[i + 1].marker, "LEFT", -8 * scale, 0)
      line:SetHeight(3 * scale)
    end
    self:SetHeight(height)
    self.layingOut = nil
  end

  function w:SetCurrent(index)
    index = math.max(1, math.min(#self.buttons + 1, math.floor(tonumber(index) or 1)))
    if self.current == index then return end
    self.current = index
    for i, button in ipairs(self.buttons) do
      local complete, current = i < index, i == index
      button.state = complete and "complete" or current and "current" or "upcoming"
      button.enabled = complete and opts.onSelect ~= nil
      button:SetEnabled(button.enabled)
      button:ResetFeedback()
      button.halo:SetShown(current)
      button.number:SetShown(not complete); button.check:SetShown(complete)
      button.status:SetText(complete and ns.Locale:Get("shared.progressstepper.done.e782e7") or current and ns.Locale:Get("shared.progressstepper.current_step.57706f") or ns.Locale:Get("shared.progressstepper.upcoming.c22db1"))
      Theme.Tint(button.ring, (complete or current) and tone or "controlBorder")
      Theme.Tint(button.face, (complete or current) and tone or "well")
      Theme.Paint(button.number, current and "onAccent" or "textMuted")
      Theme.Paint(button.label, current and tone or complete and "text" or "textMuted")
      Theme.Paint(button.status, current and tone or "textMuted")
    end
    for i, line in ipairs(self.connectors) do Theme.Paint(line, i < index and tone or "controlBorder") end
    self:Layout()
  end

  w:SetScript("OnSizeChanged", function() w:Layout() end)
  Core.OnFontScaleChange(function() w:Layout() end)
  Theme.OnChange(function() w:Layout() end)
  w:SetCurrent(opts.current or 1)
  return w
end
