local test, new, check = ...
local function equal(a, b, why) return check(a, b, why or "values match") end
local function click(button) button.scripts.OnClick(button, "LeftButton") end

for _, game in ipairs({ "cata", "retail", "forever" }) do
test(game .. " quick buttons are game macros for the battleground and keep their area in combat", function()
  local area = "Farm"
  local sim = new(game == "cata" and "cata" or "retail", nil, function(_, env)
    env.GetSubZoneText = function() return area end
    if game == "forever" then env.GetBuildInfo = function() return "1.60.1", "1", "", 16001 end end
  end)
  local C, Q = sim.ns.Core, sim.ns.QuickCalls
  sim:join()
  equal(Q.win, nil, "new feature is off until enabled")
  C.SetFeature("quickCalls", true)
  local w = assert(Q.win)
  assert(w:IsShown(), "the panel appears")
  sim.env.ChatFrame_OpenChat("/w Friend unfinished message")
  for i, message in ipairs({ "Need help — Farm", "Need help — Farm (1 enemy)", "Need help — Farm (2 enemies)",
    "Need help — Farm (3+ enemies)", "All clear — Farm" }) do
    sim:click(w.buttons[i].fire)
    equal(#sim.chat, i, "one message per click, no Enter")
    equal(sim.chat[i].text, message)
    assert(sim.chat[i].macro and sim.chat[i].channel == "INSTANCE_CHAT", "sent as a /i macro, like the player's own")
    equal(sim.chatDraft, "/w Friend unfinished message", "an open chat message stays intact")
  end
  equal(w.status.text, "Sent to battleground")
  sim:setCombat(true)
  area = "Blacksmith"
  sim:advance(0.5)
  equal(w.area.text, "Farm", "in combat the panel keeps the area its macros were made for")
  equal(w.status.text, "Updates after combat", "and says an update is waiting")
  sim:click(w.buttons[3].fire)
  equal(sim.chat[6].text, "Need help — Farm (2 enemies)", "combat clicks still send")
  sim:setCombat(false)
  sim:advance(0.5)
  equal(w.area.text, "Blacksmith", "the area catches up after combat")
  sim:click(w.buttons[3].fire)
  equal(sim.chat[7].text, "Need help — Blacksmith (2 enemies)")
  C.SetFeature("quickCalls", false)
  assert(not w:IsShown(), "turning off hides the panel")
  equal(w.buttons[1].fire.attrs.macrotext, "", "and clears its macros")
  sim:leave()
  sim:assertHealthy()
end)
end

test("quick callouts follow named areas and battleground scope independently of timers", function()
  local sim = new("cata", { timers = false, flags = false, quickCalls = true })
  local Q = sim.ns.QuickCalls
  local area, minimap = "Farm", "Farm"
  sim.env.GetSubZoneText = function() return area end
  sim.env.GetMinimapZoneText = function() return minimap end
  equal(Q.win, nil, "no live panel outside battlegrounds")
  sim:join()
  local w = assert(Q.win)
  assert(w:IsShown())
  sim.ns.Timers.HideWindows()
  assert(w:IsShown(), "timer visibility does not own the callout panel")
  area, minimap = "", "Arathi Basin"
  sim:event("ZONE_CHANGED")
  assert(not w:IsShown(), "whole battleground name is not a destination")
  equal(w.buttons[1].macro, "", "no macro without a named area")
  area, minimap = "", "Lumber Mill"
  sim:event("ZONE_CHANGED_INDOORS")
  assert(w:IsShown()); equal(w.area.text, "Lumber Mill", "minimap area fallback")
  area = "Ferme"
  sim:event("ZONE_CHANGED")
  equal(w.area.text, "Ferme", "localized names are preserved")
  sim:leave(); assert(not w:IsShown()); equal(w.buttons[1].macro, "", "no macro after leaving")
  sim:joinArena(); assert(not w:IsShown()); equal(w.buttons[1].macro, "", "no macro in arenas")
  equal(#sim.chat, 0)
  sim:leave()
  sim.rated = false
  sim.ns.Core.SetFeature("bg15", false)
  sim:join()
  assert(not w:IsShown(), "excluded battleground size stays hidden")
  sim:assertHealthy()
end)

test("quick callouts remain opt-in on upgrades and are exposed in the main settings", function()
  for _, saved in ipairs({ {}, { quickCalls = false }, { quickCalls = "invalid" } }) do
    local sim = new("cata", saved)
    equal(sim.ns.Core.db.quickCalls, false)
    local toggle
    for _, box in ipairs(sim.ns.Options.featureBoxes) do if box.key == "quickCalls" then toggle = box end end
    assert(toggle and not toggle.option.advanced and not toggle.option.parent, "independent main switch")
    sim.ns.Hub.Open("general")
    sim.ns.Options.general.SelectGroup("Battleground")
    assert(toggle:IsVisible())
    click(toggle)
    equal(sim.ns.Core.db.quickCalls, true)
    local reloaded = new("cata", sim.env.HighgroundDB)
    equal(reloaded.ns.Core.db.quickCalls, true, "enabled choice survives reload")
    click(toggle)
    equal(sim.ns.Core.db.quickCalls, false)
  end
end)

test("quick callout previews move independently and save positions in profiles and reloads", function()
  local sim = new("cata", { quickCalls = true, timers = false, flags = false, killorder = false, arena = false })
  local C, Q, S, P = sim.ns.Core, sim.ns.QuickCalls, sim.ns.Setup, sim.ns.Options.Profiles
  assert(S.BeginPlacement())
  local w = assert(Q.win)
  assert(w:IsShown() and w.preview, "preview available with other battleground panels off")
  equal(S.placement.context, "bg")
  equal(w.buttons[1]:IsEnabled(), false)
  equal(w.buttons[3].fire.attrs.macrotext, "", "preview cannot send"); equal(#sim.chat, 0)
  local moved = 0
  w.StartMoving = function() moved = moved + 1 end
  w.scripts.OnDragStart(w); equal(moved, 1)
  w:ClearAllPoints(); w:SetPoint("CENTER", sim.env.UIParent, "CENTER", 75, 95)
  w.scripts.OnDragStop(w)
  equal(C.pos.quickCallsPoint[3], 75); equal(C.pos.quickCallsPoint[4], 95)
  C.SetFeature("compact", true)
  equal(w:GetParent(), sim.env.UIParent); equal(w.docks, false)
  equal(select(4, w:GetPoint()), 75, "compact mode leaves the callout panel where it was placed")
  S.EndPlacement(true)
  assert(not w:IsShown(), "finishing placement closes the preview immediately")
  w.scripts.OnDragStart(w); equal(moved, 1, "panel lock is respected")
  P.SaveProfile("Callouts")
  C.pos.quickCallsPoint = nil; C.db.quickCalls = false
  sim:command("profile load Callouts")
  equal(C.pos.quickCallsPoint[3], 75); equal(C.db.quickCalls, true)
  local reloaded = new("cata", sim.env.HighgroundDB, function(_, env) env.HighgroundCharDB = sim.env.HighgroundCharDB end)
  reloaded.ns.BattlegroundsPreview.Start()
  equal(select(4, reloaded.ns.QuickCalls.win:GetPoint()), 75, "per-character position survives reload")
  reloaded.ns.TimersWindowReset()
  equal(reloaded.ns.Core.pos.quickCallsPoint, nil, "reset includes callouts")
  equal(select(1, reloaded.ns.QuickCalls.win:GetPoint()), "BOTTOM")
  reloaded.ns.BattlegroundsPreview.Stop()
  assert(not reloaded.ns.QuickCalls.win:IsShown())
  sim:assertHealthy(); reloaded:assertHealthy()
end)

test("quick callout controls fit enlarged text and long location names in every theme", function()
  local sim = new("cata", { quickCalls = true }, function(s) dofile("../../tools/wowsim/geometry.lua")(s) end)
  sim.env.GetSubZoneText = function() return "A long localized battleground objective name" end
  sim:join()
  local C, w = sim.ns.Core, sim.ns.QuickCalls.win
  for _, theme in ipairs(sim.ns.Theme.Names()) do
    sim.ns.Theme.Use(theme)
    for _, scale in ipairs({ 1, 1.5 }) do
      C.SetFontScale(scale)
      for _, compact in ipairs({ false, true }) do
        C.SetFeature("compact", compact)
        assert(w.area:GetStringHeight() <= w.area:GetHeight(), "location fits")
        assert(w.status:GetStringWidth() <= w.status:GetWidth(), "send hint fits")
        for _, language in ipairs({ "enUS", "deDE", "frFR" }) do
          sim.ns.Localization.SetPreference(language)
          w.status:SetText(sim.ns.Locale:Get("battlegrounds.quickcalls.updates_after_combat.d3bbe0"))
          assert(w.status:GetStringWidth() <= w.status:GetWidth(), language .. " combat hint fits")
        end
        sim.ns.Localization.SetPreference("enUS")
        local area = sim.bounds(w.area)
        for _, button in ipairs(w.buttons) do
          assert(button.label:GetStringWidth() <= button:GetWidth() - 8, "button label fits")
          local bounds = sim.bounds(button)
          assert(area[2] + area[4] < bounds[2], "area stays above the buttons")
        end
      end
    end
  end
  sim:assertHealthy()
end)

test("the callout panel holds secure buttons: in combat it stays put, a reset waits for the end", function()
  local sim = new("cata", { quickCalls = true, timers = false, flags = false })
  sim:join()
  local C, T, w = sim.ns.Core, sim.ns.Timers, assert(sim.ns.QuickCalls.win)
  sim:command("unlock")
  C.pos.quickCallsPoint = { "CENTER", "CENTER", 40, 60 }
  T.PlaceWin(w)
  local moved = 0
  w.StartMoving = function() moved = moved + 1 end
  sim:setCombat(true)
  w.scripts.OnDragStart(w); w.scripts.OnDragStop(w)
  equal(moved, 0, "no drag in combat")
  sim.ns.TimersWindowReset()
  equal(C.pos.quickCallsPoint, nil, "the reset is saved")
  equal(select(4, w:GetPoint()), 40, "the panel keeps its place in combat")
  sim:advance(1)
  sim:setCombat(false)
  equal(select(1, w:GetPoint()), "BOTTOM", "and moves once combat ends")
  w.scripts.OnDragStart(w)
  equal(moved, 1, "it can be dragged again")
  sim:assertHealthy()
end)

test("an unchanged callout panel formats no messages and keeps its layout", function()
  local sim = new("cata", { quickCalls = true, quickCallsDestinations = true, timers = false, flags = false })
  local Q = sim.ns.QuickCalls
  sim:join()
  local w = assert(Q.win)
  local messages, lists, sized = 0, 0, 0
  local Message, Destinations, SetWidth = Q.Message, Q.Destinations, w.SetWidth
  Q.Message = function(...) messages = messages + 1; return Message(...) end
  Q.Destinations = function(...) lists = lists + 1; return Destinations(...) end
  w.SetWidth = function(...) sized = sized + 1; return SetWidth(...) end
  sim:advance(5)
  equal(messages, 0, "no message formatted again")
  assert(lists <= 21, "the destination list is read once per update")
  equal(sized, 0, "no layout")
  assert(w.destination:SetValue("Farm"))
  equal(w.destinationButtons[2].fire.attrs.macrotext, "/i 2 enemies going to Farm", "a chosen destination is armed")
  sim:advance(0.5)
  messages = 0
  sim.env.GetSubZoneText = function() return "Blacksmith" end
  sim:event("ZONE_CHANGED")
  equal(messages, #w.buttons, "a new area makes the macros again")
  assert(sized > 0, "and lays out its new name")
  equal(w.buttons[3].fire.attrs.macrotext, "/i Need help — Blacksmith (2 enemies)")
  sim:assertHealthy()
end)
