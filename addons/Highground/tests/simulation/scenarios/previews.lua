local test, newClient, equal = ...
local F = dofile("tests/modules/fixture.lua")
local function new(client, disabled)
  return newClient(client == "forever" and "retail" or client, {}, function(s, e)
    F.configure(disabled)(s, e)
    if client == "forever" then
      e.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end
      e.loadstring_untainted, s.secureSnippets = nil, false
    end
  end)
end
local function click(button) button.scripts.OnClick(button) end
local function commandButton(s, id, owner)
  local key = owner and owner .. "-commands" or "tools"
  s.ns.Hub.Open(key)
  for _, item in ipairs(s.ns.Options.byKey[key].commandRows) do
    if item.definition.id == id then return item.button end
  end
  error("Missing command control: " .. id)
end
local function stopped(s)
  assert(not s.ns.PreviewTests.AnyActive(), "all sample modes stopped")
  assert(not s.ns.Nearby.test and not s.ns.Bounty.Preview.state, "sample providers released")
end

for _, client in ipairs({ "cata", "retail", "forever" }) do
  test(client .. " battleground command owns its panels and leaves other addons alone", function()
    local s = new(client)
    local C, T = s.ns.Core, s.ns.Timers
    local settings = s.ns.Options.Profiles.SnapshotSetup()
    s:command("bg test"); s:advance(1)
    assert(C.testMode and T.previewing and C.frame:IsVisible())
    assert(not s.ns.Arena.preview and not s.ns.Nearby.preview and not s.ns.Bounty.Preview.testing)
    assert(not C.sniperTest.on, "dedicated marker override is not forced by battleground panels")
    s.ns.Hub.Open("battlegrounds-previews")
    local button = s.ns.Options.byKey["battlegrounds-previews"].previews[1]
    equal(button.cmd, "bg test", "battleground UI uses its owned command")
    assert(button:GetText():find("Stop", 1, true))
    click(button); stopped(s)
    click(button); assert(C.testMode and T.previewing)
    click(commandButton(s, "bg test stop", "battlegrounds")); stopped(s)
    s:command("bg test stop"); stopped(s)
    equal(s.ns.Codec.Pack(s.ns.Options.Profiles.SnapshotSetup()), s.ns.Codec.Pack(settings), "preview leaves saved settings alone")
    s:assertHealthy()
  end)

  test(client .. " shared commands and UI start enabled samples and preserve existing previews", function()
    local s = new(client)
    local N, B, P = s.ns.Nearby, s.ns.Bounty, s.ns.PreviewTests
    local byName = N.seen
    local saved = s.ns.Codec.Pack(B.Personal())
    s:command("nearby test")
    s:command("intel test")
    local all = commandButton(s, "test")
    equal(s.ns.CommandCatalog.Owner("test all"), nil, "all-addon alias remains shared")
    equal(s.ns.CommandCatalog.Owner("bg test"), "battlegrounds", "battleground preview has its addon owner")
    click(all); s:advance(1)
    assert(P.AllActive() and N.preview and s.ns.Intel.testPins, "existing previews stay on")
    assert(s.ns.Core.testMode and s.ns.Timers.previewing and s.ns.Arena.preview and B.Preview.testing)
    assert(s.ns.Core.sniperTest.on, "all includes the target-marker test")
    equal(s.ns.Core.burstTest == true, client == "cata", "burst preview respects client support")
    equal(N.seen, byName, "live nearby records are retained")
    equal(s.ns.Codec.Pack(B.Personal()), saved, "live bounty store is retained")
    s:command("bg test stop")
    assert(not s.ns.Core.testMode and N.preview and B.Preview.testing, "scoped stop leaves other addons running")
    click(commandButton(s, "test stop")); s:advance(1); stopped(s)
    click(all); assert(P.AllActive())
    click(all); stopped(s)
    for _, start in ipairs({ "test", "test all" }) do
      s:command(start); assert(P.AllActive())
      s:command(start); stopped(s)
    end
    s:command("arena test"); s:command("bounty test board")
    s:command("test stop"); stopped(s)
    s:assertHealthy()
  end)

  test(client .. " shared previews work with battlegrounds disabled and skip disabled addons", function()
    local s = new(client, { battlegrounds = true, bounties = true })
    s:command("test all")
    assert(s.ns.Arena.preview and s.ns.Nearby.preview)
    assert(not s.ns.Core.testMode and not s.ns.Timers.previewing and not s.ns.Core.sniperTest.on)
    assert(not s.ns.Bounty.Preview.testing and not s.ns.Intel.testPins)
    s:command("test stop"); stopped(s)
    s:command("bg test")
    equal(s.ns.Hub.current, "module-battlegrounds", "scoped command opens disabled-addon controls")
    local off = new(client, { battlegrounds = true, arena = true, nearby = true, bounties = true })
    off:command("test")
    assert(not off.ns.PreviewTests.AnyActive())
    assert(off.messages[#off.messages]:find("No enabled addons", 1, true), "no false success when only tools remain")
    s:assertHealthy(); off:assertHealthy()
  end)

  test(client .. " preview validation protects combat, matches, duels and invalid arguments", function()
    local s = new(client)
    for _, command in ipairs({ "test typo", "test all stop", "bg", "bg typo", "bg test typo" }) do
      s:command(command); stopped(s)
    end
    s:setCombat(true)
    s:command("test all"); s:command("bg test"); stopped(s)
    s:setCombat(false)
    s:enemy("LiveEnemy"); s:join()
    local enemy = s:entry("LiveEnemy")
    assert(enemy and not s.ns.Core.testMode)
    s:command("bg test"); s:command("test"); s:command("bg test stop"); s:command("test stop")
    equal(s:entry("LiveEnemy"), enemy, "refused previews and idle stop preserve the live roster")
    assert(s.ns.Core.active and not s.ns.Core.testMode)
    s:leave(); s.ns.Arena.duel = { name = "Opponent" }
    s:command("test all"); s:command("bg test"); stopped(s)
    s:assertHealthy()
  end)

  test(client .. " grouped previews stop on combat and instance transitions and restore live data", function()
    local s = new(client)
    local N = s.ns.Nearby
    N.seen["Remembered-Realm"] = { name = "Remembered-Realm", class = "MAGE", first = s.now, last = s.now }
    local remembered = N.seen["Remembered-Realm"]
    s:command("test all"); s:advance(1)
    s:setCombat(true); stopped(s)
    assert(not s.ns.Core.frame:IsShown() or s.ns.Core.frame:GetAlpha() == 0, "protected sample panel is hidden or faded in combat")
    s:setCombat(false); s:advance(1)
    assert(not s.ns.Core.frame:IsShown(), "protected frame finishes cleanup after combat")
    equal(N.seen["Remembered-Realm"], remembered, "live nearby sightings survive sample cleanup")
    s:command("test all"); s:join(); stopped(s)
    s:leave(); s:command("test"); s:joinArena(); stopped(s)
    s:leave(); s:command("test"); s:event("DUEL_REQUESTED", "Opponent"); stopped(s)
    s:assertHealthy()
  end)

  test(client .. " guides and placement retire the shared set and keep their own lifecycle", function()
    local s = new(client)
    s:command("test all")
    s:command("guide enemies")
    assert(s.ns.Onboarding.Coach.running and s.ns.Core.guidedTest)
    assert(not s.ns.PreviewTests.managed and not s.ns.Bounty.Preview.testing and not s.ns.Nearby.preview)
    s:command("bg test"); s:command("bg test stop")
    assert(s.ns.Onboarding.Coach.running and s.ns.Core.guidedTest, "scoped tests cannot dismantle a guided scene")
    s:command("test all")
    assert(s.ns.Onboarding.Coach.running and s.ns.Core.guidedTest, "shared start cannot replace a running guide")
    s:command("test stop")
    assert(not s.ns.Onboarding.Coach.running and not s.ns.Setup.placement)
    stopped(s)
    s:command("test all"); assert(s.ns.Setup.BeginPlacement())
    assert(not s.ns.PreviewTests.managed and not s.ns.Bounty.Preview.testing)
    s.ns.Setup.EndPlacement(false); stopped(s)
    s.ns.Onboarding.Open()
    s.ns.Onboarding.Go("battlegrounds")
    s.ns.Onboarding.Explore(s.ns.Onboarding.Current().actions[2])
    equal(s.ns.Hub.current, "battlegrounds-previews", "guide links to the owned preview page")
    click(s.ns.Options.byKey["battlegrounds-previews"].previews[1])
    assert(s.ns.Core.testMode and s.ns.Timers.previewing, "guide page link can run the preview")
    s:command("test stop"); stopped(s)
    s:assertHealthy()
  end)
end
