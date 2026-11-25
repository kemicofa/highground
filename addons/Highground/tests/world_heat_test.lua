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
    equal(tip(busy), "2 enemies seen here\nLatest sighting: now")
    equal(busy.size, sim.ns.WorldHeat.BLOB / 20, "a blob wider than its cell")
    equal(busy.hit, 1 / 20, "only the cell takes the mouse")
    group(sim, "Near", 0.51, 0.41)
    group(sim, "Near", 0.2, 0.7, 30)
    equal(tip(heat(sim)[1]):match("^%d+"), "2", "a repeat or an older report adds nothing")
    sim:advance(1)
    group(sim, "Apart", 0.52, 0.42)
    cells = heat(sim)
    equal(#cells, 1, "an enemy moves with its latest report")
    equal(tip(cells[1]), "3 enemies seen here\nLatest sighting: now")
    equal(#heat(sim, HILLSBRAD), 1)
    local fresh = cells[1].heat
    -- Close leaves sight: an enemy still in view stays fresh.
    sim.units.nameplate1 = nil
    sim:event("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    sim:advance(200)
    assert(heat(sim)[1].heat < fresh, "older heat is fainter")
    sim:advance(101)
    equal(#heat(sim), 0, "gone after five minutes")
    sim:assertHealthy()
  end)

  test(build .. ": an enemy raid is full strength and the colour steps up", function()
    local sim = setup(client, build)
    group(sim, "Lone", 0.1, 0.1)
    for i = 1, 8 do group(sim, "Raider" .. i, 0.71, 0.61, 0) end
    local cells = heat(sim)
    local lone, raid = cells[1].x < 0.5 and cells[1] or cells[2], cells[1].x < 0.5 and cells[2] or cells[1]
    assert(raid.heat > 0.99, "eight enemies, the Enemy raid size: " .. raid.heat)
    equal(raid.ring, "mapHeatHigh")
    equal(lone.ring, "mapHeatLow")
    assert(lone.alpha < raid.alpha, "fewer enemies, fainter")
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
    equal(tip(cells[1]), "2 enemies seen here\nLatest sighting: 3s")
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
