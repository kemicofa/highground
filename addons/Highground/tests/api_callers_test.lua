-- Callers of moved game APIs reach them through ns.Api: namespaced-only
-- clients (Retail, WoW Forever) and globals-only paths (Cataclysm Classic)
-- both work. tests/test_api_compat.py keeps new direct reads out.
-- Run from addons/Highground.
local t = dofile("../../tools/harness.lua")("api callers")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")

local REMOVED = { "SendChatMessage", "GetSpellInfo", "GetSpellTexture", "IsRatedBattleground", "GuildRoster",
  "LoadAddOn", "GetAtlasInfo", "GetAddOnMemoryUsage", "UpdateAddOnMemoryUsage", "GetSpecialization",
  "GetSpecializationInfo", "IsHelpfulSpell", "SpellHasRange", "GetSpellSubtext", "PickupSpell" }

-- calls[name] = list of first arguments ("-" for none).
local function Recorder(calls, name, result)
  return function(first, ...)
    calls[name] = calls[name] or {}
    table.insert(calls[name], first == nil and "-" or first)
    if type(result) == "function" then return result(first, ...) end
    return result
  end
end

local function modern(calls)
  return new("retail", {}, function(sim, env)
    env.GetBuildInfo = function() return "x", "1", "Nov 22 2026", 16001 end
    for _, name in ipairs(REMOVED) do env[name] = nil end
    env.C_ChatInfo.SendChatMessage = Recorder(calls, "C_ChatInfo.SendChatMessage")
    env.C_PvP = env.C_PvP or {}
    env.C_PvP.IsRatedBattleground = Recorder(calls, "C_PvP.IsRatedBattleground", true)
    env.C_GuildInfo = env.C_GuildInfo or {}
    env.C_GuildInfo.GuildRoster = Recorder(calls, "C_GuildInfo.GuildRoster")
    env.C_AddOns = env.C_AddOns or {}
    env.C_AddOns.LoadAddOn = Recorder(calls, "C_AddOns.LoadAddOn", true)
    env.C_AddOns.UpdateAddOnMemoryUsage = Recorder(calls, "C_AddOns.UpdateAddOnMemoryUsage")
    env.C_AddOns.GetAddOnMemoryUsage = Recorder(calls, "C_AddOns.GetAddOnMemoryUsage", 2048)
    env.C_Texture = { GetAtlasInfo = Recorder(calls, "C_Texture.GetAtlasInfo", {}) }
    env.C_Spell.SpellHasRange = Recorder(calls, "C_Spell.SpellHasRange", true)
    env.C_Spell.IsSpellHelpful = Recorder(calls, "C_Spell.IsSpellHelpful", true)
    env.C_Spell.GetSpellSubtext = Recorder(calls, "C_Spell.GetSpellSubtext", "Rank 3")
    env.C_Spell.PickupSpell = Recorder(calls, "C_Spell.PickupSpell")
    env.C_Spell.GetSpellInfo = function(name) return { name = name, spellID = 116 } end
  end)
end

local function legacy(calls)
  return new("cata", {}, function(sim, env)
    env.GetBuildInfo = function() return "x", "1", "Nov 22 2026", 40402 end
    env.C_Spell, env.C_PvP, env.C_GuildInfo, env.C_Texture = nil, nil, nil, nil
    if env.C_AddOns then env.C_AddOns.LoadAddOn = nil end
    env.GetSpellInfo = function(name) return "Old " .. tostring(name), nil, nil, nil, nil, 30, 133 end
    env.GetSpellTexture = function(id) return "Old icon " .. tostring(id) end
    env.IsRatedBattleground = Recorder(calls, "IsRatedBattleground", true)
    env.GuildRoster = Recorder(calls, "GuildRoster")
    env.LoadAddOn = Recorder(calls, "LoadAddOn", true)
    env.GetAtlasInfo = Recorder(calls, "GetAtlasInfo", {})
  end)
end

