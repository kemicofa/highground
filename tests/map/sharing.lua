local support = ...
local key = support.key
local check = support.check
local client = support.client
local tooltip = support.tooltip
local checkUnknown = support.checkUnknown

do
  local s, ns = client()
  s.mapID, s.area, s.positions = 206, "Twin Peaks", {}
  s.bg = assert(ns.ResolveBattleground(206, 726, "cata", "standard"))
  s.tick()
  ns.RecordSighting(key, 0.8, 0.8, 3, "Me", s.now, nil, "coords")
  s.now = 110
  s.receive("2:206:" .. key .. ",2000,7500,80,0,Twin Peaks")
  checkUnknown(s, ns, "legacy shared coordinates must not restore an old graveyard proxy")
  check(ns.intel[key].area == "Twin Peaks", "legacy messages retain usable area context")
end

do
  local s, _, e = client({ unit = "target" })
  s.group, e.yards = true, 5
  s.tick()
  s.tick()
  local message = s.messages[1] and s.messages[1].message
  check(message and message:match("^3:1460:"), "outbound sightings use the v3 protocol")
  check(message:find(key .. ",1000,1000,5,0,nearby,", 1, true), "outbound sharing preserves approximate source quality")
end

do
  local s, ns = client()
  s.mapID, s.area = 206, "Twin Peaks"
  s.bg = assert(ns.ResolveBattleground(206, 726, "cata", "standard"))
  s.flags = { { 0.41, 0.63, "Alliance" } }
  s.flagPickup("The Alliance flag was picked up by Enemy!")
  local x, y = ns.AreaXY(206, "Wildhammer Stronghold")
  check(x == 0.58 and y == 0.2, "picking up a dropped midfield flag must not relocate its home base")
  check(not (s.db.observedAnchors and s.db.observedAnchors[206]),
    "a remote flag pickup is not an observation of the player's current area")
end

do
  local s, ns = client()
  s.mapID = 206
  s.bg = assert(ns.ResolveBattleground(206, 726, "cata", "standard"))
  local old = { [206] = { ["wildhammer stronghold"] = { 0.1, 0.9, 5 } } }
  s.db.anchors = old
  local x, y = ns.AreaXY(206, "Wildhammer Stronghold")
  check(x == 0.58 and y == 0.2, "legacy anchors from unqualified pickups must not override configured bases")
  check(s.db.anchors == old and old[206]["wildhammer stronghold"][1] == 0.1,
    "legacy anchor data is preserved without being trusted as a current observation")
end

do
  local s, ns = client()
  s.mapID, s.area, s.positions = 206, "Wildhammer Stronghold", {}
  s.bg = assert(ns.ResolveBattleground(206, 726, "cata", "standard"))
  s.flagAura = 23333
  s.flags = { { 0.57, 0.21, "Horde" } }
  s.tick()
  local anchor = s.db.observedAnchors and s.db.observedAnchors[206]
    and s.db.observedAnchors[206]["wildhammer stronghold"]
  check(anchor and anchor[1] == 0.57 and anchor[2] == 0.21,
    "carrying a flag observes the player's named area through its exact position")
  local x, y = ns.AreaXY(206, "Wildhammer Stronghold")
  check(x == 0.57 and y == 0.21, "qualified observed anchors take precedence over rough defaults")
end
