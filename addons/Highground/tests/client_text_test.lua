-- Display text from the game client or the catalogs instead of English data:
-- spell names by ID, audience labels and capitals for every alphabet.
local t = dofile("../../tools/harness.lua")("client text")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local test, equal = t.test, t.equal

local GERMAN = { [1856] = "Verschwinden", [110959] = "Größere Unsichtbarkeit", [605] = "Gedankenkontrolle" }
local function german(sim) sim.env.C_Spell.GetSpellName = function(id) return GERMAN[id] end end

test("stealth messages use the client's spell name, English when it has none", function()
  local sim = new("retail")
  local S = sim.ns.Stealth
  german(sim)
  equal(S.Name(110959), "Größere Unsichtbarkeit", "client name by spell ID")
  local e = { name = "Sneaky-Realm", class = "ROGUE" }
  S.Hid(e, 1856)
  equal(e.hidden.spell, "Verschwinden", "remembered for the fade message")
  sim.env.C_Spell.GetSpellName = function() return nil end
  equal(S.Name(110959), "Greater Invisibility", "English fallback")
  equal(S.Name(12345), nil, "not a hiding spell")
end)

test("kill preferences named after a spell use the client's name", function()
  local sim = new("retail")
  local T = sim.ns.Bounty.Terms
  german(sim)
  local control
  for _, m in ipairs(T.methods) do if m.id == "control" then control = m end end
  equal(T.Label(control), "Gedankenkontrolle", "client name")
  equal(T.Methods({ killMethods = "fall.control" }):find("Gedankenkontrolle", 1, true) ~= nil, true, "in the summary")
  sim.env.C_Spell.GetSpellName = function() return nil end
  equal(T.Label(control), "Mind Control", "English fallback")
end)

test("bounty audiences and capitals follow the chosen language", function()
  local sim = new("retail")
  local ns = sim.ns
  assert(ns.Localization.SetPreference("deDE"))
  local P = ns.Bounty.Pot
  equal(P.AudienceLabel("guild"), "Gilde", "guild")
  equal(P.AudienceLabel("community"), ns.Locale:Get("shared.pot.community.bfd58e"), "community")
  equal(P.AudienceLabel("private"), ns.Locale:Get("shared.boardmodel.only_me.7631b1"), "private")
  equal(P.AudienceLabel("global"), ns.Locale:Get("shared.form.shared.50d0d8"), "global")
  equal(P.AudienceLabel("other"), "other", "unknown values stay")
  local parent = sim.env.CreateFrame("Frame")
  equal(ns.Kit.Section(parent, "Größe"):GetText(), "GRÖßE", "section titles")
  equal(ns.Kit.Caption(parent, "Арена"):GetText(), "АРЕНА", "captions")
end)

t.finish("Client text: " .. t.tests .. " scenarios, " .. t.failures .. " failures")
