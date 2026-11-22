local test, new, check = ...
local function equal(a, b, why) return check(a, b, why or "values match") end
local function click(b) b.scripts.OnClick(b) end
local function save(sim, name)
  sim.ns.Hub.Open("profiles")
  local p = sim.ns.Options.panel
  if sim.ns.Core.db.profiles and sim.ns.Core.db.profiles[name] then
    p.SelectProfile(name)
    click(p.profileButtons.Update)
  else p.NewProfile(); p.profileName:SetText(name) end
  click(p.profileButtons.Save)
end
local function state(sim, name, modified)
  local value = sim.ns.Options.Profiles.ActiveState()
  equal(value.name, name, "active profile name")
  if name then equal(value.modified, modified, "active setup compared with the saved copy") end
  return value
end

for _, client in ipairs({ "cata", "retail" }) do
test(client .. " current profile stays visible across settings and updates after edits", function()
  local sim = new(client, {})
  local C, P = sim.ns.Core, sim.ns.Options.Profiles
  save(sim, "My healer")
  state(sim, "My healer", false)
  local bar = sim.ns.Hub.win.profileContext
  for _, key in ipairs({ "general", "appearance", "alerts", "setup", "behavior", "tracking", "profiles" }) do
    sim.ns.Hub.Open(key)
    assert(bar:IsVisible(), "the hub keeps a fixed profile indicator on " .. key)
    equal(bar.label.text, "Settings from: My healer")
  end
  C.SetFeature("sniper", false); sim:advance(0.6)
  equal(bar.state.text, "Edited since applying")
  state(sim, "My healer", true)
  equal(C.db.profiles["My healer"].setup.features.sniper, true, "editing does not silently update the saved copy")
  P.SaveProfile("Another setup")
  sim.ns.Options.panel.RefreshProfiles()
  sim.ns.Options.panel.savedProfiles:SetValue("Another setup")
  state(sim, "My healer", true)
  save(sim, "My healer")
  state(sim, "My healer", false); equal(bar.state.text, "Matches saved profile")
  C.SetFeature("sniper", true); assert(P.LoadProfile("My healer"))
  state(sim, "My healer", false); equal(C.db.sniper, false)
  sim:assertHealthy()
end)
end

test("legacy callout channels do not affect profile loading, import or modified status", function()
  local sim = new("cata", { objectiveChannel = "s" })
  local C, P = sim.ns.Core, sim.ns.Options.Profiles
  C.SetFeature("quickCalls", true)
  save(sim, "Old battleground setup")
  local legacy = C.db.profiles["Old battleground setup"]
  legacy.setup.preferences.objectiveChannel = "raid"
  state(sim, "Old battleground setup", false)
  C.db.objectiveChannel = "party"
  state(sim, "Old battleground setup", false)
  C.SetFeature("quickCalls", false)
  state(sim, "Old battleground setup", true)
  assert(P.LoadProfile("Old battleground setup"))
  equal(C.db.quickCalls, true)
  equal(C.db.objectiveChannel, "party", "retired setting is not restored")
  state(sim, "Old battleground setup", false)
  C.SetFeature("quickCalls", false)
  assert(P.ImportText(P.ExportString(legacy)))
  equal(C.db.quickCalls, true, "legacy imports retain Quick callouts")
  equal(P.Snapshot().setup.preferences.objectiveChannel, nil, "retired setting is no longer exported")
  sim:assertHealthy()
end)

test("restoring defaults clears Modified across appearance, alerts and HUD positions", function()
  local sim = new("cata", {})
  local C, P = sim.ns.Core, sim.ns.Options.Profiles
  save(sim, "Default layout")
  C.SetFontScale(1.2); state(sim, "Default layout", true)
  C.SetFontScale(1); state(sim, "Default layout", false)
  C.SetPanelScale("main", 1.1); state(sim, "Default layout", true)
  C.SetPanelScale("main", 1); state(sim, "Default layout", false)
  C.SetElement("hero", true); state(sim, "Default layout", true)
  C.SetElement("hero", false); state(sim, "Default layout", false)
  sim.ns.Alerts.Settings().channels.capture = { sound = false }
  state(sim, "Default layout", true)
  sim.ns.Alerts.Settings().channels.capture.sound = true
  state(sim, "Default layout", false)
  local point = C.pos.arenaPoint
  C.pos.arenaPoint = { "CENTER", "CENTER", 140, -100 }
  state(sim, "Default layout", true)
  C.pos.arenaPoint = point; state(sim, "Default layout", false)
  sim.ns.Theme.Use("parchment"); state(sim, "Default layout", true)
  assert(P.LoadProfile("Default layout")); state(sim, "Default layout", false)
end)

