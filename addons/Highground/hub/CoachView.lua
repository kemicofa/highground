local _, ns = ...
local O, Core, Kit, Theme = ns.Onboarding, ns.Core, ns.Kit, ns.Theme
local C = {}
O.Coach = C

local Text = Kit.Paragraph

local function Box(region, x, y, width, height)
  region:ClearAllPoints(); region:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
  region:SetSize(math.max(1, width), math.max(1, height))
end

local function Clamp(value, minimum, maximum) return math.max(minimum, math.min(maximum, value)) end

function C.Build()
  if C.root then return end
  local root = CreateFrame("Frame", nil, UIParent)
  C.root = root
  root:SetAllPoints(); root:SetFrameStrata("FULLSCREEN_DIALOG"); root:SetFrameLevel(300)
  root:EnableMouse(false)
  C.shades = {}
  for i = 1, 4 do C.shades[i] = Theme.Fill(root, "BACKGROUND", "bg", 0.64) end
  local spot = CreateFrame("Frame", nil, root)
  C.spot = spot; spot:EnableMouse(false)
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local edge = Theme.Fill(spot, "OVERLAY", "accent")
    if side == "TOP" or side == "BOTTOM" then
      edge:SetPoint(side .. "LEFT"); edge:SetPoint(side .. "RIGHT"); edge:SetHeight(3)
    else
      edge:SetPoint("TOP" .. side); edge:SetPoint("BOTTOM" .. side); edge:SetWidth(3)
    end
  end
  spot.glow = Kit.Glow(spot, "accent", 10)
  local arrow = CreateFrame("Frame", nil, root)
  C.arrow = arrow; arrow:SetAllPoints(root); arrow:EnableMouse(false)
  arrow.shaft = Theme.Fill(arrow, "OVERLAY", "accent")
  arrow.shaft:SetSize(30, 3); arrow.shaft:SetPoint("CENTER")
  arrow.head = {}
  for i = 1, 2 do
    local stroke = Theme.Fill(arrow, "OVERLAY", "accent")
    stroke:SetSize(14, 3); arrow.head[i] = stroke
  end
  C.pointer = root:CreateTexture(nil, "OVERLAY", nil, 7)
  C.pointer:SetTexture("Interface\\CURSOR\\Point"); C.pointer:SetSize(32, 32); C.pointer:Hide()

  -- Not a coordinated tool: this coach must remain above the sample window
  -- and its child forms. All shading and highlighting pass mouse input through.
  local w = CreateFrame("Frame", "HighgroundSampleCoach", root, "BackdropTemplate")
  C.win = w
  w:SetFrameLevel(310); w:SetClampedToScreen(true); w:EnableMouse(true)
  Theme.Backdrop(w, { alpha = "dialog", border = "borderAccent" })
  w.caption = Text(w, "label", "accent"); w.caption:SetPoint("TOPLEFT", 18, -16)
  w.scroll = Kit.ScrollArea(w)
  w.title = Text(w.scroll.body, "heading", "text")
  w.body = Text(w.scroll.body, "bodyLarge", "text")
  w.hint = Text(w.scroll.body, "body", "textMuted")
  w.back = Kit.Button(w, "Back", 70, 30, { tone = "accent", onClick = function() C.Step(-1) end })
  w.next = Kit.Button(w, "Next", 100, 30, { tone = "accent", onClick = function() C.Continue() end })
  Kit.Tooltip(w.back, { "Back", "Return to the previous step, or the guide choices at the start." })
  Kit.Tooltip(w.next, function()
    local step = C.running and C.steps[C.index]
    return { "Next", step and step.action and "Follows the highlighted sample action. You can also click it yourself."
      or "Continue to the next step." }
  end)
  w.done = Kit.Button(w, "Guides", 70, 30, { onClick = O.Return })
  w.replay = Kit.Button(w, "Replay", 70, 30, { onClick = function() C.Replay() end })
  w.enable = Kit.Toggle(w, "", { onChange = function(_, on)
    if C.feature and not InCombatLockdown() then Core.SetFeature(C.feature, on) end
    C.Refresh()
  end })
  Kit.Tooltip(w.enable, { "Enable in game", "Saves this setting for normal play immediately." })
  w.close = Kit.Button(w, "X", 24, 24, { onClick = O.Return })
  w.close:SetPoint("TOPRIGHT", -10, -10)
  w:SetScript("OnHide", function() if C.running and not C.changing then O.Return() end end)
  w:Hide(); root:Hide()
  root:SetScript("OnUpdate", function(_, elapsed)
    C.Animate(elapsed)
    C.elapsed = (C.elapsed or 0) + elapsed
    if C.elapsed >= 0.08 then C.elapsed = 0; C.Update() end
  end)
  Core.OnFontScaleChange(function() if C.running then C.Refresh() end end)
  Theme.OnChange(function() if C.running then C.Refresh() end end)
