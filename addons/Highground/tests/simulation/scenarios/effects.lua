local test, new, equal = ...

local function near(a, b, why)
  assert(math.abs(a - b) < 0.00001, why .. ": " .. tostring(a) .. " ~= " .. tostring(b))
end

for _, client in ipairs({ "cata", "retail" }) do
test(client .. " a running glint follows its owner's resized bounds", function()
  local sim = new(client, nil, function(s) dofile("../../tools/wowsim/geometry.lua")(s) end)
  local parent = sim.env.CreateFrame("Frame", nil, sim.env.UIParent)
  parent:SetSize(348, 43); parent:SetPoint("TOPLEFT", 100, -100)
  local sweep = sim.ns.Kit.Sweep(parent)
  sweep:Play(); sim:advance(0.2)
  local progress = sweep.progress
  parent:SetSize(80, 58)
  -- The lightweight simulator does not dispatch native resize callbacks.
  for _, hook in ipairs(parent.hooks.OnSizeChanged or {}) do hook(parent, 80, 58) end
  equal(sweep.progress, progress, "resizing keeps the current animation progress")
  local owner, light = sim.bounds(parent), sim.bounds(sweep.light)
  assert(light[1] >= owner[1] and light[1] + light[3] <= owner[1] + owner[3], "glint fits the new width immediately")
  sim:advance(1)
  assert(not sweep.light:IsShown(), "finished glints leave no visible texture")
  sim.ns.Theme.Repaint()
  assert(not sweep.light:IsShown(), "repainting cannot revive a finished glint")
end)

test(client .. " illumination follows action, selection, disabled and focus states", function()
  local sim = new(client)
  local Kit, T, M = sim.ns.Kit, sim.ns.Theme, sim.ns.Motion
  local action = Kit.Button(sim.env.UIParent, "Apply", 120, 28, { tone = "accent" })
  local secondary = Kit.Button(sim.env.UIParent, "Details", 120, 28)
  assert(action.glow.active and not secondary.glow.active, "only the primary action glows at rest")
  secondary.scripts.OnEnter(secondary)
  sim:advance(0.04)
  assert(secondary.glow.active and M.IsPlaying(secondary.glow), "hover light eases in")
  secondary.scripts.OnLeave(secondary)
  sim:advance(0.2)
  assert(not secondary.glow:IsShown(), "leaving removes the hover halo")
  secondary.scripts.OnEnter(secondary)
  sim:advance(0.04)
  secondary.scripts.OnLeave(secondary)
  secondary:Hide(); secondary:Show()
  assert(not secondary.glow:IsShown() and not M.IsPlaying(secondary.glow), "reopening during a fade cannot strand a hover halo")
  local tiny = Kit.Button(sim.env.UIParent, "X", 24, 24)
  tiny.scripts.OnEnter(tiny)
  sim:advance(0.04)
  assert(tiny.sweep.light:GetWidth() <= tiny:GetWidth() - 6, "glints stay inside small close and stepper controls")
  action:Disable()
  assert(not action.glow:IsShown() and not M.IsPlaying(action.glow), "disabled primary loses its halo")
  action:Enable()
  assert(action.glow:IsShown(), "enabled action restores its importance")
  Kit.Paint(secondary, "selected")
  sim:advance(0.1)
  local progress = secondary.sweep.progress
  Kit.Paint(secondary, "selected")
  equal(secondary.sweep.progress, progress, "refreshing selection never replays its glint")
  Kit.Paint(secondary, "panel")
  sim:advance(1)
  assert(not secondary.glow:IsShown(), "deselection removes the halo")
  T.Use("ember")
  near(action.glow.parts[1].gradient.from[1], T.Rgb("accent")[1], "halo repaints live")
  near(action.glow.parts[1].gradient.from[4], T.Alpha("glow"), "halo intensity follows the palette")
  T.Use("parchment")
  equal(action.glow.parts[1].gradient.from[4], 0, "paper has no emitted light")
  local input = Kit.Input(sim.env.UIParent, 200, "Player")
  input:SetFocus()
  assert(input.focusGlow.active and input.focusLine:IsShown(), "focus has light and a persistent underline")
  input:ClearFocus()
  assert(not input.focusGlow:IsShown(), "blur clears the focus halo immediately")
end)

