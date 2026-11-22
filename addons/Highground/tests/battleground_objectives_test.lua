-- Flag, single-flag and orb objectives on real battleground rules
-- (core/Objectives.lua, flags/State.lua): carriers from chat and arena
-- tokens, the shared assault clock, orb stacks and resets.
-- Run from addons/Highground: luajit tests/battleground_objectives_test.lua
local t = dofile("../../tools/harness.lua")("battleground objectives")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local equal = t.equal

local function chat(sim, side, text) sim:event("CHAT_MSG_BG_SYSTEM_" .. side, text) end

t.test("Warsong Gulch drops keep the assault clock; both flags home or a neutral reset clear it", function()
  local sim = new("cata", {})
  local Core, Flags = sim.ns.Core, sim.ns.Flags
  sim:enemy("Carrier")
  sim:join(1460, 489, "Warsong Gulch")
  chat(sim, "HORDE", "The Alliance flag was picked up by Carrier!")
  chat(sim, "ALLIANCE", "The Horde flag was picked up by Me!")
  equal(Flags.carriers.H.name, "Carrier", "enemy carrier on the flags window")
  equal(Flags.carriers.A.name, "Me", "your carrier")
  local started = Core.obj.assaultStart
  assert(started, "both flags held: assault clock running")
  chat(sim, "HORDE", "The Alliance flag was dropped by Carrier!")
  equal(sim:entry("Carrier").carrier, false, "dropper no longer carries")
  assert(Flags.carriers.H.dropped and not Flags.carriers.H.name, "flags window shows the drop")
  equal(Flags.LastEnemyCarrier(), "Carrier", "last enemy carrier remembered")
  equal(Core.obj.assaultStart, started, "a drop keeps the clock running")
  chat(sim, "ALLIANCE", "The Alliance Flag was returned to its base by Defender!")
  equal(Flags.carriers.H, nil, "returned flag clears its row")
  equal(Core.obj.assaultStart, started, "one flag still held: clock keeps running")
  chat(sim, "HORDE", "The Horde Flag was returned to its base by Grunt!")
  equal(Core.obj.assaultStart, nil, "both flags home reset the clock")
  chat(sim, "HORDE", "The Alliance flag was picked up by Carrier!")
  chat(sim, "ALLIANCE", "The Horde flag was picked up by Me!")
  assert(Core.obj.assaultStart, "clock restarts")
  chat(sim, "NEUTRAL", "The flags are now placed at their bases.")
  equal(Core.obj.assaultStart, nil, "neutral reset clears the clock")
  equal(sim:entry("Carrier").carrier, false, "and the carriers")
  equal(next(Flags.carriers), nil, "and the flags window")
end)

t.test("joining a running Warsong Gulch waits for both flags home before counting stacks", function()
  local sim = new("cata", {})
  local Core = sim.ns.Core
  sim:enemy("Carrier")
  sim.matchStart = sim.now - 300 -- the match started five minutes ago
  sim.inBG, sim.mapID, sim.instanceID, sim.mapName = true, 1460, 489, "Warsong Gulch"
  sim:event("PLAYER_ENTERING_WORLD"); sim:event("UPDATE_BATTLEFIELD_SCORE"); sim:advance(1)
  equal(Core.obj.trusted, false, "an unseen clock may already be running")
  chat(sim, "HORDE", "The Alliance flag was picked up by Carrier!")
  chat(sim, "ALLIANCE", "The Horde flag was picked up by Me!")
  equal(Core.obj.assaultStart, nil, "no stack clock from a partial view")
  equal(Core.FlagStacks(), nil, "no stacks shown")
  chat(sim, "ALLIANCE", "The Alliance Flag was returned to its base by Defender!")
  chat(sim, "HORDE", "The Horde Flag was returned to its base by Grunt!")
  equal(Core.obj.trusted, true, "both flags seen home")
  chat(sim, "HORDE", "The Alliance flag was picked up by Carrier!")
  chat(sim, "ALLIANCE", "The Horde flag was picked up by Me!")
  assert(Core.obj.assaultStart, "clock starts once trusted")
end)

