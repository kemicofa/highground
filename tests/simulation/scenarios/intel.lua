local test, new, equal = ...

test("remote node announcements place last-seen enemies and ownership does not refresh them", function()
  local sim = new("cata")
  sim.area = "Gilnean Coast"
  local _, token = sim:enemy("Scout")
  sim.units[token] = nil
  sim:join(275, 761, "Battle for Gilneas")
  equal(sim.ns.intel["Scout-Realm"], nil, "unseen enemy starts unlocated")
  sim:event("CHAT_MSG_BG_SYSTEM_HORDE", "Scout has assaulted the lighthouse!")
  local sight = assert(sim.ns.intel["Scout-Realm"])
  equal(sight.how, "objective", "system announcement supplies location evidence")
  sim:advance(0.5)
  for _, canvas in ipairs({ sim.env.WorldMapFrame, sim.env.BattlefieldMapFrame }) do
    local pin
    for _, candidate in ipairs(canvas.pins) do
      if candidate.item.icon == "classicon-mage" then pin = candidate end
    end
    assert(pin, "remote enemy rendered on map")
    equal(pin.x, 0.35904251, "announcement selects Lighthouse capture flag")
    equal(pin.y, 0.62878461, "announcement selects Lighthouse capture flag")
    local lines = {}
    pin.item.tooltip({ AddLine = function(_, line) lines[#lines + 1] = line end })
    assert(table.concat(lines, " "):find("battleground announcement", 1, true))
  end
  sim:advance(65)
  sim:event("CHAT_MSG_BG_SYSTEM_HORDE", "The Horde has taken the lighthouse!")
  equal(sim.ns.intel["Scout-Realm"].t, sight.t, "ownership cannot claim the assaulter stayed at the node")
  sim:event("CHAT_MSG_BG_SYSTEM_HORDE", "Scout has defended the mines!")
  equal(sim.ns.intel["Scout-Realm"].x, 0.60478025, "new named action updates the remote location")
  sim:combatLog("UNIT_DIED", "Me", "Scout")
  sim:advance(1.5)
  for _, canvas in ipairs({ sim.env.WorldMapFrame, sim.env.BattlefieldMapFrame }) do
    for _, pin in ipairs(canvas.pins) do
      assert(pin.item.icon ~= "classicon-mage", "death removes the announcement pin")
    end
  end
end)

test("large stacks remain separate on the world and small battlefield canvases", function()
  local sim = new("cata")
  sim.area = "Lighthouse"
  for i = 1, 15 do sim:enemy("Scout" .. i) end
  sim:join(275, 761, "Battle for Gilneas")
  for _, area in ipairs({ "Lighthouse", "Gilnean Coast" }) do
    sim.area = area
    sim:advance(2.5)
    for _, canvas in ipairs({ sim.env.WorldMapFrame, sim.env.BattlefieldMapFrame }) do
      local enemies = {}
      for _, pin in ipairs(canvas.pins) do
        if pin.item.icon == "classicon-mage" then enemies[#enemies + 1] = pin end
      end
      equal(#enemies, 15, "all enemy markers are rendered")
      for i, pin in ipairs(enemies) do
        assert(pin.x > 0 and pin.x < 1 and pin.y > 0 and pin.y < 1, "marker stays within the map")
        for j = 1, i - 1 do
          local dx = math.abs(pin.x - enemies[j].x) * canvas:GetWidth()
          local dy = math.abs(pin.y - enemies[j].y) * canvas:GetHeight()
          assert(dx >= 39.9 or dy >= 41.9, "marker icons and labels remain separated in screen space")
        end
      end
    end
  end
end)

test("Gilneas sightings follow named areas on both maps without coordinate APIs", function()
  local sim = new("cata")
  sim.area = "Lighthouse"
  sim:enemy("Scout")
  sim:join(275, 761, "Battle for Gilneas")
  sim.releasePosition = { x = 0.62092516, y = 0.82485021 }
  for _, point in ipairs({
    { "Lighthouse", 0.35904251, 0.62878461 },
    { "Waterworks", 0.61219299, 0.71837309 },
    { "Mines", 0.60478025, 0.40649971 },
    { "Gilnean Stronghold", 0.31425966, 0.78938248 },
    { "Horde Landing", 0.59039461, 0.23965079 },
  }) do
    sim.area = point[1]
    sim:advance(2.5)
    local sight = assert(sim.ns.intel["Scout-Realm"])
    equal(sight.how, "area", point[1] .. " has a fallback area position")
    equal(sight.area, point[1], "current area replaces the previous one")
    for _, canvas in ipairs({ sim.env.WorldMapFrame, sim.env.BattlefieldMapFrame }) do
      local pin
      for _, candidate in ipairs(canvas.pins) do
        if candidate.item.icon == "classicon-mage" then pin = candidate end
      end
      assert(pin, "enemy pin rendered")
      equal(pin.x, point[2], "enemy pin follows the area horizontally")
      equal(pin.y, point[3], "enemy pin follows the area vertically")
      equal(pin.item.label, "~", "fallback is marked approximate")
    end
  end
  local sent = false
  for _, packet in ipairs(sim.sent) do
    if packet.prefix == "WarboardI" and packet.message:find(",area,Mines", 1, true) then sent = true end
  end
  assert(sent, "Mines area position is shared with its quality intact")
  sim.area = "Gilnean Coast"
  sim:advance(2.5)
  equal(sim.ns.intel["Scout-Realm"].how, "unknown", "broad coastal name cannot perpetuate the last base position")
end)

test("Arathi area pins survive unlocated teammate combat on both maps", function()
  local sim = new("cata")
  sim.members, sim.units.party1 = 2, { name = "Friend", classID = 1 }
  local _, token = sim:enemy("Scout")
  sim:join(1461, 529, "Arathi Basin")
  for _ = 1, 20 do
    sim:advance(0.25)
    sim:combatLog("SWING_DAMAGE", "Friend", "Scout")
    equal(sim.ns.intel["Scout-Realm"].how, "area", "unknown ally position does not displace a fresh area pin")
  end
  for _, canvas in ipairs({ sim.env.WorldMapFrame, sim.env.BattlefieldMapFrame }) do
    local pin
    for _, candidate in ipairs(canvas.pins) do
      if candidate.item.icon == "classicon-mage" then pin = candidate end
    end
    assert(pin, "enemy pin rendered without coordinate APIs")
    equal(pin.x, 0.3748, "pin uses Stables area anchor")
    equal(pin.y, 0.2917, "pin uses Stables area anchor")
    equal(pin.item.label, "~", "area estimates are labeled")
  end
  local sent = false
  for _, packet in ipairs(sim.sent) do
    if packet.prefix == "WarboardI" and packet.message:find(",area,Stables", 1, true) then sent = true end
  end
  assert(sent, "located area sightings remain available to share")
  sim.units[token] = nil
  sim:advance(5)
  sim:combatLog("SWING_DAMAGE", "Friend", "Scout")
  sim:advance(0.5)
  equal(sim.ns.intel["Scout-Realm"].how, "unknown", "unknown events cannot keep old positions fresh")
end)

test("local coordinates flow through observations, packets and both map canvases", function()
  local sim = new("cata")
  local _, token = sim:enemy("Scout", { position = { x = 0.3, y = 0.4 } })
  sim:join()
  sim:advance(2)
  local intel = assert(sim.ns.intel["Scout-Realm"])
  equal(intel.how, "coords", "location source retained")
  equal(intel.x, 0.3, "coordinates retained")
  for _, canvas in ipairs({ sim.env.WorldMapFrame, sim.env.BattlefieldMapFrame }) do
    equal(#canvas.pins, 1, "one enemy pin rendered")
    equal(canvas.pins[1].x, 0.3, "pin mixin receives position")
    equal(canvas.pins[1].y, 0.4, "pin mixin receives position")
  end
  local sent = false
  for _, packet in ipairs(sim.sent) do
    if packet.prefix == "WarboardI" and packet.message:find("Scout-Realm", 1, true) then sent = true end
  end
  assert(sent, "observation broadcast from actual queue")
  sim.units[token] = nil
  sim:advance(6)
  equal(sim.env.WorldMapFrame.pins[1].item.desat, true, "old observations grey out")
  sim:advance(120)
  equal(#sim.env.WorldMapFrame.pins, 0, "expired observations leave map")
end)

test("another addon instance receives shared sightings and ignores other maps", function()
  local sender, receiver = new("cata"), new("cata")
  sender:enemy("Scout", { position = { x = 0.3, y = 0.4 } })
  receiver:enemy("Scout")
  receiver.units.nameplate1 = nil
  sender:join(); receiver:join()
  sender:advance(2)
  local packet
  for _, item in ipairs(sender.sent) do
    if item.prefix == "WarboardI" and item.message:find("Scout-Realm", 1, true) then packet = item end
  end
  assert(packet)
  receiver:event("CHAT_MSG_ADDON", packet.prefix, packet.message, packet.channel, "Friend-Realm")
  receiver:advance(0.5)
  equal(receiver.ns.intel["Scout-Realm"].x, 0.3, "remote coordinates received")
  equal(receiver.env.WorldMapFrame.pins[1].x, 0.3, "remote sighting rendered")
  receiver:join(1460, 489, "Warsong Gulch")
  receiver:event("CHAT_MSG_ADDON", packet.prefix, packet.message, packet.channel, "Friend-Realm")
  equal(receiver.ns.intel["Scout-Realm"], nil, "previous map packet ignored")
end)

test("enemy death removes map pin and reappearance supplies resurrection evidence", function()
  local sim = new("cata")
  local enemy = sim:enemy("Fallen", { position = { x = 0.2, y = 0.3 } })
  sim:join()
  sim:poi(40) -- independently observed Horde graveyard at Stables
  enemy.dead = true
  sim:combatLog("UNIT_DIED", "Me", "Fallen")
  sim:advance(1.5)
  equal(sim:entry("Fallen").dead, true, "death reaches roster")
  for _, pin in ipairs(sim.env.WorldMapFrame.pins) do
    assert(pin.item.icon ~= "classicon-mage", "dead enemy has no map pin")
  end
  equal(sim.ns.GetKillNow(), nil, "dead enemy cannot be kill target")
  sim:advance(5)
  enemy.dead = false
  sim:advance(1.5)
  equal(sim:entry("Fallen").dead, false, "sighting clears death")
  equal(sim.ns.GetKillNow().key, "Fallen-Realm", "alive target returns")
  assert(sim.ns.Timers.stats.votes > 0, "map reappearance reaches resurrection estimator")
end)
