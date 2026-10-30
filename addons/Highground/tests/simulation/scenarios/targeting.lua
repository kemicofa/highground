local test, newClient, equal = ...
-- Exercise the existing full-feature setup; fresh installs are covered by onboarding.
local function new(client, saved, configure) return newClient(client, saved or {}, configure) end

test("live target changes in combat while secure bindings and scale defer", function()
  local sim = new("cata")
  local alpha = sim:enemy("Alpha")
  local beta = sim:enemy("Beta", { yards = 70 })
  sim:join()
  equal(sim.ns.GetKillNow().key, "Alpha-Realm", "only reachable target selected")
  sim:setCombat(true)
  alpha.yards, beta.yards = 70, 20
  sim:advance(0.5)
  equal(sim.ns.GetKillNow().key, "Beta-Realm", "live targeting reacts to range")
  equal(sim.env.HighgroundTargetButton.attrs.macrotext, "/targetexact Alpha", "combat macro stays bound")
  equal(sim.ns.Core.hero.name.text, "Alpha", "hero names its actual combat click target")
  assert(sim.ns.Core.hero.clickNote.text:find("BETA", 1, true), "live recommendation remains visible")
  sim:command("scale 1.1")
  equal(sim.env.HighgroundDB.scale, 1.1, "scale preference saved")
  equal(sim.env.HighgroundFrame.scale, 0.8, "scale stays unchanged during combat")
  sim:setCombat(false)
  equal(sim.env.HighgroundTargetButton.attrs.macrotext, "/targetexact Beta", "binding catches up after combat")
  equal(sim.env.HighgroundFrame.scale, 1.1, "deferred scale applies")
  equal(sim.env.HighgroundTimersFrame.scale, 1.1, "timer panels share scale")
end)

test("Cata casts and aura fades affect scores; tracking controls suppress signals", function()
  local sim = new("cata")
  local enemy = sim:enemy("Mage", { buffs = { { spellId = 45438, icon = 1 } } })
  sim:join()
  local entry = sim:entry("Mage")
  equal(entry.def, true, "active Ice Block observed")
  local protectedScore = entry.live
  sim:combatLog("SPELL_CAST_SUCCESS", "Mage", "Mage", 45438)
  local expires = assert(entry.cds[45438])
  sim:advance(1)
  sim:combatLog("SPELL_AURA_APPLIED", "Mage", "Mage", 45438)
  equal(entry.cds[45438], expires, "duplicate aura cannot extend cooldown")
  enemy.buffs = {}
  sim:combatLog("SPELL_AURA_REMOVED", "Mage", "Mage", 45438)
  sim:advance(0.5)
  assert(entry.burnedAt and entry.live > protectedScore, "fade opens a higher-priority kill window")
  local tracking
  for _, page in ipairs(sim.ns.Options.pages) do
    if page.name == "Cooldown tracking" then tracking = page; page.frame:Show() end
  end
  local found = false
  for _, checkbox in ipairs(assert(tracking).trackingBoxes) do
    if checkbox.spellID == 45438 then
      assert(checkbox:GetChecked(), "starts tracked")
      checkbox.scripts.OnClick(checkbox); found = true
    end
  end
  assert(found)
  equal(entry.burnedAt, nil, "actual option handler removes GO state")
  enemy.buffs = { { spellId = 45438, icon = 1 } }
  sim:advance(0.5)
  equal(entry.def, false, "disabled spell no longer affects scoring")
  equal(entry.cds[45438], expires, "observed cooldown remains available if re-enabled")
end)

test("Retail restricted health displays without influencing target scores", function()
  local sim = new("retail")
  local secret = setmetatable({ secret = true }, {
    __lt = function() error("secret comparison") end,
    __le = function() error("secret comparison") end,
    __div = function() error("secret arithmetic") end,
  })
  local enemy = sim:enemy("Hidden", { health = secret, maxHealth = secret, maxMana = secret, mana = secret })
  sim.scores[2].talentSpec = secret
  sim:join()
  local entry = sim:entry("Hidden")
  equal(entry.hpPct, nil, "restricted health does not become a score signal")
  equal(entry.specID, nil, "restricted specialization stays unknown")
  equal(sim.env.HighgroundRow1.hp.value, secret, "raw health reaches display boundary")
  local score = entry.live
  enemy.categories = { ["HARMFUL|CROWD_CONTROL"] = { { spellId = 853 } } }
  sim:advance(0.5)
  equal(entry.live, score, "generic crowd control does not invent a breakable-CC penalty")
  equal(entry.crowdControlled, true, "category remains visible")
end)

