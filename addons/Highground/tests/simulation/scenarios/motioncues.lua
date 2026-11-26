local test, new, equal = ...

local function near(actual, expected, why)
  assert(math.abs(actual - expected) < 0.00001, why .. ": " .. tostring(actual) .. " ~= " .. tostring(expected))
end

local function setup(client)
  local sim = new(client or "cata")
  local M, T = sim.ns.Motion, sim.ns.Theme
  return sim, M, T
end

test("warm transitions allocate nothing and restarted records advance once", function()
  local sim, M, T = setup()
  local a, b = T.Fill(sim.env.UIParent, "ARTWORK", "accent"), T.Fill(sim.env.UIParent, "ARTWORK", "accent")
  -- A long transition keeps the driver awake: the simulator's own Show and
  -- Hide events allocate. Compiled traces are GC objects too.
  local keep = T.Fill(sim.env.UIParent, "ARTWORK", "accent")
  keep:SetAlpha(0); M.Alpha(keep, 1, 30)
  local driver
  for _, f in ipairs(sim.updateFrames) do
    local script = f:GetScript("OnUpdate")
    if script and debug.getinfo(script, "S").source:find("Motion.lua", 1, true) then driver = f end
  end
  local update = driver:GetScript("OnUpdate")
  local function cycle()
    M.Alpha(a, 0, "hover"); update(driver, 0.05); M.Alpha(a, 1, "exit")
    M.Show(b, false, "exit"); update(driver, 0.05); M.Show(b, true, "hover")
  end
  for _ = 1, 4 do cycle() end
  if jit then jit.off() end
  collectgarbage("collect"); collectgarbage("stop")
  local before = collectgarbage("count")
  for _ = 1, 100 do cycle() end
  local allocated = collectgarbage("count") - before
  collectgarbage("restart")
  if jit then jit.on() end
  M.Stop(keep, 1)
  assert(allocated < 1, "retargeting reuses pooled records: " .. allocated .. " KiB")
  -- A completion callback restarting another transition must not let the
  -- new transition advance during the frame that started it.
  local owner = sim.env.CreateFrame("Frame", nil, sim.env.UIParent)
  M.Alpha(b, 0, 0); M.Alpha(b, 1, 1)
  local restarted
  M.Value(owner, 0, 1, 0.04, function(_, value)
    if value == 1 and not restarted then
      restarted = true
      M.Stop(b); M.Alpha(b, 0.2, 0); M.Alpha(b, 1, 1, "linear")
    end
  end)
  sim:advance(0.05)
  near(b:GetAlpha(), 0.2, "restarted transition starts on the next frame")
  sim:advance(0.5)
  near(b:GetAlpha(), 0.6, "then advances linearly")
  sim:advance(0.6)
  equal(b:GetAlpha(), 1, "and settles exactly")
  assert(not M.IsPlaying(a) and not M.IsPlaying(b), "driver is idle")
end)

test("named easings shape scalar transitions and reject unknown names", function()
  local sim, M = setup()
  local owner = sim.env.CreateFrame("Frame", nil, sim.env.UIParent)
  local seen = {}
  local function draw(_, value) seen.value = value end
  for name, expected in pairs({ linear = 0.5, ["in"] = 0.125, inOut = 0.5, out = 0.875 }) do
    M.Stop(owner)
    M.Value(owner, 0, 1, 1, draw, name)
    sim:advance(0.5)
    near(seen.value, expected, name .. " midpoint")
    M.Finish(owner)
    equal(seen.value, 1, name .. " endpoint")
  end
  equal(M.Smoothing("inOut"), "IN_OUT", "native smoothing shares the easing names")
  equal(M.Smoothing(), "OUT", "default easing")
  assert(not pcall(M.Value, owner, 0, 1, 1, draw, "bounce"), "unknown easing is a coding error")
  assert(not pcall(M.Smoothing, "bounce"), "unknown native easing is a coding error")
end)

test("interrupted, hidden and re-shown fades always land on the requested state", function()
  local sim, M, T = setup()
  local parent = sim.env.CreateFrame("Frame", nil, sim.env.UIParent)
  local region = T.Fill(parent, "ARTWORK", "accent")
  region:Hide()
  M.Show(region, true, "page")
  sim:advance(0.05)
  parent:Hide()
  sim:advance(0.05)
  assert(not M.IsPlaying(region) and region:IsShown() and region:GetAlpha() == 1, "hidden owner settles a fade-in")
  parent:Show()
  M.Show(region, false, "page")
  sim:advance(0.05)
  parent:Hide(); sim:advance(0.05)
  assert(not region:IsShown() and not M.IsPlaying(region), "hidden owner settles a fade-out and hides")
  parent:Show()
  M.Show(region, true, "page"); M.Show(region, false, "page"); M.Show(region, true, "page")
  sim:advance(0.3)
  assert(region:IsShown() and region:GetAlpha() == 1, "last request wins after rapid toggles")
  M.Show(region, false, "page"); sim:advance(0.05)
  sim.ns.Core.SetReducedMotion(true)
  assert(not region:IsShown() and not M.IsPlaying(region), "reduced motion completes the pending hide now")
  M.Show(region, true, "page")
  assert(region:IsShown() and region:GetAlpha() == 1 and not M.IsPlaying(region), "later fades are instant")
end)