test("changes to records, other profiles and switching rules do not mark the active profile modified", function()
  local sim = new("cata", {})
  local C, P = sim.ns.Core, sim.ns.Options.Profiles
  save(sim, "My setup")
  C.db.history = { { outcome = "win" } } -- legacy records outside profiles
  C.db.profileAssignments = { Other = { bg = "Elsewhere" } }
  C.db.hubSection = "history"
  C.pos.autoProfiles = true
  P.SaveProfile("Another copy")
  state(sim, "My setup", false)
end)

test("profile indicators describe imported copies and never retain the previous profile name", function()
  local sim = new("retail", {})
  local P, C = sim.ns.Options.Profiles, sim.ns.Core
  save(sim, "Original")
  local snap = P.Snapshot(); snap.setup.features.sniper = false
  local exported = P.ExportString(snap, "Friend's healer")
  assert(P.ImportText(exported))
  local current = state(sim, nil)
  equal(current.label, "Imported settings: Friend's healer"); equal(current.status, "Not saved as a profile")
  equal(C.db.activeProfile, nil)
  assert(P.SaveImported(exported, "Saved for later"))
  equal(P.ActiveState().status, "Not saved as a profile", "saving an import alone does not switch active settings")
  save(sim, "My edited healer")
  state(sim, "My edited healer", false); equal(C.db.importedProfileName, nil)
  P.DeleteProfile("My edited healer"); P.RefreshContext()
  equal(P.ActiveState().status, "Saved automatically")
end)

test("combat queues keep showing the current profile until the requested setup actually applies", function()
  local sim = new("cata", {})
  local P, C = sim.ns.Options.Profiles, sim.ns.Core
  save(sim, "First")
  C.SetFeature("sniper", false); save(sim, "Second")
  assert(P.LoadProfile("First"))
  sim:setCombat(true); assert(P.LoadProfile("Second"))
  local current = state(sim, "First", false)
  equal(current.pending, "Second"); equal(current.status, "Applies after combat")
  sim:setCombat(false); state(sim, "Second", false)
  local text = P.ExportString(C.db.profiles.First, "Imported")
  sim:setCombat(true); assert(P.ImportText(text))
  current = state(sim, "Second", false)
  equal(current.pending, "Imported")
  sim:setCombat(false)
  equal(P.ActiveState().label, "Imported settings: Imported"); equal(P.ActiveState().status, "Not saved as a profile")
end)

test("named profile context survives reload and automatic profile changes", function()
  local sim = new("cata", {})
  save(sim, "Main")
  local P, C = sim.ns.Options.Profiles, sim.ns.Core
  C.SetFeature("sniper", false); P.SaveProfile("Arena")
  assert(P.LoadProfile("Main")); assert(P.Assign("Arena", "arena")); C.pos.autoProfiles = true
  sim:joinArena(); state(sim, "Arena", false)
  local again = new("cata", sim.env.HighgroundDB)
  state(again, "Arena", false)
  again.ns.Core.SetFeature("sniper", true)
  local changed = new("cata", again.env.HighgroundDB)
  state(changed, "Arena", true)
end)

test("legacy tuning profiles only compare the settings they contain", function()
  local sim = new("cata", {})
  local P = sim.ns.Options.Profiles
  assert(P.SaveImported("WB1;n=Old;o.executePct=0.15", "Old"))
  assert(P.LoadProfile("Old")); state(sim, "Old", false)
  sim.ns.Core.SetElement("hero", false); state(sim, "Old", false)
  sim.ns.Core.SetTuning("option", "executePct", 0.2); state(sim, "Old", true)
end)

