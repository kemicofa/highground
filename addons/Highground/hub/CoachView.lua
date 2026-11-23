local _, ns = ...
local O, Core, Kit, Theme = ns.Onboarding, ns.Core, ns.Kit, ns.Theme
local C = {}
O.Coach = C

local Text = Kit.Paragraph

local function Box(region, x, y, width, height)
  Kit.Place(region, "BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y, math.max(1, width), math.max(1, height))
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
  w.back = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("highground.coachview.back.b52b36"), 70, 30, { tone = "accent", onClick = function() C.Step(-1) end }), "highground.coachview.back.b52b36")
  w.next = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("highground.coach.next.bc9819"), 100, 30, { tone = "accent", onClick = function() C.Continue() end }), "highground.coach.next.bc9819")
  Kit.Tooltip(w.back, function() return { ns.Locale:Get("highground.coachview.back.b52b36"), ns.Locale:Get("highground.coachview.return_to_the_previous_step_or_the.c9dd2c") } end)
  Kit.Tooltip(w.next, function()
    local step = C.running and C.steps[C.index]
    return { ns.Locale:Get("highground.coach.next.bc9819"), step and step.action and ns.Locale:Get("highground.coachview.follows_the_highlighted_sample_action_you_can.a2b562")
      or ns.Locale:Get("highground.coachview.continue_to_the_next_step.e9c768") }
  end)
  w.done = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("highground.coachview.guides.929a28"), 70, 30, { onClick = function() O.Return(true) end }), "highground.coachview.guides.929a28")
  w.replay = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("highground.coachview.replay.c0f85d"), 70, 30, { onClick = function() C.Replay() end }), "highground.coachview.replay.c0f85d")
  w.enable = Kit.Toggle(w, "", { onChange = function(_, on)
    if C.feature then C.SetFeature(C.feature, on) end
    C.Refresh()
  end })
  Kit.Tooltip(w.enable, function() return { ns.Locale:Get("highground.coach.enable_in_game.2b3569"), ns.Locale:Get("highground.coachview.saves_this_setting_for_normal_play_immediately.a085c3") } end)
  -- Steps about an alert offer its sound: on/off, an audition and a choice.
  w.sound = ns.Localization.BindWidget(Kit.Toggle(w, ns.Locale:Get("guide.sound.toggle"), { onChange = function(_, on)
    if C.sound then C.SetSoundOn(C.sound, on) end
    C.Refresh()
  end }), { label = "guide.sound.toggle" })
  Kit.Tooltip(w.sound, function() return { ns.Locale:Get("guide.sound.toggle"), ns.Locale:Get("guide.sound.tooltip") } end)
  w.play = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("alerts.sample.play"), 110, 28, { onClick = function()
    local ok, problem = ns.Alerts.PlaySample(C.sound)
    if not ok then w.soundNote:SetText(problem); C.Layout() end
  end }), "alerts.sample.play")
  Kit.Tooltip(w.play, function() return { ns.Locale:Get("alerts.sample.play"), { ns.Locale:Get("alerts.sample.description"), "textMuted", true } } end)
  w.cue = Kit.Select(w, { width = 200, menu = true, onChange = function(_, value)
    if C.sound and ns.Alerts.SetSound(C.sound, value) then ns.Alerts.Play(C.sound) end
  end })
  Kit.Tooltip(w.cue, function() return { ns.Locale:Get("alerts.sound.choice"), ns.Locale:Get("guide.sound.choice_tooltip") } end)
  w.soundNote = Text(w, "body", "textMuted")
  w.close = Kit.Button(w, "X", 24, 24, { onClick = function() O.Return() end })
  w.close:SetPoint("TOPRIGHT", -10, -10)
  w:SetScript("OnHide", function() if C.running and not C.changing then O.Return() end end)
  w:Hide(); root:Hide()
  -- Targets move with their windows, so a shown coach follows them on a
  -- native ticker. Only the pointer cue needs per-frame updates, and only
  -- while it moves.
  C.ticker = ns.Util.Every(0.08, C.Tick, "feature guide")
  C.ticker.Stop()
  root:HookScript("OnShow", function() C.ticker.Start() end)
  root:HookScript("OnHide", function() C.ticker.Stop(); C.StopMotion() end)
  C.driver = CreateFrame("Frame", nil, root)
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
  local control, x, row = 26, 14, 12
  for _, b in ipairs({ w.done, w.replay, w.back, w.next }) do
    b.label:SetWordWrap(true)
    b:SetWidth(math.min(width - 28, b.label:GetStringWidth() + 20))
    control = math.max(control, b.label:GetStringHeight() + 10)
  end
  for _, b in ipairs({ w.done, w.replay, w.back, w.next }) do
    if x > 14 and x + b:GetWidth() > width - 14 then x, row = 14, row + control + 6 end
    b:SetHeight(control)
    b:ClearAllPoints(); b:SetPoint("BOTTOMLEFT", x, row)
    x = x + b:GetWidth() + 6
  end
  local footer = row + control + 16
  local sound = C.sound ~= nil
  for _, part in ipairs({ w.sound, w.play, w.soundNote }) do part:SetShown(sound) end
  w.cue:SetShown(sound and #w.cue.choices > 1)
  if sound then
    w.play:SetWidth(math.min(width - 28, w.play.label:GetStringWidth() + 24))
    local cueWidth = math.max(140, width - 28 - w.play:GetWidth() - 8)
    w.play:ClearAllPoints(); w.play:SetPoint("BOTTOMLEFT", 14, footer)
    if w.cue:IsShown() then
      w.cue:SetWidth(math.min(cueWidth, width - 28))
      w.cue:ClearAllPoints()
      if w.play:GetWidth() + 8 + w.cue:GetWidth() <= width - 28 then
        w.cue:SetPoint("LEFT", w.play, "RIGHT", 8, 0)
      else
        w.cue:SetPoint("BOTTOMLEFT", 14, footer); w.play:SetPoint("BOTTOMLEFT", 14, footer + w.cue:GetHeight() + 6)
        footer = footer + w.cue:GetHeight() + 6
      end
    end
    footer = footer + math.max(w.play:GetHeight(), w.cue:IsShown() and w.cue:GetHeight() or 0) + 6
    w.sound.label:SetWordWrap(true); w.sound:SetWidth(width - 28)
    w.sound:SetHeight(math.max(28, w.sound.label:GetStringHeight() + 8))
    w.sound:ClearAllPoints(); w.sound:SetPoint("BOTTOMLEFT", 14, footer)
    footer = footer + w.sound:GetHeight() + 4
    w.soundNote:SetWidth(width - 28); w.soundNote:SetHeight(0)
    local note = w.soundNote:GetText() ~= "" and math.ceil(w.soundNote:GetStringHeight()) or 0
    w.soundNote:SetHeight(math.max(1, note)); w.soundNote:ClearAllPoints(); w.soundNote:SetPoint("BOTTOMLEFT", 14, footer)
    footer = footer + note + (note > 0 and 6 or 0)
  end
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

-- The step alert's Sound switch and sound choice; clears an old audition note.
function C.RefreshSound()
  local w, category = C.win, C.sound
  if not category then return end
  if not C.SoundAvailable(category) then C.sound = nil; return end
  w.sound:SetChecked(C.SoundOn(category), true)
  w.sound:SetEnabled(not InCombatLockdown())
  local choices = ns.Alerts.SoundChoices(category)
  w.cue:SetChoices(choices); w.cue:SetValue(ns.Alerts.Sound(category), true)
  w.soundNote:SetText("")
end

function C.Tick() C.Update() end

local function Drive(_, elapsed) C.Animate(elapsed) end

function C.StopMotion()
  C.motion = nil
  if C.pointer then C.pointer:Hide() end
  if C.driver then C.driver:SetScript("OnUpdate", nil) end
end

-- Start the pointer cue from (x, y) to (toX, toY) in UIParent coordinates.
local function Move(x, y, toX, toY)
  C.motion = { x = x, y = y, toX = toX, toY = toY, elapsed = 0 }
  C.Animate(0)
  if C.motion then C.driver:SetScript("OnUpdate", Drive) end
end

function C.HideSpotlight()
  C.position = nil
  C.spot:Hide(); C.spot.glow:SetActive(false, false, true); C.arrow:Hide()
  C.StopMotion()
  for _, shade in ipairs(C.shades) do shade:Hide() end
end

function C.Animate(elapsed)
  local m = C.motion
  if not m or Core.ReducedMotion() then return C.StopMotion() end
  m.elapsed = m.elapsed + elapsed
  local progress = math.min(1, m.elapsed / 0.45)
  local ease = 1 - (1 - progress) ^ 3
  C.pointer:ClearAllPoints(); C.pointer:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT",
    m.x + (m.toX - m.x) * ease, m.y + (m.toY - m.y) * ease)
  local pulse = progress == 1 and math.sin(math.min(1, (m.elapsed - 0.45) / 0.6) * math.pi * 2) or 0
  C.pointer:SetSize(32 - 4 * pulse, 32 - 4 * pulse)
  C.pointer:SetAlpha(math.min(1, math.max(0, (1.7 - m.elapsed) / 0.35)))
  C.pointer:Show()
  if m.elapsed >= 1.7 then C.StopMotion() end
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
  Move((fl + fr) / 2, (fb + ft) / 2, (l + r) / 2, (b + t) / 2)