end

function C.Layout()
  local w = C.win
  local scale = math.max(1, Core.FontScale())
  local width = math.min(450, 350 + (scale - 1) * 140)
  width = math.min(width, UIParent:GetWidth() - 32)
  w:SetWidth(width)
  local top, y = 18 + w.caption:GetStringHeight() + 12, 0
  local textWidth = width - 44
  for _, fs in ipairs({ w.title, w.body, w.hint }) do
    fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", 0, -y); fs:SetWidth(textWidth)
    -- Native FontStrings retain their previous height, which can truncate
    -- a longer step before GetStringHeight measures it. Clear that limit.
    fs:SetHeight(0); fs:SetHeight(math.ceil(fs:GetStringHeight()) + 2)
    y = y + fs:GetHeight() + 12
  end
  local control, x = math.max(26, w.next.label:GetStringHeight() + 10), 14
  for _, b in ipairs({ w.done, w.replay, w.back, w.next }) do
    b:SetSize(b.label:GetStringWidth() + 20, control)
    b:ClearAllPoints(); b:SetPoint("BOTTOMLEFT", x, 12)
    x = x + b:GetWidth() + 6
  end
  local footer = control + 28
  w.enable:SetShown(C.feature ~= nil)
  if C.feature then
    w.enable.label:SetWordWrap(true); w.enable:SetWidth(width - 28)
    w.enable:SetHeight(math.max(28, w.enable.label:GetStringHeight() + 8))
    w.enable:ClearAllPoints(); w.enable:SetPoint("BOTTOMLEFT", 14, footer)
    footer = footer + w.enable:GetHeight() + 6
  end
  w:SetHeight(math.min(top + y + footer, UIParent:GetHeight() - 32))
  w.scroll:ClearAllPoints(); w.scroll:SetPoint("TOPLEFT", 14, -top)
  w.scroll:SetPoint("BOTTOMRIGHT", -14, footer)
  w.scroll.body:SetHeight(y); w.scroll:Refresh()
end

function C.HideSpotlight()
  C.spot:Hide(); C.spot.glow:SetActive(false, false, true); C.arrow:Hide()
  C.pointer:Hide(); C.motion = nil
  for _, shade in ipairs(C.shades) do shade:Hide() end
end

function C.Animate(elapsed)
  local m = C.motion
  if not m or Core.ReducedMotion() then C.pointer:Hide(); return end
  m.elapsed = m.elapsed + elapsed
  local progress = math.min(1, m.elapsed / 0.45)
  local ease = 1 - (1 - progress) ^ 3
  C.pointer:ClearAllPoints(); C.pointer:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
    m.x + (m.toX - m.x) * ease, m.y + (m.toY - m.y) * ease)
  local pulse = progress == 1 and math.sin(math.min(1, (m.elapsed - 0.45) / 0.6) * math.pi * 2) or 0
  C.pointer:SetSize(32 - 4 * pulse, 32 - 4 * pulse)
  C.pointer:SetAlpha(math.min(1, math.max(0, (1.7 - m.elapsed) / 0.35)))
  C.pointer:Show()
  if m.elapsed >= 1.7 then C.pointer:Hide(); C.motion = nil end
end

local function Bounds(target)
  local x, y = target:GetCenter()
  if type(x) ~= "number" or type(y) ~= "number" then return end
  local owner = target.GetEffectiveScale and target or target:GetParent()
  local scale = owner:GetEffectiveScale() / UIParent:GetEffectiveScale()
  return (x - target:GetWidth() / 2) * scale, (y - target:GetHeight() / 2) * scale,
    (x + target:GetWidth() / 2) * scale, (y + target:GetHeight() / 2) * scale
end

function C.PointAt(target, from)
  local l, b, r, t = Bounds(target)
  local fl, fb, fr, ft = Bounds(from)
  if not l or not fl then return end
  C.motion = { x = (fl + fr) / 2, y = (fb + ft) / 2, toX = (l + r) / 2, toY = (b + t) / 2, elapsed = 0 }
  C.Animate(0)
end

