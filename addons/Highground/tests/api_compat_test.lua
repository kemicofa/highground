-- ns.Api (libs/config/Client.lua): moved game APIs on Retail and WoW Forever
-- (namespaced only), Cataclysm Classic (older globals) and missing ones.
-- Run from addons/Highground.
local t = dofile("../../tools/harness.lua")("api compat")

-- Load the client file into its own global table, as the game would.
local function api(globals)
  local env = setmetatable(globals, { __index = _G })
  local ns = { CLIENT = "retail", GAME = "retail" }
  setfenv(assert(loadfile("libs/config/Client.lua")), env)("Highground", ns)
  return ns.Api, env
end

t.test("namespaced functions win and are looked up on every call", function()
  local sent = {}
  local A, env = api({
    C_AddOns = { GetAddOnMetadata = function(addon, field) return addon .. ":" .. field end },
    GetAddOnMetadata = function() error("the removed global must not be used") end,
    C_ChatInfo = { SendChatMessage = function(...) sent[#sent + 1] = { ... } end },
    C_Item = { GetItemCount = function() return 3 end, IsEquippedItem = function() return true end,
      GetItemNameByID = function(id) return "Item " .. id end },
    C_SpecializationInfo = { GetSpecialization = function() return 2 end,
      GetSpecializationInfo = function(i) return 260 + i, "Spec" end,
      GetNumSpecializationsForClassID = function() return 4 end },
  })
  t.equal(A.AddOnMetadata("Highground", "Version"), "Highground:Version", "C_AddOns metadata")
  t.equal(A.SendChatMessage("hi", "INSTANCE_CHAT"), true, "accepted")
  t.equal(sent[1][1] .. sent[1][2], "hiINSTANCE_CHAT", "namespaced chat send")
  t.equal(A.ItemCount("Healthstone"), 3, "C_Item count")
  t.equal(A.IsEquippedItem("Trinket"), true, "C_Item equipped")
  t.equal(A.ItemName(42), "Item 42", "item name by ID")
  t.equal(A.Specialization(), 2, "C_SpecializationInfo index")
  t.equal(A.SpecializationInfo(2), 262, "spec ID first")
  t.equal(A.NumSpecializationsForClassID(11), 4, "spec count")
  env.C_ChatInfo.SendChatMessage = function() return false end
  t.equal(A.SendChatMessage("hi", "SAY"), false, "a refused send is not accepted")
  env.C_ChatInfo.SendChatMessage = function() error("chat lockdown") end
  t.equal(A.SendChatMessage("hi", "SAY"), false, "an error is not accepted")
end)

t.test("older globals are the fallback and missing functions are harmless", function()
  local A = api({
    GetAddOnMetadata = function() return "1.0" end,
    SendChatMessage = function() end,
    GetItemCount = function() return "2" end,
    IsEquippedItem = function() return nil end,
    GetItemInfo = function(id) return "Old item " .. id end,
    GetSpecialization = function() return 1 end,
    GetSpecializationInfo = function(i) return 70 + i end,
    IsSpellKnown = function(id, pet) return id == 7 and pet == true end,
  })
  t.equal(A.AddOnMetadata("Highground", "Version"), "1.0", "global metadata")
  t.equal(A.SendChatMessage("hi", "SAY"), true, "global chat send")
  t.equal(A.ItemCount("Healthstone"), 2, "numbers from strings")
  t.equal(A.IsEquippedItem("Trinket"), false, "nil is false")
  t.equal(A.ItemName(9), "Old item 9", "GetItemInfo name")
  t.equal(A.SpecializationInfo(A.Specialization()), 71, "global specialization")
  t.equal(A.IsSpellKnown(7, true), true, "pet spell through the global")
  t.equal(A.IsSpellKnown(7), false, "not a player spell")
  local none = api({})
  t.equal(none.Fn("C_AddOns", "GetAddOnMetadata"), nil, "neither exists")
  t.equal(none.AddOnMetadata("Highground", "Version"), nil, "no metadata")
  t.equal(none.SendChatMessage("hi", "SAY"), false, "no send")
  t.equal(none.ItemCount("x"), 0, "no count")
  t.equal(none.IsSpellKnown(7, true), false, "no spellbook")
  t.equal(none.Specialization(), nil, "no specialization")
end)

t.test("C_SpellBook takes a spell bank instead of a pet flag", function()
  local asked = {}
  local A = api({
    Enum = { SpellBookSpellBank = { Player = 0, Pet = 1 } },
    C_SpellBook = { IsSpellKnown = function(id, bank) asked[#asked + 1] = bank; return id == 19647 and bank == 1 end },
    IsSpellKnown = function() error("the global must not be used") end,
  })
  t.equal(A.IsSpellKnown(19647, true), true, "pet bank")
  t.equal(A.IsSpellKnown(19647), false, "player bank")
  t.equal(asked[1] .. "," .. asked[2], "1,0", "banks passed")
end)

t.finish("API compat: " .. t.tests .. " tests")
