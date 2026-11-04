local test, new, check = ...
local function equal(a, b, why) return check(a, b, why or "values match") end
local function click(button) button.scripts.OnClick(button, "LeftButton") end

local function setup(game, saved, configure)
  return new(game == "cata" and "cata" or "retail", saved, function(sim, env)
    if game == "forever" then env.GetBuildInfo = function() return "1.60.1", "1", "", 16001 end end
    if game ~= "cata" then env.C_ChatInfo.SendChatMessage, env.SendChatMessage = env.SendChatMessage, nil end
    if configure then configure(sim, env) end
  end)
end

for _, game in ipairs({ "cata", "retail", "forever" }) do
test(game .. " destination calls send the selected area, with local calls and a shared cooldown", function()
  local sim = setup(game, { quickCalls = true, timers = false, flags = false })
  local C, Q = sim.ns.Core, sim.ns.QuickCalls
  local area = "Lumber Mill"
  sim.env.GetSubZoneText = function() return area end
  sim:join(); sim:setCombat(true)
  local w = Q.win
  assert(not w.destinationGroup:IsShown() and not w.routeGroup:IsShown(), "additions start off")
  C.SetFeature("quickCallsDestinations", true)
  assert(w.destinationGroup:IsShown() and not w.routeGroup:IsShown())
  equal(w.destinationButtons[2]:IsEnabled(), false, "choose a destination first")
  assert(w.destination:SetValue("Farm"), "all bases available without timers or map POIs")
  equal(#sim.chat, 0, "selecting a place does not send")
  sim.env.ChatFrame_OpenChat("/w Friend unfinished message")
  for i, count in ipairs({ "1", "2", "3+" }) do
    click(w.destinationButtons[i])
    equal(sim.chat[i].text, "" .. count .. (i == 1 and " enemy" or " enemies") .. " going to Farm")
    equal(sim.chat[i].channel, "INSTANCE_CHAT")
    equal(sim.chatDraft, "/w Friend unfinished message")
    equal(Q.Send(1), false, "local calls share the cooldown")
    equal(w.destinationButtons[2]:IsEnabled(), false)
    sim:advance(2.3)
    area = "Blacksmith" -- Moving the observer must not change the chosen destination.
    equal(#sim.chat, i, "no automatic sends")
  end
  click(w.buttons[3])
  equal(sim.chat[4].text, "Need help — Blacksmith (2 enemies)", "local help still follows the observer")
  equal(Q.SendDestination(2, "Farm"), false, "cooldown also applies after local help")
  sim:advance(2.3)
  equal(Q.SendDestination(4, "Farm"), false)
  equal(Q.SendDestination(2, "not a map destination"), false)
  equal(Q.SendRoute("Tunnel"), false, "route feature stays off")
  C.SetFeature("quickCallsDestinations", false)
  assert(not w.destinationGroup:IsShown() and w:IsShown())
  equal(Q.SendDestination(2, "Farm"), false)
  equal(#sim.chat, 4)
  sim:assertHealthy()
end)

test(game .. " WSG and Twin Peaks routes work in midfield without carrier observations", function()
  local sim = setup(game, { quickCalls = true, timers = false, flags = false })
  local C, Q = sim.ns.Core, sim.ns.QuickCalls
  sim.env.GetSubZoneText = function() return sim.mapName end
  sim:join(1460, 489, "Warsong Gulch"); sim:setCombat(true)
  equal(Q.win, nil, "broad area still hides the original panel")
  C.SetFeature("quickCallsRoutes", true)
  local w = assert(Q.win)
  assert(w:IsShown() and w.routeGroup:IsShown() and not w.localRow:IsShown())
  for i, route in ipairs({ "ramp", "graveyard", "tunnel" }) do
    click(w.routeButtons[i])
    equal(sim.chat[i].text, "EFC going " .. route)
    equal(sim.chat[i].channel, "INSTANCE_CHAT")
    equal(w.routeButtons[i]:IsEnabled(), false)
    equal(Q.SendRoute("Ramp"), false)
    sim:advance(2.3)
  end
  -- A click before the map event/tick cannot reuse the old map's buttons.
  sim.mapID, sim.instanceID, sim.mapName = 206, 726, "Twin Peaks"
  click(w.routeButtons[1]); click(w.routeButtons[3])
  equal(#sim.chat, 3, "stale route controls do not send, even for a shared route")
  sim:join(206, 726, "Twin Peaks")
  equal(w.routeButtons[3].label.text, "Water")
  for i, route in ipairs({ "ramp", "graveyard", "water" }) do
    click(w.routeButtons[i])
    equal(sim.chat[3 + i].text, "EFC going " .. route)
    sim:advance(2.3)
  end
  equal(Q.SendRoute("Tunnel"), false, "wrong-map route rejected")
  C.SetFeature("quickCallsRoutes", false)
  assert(not w:IsShown())
  equal(Q.SendRoute("Water"), false)
  C.SetFeature("quickCallsRoutes", true)
  C.SetFeature("quickCalls", false)
  assert(not w:IsShown()); equal(Q.SendRoute("Water"), false)
  C.SetFeature("quickCalls", true)
  sim:setCombat(false); sim:leave()
  assert(not w:IsShown()); equal(Q.SendRoute("Water"), false)
  sim:joinArena(); assert(not w:IsShown()); equal(Q.SendRoute("Water"), false)
  sim:leave(); sim:join()
  assert(not w:IsShown(), "flag routes never appear on a base map")
  equal(#sim.chat, 6)
  sim:assertHealthy()
end)
end

test("destination choices reset across matches and map changes before a fresh tick", function()
  local sim = new("retail", { quickCalls = true, quickCallsDestinations = true, timers = false })
  local Q = sim.ns.QuickCalls
  sim.env.GetSubZoneText = function() return sim.mapName end
  sim:join()
  local w = assert(Q.win)
  assert(w:IsShown() and not w.localRow:IsShown(), "destination calls also work on roads")
  w.destination:SetValue("Farm")
  sim.mapID, sim.instanceID, sim.mapName = 1576, 2245, "Deepwind Gorge"
  click(w.destinationButtons[2])
  equal(#sim.chat, 0, "Farm on a different map needs a fresh selection")
  Q.Update()
  equal(w.destination:GetValue(), "")
  equal(w.destinationButtons[2]:IsEnabled(), false)
  assert(w.destination:SetValue("Market"))
  click(w.destinationButtons[2])
  equal(sim.chat[1].text, "2 enemies going to Market")
  sim:leave(); sim:join(1576, 2245, "Deepwind Gorge")
  equal(w.destination:GetValue(), "", "a new match clears the destination")
  sim:leave(); sim:join(275, 761, "Battle for Gilneas")
  assert(w.destination:SetValue("Lighthouse"))
  equal(w.destination:SetValue("Farm"), false, "old map bases removed")
  sim:leave(); sim:join(112, 566, "Eye of the Storm")
  assert(w.destination:SetValue("Mage Tower"))
  sim:assertHealthy()
end)

test("Gilneas Mine and Mines are one destination using the client's observed name", function()
  local sim = new("cata", { quickCalls = true, quickCallsDestinations = true, timers = false })
  local Q = sim.ns.QuickCalls
  sim:join(275, 761, "Battle for Gilneas")
  local w = Q.win
  assert(w.destination:SetValue("Mine"), "fallback available before map landmarks")
  sim.pois = { { name = "Mines", position = { x = 0.6, y = 0.4 } } }
  sim:event("AREA_POIS_UPDATED"); Q.Update()
  equal(#w.destination.choices, 4, "placeholder plus the three Gilneas bases")
  equal(w.destination:GetValue(), "", "a replaced fallback needs a fresh selection")
  equal(w.destination:SetValue("Mine"), false, "duplicate fallback removed")
  assert(w.destination:SetValue("Mines"), "game spelling available")
  click(w.destinationButtons[2])
  equal(sim.chat[1].text, "2 enemies going to Mines")
  sim:assertHealthy()
end)

test("destination calls use localized landmarks independently of timer and intel settings", function()
  local sim = new("cata", { quickCalls = true, quickCallsDestinations = true, timers = false, intel = false })
  sim.env.GetLocale = function() return "frFR" end
  sim.env.GetSubZoneText = function() return "Scierie" end
  sim.pois = { { name = "Ferme", position = { x = 0.56, y = 0.6 } },
    { name = "Scierie", position = { x = 0.4, y = 0.56 } } }
  sim:join()
  local w = sim.ns.QuickCalls.win
  assert(w.destination:SetValue("Ferme"))
  equal(w.destination:SetValue("Farm"), false, "English fallback does not duplicate localized choices")
  click(w.destinationButtons[2])
  equal(sim.chat[1].text, "2 enemies going to Ferme")
  sim:assertHealthy()
end)

test("new callout options are opt-in, saved in profiles and disabled in previews", function()
  for _, saved in ipairs({ {}, { quickCalls = true }, { quickCallsDestinations = "invalid", quickCallsRoutes = 1 } }) do
    local sim = new("cata", saved)
    local C = sim.ns.Core
    equal(C.db.quickCallsDestinations, false); equal(C.db.quickCallsRoutes, false)
    C.SetFeature("quickCalls", true)
    for _, key in ipairs({ "quickCallsDestinations", "quickCallsRoutes" }) do
      local toggle
      for _, box in ipairs(sim.ns.Options.featureBoxes) do if box.key == key then toggle = box end end
      assert(toggle and not toggle.option.advanced and toggle.option.parent == "quickCalls")
      click(toggle); equal(C.db[key], true)
    end
    local P, Q = sim.ns.Options.Profiles, sim.ns.QuickCalls
    P.SaveProfile("Routes")
    C.SetFeature("quickCallsDestinations", false); C.SetFeature("quickCallsRoutes", false)
    sim:command("profile load Routes")
    equal(C.db.quickCallsDestinations, true); equal(C.db.quickCallsRoutes, true)
    assert(sim.ns.BattlegroundsPreview.Start())
    local w = assert(Q.win)
    assert(w.destinationGroup:IsShown() and w.routeGroup:IsShown())
    equal(w.destination:IsEnabled(), false)
    for _, buttons in ipairs({ w.buttons, w.destinationButtons, w.routeButtons }) do
      for _, button in ipairs(buttons) do equal(button:IsEnabled(), false) end
    end
    equal(Q.SendDestination(2, "Farm"), false); equal(Q.SendRoute("Tunnel"), false)
    equal(#sim.chat, 0, "previews never send")
    sim.ns.BattlegroundsPreview.Stop(); assert(not w:IsShown())
    local reload = new("cata", sim.env.HighgroundDB)
    equal(reload.ns.Core.db.quickCallsDestinations, true); equal(reload.ns.Core.db.quickCallsRoutes, true)
    sim:assertHealthy(); reload:assertHealthy()
  end
end)

test("new callouts keep failed sends out of premade chat and do not retry them", function()
  local sim = new("cata", { quickCalls = true, quickCallsDestinations = true, quickCallsRoutes = true })
  local Q = sim.ns.QuickCalls
  sim:join()
  sim.env.IsInGroup = function(category) return category ~= sim.env.LE_PARTY_CATEGORY_INSTANCE end
  sim.env.IsInRaid = function() return true end
  equal(Q.SendDestination(2, "Farm"), false)
  sim:leave(); sim:join(1460, 489, "Warsong Gulch")
  equal(Q.SendRoute("Tunnel"), false)
  sim.env.IsInGroup = function() return true end
  local send = sim.env.SendChatMessage
  sim.env.SendChatMessage = function() error("unavailable") end
  equal(Q.SendRoute("Tunnel"), false)
  sim.env.SendChatMessage = send
  sim:advance(3); equal(#sim.chat, 0)
  assert(Q.SendRoute("Tunnel"), "a failed send does not consume the cooldown")
  sim:assertHealthy()
end)

test("expanded callout controls fit every theme and text size", function()
  local sim = new("cata", { quickCalls = true, quickCallsDestinations = true, quickCallsRoutes = true },
    function(s) dofile("../../tools/wowsim/geometry.lua")(s) end)
  sim.ns.BattlegroundsPreview.Start()
  local w = sim.ns.QuickCalls.win
  for _, theme in ipairs(sim.ns.Theme.Names()) do
    sim.ns.Theme.Use(theme)
    for _, scale in ipairs({ 1, 1.5 }) do
      sim.ns.Core.SetFontScale(scale)
      local panel, status = sim.bounds(w), sim.bounds(w.status)
      for _, buttons in ipairs({ w.buttons, w.destinationButtons, w.routeButtons }) do
        local previous
        for _, button in ipairs(buttons) do
          assert(button.label:GetStringWidth() <= button:GetWidth() - 8, "button label fits")
          local bounds = sim.bounds(button)
          assert(bounds[1] >= panel[1] and bounds[1] + bounds[3] <= panel[1] + panel[3], "inside panel width")
          assert(bounds[2] + bounds[4] < status[2], "controls stay above the status")
          if previous then assert(previous[1] + previous[3] < bounds[1], "buttons stay apart") end
          previous = bounds
        end
      end
      local localRow, dest, routes = sim.bounds(w.localRow), sim.bounds(w.destinationGroup), sim.bounds(w.routeGroup)
      assert(localRow[2] + localRow[4] < dest[2] and dest[2] + dest[4] < routes[2], "sections stay apart")
      assert(w.routeGroup.heading:GetStringWidth() <= w.routeGroup:GetWidth(), "route heading fits")
      assert(status[2] + status[4] < panel[2] + panel[4], "status stays inside panel")
    end
  end
  sim:assertHealthy()
end)
