local support = ...
local equal = support.equal
local scenario = support.scenario
local scenarios = support.scenarios

do
  local s = scenario()
  s:addAlly("Ally-Realm", "party1", true)
  local unit = s:addEnemy("Enemy-Realm", "Ally-Realm")
  s:update()
  local marker = s.env.WarboardPressure1
  local oldPlate, oldToken = marker.anchor, marker.plateUnit
  s:event("NAME_PLATE_UNIT_REMOVED", oldToken)
  equal(marker.shown, false, "nameplate removal immediately hides its marker")
  equal(marker.anchor, nil, "removed plate anchor is discarded immediately")
  equal(#marker.points, 0, "removed plate leaves no stale UI anchor")
  s.plates.party1, s.plates[oldToken], s.units[oldToken] = nil, nil, nil
  s:update()
  equal(#s.ns.enemyFocus, 1, "missing nameplate does not discard valid targeting observations")
  equal(marker.shown, false, "missing nameplate keeps the marker hidden")
  local newPlate, newToken = s:setPlate("Ally-Realm")
  s:event("NAME_PLATE_UNIT_ADDED", newToken)
  equal(marker.anchor, newPlate, "new plate receives the same teammate's marker")
  equal(marker.shown, true, "new visible plate restores marker")
  newPlate.forbidden = true
  s:update()
  equal(marker.shown, false, "forbidden plate cannot preserve an old marker")
  newPlate.forbidden, newPlate.rejectAnchor = false, true
  s:update()
  equal(marker.shown, false, "failed anchoring clears the marker safely")
  newPlate.rejectAnchor, newPlate.shown = false, false
  s:update()
  equal(marker.shown, false, "hidden plate cannot receive a marker")
  newPlate.shown = true
  s.units[newToken] = { key = "Unrelated-Realm", isPlayer = true }
  s:update()
  equal(marker.shown, false, "recycled plate with a different identity is not reused")
  s.units[newToken] = { key = "Ally-Realm", isPlayer = false }
  s:update()
  equal(marker.shown, false, "same-name pet plate is rejected in direct and fallback lookup")
  s.units[newToken] = s.allies["Ally-Realm"]
  s.plates.party1 = nil
  s:update()
  equal(marker.anchor, newPlate, "nameplate-token fallback works when raid-token lookup is absent")
  s.plateError = newToken
  s:update()
  equal(marker.shown, false, "unreadable nameplate lookup clears the prior marker")
  equal(oldPlate.shown, true, "addon never hides or modifies the old Blizzard plate")
end

do
  local s = scenario()
  s:addAlly("First-Realm", "party1")
  s:addAlly("Second-Realm", "party2")
  s:addAlly("Third-Realm", "party3", true)
  for i, key in ipairs({ "First-Realm", "Second-Realm", "Third-Realm" }) do
    for j = 1, 4 - i do s:addEnemy(key .. j, key) end
  end
  s:update()
  equal(s.env.WarboardPressure1, nil, "invisible rank one does not allocate a marker")
  equal(s.env.WarboardPressure2, nil, "invisible rank two does not allocate a marker")
  equal(s.env.WarboardPressure3.shown, true, "visible rank three can exist with marker array holes")
  local marker = s.env.WarboardPressure3
  s:event("NAME_PLATE_UNIT_REMOVED", marker.plateUnit)
  equal(marker.shown, false, "removal reaches a marker after array holes")
  s:update()
  s:event("PLAYER_ENTERING_WORLD")
  equal(marker.shown, false, "world entry clears a marker after array holes")
  equal(#s.ns.enemyFocus, 0, "world entry clears all ranked observations")
  s:update()
  s.active = false; s:update()
  equal(marker.shown, false, "leaving the battleground hides sparse markers")
  equal(#s.ns.enemyFocus, 0, "leaving the battleground clears observations")
end

do
  local s = scenario()
  s:addEnemy("Enemy-Realm", "Me-Realm")
  s:update()
  equal(s.env.WarboardPressure1.anchor, s.env.PlayerFrame, "own player uses player-frame fallback")
  local plate = s:setPlate("Me-Realm")
  s:update()
  equal(s.env.WarboardPressure1.anchor, plate, "own player prefers a visible personal nameplate")
  s:command("off")
  equal(s.db.pressure, false, "off command persists preference")
  equal(s:visible(), 0, "off command hides all badges")
  equal(#s.ns.enemyFocus, 0, "off command clears observations")
  s:command("on")
  equal(s:visible(), 1, "on command restores current observations")
  s:command("status")
  equal(s.messages[#s.messages], "Me: 1 enemies targeting", "explicit status reports current observations")
  equal(s.db.sniper, false, "pressure commands do not enable offensive sniper markers")
  equal(s.db.killorder, false, "pressure commands do not enable kill order")
end

do
  local s = scenario()
  for i = 1, 3 do
    local key = "Ally" .. i .. "-Realm"
    s:addAlly(key, "party" .. i, true)
    s:addEnemy("Enemy" .. i .. "-Realm", key)
  end
  s:command("count 2")
  equal(s.db.pressureCount, 2, "count command persists valid limit")
  equal(#s.ns.enemyFocus, 2, "count setting limits ranked observations")
  equal(s:visible(), 2, "count setting limits visible markers")
  s:command("count 1")
  equal(s:visible(), 1, "lowering count clears the old extra marker")
  for _, value in ipairs({ "0", "4", "1.5", "bad" }) do
    s:command("count " .. value)
    equal(s.db.pressureCount, 1, "invalid count does not replace saved limit")
  end
  s.db.pressureCount = 99; s:update()
  equal(#s.ns.enemyFocus, 3, "out-of-range saved count is bounded by config")
  s.db.pressureCount = -1; s:update()
  equal(#s.ns.enemyFocus, 1, "negative saved count retains minimum one")
end

do
  local s = scenario()
  s.active = false
  s:command("test")
  equal(s:visible(), 1, "preview works outside a battleground")
  equal(s.env.WarboardPressure1.label.text, "TEST: 4 targeting", "preview is visibly marked as synthetic")
  equal(#s.ns.enemyFocus, 0, "preview never publishes synthetic enemy focus")
  equal(next(s.enemies), nil, "preview never inserts synthetic enemies")
  s:command("test")
  equal(s:visible(), 0, "second preview command restores normal inactive state")
  s:command("test")
  s:event("PLAYER_ENTERING_WORLD")
  equal(s:visible(), 0, "world entry exits preview immediately")
  s:pulse(0.25)
  equal(s:visible(), 0, "world entry does not silently resume preview")
  local ally = s:addAlly("Friend-Realm", "party1", true)
  s.units.target = ally
  s:command("test")
  equal(s.env.WarboardPressure1.anchor, s.plates.party1, "targeted group member receives preview")
  s:command("off")
  equal(s:visible(), 0, "off command also exits preview")
end

do
  local s = scenario()
  s:addAlly("Me-Realm", "raid1") -- player also appears in the raid roster
  s:addAlly("Raidmate-Realm", "raid2", true)
  s:addEnemy("Enemy-Realm", "Me-Realm")
  s:addEnemy("OtherEnemy-Realm", "Raidmate-Realm")
  s:update()
  equal(#s.ns.enemyFocus, 2, "raid aliases do not create duplicate ally entries")
  for _, ally in ipairs(s.ns.enemyFocus) do equal(ally.count, 1, "raid aliases do not inflate counts") end
end

do
  local s = scenario("retail")
  s:addEnemy("Enemy-Realm", "Me-Realm")
  s:update()
  s:pulse(1)
  s:command("test")
  equal(s.reads, 0, "unsupported Retail client never inspects targeting units")
  equal(#s.ns.enemyFocus, 0, "unsupported client publishes no observations")
  equal(s:visible(), 0, "unsupported client cannot show a synthetic marker")
  equal(s.db.pressure, nil, "unsupported command does not modify settings")
end
