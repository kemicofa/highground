-- Enemy health on board rows (ui/Health.lua): Retail's percentage API and
-- execute colour curve, fallbacks when a read or a bar update fails, and
-- Cata's health text. Run from addons/Highground: luajit tests/health_test.lua
local t = dofile("../../tools/harness.lua")("health")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local equal = t.equal

-- Retail's UnitHealthPercent(unit, predicted[, curve]) and step colour
-- curves: with a curve the API returns the colour at the unit's health.
local function curves(sim, env)
  env.Enum = env.Enum or {}
  env.Enum.LuaCurveType = { Step = 1 }
  env.CreateColor = function(r, g, b, a)
    return { r, g, b, a, GetRGBA = function(c) return c[1], c[2], c[3], c[4] end }
  end
  env.C_CurveUtil = { CreateColorCurve = function()
    local curve = { points = {} }
    function curve:SetType(kind) self.kind = kind end
    function curve:AddPoint(x, color) self.points[#self.points + 1] = { x = x, color = color } end
    function curve:Evaluate(x)
      local color
      for _, p in ipairs(self.points) do if x >= p.x then color = p.color end end
      return color
    end
    return curve
  end }
  env.UnitHealthPercent = function(unit, _, curve)
    local u = sim.units[unit]
    if not u then return nil end
    local pct = (u.health or 100) / (u.maxHealth or 100)
    if curve then return curve:Evaluate(pct) end
    return pct
  end
end

local function rowFor(sim, name)
  for _, r in ipairs(sim.ns.Core.rows) do
    if r.entry and r.entry.key == name .. "-Realm" then return r end
  end
end

t.test("Retail rows draw health percentages and execute marks from the colour curve", function()
  local sim = new("retail", {}, curves)
  local Core = sim.ns.Core
  equal(Core.execCurve.kind, sim.env.Enum.LuaCurveType.Step, "step curve")
  equal(Core.execCurve.points[2].x, Core.db.executePct, "curve steps at the execute threshold")
  local low = sim:enemy("Low", { health = 20, maxHealth = 100 })
  sim:enemy("High", { health = 90, maxHealth = 100 })
  sim:join()
  local lowRow, highRow = rowFor(sim, "Low"), rowFor(sim, "High")
  equal(lowRow.hpMode, "pct", "percentage mode")
  equal(lowRow.hp.minimum, 0, "bar starts at zero")
  equal(lowRow.hp.maximum, 1, "and ends at one")
  equal(lowRow.hp.value, 0.2, "low enemy at 20%")
  equal(highRow.hp.value, 0.9, "high enemy at 90%")
  equal(lowRow.exec.alpha, 1, "execute mark under the threshold")
  equal(highRow.exec.alpha, 0, "no execute mark above it")
  assert(lowRow.hp.wbHealthLine.wbHealthKnown, "reading shown as known")
  assert(Core.db.liveStats.health.pct > 0, "percentage reads counted")
  equal(Core.db.liveStats.health.pctFail, nil, "no failed reads")
  sim:command("exec 50")
  equal(Core.execCurve.points[2].x, 0.5, "threshold change rebuilds the curve")
  low.health = 45
  sim:advance(0.5)
  equal(lowRow.hp.value, 0.45, "bar follows health")
  equal(lowRow.exec.alpha, 1, "45% is under the new threshold")
end)

t.test("Retail falls back to absolute health and keeps only the first error", function()
  local sim = new("retail", {}, curves)
  local Core, env = sim.ns.Core, sim.env
  sim:enemy("Shaky", { health = 30, maxHealth = 60 })
  sim:join()
  local r = rowFor(sim, "Shaky")
  local unit, color = r.entry.plateUnit, { r = 1, g = 0, b = 0 }
  local percent = env.UnitHealthPercent
  env.UnitHealthPercent = function() error("first failure") end
  Core.UpdateHealth(r, unit, color)
  equal(r.hpMode, "abs", "absolute fallback")
  equal(r.hp.maximum, 60, "range from maximum health")
  equal(r.hp.value, 30, "value from current health")
  assert(Core.db.healthErr:find("first failure", 1, true), "error kept for /hg err")
  env.UnitHealthPercent = function() error("second failure") end
  Core.UpdateHealth(r, unit, color)
  assert(Core.db.healthErr:find("first failure", 1, true), "later errors do not replace the first")
  equal(Core.db.liveStats.health.pctFail, 2, "failed reads counted")
  env.UnitHealthPercent = function() return nil end
  env.UnitHealth, env.UnitHealthMax = function() end, function() end
  Core.UpdateHealth(r, unit, color)
  equal(Core.db.liveStats.health.noData, 1, "nothing readable counted")
  equal(r.hp.wbHealthLine.wbHealthKnown, false, "unknown health shown as unknown")
  Core.db.healthErr = nil -- the simulator fails on recorded health errors
  env.UnitHealthPercent = percent
end)

t.test("a bar that rejects the percentage still draws absolute health", function()
  local sim = new("retail", {}, curves)
  local Core = sim.ns.Core
  sim:enemy("Picky", { health = 10, maxHealth = 40 })
  sim:join()
  local r = rowFor(sim, "Picky")
  local set = r.hp.SetValue
  r.hp.SetValue = function(bar, value)
    if bar.maximum == 1 then error("rejected") end
    return set(bar, value)
  end
  Core.UpdateHealth(r, r.entry.plateUnit, { r = 1, g = 1, b = 1 })
  equal(Core.db.liveStats.health.pctSetFail, 1, "rejected update counted")
  equal(r.hpMode, "abs", "absolute fallback")
  equal(r.hp.value, 10, "health drawn")
  assert(Core.db.healthErr:find("rejected", 1, true), "first error kept")
  Core.db.healthErr = nil
  r.hp.SetValue = set
end)

t.test("Cata health text rounds, clamps and colours execute, live and stale readings", function()
  local sim = new("cata", {})
  local Core = sim.ns.Core
  sim:enemy("Text", { health = 50, maxHealth = 100 })
  sim:join()
  local r = rowFor(sim, "Text")
  local e = r.entry
  local function show(pct, unit)
    e.hpPct, e.unit, e.testHp = pct, unit, nil
    Core.UpdateHealthText(r, e)
    return r.hpText:IsShown() and r.hpText.text, r.hpText.wbToken
  end
  local text, token = show(0.294, "nameplate1")
  equal(text, "29%", "rounded")
  equal(token, "kill", "under the execute threshold")
  text, token = show(0.505, "nameplate1")
  equal(text, "51%", "rounded half up")
  equal(token, "text", "bright while in view")
  text, token = show(0.8, nil)
  equal(token, "textMuted", "grey from the last reading")
  equal(show(1.4, "nameplate1"), "100%", "clamped above")
  equal(show(-0.2, "nameplate1"), "0%", "clamped below")
  e.dead = true
  equal(show(0.5, "nameplate1"), false, "hidden when dead")
  e.dead = nil
  local retail = new("retail", {})
  retail:enemy("Text")
  retail:join()
  local rr = rowFor(retail, "Text")
  local secret = { secret = true }
  rr.entry.hpPct, rr.entry.hpSeen, rr.entry.unit = nil, secret, "nameplate1"
  retail.ns.Core.UpdateHealthText(rr, rr.entry)
  equal(rr.hpText.text, "<secret>%", "the widget formats secret health; Highground never reads it")
  equal(rr.hpText.wbToken, "text", "bright while in view")
  rr.entry.hpSeen = nil
  retail.ns.Core.UpdateHealthText(rr, rr.entry)
  assert(not rr.hpText:IsShown(), "no text without a reading")
end)

t.finish("Health: " .. t.tests .. " tests")
