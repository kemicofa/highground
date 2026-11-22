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
local sent = #sim.sent
for _, def in ipairs(ns.LocaleDefinitions) do
  assert(adapter.SetPreference(def.key))
  assert(header:GetText() == l:Get("preferences.title"), "existing page title follows the language: " .. def.key .. ": " .. tostring(header:GetText()))
  assert(label:GetText() == private and input:GetText() == private, "reused labels and player input are never retranslated")
  assert(selected:GetValue() == "kept" and selected:GetText() == l:Get("locale.title"), "menu labels refresh without changing the choice")
  assert(macroBodies() == bodies, "translated labels must never alter executable macros: " .. def.key)
  assert(ns.Protocols.Encode(nil, 200) == protocol, "capability payload is language-independent")
  assert(B.Kills.Pack(nil) == evidence, "default kill evidence is a stable wire value")
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
sim:assertHealthy()
print(build .. ": all locale catalogs preserve commands, macros, data, bindings, guide and preview state")
