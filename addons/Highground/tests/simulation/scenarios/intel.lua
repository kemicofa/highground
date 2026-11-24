local test, new, equal = ...

test("remote node announcements place last-seen enemies and ownership does not refresh them", function()
  local sim = new("cata")
  sim.area = "Gilnean Coast"
  local _, token = sim:enemy("Scout")
  sim.units[token] = nil
  sim:join(275, 761, "Battle for Gilneas")
  equal(sim.ns.Test.intel["Scout-Realm"], nil, "unseen enemy starts unlocated")
  sim:event("CHAT_MSG_BG_SYSTEM_HORDE", "Scout has assaulted the lighthouse!")
  local sight = assert(sim.ns.Test.intel["Scout-Realm"])
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
    local tip = table.concat(lines, " ")
    assert(tip:find("Scout", 1, true) and tip:find("Last seen %d+s ago") and not tip:find(" by ", 1, true),
      "a circled enemy's tooltip gives only who and how long ago")
  end
  sim:advance(65)
  sim:event("CHAT_MSG_BG_SYSTEM_HORDE", "The Horde has taken the lighthouse!")
  equal(sim.ns.Test.intel["Scout-Realm"].t, sight.t, "ownership cannot claim the assaulter stayed at the node")
  sim:event("CHAT_MSG_BG_SYSTEM_HORDE", "Scout has defended the mines!")
  equal(sim.ns.Test.intel["Scout-Realm"].x, 0.60478025, "new named action updates the remote location")
  sim:combatLog("UNIT_DIED", "Me", "Scout")
  sim:advance(1.5)
  for _, canvas in ipairs({ sim.env.WorldMapFrame, sim.env.BattlefieldMapFrame }) do
    for _, pin in ipairs(canvas.pins) do
      assert(pin.item.icon ~= "classicon-mage", "death removes the announcement pin")
    end
  end
end)

