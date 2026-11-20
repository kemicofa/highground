return function(addon)
  local t = dofile("../../tools/harness.lua")(addon .. " arena specs")
  local new = dofile("../../tools/wowsim/battleground/runtime.lua")
  local function equal(a, b, why) t.equal(a, b, why or "spec state") end
  local function setup(build, configure)
    return new(build == 40402 and "cata" or "retail", {}, function(s, env)
      s.addon, s.manifest = addon, addon .. (build == 40402 and "_Cata" or "") .. ".toc"
      env.GetBuildInfo = function() return "x", "1", "Nov 19 2026", build end
      if configure then configure(s, env) end
    end)
  end
  local function opponent(sim, classID, token, name)
    local unit = { name = name or "Duelist", classID = classID, guid = "Player-" .. (name or "Duelist") }
    sim.units[token or "target"] = unit
    return unit
  end
  local function begin(sim) sim:event("DUEL_REQUESTED", "Duelist-Realm"); return sim.ns.Arena end
  local function cast(sim, id, unit) sim:event("UNIT_SPELLCAST_SUCCEEDED", unit or "target", "Cast-1", id) end
  local function buff(id, source) return { spellId = id, sourceUnit = source or "target", isStealable = false } end

  -- One observed clue for each of Forever's 27 trees, in both real manifests.
  local classes = {
    { 1, "WARRIOR", { { 12292, 71, true }, { 12328, 72, true }, { 12975, 73, true } } },
    { 2, "PALADIN", { { 20216, 65, true }, { 20928, 66, true }, { 20375, 70, true } } },
    { 3, "HUNTER", { { 19574, 253 }, { 1299346, 254, true }, { 19263, 255, true } } },
    { 4, "ROGUE", { { 14177, 259, true }, { 13750, 260, true }, { 16511, 261 } } },
    { 5, "PRIEST", { { 10060, 256, true }, { 15237, 257 }, { 15473, 258, true } } },
    { 7, "SHAMAN", { { 408490, 262 }, { 425336, 263, true }, { 408510, 264, true } } },
    { 8, "MAGE", { { 12042, 62, true }, { 11129, 63, true }, { 13033, 64, true } } },
    { 9, "WARLOCK", { { 1316697, 265 }, { 19028, 266, true }, { 1293817, 267 } } },
    { 11, "DRUID", { { 24858, 102, true }, { 417141, 103, true }, { 408120, 105 } } },
  }
  for _, class in ipairs(classes) do
    t.test("Forever " .. class[2] .. " uses the spec icon for observed talent clues", function()
      local sim = setup(16001)
      local unit = opponent(sim, class[1])
      for _, clue in ipairs(class[3]) do
        unit.buffs = clue[3] and { buff(clue[1]) } or {}
        local A = begin(sim)
        if not clue[3] then cast(sim, clue[1]) end
        local seen, row = A.seen[1], A.rows[1]
        equal(seen.specID, clue[2], "correct Forever tree")
        equal(row.icon.texture, A.specCatalog[clue[2]].icon, "spec icon, not the observed spell's icon")
        equal(seen.specSource, "observed")
        assert(A.SpecLabel(seen):find("Likely ", 1, true), "tooltip distinguishes observation from confirmation")
        assert(row.spec == nil, "no redundant class or spec text row")
        equal(row.name.text, "Duelist")
        sim:event("DUEL_FINISHED")
      end
    end)
  end

  t.test("native arena preparation overrides clues and supplies its own icon", function()
    local sim = setup(16001, function(_, env)
      env.GetArenaOpponentSpec = function(i) return i == 1 and 64 or 0 end
      env.GetSpecializationInfoByID = function(id) return id, "Client Frost", nil, 99999, "DAMAGER", "MAGE" end
    end)
    local unit = opponent(sim, 8, "arena1")
    unit.buffs = { buff(12042, "arena1") }
    sim:joinArena()
    local A = sim.ns.Arena
    equal(A.seen[1].specSource, "arena")
    equal(A.rows[1].icon.texture, 99999)
    cast(sim, 11129, "arena1")
    equal(A.seen[1].specID, 64)
    equal(A.SpecLabel(A.seen[1]), "Client Frost", "confirmed spec has no estimate label")
  end)

  t.test("baseline abilities and foreign, stolen, secret or wrong-class buffs stay unknown", function()
    local sim = setup(16001)
    local unit = opponent(sim, 5)
    opponent(sim, 5, "focus", "Bystander")
    local A = begin(sim)
    local secret = { secret = true }
    for _, aura in ipairs({ buff(1243), buff(24858), buff(10060, "focus"), { spellId = 15473 },
      { spellId = 15473, sourceUnit = "target", isStealable = true },
      { spellId = secret, sourceUnit = "target" }, { spellId = 15473, sourceUnit = secret },
      { spellId = 15473, sourceUnit = "target", isStealable = secret }, secret }) do
      unit.buffs = { aura }; sim:event("UNIT_AURA", "target")
      equal(A.seen[1].specID, nil, "unsafe buff cannot identify the recipient")
      equal(A.SpecIcon(A.seen[1]), nil, "class icon remains the fallback")
    end
    cast(sim, 585) -- Smite is available to every priest.
    cast(sim, 12294) -- A warrior ability cannot identify a priest.
    cast(sim, secret)
    equal(A.seen[1].specID, nil)
    equal(A.seen[1].specEvidence, nil, "no unreadable data recorded")
  end)

  t.test("Classic mixed trees stay unknown on ties and deeper talent evidence wins", function()
    local sim = setup(16001)
    local unit = opponent(sim, 1)
    local A = begin(sim)
    unit.buffs = { buff(12292) }; sim:event("UNIT_AURA", "target")
    equal(A.seen[1].specID, 71, "Forever Sweeping Strikes means Arms, not Cata Fury")
    unit.buffs = {}; sim:event("UNIT_AURA", "target")
    equal(A.seen[1].specID, 71, "buff expiry retains observed evidence")
    cast(sim, 12328) -- Death Wish, another 21-point talent.
    equal(A.seen[1].specID, nil)
    assert(A.seen[1].specConflict and A.SpecLabel(A.seen[1]):find("mixed", 1, true))
    equal(A.SpecIcon(A.seen[1]), nil)
    cast(sim, 21553) -- Rank 4 Mortal Strike is a 31-point talent.
    equal(A.seen[1].specID, 71)
    cast(sim, 12975) -- An 11-point off-tree talent cannot replace it.
    equal(A.seen[1].specID, 71)
    sim:event("DUEL_FINISHED"); begin(sim)
    equal(A.seen[1].specID, nil, "next duel starts with fresh evidence")
  end)

  t.test("observations follow the exact opponent across target and nameplate changes", function()
    local sim = setup(16001)
    local unit = opponent(sim, 5, "nameplate1")
    local bystander = opponent(sim, 5, "target", "Bystander")
    local A = begin(sim)
    cast(sim, 15473, "target")
    equal(A.seen[1].specID, nil, "ignore the selected bystander's casts")
    sim.units.nameplate1, sim.units.nameplate2 = bystander, unit
    cast(sim, 15473, "nameplate1")
    equal(A.seen[1].specID, nil, "a recycled nameplate is not the opponent")
    sim:setCombat(true)
    cast(sim, 15473, "nameplate2")
    equal(A.seen[1].specID, 258)
    equal(A.rows[1].attrs.macrotext1, "/targetexact Duelist-Realm", "icon changes never rewrite combat bindings")
    sim.units.nameplate2 = nil; sim:advance(0.3)
    equal(A.rows[1].icon.texture, A.specCatalog[258].icon, "remember the icon while unseen")
    sim:event("DUEL_FINISHED")
    sim.units.nameplate2 = unit; cast(sim, 15473, "nameplate2")
    equal(next(A.seen), nil, "no tracking after the duel")
  end)

  t.test("aura changes update immediately and restricted combat data cannot erase a pre-duel clue", function()
    local sim = setup(16001)
    local unit = opponent(sim, 11)
    local A = begin(sim)
    unit.buffs = { buff(24858) }; sim:event("UNIT_AURA", "target")
    equal(A.seen[1].specID, 102, "no wait for the periodic aura scan")
    local secret = { secret = true }
    unit.buffs = { { spellId = secret, sourceUnit = secret, isStealable = secret } }
    sim:setCombat(true); sim:event("UNIT_AURA", "target"); cast(sim, secret)
    equal(A.seen[1].specID, 102, "keep the readable Moonkin observation")
  end)

  t.test("Forever data is never applied to Retail or Cata", function()
    for _, build in ipairs({ 120100, 40402 }) do
      local sim = setup(build)
      local unit = opponent(sim, 1)
      unit.buffs = { buff(12292) }
      local A = begin(sim)
      cast(sim, 12328)
      equal(A.seen[1].specID, nil)
      equal(next(A.specClues), nil, "different rulesets cannot reuse Forever spell meanings")
    end
  end)

  t.test("spec previews work without the bundled battleground spec catalog", function()
    local sim = setup(16001)
    local A = sim.ns.Arena
    sim.ns.ArenaPreview()
    equal(A.rows[1].icon.texture, A.specCatalog[261].icon, "Subtlety preview uses its spec icon")
    equal(A.rows[1].spec, nil)
  end)
  t.finish("Arena specs: " .. t.tests .. " scenarios")
end
