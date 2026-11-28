local test, new, check = ...
local function equal(a, b, why) check(a, b, why or "value") end

-- Another character on the same account: shares HighgroundDB, not CharDB.
local function Alt(sim, name, guid)
  sim:event("PLAYER_LOGOUT")
  return new("cata", sim.env.HighgroundDB, function(s, env)
    env.HighgroundCharDB = {}
    s.units.player.name, s.units.player.guid = name, guid
  end)
end
local function Back(sim, other, name, guid)
  other:event("PLAYER_LOGOUT")
  return new("cata", other.env.HighgroundDB, function(s, env)
    env.HighgroundCharDB = sim.env.HighgroundCharDB
    s.units.player.name, s.units.player.guid = name, guid
  end)
end
local function Find(list, name) for _, item in ipairs(list) do if item.name == name then return item end end end

test("every character keeps its own settings; a new one starts from the last one played", function()
  local sim = new("cata", nil, function(s) s.units.player.guid = "Player-1-A" end)
  local C = sim.ns.Core
  C.SetFeature("sniper", false); C.SetTuning("option", "nearbyRows", 7); sim.ns.Theme.Use("parchment")
  local alt = Alt(sim, "Kemi", "Player-1-B")
  local C2 = alt.ns.Core
  equal(C2.On("sniper"), false, "a new character copies the last one")
  equal(C2.O("nearbyRows"), 7)
  C2.SetFeature("sniper", true); C2.SetTuning("option", "nearbyRows", 3)
  local again = Back(sim, alt, "Me", "Player-1-A")
  local C3 = again.ns.Core
  equal(C3.On("sniper"), false, "the first character keeps its own")
  equal(C3.O("nearbyRows"), 7)
  equal(C3.db.theme, "parchment", "general preferences are per character too")
  again:assertHealthy()
end)

test("Copy into replaces one addon's settings, every battleground size included", function()
  local sim = new("cata", nil, function(s) s.units.player.guid = "Player-1-A" end)
  local C, CS = sim.ns.Core, sim.ns.CharacterSettings
  CS.Select("bg40"); C.SetFeature("sniper", false)
  CS.Select("bg10"); C.SetTuning("option", "nearbyRows", 9)
  local alt = Alt(sim, "Kemi", "Player-1-B")
  local C2, CS2 = alt.ns.Core, alt.ns.CharacterSettings
  C2.SetFeature("timers", false); C2.SetTuning("option", "nearbyRows", 4)
  local other = Find(CS2.Profiles("battlegrounds"), "Me")
  assert(other and other.kind == "character", "the other character is listed")
  assert(CS2.Copy(other.source, "battlegrounds"))
  equal(C2.On("timers"), true, "10v10 now matches Me's")
  equal(C2.O("nearbyRows"), 4, "Nearby is another addon")
  CS2.Select("bg40"); equal(C2.On("sniper"), false, "epic came along")
  assert(CS2.Copy(other.source, "nearby")); equal(C2.O("nearbyRows"), 9, "Nearby copies on its own")
  equal(select(1, CS2.Copy({ character = CS2.Key() }, "nearby")), false, "not from yourself")
  alt:setCombat(true); equal(select(1, CS2.Copy(other.source, "nearby")), false, "not in combat"); alt:setCombat(false)
  assert(CS2.Delete(other.source)); equal(Find(CS2.Profiles("battlegrounds"), "Me"), nil, "deleted")
  alt:assertHealthy()
end)

test("exports import under the sender's character name and old codes still import", function()
  local sim = new("cata")
  local C, CS = sim.ns.Core, sim.ns.CharacterSettings
  C.SetFeature("sniper", false)
  local code = CS.Export("battlegrounds")
  assert(code and code ~= "", "export")
  local ok, message = CS.Import(code, "Jaina")
  assert(ok and message:find("Jaina", 1, true))
  assert(CS.Import(code, "Jaina"))
  assert(Find(CS.Profiles("battlegrounds"), "Jaina (2)"), "names stay unique")
  equal(Find(CS.Profiles("nearby"), "Jaina"), nil, "a Battlegrounds export offers only Battlegrounds")
  C.SetFeature("sniper", true)
  assert(CS.Copy(Find(CS.Profiles("battlegrounds"), "Jaina").source, "battlegrounds"))
  equal(C.On("sniper"), false, "copying applies it")
  equal(select(1, CS.Import("not a code")), false, "invalid codes are refused")
  local legacy = sim.ns.Options.Profiles.ExportString(sim.ns.Options.Profiles.Snapshot(), "Old Main")
  assert(CS.Import(legacy))
  local old = Find(CS.Profiles("arena"), "Old Main")
  assert(old and Find(CS.Profiles("battlegrounds"), "Old Main"), "an old full profile offers every addon")
  sim:assertHealthy()
end)

