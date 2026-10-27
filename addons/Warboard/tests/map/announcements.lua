local support = ...
local check, key = support.check, support.key
local function client()
  local s, ns, e = support.client()
  s.mapID, s.positions, s.area = 275, {}, "Gilnean Coast"
  s.bg = assert(ns.ResolveBattleground(275, 761, "cata", "standard"))
  return s, ns, e
end

for _, message in ipairs({
  "Enemy has assaulted the lighthouse!",
  "Enemy has defended the lighthouse!",
  "Enemy claims the lighthouse!  If left unchallenged, the Horde will control it in 1 minute!",
  "|cffff0000|Hplayer:Enemy-Realm|hEnemy-Realm|h|r has assaulted the lighthouse!",
}) do
  local s, ns = client()
  s.nodeChat(message) -- before the first map scan
  local sight = ns.Test.intel[key]
  check(sight and sight.how == "objective" and sight.t == s.now, "named node action produces a timestamped sighting")
  check(sight.x == 0.35904251 and sight.y == 0.62878461, "remote enemy is placed at the announced capture flag")
  s.tick()
  check(ns.Test.intel[key] == sight, "first scan preserves event-driven intel")
  check(support.tooltip(s.items()[1]):find("battleground announcement", 1, true), "tooltip identifies the source")
  check(ns.MapWhere(key):find("last seen", 1, true), "announcement is last-seen information even when fresh")
  s.now = s.now + 65
  s.nodeChat("The Horde has taken the lighthouse!")
  s.tick()
  check(ns.Test.intel[key].t == sight.t and s.items()[1].desat, "faction ownership and scans do not refresh a player's old location")
  s.now = s.now + 60
  check(#s.items() == 0, "announcement sighting expires normally")
end

do
  local s, ns = client()
  for _, message in ipairs({ "Enemy has captured the flag!", "Unknown has assaulted the lighthouse!",
    "Enemy has assaulted the missing node!", "The Horde has taken the mines!" }) do
    s.nodeChat(message)
    check(ns.Test.intel[key] == nil, "unidentified players, nodes and ownership announcements cannot invent sightings")
  end
  s.nodeChat("Enemy has assaulted the lighthouse!", "CHAT_MSG_BG_SYSTEM_ALLIANCE")
  check(ns.Test.intel[key], "cross-faction games announce on the character's faction: an enemy on either channel counts")
  ns.Test.intel[key] = nil
  ns.enemies["Enemy-OtherRealm"] = { key = "Enemy-OtherRealm", display = "Enemy", class = "MAGE" }
  s.nodeChat("Enemy has assaulted the lighthouse!")
  check(next(ns.Test.intel) == nil, "ambiguous short names must not select an arbitrary enemy")
  s.nodeChat("Enemy-OtherRealm has assaulted the mines!")
  check(ns.Test.intel["Enemy-OtherRealm"] and not ns.Test.intel[key], "realm-qualified actor identifies only the correct enemy")
end

do
  local s, ns, e = client()
  s.tick()
  ns.Intel.Died(key, s.now)
  e.dead, s.now = true, s.now + 10
  local votes = 0
  ns.OnEnemySighted = function() votes = votes + 1 end
  s.nodeChat("Enemy has defended the waterworks!")
  check(ns.Test.intel[key].how == "objective" and not e.dead, "a later named interaction proves the enemy is alive")
  check(votes == 0, "a banner interaction cannot be used as resurrection-location evidence")
  s.tick()
  check(not ns.Test.intel[key].dead, "stale roster death does not erase the objective sighting")
end

do
  local s, ns = client()
  s.mapID = 1461
  s.bg = assert(ns.ResolveBattleground(1461, 529, "cata", "standard"))
  s.nodeChat("Enemy claims the stables!  If left unchallenged, the Horde will control it in 1 minute!")
  check(ns.Test.intel[key] and ns.Test.intel[key].x == 0.3748, "Arathi announcements use its configured node")
  s.now = s.now + 10
  s.pois = { { name = "Stables", position = { x = 0.38, y = 0.29 } } }
  s.poiUpdated()
  s.nodeChat("Enemy has defended the stables!")
  check(ns.Test.intel[key].x == 0.38 and ns.Test.intel[key].y == 0.29, "live node positions override defaults for announcements")
  s.active = false
  s.tick()
  s.nodeChat("Enemy has assaulted the stables!")
  check(next(ns.Test.intel) == nil, "announcements outside an active battleground are ignored")
end
