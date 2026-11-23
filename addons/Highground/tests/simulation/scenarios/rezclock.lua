local test, new, equal = ...

-- Resurrection clocks from teammates' revivals, the match's end, and waves
-- shared between teammates' addons (timers/Observations.lua, Graveyards.lua
-- and Sharing.lua).

-- WoW Forever: the retail manifest on interface 16001.
local function forever(s)
  s.env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end
  s.env.loadstring_untainted = nil
  s.secureSnippets = false
end

local function horde()
  return new("cata", nil, function(sim)
    sim.faction, sim.scores[1].faction, sim.area = 0, 0, "Warsong Lumber Mill"
  end)
end

local function graveyard(sim, team)
  for _, g in ipairs(sim.ns.Timers.gys) do
    if g.team == team then return g end
  end
  error("missing " .. team .. " graveyard")
end

-- A WoW Forever ghost: whole-second countdowns ending at `ends`, alive
-- `lag` seconds later.
local function reviveAt(sim, ends, lag)
  sim.env.GetAreaSpiritHealerTime = function()
    return sim.units.player.ghost and math.max(0, math.floor(ends - sim.now)) or nil
  end
  sim.units.player.ghost = true
  sim:advance(ends + lag - sim.now)
  sim.units.player.ghost = false
  sim:advance(1)
end

-- A teammate seen alive again at `at` (they were a ghost until then).
local function teammateBack(sim, at)
  sim.units.raid1.ghost = true
  sim:advance(at - sim.now)
  sim.units.raid1.ghost = false
  sim:advance(0.5)
end

local function foreverTeam()
  local sim = new("retail", nil, function(s) forever(s); s.rated, s.blitz = false, false end)
  sim.raid, sim.members = true, 2
  sim.units.raid1 = { name = "Ally Person", classID = 1 }
  sim:join(1460, 489, "Warsong Gulch")
  return sim, sim.ns.Timers
end

test("WoW Forever teammates seen back late keep the timed clock; the same delay twice moves it", function()
  local sim, T = foreverTeam()
  local mine, cycle = T.SingleGY(T.MyTeam()), T.WaveCycle()
  reviveAt(sim, sim.now + 10, 0.9)
  local wave = mine.wave
  teammateBack(sim, wave + cycle + 3)
  equal(mine.wave, wave, "a revival seen 3 s late is set aside")
  teammateBack(sim, wave + 2 * cycle + 0.2)
  assert(math.abs(mine.wave - (wave + 2 * cycle + 0.2)) <= 0.25, "one on the wave refreshes the clock")
  wave = mine.wave
  teammateBack(sim, wave + cycle + 4)
  equal(mine.wave, wave, "late again: set aside")
  teammateBack(sim, wave + 2 * cycle + 4)
  assert(math.abs(mine.wave - (wave + 2 * cycle + 4)) <= 0.25, "the same delay a cycle later: the clock moved")
  wave = mine.wave
  teammateBack(sim, wave + cycle - 2)
  assert(math.abs(mine.wave - (wave + cycle - 2)) <= 0.25, "an early revival corrects the clock at once")
  sim:assertHealthy()
end)

test("the match's end brings everyone back without timing a wave", function()
  local sim, T = foreverTeam()
  local mine = T.SingleGY(T.MyTeam())
  reviveAt(sim, sim.now + 10, 0.9)
  local wave = mine.wave
  sim.units.raid1.ghost = true
  sim:advance(5)
  sim.matchComplete = true
  sim.units.raid1.ghost = false
  sim:advance(1)
  equal(mine.wave, wave, "no wave from the final revival")
  sim:assertHealthy()
end)

-- Two Cata teammates in Warsong Gulch, both running Highground. Their game
-- clocks are in step, so a shared wave can be compared directly.
test("your revival reaches a teammate's addon to a tenth of a second", function()
  local me, friend = horde(), horde()
  for _, sim in ipairs({ me, friend }) do
    sim.rated = false
    sim:join(1460, 489, "Warsong Gulch")
  end
  local function step(dt)
    me:advance(dt); friend:advance(dt)
    equal(me.now, friend.now, "clocks in step")
  end
  local mine = graveyard(me, "H")
  me.units.player.ghost, me.healerTime = true, 12
  step(0.5)
  step(11.6)
  assert(#me.sent > 0, "the countdown was shared while you waited")
  local before = #me.sent
  me.units.player.ghost, me.healerTime = false, nil
  step(0.5)
  assert(mine.wave, "your revival times the wave")
  local packet
  for _ = 1, 12 do
    for i = before + 1, #me.sent do
      local p = me.sent[i]
      if p.prefix == "HighgroundT" and p.message:find("^3:1460:W,H,") then packet = p end
    end
    if packet then break end
    me:advance(0.25)
  end
  assert(packet, "the wave goes out in the version 3 format")
  local tenths = tonumber(packet.message:match("^3:1460:W,H,%d+,%d+,(%d+),"))
  local next = me.ns.Timers.NextWave(mine, packet.at)
  assert(math.abs(tenths / 10 - (next - packet.at)) <= 0.05, "tenths until the next wave: " .. tenths)
  -- Delivered as it is sent.
  friend:advance(packet.at - friend.now)
  friend:event("CHAT_MSG_ADDON", "HighgroundT", packet.message, packet.channel, "Buddy-Realm")
  local theirs = graveyard(friend, "H")
  equal(theirs.conf, "shared", "the teammate's clock comes from you")
  assert(math.abs(friend.ns.Timers.NextWave(theirs, friend.now) - next) <= 0.05,
    "the teammate's next wave matches yours within 0.05 s")
end)

test("shared waves read tenths from version 3 and whole seconds from version 2", function()
  local sim = horde()
  sim:join(1460, 489, "Warsong Gulch")
  local h = graveyard(sim, "H")
  sim:event("CHAT_MSG_ADDON", "HighgroundT", "3:1460:W,H,0,0,94,Warsong Lumber Mill", "INSTANCE_CHAT", "Friend-Realm")
  assert(math.abs(h.wave - (sim.now + 9.4)) < 1e-6, "version 3: 9.4 s")
  sim:event("CHAT_MSG_ADDON", "HighgroundT", "2:1460:W,H,0,0,9,Warsong Lumber Mill", "INSTANCE_CHAT", "Friend-Realm")
  equal(h.wave, sim.now + 9, "version 2: 9 s")
  sim:event("CHAT_MSG_ADDON", "HighgroundT", "4:1460:W,H,0,0,50,Warsong Lumber Mill", "INSTANCE_CHAT", "Friend-Realm")
  equal(h.wave, sim.now + 9, "an unknown version is ignored")
end)
