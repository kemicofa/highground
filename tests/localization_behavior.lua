-- Full catalogs in the combined host: localized display must not change data.
local client, build = arg[1], tonumber(arg[2])
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local sim = new(client, {}, function(s, env)
  env.GetLocale = function() return "enUS" end
  env.GetBuildInfo = function() return "1", "1", "date", build end
  dofile("../../tools/wowsim/geometry.lua")(s)
end)
local ns, C, M, B = sim.ns, sim.ns.Core, sim.ns.Macros, sim.ns.Bounty
local l, adapter = ns.Locale, ns.Localization
local function macroBodies()
  local out = {}
  for _, entry in ipairs(M.catalog) do
    for _, game in ipairs({ "cata", "retail", "forever", "classic", "tbc" }) do
      out[#out + 1] = entry.name .. "\n" .. (M.Build(entry, game) or "")
    end
  end
  out[#out + 1] = M.Scripts.Buy("Test Item", 3, "cata")
  out[#out + 1] = M.Scripts.Buy("Test Item", 3, "classic")
  return table.concat(out, "\n")
end
local bodies, protocol = macroBodies(), ns.Protocols.Encode(nil, 200)
local evidence = B.Kills.Pack(nil)
local buttons = {}
for _, group in ipairs(ns.CommandCatalog.groups) do
  for _, row in ipairs(group.commands) do buttons[row.id] = row[1] .. "\n" .. table.concat(row.aliases or {}, "\n") end
end
ns.Hub.Open("general")
local header = ns.Options.general.title
local label = ns.Theme.Text(ns.Hub.win, "body")
adapter.Bind(label, "locale.title")
label:SetText("Open · player-authored {name} 100%")
local selected = ns.Kit.Select(ns.Hub.win, { choices = {
  adapter.Define({ key = "kept" }, { label = "locale.title" }),
}, value = "kept" })
local private = "Open · player-authored {name} 100%"
local input = ns.Kit.Input(ns.Hub.win, 200, "")
input:SetText(private)
local profileRows = ns.Options.Profiles.Review(ns.Options.Profiles.Snapshot())
ns.Hub.Open("bounties-previews")
local previews = ns.Options.byKey["bounties-previews"].previews
local sceneCommands = {}
for _, scene in ipairs(B.Preview.scenes) do sceneCommands["bounty test " .. scene.key] = true end
ns.Hub.Open("general")
local function checkMapLookups()
  local T, I, configs = ns.Timers, ns.Intel, ns.BattlegroundConfigs
  local rules, mapID, getBG, landmarks = T.Rules, T.MapID, ns.GetBG, I.Landmarks
  T.Rules = function() return configs.alterac_valley.rules end
  assert(T.HasGraveyard("Stormpike Aid Station") and T.HasGraveyard("Frostwolf Relief Hut"),
    "translated addon text preserves English-client graveyard matching")
  T.Rules = function() return configs.arathi_basin.rules end
  assert(T.HasGraveyard("Lumber Mill") and T.HasGraveyard("Gold Mine"))
  T.Rules = function() return configs.eye_of_the_storm.rules end
  assert(T.HasGraveyard("Fel Reaver Ruins") and T.HasGraveyard("Blood Elf Tower"))
  I.Landmarks = function() return {} end
  ns.GetBG = function() return { ui = { 275 }, rules = configs.battle_for_gilneas.games.cata.rules } end
  local x, y = I.AreaXY(275, "Lighthouse")
  assert(x == 0.35904251 and y == 0.62878461, "capture fallback locations preserve game matching names")
  T.Rules = function() return configs.twin_peaks.rules end
  T.MapID = function() return 206 end
  ns.GetBG = function() return { ui = { 206 }, rules = configs.twin_peaks.rules } end
  assert(T.SideName({ x = 0.58, y = 0.2 }), "translated side labels still locate the base")
  assert(table.concat(configs.deepwind_gorge.rules.callouts.destinations, ",") == "Market,Farm,Ruins,Shrine,Quarry",
    "fallback destinations remain compatible with client POI names")
  local quick, intelMap = ns.QuickCalls.Battleground, I.MapID
  ns.QuickCalls.Battleground = function() return { ui = { 93 }, rules = configs.arathi_basin.rules } end
  I.MapID = function() return 93 end
  I.Landmarks = function()
    return { { name = "Stables" }, { name = "Farm" }, { name = "Blacksmith" }, { name = "Lumber Mill" }, { name = "Gold Mine" } }
  end
  assert(#ns.QuickCalls.Destinations(false) == 5, "addon language cannot duplicate client callout destinations")
  ns.QuickCalls.Battleground, I.MapID = quick, intelMap
  T.Rules, T.MapID, ns.GetBG, I.Landmarks = rules, mapID, getBG, landmarks
end
local resolvedBG = ns.ResolveBattleground(206, 726, "cata")
ns.Core.SetFontScale(1.5)
local sent = #sim.sent
for _, def in ipairs(ns.LocaleDefinitions) do
  assert(adapter.SetPreference(def.key))
  assert(header:GetText() == l:Get("preferences.title"), "existing page title follows the language: " .. def.key .. ": " .. tostring(header:GetText()))
  assert(label:GetText() == private and input:GetText() == private, "reused labels and player input are never retranslated")
  assert(selected:GetValue() == "kept" and selected:GetText() == l:Get("locale.title"), "menu labels refresh without changing the choice")
  assert(l:Format("profiles.workspace.profile_title", { name = private }) == private,
    "a profile title preserves the author's exact name")
  assert(macroBodies() == bodies, "translated labels must never alter executable macros: " .. def.key)
  assert(ns.Protocols.Encode(nil, 200) == protocol, "capability payload is language-independent")
  assert(B.Kills.Pack(nil) == evidence, "default kill evidence is a stable wire value")
  checkMapLookups()
  assert(resolvedBG.name == ns.BattlegroundConfigs.twin_peaks.name, "cached battleground display names follow the language")
  local advertised = 0
  for _, button in ipairs(previews) do
    if button.definition.active then
      assert(sceneCommands[button.cmd], "bounty preview tooltips retain executable command syntax")
      advertised = advertised + 1
    end
  end
  assert(advertised == #B.Preview.scenes, "every bounty scene advertises its command")
  for _, row in ipairs(profileRows) do
    local key = "profiles.group." .. row.group:lower():gsub(" ", "_")
    local _, _, _, group = ns.Options.Profiles.ReviewFields(row)
    assert(group == l:Get(key) and group ~= key, "retained profile groups resolve through stable identifiers")
    if row.id == "preferences.scale" then
      assert(ns.Options.Profiles.ReviewFields(row) == l:Get("highground.profilesummary.interface_scale.0e06dc"),
        "retained profile labels follow the language without changing values")
    end
  end
  for _, profiles in pairs(ns.SpecsByIndex or {}) do
    for _, profile in ipairs(profiles) do
      assert(({ phys = true, magic = true, mixed = true })[profile.dmg], "damage type remains gameplay data")
    end
  end
  for _, group in ipairs(ns.CommandCatalog.groups) do
    for _, row in ipairs(group.commands) do assert(row[1] .. "\n" .. table.concat(row.aliases or {}, "\n") == buttons[row.id], "command syntax and aliases never change") end
  end
  local row = { name = "Example-Realm", personal = { name = "Example-Realm", by = B.Me() } }
  assert(B.BoardActions.PrimaryKey(row) == "highground.coachbountysamples.edit_reward.0854ae")
  assert(B.BoardActions.Primary(row) == l:Get(B.BoardActions.PrimaryKey(row)))
  assert(type(B.BoardActions.Help(row)) == "string", "action help uses stable IDs")
  local opened, open = nil, B.Form.Open
  B.Form.Open = function(name, scope) opened = { name, scope } end
  B.BoardActions.Run(nil, row)
  B.Form.Open = open
  assert(opened and opened[1] == row.name and opened[2] == "personal", "localized action still opens its owned editor")
  assert(C.PIP.immune[1] == l:Get("highground.coachtargeting.immune.4c42ca"), "cached HUD chips follow the language")
  assert(B.Widgets.STATE.pending[1] == l:Get("shared.widgets.pending.0a7b38"), "cached bounty badges follow the language")
  local geom = { C.PanelGeometry("arena") }
  for i = 1, 4 do assert(type(geom[i]) == "number", "layout metric keys are never translated") end
  ns.Hub.Open("battlegrounds-commands")
  ns.Hub.Open("profiles")
  ns.Options.panel.SelectProfile("Default")
  local panel = ns.Options.panel
  assert(panel.listScroll:GetHeight() > 0, "profile choices remain reachable with translated controls")
  for _, key in ipairs({ "Import", "Export", "Chat" }) do
    local button, area = sim.bounds(panel.profileButtons[key]), sim.bounds(panel.footer)
    assert(button[1] >= area[1] and button[1] + button[3] <= area[1] + area[3] + 1,
      "translated profile actions fit inside the footer")
  end
  ns.Hub.Open("general")
  sim:assertHealthy()
end
assert(#sim.sent == sent, "changing display language never sends data")
assert(adapter.SetPreference("frFR"))
assert(l:Get("locale.title") == "Langue", "this test uses the shipped French catalog")
assert(ns.CommandCatalog.groups[2].label ~= "Battlegrounds", "owning-addon command heading is translated")
assert(ns.Options.byKey["arena-settings"].name ~= "Arena: Settings", "generated page names refresh after login")
ns.Onboarding.Start("features")
local coach = ns.Onboarding.Coach
local before, body = coach.index, coach.win.body:GetText()
assert(adapter.SetPreference("deDE"))
assert(coach.running and coach.index == before, "switching language does not restart or advance a guide")
assert(coach.win.body:GetText() ~= body, "an open guide translates its current step")
ns.Core.SetFontScale(1.5)
for _, button in ipairs({ coach.win.done, coach.win.replay, coach.win.back, coach.win.next }) do
  local bounds, parent = sim.bounds(button), sim.bounds(coach.win)
  assert(bounds[1] >= parent[1] and bounds[1] + bounds[3] <= parent[1] + parent[3] + 1,
    "long guide buttons remain inside the window at large text size")
end
ns.Onboarding.Return()
assert(not coach.running)
sim:command("test"); sim:advance(0.2)
assert(ns.PreviewTests.AllActive(), "translated preview starts through its original command")
sim:command("test stop")
assert(not ns.PreviewTests.AnyActive() and not B.Preview.state, "preview cleanup preserves live state")
ns.Hub.Open("profiles")
ns.Options.panel.SelectProfile("Default")
local body = ns.Options.panel.defaultInfo.body
local view, footer = sim.bounds(body.view), sim.bounds(ns.Options.panel.footer)
assert(view[2] + view[4] <= footer[2], "long translated Default help stays above the profile actions")
assert(body.range > 0, "long Default help remains available by scrolling at large text size")
body:Scroll(body.range)
assert(body.offset == body.range, "the last translated paragraph is reachable")
sim:assertHealthy()
print(build .. ": all locale catalogs preserve commands, macros, data, bindings, guide and preview state")