test("approximate sightings share a faint circle that holds their enemies on both canvases", function()
  local sim = new("cata")
  sim.area = "Lighthouse"
  for i = 1, 15 do sim:enemy("Scout" .. i) end
  sim:join(275, 761, "Battle for Gilneas")
  for _, area in ipairs({ "Lighthouse", "Gilnean Coast" }) do
    sim.area = area
    sim:advance(2.5)
    for _, canvas in ipairs({ sim.env.WorldMapFrame, sim.env.BattlefieldMapFrame }) do
      local zones, enemies = {}, {}
      for _, pin in ipairs(canvas.pins) do
        if pin.item.radius then zones[#zones + 1] = pin end
        if pin.item.icon == "classicon-mage" then enemies[#enemies + 1] = pin end
      end
      equal(#zones, 1, "enemies seen in one area share one circle")
      local zone = zones[1]
      local radius = zone:GetWidth() / 2
      equal(zone.Count.text, "15", "the circle shows how many were seen there")
      assert(#enemies <= 15, "icons only for the enemies that fit")
      for i, pin in ipairs(enemies) do
        local dx = (pin.x - zone.x) * canvas:GetWidth()
        local dy = (pin.y - zone.y) * canvas:GetHeight()
        local d = math.sqrt(dx * dx + dy * dy)
        assert(d <= radius + 0.5 and d >= radius / 3, "icons sit on the inside of the ring, clear of the count")
        equal(pin.item.label, "", "ages move to the circle's tooltip")
        for j = 1, i - 1 do
          local ox = (pin.x - enemies[j].x) * canvas:GetWidth()
          local oy = (pin.y - enemies[j].y) * canvas:GetHeight()
          assert(math.sqrt(ox * ox + oy * oy) >= pin.item.size * 0.9, "icons are spread evenly, not piled up")
        end
      end
      if #enemies > 0 then enemies[1].item.alpha = 0.4 end
      zone.scripts.OnEnter(zone)
      equal(zone.highlighted, true, "hover brings the circle up")
      equal(zone.Rim.texture, sim.ns.Core.MAP_RING, "a thin outline, not a dark disc under the fill")
      assert(zone.Disc.alpha < 0.5, "the fill stays see-through while hovered")
      if #enemies > 0 then equal(enemies[1].alpha, 1, "hover shows its enemies at full strength") end
      zone.scripts.OnLeave(zone)
      equal(zone.highlighted, false, "and it fades again")
      if #enemies > 0 then equal(enemies[1].alpha, 0.4, "and lets them fade with age again") end
      if #enemies > 0 then
        enemies[1].scripts.OnEnter(enemies[1])
        equal(zone.highlighted, true, "hovering an enemy brings up its circle")
        enemies[1].scripts.OnLeave(enemies[1])
      end
      local lines = {}
      zone.item.tooltip({ AddLine = function(_, line) lines[#lines + 1] = line end })
      assert(table.concat(lines, " "):find("Somewhere in this circle", 1, true), "the circle explains itself")
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
    local sight = assert(sim.ns.Test.intel["Scout-Realm"])
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
      assert(pin.item.zone and pin.item.zone.radius > 0, "a fallback position sits in a circle")
    end
  end
  local sent = false
  for _, packet in ipairs(sim.sent) do
    if packet.prefix == "HighgroundI" and packet.message:find(",area,Mines", 1, true) then sent = true end
  end
  assert(sent, "Mines area position is shared with its quality intact")
  sim.area = "Gilnean Coast"
  sim:advance(2.5)
  local sight = sim.ns.Test.intel["Scout-Realm"]
  equal(sight.how, "recent", "just leaving a base keeps a guess near it")
  equal(sight.near, "Horde Landing", "the guess names the area just left")
  equal(sight.area, "Gilnean Coast", "the observed broad area is kept")
  sim:advance(15)
  equal(sim.ns.Test.intel["Scout-Realm"].how, "unknown", "broad coastal name cannot perpetuate the last base position")
end)

test("Arathi area pins survive unlocated teammate combat on both maps", function()
  local sim = new("cata")
  sim.members, sim.units.party1 = 2, { name = "Friend", classID = 1 }
  local _, token = sim:enemy("Scout")
  sim:join(1461, 529, "Arathi Basin")
  for _ = 1, 20 do
    sim:advance(0.25)
    sim:combatLog("SWING_DAMAGE", "Friend", "Scout")
    equal(sim.ns.Test.intel["Scout-Realm"].how, "area", "unknown ally position does not displace a fresh area pin")
  end
  for _, canvas in ipairs({ sim.env.WorldMapFrame, sim.env.BattlefieldMapFrame }) do
    local pin
    for _, candidate in ipairs(canvas.pins) do
      if candidate.item.icon == "classicon-mage" then pin = candidate end
    end
    assert(pin, "enemy pin rendered without coordinate APIs")
    equal(pin.x, 0.3748, "pin uses Stables area anchor")
    equal(pin.y, 0.2917, "pin uses Stables area anchor")
    assert(pin.item.zone and pin.item.zone.radius > 0, "area estimates sit in a circle")
  end
  local sent = false
  for _, packet in ipairs(sim.sent) do
    if packet.prefix == "HighgroundI" and packet.message:find(",area,Stables", 1, true) then sent = true end
  end
  assert(sent, "located area sightings remain available to share")
  sim.units[token] = nil
  sim:advance(5)
  sim:combatLog("SWING_DAMAGE", "Friend", "Scout")
  sim:advance(0.5)
  equal(sim.ns.Test.intel["Scout-Realm"].how, "unknown", "unknown events cannot keep old positions fresh")
end)

test("local coordinates flow through observations, packets and both map canvases", function()
  local sim = new("cata")
  local _, token = sim:enemy("Scout", { position = { x = 0.3, y = 0.4 } })
  sim:join()
  sim:advance(2)
  local intel = assert(sim.ns.Test.intel["Scout-Realm"])
  equal(intel.how, "coords", "location source retained")
  equal(intel.x, 0.3, "coordinates retained")
  for _, canvas in ipairs({ sim.env.WorldMapFrame, sim.env.BattlefieldMapFrame }) do
    equal(#canvas.pins, 1, "one enemy pin rendered")
    equal(canvas.pins[1].x, 0.3, "pin mixin receives position")
    equal(canvas.pins[1].y, 0.4, "pin mixin receives position")
  end
  local sent = false
  for _, packet in ipairs(sim.sent) do
    if packet.prefix == "HighgroundI" and packet.message:find("Scout-Realm", 1, true) then sent = true end
  end
  assert(sent, "observation broadcast from actual queue")
  sim.units[token] = nil
  sim:advance(6)
  local early = sim.env.WorldMapFrame.pins[1].item
  equal(early.desat > 0, true, "old observations grey out")
  sim:advance(60)
  local late = sim.env.WorldMapFrame.pins[1].item
  equal(late.desat > early.desat and late.alpha < early.alpha and late.size < early.size, true,
    "older observations are greyer, fainter and smaller")
  sim:advance(60)
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
    if item.prefix == "HighgroundI" and item.message:find("Scout-Realm", 1, true) then packet = item end
  end
  assert(packet)
  receiver:event("CHAT_MSG_ADDON", packet.prefix, packet.message, packet.channel, "Friend-Realm")
  receiver:advance(0.5)
  equal(receiver.ns.Test.intel["Scout-Realm"].x, 0.3, "remote coordinates received")
  equal(receiver.env.WorldMapFrame.pins[1].x, 0.3, "remote sighting rendered")
  receiver:join(1460, 489, "Warsong Gulch")
  receiver:event("CHAT_MSG_ADDON", packet.prefix, packet.message, packet.channel, "Friend-Realm")
  equal(receiver.ns.Test.intel["Scout-Realm"], nil, "previous map packet ignored")
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

test("map pins update in place: a hovered enemy keeps its pin and its tooltip follows", function()
  local sim = new("cata")
  local _, scoutToken = sim:enemy("Scout", { position = { x = 0.3, y = 0.4 } })
  local otherUnit = sim:enemy("Other", { position = { x = 0.6, y = 0.4 } })
  sim:join(); sim:advance(2)
  local canvas, tip = sim.env.WorldMapFrame, sim.env.GameTooltip
  local function pinOf(key)
    for _, pin in ipairs(canvas.pins) do if pin.item.sortKey == key then return pin end end
  end
  local scout, other = assert(pinOf("Scout-Realm")), assert(pinOf("Other-Realm"))
  sim.units[scoutToken] = nil
  sim:advance(6)
  scout.scripts.OnEnter(scout)
  assert(tip:IsShown() and tip.owner == scout, "hovering shows the enemy's tooltip")
  local before = table.concat(tip.lines, " ")
  local hides = 0
  scout:HookScript("OnHide", function() hides = hides + 1 end)
  sim:advance(5)
  equal(pinOf("Scout-Realm"), scout, "the same pin")
  equal(pinOf("Other-Realm"), other, "each enemy keeps its own")
  equal(hides, 0, "never hidden while hovered")
  assert(tip:IsShown() and tip.owner == scout, "the tooltip stays")
  local after = table.concat(tip.lines, " ")
  assert(after ~= before and after:find("ago", 1, true), "and follows the sighting's age: " .. after)
  otherUnit.dead = true
  sim:combatLog("UNIT_DIED", "Me", "Other")
  sim:advance(1.5)
  equal(pinOf("Other-Realm"), nil, "a dead enemy's pin is released")
  equal(pinOf("Scout-Realm"), scout, "the other keeps its pin")
  sim:assertHealthy()
end)