test("protected frames keep their visibility in combat and fade alpha instead", function()
  local sim, M = setup()
  local panel = sim.env.CreateFrame("Frame", nil, sim.env.UIParent)
  sim.env.CreateFrame("Button", nil, panel, "SecureActionButtonTemplate")
  local hidden = sim.env.CreateFrame("Frame", nil, sim.env.UIParent)
  sim.env.CreateFrame("Button", nil, hidden, "SecureActionButtonTemplate")
  hidden:Hide()
  sim:setCombat(true)
  assert(M.Locked(panel) and not M.Locked(sim.env.CreateFrame("Frame", nil, sim.env.UIParent)), "only protected frames lock")
  M.Show(panel, false, "exit")
  sim:advance(0.2)
  assert(panel:IsShown() and panel:GetAlpha() == 0, "fades out without a protected Hide")
  M.Show(panel, true, "hover")
  sim:advance(0.2)
  equal(panel:GetAlpha(), 1, "fades back in")
  M.Show(hidden, true, "hover")
  assert(not hidden:IsShown(), "a hidden protected frame waits for its owner")
  M.Mark(panel, false); equal(panel:GetAlpha(), 0, "mark removal is alpha-only")
  M.Mark(panel, true); equal(panel:GetAlpha(), 1, "mark return is alpha-only")
  assert(not M.Slide(panel, 0, 8).group:IsPlaying(), "protected frames never translate")
  assert(not M.PopCue(panel, 1.1):IsPlaying() and (M.PopCue(panel):Play() or true)
    and not M.PopCue(panel).group:IsPlaying(), "protected frames never scale in combat")
  sim:setCombat(false)
  M.Show(panel, false, 0)
  assert(not panel:IsShown(), "out of combat the same call hides it")
  sim:assertHealthy()
end)

test("a hide deferred by combat happens after combat unless the frame was shown again", function()
  local sim, M = setup()
  local function secure()
    local f = sim.env.CreateFrame("Frame", nil, sim.env.UIParent)
    sim.env.CreateFrame("Button", nil, f, "SecureActionButtonTemplate")
    return f
  end
  local function listener()
    for _, f in ipairs(sim.frames) do
      local script = f.scripts.OnEvent
      if script and debug.getinfo(script, "S").source:find("Motion.lua", 1, true) then return f end
    end
  end
  local faded, instant, reshown, restored, marked = secure(), secure(), secure(), secure(), secure()
  sim:setCombat(true)
  M.Show(faded, false, "exit"); M.Show(instant, false, 0); M.Show(reshown, false, 0)
  M.Show(restored, false, 0); M.Mark(marked, false)
  sim:advance(0.2)
  assert(faded:IsShown() and faded:GetAlpha() == 0, "combat keeps it shown but transparent")
  assert(listener().events.PLAYER_REGEN_ENABLED, "a pending hide waits for the end of combat")
  M.Show(reshown, true, 0)
  restored:SetAlpha(1) -- its owner made it visible directly
  sim:setCombat(false)
  assert(not faded:IsShown() and faded:GetAlpha() == 0, "a faded-out frame hides when combat ends")
  assert(not instant:IsShown(), "so does an immediate hide")
  assert(not marked:IsShown() and marked:GetAlpha() == 1, "a removed mark hides at its rest alpha")
  assert(reshown:IsShown() and reshown:GetAlpha() == 1, "a later Show cancels the pending hide")
  assert(restored:IsShown(), "a frame made visible again is not hidden")
  assert(not listener().events.PLAYER_REGEN_ENABLED, "nothing stays registered")
  sim:setCombat(true); M.Show(reshown, false, 0); sim:setCombat(false)
  assert(not reshown:IsShown(), "the listener re-arms for the next combat")
  sim:assertHealthy()
end)

