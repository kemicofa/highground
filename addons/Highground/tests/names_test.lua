local t = dofile("../../tools/harness.lua")("names")

-- Real Names.lua with a stub client: UnitName, secrets and the Forever ruleset.
local secret = setmetatable({}, { __tostring = function() return "secret" end })
local function Fixture(caps, realm)
  local env = setmetatable({ issecretvalue = function(v) return v == secret end }, { __index = _G })
  local ns = { Caps = caps, Core = { myRealm = realm }, Util = {} }
  ns.Util.plain = function(v) return v ~= nil and v ~= secret end
  ns.Scope = { Ruleset = function() return "PvP" end }
  setfenv(assert(loadfile("libs/core/Names.lua")), env)("Highground", ns)
  return ns.Core, ns
end

t.test("same-realm names drop the suffix and other realms keep it", function()
  local C = Fixture({}, "Home")
  t.equal(C.DisplayName("Mage-Home"), "Mage", "own realm hidden")
  t.equal(C.DisplayName("Mage-Other Realm"), "Mage-OtherRealm", "other realm kept without spaces")
  t.equal(C.DisplayName("Mage"), "Mage", "no realm means ours")
  t.equal(C.DisplayName("Mage-Other Realm", true), "Mage-Other Realm", "detailed views keep the original label")
  t.equal(C.DisplayName("Mage-Home", true), "Mage-Home", "and the own realm when asked")
  t.equal(C.DisplayName(""), "", "empty name")
  t.equal(C.DisplayName(nil), "", "missing name")
  t.equal(C.DisplayName(42), "", "non-string name")
end)

t.test("WoW Forever keeps two-part names whole and hides the ruleset", function()
  local C = Fixture({ rulesetRealms = true, hideRealmNames = true }, "")
  t.equal(C.DisplayName("Owner Bright-PvP"), "Owner Bright", "first and last name kept")
  t.equal(C.DisplayName("Owner Bright"), "Owner Bright", "name without ruleset")
  t.equal(C.DisplayName("Owner Bright-RP-PvP", true), "Owner Bright", "Forever always omits the suffix")
  t.equal(C.CharacterName("Owner Bright").full, "Owner Bright-PvP", "identity keeps the ruleset")
end)

t.test("names written before the Forever ruleset is readable keep one identity", function()
  local C, ns = Fixture({ rulesetRealms = true, hideRealmNames = true }, "")
  local rule
  ns.Scope.Ruleset = function() return rule end
  local early = C.Canon("Owner Bright")
  t.equal(early, "Owner Bright-", "no suffix while the ruleset is unknown")
  t.equal(C.Canon(early), early, "and canonical names stay put")
  rule = "PvP"
  t.equal(C.Canon(early), "Owner Bright-PvP", "an early key takes the ruleset once known")
  t.equal(C.Canon("Owner Bright"), C.Canon(early), "the same player as the plain name")
  t.equal(C.Canon("Owner Bright-RP-PvP"), "Owner Bright-RP-PvP", "explicit suffixes are kept")
  t.equal(C.DisplayName(early), "Owner Bright", "shown without a suffix")
  local R = Fixture({}, nil)
  t.equal(R.Canon("Mage"), "Mage-", "realm unknown before login")
  R.myRealm = "Home"
  t.equal(R.Canon("Mage-"), "Mage-Home", "and the own realm afterwards")
end)

t.test("cached answers follow realm and client rule changes; secrets bypass the cache", function()
  local C, ns = Fixture({}, nil)
  t.equal(C.DisplayName("Mage-Home"), "Mage-Home", "realm unknown at load")
  C.myRealm = "Home"
  t.equal(C.DisplayName("Mage-Home"), "Mage", "realm learned after login")
  ns.Caps.hideRealmNames = true
  t.equal(C.DisplayName("Mage-Other Realm", true), "Mage", "rule change applies")
  t.equal(C.DisplayName(secret), "", "secret names are not displayed")
  t.equal(C.DisplayName(secret, true), "", "nor cached")
  ns.Caps.hideRealmNames = false
  for i = 1, 600 do t.equal(C.DisplayName("Player" .. i .. "-Away"), "Player" .. i .. "-Away", "bounded cache answer") end
  t.equal(C.DisplayName("Mage-Other Realm"), "Mage-OtherRealm", "answers stay correct after the cache resets")
end)

t.test("repeated display names allocate nothing", function()
  local C = Fixture({}, "Home")
  local names = {}
  for i = 1, 40 do names[i] = "Enemy" .. i .. (i % 2 == 0 and "-Home" or "-Away") end
  for _, name in ipairs(names) do C.DisplayName(name); C.DisplayName(name, true) end
  if jit then jit.off() end
  collectgarbage("collect"); collectgarbage("stop")
  local before = collectgarbage("count")
  for _ = 1, 50 do
    for _, name in ipairs(names) do C.DisplayName(name); C.DisplayName(name, true) end
  end
  local grown = collectgarbage("count") - before
  collectgarbage("restart")
  if jit then jit.on() end
  assert(grown < 1, "4,000 lookups allocated " .. grown .. " KiB")
end)

t.finish("Names: " .. t.tests .. " tests, " .. t.checks .. " checks")
