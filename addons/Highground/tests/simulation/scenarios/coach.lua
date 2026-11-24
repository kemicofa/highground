local test, new, check = ...
local function equal(a, b, why) return check(a, b, why or "values match") end
local function click(button) button.scripts.OnClick(button) end
local function geometry(sim)
  dofile("../../tools/wowsim/geometry.lua")(sim)
  -- Blizzard frames exist before optional geometry is installed.
  for _, map in ipairs({ sim.env.WorldMapFrame, sim.env.BattlefieldMapFrame }) do map:SetSize(map.width, map.height) end
end
local function mapSetup(sim)
  geometry(sim)
  sim.mapID = 37
  sim.env.WorldMapFrame:SetMapID(37)
  sim.env.WorldMapFrame:Hide()
end
local function snapshot(sim)
  local p = sim.ns.Options.Profiles
  return p.ExportString(p.Snapshot())
end

for _, client in ipairs({ "cata", "retail", "forever" }) do
  local function make(saved, configure)
    return new(client == "cata" and "cata" or "retail", saved, function(s, env)
      if client == "forever" then env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end end
      (configure or mapSetup)(s, env)
    end)
  end
  test(client .. " visual samples close the hub, highlight real controls, and finish cleanly", function()
    local sim = make({})
    local O = sim.ns.Onboarding
    local before = snapshot(sim)
    local keys = { "panels", "enemies", "objectives", "arena", "nearby", "map", "bounty_post", "bounty_hunt" }
    if client == "forever" then table.remove(keys, 4) end -- no Arena on Forever
    for _, key in ipairs(keys) do
      sim.ns.Hub.Open("checklist"); O.Go(key); O.Explore(O.Current().actions[1])
      local C = O.Coach
      assert(C.running and not sim.ns.Hub.win:IsVisible() and not O.win:IsVisible(), key .. " launches outside the hub")
      assert(not sim.ns.Setup.layoutBar or not sim.ns.Setup.layoutBar:IsVisible())
      for i = 1, #C.steps do
        C.Go(i); equal(C.index, i)
        sim:advance(0.3); C.Update()
        assert(C.target and C.target:IsVisible(), key .. " visible target for " .. C.steps[i].id)
        assert(C.spot:IsVisible() and C.arrow:IsVisible(), key .. " spotlight and arrow")
        assert(C.root.mouseEnabled == false and C.spot.mouseEnabled == false, "overlays pass clicks through")
        if i == #C.steps then C.Step(1) end
      end
      assert(not C.running and O.win:IsVisible() and not O.exploring)
      equal(O.Current().key, key)
      equal(O.State().samples[key], "done")
      assert(O.Done(key), "finishing a sample completes its own chapter")
    end
    equal(snapshot(sim), before, "unacted sample controls never change settings")
    sim:assertHealthy()
  end)

  test(client .. " map guide uses the actual world map and live pins with isolated observations", function()
    local sim = make({})
    local O, Intel = sim.ns.Onboarding, sim.ns.Intel
    local live, map = Intel.intel, sim.env.WorldMapFrame
    local mapID, sends = map:GetMapID(), #sim.sent
    for _, alreadyOpen in ipairs({ false, true }) do
      map:SetShown(alreadyOpen)
      O.Start("map")
      local M = O.Coach.Map
      equal(M.win, map, "the guide opens WoW's world map")
      equal(map:GetMapID(), M.mapID)
      equal(M.mapID, client == "cata" and 1460 or 1339)
      assert(map:IsVisible() and not sim.env.HighgroundMapSample, "no copied map window")
      equal(#map.pins, 6, "five sample enemies and the rough sighting's circle")
      equal(#sim.env.BattlefieldMapFrame.pins, 0, "sample pins stay on the guide's map")
      local circles = 0
      for _, pin in ipairs(map.pins) do
        equal(pin:GetParent(), map:GetCanvas())
        if pin.template == "HighgroundZonePinTemplate" then circles = circles + 1
        else equal(pin.template, "HighgroundPinTemplate") end
        assert(pin:IsVisible() and pin.mouseEnabled)
      end
      equal(circles, 1, "only the approximate sighting gets a circle")
      assert(M.Pin("fresh").item.mark)
      equal(M.Pin("old").item.label, "36s"); equal(M.Pin("rough").item.label, "~12s")
      assert(M.Pin("rough").item.zone.radius > 0)
      assert(M.Pin("old"):GetAlpha() < M.Pin("fresh"):GetAlpha())
      O.Coach.Go(2); sim:advance(1); O.Coach.Update()
      local pin = M.Pin("fresh")
      equal(O.Coach.target, pin, "the coach follows the current pooled pin after refresh")
      pin.scripts.OnEnter(pin)
      for _, hook in ipairs(pin.hooks.OnEnter or {}) do hook(pin) end
      assert(O.Coach.observed and sim.env.GameTooltip:IsShown())
      equal(sim.env.GameTooltip:GetOwner(), pin, "the normal pin tooltip is used")
      equal(Intel.intel, live); equal(next(live), nil); equal(#sim.sent, sends)
      for i, step in ipairs(O.Coach.steps) do if step.id == "share" then O.Coach.Go(i) end end
      equal(O.Coach.win.enable:IsShown(), client ~= "forever", "the sharing switch only where the game allows sharing")
      map:SetMapID(37); equal(#map.pins, 0, "samples never appear on a different zone")
      O.Coach.Replay(); equal(map:GetMapID(), M.mapID); equal(#map.pins, 6, "replay restores the samples and circle")
      map:Hide(); O.Coach.Replay(); assert(map:IsVisible(), "Replay reopens the native map")
      O.Return(); equal(map:IsShown(), alreadyOpen); equal(map:GetMapID(), mapID)
      assert(not sim.env.GameTooltip:IsShown() and not M.session)
      equal(#map.pins, 0, "guide pins are removed on exit")
    end
    sim:assertHealthy()
  end)
end

test("sample progress resumes, Back reopens the preceding target, and Escape returns to the guide", function()
  local sim = new("cata", {}, mapSetup)
  local O, C = sim.ns.Onboarding, sim.ns.Onboarding.Coach
  O.Start("map"); C.Go(3); C.Go(4); click(C.win.back); equal(C.steps[C.index].id, "target")
  C.win:Hide(); assert(O.win:IsVisible() and not C.running)
  local again = new("cata", sim.env.HighgroundDB, mapSetup)
  O, C = again.ns.Onboarding, again.ns.Onboarding.Coach
  O.Start("map"); equal(C.steps[C.index].id, "target")
  O.Return()
  O.State().samples = "damaged"; O.Start("map"); equal(C.index, 1)
  O.Return()
end)

test("map guide handles unavailable Warsong maps without making a fake canvas", function()
  local sim = new("cata", {}, mapSetup)
  local O, env = sim.ns.Onboarding, sim.env
  env.C_Map.GetMapInfo = function(id)
    if id == 1460 then error("Unavailable map") end
    if id == 1339 then return { name = "Warsong Gulch" } end
  end
  O.Start("map"); equal(O.Coach.Map.mapID, 1339)
  equal(O.Coach.Map.win, env.WorldMapFrame); equal(env.WorldMapFrame:GetMapID(), 1339)
  O.Return()
  env.C_Map.GetMapInfo = function() end
  O.Start("map"); equal(O.Coach.Map.mapID, nil); equal(env.WorldMapFrame:GetMapID(), 37)
  equal(#env.WorldMapFrame.pins, 0); assert(not env.HighgroundMapSample)
  O.Coach.Go(2); assert(O.Coach.win.hint:GetText():find("unavailable", 1, true))
  O.Return(); sim:assertHealthy()
end)

test("combat and match entry end all visual samples without reopening the guide", function()
  for _, chapter in ipairs({ "enemies", "objectives", "panels", "arena", "nearby", "map", "bounty_post", "bounty_hunt", "callouts", "macros" }) do
    for _, ending in ipairs({ "combat", "match" }) do
      local sim = new("cata", {}, mapSetup)
      local O, C = sim.ns.Onboarding, sim.ns.Onboarding.Coach
      O.Start(chapter)
      if ending == "combat" then sim:setCombat(true) else sim:join() end
      assert(not C.running and not C.root:IsVisible() and not O.win:IsVisible())
      assert(not sim.ns.Setup.placement and not sim.ns.Bounty.Preview.guided)
      if C.Map.win then assert(not C.Map.win:IsVisible()) end
      sim:assertHealthy()
    end
  end
end)

test("coach text and controls fit at large font sizes and remain on screen", function()
  local sim = new("cata", {}, mapSetup)
  local O, C = sim.ns.Onboarding, sim.ns.Onboarding.Coach
  for _, size in ipairs({ 1, 1.5 }) do
    sim.ns.Core.SetFontScale(size)
    for _, chapter in ipairs({ "map", "nearby", "panels", "bounty_post", "bounty_hunt" }) do
      O.Start(chapter)
      for i = 1, #C.steps do
        C.Go(i); C.Update()
        local b = sim.bounds(C.win)
        assert(b[1] >= 0 and b[2] >= 0 and b[1] + b[3] <= 1280 and b[2] + b[4] <= 820, "coach stays in view")
        local body, hint = sim.bounds(C.win.body), sim.bounds(C.win.hint)
        assert(body[2] + body[4] <= hint[2], "body and prompt never overlap")
        for _, button in ipairs({ C.win.back, C.win.next, C.win.done }) do
          assert(button.label:GetStringWidth() <= button:GetWidth() - 12, "readable coach actions")
          local box = sim.bounds(button)
          assert(hint[2] + hint[4] <= box[2], "buttons stay below the prompt")
        end
      end
      O.Return()
    end
  end
  sim:assertHealthy()
end)

test("disabled battleground panels stay disabled and a callout-only sample has a target", function()
  local sim = new("cata", { killorder = false, timers = false, flags = false, quickCalls = false }, geometry)
  local O, C = sim.ns.Onboarding, sim.ns.Onboarding.Coach
  O.Start("panels")
  assert(not C.running and O.win:IsVisible() and O.win.status.text:find("panels are off", 1, true))
  sim.ns.Core.SetFeature("quickCalls", true)
  O.Start("panels")
  assert(C.running and C.target == sim.ns.QuickCalls.win and C.target:IsVisible())
  O.Return()
  equal(sim.ns.Core.On("killorder"), false); equal(sim.ns.Core.On("timers"), false)
  sim:assertHealthy()
end)

test("feature guides keep their switch on every step, enable parents and offer alert sounds", function()
  local sim = new("cata", { objectives = false, dieAlert = false, sound = false }, geometry)
  local O, C, Core, A = sim.ns.Onboarding, sim.ns.Onboarding.Coach, sim.ns.Core, sim.ns.Alerts
  sim.ns.Hub.Open("checklist"); O.Go("objectives"); O.Explore(O.Current().actions[1])
  local w = C.win
  for i, id in ipairs({ "resurrection", "estimate", "capture", "score", "carrier" }) do
    C.Go(i); equal(C.steps[C.index].id, id)
    assert(w.enable:IsShown(), id .. " offers its feature switch")
  end
  C.Go(2); equal(C.feature, "timers"); equal(w.enable:GetChecked(), true, "a step without its own switch keeps the previous one")
  C.Go(3); equal(C.feature, "objectives"); equal(w.enable:GetChecked(), false)
  click(w.enable); equal(Core.On("objectives"), true)
  C.Go(4); equal(C.feature, "forecast"); equal(w.enable:GetChecked(), true, "the win forecast has its own switch, on by default")
  C.Go(3); equal(C.sound, "capture"); assert(w.sound:IsShown() and w.play:IsShown() and w.cue:IsShown())
  C.Go(1); equal(C.sound, "resurrection")
  equal(w.sound:GetChecked(), false, "the resurrection alert starts off")
  click(w.sound)
  equal(Core.On("dieAlert"), true); equal(Core.On("sound"), true); equal(A.Settings().channels.resurrection.sound, true)
  equal(w.sound:GetChecked(), true)
  click(w.play); assert(sim.sounds[#sim.sounds]:find("alert-resurrection.ogg", 1, true), "plays the alert's own cue")
  w.cue:SetValue("readycheck"); equal(sim.sounds[#sim.sounds], 8960, "a new choice plays once")
  equal(A.Sound("resurrection"), "readycheck")
  local P = sim.ns.Options.Profiles
  local setup = P.SnapshotSetup()
  equal(assert(P.PrepareSetup(setup)).alerts.sounds.resurrection, "readycheck", "profiles keep the choice")
  setup.alerts.sounds.resurrection = "missing"
  local result, problem = P.PrepareSetup(setup)
  assert(not result and problem:find("invalid alert sound", 1, true), "unknown sounds are rejected")
  click(w.sound); equal(A.Settings().channels.resurrection.sound, false)
  equal(Core.On("dieAlert"), true, "muting the sound keeps the written alert")
  Core.SetFeature("timers", false); Core.SetFeature("objectives", false)
  C.SetFeature("objectiveOverview", true)
  equal(Core.On("objectives"), true); equal(Core.On("timers"), true, "a child switch enables its parents")
  O.Return(); sim:assertHealthy()
end)

test("a ticked target-lock switch plays even with an old Essentials level saved", function()
  local sim = new("cata", { alerts = { mode = "essential", channels = {} }, sniperSound = 1 }, geometry)
  local O, C, Core = sim.ns.Onboarding, sim.ns.Onboarding.Coach, sim.ns.Core
  sim.ns.Hub.Open("checklist"); O.Go("enemies"); O.Explore(O.Current().actions[1])
  for i, step in ipairs(C.steps) do if step.id == "crosshair" then C.Go(i) end end
  equal(C.sound, "lockon"); equal(C.win.sound:GetChecked(), true)
  equal(C.win.soundNote:GetText(), "", "nothing mutes a ticked switch")
  local before = #sim.sounds
  Core.PlaySniperSound(); sim:advance(0.2)
  equal(#sim.sounds, before + 1, "lock-on plays through the alert queue")
  click(C.win.sound)
  equal(sim.ns.Alerts.ChannelOn("lockon", "sound"), false, "the guide switch is the alert's Sound switch")
  sim:advance(2); Core.PlaySniperSound(); sim:advance(0.2)
  equal(#sim.sounds, before + 1, "unticked, it stays quiet")
  O.Return(); sim:assertHealthy()
end)

test("the spotlight follows scaled panels and dragging without covering the target", function()
  local sim = new("cata", {}, geometry)
  local O, C = sim.ns.Onboarding, sim.ns.Onboarding.Coach
  O.Start("panels")
  local f = sim.ns.Core.frame
  f:SetScale(0.75); f:ClearAllPoints(); f:SetPoint("TOPLEFT", sim.env.UIParent, "TOPLEFT", 30, -100)
  C.Update()
  local target, spot, card = sim.bounds(f), sim.bounds(C.spot), sim.bounds(C.win)
  assert(math.abs(spot[1] - (target[1] - 6)) < 0.01 and math.abs(spot[3] - (target[3] + 12)) < 0.01,
    "spotlight uses the target's effective scale")
  assert(card[1] >= spot[1] + spot[3] or card[1] + card[3] <= spot[1]
    or card[2] >= spot[2] + spot[4] or card[2] + card[4] <= spot[2], "coach leaves the target clickable")
  f:ClearAllPoints(); f:SetPoint("TOPLEFT", sim.env.UIParent, "TOPLEFT", 180, -160)
  sim:advance(0.1)
  assert(sim.bounds(C.spot)[1] > spot[1], "highlight follows a moved panel")
  O.Return(); sim:assertHealthy()
end)