t.test("namespaced-only clients reach every migrated caller", function()
  local calls = {}
  local sim = modern(calls)
  local ns, U = sim.ns, sim.ns.Util
  t.equal(U.SpellName(116), "Spell 116", "C_Spell.GetSpellName")
  t.equal(U.SpellTexture(116), "Interface\\Icons\\Spell116", "C_Spell.GetSpellTexture")
  t.equal(U.SpellID("Frostbolt"), 116, "spell ID from the C_Spell table")
  t.equal(ns.Core.IsRatedBG(), true, "C_PvP rated check")
  ns.Guild.RequestRoster()
  t.equal(#(calls["C_GuildInfo.GuildRoster"] or {}), 1, "C_GuildInfo roster request")
  ns.Organizations.Open()
  t.equal(calls["C_AddOns.LoadAddOn"] and calls["C_AddOns.LoadAddOn"][1], "Blizzard_Communities", "C_AddOns load")
  local icon = sim.env.UIParent:CreateTexture()
  ns.Kit.ClassIcon(icon, "MAGE")
  t.equal(calls["C_Texture.GetAtlasInfo"] and calls["C_Texture.GetAtlasInfo"][1], "classicon-mage", "C_Texture atlas lookup")
  local missing = table.concat(ns.Core.MissingAPI(), ",")
  assert(not missing:find("Specialization", 1, true), "moved spec APIs are found: " .. missing)
  assert(not missing:find("CombatLog", 1, true), "the combat log is not expected here: " .. missing)
  ns.Core.StartPerformance(function() end)
  ns.Core.StopPerformance()
  assert(#(calls["C_AddOns.GetAddOnMemoryUsage"] or {}) >= 2, "addon memory from C_AddOns")
  assert(ns.Api.SendChatMessage("hi", "SAY"), "chat send accepted")
  t.equal(calls["C_ChatInfo.SendChatMessage"][1], "hi", "C_ChatInfo chat")
  sim:assertHealthy()
end)

t.test("macro tools reach moved spell APIs through Macros.Host", function()
  local calls = {}
  local sim = modern(calls)
  local Ranks = sim.ns.Macros.Ranks
  t.equal(Ranks.HasRange("Frostbolt"), true, "C_Spell range")
  t.equal(select(2, Ranks.Of(116)), 3, "C_Spell subtext rank")
  sim.env.C_Spell.SpellHasRange = nil
  t.equal(Ranks.HasRange("Frostbolt"), false, "a C_Spell table without maxRange has no range")
  sim:assertHealthy()
end)

t.test("Cataclysm Classic globals still answer where namespaces are missing", function()
  local calls = {}
  local sim = legacy(calls)
  local ns, U = sim.ns, sim.ns.Util
  t.equal(U.SpellName(116), "Old 116", "global GetSpellInfo name")
  t.equal(U.SpellTexture(116), "Old icon 116", "global GetSpellTexture")
  t.equal(U.SpellID("Frostbolt"), 133, "spell ID: the global's 7th value")
  t.equal(ns.Core.IsRatedBG(), true, "global rated check")
  ns.Guild.RequestRoster()
  t.equal(#(calls.GuildRoster or {}), 1, "global roster request")
  ns.Organizations.Open()
  t.equal(calls.LoadAddOn and calls.LoadAddOn[1], "Blizzard_Communities", "global LoadAddOn")
  local icon = sim.env.UIParent:CreateTexture()
  ns.Kit.ClassIcon(icon, "MAGE")
  t.equal(calls.GetAtlasInfo and calls.GetAtlasInfo[1], "classicon-mage", "global atlas lookup")
  t.equal(sim.ns.Macros.Ranks.HasRange("Frostbolt"), true, "range from the global's 6th value")
  assert(ns.Api.SendChatMessage("hi", "SAY"), "the global chat send")
  t.equal(sim.chat[#sim.chat] and sim.chat[#sim.chat].text, "hi", "the global recorded it: " .. #sim.chat)
  sim:assertHealthy()
end)

t.finish("API callers: " .. t.tests .. " tests")
