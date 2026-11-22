local t = dofile("../../tools/harness.lua")("scoped storage")

-- Real Util, Saved and Scope with a client whose identity arrives late.
local function Fixture(caps)
  local s = { guid = nil, name = nil, faction = "Horde", rules = nil }
  local env = setmetatable({}, { __index = _G })
  env.CreateFrame = function() return { RegisterEvent = function() end, SetScript = function() end } end
  env.UnitGUID = function() return s.guid end
  env.UnitFactionGroup = function() return s.faction end
  env.GetCurrentRegion = function() return 3 end
  env.GetNormalizedRealmName = function() return s.realm end
  local ns = { GAME = "cata", CLIENT = "cata", Caps = caps or {}, Core = {} }
  ns.Core.CanonUnit = function() return s.name end
  for _, file in ipairs({ "Util", "Saved", "Scope" }) do
    setfenv(assert(loadfile("libs/core/" .. file .. ".lua")), env)("Highground", ns)
  end
  s.ns, s.S = ns, ns.Scope
  return s
end

t.test("writes before the character is known move into its saved store", function()
  local s = Fixture()
  local db = { scoped = { character = { ["cata:3:realm:Home:Horde:Player-1"] = { history = { old = 1 }, kept = "yes" } } } }
  s.ns.Core.db = db
  local early = s.S.Saved("history", "character")
  early.new, early.old = 2, 5
  s.S.Store("character").setting = "early"
  t.equal(db.scoped.character["cata:3:realm:Home:Horde:Player-1"].setting, nil, "nothing written under a guessed key")
  s.guid, s.ns.Core.myRealm = "Player-1", "Home"
  local store = s.S.Store("character")
  t.equal(store, db.scoped.character["cata:3:realm:Home:Horde:Player-1"], "the real saved store")
  t.equal(store.history.new, 2, "pending entries arrive")
  t.equal(store.history.old, 5, "newer pending values win")
  t.equal(store.setting, "early", "top-level pending values arrive")
  t.equal(store.kept, "yes", "existing values stay")
  store.history.new = 3
  t.equal(s.S.Store("character").history.new, 3, "pending data is taken over only once")
end)

t.test("writes before the saved table exists reach the default saved table", function()
  local s = Fixture()
  s.guid, s.ns.Core.myRealm = "Player-2", "Home"
  s.S.Saved("history", "faction").early = true
  s.S.Saved("history", "account").early = true
  local other = {}
  t.equal(s.S.Store("faction", other).history, nil, "another saved table does not take them")
  local db = {}
  s.ns.Core.db = db
  t.equal(s.S.Saved("history", "faction").early, true, "faction write kept")
  t.equal(s.S.Saved("history", "account").early, true, "account write kept")
  t.equal(db.scoped.faction["cata:3:realm:Home:Horde"].history.early, true, "and saved")
end)

t.test("realm-dependent keys wait for a realm or a ruleset", function()
  local s = Fixture()
  s.ns.Core.db, s.guid = {}, "Player-3"
  s.S.Store("realm").value = 1
  t.equal(s.ns.Core.db.scoped, nil, "no store under an empty realm")
  t.equal(s.S.Store("account").ready, nil, "account storage needs no realm")
  t.equal(type(s.ns.Core.db.scoped.account), "table", "and saves at once")
  s.ns.Core.myRealm = "Home"
  t.equal(s.S.Store("realm").value, 1, "write kept once the realm is known")
end)

t.finish("Scoped storage: " .. t.tests .. " tests, " .. t.checks .. " checks")