test("standalone and Blizzard settings retain context without duplicate embedded footers", function()
  local sim = new("cata", {})
  local O, P = sim.ns.Options, sim.ns.Options.Profiles
  O.general.frame:Show()
  assert(not O.general.frame.profileContext:IsVisible(), "there is no profile footer until a player uses profiles")
  save(sim, "My setup")
  sim.ns.Hub.Open("general")
  assert(not O.general.frame.profileContext:IsVisible())
  assert(sim.ns.Hub.win.profileContext:IsVisible())
  sim.ns.Hub.win:Hide(); O.general.frame:Show()
  assert(O.general.frame.profileContext:IsVisible())
  local alerts = sim.ns.Alerts.Open()
  assert(alerts.profileContext:IsVisible())
  sim.ns.Hub.Open("alerts"); assert(not alerts.profileContext:IsVisible())
  sim.ns.Alerts.Open(); assert(alerts.profileContext:IsVisible())
  O.panel.profileName:SetText("Another saved copy")
  click(alerts.profileContext)
  equal(sim.ns.Hub.current, "profiles"); assert(not alerts:IsVisible(), "profile navigation closes the standalone dialog")
  equal(O.panel.profileName:GetText(), "My setup", "the footer takes you to the profile being edited")
  local setup = sim.ns.Setup.Open()
  assert(setup.profileContext:IsVisible())
  assert(P.OpenAssignments():IsVisible(), "switching is embedded on Profiles")
  P.ShowExport("My setup"); assert(P.share.profileContext:IsVisible())
  sim:assertHealthy()
end)

test("profile explanations and shared reviews remain readable at large text sizes", function()
  local sim = new("cata", {}, function(s) dofile("../../tools/wowsim/geometry.lua")(s) end)
  local P, O = sim.ns.Options.Profiles, sim.ns.Options
  sim.ns.Core.SetFontScale(1.5); save(sim, "Healer for battlegrounds and arena")
  local function below(a,b) local x,y=sim.bounds(a),sim.bounds(b);assert(x[2]+x[4]<=y[2],"text and actions do not overlap") end
  local bar = sim.ns.Hub.win.profileContext
  local y = sim.bounds(bar)[2]
  O.panel.profileScroll:Scroll(220)
  equal(sim.bounds(bar)[2],y,"context does not scroll with settings")
  P.Chat.Review(P.ExportString(P.Snapshot(),"Healer"),"Friend-Realm","Healer")
  local w=P.Chat.win
  assert(w.summary:GetStringHeight()<=w.summary:GetHeight())
  below(w.summary,w.reviewTitle);below(w.review,w.name.caption);below(w.apply,w.profileContext)
  assert(w.summary.text:find(O.PROFILE_EXCLUSIONS,1,true))
  equal(#w.rows,1,"large text is the only difference from Default")
  equal(w.rows[1].id,"style.fontScale")
  click(w.details);assert(#w.rows>100,"All settings includes the complete shared setup")
end)

for _,scale in ipairs({1,1.5})do
test("profile actions and switching stay visible while the full review scrolls at " .. scale * 100 .. "% text",function()
  local sim=new("cata",{},function(s)dofile("../../tools/wowsim/geometry.lua")(s)end)
  sim.ns.Core.SetFontScale(scale);save(sim,"My setup")
  local p=sim.ns.Options.panel
  click(p.profileButtons.Details)
  local scroll=p.profileScroll
  assert(scroll.range>0 and scroll.bar:IsVisible(),"complete settings have a visible scrollbar")
  local controls={p.assignments,p.profileButtons.Load,p.profileButtons.Copy,p.profileButtons.Import,p.profileButtons.Export,p.profileButtons.Chat}
  local positions={};for i,c in ipairs(controls)do positions[i]=sim.bounds(c)[2] end
  scroll:Scroll(scroll.range)
  for i,c in ipairs(controls)do equal(sim.bounds(c)[2],positions[i],"actions do not scroll");assert(c:IsVisible())end
  sim.ns.Core.SetFeature("sniper",false);p.RefreshProfiles();click(p.profileButtons.Update);click(p.profileButtons.Save)
  equal(sim.ns.Core.db.profiles["My setup"].setup.features.sniper,false,"save remains usable")
  sim:assertHealthy()
end)
end
