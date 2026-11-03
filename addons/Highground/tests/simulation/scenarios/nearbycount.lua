local test, new, equal = ...
local function plate(s, i, name, extra)
  local unit = extra or {}
  unit.name, unit.enemy, unit.classID = name, true, 4
  s.units["nameplate" .. i] = unit
  s:event("NAME_PLATE_UNIT_ADDED", "nameplate" .. i)
  return unit
end

for _, case in ipairs({ { "cata", 40402 }, { "retail", 120100 }, { "forever", 16001 } }) do
  local function start(saved)
    return new(case[1] == "cata" and "cata" or "retail", saved or {}, function(s)
      s.env.GetBuildInfo = function() return "test", "test", "test", case[2] end
      s.env.UnitIsPlayer = function(unit)
        return s.units[unit] and s.units[unit].isPlayer ~= false
      end
    end)
  end

  test(case[1] .. ": live count deduplicates sources and follows arrivals, departures and deaths", function()
    local s = start({ nearbyRows = 1 })
    s:advance(1)
    local N, w = s.ns.Nearby, s.ns.Nearby.win
    assert(w:IsVisible() and w.title.text == "NEARBY: 0", "counter starts at zero")
    local one = plate(s, 1, "One")
    s.units.target = { name = "One", realm = "", enemy = true }
    s.units.mouseover, s.units.focus = one, one
    s:event("PLAYER_TARGET_CHANGED")
    s:event("UPDATE_MOUSEOVER_UNIT")
    s:event("PLAYER_FOCUS_CHANGED")
    equal(w.title.text, "NEARBY: 1", "same-realm aliases count once")
    local two = plate(s, 41, "Two")
    equal(N.count, 2, "count includes plates above 40 and rows beyond the cap")
    equal(N.shownCount, 1, "row limit still applies")
    plate(s, 42, "One", { realm = "OtherRealm" })
    equal(N.count, 3, "same name on another realm is a different enemy")
    plate(s, 3, "Pet", { isPlayer = false })
    plate(s, 4, "Ghost", { ghost = true })
    plate(s, 5, "Unloaded", { visible = false })
    equal(N.count, 3, "pets, ghosts and invisible units excluded")

    two.dead = true
    s:event("UNIT_FLAGS", "nameplate41")
    equal(N.count, 2, "death updates without waiting for the sighting to expire")
    two.dead = false
    s:advance(1)
    equal(N.count, 3, "poll detects resurrection without another plate event")
    two.enemy = false
    s:event("UNIT_FACTION", "nameplate41")
    equal(N.count, 2, "friendly players excluded")
    s:event("NAME_PLATE_UNIT_REMOVED", "nameplate42")
    equal(N.count, 1, "removal works before the old token disappears")
    s.units.nameplate42 = nil
    s:event("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    equal(N.count, 1, "other sources still see the same enemy")
    s.units.nameplate1, s.units.target, s.units.focus, s.units.mouseover = nil, nil, nil, nil
    s:advance(1)
    equal(w.title.text, "NEARBY: 0", "poll catches lost target, focus and mouseover")
    assert(#N.List(s.now) > 0, "remembered sightings do not inflate the live count")
  end)

  test(case[1] .. ": counter updates in combat before any rows exist and beyond the row limit", function()
    local s = start({ nearbyRows = 1 })
    s:advance(1)
    local N, w = s.ns.Nearby, s.ns.Nearby.win
    local height = w:GetHeight()
    s:setCombat(true)
    plate(s, 1, "First")
    plate(s, 2, "Second")
    equal(w.title.text, "NEARBY: 2", "first sightings in combat update the visible header")
    equal(w.info.text, "+2 after combat", "all pending enemies counted")
    equal(N.shownCount, 0, "secure rows remain hidden")
    equal(w:GetHeight(), height, "secure window does not resize")
    s:setCombat(false)
    equal(N.shownCount, 1, "row limit applied after combat")
    local binding = N.rows[1].attrs.macrotext1
    s:setCombat(true)
    plate(s, 3, "Third")
    equal(N.count, 3, "new enemy counted during combat")
    equal(w.info.text, "+2 after combat", "counts pending enemies beyond the one-row cap")
    equal(N.rows[1].attrs.macrotext1, binding, "click binding stays fixed")
    s.units.nameplate1, s.units.nameplate2, s.units.nameplate3 = nil, nil, nil
    s:advance(1)
    equal(w.title.text, "NEARBY: 0", "departures update in combat")
    equal(N.rows[1].attrs.macrotext1, binding, "departures do not rebind rows")
    s:setCombat(false)
  end)

  test(case[1] .. ": continuously observed aliases stay fresh and preview and switches restore the counter", function()
    local s = start({ nearbyForget = 30, nearbyFade = 5 })
    s.units.target = { name = "Target", enemy = true }
    s.units.focus = { name = "Focus", enemy = true }
    s.units.mouseover = { name = "Mouseover", enemy = true }
    s:event("PLAYER_FOCUS_CHANGED")
    s:advance(35)
    local N, w = s.ns.Nearby, s.ns.Nearby.win
    equal(N.count, 3, "all observation aliases polled")
    equal(#N.List(s.now), 3, "visible aliases do not age out")
    for _, row in ipairs(N.List(s.now)) do assert(s.now - row.last < 2, "sighting kept fresh") end
    s.units.target.visible = false
    s:advance(1.1)
    equal(N.count, 2, "a retained but unloaded target is excluded")
    s:command("nearby test")
    equal(w.title.text, "NEARBY: 3", "preview uses sample count")
    equal(N.count, 2, "preview does not change real tracking")
    s:command("nearby test")
    equal(w.title.text, "NEARBY: 2", "preview restores real count immediately")
    s:command("nearby clear")
    equal(#N.List(s.now), 0, "clear empties recent sightings")
    equal(N.count, 2, "clearing remembered sightings preserves live observations")
    s.ns.Core.db.nearby = false
    s:advance(1)
    equal(N.count, 0, "disabled tracker resets")
    assert(not w:IsVisible(), "disabled panel hides")
    s.ns.Core.db.nearby = true
    s:advance(1)
    equal(N.count, 2, "re-enabled tracker recovers visible enemies")
    s:join()
    equal(N.count, 0, "instance transition resets the count")
    assert(not w:IsVisible(), "counter stays out of battlegrounds")
  end)
end

test("live count skips restricted identities and combat-log-only sightings", function()
  local s = new("retail", {})
  plate(s, 1, { secret = true })
  equal(s.ns.Nearby.count, 0, "unreadable identity cannot be deduplicated")
  local enemy = plate(s, 2, "Known")
  equal(s.ns.Nearby.count, 1, "readable enemy counted")
  enemy.visible = { secret = true }
  s:advance(1)
  equal(s.ns.Nearby.count, 0, "unreadable visibility skipped")
  local c = new("cata", {})
  c.combatEvent = { c.now, "SPELL_DAMAGE", false, "Player-1", "Sniper", 0x548, 0, "Player-2", "Me", 0x511, 0, 1 }
  c:event("COMBAT_LOG_EVENT_UNFILTERED")
  c:advance(1)
  equal(#c.ns.Nearby.List(c.now), 1, "combat log still adds recent sightings")
  equal(c.ns.Nearby.count, 0, "combat log alone does not confirm current visibility")
end)
