-- Nearby's shared open-world sightings (world/Share.lua) and their world
-- map pins (world/Map.lua), against each client's real TOC.
local t = dofile("../../tools/harness.lua")("world sightings")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local test = t.test
local function equal(actual, expected, why) t.equal(actual, expected, why or "values match") end

local HILLSBRAD, ARATHI = 1424, 1417

local function setup(client, build, saved)
  return new(client, saved, function(s, env)
    env.GetBuildInfo = function() return "x", "1", "Nov 18 2026", build end
    env.IsInGuild = function() return s.guild ~= false end
    -- The battleground runtime ties groups to battlegrounds; the open world has its own.
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

local function sent(sim, channel)
  local out = {}
  for _, m in ipairs(sim.sent) do
    if m.prefix == "HighgroundW" and (not channel or m.channel == channel) then out[#out + 1] = m end
  end
  return out
end

local function receive(sim, text, channel, sender)
  sim:event("CHAT_MSG_ADDON", "HighgroundW", text, channel or "PARTY", sender or "Ally-Realm")
end

local function row(sim, name)
  for _, r in ipairs(sim.ns.Nearby.rows or {}) do
    if r:IsShown() and r.who == name then return r end
  end
end

for _, case in ipairs({ { "cata", 40402 }, { "retail", 120100 }, { "retail", 16001 } }) do
  local client, build = unpack(case)

  test(build .. ": your sightings reach the group with your position, and the guild less often", function()
    local sim = setup(client, build)
    plate(sim, "Sneaky")
    sim:advance(4)
    local party = sent(sim, "PARTY")
    equal(#party, 1, "one group batch")
    local map, name, class, level, x, y, r = party[1].message:match("^1:(%d+):([^,]+),(%u+),(%d+),(%d+),(%d+),(%d+),")
    equal(tonumber(map), HILLSBRAD, "zone map")
    equal(name, "Sneaky-Realm", "realm-qualified name")
    equal(class, "ROGUE"); equal(level, "60")
    equal(x .. "," .. y, "5000,4000", "where you stood")
    equal(r, "60", "a nameplate can be 60 yards away")
    sim:advance(4)
    equal(#sent(sim, "PARTY"), 1, "unchanged enemies are not repeated")
    sim:advance(4)
    equal(#sent(sim, "GUILD"), 1, "the guild gets its own, slower batch")
    sim:event("NAME_PLATE_UNIT_ADDED", "nameplate1")
    sim:advance(11)
    equal(#sent(sim, "GUILD"), 1, "the guild hears of the same enemy at most every 30 seconds")
    sim:assertHealthy()
  end)

  test(build .. ": received sightings are listed with who saw them, without sound or journal entry", function()
    local sim = setup(client, build)
    local N = sim.ns.Nearby
    local sounds = #sim.sounds
    receive(sim, "1:" .. HILLSBRAD .. ":Ganker-Realm,ROGUE,60,4800,4100,28,5,Night Watch")
    N.Update()
    local e = N.seen.Ganker
    assert(e, "your realm's enemy keeps its short name")
    equal(e.by, "Ally-Realm"); equal(e.via, "group")
    equal(e.guild, "Night Watch"); equal(e.r, 28)
    local r = row(sim, "Ganker")
    assert(r, "listed in your zone")
    equal(r.sub.text, "Lv 60 · Seen by Ally")
    equal(#sim.sounds, sounds, "someone else's sighting makes no sound")
    assert(not sim.ns.NearbyHistory.Get("Ganker-Realm"), "not an encounter of yours")
    -- Another zone: kept for the map, not listed.
    receive(sim, "1:" .. ARATHI .. ":Faraway-Realm,MAGE,60,1000,1000,60,5,", "GUILD", "Officer-Realm")
    N.Update()
    assert(N.seen.Faraway, "kept")
    equal(N.seen.Faraway.via, "guild")
    assert(not row(sim, "Faraway"), "another zone's sighting is not listed")
    -- Seeing it yourself makes it yours: sound, journal, your position.
    plate(sim, "Ganker")
    sim:advance(0.2)
    equal(e.by, nil, "your own sighting replaces the shared one")
    assert(#sim.sounds > sounds, "the first sighting of your own sounds")
    assert(sim.ns.NearbyHistory.Get("Ganker-Realm"), "now in the journal")
    equal(r.sub.text, "Lv 60")
    sim:assertHealthy()
  end)

  test(build .. ": stale, older, malformed and own messages change nothing", function()
    local sim = setup(client, build)
    local N = sim.ns.Nearby
    plate(sim, "Seen")
    local mine = N.seen["Seen-Realm"] or N.seen.Seen
    local last = mine.last
    receive(sim, "1:" .. HILLSBRAD .. ":Seen-Realm,ROGUE,60,100,100,60,30,")
    equal(mine.by, nil, "an older shared sighting never replaces yours")
    equal(mine.last, last)
    receive(sim, "1:" .. HILLSBRAD .. ":Old-Realm,ROGUE,60,100,100,60,500,")
    equal(N.seen.Old, nil, "too old")
    receive(sim, "1:" .. HILLSBRAD .. ":Me-Realm,MAGE,60,100,100,60,1,", "PARTY", "Me-Realm")
    equal(N.seen.Me, nil, "your own messages are ignored")
    for _, bad in ipairs({ "2:1424:X-Realm,ROGUE,60,1,1,1,1,", "1:x:X-Realm,ROGUE,60,1,1,1,1,", "1:1424:X-Realm,rogue,60,1,1,1,1,",
      "1:1424:;;", "1:1424:X-Realm,ROGUE" }) do
      receive(sim, bad)
    end
    equal(N.seen.X, nil, "malformed messages are ignored")
    receive(sim, "1:" .. HILLSBRAD .. ":Whisper-Realm,ROGUE,60,1,1,1,1,", "WHISPER")
    equal(N.seen.Whisper, nil, "only the group and guild channels are read")
    sim:assertHealthy()
  end)

  test(build .. ": switches, instances and chat lockdown stop sharing", function()
    local sim = setup(client, build)
    local N = sim.ns.Nearby
    sim:command("nearby share guild off")
    plate(sim, "One")
    sim:advance(11)
    equal(#sent(sim, "GUILD"), 0, "guild sharing off sends nothing to the guild")
    equal(#sent(sim, "PARTY"), 1, "the group still gets it")
    receive(sim, "1:" .. HILLSBRAD .. ":Two-Realm,ROGUE,60,1,1,1,1,", "GUILD")
    equal(N.seen.Two, nil, "nor reads the guild's")
    sim:command("nearby share off")
    plate(sim, "Three", "nameplate2")
    sim:advance(4)
    equal(#sent(sim, "PARTY"), 1, "group sharing off")
    receive(sim, "1:" .. HILLSBRAD .. ":Four-Realm,ROGUE,60,1,1,1,1,")
    equal(N.seen.Four, nil)
    sim:command("nearby share on")
    sim.chatLockdown = true
    plate(sim, "Five", "nameplate3")
    sim:advance(4)
    if client ~= "cata" then
      equal(#sent(sim, "PARTY"), 1, "lockdown keeps the batch")
      sim.chatLockdown = false
      sim:advance(4)
    end
    equal(#sent(sim, "PARTY"), 2, "sent once the game allows it")
    sim.inBG = true
    sim:event("PLAYER_ENTERING_WORLD")
    receive(sim, "1:" .. HILLSBRAD .. ":Six-Realm,ROGUE,60,1,1,1,1,")
    equal(N.seen.Six, nil, "nothing is read inside an instance")
    sim:assertHealthy()
  end)

  test(build .. ": a raid's batches stay under the message limit and skip what others shared", function()
    local sim = setup(client, build)
    sim.raid = true
    for i = 1, 12 do plate(sim, "Enemy" .. string.rep("x", 8) .. i, "nameplate" .. i) end
    -- Another member reported Enemyxxxxxxxx1 as fresh as you.
    receive(sim, "1:" .. HILLSBRAD .. ":Enemyxxxxxxxx1-Realm,ROGUE,60,5000,4000,60,0,", "RAID")
    for _ = 1, 4 do
      if #sent(sim, "RAID") > 0 then break end
      sim:advance(1)
    end
    local raid = sent(sim, "RAID")
    equal(#raid, 2, "at most two messages a batch")
    local names = 0
    for _, m in ipairs(raid) do
      assert(#m.message <= 255)
      assert(not m.message:find("Enemyxxxxxxxx1-", 1, true), "already shared by someone else")
      for _ in m.message:gmatch("Enemyx+%d+%-") do names = names + 1 end
    end
    assert(names < 11, "two messages cannot carry all eleven")
    sim:advance(3)
    names = 0
    for _, m in ipairs(sent(sim, "RAID")) do
      for _ in m.message:gmatch("Enemyx+%d+%-") do names = names + 1 end
    end
    equal(names, 11, "the rest go out in the next batch, each once")
    sim:assertHealthy()
  end)

  test(build .. ": world map pins show your own and shared sightings, grouped and fading", function()
    local sim = setup(client, build)
    local W = sim.ns.WorldMap
    plate(sim, "Close")
    receive(sim, "1:" .. HILLSBRAD .. ":Near-Realm,MAGE,60,5010,4010,28,2,")
    receive(sim, "1:" .. HILLSBRAD .. ":Apart-Realm,PRIEST,60,2000,7000,28,2,")
    local items = W.Pins(HILLSBRAD)
    local pins, circles = {}, 0
    for _, item in ipairs(items) do
      if item.radius then circles = circles + 1 else pins[#pins + 1] = item end
    end
    equal(#pins, 2, "close sightings share a pin")
    local grouped
    for _, p in ipairs(pins) do if p.label == "×2" then grouped = p end end
    assert(grouped, "the shared pin counts its enemies")
    equal(#W.Pins(ARATHI), 0, "another zone's map has none of them")
    sim:command("nearby map off")
    equal(#W.Pins(HILLSBRAD), 0, "the switch hides them")
    sim:command("nearby map on")
    sim.inBG = true
    sim:event("PLAYER_ENTERING_WORLD")
    equal(#W.Pins(HILLSBRAD), 0, "nothing on instance maps")
    sim:assertHealthy()
  end)

  test(build .. ": the preview lists a shared sample and pins samples on any open map", function()
    local sim = setup(client, build)
    sim.grouped = false
    local N, W = sim.ns.Nearby, sim.ns.WorldMap
    sim:command("nearby test")
    assert(N.preview)
    local found
    for _, r in ipairs(N.rows) do
      if r:IsShown() and r.sub.text:find("Seen by Guildmate", 1, true) then found = true end
    end
    assert(found, "a sample row shows who shared it")
    assert(#W.Pins(ARATHI) > 0, "samples show on whatever map is open")
    sim:advance(5)
    equal(#sim.sent, 0, "samples are never sent")
    sim:command("nearby test")
    assert(not N.preview)
    equal(#W.Pins(ARATHI), 0, "stopping clears the samples")
    sim:assertHealthy()
  end)

  test(build .. ": /hg nearby reports sharing and the switches match the settings", function()
    local sim = setup(client, build)
    sim:command("nearby share guild off")
    equal(sim.ns.Core.On("nearbyShareGuild"), false)
    sim:command("nearby map off")
    equal(sim.ns.Core.On("nearbyMap"), false)
    local before = #sim.messages
    sim:command("nearby")
    local line
    for i = before + 1, #sim.messages do
      if sim.messages[i]:find("Shared sightings", 1, true) then line = sim.messages[i] end
    end
    assert(line, "status line")
    sim:command("nearby share guild on"); sim:command("nearby map on")
    assert(sim.ns.Core.On("nearbyShareGuild") and sim.ns.Core.On("nearbyMap"))
    sim:assertHealthy()
  end)
end

for _, build in ipairs({ 120100, 16001 }) do
  test(build .. ": everyone in the users channel gets coarse sightings only with the opt-in", function()
    local sim = setup("retail", build)
    local N = sim.ns.Nearby
    sim.ns.Peers.ChannelID = function() return 7 end
    sim.ns.Peers.CHANNEL = sim.ns.Peers.CHANNEL or "HighgroundUsersPvP"
    local function channel()
      local out = {}
      for _, m in ipairs(sim.sent) do
        if m.prefix == "HighgroundW" and m.channel == "CHANNEL" and m.message:find("^1:") then out[#out + 1] = m end
      end
      return out
    end
    plate(sim, "Sneaky")
    sim:advance(25)
    equal(#channel(), 0, "off by default")
    sim:command("nearby share world on")
    sim:event("NAME_PLATE_UNIT_ADDED", "nameplate1")
    sim:advance(25)
    local sentWorld = channel()
    equal(#sentWorld, 1)
    equal(sentWorld[1].target, 7)
    assert(sentWorld[1].message:find(",5250,4250,", 1, true), "the cell's centre, not where you stood: " .. sentWorld[1].message)
    local function hear(text, name)
      -- The channel's name can reset while the ruleset is unknown (Forever).
      sim.ns.Peers.CHANNEL = sim.ns.Peers.CHANNEL or "HighgroundUsersPvP"
      sim:event("CHAT_MSG_ADDON", "HighgroundW", text, "CHANNEL", "Scout-Realm", "", 0, 7, name or sim.ns.Peers.CHANNEL)
    end
    hear("1:" .. HILLSBRAD .. ":Rover-Realm,MAGE,60,2250,2250,100,3,")
    N.Update()
    local e = N.seen.Rover
    assert(e and e.via == "world", "everyone's sightings from your zone are listed")
    local r = row(sim, "Rover")
    equal(r and r.sub.text, "Lv 60 · Reported by Scout")
    hear("1:" .. ARATHI .. ":Elsewhere-Realm,MAGE,60,2250,2250,100,3,")
    equal(N.seen.Elsewhere, nil, "other zones are dropped")
    hear("1:" .. HILLSBRAD .. ":Trader-Realm,MAGE,60,2250,2250,100,3,", "Trade")
    equal(N.seen.Trader, nil, "only the users channel")
    sim:command("nearby share world off")
    hear("1:" .. HILLSBRAD .. ":Late-Realm,MAGE,60,2250,2250,100,3,")
    equal(N.seen.Late, nil, "nothing is read with the opt-in off")
    sim:assertHealthy()
  end)
end

t.finish("World sightings: " .. t.tests .. " scenarios, " .. t.failures .. " failures")
