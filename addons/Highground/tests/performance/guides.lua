local t, new = ...

t.test("battleground guide steps repaint nothing and keep their sample panels shown", function()
  -- The game's ColorMixin: every CreateColor is a new table.
  local colors = 0
  local sim = new("retail", nil, function(s)
    s.env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end
    s.env.CreateColor = function(r, g, b, a)
      colors = colors + 1
      return { r = r, g = g, b = b, a = a, SetRGBA = function(c, ...) c.r, c.g, c.b, c.a = ... end }
    end
    local methods = getmetatable(s.env.CreateFrame("Frame"):CreateTexture()).__index
    methods.SetGradient = function() end
  end)
  local O, C, Core, Theme = sim.ns.Onboarding, sim.ns.Onboarding.Coach, sim.ns.Core, sim.ns.Theme
  Core.SetFeature("quickCalls", true)
  local function Run(key, each)
    O.Start(key); sim:advance(1)
    while C.running do
      if each then each(C.steps[C.index].id) end
      C.Continue(); sim:advance(1)
    end
  end
  Run("enemies"); Run("objectives") -- builds every sample widget once
  local repaints, stops, hides, starts = 0, 0, 0, 0
  local repaint, stop, start = Theme.Repaint, Core.StopTest, sim.ns.BattlegroundsPreview.Start
  Theme.Repaint = function(...) repaints = repaints + 1; return repaint(...) end
  Core.StopTest = function(...) stops = stops + 1; return stop(...) end
  sim.ns.BattlegroundsPreview.Start = function(...) starts = starts + 1; return start(...) end
  sim.ns.QuickCalls.win:HookScript("OnHide", function() hides = hides + 1 end)
  local made, panel, onPanel, markers = colors, Core.frame, 0, false
  Run("enemies", function(id)
    markers = markers or id == "crosshair" -- sample nameplates, no panels
    if markers then return end
    if Core.rows[1] and Core.rows[1]:IsVisible() then onPanel = onPanel + 1 end
    assert(panel:IsVisible() and sim.ns.QuickCalls.win:IsVisible(), id .. " keeps the sample panels shown")
  end)
  t.equal(onPanel, 9, "every enemy-list step shows the real panel")
  t.equal(hides, 1, "Quick callouts closes once, when the markers chapter ends placement")
  Run("objectives")
  t.equal(starts, 1, "objectives start their preview once, without a battleground preview first")
  t.equal(repaints, 0, "entering and leaving placement repaints no themed region")
  t.equal(colors - made, 0, "guide steps create no gradient colour objects")
  assert(stops <= 4, "test mode stops only when placement starts or ends, not on each step")
  sim:assertHealthy()
end)
