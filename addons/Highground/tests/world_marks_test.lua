-- Map marks (world/Marks.lua) and World PvP calls (world/Calls.lua).
local t = dofile("../../tools/harness.lua")("map marks and calls")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local test = t.test
local function equal(actual, expected, why) t.equal(actual, expected, why or "values match") end

local HILLSBRAD, ARATHI, CONTINENT = 1424, 1417, 1415

local function setup(client, build)
  return new(client, nil, function(s, env)
    env.GetBuildInfo = function() return "x", "1", "Nov 18 2026", build end
    env.IsInGuild = function() return true end
    env.IsInGroup = function(category)
      if category ~= nil and category == env.LE_PARTY_CATEGORY_INSTANCE then return s.inBG end
      return s.grouped or s.inBG
    end
    env.IsAltKeyDown = function() return true end
    s.mapID, s.mapName, s.area = HILLSBRAD, "Hillsbrad Foothills", "Tarren Mill"
    s.units.player.position = { x = 0.5, y = 0.4 }
    s.grouped = true
  end)
end

local function sent(sim, channel, start)
  local out = {}
  for _, m in ipairs(sim.sent) do
    if m.prefix == "HighgroundW" and m.channel == channel and m.message:sub(1, #start) == start then out[#out + 1] = m end
  end
  return out
end

local function said(sim, text, from)
  for i = (from or 0) + 1, #sim.messages do
    if sim.messages[i]:find(text, 1, true) then return sim.messages[i] end
  end
end

local function receive(sim, text, channel, sender)
  sim:event("CHAT_MSG_ADDON", "HighgroundW", text, channel or "GUILD", sender or "Officer-Realm")
  sim:advance(0.2)
end

local function pins(sim, mapID, kind)
  local out = {}
  for _, p in ipairs(sim.ns.WorldMarks.Pins(mapID)) do
    if not kind or p.sortKey:find(":" .. kind .. ":", 1, true) then out[#out + 1] = p end
  end
  return out
end

for _, case in ipairs({ { "cata", 40402 }, { "retail", 120100 }, { "retail", 16001 } }) do
  local client, build = unpack(case)

  test(build .. ": marks at your position and on a zone map go to group and guild and expire", function()
    local sim = setup(client, build)
    local M = sim.ns.WorldMarks
    sim:command("nearby mark enemies")
    assert(said(sim, "Marked: Enemies here."))
    local party = sent(sim, "PARTY", "1M:")
    equal(#party, 1); equal(#sent(sim, "GUILD", "1M:"), 1)
    local id = party[1].message:match("^1M:1424:(%d+),enemies,5000,4000,0,600,Tarren Mill$")
    assert(id, party[1].message)
    equal(#pins(sim, HILLSBRAD, "enemies"), 1, "your mark is on the map")
    -- A zone map spot, through the chooser.
    assert(M.Choose(HILLSBRAD, 0.3, 0.7))
    local chooser = M.chooser
    assert(chooser:IsShown())
    chooser.buttons[3].scripts.OnClick(chooser.buttons[3])
    assert(not chooser:IsShown())
    local help = pins(sim, HILLSBRAD, "help")
    equal(#help, 1); equal(help[1].x, 0.3); equal(help[1].y, 0.7)
    -- Continent maps can't take marks.
    local info = sim.env.C_Map.GetMapInfo
    sim.env.C_Map.GetMapInfo = function(mapID) if mapID == CONTINENT then return { mapType = 2 } end return info(mapID) end
    local ok, why = M.Choose(CONTINENT, 0.5, 0.5)
    assert(not ok and why:find("zone map", 1, true))
    -- Sent again for latecomers, gone after their time.
    sim:advance(121)
    equal(#sent(sim, "PARTY", "1M:"), 4, "both marks sent again after two minutes")
    sim:advance(200)
    equal(#pins(sim, HILLSBRAD, "help"), 0, "help marks last five minutes")
    equal(#pins(sim, HILLSBRAD, "enemies"), 1)
    sim:command("nearby mark clear")
    assert(said(sim, "Map marks cleared: 1."))
    equal(#sent(sim, "PARTY", "1M:1424:" .. id .. ",X"), 1, "removal is shared")
    equal(#pins(sim, HILLSBRAD), 0)
    sim:assertHealthy()
  end)

  test(build .. ": received marks pin, call in your zone, merge and can be removed", function()
    local sim = setup(client, build)
    local start = #sim.messages
    receive(sim, "1M:1424:12,enemies,4700,4300,30,600,Southshore")
    assert(said(sim, "Enemies here · Hillsbrad Foothills (Southshore) · marked by Officer", start), "a call in your zone")
    receive(sim, "1M:1424:3,enemies,4710,4310,10,600,", "PARTY", "Ally-Realm")
    local p = pins(sim, HILLSBRAD, "enemies")
    equal(#p, 1, "close marks of one type share a pin")
    equal(p[1].label, "Enemies here ×2")
    start = #sim.messages
    receive(sim, "1M:1417:4,ganker,1000,1000,0,900,")
    assert(not said(sim, "Ganker ·", start), "another zone's mark is only pinned")
    equal(#pins(sim, ARATHI, "ganker"), 1)
    receive(sim, "1M:1424:12,X")
    equal(pins(sim, HILLSBRAD, "enemies")[1].label, "Enemies here", "the author removed theirs")
    for _, bad in ipairs({ "1M:1424:5,boss,1,1,0,600,", "1M:1424:6,help,20000,1,0,600,", "1M:1424:7,help,1,1,900,600,", "1M:x:8,help,1,1,0,600," }) do
      receive(sim, bad)
    end
    equal(#pins(sim, HILLSBRAD, "help"), 0, "invalid marks are ignored")
    receive(sim, "1M:1424:9,help,1,1,0,600,", "PARTY", "Me-Realm")
    equal(#pins(sim, HILLSBRAD, "help"), 0, "your own messages are ignored")
    sim:command("nearby marks off")
    equal(#pins(sim, HILLSBRAD), 0, "the switch hides marks")
    receive(sim, "1M:1424:10,help,4000,4000,0,300,")
    sim:command("nearby marks on")
    equal(#pins(sim, HILLSBRAD, "help"), 0, "and reads none")
    sim:assertHealthy()
  end)

  test(build .. ": map visibility does not lock the mark sharing preference", function()
    local sim = setup(client, build)
    local C, O, M = sim.ns.Core, sim.ns.Options, sim.ns.WorldMarks
    sim.ns.Hub.Open("nearby")
    local toggle
    for _, box in ipairs(O.featureBoxes) do if box.key == "nearbyMarks" then toggle = box end end
    assert(toggle and toggle:IsEnabled())
    sim:command("nearby map off")
    assert(toggle:IsEnabled(), "marks stay configurable when the map is hidden")
    sim:command("nearby mark enemies")
    equal(#sent(sim, "PARTY", "1M:"), 1, "the mark still reaches teammates")
    equal(#pins(sim, HILLSBRAD), 0, "map visibility still controls rendering")
    toggle.scripts.OnClick(toggle)
    equal(C.db.nearbyMarks, false, "the visible switch saves the setting")
    local mark = M.Here("help")
    equal(mark, nil, "disabled marks cannot be placed")
    sim:command("nearby marks on")
    assert(toggle:GetChecked(), "the command refreshes the same control")
    sim:command("nearby map on")
    equal(#pins(sim, HILLSBRAD), 1, "showing the map restores the retained mark")
    sim:assertHealthy()
  end)

  test(build .. ": known gankers and gathering enemy raids are World PvP calls", function()
    local sim = setup(client, build)
    local N, H = sim.ns.Nearby, sim.ns.NearbyHistory
    N.Note("Ganker-Realm", "ROGUE", 60)
    H.Get("Ganker-Realm").killedMe = 3
    sim:advance(400)
    local start = #sim.messages
    receive(sim, "1:1424:Ganker-Realm,ROGUE,60,4000,4000,60,0,", "PARTY", "Ally-Realm")
    assert(said(sim, "Known ganker: Ganker (your deaths to them: 3) · seen by Ally", start))
    start = #sim.messages
    receive(sim, "1:1424:Ganker-Realm,ROGUE,60,4100,4000,60,0,", "GUILD", "Officer-Realm")
    assert(not said(sim, "Known ganker", start), "five minutes between calls for one enemy")
    H.Get("Ganker-Realm").killedMe = 2
    sim:advance(400)
    start = #sim.messages
    receive(sim, "1:1424:Ganker-Realm,ROGUE,60,4000,4000,60,0,", "PARTY", "Ally-Realm")
    assert(not said(sim, "Known ganker", start), "below the setting")
    -- Eight enemies close together within a minute.
    local batch = {}
    for i = 1, 8 do batch[i] = string.format("Raider%d-Realm,WARRIOR,60,%d,%d,60,1,", i, 6000 + i * 20, 6000 + i * 15) end
    start = #sim.messages
    receive(sim, "1:1424:" .. table.concat(batch, ";", 1, 4), "RAID", "Ally-Realm")
    receive(sim, "1:1424:" .. table.concat(batch, ";", 5, 8), "RAID", "Other-Realm")
    sim:advance(6)
    assert(said(sim, "Enemy raid in Hillsbrad Foothills: enemies seen together: 8", start))
    start = #sim.messages
    sim:advance(30)
    assert(not said(sim, "Enemy raid", start), "one call per raid every five minutes")
    sim:command("nearby calls off")
    sim:advance(400)
    receive(sim, "1M:1424:2,help,4000,4000,0,300,")
    assert(not said(sim, "Help needed", start), "the switch silences calls")
    sim:assertHealthy()
  end)

  test(build .. ": the preview pins sample marks; the key binding marks your position", function()
    local sim = setup(client, build)
    sim.grouped = false
    sim:command("nearby test")
    local p = pins(sim, HILLSBRAD, "enemies")
    equal(#p, 1); equal(p[1].label, "Enemies here ×2")
    assert(math.abs(p[1].x - 0.52) < 0.01 and math.abs(p[1].y - 0.43) < 0.01, "around you: " .. p[1].x .. "," .. p[1].y)
    equal(#pins(sim, HILLSBRAD, "help"), 1)
    equal(#pins(sim, ARATHI), 0, "not on another zone's map")
    sim:command("nearby test")
    equal(#pins(sim, HILLSBRAD), 0)
    sim.env.Highground_WorldMark()
    equal(#pins(sim, HILLSBRAD, "enemies"), 1)
    assert(sim.env.BINDING_NAME_HIGHGROUND_WORLD_MARK, "the binding has a name")
    sim.inBG = true
    sim:event("PLAYER_ENTERING_WORLD")
    local start = #sim.messages
    sim:command("nearby mark help")
    assert(said(sim, "open world", start), "no marks inside instances")
    sim:assertHealthy()
  end)

  if client ~= "cata" then
    test(build .. ": marks reach everyone only with the opt-in", function()
      local sim = setup(client, build)
      sim.ns.Peers.ChannelID = function() return 7 end
      sim.ns.Peers.CHANNEL = sim.ns.Peers.CHANNEL or "HighgroundUsersPvP"
      sim:command("nearby mark ganker")
      equal(#sent(sim, "CHANNEL", "1M:"), 0, "off by default")
      sim:command("nearby marks world on")
      sim:command("nearby mark help")
      equal(#sent(sim, "CHANNEL", "1M:"), 1)
      sim:event("CHAT_MSG_ADDON", "HighgroundW", "1M:1424:2,enemies,4000,4000,0,600,", "CHANNEL", "Scout-Realm", "", 0, 7, sim.ns.Peers.CHANNEL)
      equal(#pins(sim, HILLSBRAD, "enemies"), 1, "everyone's marks with the opt-in")
      sim:event("CHAT_MSG_ADDON", "HighgroundW", "1M:1424:3,ganker,2000,2000,0,600,", "CHANNEL", "Scout-Realm", "", 0, 7, "Trade")
      equal(#pins(sim, HILLSBRAD, "ganker"), 1, "not from another channel (only yours)")
      sim:assertHealthy()
    end)
  end
end

t.finish("Map marks and calls: " .. t.tests .. " scenarios, " .. t.failures .. " failures")
