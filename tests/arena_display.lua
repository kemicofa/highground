-- Screenshot regressions and honest cooldown state, in both shipping owners.
return function(addon)
  local t = dofile("../../tools/harness.lua")(addon .. " arena display")
  local new = dofile("../../tools/wowsim/battleground/runtime.lua")
  local function equal(a, b, why) t.equal(a, b, why or "display state") end
  local function setup(build, configure)
    return new(build == 40402 and "cata" or "retail", {}, function(s, env)
      s.addon = addon
      s.manifest = addon .. (build == 40402 and "_Cata" or "") .. ".toc"
      env.GetBuildInfo = function() return "x", "1", "Nov 19 2026", build end
      dofile("../../tools/wowsim/geometry.lua")(s)
      local methods = getmetatable(env.UIParent).__index
      methods.SetStatusBarColor = function(f, ...) f.statusColor = { ... } end
      if configure then configure(s, env, methods) end
    end)
  end
  local function opponent(sim, token, name)
    local unit = { name = name or "Gorak Gronnslayer", classID = 1, health = 55, guid = "Player-" .. (name or "Gorak") }
    sim.units[token] = unit
    return unit
  end
  local function arena(sim)
    sim:joinArena()
    local unit = opponent(sim, "arena1")
    sim.units.target, sim.units.focus = unit, unit
    sim:event("ARENA_OPPONENT_UPDATE", "arena1", "seen")
    return sim.ns.Arena.rows[1], unit
  end
  local function above(sim, top, bottom, why)
    local a, b = sim.bounds(top), sim.bounds(bottom)
    assert(a[2] + a[4] <= b[2], why)
  end
  local function beside(sim, left, right, why)
    local a, b = sim.bounds(left), sim.bounds(right)
    assert(a[1] + a[3] <= b[1], why)
  end

  for _, build in ipairs({ 120100, 40402 }) do
    t.test(build .. ": solid health and readable icon remain separate at larger text sizes", function()
      local sim = setup(build)
      local row = arena(sim)
      for _, scale in ipairs({ 1, 1.5, 1 }) do
        sim.ns.Core.SetFontScale(scale)
        equal(row.bar.statusColor[4], 1, "health is opaque, not the theme's faint row tint")
        equal(row.bar.value, 0.55, "health fill still reflects the opponent")
        assert(row.icon:GetWidth() >= 40 and row.icon:GetHeight() >= 40, "class/CC icon readable at a glance")
        assert(row.bar:GetWidth() >= 150 and row.bar:GetHeight() >= 20, "dedicated health strip")
        above(sim, row.name, row.bar, "name stays above health")
        above(sim, row.bar, row.cast, "activity line stays below health")
        beside(sim, row.icon, row.bar, "portrait does not cover health")
        beside(sim, row.bar, row.trinket, "trinket does not cover health")
        beside(sim, row.name, row.marks, "target/focus markers never overlap the name")
        equal(row.name.wordWrap, false, "long names cannot wrap over the health bar")
        equal(row.marks.text, "TGT FOC")
        assert(row.spec == nil and not row.cast:IsShown() and not row.ccText:IsShown(), "idle rows have no redundant class/spec text")
      end
      sim:setCombat(true)
      for _, theme in ipairs({ "ember", "parchment", "azeroth", "highground" }) do
        assert(sim.ns.Theme.Use(theme))
        equal(row.bar.statusColor[4], 1, "theme switches keep health opaque")
      end
      equal(row.attrs.unit, "arena1", "display changes preserve protected clicks")
      equal(row.attrs.type1, "target")
    end)
  end

  for _, build in ipairs({ 16001, 120100, 40402 }) do
    t.test(build .. ": duels open no opponent panel", function()
      local sim = setup(build)
      opponent(sim, "target")
      sim:event("DUEL_REQUESTED", "Gorak Gronnslayer-Realm")
      sim:advance(0.5)
      local win = sim.ns.Arena.win
      assert(not (win and win:IsShown()), "the Arena panel stays closed")
      sim:assertHealthy()
    end)
  end

  t.test("restricted health goes straight to native widgets; casts and CC share space", function()
    local secret, duration, scaleCurve = { secret = true }, {}, {}
    local sim = setup(120100, function(_, env, methods)
      env.CurveConstants = { ScaleTo100 = scaleCurve }
      env.UnitHealthPercent = function(_, _, curve)
        assert(curve == nil or curve == scaleCurve)
        return secret
      end
      methods.SetFormattedText = function(f, format, value) f.formatted = { format, value } end
    end)
    local row, unit = arena(sim)
    unit.health, unit.maxHealth = secret, secret
    sim:setCombat(true); sim:advance(0.3)
    equal(row.bar.value, secret, "secret health sent to the fill without arithmetic")
    equal(row.right.formatted[2], secret, "native text widget receives restricted percentage directly")
    equal(row.bar.statusColor[4], 1)
    sim.env.UnitCastingInfo = function() return secret, nil, nil, secret, secret end
    sim.env.UnitCastingDuration = function() return duration end
    sim.env.C_UnitAuras.GetAuraDataByIndex = function()
      return { name = secret, icon = secret, auraInstanceID = secret }
    end
    sim.env.C_UnitAuras.GetAuraDuration = function() return duration end
    sim:event("UNIT_AURA", "target")
    sim:advance(0.3)
    assert(row.cast:IsShown() and row.cc:IsShown(), "CC portrait stays visible during a cast")
    assert(not row.ccText:IsShown(), "one detail line at a time")
    equal(row.cast.timerDuration, duration)
    equal(row.ccCD.cooldown.object, duration)
    equal(row.cc:GetWidth(), row.icon:GetWidth(), "CC uses the full portrait")
    above(sim, row.bar, row.cast, "cast stays below health")
    sim.env.UnitCastingInfo = function() end
    sim:advance(0.3)
    assert(row.ccText:IsShown(), "CC label takes the freed detail line")
    sim.env.C_UnitAuras.GetAuraDataByIndex = function() end
    sim:event("UNIT_AURA", "target")
    sim:advance(0.3)
    assert(not row.cc:IsShown() and not row.ccText:IsShown(), "activity clears after control ends")
  end)

  t.test("missing trinket data is unknown even when the API returns an empty duration", function()
    local sim = setup(120100, function(_, env)
      env.C_PvP.GetArenaCrowdControlDuration = function() return {} end
      env.C_PvP.RequestCrowdControlSpell = function() error("unsupported unit") end
    end)
    local row = arena(sim)
    assert(row.trinket:IsShown())
    equal(row.trinketState.text, "?", "missing data does not mean ready")
    assert(not row.trinketKnown and not row.trinketCD:IsShown())
    sim.env.C_PvP.GetArenaCrowdControlInfo = function() return 0, 0, 0 end
    sim:event("ARENA_COOLDOWNS_UPDATE")
    equal(row.trinketState.text, "?", "no reported spell is still unknown")
    assert(not row.trinketKnown and not row.trinketCD:IsShown())
    sim:advance(3)
    equal(row.trinketState.text, "?")
  end)

  t.test("native trinket data follows the arena opponent and clears between rounds", function()
    local requests, ready = {}, false
    local sim = setup(120100, function(_, env)
      env.C_PvP.RequestCrowdControlSpell = function(unit) requests[#requests + 1] = unit end
      env.C_PvP.GetArenaCrowdControlInfo = function() return 42292, ready and 0 or 95000, ready and 0 or 120000 end
    end)
    sim:joinArena()
    local row = sim.ns.Arena.rows[1]
    equal(#requests, 0, "no request before the opponent is seen")
    opponent(sim, "arena1")
    sim:event("ARENA_OPPONENT_UPDATE", "arena1", "seen")
    equal(requests[1], "arena1", "request as soon as the opponent becomes visible")
    assert(row.trinketKnown and row.trinketCD:IsShown())
    equal(row.trinketState.text, "")
    equal(row.trinketCD.cooldown.start, 95)
    equal(row.trinketCD.cooldown.duration, 120)
    equal(row.trinket.texture, "Interface\\Icons\\Spell42292")
    sim:event("ARENA_CROWD_CONTROL_SPELL_UPDATE", "arena2", 999)
    equal(row.trinket.texture, "Interface\\Icons\\Spell42292", "ignore another opponent's spell")
    ready = true
    sim:event("ARENA_COOLDOWNS_UPDATE")
    assert(row.trinketKnown and not row.trinketCD:IsShown(), "client-reported readiness is distinct from unknown")
    sim:advance(2)
    assert(not row.trinketCD:IsShown(), "row ticks cannot restart a completed sweep")
    sim.env.C_PvP.GetArenaCrowdControlInfo = function() end
    sim:event("ARENA_PREP_OPPONENT_SPECIALIZATIONS")
    equal(row.trinketState.text, "?", "the next round does not inherit readiness")
    equal(row.trinket.texture, sim.ns.Arena.TRINKET_ICON)
  end)

  t.test("restricted trinket timing stays in the native cooldown widget", function()
    local secret, duration = { secret = true }, {}
    local sim = setup(120100, function(_, env)
      env.C_PvP.GetArenaCrowdControlInfo = function() return secret, secret, secret end
      env.C_PvP.GetArenaCrowdControlDuration = function() return duration end
    end)
    local row = arena(sim)
    assert(row.trinketKnown)
    equal(row.trinketCD.cooldown.object, duration)
    sim:event("ARENA_CROWD_CONTROL_SPELL_UPDATE", "arena1", 42292)
    equal(row.trinket.texture, "Interface\\Icons\\Spell42292", "unreadable spell responses do not erase a known icon")
    equal(row.trinketCD.cooldown.object, duration)
  end)

  t.test("leaving an arena clears timing and cannot query stale arena tokens", function()
    local queries = 0
    local sim = setup(40402, function(_, env)
      env.C_PvP.GetArenaCrowdControlInfo = function()
        queries = queries + 1
        return 42292, 95000, 120000
      end
    end)
    sim:joinArena()
    opponent(sim, "arena1")
    sim:event("ARENA_OPPONENT_UPDATE", "arena1", "seen")
    local row = sim.ns.Arena.rows[1]
    equal(row.trinket.texture, "Interface\\Icons\\Spell42292")
    assert(row.trinketCD:IsShown())
    local before = queries
    sim:leave() -- the fixture deliberately retains arena1
    equal(queries, before, "no trinket API query outside a match")
    equal(row.trinket.texture, sim.ns.Arena.TRINKET_ICON)
    assert(not row.trinketKnown and not row.trinketCD:IsShown())
  end)
  t.finish("Arena display: " .. t.tests .. " scenarios")
end
