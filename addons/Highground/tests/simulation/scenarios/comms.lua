local test, new, equal = ...

-- Addon messages through core/Comms.lua: one CHAT_MSG_ADDON frame, each
-- prefix registered once, and the wire strings old versions understand.

local function sentOn(sim, prefix)
  local out = {}
  for _, m in ipairs(sim.sent) do
    if m.prefix == prefix then out[#out + 1] = m end
  end
  return out
end

-- Counts RegisterAddonMessagePrefix calls per prefix.
local function counting(registered)
  return function(sim)
    sim.env.C_ChatInfo.RegisterAddonMessagePrefix = function(prefix)
      registered[prefix] = (registered[prefix] or 0) + 1
    end
  end
end

local function inGuild(sim)
  sim.guild, sim.rank = "Night Watch", 1
  sim.roster = { { "Boss-Realm", 0 }, { "Me-Realm", 1 }, { "Member-Realm", 5 } }
  sim:event("PLAYER_GUILD_UPDATE")
  sim:event("GUILD_ROSTER_UPDATE")
  sim:advance(12)
end

test("every addon prefix is registered once at login", function()
  local registered = {}
  local sim = new("cata", nil, counting(registered))
  for _, prefix in ipairs({ "HighgroundC", "HighgroundT", "HighgroundI", "HighgroundB" }) do
    equal(registered[prefix], 1, prefix .. " registered once")
  end
  sim:event("PLAYER_LOGIN")
  equal(registered.HighgroundI, 1, "a second login does not register again")
  local late = {}
  sim.ns.Comms.Listen("HighgroundX", function() late.heard = true end, "test")
  equal(registered.HighgroundX, 1, "a prefix added after login registers at once")
  sim:event("CHAT_MSG_ADDON", "HighgroundX", "hi", "PARTY", "Friend-Realm")
  equal(late.heard, true, "its listener hears its messages")
end)

test("typical capture, sighting and bounty messages keep their wire format", function()
  local sim = new("cata")
  sim.env.UnitCastingInfo = function(unit)
    if unit == "player" and sim.capping then
      return "Opening", "Opening", nil, sim.capping * 1000, (sim.capping + 7) * 1000, false, "cast", false, 21651
    end
  end
  sim:enemy("Scout", { position = { x = 0.3, y = 0.4 } })
  sim:join()
  sim.env.HighgroundDB.capSpells = { [21651] = { name = "Opening", secs = 7, own = true } }

  sim.capping = sim.now
  sim:event("UNIT_SPELLCAST_START", "player", "Cast-1", 21651)
  sim.capping = nil
  sim:event("UNIT_SPELLCAST_STOP", "player", "Cast-1", 21651)
  local caps = sentOn(sim, "HighgroundC")
  equal(#caps, 2, "capture start and end")
  equal(caps[1].message, "1:S,70,70,", "capture start")
  equal(caps[1].channel, "INSTANCE_CHAT", "capture to the battleground group")
  equal(caps[2].message, "1:E", "capture end")

  sim:advance(2)
  local intel = sentOn(sim, "HighgroundI")
  assert(intel[1], "sighting shared")
  equal(intel[1].message, "3:93:@,Stables;Scout-Realm,3000,4000,3,0,coords,", "sighting")
  equal(intel[1].channel, "INSTANCE_CHAT", "sighting to the battleground group")

  inGuild(sim)
  sim:command("bounty add 250 Ganker-Other; camps the flight master")
  sim:command("bounty submit Ganker-Other")
  sim:advance(1)
  local bounty = sentOn(sim, "HighgroundB")
  equal(bounty[1].message, "1:Q", "sync request on joining the guild")
  local entry = bounty[#bounty]
  assert(entry.message:find("^1:A,Ganker%-Other,250,Me%-Realm,%d+,A,Me%-Realm,camps the flight master$"),
    "guild entry: " .. entry.message)
  equal(entry.channel, "GUILD", "bounty to the guild")
end)

test("each prefix reaches only its own module", function()
  local sim = new("cata")
  sim:enemy("Scout")
  sim.units.nameplate1 = nil
  sim:join()
  inGuild(sim)
  local Timers, Core = sim.ns.Timers, sim.ns.Core
  local timersRecv = Timers.stats.recv

  sim:event("CHAT_MSG_ADDON", "HighgroundC", "1:S,65,70,Stables", "INSTANCE_CHAT", "Buddy-Realm")
  assert(Core.logCaps.Buddy, "capture received")
  equal(sim.ns.Test.intel["Scout-Realm"], nil, "capture is not intel")
  equal(Timers.stats.recv, timersRecv, "capture is not a timer")

  sim:event("CHAT_MSG_ADDON", "HighgroundI", "3:93:Scout-Realm,3000,4000,3,0,coords,",
    "INSTANCE_CHAT", "Friend-Realm")
  equal(sim.ns.Test.intel["Scout-Realm"].x, 0.3, "sighting received")
  equal(Timers.stats.recv, timersRecv, "sighting is not a timer")

  sim:event("CHAT_MSG_ADDON", "HighgroundT", "2:93:W,H,0,0,9,Stables", "INSTANCE_CHAT", "Friend-Realm")
  equal(Timers.stats.recv, timersRecv + 1, "timer received")

  local entry = "1:A,Thief-Other,50,Boss-Realm,1000,A,Boss-Realm,stole my kill"
  sim:event("CHAT_MSG_ADDON", "HighgroundB", entry, "WHISPER", "Boss-Realm")
  equal(sim.ns.Bounty.Find("Thief-Other"), nil, "bounty outside the guild channel ignored")
  sim:event("CHAT_MSG_ADDON", "HighgroundB", entry, "GUILD", "Boss-Realm")
  equal(sim.ns.Bounty.Find("Thief-Other").state, "approved", "bounty received")

  sim:event("CHAT_MSG_ADDON", "OtherAddon", "1:E", "INSTANCE_CHAT", "Buddy-Realm")
  assert(Core.logCaps.Buddy, "other addons' messages ignored")
  sim:event("CHAT_MSG_ADDON", "HighgroundC", nil, "INSTANCE_CHAT", "Buddy-Realm")
  assert(Core.logCaps.Buddy, "messages without text ignored")
end)

test("battleground messages count only from the group channel", function()
  local sim = new("cata")
  sim:enemy("Scout") -- a mage
  sim.units.nameplate1 = nil
  sim:join()
  local Timers, Core = sim.ns.Timers, sim.ns.Core
  local tags, recv = sim.ns.Scope.Saved("specTags", "social"), Timers.stats.recv
  local function say(channel, sender)
    sim:event("CHAT_MSG_ADDON", "HighgroundC", "1:S,65,70,Stables", channel, sender)
    sim:event("CHAT_MSG_ADDON", "HighgroundI", "3:93:Scout-Realm,3000,4000,3,0,coords,", channel, sender)
    sim:event("CHAT_MSG_ADDON", "HighgroundT", "3:93:W,H,0,0,90,Stables", channel, sender)
    sim:event("CHAT_MSG_ADDON", "HighgroundS", "1:Scout-Realm,MAGE,2", channel, sender)
  end
  -- Anyone outside the match can whisper; guildmates may be elsewhere.
  say("WHISPER", "Stranger-Realm")
  say("GUILD", "Guildie-Realm")
  equal(next(Core.logCaps), nil, "no capture from outside the group")
  equal(sim.ns.Test.intel["Scout-Realm"], nil, "no sighting from outside the group")
  equal(Timers.stats.recv, recv, "no timer from outside the group")
  equal(tags["Scout-Realm"], nil, "no spec tag saved from outside the group")

  say("INSTANCE_CHAT", "Buddy-Realm")
  assert(Core.logCaps.Buddy, "the group's capture")
  equal(sim.ns.Test.intel["Scout-Realm"].x, 0.3, "the group's sighting")
  equal(Timers.stats.recv, recv + 1, "the group's timer")
  equal(tags["Scout-Realm"].by, "Buddy", "the group's spec tag")
  say("PARTY", "Pal-Realm")
  assert(Core.logCaps.Pal, "a party message counts too")
  equal(Timers.stats.recv, recv + 2, "and a party timer")
  sim:assertHealthy()
end)

test("refused sightings stay queued and go out once sending is allowed", function()
  local sim = new("cata")
  sim:enemy("Scout", { position = { x = 0.3, y = 0.4 } })
  sim.sendResult = 3 -- throttled
  sim:join()
  sim:advance(2)
  local Intel = sim.ns.Intel
  equal(#sentOn(sim, "HighgroundI"), 0, "a throttled sighting is not sent")
  equal(Intel.stats.sent, 0, "refused packets are not counted as sent")
  assert(Intel.stats.unsent > 0, "refused packets are counted")
  assert(Intel.Status():find("refused by the game", 1, true), "status reports refused messages")
  sim.sendResult = nil
  sim:advance(2)
  local intel = sentOn(sim, "HighgroundI")
  assert(intel[1] and intel[1].message:find("Scout-Realm,3000,4000", 1, true), "the kept sighting goes out")
end)

test("a refused capture start is retried while the capture lasts", function()
  local sim = new("cata")
  local active = {}
  sim.env.UnitCastingInfo = function(unit)
    local c = active[unit]
    if c and sim.now < c.finish then
      return c.name, c.name, nil, c.start * 1000, c.finish * 1000, false, "cast", false, c.spell
    end
  end
  sim:join()
  sim.env.HighgroundDB.capSpells = { [21651] = { name = "Opening", secs = 7, own = true } }
  active.player = { name = "Opening", spell = 21651, start = sim.now, finish = sim.now + 7 }
  sim.sendResult = 3
  sim:event("UNIT_SPELLCAST_START", "player", "Cast-1", 21651)
  equal(#sentOn(sim, "HighgroundC"), 0, "throttled start not sent")
  sim:advance(1)
  equal(#sentOn(sim, "HighgroundC"), 0, "still throttled")
  sim.sendResult = nil
  sim:advance(1)
  local caps = sentOn(sim, "HighgroundC")
  equal(#caps, 1, "start sent on retry")
  assert(caps[1].message:find("^1:S,50,70,"), "with the time left then: " .. caps[1].message)
  sim:advance(1)
  equal(#sentOn(sim, "HighgroundC"), 1, "no further retries once delivered")

  -- A refused end is retried; it stops once teammates' bars would end anyway.
  sim.sendResult = 3
  active.player = nil
  sim:event("UNIT_SPELLCAST_STOP", "player", "Cast-1", 21651)
  equal(#sentOn(sim, "HighgroundC"), 1, "throttled end not sent")
  sim.sendResult = nil
  sim:advance(1)
  caps = sentOn(sim, "HighgroundC")
  equal(caps[#caps].message, "1:E", "end sent on retry")
  sim:advance(10)
  equal(#sentOn(sim, "HighgroundC"), 2, "nothing more")
end)

test("chat lockdown holds battleground sharing without counting it as sent", function()
  local sim = new("retail")
  sim:enemy("Scout", { position = { x = 0.3, y = 0.4 } })
  sim.chatLockdown = true
  sim:join()
  sim:advance(4)
  for _, prefix in ipairs({ "HighgroundC", "HighgroundT", "HighgroundI" }) do
    equal(#sentOn(sim, prefix), 0, prefix .. " held during lockdown")
  end
  equal(sim.ns.Intel.stats.sent, 0, "nothing counted as sent")
  assert(sim.ns.Intel.stats.unsent > 0, "lockdown counted")
  sim.chatLockdown = nil
  sim:advance(2)
  assert(sentOn(sim, "HighgroundI")[1], "intel goes out after lockdown")
end)

test("WoW Forever shares despite its advisory restricted flag; retail holds", function()
  local function forever(s)
    s.env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end
    s.env.loadstring_untainted = nil
    s.secureSnippets = false
  end
  for _, case in ipairs({ { "Forever", forever, 1 }, { "Retail", nil, 0 } }) do
    local sim = new("retail", nil, case[2])
    sim:enemy("Scout", { position = { x = 0.3, y = 0.4 } })
    sim.addonMessagesRestricted = true
    sim:join()
    sim:advance(2)
    equal(#sentOn(sim, "HighgroundI") > 0 and 1 or 0, case[3], case[1] .. " intel with outgoing messages restricted")
  end
end)
