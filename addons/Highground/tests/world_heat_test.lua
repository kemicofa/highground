-- Nearby's enemy heatmap (world/Heat.lua) and its map pins
-- (battlegrounds/map/Pins.lua), against each client's real TOC.
local t = dofile("../../tools/harness.lua")("world heat")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local test = t.test
local function equal(actual, expected, why) t.equal(actual, expected, why or "values match") end

local HILLSBRAD, ARATHI, KINGDOMS = 1424, 1417, 1415

local function setup(client, build)
  return new(client, nil, function(s, env)
    env.GetBuildInfo = function() return "x", "1", "Nov 18 2026", build end
    env.IsInGuild = function() return true end
    env.IsInGroup = function(category)
      if category ~= nil and category == env.LE_PARTY_CATEGORY_INSTANCE then return s.inBG end
      return s.grouped or s.inBG
    end
    s.mapID, s.mapName, s.area = HILLSBRAD, "Hillsbrad Foothills", "Tarren Mill"
    s.units.player.position = { x = 0.5, y = 0.4 }
    s.grouped = true
  end)
end

local function plate(sim, name, token)
  token = token or "nameplate1"
  sim.units[token] = { name = name, classID = 4, enemy = true, level = 60, realm = "" }
  sim:event("NAME_PLATE_UNIT_ADDED", token)
end

-- A group member's sighting at x, y (0-1) of `map`, `age` seconds old.
local function group(sim, name, x, y, age, map)
  sim:event("CHAT_MSG_ADDON", "HighgroundW", string.format("1:%d:%s-Realm,MAGE,60,%d,%d,28,%d,",
    map or HILLSBRAD, name, x * 10000, y * 10000, age or 1), "PARTY", "Ally-Realm")
end

