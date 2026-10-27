local support = ...
local equal = support.equal
local scenario = support.scenario
local scenarios = support.scenarios

do
  local s = scenario()
  for i = 1, 4 do s:addAlly("Ally" .. i .. "-Realm", "party" .. i, true) end
  for i = 1, 4 do
    for n = 1, 5 - i do s:addEnemy("Enemy" .. i .. n .. "-Realm", "Ally" .. i .. "-Realm") end
  end
  s:pulse(0.24)
  equal(#s.ns.Test.enemyFocus, 0, "observations wait for configured update interval")
  s:pulse(0.01)
  equal(#s.ns.Test.enemyFocus, 3, "only the three most targeted teammates are ranked")
  equal(s:visible(), 3, "three private markers appear with sniper and kill order disabled")
  for i = 1, 3 do
    equal(s.ns.Test.enemyFocus[i].key, "Ally" .. i .. "-Realm", "rank follows distinct enemy count")
    equal(s.ns.Test.enemyFocus[i].count, 5 - i, "each observed enemy contributes once")
    local marker = s.env["HighgroundPressure" .. i]
    equal(marker.parent, s.env.UIParent, "marker is independent of protected nameplate parent")
    equal(marker.anchor, s.plates["party" .. i], "marker follows the ranked teammate")
    equal(marker.count.text, 5 - i, "badge shows the current enemy count")
    equal(marker.label.text, (5 - i) .. " targeting", "badge describes target observation")
  end
end

do
  local s = scenario()
  local a = s:addAlly("Alpha-Realm", "party1", true)
  local z = s:addAlly("Zulu-Realm", "party2", true)
  local first = s:addEnemy("First-Realm", z)
  local second = s:addEnemy("Second-Realm", z)
  s:addEnemy("Third-Realm", a)
  s:update()
  equal(s.ns.Test.enemyFocus[1].key, z.key, "higher count establishes prior rank")
  s.units[second .. "target"] = nil
  s:event("UNIT_TARGET", second)
  equal(s.ns.Test.enemyFocus[1].key, z.key, "equal counts preserve previous ordering")
  s.units[first .. "target"] = a
  s:event("UNIT_TARGET", first)
  equal(#s.ns.Test.enemyFocus, 1, "retarget removes the former victim without stale holding")
  equal(s.ns.Test.enemyFocus[1].count, 2, "retarget transfers the count immediately")
  equal(s.env.HighgroundPressure2.shown, false, "unused previous marker hides")
  s.units[first .. "target"] = nil
  s.units["nameplate23target"] = nil
  s:update()
  equal(#s.ns.Test.enemyFocus, 0, "loss of all observed targets clears ranking")
  equal(s:visible(), 0, "loss of all observed targets clears markers")
end

do
  local s = scenario()
  local ally = s:addAlly("Ally-Realm", "party1", true)
  local valid = s:addEnemy("Valid-Realm", ally)
  s.enemies["DuplicateAlias-Realm"] = { unit = valid }
  local stale = s:addEnemy("Stale-Realm", ally)
  s.units[stale].key = "DifferentEnemy-Realm"
  local dead = s:addEnemy("Dead-Realm", ally); s.units[dead].dead = true
  s:addEnemy("RosterDead-Realm", ally); s.enemies["RosterDead-Realm"].dead = true
  local offline = s:addEnemy("Offline-Realm", ally); s.units[offline].connected = false
  local missing = s:addEnemy("Missing-Realm", ally); s.units[missing].exists = false
  s:addEnemy("UnknownTarget-Realm", { key = "Stranger-Realm", isPlayer = true })
  s:addEnemy("PetTarget-Realm", { key = "Pet-Realm", isPlayer = false })
  s:addEnemy("SecretTarget-Realm", { key = s.secret })
  s:addEnemy("UnreadableTarget-Realm", { error = "key" })
  s:update()
  equal(#s.ns.Test.enemyFocus, 1, "unreadable and invalid observations do not create targets")
  equal(s.ns.Test.enemyFocus[1].count, 1, "aliases, stale units, dead and disconnected enemies are ignored")
  ally.connected = false
  s:update()
  equal(#s.ns.Test.enemyFocus, 0, "disconnected group members are excluded")
  ally.connected, ally.dead = true, true
  s:update()
  equal(#s.ns.Test.enemyFocus, 0, "dead group members are excluded")
  ally.dead, ally.error = false, "dead"
  s:update()
  equal(#s.ns.Test.enemyFocus, 0, "unreadable ally health state cannot retain a marker")
end

do
  local s = scenario()
  local ally = s:addAlly("SameName-Realm", "party1", true)
  s:addEnemy("PetWatcher-Realm", { key = ally.key, isPlayer = false })
  s:update()
  equal(#s.ns.Test.enemyFocus, 0, "a pet sharing a teammate name is not that teammate")
  local pet = s:addEnemy("EnemyName-Realm", ally)
  s.units[pet].isPlayer = false
  s:update()
  equal(#s.ns.Test.enemyFocus, 0, "a pet sharing an enemy name is not a scoreboard player")
end

do
  local s = scenario()
  local ally = s:addAlly("Ally-Realm", "party1", true)
  local unit = s:addEnemy("Enemy-Realm", ally)
  local enemy = s.units[unit]
  for _, field in ipairs({ "key", "exists", "dead", "connected", "isPlayer" }) do
    enemy.error = field
    s:update()
    equal(#s.ns.Test.enemyFocus, 0, "unreadable enemy " .. field .. " is ignored")
  end
  enemy.error = nil
  local target = { key = ally.key, isPlayer = true }
  s.units[unit .. "target"] = target
  for _, field in ipairs({ "key", "exists", "dead", "connected", "isPlayer" }) do
    target.error = field
    s:update()
    equal(#s.ns.Test.enemyFocus, 0, "unreadable target " .. field .. " is ignored")
  end
  target.error, target.isPlayer = nil, s.secret
  s:update()
  equal(#s.ns.Test.enemyFocus, 0, "secret target player classification is ignored")
  target.isPlayer, target.exists = true, false
  s:update()
  equal(#s.ns.Test.enemyFocus, 0, "missing target token cannot retain a same-name ally count")
  target.exists, target.dead = true, true
  s:update()
  equal(#s.ns.Test.enemyFocus, 0, "dead target token is ignored even if roster state has not caught up")
end