test("enemy targeting observations reach private teammate markers", function()
  local sim = new("cata")
  local _, token = sim:enemy("Attacker")
  sim.units[token .. "target"] = sim.units.player
  sim:join()
  equal(sim.ns.Test.enemyFocus[1].key, "Me-Realm", "player appears in focus ranking")
  equal(sim.env.HighgroundPressure1.count.text, "1", "badge displays enemy count")
  assert(sim.env.HighgroundPressure1:IsShown())
  sim.units[token .. "target"] = nil
  sim:event("UNIT_TARGET", token)
  equal(#sim.ns.Test.enemyFocus, 0, "retarget clears observation")
  equal(sim.env.HighgroundPressure1:IsShown(), false, "badge disappears")
end)

test("target recommendations off: no priority outputs, scope follows your own target", function()
  local sim = new("cata")
  local alpha = sim:enemy("Alpha")
  local beta = sim:enemy("Beta")
  sim:join()
  equal(sim.env.HighgroundTargetButton.attrs.macrotext, "/targetexact Alpha", "recommendation bound while on")
  sim:command("priority off")
  sim:advance(0.5)
  assert(not sim.env.HighgroundFrame:IsVisible(), "priority panel hidden")
  equal(sim.env.HighgroundTargetButton.attrs.macrotext, "", "kill-order keybind cleared")
  equal(sim.ns.GetKillNow(), nil, "no kill target for the map")
  assert(not sim.env.HighgroundSniper:IsShown(), "no target: no scope")
  sim.units.target = beta
  sim:advance(0.5)
  assert(sim.env.HighgroundSniper:IsShown(), "scope on your own target")
  equal(sim.env.HighgroundSniper.points[1][2], sim.plates.nameplate2, "scope anchored to your target's nameplate")
  sim.units.target = alpha
  sim:advance(0.5)
  equal(sim.env.HighgroundSniper.points[#sim.env.HighgroundSniper.points][2], sim.plates.nameplate1, "scope follows target changes")
  sim.units.target = sim.units.player
  sim:advance(0.5)
  assert(not sim.env.HighgroundSniper:IsShown(), "friendly target: no scope")
  sim:command("priority on")
  sim:advance(0.5)
  assert(sim.env.HighgroundFrame:IsVisible(), "panel back")
  equal(sim.env.HighgroundTargetButton.attrs.macrotext, "/targetexact Alpha", "keybind restored")
end)

test("known enemy healers get a large marker above their nameplate", function()
  for _, client in ipairs({ "cata" }) do -- retail specs are secret mid-match
    local sim = new(client)
    local _, healerPlate = sim:enemy("Mender", { classID = 11, specIndex = 3 })
    local _, dpsPlate = sim:enemy("Striker", { classID = 1, specIndex = 1 })
    sim:join()
    sim:advance(1)
    local marks = sim.ns.Core.healerMarks
    local shown = {}
    for _, m in ipairs(marks) do if m:IsShown() then shown[#shown + 1] = m end end
    equal(#shown, 1, client .. ": one marker, on the healer only")
    local p = shown[1].points[#shown[1].points]
    equal(p[1], "BOTTOM", client .. ": marker sits above")
    equal(p[2], sim.plates[healerPlate], client .. ": anchored to the healer's plate")
    equal(p[3], "TOP", client .. ": above the plate")
    assert(p[2] ~= sim.plates[dpsPlate], "never on a damage dealer")
    sim.env.HighgroundDB.healerMarks = false
    sim:advance(1)
    equal(shown[1]:IsShown(), false, client .. ": setting off hides the markers")
  end
end)
