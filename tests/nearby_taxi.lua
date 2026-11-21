-- Flight passengers can be visible and targetable without being attackable.
return function(test, setup, equal)
  local function start(client, build)
    local s = setup(client, build)
    local isPlayer, canAttack, faction = s.env.UnitIsPlayer, s.env.UnitCanAttack, s.env.UnitFactionGroup
    s.env.UnitIsPlayer = function(unit)
      return isPlayer(unit) and s.units[unit].isPlayer ~= false
    end
    s.env.UnitCanAttack = function(from, unit)
      local u = s.units[unit]
      if u and u.attackable ~= nil then return u.attackable end
      return canAttack(from, unit)
    end
    s.env.UnitOnTaxi = function(unit) return s.units[unit] and s.units[unit].taxi end
    s.env.UnitFactionGroup = function(unit)
      local u = s.units[unit]
      if u and u.faction ~= nil then return u.faction end
      return faction(unit)
    end
    return s
  end

  for _, case in ipairs({ { "cata", 40402 }, { "retail", 120100 }, { "retail", 16001 } }) do
    local client, build = unpack(case)
    test(build .. ": targeted enemy flight passengers are listed, counted and remembered", function()
      for team = 0, 1 do
        local s = start(client, build)
        s.faction = team
        local rider = { name = "Flyby", enemy = true, taxi = true, attackable = false, level = 60 }
        s.units.target = rider
        s:event("PLAYER_TARGET_CHANGED")
        local N, H = s.ns.Nearby, s.ns.NearbyHistory
        equal(N.shownCount, 1, "targeting alone records a flight passenger")
        equal(N.win.title.text, "NEARBY: 1", "the live count includes the passenger")
        equal(N.rows[1].who, "Flyby-Realm", "row belongs to the observed player")
        equal(s.ns.Stealth.Hostile("target"), false, "combat observers still require attackability")
        equal(H.Get("Flyby-Realm").times, 1, "encounter saved")
        s.units.mouseover, s.units.nameplate1 = rider, rider
        s:event("UPDATE_MOUSEOVER_UNIT")
        s:event("NAME_PLATE_UNIT_ADDED", "nameplate1")
        equal(N.count, 1, "multiple observation sources count the same rider once")
        s:advance(2)
        equal(H.Get("Flyby-Realm").times, 1, "polling does not add encounters")
        assert(s.now - N.seen["Flyby-Realm"].last < 2, "visible rider stays fresh")
        rider.taxi, rider.attackable = false, true
        s:advance(1)
        equal(N.count, 1, "landing preserves ordinary hostile detection")
        rider.visible = false
        s:advance(1)
        equal(N.count, 0, "retained target stops counting when no longer visible")
        assert(N.seen["Flyby-Realm"], "last sighting remains in the recent list")
        s:assertHealthy()
      end
    end)

    test(build .. ": flight passengers can first be seen through any nearby source", function()
      for _, source in ipairs({ { "mouseover", "UPDATE_MOUSEOVER_UNIT" },
        { "focus", "PLAYER_FOCUS_CHANGED" }, { "nameplate41", "NAME_PLATE_UNIT_ADDED" },
      }) do
        local s = start(client, build)
        s.units[source[1]] = { name = "Rider", enemy = true, taxi = true, attackable = false }
        s:event(source[2], source[1])
        equal(s.ns.Nearby.shownCount, 1, source[1] .. " adds the rider")
        equal(s.ns.Nearby.count, 1, source[1] .. " counts the rider")
        s:assertHealthy()
      end
    end)

    test(build .. ": the flight exception requires a visible player with a known opposing faction", function()
      for _, extra in ipairs({ { enemy = false }, { isPlayer = false }, { taxi = false },
        { visible = false }, { faction = "" }, { faction = "Neutral" },
        { faction = { secret = true } }, { taxi = { secret = true } },
        { visible = { secret = true } },
      }) do
        local s = start(client, build)
        local rider = { name = "Excluded", enemy = true, taxi = true, attackable = false }
        for key, value in pairs(extra) do rider[key] = value end
        s.units.target = rider
        s:event("PLAYER_TARGET_CHANGED")
        equal(s.ns.Nearby.count, 0, "not counted as a nearby enemy")
        equal(s.ns.Nearby.seen["Excluded-Realm"], nil, "no false sighting")
        equal(s.ns.NearbyHistory.Get("Excluded-Realm"), nil, "no false history entry")
        s:assertHealthy()
      end
    end)
  end
end
