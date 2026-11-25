-- Kill feed (world/Feed.lua) and World activity (world/Activity.lua).
local t = dofile("../../tools/harness.lua")("world activity")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local test = t.test
local function equal(actual, expected, why) t.equal(actual, expected, why or "values match") end

local HILLSBRAD, ARATHI = 1424, 1417

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

local function sent(sim, channel)
  local out = {}
  for _, m in ipairs(sim.sent) do
    if m.prefix == "HighgroundW" and m.channel == channel and m.message:find("^1K:") then out[#out + 1] = m end
  end
  return out
end

local function receive(sim, text, channel, sender)
  sim:event("CHAT_MSG_ADDON", "HighgroundW", text, channel or "GUILD", sender or "Officer-Realm")
end

for _, case in ipairs({ { "cata", 40402 }, { "retail", 120100 }, { "retail", 16001 } }) do
  local client, build = unpack(case)

  test(build .. ": your kills and deaths go to group and guild; theirs join the feed once", function()
    local sim = setup(client, build)
    local F = sim.ns.WorldFeed
    F.Local("Ganker-Realm", "killedThem")
    local party = sent(sim, "PARTY")
    equal(#party, 1); equal(#sent(sim, "GUILD"), 1)
    equal(party[1].message, "1K:1424:Me-Realm,Ganker-Realm,0,Tarren Mill")
    F.Local("Ganker-Realm", "killedMe")
    equal(sent(sim, "PARTY")[2].message, "1K:1424:Ganker-Realm,Me-Realm,0,Tarren Mill")
    equal(#F.list, 2)
    receive(sim, "1K:1424:Officer-Realm,Bob-Realm,5,Southshore")
    receive(sim, "1K:1424:Officer-Realm,Bob-Realm,6,Southshore", "PARTY", "Officer-Realm")
    equal(#F.list, 3, "one fight reported twice is listed once")
    receive(sim, "1K:1424:Stranger-Realm,Bob-Realm,1,", "GUILD", "Officer-Realm")
    equal(#F.list, 3, "the sender must be the killer or the victim")
    receive(sim, "1K:1424:Officer-Realm,Bob-Realm,1,", "WHISPER", "Officer-Realm")
    equal(#F.list, 3, "only the group and guild channels")
    sim:command("nearby feed off")
    F.Local("Other-Realm", "killedThem")
    equal(#sent(sim, "PARTY"), 2, "the switch stops sending")
    equal(#F.list, 4, "your own kills are still listed")
    receive(sim, "1K:1424:Ally-Realm,Bob-Realm,1,", "PARTY", "Ally-Realm")
    equal(#F.list, 4, "and reading")
    sim:assertHealthy()
  end)

  test(build .. ": World activity lists zones by recent enemies, marks and kills", function()
    local sim = setup(client, build)
    local A, N = sim.ns.WorldActivity, sim.ns.Nearby
    sim.units.nameplate1 = { name = "Rogueone", classID = 4, enemy = true, level = 60, realm = "" }
    sim:event("NAME_PLATE_UNIT_ADDED", "nameplate1")
    receive(sim, "1:" .. HILLSBRAD .. ":Magetwo-Realm,MAGE,60,4000,4000,60,30,Night Watch")
    receive(sim, "1:" .. ARATHI .. ":Faraway-Realm,WARRIOR,60,1000,1000,60,100,")
    receive(sim, "1M:" .. HILLSBRAD .. ":4,help,4000,4000,0,300,")
    sim.ns.WorldFeed.Local("Rogueone", "killedThem")
    local entries = A.Entries()
    equal(#entries, 2)
    local hills = entries[1]
    equal(hills.mapID, HILLSBRAD, "the most recent zone first")
    equal(hills.summary, "Enemies 2 · last minute 2 · marks 1 · kills 1")
    local classes = hills.detail:lower():match("classes: ([^\n]+)")
    assert(classes and classes:find("mage 1", 1, true) and classes:find("rogue 1", 1, true), hills.detail)
    assert(hills.detail:find("Guilds: <Night Watch> 1", 1, true), hills.detail)
    assert(hills.detail:find("Marks: Help needed 1", 1, true))
    assert(hills.detail:find("You killed Rogueone", 1, true), hills.detail)
    -- A bounty on the victim shows its reward.
    if sim.ns.Bounty then
      local find, enabled, gold = sim.ns.Bounty.Find, sim.ns.Bounty.Enabled, sim.ns.Bounty.GoldText
      sim.ns.Bounty.Enabled, sim.ns.Bounty.Find = function() return true end, function(name) return name == "Rogueone-Realm" and {} or nil end
      sim.ns.Bounty.GoldText = function() return "500g" end
      assert(A.Entries()[1].detail:find("You killed Rogueone · Tarren Mill · now · Bounty: 500g", 1, true), A.Entries()[1].detail)
      sim.ns.Bounty.Find, sim.ns.Bounty.Enabled, sim.ns.Bounty.GoldText = find, enabled, gold
    end
    sim.ns.Options.OpenTool("activity")
    local w = A.win
    assert(w:IsShown(), "opens as a tool")
    equal(#w.items, 2)
    sim:command("activity")
    assert(not w:IsShown(), "/hg activity toggles it")
    sim:command("activity")
    assert(w:IsShown())
    sim:advance(301)
    w:Refresh()
    equal(#w.items, 1, "forgotten enemies leave; the kill keeps its zone")
    sim:assertHealthy()
  end)

  test(build .. ": the guide's sample zones leave live data alone", function()
    local sim = setup(client, build)
    local A = sim.ns.WorldActivity
    local samples = A.Samples()
    equal(#samples, 2)
    assert(samples[1].detail:find("Guildmate killed Sneakypete", 1, true))
    local provider = { entries = A.Samples }
    local w = A.Build(provider)
    w:Open()
    equal(#w.items, 2)
    equal(#A.Entries(), 0, "no live zones were created")
    sim:assertHealthy()
  end)
end

for _, case in ipairs({ { "cata", 40402 }, { "retail", 120100 }, { "retail", 16001 } }) do
  test(case[2] .. ": /hg activity test and its Previews button show sample zones, outside /hg test", function()
    local sim = setup(case[1], case[2])
    local A, H, O = sim.ns.WorldActivity, sim.ns.Hub, sim.ns.Options
    sim:command("activity test")
    local w = sim.env.HighgroundWorldActivityPreview
    assert(A.PreviewShown() and w:IsShown(), "the command opens the sample")
    equal(#w.items, 2)
    equal(#A.Entries(), 0, "live data untouched")
    assert(not (A.win and A.win:IsShown()), "the live window stays closed")
    sim:command("activity test")
    assert(not w:IsShown(), "the command closes it again")
    -- A window would replace the Highground window, so /hg test leaves it out.
    H.Open("nearby-previews")
    sim.ns.PreviewTests.StartAll()
    assert(H.win:IsVisible() and not w:IsShown(), "/hg test keeps the Highground window")
    sim.ns.PreviewTests.StopAll()
    local button
    for _, b in ipairs(O.byKey["nearby-previews"].previews) do if b.cmd == "activity test" then button = b end end
    assert(button and button:IsEnabled(), "Nearby's Previews page offers the sample")
    button:Click()
    assert(w:IsShown(), "Start opens it")
    w:Hide()
    sim:assertHealthy()
  end)
end

for _, case in ipairs({ { "cata", 40402 }, { "retail", 120100 }, { "retail", 16001 } }) do
  test(case[2] .. ": /hg nearby guide starts the Nearby walkthrough and every step opens", function()
    local sim = setup(case[1], case[2])
    sim:event("PLAYER_LOGIN"); sim:advance(1)
    local C = sim.ns.Onboarding.Coach
    sim:command("nearby guide")
    assert(C.running, "the walkthrough runs")
    equal(C.steps[1].id, "nearby")
    local seen = {}
    for i, step in ipairs(C.steps) do
      C.Go(i); sim:advance(0.3)
      equal(C.steps[C.index].id, step.id, "step " .. step.id .. " opens")
      seen[step.id] = true
    end
    for _, id in ipairs({ "shared", "fights", "marks", "activity", "track" }) do assert(seen[id], "has the " .. id .. " step") end
    sim.ns.Onboarding.Return()
    sim:assertHealthy()
  end)
end

t.finish("World activity: " .. t.tests .. " scenarios, " .. t.failures .. " failures")