for _, client in ipairs({ "cata", "retail" }) do
test(client .. " native cues replay, stop and respect reduced motion", function()
  local sim, M, T = setup(client)
  local Core = sim.ns.Core
  local flash = T.Fill(sim.env.UIParent, "ARTWORK", "success")
  flash:SetAlpha(0)
  local cue = M.Flash(flash)
  assert(cue.group:IsPlaying() and cue:IsPlaying(), "flash plays natively")
  equal(cue.fade.fromAlpha, T.Alpha("flash"), "peak follows its token")
  equal(cue.fade.duration, T.Motion("flash"), "duration follows its token")
  equal(M.Flash(flash, 0.3, 1.8, "in"), cue, "one group per region is reused")
  equal(cue.fade.duration, 1.8, "explicit seconds update the cue")
  M.Stop(flash)
  assert(not cue.group:IsPlaying() and flash:GetAlpha() == 0, "Stop ends one-shot cues at rest")
  local card = sim.env.CreateFrame("Frame", nil, sim.env.UIParent)
  local slide = M.Slide(card, 0, -6)
  assert(slide.group:IsPlaying(), "slide plays on plain frames")
  equal(slide.jump.offsetY, -6, "starts offset"); equal(slide.glide.offsetY, 6, "settles at its anchor")
  equal(slide.glide.duration, T.Motion("slide"), "slide duration token")
  local pop = M.PopCue(card, 1.02, 1.06)
  assert(not pop.group:IsPlaying(), "building a cue does not play it")
  equal(M.Pop(card, 1.02, 1.06), pop, "Pop replays the same cue")
  assert(pop.group:IsPlaying(), "pop plays")
  equal(pop.grow.scale, 1.02, "grows"); near(pop.shrink.scale, 1 / 1.02, "and returns")
  near(pop.grow.duration + pop.shrink.duration, T.Motion("pop"), "pop spans its token")
  local pulse = M.Pulse(card, 0.55, 1)
  pulse:Play()
  equal(pulse.fade.duration, T.Motion("pulse"), "pulse half-cycle token")
  Core.SetReducedMotion(true)
  assert(not pop.group:IsPlaying() or not pop:IsPlaying(), "reduced motion settles the pop")
  equal(card:GetAlpha(), 0.55, "loops hold a steady alpha")
  M.Flash(flash)
  assert(not cue.group:IsPlaying() and flash:GetAlpha() == 0, "no flash under reduced motion")
  assert(not M.Slide(card, 0, -6).group:IsPlaying(), "no slide under reduced motion")
  Core.SetReducedMotion(false)
  assert(not cue.group:IsPlaying(), "turning motion back on never replays a one-shot")
  card:Hide()
  assert(not M.Slide(card, 0, -6).group:IsPlaying(), "hidden regions do not slide")
end)
end

test("a rounded hover layer fades all its pieces with one transition", function()
  local sim, M = setup()
  local b = sim.ns.Kit.Button(sim.env.UIParent, "Apply", 120, 24)
  equal(b.hover, nil, "the hover layer is built on the first hover")
  b.scripts.OnEnter(b)
  local hover = b.hover
  assert(#hover.parts > 0, "rounded layer has corner pieces")
  sim:advance(0.05)
  assert(M.IsPlaying(hover), "the layer owns the transition")
  for _, part in ipairs(hover.parts) do
    assert(not M.IsPlaying(part), "pieces have no records of their own")
    assert(part:IsShown() and part:GetAlpha() == hover:GetAlpha(), "pieces follow the layer")
  end
  b.scripts.OnLeave(b)
  sim:advance(0.05)
  b.scripts.OnEnter(b)
  sim:advance(0.3)
  for _, part in ipairs(hover.parts) do assert(part:IsShown() and part:GetAlpha() == 1, "re-entry settles every piece") end
  b.scripts.OnLeave(b)
  sim:advance(0.3)
  assert(not hover:IsShown(), "fade-out hides the layer")
  for _, part in ipairs(hover.parts) do assert(not part:IsShown(), "and every piece") end
  b.scripts.OnEnter(b); b:Hide(); b:Show()
  assert(not hover:IsShown() and not M.IsPlaying(hover), "hiding resets the layer at once")
  for _, part in ipairs(hover.parts) do assert(not part:IsShown(), "with its pieces") end
end)

test("progress eases from the drawn value; first, hidden and secret values are immediate", function()
  local sim, M = setup("retail")
  local bar = sim.env.CreateFrame("StatusBar", nil, sim.env.UIParent)
  M.Progress(bar, 0.2)
  equal(bar.value, 0.2, "first value is drawn immediately")
  M.Progress(bar, 0.8)
  assert(M.IsPlaying(bar) and bar.value == 0.2, "a change eases")
  sim:advance(0.1)
  assert(bar.value > 0.2 and bar.value < 0.8, "progresses")
  local midway = bar.value
  M.Progress(bar, 0.4)
  near(bar.value, midway, "retargeting starts where the bar is drawn")
  sim:advance(0.3)
  equal(bar.value, 0.4, "settles exactly")
  local secret = { secret = true }
  M.Progress(bar, 0.9); M.Progress(bar, secret)
  assert(bar.value == secret and not M.IsPlaying(bar), "secret values bypass motion")
  M.Progress(bar, 0.5)
  equal(bar.value, 0.5, "after a secret value the next value is immediate")
  bar:Hide(); M.Progress(bar, 0.1)
  assert(bar.value == 0.1 and not M.IsPlaying(bar), "hidden bars jump")
end)
