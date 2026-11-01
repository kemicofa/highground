-- Run the same observed-event scenarios against each addon's real TOCs.
-- Called from addons/<Addon>/tests/stealth_test.lua.
return function(addon, contexts)
  local t = dofile("../../tools/harness.lua")(addon .. " stealth")
  local new = dofile("../../tools/wowsim/battleground/runtime.lua")
  local test, equal = t.test, t.equal
  local enter = "Interface\\AddOns\\" .. addon .. "\\libs\\sounds\\stealth-enter.ogg"
  local exit = "Interface\\AddOns\\" .. addon .. "\\libs\\sounds\\stealth-exit.ogg"

  local function setup(client, build, context, saved)
    local sim = new(client, saved or { nearbySound = true }, function(s, env)
      s.addon = addon
      s.manifest = addon .. (client == "cata" and "_Cata" or "") .. ".toc"
      env.GetBuildInfo = function() return "x", "1", "Nov 1 2026", build end
      local play = env.PlaySoundFile
      env.PlaySoundFile = function(file, channel)
        equal(channel, "Master", "custom cue uses the alert channel")
        return play(file)
      end
      env.UnitIsVisible = function(unit) return s.units[unit] ~= nil and s.units[unit].visible ~= false end
    end)
    if context == "pvp" then sim:join()
    elseif context == "arena" then sim:joinArena() end
    return sim
  end

  local function log(sim, kind, id, hostile)
    local flags = hostile == false and 0x511 or 0x548
    sim.combatEvent = { sim.now, kind, false, "Player-sneak", "Sneak-Realm", flags, 0,
      "Player-sneak", "Sneak-Realm", flags, 0, id }
    sim:event("COMBAT_LOG_EVENT_UNFILTERED")
  end

  local function cast(sim, unit, id)
    sim:event("UNIT_SPELLCAST_SUCCEEDED", unit, "Cast-1", id or 5215)
  end

  for _, context in ipairs(contexts) do
    test(context .. ": Cata enter/exit sounds, Vanish deduplication and final aura removal", function()
      local sim = setup("cata", 40402, context)
      log(sim, "SPELL_CAST_SUCCESS", 1856)
      log(sim, "SPELL_AURA_APPLIED", 11327)
      log(sim, "SPELL_AURA_APPLIED", 1784)
      sim:advance(0.2)
      equal(#sim.sounds, 1, "one sound for cast and hiding auras")
      equal(sim.sounds[1], enter, "altered stealth cue wins over any fresh-sighting sound")
      sim:advance(2)
      log(sim, "SPELL_AURA_REMOVED", 11327)
      sim:advance(0.2)
      equal(#sim.sounds, 1, "Vanish's intermediate aura does not end stealth")
      log(sim, "SPELL_AURA_REMOVED", 1784)
      sim:advance(0.2)
      equal(sim.sounds[2], exit, "stealth removal has its own cue")
      sim:advance(2)
      log(sim, "SPELL_AURA_REMOVED", 1784)
      sim:advance(0.2)
      equal(#sim.sounds, 2, "duplicate removal stays quiet")
    end)

    test(context .. ": both stealth cues respect sound settings and per-enemy muting", function()
      local cases = {
        { sound = false }, { alerts = { mode = "quiet" } },
        { alerts = { channels = { stealth = { sound = false } } }, nearbySound = false },
      }
      if context == "world" then
        cases[#cases + 1] = { nearbySound = false }
        cases[#cases + 1] = { nearbyStealth = false, nearbySound = false }
        cases[#cases + 1] = { nearbySound = true, enemyHistory = {
          ["Sneak-Realm"] = { muted = true, times = 1, killedMe = 0, killedThem = 0 },
        } }
      end
      for _, saved in ipairs(cases) do
        local sim = setup("cata", 40402, context, saved)
        log(sim, "SPELL_AURA_APPLIED", 1784)
        sim:advance(2)
        log(sim, "SPELL_AURA_REMOVED", 1784)
        sim:advance(0.2)
        equal(#sim.sounds, 0, "muted on application and removal")
      end
    end)

    test(context .. ": friendly stealth and disabled features stay quiet", function()
      local sim = setup("cata", 40402, context)
      log(sim, "SPELL_AURA_APPLIED", 1784, false)
      sim:advance(2)
      log(sim, "SPELL_AURA_REMOVED", 1784, false)
      sim:advance(0.2)
      equal(#sim.sounds, 0, "friendly stealth is ignored")
      if context == "world" then sim.ns.Core.db.nearby = false
      elseif context == "arena" then sim.ns.Core.db.arena = false
      else sim.ns.Core.db.off = true; sim.ns.Core.SetActive(false) end
      log(sim, "SPELL_AURA_APPLIED", 1784)
      sim:advance(2)
      log(sim, "SPELL_AURA_REMOVED", 1784)
      sim:advance(0.2)
      equal(#sim.sounds, 0, "disabled feature is ignored")
    end)

    for _, build in ipairs(context == "arena" and { 120100 } or { 120100, 16001 }) do
      test(context .. " " .. build .. ": visible casts and reappearance use distinct cues", function()
        local sim = setup("retail", build, context)
        local unit = context == "arena" and "arena1" or "nameplate1"
        local enemy = { name = "Sneak", classID = 11, enemy = true }
        sim.units[unit] = enemy
        local aura = { name = "Prowl" }
        sim.env.C_UnitAuras.GetAuraDataBySpellName = function() return aura end
        cast(sim, unit)
        cast(sim, unit, { secret = true })
        sim:advance(3)
        equal(#sim.sounds, 1, "readable hiding aura prevents a false fade")
        equal(sim.sounds[1], enter, "cast uses enter cue")
        aura = { secret = true }
        sim:advance(2)
        equal(#sim.sounds, 1, "unreadable aura does not reveal a fade")
        sim.units[unit] = nil
        sim:advance(3)
        equal(#sim.sounds, 1, "nothing while the enemy is unseen")
        aura, sim.units[unit] = nil, enemy
        sim:event(context == "arena" and "ARENA_OPPONENT_UPDATE" or "NAME_PLATE_UNIT_ADDED", unit, "seen")
        sim:advance(0.2)
        equal(sim.sounds[2], exit, "reappearance uses exit cue")
        sim:advance(3)
        equal(#sim.sounds, 2, "no repeated fade")
      end)
    end

    test(context .. ": missing custom files fall back to the in-game stealth sound", function()
      local sim = setup("cata", 40402, context)
      sim.env.PlaySoundFile = function() return false end
      log(sim, "SPELL_AURA_APPLIED", 1784)
      sim:advance(2)
      log(sim, "SPELL_AURA_REMOVED", 1784)
      sim:advance(0.2)
      equal(#sim.sounds, 2, "both transitions have a fallback")
      equal(sim.sounds[1], 3325, "enter falls back to Stealth")
      equal(sim.sounds[2], 3325, "exit falls back to Stealth")
    end)

    if context ~= "world" then
      test(context .. ": leaving a match discards hidden opponents", function()
        local sim = setup("retail", 120100, context)
        local unit = context == "arena" and "arena1" or "nameplate1"
        sim.units[unit] = { name = "Sneak", classID = 4, enemy = true }
        cast(sim, unit, 1784)
        sim:advance(0.2)
        sim:leave()
        if context == "arena" then sim:joinArena() else sim:join() end
        sim:advance(3)
        equal(#sim.sounds, 1, "no stale fade in the next match")
      end)
    end
  end
  t.finish("Stealth: " .. t.tests .. " scenarios, " .. t.failures .. " failures")
end
