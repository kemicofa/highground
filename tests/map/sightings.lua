local support = ...
local key = support.key
local check = support.check
local client = support.client
local tooltip = support.tooltip
local checkUnknown = support.checkUnknown

-- Range to an unlocated teammate is not a map-position accuracy. Frequent
-- melee events used to override area pins and then prevent local refreshes.
do
  local s, ns, e = client({ unit = "target", ally = true })
  s.positions, e.yards = {}, 5
  s.tick()
  for i = 1, 4 do
    s.now = s.now + 0.5
    s.combat("SWING_DAMAGE", nil, "Ally")
    check(ns.intel[key].how == "area", "unlocated teammate combat must not erase a concurrent area sighting")
    s.tick()
    check(ns.intel[key].t == s.now, "local area sightings must keep refreshing during teammate combat")
  end
  e.unit = nil
  s.now = s.now + 5
  s.combat("SWING_DAMAGE", nil, "Ally")
  checkUnknown(s, ns, "a later unknown sighting still replaces a stale position")
  e.unit = "target"
  s.tick()
  check(ns.intel[key].how == "area", "a concurrent located sighting must replace unknown intel even with a wider radius")
end

do
  local s, ns, e = client({ unit = "arena1" })
  e.carrier = true
  s.positions.arena1 = { x = 0.9, y = 0.9 }
  s.tick()
  local sight = ns.intel[key]
  check(sight and sight.x == 0.9 and sight.y == 0.9, "remote carrier must use its own coordinates")
  check(sight.how == "coords" and sight.r == 3, "coordinate sightings retain their precision")
  local items = s.items()
  check(#items == 1 and items[1].x == 0.9 and items[1].y == 0.9, "exact coordinates reach the map layer unchanged")
end

-- Cata reports no unit coordinates in some battlegrounds. A graveyard is
-- where the player would release, not where the current fight is happening.
do
  local s, ns, e = client({ unit = "target" })
  s.mapID, s.area, s.positions = 206, "Twin Peaks", {}
  s.bg = assert(ns.ResolveBattleground(206, 726, "cata", "standard"))
  s.releasePosition = { x = 0.2, y = 0.75 }
  e.yards, e.class = 5, "PALADIN"
  s.tick()
  checkUnknown(s, ns, "a nearby enemy must never be located at the player's release graveyard")
  check(ns.intel[key].area == "Twin Peaks", "unknown-position intel retains the observed broad area")
  s.now = 110
  s.tick()
  checkUnknown(s, ns, "ongoing combat stays fresh without inventing a graveyard position")
end

do
  local s, ns, e = client({ unit = "target" })
  s.area, s.positions = "", {}
  e.yards = 5
  s.tick()
  ns.RecordSighting(key, 0.8, 0.8, 3, "Me", s.now, nil, "coords")
  s.now = 110
  s.tick()
  checkUnknown(s, ns, "nearby observation without area must replace a stale old position")
  e.unit, e.yards = nil, nil
  ns.RecordSighting(key, 0.8, 0.8, 3, "Me", s.now, nil, "coords")
  s.now = 120
  s.combat("SWING_DAMAGE")
  checkUnknown(s, ns, "confirmed melee without area must replace a stale old position")
end

for _, event in ipairs({ "SPELL_CAST_SUCCESS", "SPELL_DAMAGE", "SPELL_MISSED" }) do
  local s, ns = client({ unit = "target" })
  s.tick()
  check(ns.intel[key] == nil, "a target token alone remains insufficient")
  s.combat(event, 49020) -- Obliterate: a configured melee ability
  local sight = ns.intel[key]
  check(sight and sight.t == s.now and sight.r == 5 and sight.x == 0.1,
    event .. " for a known melee ability provides proximity evidence")
end

do
  local s, ns = client({ unit = "target" })
  s.tick()
  s.combat("SPELL_CAST_SUCCESS", 116) -- Frostbolt: a configured ranged probe
  check(ns.intel[key] and ns.intel[key].r == 40, "a successful known targeted ranged cast locates the encounter roughly")
  local original = ns.intel[key]
  s.now, s.positions.player = 110, { x = 0.7, y = 0.7 }
  for _, event in ipairs({ "SPELL_DAMAGE", "SPELL_MISSED", "SPELL_PERIODIC_DAMAGE", "SPELL_AURA_APPLIED",
    "SPELL_AURA_REFRESH", "SPELL_AURA_REMOVED" }) do
    s.combat(event, 116)
    check(ns.intel[key] == original, event .. " must not treat a delayed ranged effect as current proximity")
  end
  for _, event in ipairs({ "SPELL_CAST_SUCCESS", "SPELL_DAMAGE", "SPELL_MISSED" }) do
    s.combat(event, 999999) -- An unrecognized proc/effect cannot establish range.
    check(ns.intel[key] == original, event .. " with an unrecognized spell must not refresh intel")
  end
  s.combat("SPELL_PERIODIC_DAMAGE", 49020)
  check(ns.intel[key] == original, "even known melee IDs cannot make periodic damage prove proximity")
end

do
  local s, ns, e = client({ unit = "target" })
  e.yards = 5
  s.tick()
  check(ns.intel[key].how == "nearby", "observer coordinates are identified as an estimate of enemy position")
  check(s.items()[1].label:sub(1, 1) == "~", "rough observed positions are visibly approximate")
  s.now, s.positions = 110, {}
  s.tick()
  check(ns.intel[key].how == "area", "a named anchor is identified as an area estimate")
  check(s.items()[1].label:sub(1, 1) == "~", "anchor estimates are visibly approximate")
end

for _, unit in ipairs({ "arena1", "target", "mouseover" }) do
  local s, ns = client({ unit = unit })
  s.tick()
  check(ns.intel[key] == nil, unit .. " alone must not place an enemy beside the observer")
end

do
  local s, ns, e = client({ unit = "target" })
  e.yards = 30
  s.tick()
  check(ns.intel[key].x == 0.1 and ns.intel[key].r == 30, "measured proximity allows approximate local sightings")
  s.now = 110
  e.yards = 45
  s.tick()
  check(ns.intel[key].t == 100, "a distant target must not refresh the sighting")
end

do
  local s, ns, e = client({ unit = "nameplate1" })
  e.plateUnit = "nameplate1"
  s.tick()
  check(ns.intel[key] and ns.intel[key].r == 40, "visible nameplates permit rough local sightings")
end

do
  local s, ns = client({ ally = true })
  s.positions.party1 = { x = 0.7, y = 0.7 }
  s.tick()
  check(ns.intel[key] == nil, "an ally's target must not be placed at the ally")
  s.positions.party1target = { x = 0.9, y = 0.8 }
  s.tick()
  check(ns.intel[key].x == 0.9 and ns.intel[key].y == 0.8, "readable ally-target coordinates remain usable")
end

do
  local s, ns = client()
  s.tick()
  ns.RecordSighting(key, 0.8, 0.8, 40, "Me", s.now)
  local original = ns.intel[key]
  s.now = 110
  s.positions.player = { x = 0.2, y = 0.2 }
  for _, event in ipairs({ "SPELL_PERIODIC_DAMAGE", "SPELL_AURA_APPLIED", "SPELL_AURA_REFRESH",
    "SPELL_AURA_REMOVED", "SPELL_DAMAGE" }) do
    s.combat(event)
    check(ns.intel[key] == original, event .. " must not fabricate current proximity")
  end
  s.combat("SWING_DAMAGE")
  check(ns.intel[key].t == 110 and ns.intel[key].x == 0.2 and ns.intel[key].r == 8,
    "a melee swing proves current proximity")
  s.now = 120
  s.combat("SWING_MISSED")
  check(ns.intel[key].t == 120, "a missed melee swing also proves proximity")
end

-- Teammates without Warboard send no area. One in group range of you is
-- in your area; one out of range stays unknown.
do
  local s, ns, e = client({ ally = true })
  s.positions, s.area = {}, "Silverwing Hold"
  s.inRange = { party1 = true }
  s.combat("SWING_DAMAGE", nil, "Ally")
  local sight = ns.intel[key]
  check(sight and sight.how == "area" and sight.area == "Silverwing Hold" and sight.x == 0.5,
    "an in-range teammate's combat is placed in the player's area")
  check(sight.by == "Ally" and sight.r == 120, "the teammate stays the observer, with range added to the radius")
  s.inRange.party1, s.now = false, s.now + 5
  s.combat("SWING_DAMAGE", nil, "Ally")
  checkUnknown(s, ns, "an out-of-range teammate without Warboard cannot be located")
  check(e.unit == nil, "the enemy had no unit token in this scenario")
end

-- The recent-area guess ends with the observer's death: a resurrection is
-- a graveyard, not the place left before dying.
do
  local s, ns, e = client({ unit = "target" })
  s.positions, e.yards, s.area = {}, 5, "Silverwing Hold"
  s.tick()
  s.dead = { player = true }
  s.now = s.now + 2
  s.tick()
  s.dead, s.area, s.now = nil, "", s.now + 2
  s.tick()
  checkUnknown(s, ns, "dying clears the recently left area")
end

-- Map-only inference never reaches the timers' own location lookup.
do
  local s, ns, e = client({ unit = "target" })
  s.positions, e.yards, s.area = {}, 5, "Silverwing Hold"
  s.tick()
  s.area, s.now = "", s.now + 2
  s.tick()
  check(ns.intel[key].how == "recent", "the map guesses from the area just left")
  check(select(4, ns.Locate(s.mapID, "player", "Me")) == "unknown", "Locate keeps reporting only what is known")
end

-- Cata Warsong Gulch flag rooms anchor at the flag spawns.
for area, y in pairs({ ["Warsong Flag Room"] = 0.93, ["Silverwing Flag Room"] = 0.11335 }) do
  local s, ns, e = client({ unit = "target" })
  s.positions, e.yards, s.area = {}, 5, area
  s.tick()
  check(ns.intel[key].how == "area" and ns.intel[key].y == y, area .. " has a configured anchor")
end