t.test("Eye of the Storm tracks the single flag and its respawn after a capture", function()
  local sim = new("cata", {})
  local Core, Flags = sim.ns.Core, sim.ns.Flags
  sim:enemy("Runner")
  sim:join(112, 566, "Eye of the Storm")
  equal(Core.obj.mode, "carry", "single-flag rules")
  chat(sim, "HORDE", "Runner has taken the flag!")
  equal(sim:entry("Runner").carrier, true, "enemy carrier")
  equal(Flags.carriers.H.name, "Runner", "carrier's team from the roster")
  chat(sim, "HORDE", "The flag has been dropped.")
  equal(sim:entry("Runner").carrier, false, "drop clears the carrier")
  assert(Flags.carriers.H.dropped, "flags window shows the drop on the carrier's side")
  chat(sim, "ALLIANCE", "Me has taken the flag!")
  equal(Flags.carriers.A.name, "Me", "your carrier")
  equal(Flags.carriers.H, nil, "one flag: the other side is cleared")
  chat(sim, "ALLIANCE", "The Alliance have captured the flag!")
  equal(sim.ns.flagRespawnAt, sim.now + 21, "respawn from the map's rules")
  equal(next(Flags.carriers), nil, "capture clears the flags window")
  sim:advance(1)
  local pin
  for _, item in ipairs(sim.env.WorldMapFrame.pins) do
    if item.item.label and item.item.label:find("^FLAG ") then pin = item.item end
  end
  assert(pin and pin.label == "FLAG 20s", "respawn pin on the map: " .. tostring(pin and pin.label))
  local lines = {}
  pin.tooltip({ AddLine = function(_, line) lines[#lines + 1] = line end })
  assert(table.concat(lines, " "):find("Flag respawns in 20s", 1, true), "respawn tooltip")
  sim:advance(21)
  for _, item in ipairs(sim.env.WorldMapFrame.pins) do
    assert(not (item.item.label or ""):find("^FLAG "), "pin gone once the flag is back")
  end
end)

t.test("Temple of Kotmogu orbs grow stacks and drop when the carrier's token disappears", function()
  local sim = new("retail", {})
  local Core = sim.ns.Core
  local orber = sim:enemy("Orber")
  sim:join(417, 998, "Temple of Kotmogu")
  equal(Core.obj.mode, "orb", "orb rules")
  chat(sim, "HORDE", "Orber has taken the Blue orb!")
  local e = sim:entry("Orber")
  equal(e.carrier, true, "orb carrier")
  equal(Core.CarrierStacks(e), 30, "30% on pickup")
  sim.units.arena1 = orber
  sim:advance(16)
  equal(Core.CarrierStacks(e), 60, "+30% after 15 seconds")
  sim:advance(15)
  equal(Core.CarrierStacks(e), 90, "and again")
  sim.units.arena1 = nil
  sim:advance(4)
  equal(e.carrier, false, "token gone for 3 seconds: orb dropped")
  equal(Core.CarrierStacks(e), nil, "no stacks without an orb")
  sim.units.arena1 = orber
  sim:advance(1)
  equal(e.carrier, true, "token seen again: carrier without a pickup message")
  equal(Core.CarrierStacks(e), 30, "missed pickup starts at the base value")
  e.dead = true
  sim.units.arena1 = nil
  sim:advance(0.5)
  equal(e.carrier, false, "a dead carrier no longer holds the orb")
  chat(sim, "ALLIANCE", "Me has taken the Green orb!")
  assert(sim.ns.PlayerHasObjective(), "your own orb pickup counts as holding an objective")
end)

t.test("an enemy on a flag map's arena token becomes the only carrier", function()
  local sim = new("cata", {})
  local first = sim:enemy("First")
  local second = sim:enemy("Second")
  sim:join(1460, 489, "Warsong Gulch")
  chat(sim, "HORDE", "The Alliance flag was picked up by First!")
  equal(sim:entry("First").carrier, true, "chat carrier")
  sim.units.arena1 = second
  sim:advance(0.5)
  equal(sim:entry("Second").carrier, true, "arena token marks the carrier")
  equal(sim:entry("First").carrier, false, "one enemy carrier at a time")
  sim.units.arena1 = first
  sim:advance(0.5)
  equal(sim:entry("First").carrier, true, "token follows the flag")
end)

t.test("flag carriers resolve to an arena token, a raid member or a selected unit", function()
  local sim = new("cata", {})
  local runner = sim:enemy("Runner")
  sim.members, sim.raid = 2, true
  sim.units.raid1 = { name = "Buddy" }
  sim:join(1460, 489, "Warsong Gulch")
  local F = sim.ns.Flags
  equal(F.CarrierUnit("A", "Buddy-Realm"), "raid1", "your carrier from the raid")
  equal(F.CarrierUnit("A", "Stranger"), nil, "unknown teammate")
  equal(F.CarrierUnit("H", "Runner"), nil, "enemy carrier out of sight")
  sim.units.focus = runner
  equal(F.CarrierUnit("H", "Runner-Realm"), "focus", "enemy carrier you focus")
  sim.units.arena2 = runner
  equal(F.CarrierUnit("H", "Runner"), "arena2", "the arena token wins")
  equal(F.CarrierUnit("A", "Buddy"), "raid1", "a hostile token is never your carrier")
end)

t.test("chat names match coloured, short and Forever first names but never an ambiguous one", function()
  local sim = new("retail", {}, function(_, env)
    env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end
  end)
  local Core = sim.ns.Core
  sim:enemy("Ann Smith")
  sim:join(1460, 489, "Warsong Gulch")
  for _, realm in ipairs({ "Elsewhere", "Faraway" }) do
    sim.scores[#sim.scores + 1] = { name = "Twin-" .. realm, classToken = "MAGE", faction = 0 }
  end
  sim:event("UPDATE_BATTLEFIELD_SCORE"); sim:advance(1)
  equal(Core.EnemyByChatName("|cffff2020Ann Smith|r").key, "Ann Smith-Realm", "colour codes stripped")
  equal(Core.EnemyByChatName("Ann Smith").key, "Ann Smith-Realm", "two-part name kept whole")
  equal(Core.EnemyByChatName("Ann").key, "Ann Smith-Realm", "a unique first name matches the full name")
  sim.scores[#sim.scores + 1] = { name = "Ann Jones-Realm", classToken = "MAGE", faction = 0 }
  sim:event("UPDATE_BATTLEFIELD_SCORE"); sim:advance(1)
  equal(Core.EnemyByChatName("Ann"), nil, "a shared first name is ambiguous")
  equal(Core.EnemyByChatName("Ann Jones").key, "Ann Jones-Realm", "full names stay exact")
  sim.scores[#sim.scores + 1] = { name = "Ann-Realm", classToken = "MAGE", faction = 0 }
  sim:event("UPDATE_BATTLEFIELD_SCORE"); sim:advance(1)
  equal(Core.EnemyByChatName("Ann").key, "Ann-Realm", "a player named exactly that wins")
  table.remove(sim.scores); table.remove(sim.scores)
  equal(Core.EnemyByChatName("Twin-Elsewhere").key, "Twin-Elsewhere", "full name")
  equal(Core.EnemyByChatName("Twin"), nil, "two players from other realms share the short name")
  sim.scores[#sim.scores] = nil
  sim:event("UPDATE_BATTLEFIELD_SCORE"); sim:advance(1)
  equal(Core.EnemyByChatName("Twin").key, "Twin-Elsewhere", "a unique short name from another realm")
  equal(Core.EnemyByChatName(nil), nil, "no name")
end)

t.finish("Battleground objectives: " .. t.tests .. " tests")
