local _, ns = ...
local Kit, Theme, Motion = ns.Kit, ns.Theme, ns.Motion

-- Rounded layers have a center and corner bands. Fade every piece together
-- so hover, press and reset never leave clipped ends or stranded corners.
local function ShowLayer(layer, on, duration)
  Motion.Show(layer, on, duration)
  for _, part in ipairs(layer.parts or {}) do Motion.Show(part, on, duration) end
end

-- Shared hover/press feedback, independent of click handlers and tooltips.
-- Press relief is a tinted layer; labels and hit areas stay in place.
-- opts: press, pressParent, edge, onEnter, onLeave. The control supplies .hover.
function Kit.Feedback(frame, opts)
  opts = opts or {}
  local hover = frame.hover
  ShowLayer(hover, false, 0)
  if opts.press then
    if frame.cornerRadius and not opts.pressParent then
      frame.pressed = Kit.RoundedFill(frame, "overlayStrong", nil, "BORDER")
    else
      frame.pressed = Theme.Fill(opts.pressParent or frame, "BORDER", "overlayStrong")
      frame.pressed:SetAllPoints(hover)
    end
    ShowLayer(frame.pressed, false, 0)
  end
  local function Enabled(self) return not self.wbDisabled and self.enabled ~= false end
  local function Paint(self, immediate)
    local enabled = Enabled(self)
    local hovering = enabled and self.wbHovered and not self.wbPressed
    ShowLayer(hover, hovering, immediate and 0 or (self.wbPressed and "press" or hovering and "hover" or "exit"))
    if self.pressed then
      ShowLayer(self.pressed, enabled and self.wbPressed, immediate and 0 or "press")
    end
    if opts.edge then
      opts.edge:SetColor(enabled and self.wbHovered and "controlBorder" or self.selected and "accent" or "border")
    end
    if self.RefreshFinish then self:RefreshFinish(immediate) end
  end
  function frame:ResetFeedback()
    self.wbHovered, self.wbPressed = nil, nil
    Paint(self, true)
  end
  frame:SetScript("OnEnter", function(self)
    if not Enabled(self) then return end
    self.wbHovered = true
    Paint(self)
    if opts.onEnter then opts.onEnter(self) end
  end)
  frame:SetScript("OnLeave", function(self)
    self.wbHovered, self.wbPressed = nil, nil
    Paint(self)
    if opts.onLeave then opts.onLeave(self) end
  end)
  if opts.press then
    frame:SetScript("OnMouseDown", function(self)
      if not Enabled(self) then return end
      self.wbPressed = true
      Paint(self)
    end)
    frame:SetScript("OnMouseUp", function(self) self.wbPressed = nil; Paint(self) end)
  end
  frame:HookScript("OnHide", function(self) self:ResetFeedback() end)
end

-- A persistent focus boundary with a short underline reveal. Blur clears
-- it immediately, including when the editor's containing window closes.
function Kit.Focus(box, edge, line)
  box.focusGlow = Kit.Glow and Kit.Glow(box, "focus", 5)
  Motion.Mark(line, false, true)
  box:SetScript("OnEditFocusGained", function()
    Motion.Mark(line, true, false, "focus")
    edge:SetColor("focus")
    if box.focusGlow then box.focusGlow:SetActive(true) end
  end)
  local function Clear()
    Motion.Mark(line, false, true)
    edge:SetColor("controlBorder")
    if box.focusGlow then box.focusGlow:SetActive(false, false, true) end
  end
  box:SetScript("OnEditFocusLost", Clear)
  box:HookScript("OnHide", Clear)
end

-- Dialogs keep their normal Show/Hide lifecycle. Closing is immediate, so
-- focus, Escape, borrowed pages and click-away menus never wait on a fade.
-- from: an alpha token, read on each opening so theme changes apply too.
function Kit.Entrance(frame, duration, from)
  frame:HookScript("OnShow", function(self)
    Motion.Reveal(self, duration or "enter", from and Theme.Alpha(from))
  end)
  frame:HookScript("OnHide", function(self) Motion.Stop(self, 1) end)
end