function C.Position(target, context)
  local width, height = UIParent:GetWidth(), UIParent:GetHeight()
  if not target or not target:IsVisible() then
    C.HideSpotlight()
    C.win:ClearAllPoints(); C.win:SetPoint("CENTER", UIParent, "CENTER")
    return false
  end
  local left, bottom, right, top = Bounds(target)
  if not left then C.HideSpotlight(); return false end
  local parent = target:GetParent()
  while parent do
    if parent:GetObjectType() == "ScrollFrame" then
      local l, b, r, t = Bounds(parent)
      if l then left, bottom, right, top = math.max(left, l), math.max(bottom, b), math.min(right, r), math.min(top, t) end
    end
    parent = parent:GetParent()
  end
  if right <= left or top <= bottom then C.HideSpotlight(); return false end
  left, right = Clamp(left - 6, 0, width), Clamp(right + 6, 0, width)
  bottom, top = Clamp(bottom - 6, 0, height), Clamp(top + 6, 0, height)
  Box(C.spot, left, bottom, right - left, top - bottom)
  C.spot:Show(); C.spot.glow:SetActive(true, not Core.ReducedMotion())
  Box(C.shades[1], 0, top, width, height - top)
  Box(C.shades[2], 0, 0, width, bottom)
  Box(C.shades[3], 0, bottom, left, top - bottom)
  Box(C.shades[4], right, bottom, width - right, top - bottom)
  for _, shade in ipairs(C.shades) do shade:Show() end

  local tipWidth, tipHeight, gap = C.win:GetWidth(), C.win:GetHeight(), 24
  local l, b, r, t = left, bottom, right, top
  if context and context:IsVisible() then
    local cl, cb, cr, ct = Bounds(context)
    if cl then
      cl, cb, cr, ct = math.min(cl, left), math.min(cb, bottom), math.max(cr, right), math.max(ct, top)
    end
    if cl and (width - cr >= tipWidth + gap + 12 or cl >= tipWidth + gap + 12
      or cb >= tipHeight + gap + 12 or height - ct >= tipHeight + gap + 12) then l, b, r, t = cl, cb, cr, ct end
  end
  local tipX, tipY, direction
  if width - r >= tipWidth + gap + 12 then
    tipX, tipY, direction = r + gap, (top + bottom - tipHeight) / 2, "left"
  elseif l >= tipWidth + gap + 12 then
    tipX, tipY, direction = l - gap - tipWidth, (top + bottom - tipHeight) / 2, "right"
  elseif b >= tipHeight + gap + 12 then
    tipX, tipY, direction = (left + right - tipWidth) / 2, b - gap - tipHeight, "up"
  else
    tipX, tipY, direction = (left + right - tipWidth) / 2, t + gap, "down"
  end
  tipX, tipY = Clamp(tipX, 12, width - tipWidth - 12), Clamp(tipY, 12, height - tipHeight - 12)
  Box(C.win, tipX, tipY, tipWidth, tipHeight)
  local sx, sy, ex, ey
  local cx, cy = (left + right) / 2, (top + bottom) / 2
  if direction == "left" then sx, sy, ex, ey = tipX - 4, Clamp(cy, tipY + 24, tipY + tipHeight - 24), right + 3, cy
  elseif direction == "right" then sx, sy, ex, ey = tipX + tipWidth + 4, Clamp(cy, tipY + 24, tipY + tipHeight - 24), left - 3, cy
  elseif direction == "up" then sx, sy, ex, ey = Clamp(cx, tipX + 24, tipX + tipWidth - 24), tipY + tipHeight + 4, cx, bottom - 3
  else sx, sy, ex, ey = Clamp(cx, tipX + 24, tipX + tipWidth - 24), tipY - 4, cx, top + 3 end
  local dx, dy = ex - sx, ey - sy
  local length, angle = math.sqrt(dx * dx + dy * dy), math.atan2(dy, dx)
  C.arrow.shaft:ClearAllPoints(); C.arrow.shaft:SetPoint("CENTER", UIParent, "BOTTOMLEFT", (sx + ex) / 2, (sy + ey) / 2)
  C.arrow.shaft:SetSize(math.max(1, length), 3); C.arrow.shaft:SetRotation(angle)
  for i, stroke in ipairs(C.arrow.head) do
    local sign = i == 1 and 1 or -1
    stroke:ClearAllPoints()
    stroke:SetPoint("CENTER", UIParent, "BOTTOMLEFT", ex - 5 * math.cos(angle) - sign * 4 * math.sin(angle),
      ey - 5 * math.sin(angle) + sign * 4 * math.cos(angle))
    stroke:SetRotation(angle - sign * math.pi / 4)
  end
  C.arrow:Show(); C.side = direction
  if C.animateTarget then
    C.animateTarget = nil
    C.motion = { x = C.lastX or sx, y = C.lastY or sy, toX = cx, toY = cy, elapsed = 0 }
    C.Animate(0)
  end
  C.lastX, C.lastY = cx, cy
  return true
end