test(client .. " sweeps and pulses cancel on hide and respect reduced motion in combat", function()
  local sim = new(client)
  local Kit, Core, M, T = sim.ns.Kit, sim.ns.Core, sim.ns.Motion, sim.ns.Theme
  sim:enemy("Alpha"); sim:join(); sim:setCombat(true)
  local hit = Core.rows[1]
  local parent = sim.env.CreateFrame("Frame", nil, hit:GetParent())
  parent:SetSize(260, 80)
  local glow, sweep = Kit.Glow(parent, "attackEdge", 8), Kit.Sweep(parent)
  glow:SetActive(true, true)
  sweep:Play()
  sim:advance(0.15)
  assert(glow.pulse:IsPlaying() and M.IsPlaying(sweep), "tactical decoration animates in combat")
  local start = sweep.progress
  glow:SetActive(true, true)
  equal(sweep.progress, start, "repeated tactical updates do not restart motion")
  Core.SetReducedMotion(true)
  assert(not M.IsPlaying(sweep) and sweep.light:GetAlpha() == 0, "reduced motion removes the moving glint")
  assert(not glow.pulse.group:IsPlaying(), "native pulse is stopped immediately")
  equal(glow:GetAlpha(), 0.55, "urgency remains as steady light")
  Core.SetReducedMotion(false)
  assert(glow.pulse.group:IsPlaying() and not M.IsPlaying(sweep), "only the ongoing signal resumes")
  T.Use("parchment")
  assert(not glow.pulse:IsPlaying(), "zero-glow palettes suspend decorative loops")
  T.Use("highground")
  assert(glow.pulse:IsPlaying(), "restoring light resumes the ongoing signal")
  parent:Hide()
  assert(not glow.pulse:IsPlaying() and not M.IsPlaying(sweep), "hidden effects release animation work")
  parent:Show()
  assert(glow.pulse:IsPlaying(), "visible ongoing signal resumes")
  glow:SetActive(false, false, true)
  assert(not glow.pulse:IsPlaying() and not glow:IsShown(), "clearing urgency stops the effect")
  assert(hit:IsShown() and hit:GetScale() == 1, "secure hit area stays fixed")
  equal(parent.mouseEnabled, nil, "effects never enable input on the owner")
  equal(glow.mouseEnabled, false, "halo never intercepts input")
  equal(sweep.mouseEnabled, false, "sweep never intercepts input")
end)
end

test("modern and legacy gradient APIs preserve theme colour and alpha endpoints", function()
  local sim = new("retail")
  local T = sim.ns.Theme
  local legacy = T.Gradient(sim.env.UIParent, "BACKGROUND", "accent", "glow", "HORIZONTAL", 0.2, 0.8)
  local methods = getmetatable(sim.env.UIParent).__index
  sim.env.CreateColor = function(...) return { ... } end
  methods.SetGradient = function(self, direction, first, last)
    self.gradient = { direction = direction, from = first, to = last }
  end
  local modern = T.Gradient(sim.env.UIParent, "BACKGROUND", "accent", "glow", "HORIZONTAL", 0.2, 0.8)
  for i = 1, 4 do
    equal(modern.gradient.from[i], legacy.gradient.from[i], "matching start")
    equal(modern.gradient.to[i], legacy.gradient.to[i], "matching end")
  end
  T.Register("light-test", { color = { accent = { 0.4, 0.6, 0.8 } }, alpha = { glow = 0.5 } })
  T.Use("light-test")
  equal(modern.gradient.to[3], 0.8, "modern colour repaints")
  near(modern.gradient.from[4], 0.1, "start follows the live alpha token")
  near(modern.gradient.to[4], 0.4, "end follows the live alpha token")
  local button = sim.ns.Kit.Button(sim.env.UIParent, "Apply", 120, 24)
  for _, part in ipairs(button.sheen.parts) do
    if part.wbCorner then
      equal(part.texture, sim.ns.Core.CONTROL_CORNERS, "modern gradients retain the alpha texture")
      equal(part.colorTexture, nil, "corner mask is never replaced with a solid texture")
      equal(part.gradient.to[1], T.Rgb("metalHighlight")[1], "corner gradient follows the theme")
    end
  end
end)
