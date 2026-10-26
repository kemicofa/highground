local support = ...
local equal = support.equal
local rules = support.rules
local scenario = support.scenario
local scenarios = support.scenarios
local twinPeaks = support.twinPeaks
local byID = support.byID
local gilneas = support.gilneas
local rowFor = support.rowFor

do
  local s = gilneas()
  local otherMap = { { team = "H", x = 0.2, y = 0.3 } }
  s.db.gyLearned = { [275] = { { team = "A", x = s.pois[1].position.x,
    y = s.pois[1].position.y, label = "Lighthouse" } }, [93] = otherMap }
  s:pulse(0.25)
  s:scan()
  equal(#s.ns.Test.timers.gys, 5, "Gilneas models two permanent and three controlled graveyard identities")
  equal(s.db.gyLearned[275], nil, "old Gilneas capture-flag graveyard cache is discarded")
  equal(s.db.gyLearned[93], otherMap, "Gilneas cache migration preserves other maps")
  equal(#s.ns.Test.timersRows(s.now), 2, "only the permanent starting graveyards are available while nodes are neutral")
  equal(#s.mapLayer(275), 2, "neutral node graveyards do not have active resurrection pins")
  assert(s.ns.TimersStatus():find("graveyards yours 1, enemy 1, with timer 0", 1, true), "neutral nodes do not inflate faction graveyard counts")
  equal(byID(s, 1740).x, 0.31275517, "Alliance start has its own verified position")
  equal(byID(s, 1739).y, 0.23342345, "Horde start has its own verified position")
  equal(byID(s, 1738).y, 0.82485021, "Waterworks resurrection point is separate from its capture flag")
  equal(byID(s, 1735).x, 0.69833187, "Mine resurrection point is separate from its capture flag")
  s.pois[1].textureIndex, s.pois[2].textureIndex, s.pois[3].textureIndex = 38, 30, 18
  s:scan()
  equal(#s.ns.Test.timers.gys, 5, "capturing nodes reuses their configured identities")
  equal(#s.ns.Test.timersRows(s.now), 5, "all owned nodes appear alongside both permanent starts")
  equal(#s.mapLayer(275), 5, "all owned node graveyards have separate resurrection pins")
  assert(s.ns.TimersStatus():find("graveyards yours 3, enemy 2", 1, true), "available node ownership contributes to the correct faction counts")
  equal(byID(s, 1736).team, "A", "Lighthouse belongs to its POI owner")
  equal(byID(s, 1738).team, "H", "Waterworks belongs to its POI owner")
  equal(byID(s, 1735).team, "A", "Mine belongs to its POI owner")
  equal(byID(s, 1740).team, "A", "Alliance starting graveyard remains permanent")
  equal(byID(s, 1739).team, "H", "Horde starting graveyard remains permanent")
end

do
  local s = gilneas({ 38, 30, 16 })
  s:pulse(0.25)
  s:scan()
  local start, light, water = byID(s, 1740), byID(s, 1736), byID(s, 1738)
  equal(light.wave, nil, "joining an already owned Gilneas node leaves its clock unknown")
  s:event("CHAT_MSG_ADDON", "WarboardT", "2:275:W,A,3128,8010,3,;W,A,3151,6554,13,;W,H,6209,8249,23,",
    "INSTANCE_CHAT", "Friend")
  equal(start.wave, s.now + 3, "starting graveyard has an independent shared clock")
  equal(light.wave, s.now + 13, "node graveyard keeps a different shared clock")
  equal(water.wave, s.now + 23, "enemy node keeps its own shared clock")
  s:event("CHAT_MSG_ADDON", "WarboardT", "2:275:W,A,0,0,8,;W,H,0,0,8,;V,0,0,5,0,Battle for Gilneas",
    "INSTANCE_CHAT", "Friend")
  equal(start.wave, s.now + 3, "unlocated sharing cannot select the permanent starting graveyard")
  equal(light.wave, s.now + 13, "unlocated sharing cannot select an owned node")
  s:scan(39)
  equal(s.ns.Test.timers.NextWave(light, s.now), nil, "assaulted Lighthouse stops resurrecting")
  equal(rowFor(s, "Lighthouse Graveyard"), nil, "contested node is absent from active graveyard rows")
  equal(start.wave, s.now + 3, "assaulting Lighthouse leaves Alliance start available with its own clock")
  s:event("CHAT_MSG_ADDON", "WarboardT", "2:275:W,A,3151,6554,5,Lighthouse Graveyard", "INSTANCE_CHAT", "Friend")
  equal(light.wave, nil, "shared wave cannot restore a contested graveyard")
  s.now = s.now + 60
  s:scan(40)
  equal(byID(s, 1736), light, "ownership transfer preserves the Lighthouse graveyard ID")
  equal(light.team, "H", "Lighthouse graveyard transfers to the capturing team")
  equal(light.conf, "cap", "former owner clock is replaced by a new capture estimate")
  equal(light.wave, s.now, "new owner's capture estimate starts at capture")
  equal(light.x, 0.31507454, "ownership transfer does not move the resurrection pin onto the capture flag")
  equal(light.label, "Lighthouse Graveyard", "ownership transfer preserves a proper graveyard name")
  s.pois[2].textureIndex = 26
  s:scan()
  equal(water.team, nil, "neutralized configured node loses its team")
  equal(s.ns.Test.timers.NextWave(water, s.now), nil, "neutralized node has no resurrection wave")
  assert(s.ns.TimersStatus():find("graveyards yours 1, enemy 2", 1, true), "counts include starts and only currently available owned nodes")
end

do
  local s = gilneas({ 38, 28, 20 })
  s:pulse(0.25)
  s:scan()
  local start, light = byID(s, 1740), byID(s, 1736)
  light.wave, light.conf, light.waveAt = s.now + 3, "exact", s.now
  s.ns.Locate = function() return light.x, light.y, "Lighthouse", "coords" end
  equal(s.ns.Test.timers.MyGraveyard(s.now), nil, "Gilneas cannot infer spawn destination from the nearest calibrated graveyard")
  equal(rowFor(s, "Lighthouse Graveyard").tag, "OURS", "nearby timed node remains OURS without an identified destination")
  equal(s.ns.Test.timers.GoodTimeToDie(s.now), nil, "Gilneas does not recommend death from an arbitrary friendly clock")
  s.ns.ReleaseXY = function() return start.x, start.y end
  equal(s.ns.Test.timers.MyGraveyard(s.now), start, "actual release destination selects the starting graveyard")
  equal(rowFor(s, "Alliance Starting Graveyard").tag, "YOU", "YOU identifies the starting destination even with an unknown clock")
  equal(rowFor(s, "Alliance Starting Graveyard").left, nil, "unknown destination does not borrow Lighthouse countdown")
  equal(rowFor(s, "Lighthouse Graveyard").tag, "OURS", "other friendly nodes remain OURS")
  equal(s.ns.Test.timers.GoodTimeToDie(s.now), nil, "an uncalibrated actual destination cannot trigger death advice")
  start.wave, start.conf, start.waveAt = s.now + 4, "exact", s.now
  equal(s.ns.Test.timers.GoodTimeToDie(s.now), 4, "observed destination clock can support death advice")
  s.ns.ReleaseXY = function() return light.x, light.y end
  s:scan(39)
  equal(s.ns.Test.timers.MyGraveyard(s.now), nil, "a stale release position cannot identify an unavailable contested node")
  equal(rowFor(s, "Lighthouse Graveyard"), nil, "YOU cannot re-add an unavailable node to the active rows")
end

do
  local s = gilneas({ 0, 0, 0 })
  s.pois[1].name, s.pois[1].factionID = "Leuchtturm", 469
  s.pois[2].name, s.pois[2].factionID = "Wasserwerk", 67
  s.pois[3].name = "Mine"
  s.env.C_DeathInfo = { GetGraveyardsForMap = function()
    return {
      { graveyardID = 1738, position = { x = 0.63, y = 0.83 } },
      { graveyardID = 1740, position = { x = 0.32, y = 0.81 } },
      { graveyardID = 1798, position = { x = 0.31, y = 0.80 } },
    }
  end }
  s:pulse(0.25)
  s:scan()
  equal(byID(s, 1736).team, "A", "configured control positions identify localized POIs with unknown icons")
  equal(byID(s, 1738).team, "H", "localized Waterworks ownership reaches its graveyard")
  equal(byID(s, 1738).x, 0.63, "live node graveyard ID overrides its fallback position")
  equal(byID(s, 1740).x, 0.32, "live starting graveyard ID overrides its fallback position")
  equal(#s.ns.Test.timers.gys, 5, "prematch spawn ID never creates an extra starting graveyard")
  equal(s.ns.Test.GYName(byID(s, 1738)), "Waterworks Graveyard", "localized control POIs retain the configured graveyard label")
  s.pois[2].factionID = 469
  s:scan()
  equal(byID(s, 1738).team, "A", "localized ownership changes remain tied to the capture flag after live graveyard movement")
  equal(byID(s, 1738).x, 0.63, "ownership changes preserve the independently located resurrection point")
end

do
  local s = gilneas({ 38, 26, 16 })
  s:pulse(0.25)
  s:scan()
  local light = byID(s, 1736)
  local guid = "Creature-0-1-761-0-13116-0003"
  s.units.target = { guid = guid }
  s.ns.UnitXY = function(_, unit) if unit == "target" then return light.x, light.y end end
  s:pulse(1)
  s.combatEvent = { s.now, "SPELL_CAST_SUCCESS", false, guid, "Spirit Guide" }
  s:event("COMBAT_LOG_EVENT_UNFILTERED")
  equal(light.conf, "guide", "located friendly node guide supplies its own clock")
  s:scan(39)
  s.now = s.now + 60
  s:scan(40)
  s:event("COMBAT_LOG_EVENT_UNFILTERED")
  equal(light.team, "H", "node belongs to its new owner")
  equal(light.conf, "cap", "former owner's spirit guide cannot overwrite the new owner's clock")
  equal(byID(s, 1740).team, "A", "node guide reassignment never changes the permanent starting graveyard")
end

do
  local s = scenario()
  s.rules.objective = "flag"
  s:pulse(0.25)
  local names = { "WarboardTimersFrame", "WarboardBasesFrame", "WarboardFlagsFrame" }
  for _, name in ipairs(names) do
    equal(s.env[name]:GetScale(), 0.8, name .. " starts at the smaller default scale")
  end
  s.db.scale = 0.7
  s.ns.TimersApplyScale()
  for _, name in ipairs(names) do
    equal(s.env[name]:GetScale(), 0.7, name .. " follows the shared scale immediately")
  end
  s.combat = true
  s.db.scale = 0.6
  s.ns.TimersApplyScale()
  s:pulse(0.25)
  for _, name in ipairs(names) do
    equal(s.env[name]:GetScale(), 0.7, name .. " retains its scale in combat")
  end
  s.combat = false
  s.ns.TimersApplyScale()
  for _, name in ipairs(names) do
    equal(s.env[name]:GetScale(), 0.6, name .. " applies the queued scale, including an already visible carrier panel")
  end
end