end

-- Returns true when the target is highlighted, otherwise false and
-- "missing" (closed or hidden) or "clipped" (scrolled out of its viewport).
function C.Position(target, context)
  local width, height = UIParent:GetWidth(), UIParent:GetHeight()
  if not target or not target:IsVisible() then
    C.HideSpotlight()
    Kit.Place(C.win, "CENTER", UIParent, "CENTER")
    return false, "missing"
  end
  local left, bottom, right, top = Bounds(target)
  if not left then C.HideSpotlight(); return false, "missing" end
  local parent = target:GetParent()
  while parent do
    if parent:GetObjectType() == "ScrollFrame" then
      local l, b, r, t = Bounds(parent)
      if l then left, bottom, right, top = math.max(left, l), math.max(bottom, b), math.min(right, r), math.min(top, t) end
    end
    parent = parent:GetParent()
  end
  if right <= left or top <= bottom then C.HideSpotlight(); return false, "clipped" end
  left, right = Clamp(left - 6, 0, width), Clamp(right + 6, 0, width)
  bottom, top = Clamp(bottom - 6, 0, height), Clamp(top + 6, 0, height)
  local tipWidth, tipHeight, gap = C.win:GetWidth(), C.win:GetHeight(), 24
  local cl, cb, cr, ct
  if context and context:IsVisible() then cl, cb, cr, ct = Bounds(context) end
  local reduced, p = Core.ReducedMotion(), C.position
  -- Keep following moved/scrolled targets, but don't rebuild all spotlight,
  -- shade and arrow anchors every 80 ms when the geometry is unchanged.
  if p and not C.animateTarget and p.width == width and p.height == height
    and p.left == left and p.bottom == bottom and p.right == right and p.top == top
    and p.tipWidth == tipWidth and p.tipHeight == tipHeight and p.reduced == reduced
    and p.cl == cl and p.cb == cb and p.cr == cr and p.ct == ct then return true end
  p = p or {}; C.position = p
  p.width, p.height, p.left, p.bottom, p.right, p.top = width, height, left, bottom, right, top
  p.tipWidth, p.tipHeight, p.reduced = tipWidth, tipHeight, reduced
  p.cl, p.cb, p.cr, p.ct = cl, cb, cr, ct
  Box(C.spot, left, bottom, right - left, top - bottom)
  C.spot:Show(); C.spot.glow:SetActive(true, not reduced)
  Box(C.shades[1], 0, top, width, height - top)
  Box(C.shades[2], 0, 0, width, bottom)
  Box(C.shades[3], 0, bottom, left, top - bottom)
  Box(C.shades[4], right, bottom, width - right, top - bottom)
  for _, shade in ipairs(C.shades) do shade:Show() end

  local l, b, r, t = left, bottom, right, top
  if cl then
    cl, cb, cr, ct = math.min(cl, left), math.min(cb, bottom), math.max(cr, right), math.max(ct, top)
    if width - cr >= tipWidth + gap + 12 or cl >= tipWidth + gap + 12
      or cb >= tipHeight + gap + 12 or height - ct >= tipHeight + gap + 12 then l, b, r, t = cl, cb, cr, ct end
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
    Move(C.lastX or sx, C.lastY or sy, cx, cy)
  end
  C.lastX, C.lastY = cx, cy
  return true
end
