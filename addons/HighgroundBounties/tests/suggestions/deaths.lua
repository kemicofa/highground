local t = ...
local H = dofile("tests/suggestions/fixture.lua")
local equal = t.equal
local function records(s) return #s.ns.Bounty.Suggestions.Data().events end

t.test("recaps count the fatal source; NPCs, hidden names, pets and ambiguous final hits are skipped", function()
  local s = H.new()
  local cases = {
    { { timestamp = 1, sourceName = "Enemy-Realm", sourceFlags = 0x548 }, { timestamp = 2, sourceName = "Boar", sourceFlags = 0xa48 } },
    { { timestamp = 3, sourceName = "Enemy-Realm", sourceFlags = 0x548 }, { timestamp = 4, event = "ENVIRONMENTAL_DAMAGE" } },
    { { timestamp = 5, sourceName = { secret = true }, sourceFlags = 0x548 } },
    { { timestamp = 6, sourceName = "Enemy-Realm", sourceFlags = { secret = true } } },
    { { timestamp = 7, sourceName = "Enemy-Realm", sourceFlags = 0x548, hideCaster = true } },
    { { timestamp = 8, sourceName = "Enemy-Realm", sourceFlags = 0x548, hideCaster = { secret = true } } },
    { { timestamp = 9, sourceName = "Pet-Realm", sourceFlags = 0x1148 } },
    { { timestamp = 10, sourceName = "Enemy-Realm", sourceFlags = 0x548 }, { timestamp = 10, sourceName = "Other-Realm", sourceFlags = 0x548 } },
    { { timestamp = { secret = true }, sourceName = "Enemy-Realm", sourceFlags = 0x548 } },
    { { timestamp = 12, sourceName = "UnknownRealm", sourceFlags = 0x548 } },
  }
  for _, recap in ipairs(cases) do H.death(s, nil, recap); equal(records(s), 0, "unattributed death skipped") end
  H.death(s, nil, { { timestamp = 20, sourceName = "Enemy-Other", sourceFlags = 0x548 } })
  equal(records(s), 1, "readable fatal player counted")
  H.death(s, nil, { { timestamp = 20, sourceName = "Enemy-Other", sourceFlags = 0x548 } })
  equal(records(s), 1, "old recap cannot become a second death")
  H.death(s, nil, { { timestamp = 25, sourceName = "Enemy-Other", sourceFlags = 0x548 },
    { timestamp = 21, sourceName = "Boar", sourceFlags = 0xa48 }, { timestamp = 21, sourceName = "Wolf", sourceFlags = 0xa48 } })
  equal(records(s), 2, "older tied hits do not obscure the fatal player")
  s:assertHealthy()
end)

t.test("short recap names require a unique recent sighting or matching unit GUID", function()
  local s = H.new()
  s.ns.Nearby.Note("Enemy-Other", "ROGUE", 80)
  H.death(s, nil, { { timestamp = 1, sourceName = "Enemy", sourceFlags = 0x548 } })
  equal(s.ns.Bounty.Suggestions.Data().events[1].name, "Enemy-Other", "cross-realm identity retained")
  s.ns.Nearby.Note("Enemy-Realm", "ROGUE", 80)
  H.death(s, nil, { { timestamp = 2, sourceName = "Enemy", sourceFlags = 0x548 } })
  equal(records(s), 1, "two realms with the same short name are ambiguous")
  s.units.target = { name = "Enemy", realm = "Other", guid = "Player-known", enemy = true }
  H.death(s, nil, { { timestamp = 3, sourceName = "Enemy", sourceGUID = "Player-known", sourceFlags = 0x548 } })
  equal(records(s), 2, "GUID resolves the correct realm")
  s:assertHealthy()
end)

for _, kind in ipairs({ "SPELL_DAMAGE", "SWING_DAMAGE", "RANGE_DAMAGE", "SPELL_PERIODIC_DAMAGE" }) do
  t.test("Cata " .. kind .. ": only fatal damage counts, once per life", function()
    local s = H.new("Alice", { client = "cata" })
    H.death(s, "Enemy-Realm", nil, kind, -1)
    equal(records(s), 0, "last nonfatal enemy hit is insufficient")
    H.death(s, "Enemy-Realm", nil, kind, 0)
    equal(records(s), 1, "zero overkill is an exact lethal hit")
    H.death(s, "Enemy-Realm", nil, kind, 20)
    equal(records(s), 2, "positive overkill counts another life")
    s:event("PLAYER_DEAD"); s:advance(1)
    equal(records(s), 2, "repeated death notification does not count")
    s:assertHealthy()
  end)