local function heat(sim, map)
  local out = {}
  sim.ns.WorldHeat.Refresh()
  for _, item in ipairs(sim.ns.WorldHeat.Pins(map or HILLSBRAD)) do
    if item.heat then out[#out + 1] = item end
  end
  table.sort(out, function(a, b) return a.sortKey < b.sortKey end)
  return out
end

local function tip(item)
  local lines = {}
  item.tooltip({ AddLine = function(_, line) lines[#lines + 1] = line end })
  return table.concat(lines, "\n")
end

for _, case in ipairs({ { "cata", 40402 }, { "retail", 120100 }, { "retail", 16001 } }) do
  local client, build = unpack(case)

  test(build .. ": heat counts each enemy once at its latest spot and fades out", function()
    local sim = setup(client, build)
    plate(sim, "Close")
    group(sim, "Near", 0.51, 0.41)
    group(sim, "Apart", 0.2, 0.7)
    local cells = heat(sim)
    equal(#cells, 2, "one cell for the two close enemies, one apart")
    local busy = cells[1].x == 0.525 and cells[1] or cells[2]
    equal(busy.x, 0.525); equal(busy.y, 0.425, "the cell's centre")
    equal(tip(busy), "2 enemies seen here\nEnemies seen, no kills yet\nLatest sighting: now")
    equal(busy.size, sim.ns.WorldHeat.BLOB / 20, "a blob wider than its cell")
    equal(busy.hit, 1 / 20, "only the cell takes the mouse")
    group(sim, "Near", 0.51, 0.41)
    group(sim, "Near", 0.2, 0.7, 30)
    equal(tip(heat(sim)[1]):match("^%d+"), "2", "a repeat or an older report adds nothing")
    sim:advance(1)
    group(sim, "Apart", 0.52, 0.42)
    cells = heat(sim)
    equal(#cells, 1, "an enemy moves with its latest report")
    equal(tip(cells[1]), "3 enemies seen here\nEnemies seen, no kills yet\nLatest sighting: now")
    equal(#heat(sim, HILLSBRAD), 1)
    local fresh = cells[1].heat
    -- Close leaves sight: an enemy still in view stays fresh.
    sim.units.nameplate1 = nil
    sim:event("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    sim:advance(1800)
    assert(heat(sim)[1].heat < fresh, "older heat is fainter")
    sim:advance(1801)
    equal(#heat(sim), 0, "gone after an hour")
    sim:assertHealthy()
  end)

  test(build .. ": an enemy raid is full strength, in the enemy faction's colour", function()
    local sim = setup(client, build)
    group(sim, "Lone", 0.1, 0.1)
    for i = 1, 8 do group(sim, "Raider" .. i, 0.71, 0.61, 0) end
    local cells = heat(sim)
    local lone, raid = cells[1].x < 0.5 and cells[1] or cells[2], cells[1].x < 0.5 and cells[2] or cells[1]
    assert(raid.heat > 0.99, "eight enemies, the Enemy raid size: " .. raid.heat)
    equal(raid.ring, "mapHeatHorde", "an Alliance player's enemies are Horde red")
    equal(lone.ring, "mapHeatHorde")
    assert(lone.alpha < raid.alpha, "fewer enemies, fainter")
    sim.faction = 0
    equal(heat(sim)[1].ring, "mapHeatAlliance", "a Horde player's enemies are Alliance blue")
    sim.faction = 1
    sim.ns.Core.SetTuning("option", "nearbyRaidSize", 16)
    local half = heat(sim)[cells[1] == raid and 1 or 2].heat
    assert(half > 0.49 and half <= 0.5, "full strength follows Enemy raid: " .. half)
    sim:assertHealthy()
  end)

  test(build .. ": the continent map gathers its zones' heat", function()
    local sim = setup(client, build)
    sim.env.C_Map.GetMapRectOnMap = function(from, to)
      if from == HILLSBRAD and to == KINGDOMS then return 0.4, 0.5, 0.3, 0.4 end
    end
    group(sim, "Near", 0.51, 0.41)
    local cells = heat(sim, KINGDOMS)
    equal(#cells, 1)
    equal(cells[1].x, 0.475); equal(cells[1].y, 0.325, "Hillsbrad's spot on the continent")
    equal(#heat(sim, ARATHI), 0, "another zone's map has none of it")
    sim:assertHealthy()
  end)

  test(build .. ": switches, instances, the preview and clear", function()
    local sim = setup(client, build)
    group(sim, "Near", 0.51, 0.41)
    sim:command("nearby heat off")
    assert(not sim.ns.Core.On("nearbyHeat"))
    equal(#heat(sim), 0, "the switch hides heat")
    group(sim, "Later", 0.2, 0.2)
    sim:command("nearby heat on")
    equal(#heat(sim), 1, "nothing was gathered while off")
    sim:command("nearby map off")
    equal(#heat(sim), 0, "World map sightings hides heat too")
    sim:command("nearby map on")
    sim.inBG = true
    sim:event("PLAYER_ENTERING_WORLD")
    equal(#heat(sim), 0, "nothing on instance maps")
    sim.inBG = false
    sim:event("PLAYER_ENTERING_WORLD")
    sim.grouped = false
    sim:command("nearby test")
    local sample = heat(sim, ARATHI)
    assert(#sample > 2, "samples show on whatever map is open")
    local top = 0
    for _, c in ipairs(sample) do top = math.max(top, c.heat) end
    equal(top, 1, "the sample has a raid")
    sim:command("nearby test")
    equal(#heat(sim, ARATHI), 0, "stopping clears the samples")
    equal(#heat(sim), 1, "real heat is untouched")
    sim:command("nearby clear")
    equal(#heat(sim), 0, "clearing sightings clears heat")
    sim:assertHealthy()
  end)

  test(build .. ": the open map draws heat as soft cells under the enemy pins", function()
    local sim = setup(client, build)
    local map = sim.env.WorldMapFrame
    map:SetMapID(HILLSBRAD)
    group(sim, "Near", 0.51, 0.41)
    sim:advance(1.1)
    local blobs, enemies = {}, 0
    for _, pin in ipairs(map.pins) do
      if pin.template == "HighgroundHeatPinTemplate" then blobs[#blobs + 1] = pin
      elseif pin.template == "HighgroundPinTemplate" then enemies = enemies + 1 end
    end
    equal(#blobs, 1, "one heat pin")
    equal(enemies, 1, "the enemy keeps its own pin")
    local blob = blobs[1]
    equal(blob.Blob.texture, sim.ns.Core.HEAT_BLOB)
    local w, h = blob:GetWidth(), blob:GetHeight()
    equal(math.floor(w + 0.5), 150); equal(math.floor(h + 0.5), 100, "three cells of a 1000 x 667 map")
    local left, right, top, bottom = blob:GetHitRectInsets()
    equal(math.floor(left + 0.5), 50); equal(right, left)
    equal(math.floor(top + 0.5), 33); equal(bottom, top)
    blob:OnMouseEnter()
    equal(sim.env.GameTooltip.lines and sim.env.GameTooltip.lines[1], "1 enemy seen here")
    blob:OnMouseLeave()
    sim:command("nearby heat off")
    sim:advance(1.1)
    for _, pin in ipairs(map.pins) do
      assert(pin.template ~= "HighgroundHeatPinTemplate", "the switch removes the heat pin")
    end
    sim:assertHealthy()
  end)
end

-- A group member's kill report: `killer` killed `victim` at x, y.
local function fight(sim, killer, victim, x, y, channel, sender)
  sim:event("CHAT_MSG_ADDON", "HighgroundW", string.format("1K:%d:%s-Realm,%s-Realm,1,%d,%d,", HILLSBRAD,
    killer, victim, x * 10000, y * 10000), channel or "PARTY", (sender or "Ally") .. "-Realm")
end

local function badge(sim, map)
  sim.ns.WorldHeat.Refresh()
  for _, item in ipairs(sim.ns.WorldHeat.Pins(map or HILLSBRAD)) do
    if item.sortKey and item.sortKey:find("^fight:") then return item end
  end
end

for _, case in ipairs({ { "cata", 40402 }, { "retail", 120100 }, { "retail", 16001 } }) do
  local client, build = unpack(case)

  test(build .. ": kills mark which side is winning a square", function()
    local sim = setup(client, build)
    local H, crests = sim.ns.WorldHeat, sim.ns.Timers.FACTION_ICON
    group(sim, "Near", 0.51, 0.41)
    equal(badge(sim), nil, "enemies only: no badge")
    sim.ns.WorldFeed.Local("Ganker-Realm", "killedThem")
    fight(sim, "Ally", "Bob", 0.51, 0.41)
    fight(sim, "Ally", "Bob", 0.51, 0.41, "GUILD")
    fight(sim, "Evil", "Ally", 0.52, 0.42)
    local b = badge(sim)
    assert(b, "a badge where kills happened")
    equal(b.label, "2–1", "your side's kills, then the enemy's; one fight reported twice counts once")
    equal(b.icon, crests.A, "an Alliance player's side leads")
    equal(b.ring, "mapHeatAlliance")
    equal(heat(sim)[1].ring, "mapHeatAlliance", "the square takes your colour where your side killed more")
    equal(tip(b), "1 enemy seen here\nKills here: your side 2, enemy 1\nYour side is winning here\nLatest sighting: now")
    sim.ns.WorldFeed.Local("Ganker-Realm", "killedMe")
    sim:advance(11)
    fight(sim, "Evil", "Ally", 0.52, 0.42)
    b = badge(sim)
    equal(b.label, "2–3"); equal(b.icon, crests.H); equal(b.ring, "mapHeatHorde")
    equal(heat(sim)[1].ring, "mapHeatHorde")
    assert(tip(b):find("The enemy is winning here", 1, true))
    H.Kill("Old-Realm", "Me-Realm", HILLSBRAD, 0.1, 0.1, sim.now - 3700, false)
    equal(#heat(sim), 1, "nothing older than an hour")
    sim:command("nearby clear")
    equal(badge(sim), nil, "clearing sightings clears kills")
    sim:assertHealthy()
  end)

  test(build .. ": an open map reuses its heat until the data changes", function()
    local sim = setup(client, build)
    local H = sim.ns.WorldHeat
    group(sim, "Near", 0.51, 0.41)
    H.Refresh()
    local first = H.Pins(HILLSBRAD)
    local builds = H.stats.builds
    local item = first[1]
    H.Pins(HILLSBRAD)
    equal(H.stats.builds, builds, "no rebuild while nothing changed")
    group(sim, "Apart", 0.2, 0.7)
    equal(#H.Pins(HILLSBRAD), 1, "a change waits for the rebuild interval")
    sim:advance(2.1)
    local second = H.Pins(HILLSBRAD)
    equal(#second, 2, "then shows")
    assert(rawequal(second, first), "in the same list")
    local reused
    for _, it in ipairs(second) do if rawequal(it, item) then reused = true end end
    assert(reused, "a square keeps its item between builds")
    builds = H.stats.builds
    sim:advance(5); H.Pins(HILLSBRAD)
    equal(H.stats.builds, builds, "unchanged data is reused")
    sim:advance(6); H.Pins(HILLSBRAD)
    equal(H.stats.builds, builds + 1, "and rebuilt now and then so heat fades")
    builds = H.stats.builds
    sim:advance(60)
    assert(H.stats.builds - builds <= 7, "an idle open map rebuilds at most every 10 seconds: " .. H.stats.builds - builds)
    sim.env.WorldMapFrame:Hide(); sim.env.BattlefieldMapFrame:Hide()
    sim:advance(1.1)
    builds = H.stats.builds
    H.Pins(HILLSBRAD)
    equal(H.stats.builds, builds + 1, "closed maps release their items: the next open rebuilds")
    sim:assertHealthy()
  end)
end

-- Everyone's kills from the users channel feed the heatmap, not the feed list.
for _, build in ipairs({ 120100, 16001 }) do
  test(build .. ": kills reach everyone as a coarse square and add to their heatmap", function()
    local sim = setup("retail", build)
    local F = sim.ns.WorldFeed
    sim.ns.Peers.ChannelID = function() return 7 end
    sim.ns.Peers.CHANNEL = sim.ns.Peers.CHANNEL or "HighgroundUsersPvP"
    F.Local("Ganker-Realm", "killedThem")
    local out
    for _, m in ipairs(sim.sent) do
      if m.channel == "CHANNEL" and m.message:find("^1K:") then out = m end
    end
    equal(out and out.message, "1K:1424:Me-Realm,Ganker-Realm,0,5250,4250,Tarren Mill", "the square's centre, not your spot")
    local listed = #F.list
    sim:event("CHAT_MSG_ADDON", "HighgroundW", "1K:" .. ARATHI .. ":Evil-Realm,Scout-Realm,2,2250,2250,", "CHANNEL",
      "Scout-Realm", "", 0, 7, sim.ns.Peers.CHANNEL)
    equal(#F.list, listed, "not in the kill feed")
    local b = badge(sim, ARATHI)
    equal(b and b.label, "0–1", "the enemy's kill, in another zone")
    sim:assertHealthy()
  end)
end

test("Nearby settings show the Enemy heatmap switch under World map sightings", function()
  local sim = setup("retail", 16001)
  sim:command("config nearby")
  local box
  for _, cb in ipairs(sim.ns.Options.featureBoxes or {}) do
    if cb.key == "nearbyHeat" then box = cb end
  end
  assert(box and box:IsVisible(), "a visible switch")
  equal(box.option.parent, "nearbyMap", "nested under World map sightings")
  equal(box.label:GetText(), "Enemy heatmap")
  assert(box:GetChecked(), "on by default")
  box:Click()
  assert(not sim.ns.Core.On("nearbyHeat"), "clicking turns heat off, as /hg nearby heat off")
  box:Click()
  assert(sim.ns.Core.On("nearbyHeat"), "and on again")
  sim:assertHealthy()
end)

test("a busy realm keeps the newest sightings up to the cap", function()
  local sim = setup("retail", 16001)
  local H = sim.ns.WorldHeat
  for i = 1, H.MAX + 50 do
    sim:advance(0.1)
    H.Add("Enemy" .. i, HILLSBRAD, 0.51, 0.41, sim.now)
  end
  local kept = tonumber(tip(heat(sim)[1]):match("^(%d+)"))
  assert(kept <= H.MAX and kept >= H.MAX * 0.85, "at most the cap, dropping the oldest in batches: " .. kept)
  H.Add("Enemy1", HILLSBRAD, 0.11, 0.11, sim.now)
  equal(#heat(sim), 2, "a dropped enemy seen again comes back")
  sim:assertHealthy()
end)

-- Everyone's squares from other zones add heat only; Cataclysm has no users channel.
for _, build in ipairs({ 120100, 16001 }) do
  test(build .. ": everyone's sightings from any zone add heat, not rows", function()
    local sim = setup("retail", build)
    local N = sim.ns.Nearby
    sim.ns.Peers.ChannelID = function() return 7 end
    local function hear(text)
      sim.ns.Peers.CHANNEL = sim.ns.Peers.CHANNEL or "HighgroundUsersPvP"
      sim:event("CHAT_MSG_ADDON", "HighgroundW", text, "CHANNEL", "Scout-Realm", "", 0, 7, sim.ns.Peers.CHANNEL)
    end
    hear("1:" .. ARATHI .. ":Far-Realm,MAGE,60,2250,2250,100,3,;Other-Realm,PRIEST,60,2250,2250,100,3,")
    equal(N.seen.Far, nil, "not listed")
    local cells = heat(sim, ARATHI)
    equal(#cells, 1)
    equal(cells[1].x, 0.225); equal(cells[1].y, 0.225)
    equal(tip(cells[1]), "2 enemies seen here\nEnemies seen, no kills yet\nLatest sighting: 3s")
    hear("1:" .. HILLSBRAD .. ":Here-Realm,MAGE,60,5250,4250,100,3,")
    assert(N.seen.Here, "your zone's are listed as before")
    equal(#heat(sim), 1, "and add heat")
    sim:command("nearby heat off")
    hear("1:" .. ARATHI .. ":Gone-Realm,MAGE,60,7250,7250,100,3,")
    sim:command("nearby heat on")
    equal(#heat(sim, ARATHI), 1, "other zones are skipped while heat is off")
    sim:assertHealthy()
  end)
end

t.finish("World heat: " .. t.tests .. " scenarios, " .. t.failures .. " failures")