test("named profiles from before become imports; Default, switching and layouts go", function()
  local saved = { profiles = { Default = { points = {} }, ["Arena setup"] = { points = { killPer = 7 }, weights = {}, specs = {}, options = {} } },
    activeProfile = "Arena setup", profileAssignments = { x = { arena = "Arena setup" } }, profileDefaultVersion = 2,
    sizeLayouts = { ["Player-1-A"] = { bg40 = { snap = { points = { killPer = 3 }, weights = {}, specs = {}, options = {} }, saved = 1 } } } }
  local sim = new("cata", saved, function(s, env)
    s.units.player.guid = "Player-1-A"
    env.HighgroundCharDB = { autoProfiles = true }
  end)
  local db, CS = sim.env.HighgroundDB, sim.ns.CharacterSettings
  equal(db.profiles, nil); equal(db.activeProfile, nil); equal(db.profileAssignments, nil)
  local item = Find(CS.Profiles("battlegrounds"), "Arena setup")
  assert(item and item.kind == "import", "kept as an import")
  equal(Find(CS.Profiles("battlegrounds"), "Default"), nil, "the built-in Default is gone")
  equal(sim.env.HighgroundCharDB.autoProfiles, nil)
  CS.Select("bg40"); equal(sim.ns.Core.db.points.killPer, 3, "a saved epic layout became epic's settings")
  equal(db.sizeLayouts["Player-1-A"], nil)
end)

test("the Profiles page copies, deletes, exports and imports for the chosen addon", function()
  local sim = new("cata", nil, function(s) s.units.player.guid = "Player-1-A" end)
  local C = sim.ns.Core
  C.SetFeature("sniper", false)
  local alt = Alt(sim, "Kemi", "Player-1-B")
  local C2 = alt.ns.Core
  C2.SetFeature("sniper", true)
  alt.ns.Hub.Open("profiles")
  local p = alt.ns.Options.panel
  assert(p.addons:IsVisible() and p.addons.byKey.battlegrounds and p.addons.byKey.shared, "addon choice")
  equal(p.items[1].kind, "self"); assert(not p.rows[1].copy:IsShown(), "no copy onto yourself")
  local row = p.rows[2]
  equal(row.item.name, "Me")
  row.copy:Click(); equal(C2.On("sniper"), true, "the first click only arms")
  row.copy:Click(); equal(C2.On("sniper"), false, "the second copies")
  assert(p.status:GetText():find("Copied Me", 1, true))
  p.addons.byKey.nearby:Click(); equal(p.addon, "nearby")
  p.export:Click()
  local export = alt.env.HighgroundProfileExport
  assert(export:IsShown() and export:GetText() ~= "", "export shows a code")
  local code = export:GetText(); export:Hide()
  p.import:Click()
  local import = alt.env.HighgroundProfileImport
  import.box:SetText(code); import.actions.add:Click()
  assert(import.status:GetText():find("Kemi", 1, true), "named after this character's export")
  import:Hide()
  alt.ns.Hub.Open("profiles")
  local imported
  for _, r in ipairs(p.rows) do if r:IsShown() and r.item.kind == "import" then imported = r end end
  assert(imported, "the import is listed")
  imported.delete:Click(); imported.delete:Click()
  for _, r in ipairs(p.rows) do assert(not (r:IsShown() and r.item.kind == "import"), "deleted") end
  alt.ns.Core.SetFontScale(1.5); p.LayoutProfiles()
  alt:assertHealthy()
end)

test("/hg profile, export and import match the page", function()
  local sim = new("cata", nil, function(s) s.units.player.guid = "Player-1-A" end)
  sim.ns.Core.SetFeature("sniper", false)
  local alt = Alt(sim, "Kemi", "Player-1-B")
  alt.ns.Core.SetFeature("sniper", true)
  alt:command("profile battlegrounds")
  assert(alt.messages[#alt.messages]:find("Me", 1, true), "lists profiles")
  alt:command("profile copy battlegrounds me")
  equal(alt.ns.Core.On("sniper"), false, "copies by name, any case")
  local code = alt.ns.CharacterSettings.Export("shared")
  alt:command("import " .. code)
  assert(alt.messages[#alt.messages]:find("Kemi", 1, true), "imports")
  alt:command("profile delete Kemi")
  assert(alt.messages[#alt.messages]:find("Deleted Kemi", 1, true))
  alt:command("profile copy nowhere me")
  assert(alt.messages[#alt.messages]:find("/hg profile", 1, true), "usage")
  alt:command("export arena"); assert(alt.env.HighgroundProfileExport:IsShown())
  alt:assertHealthy()
end)