end

t.test("instanced PvP, duels and recap reads interrupted by resurrection do not count", function()
  local s = H.new()
  s.env.IsInInstance = function() return true, "pvp" end
  H.death(s, "Enemy-Realm")
  equal(records(s), 0, "battleground ignored")
  s.env.IsInInstance = function() return true, "arena" end
  H.death(s, "Enemy-Realm")
  equal(records(s), 0, "arena ignored")
  s.env.IsInInstance = function() return false, "none" end
  s:event("DUEL_REQUESTED"); H.death(s, "Enemy-Realm")
  equal(records(s), 0, "duel ignored")
  s:event("DUEL_FINISHED"); s:advance(3)
  s.units.player.dead = false; s:event("PLAYER_ALIVE")
  s.env.C_DeathRecap = { GetRecapEvents = function() return { { timestamp = 90, sourceName = "Enemy-Realm", sourceFlags = 0x548 } } end }
  s.units.player.dead = true; s:event("PLAYER_DEAD")
  s.units.player.dead = false; s:event("PLAYER_ALIVE"); s:advance(2)
  equal(records(s), 0, "stale callback cancelled at resurrection")
  H.death(s, "Enemy-Realm")
  equal(records(s), 1, "a later open-world death works")
  s:assertHealthy()
end)

t.test("Cata environmental death cannot inherit an earlier lethal player hit", function()
  local s = H.new("Alice", { client = "cata" })
  s.combatEvent = { s.now, "SPELL_DAMAGE", false, "Player-enemy", "Enemy-Realm", 0x548, 0,
    s.units.player.guid, "Alice", 0x511, 0, 1, "Spell", 1, 100, 0 }
  s:event("COMBAT_LOG_EVENT_UNFILTERED")
  H.death(s, "Environment", nil, "ENVIRONMENTAL_DAMAGE", 100)
  equal(records(s), 0, "environmental fatal hit has no hostile player source")
end)

t.test("short names resolve from visible hostile units with the Nearby panel disabled", function()
  local s = H.new("Alice", { saved = { bountySuggestions = true, nearby = false, nearbyHistory = false } })
  s.units.target = { name = "Enemy", realm = "Other", enemy = true, player = true }
  H.death(s, "Enemy")
  equal(records(s), 1, "target identifies the short recap name without Nearby")
  equal(s.ns.Bounty.Suggestions.Data().events[1].name, "Enemy-Other", "visible unit provides the realm")
  s.units.nameplate1 = { name = "Enemy", realm = "Another", enemy = true, player = true }
  H.death(s, "Enemy")
  equal(records(s), 1, "two possible realms remain ambiguous")
  s:assertHealthy()
end)

t.test("outgoing duels and lethal duel event ordering are excluded", function()
  local s = H.new()
  s:event("DUEL_COUNTDOWN"); H.death(s, "Enemy-Realm")
  equal(records(s), 0, "challenger's duel excluded")
  s:event("DUEL_FINISHED"); H.death(s, "Enemy-Realm")
  equal(records(s), 0, "duel finish before death cannot attribute a world kill")
  H.death(s, "Enemy-Realm")
  equal(records(s), 1, "later world encounters count")
end)

t.test("Cata accepts fatal damage delivered just after PLAYER_DEAD", function()
  local s = H.new("Alice", { client = "cata" })
  s.units.player.dead = true; s:event("PLAYER_DEAD")
  s.combatEvent = { s.now, "SPELL_DAMAGE", false, "Player-enemy", "Enemy-Realm", 0x548, 0,
    s.units.player.guid, "Alice", 0x511, 0, 1, "Spell", 1, 100, 0 }
  s:event("COMBAT_LOG_EVENT_UNFILTERED"); s:advance(1)
  equal(records(s), 1, "event ordering does not drop the attributed death")
  s:assertHealthy()
end)
