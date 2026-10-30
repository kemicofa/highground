local test, new, check = ...
local function equal(a, b, why) return check(a, b, why or "values match") end
local function click(button) button.scripts.OnClick(button, "LeftButton") end

for _, game in ipairs({ "cata", "retail", "forever" }) do
test(game .. " quick buttons send the selected count and current area directly, including in combat", function()
  local area = "Farm"
  local sim = new(game == "cata" and "cata" or "retail", nil, function(_, env)
    env.GetSubZoneText = function() return area end
    if game == "forever" then env.GetBuildInfo = function() return "1.60.1", "1", "", 16001 end end
    if game ~= "cata" then
      env.C_ChatInfo.SendChatMessage, env.SendChatMessage = env.SendChatMessage, nil
    end
  end)
  local C, Q = sim.ns.Core, sim.ns.QuickCalls
  sim:join(); sim:setCombat(true)
  equal(Q.win, nil, "new feature is off until enabled")
  C.SetFeature("quickCalls", true)
  local w = assert(Q.win)
  assert(w:IsShown() and not w.secure, "ordinary buttons appear during combat")
  equal(w.area.text, "Farm")
  C.db.objectiveChannel = "s"
  sim.env.ChatFrame_OpenChat("/w Friend unfinished message")
  for i, suffix in ipairs({ "", " (1 enemy)", " (2 enemies)", " (3+ enemies)" }) do
    click(w.buttons[i])
    equal(#sim.chat, i, "one message per click, no Enter")
    equal(sim.chat[i].text, "Need help — Farm" .. suffix)
    equal(sim.chat[i].channel, "INSTANCE_CHAT", "quick buttons always address the battleground")
    equal(sim.chatDraft, "/w Friend unfinished message", "existing draft stays intact")
    equal(w.buttons[i]:IsEnabled(), false, "brief cooldown blocks double clicks")
    equal(Q.Send(1), false)
    sim:advance(2.3)
    equal(#sim.chat, i, "updates never send messages")
    assert(w.buttons[i]:IsEnabled())
  end
  area = "Blacksmith" -- Click before the next area event or timer tick.
  click(w.buttons[3])
  equal(sim.chat[5].text, "Need help — Blacksmith (2 enemies)")
  equal(w.area.text, "Blacksmith", "label catches up with the current area")
  C.SetFeature("quickCalls", false)
  assert(not w:IsShown(), "turning off hides immediately in combat")
  equal(Q.Send(1), false)
  sim:setCombat(false); sim:leave()
  equal(#sim.chat, 5)
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
  equal(Q.Send(1), false)
  area, minimap = "", "Lumber Mill"
  sim:event("ZONE_CHANGED_INDOORS")
  assert(w:IsShown()); equal(w.area.text, "Lumber Mill", "minimap area fallback")
  area = "Ferme"
  sim:event("ZONE_CHANGED")
  equal(w.area.text, "Ferme", "localized names are preserved")
  sim:leave(); assert(not w:IsShown()); equal(Q.Send(1), false)
  sim:joinArena(); assert(not w:IsShown()); equal(Q.Send(1), false)
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
    sim.ns.Options.general.group:SetValue("Battleground")
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
  equal(Q.Send(2), false); equal(#sim.chat, 0, "preview cannot send")
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

test("unavailable battleground chat and failed sends never fall back or queue messages", function()
  local sim = new("cata", { quickCalls = true })
  local Q = sim.ns.QuickCalls
  sim.env.GetSubZoneText = function() return "Farm" end
  sim:join()
  equal(Q.Send("4"), false)
  sim.env.IsInGroup = function(category) return category ~= sim.env.LE_PARTY_CATEGORY_INSTANCE end
  sim.env.IsInRaid = function() return true end
  equal(Q.Send(1), false, "premade raid is not the battleground channel")
  sim.env.IsInGroup = function() return true end
  local send = sim.env.SendChatMessage
  sim.env.SendChatMessage = nil
  equal(Q.Send(1), false)
  sim.env.SendChatMessage = function() error("unavailable") end
  equal(Q.Send(1), false)
  sim.env.SendChatMessage = send
  sim:advance(3); equal(#sim.chat, 0, "failed sends are not retried")
  assert(Q.Send(1), "a failed send does not consume the cooldown")
  sim:assertHealthy()
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
