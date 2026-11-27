local test, new, equal = ...

-- Team icons travel from the group leader to the group (core/TeamIconShare.lua)
-- and an automatic rule fills in the rest (core/TeamIconRules.lua).

local PREFIX = "HighgroundG"

-- Your party outside a match. leader names the leading token ("player" by
-- default). party1 is a warrior, party2 a priest, party3 a warrior.
local function party(sim, leader)
  leader = leader or "player"
  sim.members = 4
  local units = {
    party1 = { name = "Brann", classID = 1, guid = "Player-1-01" },
    party2 = { name = "Lunara", classID = 5, guid = "Player-1-02" },
    party3 = { name = "Axel", classID = 1, guid = "Player-1-03" },
  }
  for token, unit in pairs(units) do sim.units[token] = unit end
  sim.env.IsInGroup = function() return true end
  sim.env.UnitIsGroupLeader = function(unit) return unit == leader end
  return units
end

local function sent(sim, prefix)
  local list = {}
  for _, m in ipairs(sim.sent) do if m.prefix == (prefix or PREFIX) then list[#list + 1] = m end end
  return list
end

local function from(sim, token, text, channel)
  sim:event("CHAT_MSG_ADDON", PREFIX, text, channel or "PARTY", sim.ns.Core.CanonUnit(token))
end

test("The leader sends every change to the party; members ask when they arrive", function()
  local sim = new("retail")
  local C = sim.ns.Core
  party(sim)
  local brann = C.CanonUnit("party1")
  C.SetTeamIcon("party1", "flag")
  C.SetTeamIcon("party2", "healer")
  sim:advance(0.5)
  local out = sent(sim)
  equal(#out, 1, "two edits in a row go out once")
  equal(out[1].channel, "PARTY", "on the party channel")
  assert(out[1].message:find("^1:2:1/1::"), "change 2, one part, no rule: " .. out[1].message)
  assert(out[1].message:find(brann .. ",flag,1", 1, true), "with the warrior's icon")
  C.SetTeamIconRule("class"); sim:advance(0.5)
  assert(sent(sim)[2].message:find("^1:3:1/1:class:"), "the automatic rule goes too")

  from(sim, "party2", "R"); from(sim, "party3", "R")
  sim:advance(6)
  equal(#sent(sim), 3, "requests in a burst are answered once")
  assert(sent(sim)[3].message:find("^1:3:"), "with the same change")

  sim.sendResult = 3 -- throttled
  C.SetTeamIcon("party3", "tank"); sim:advance(0.5)
  equal(#sent(sim), 3, "refused")
  sim.sendResult = nil; sim:advance(5.1)
  equal(#sent(sim), 4, "and sent again a little later")

  sim:join()
  sim:event("GROUP_ROSTER_UPDATE"); sim:advance(6)
  equal(#sent(sim), 4, "nothing is sent in a match")
  sim:assertHealthy()
end)

test("Members take the leader's icons and nobody else's", function()
  local sim = new("retail")
  local C = sim.ns.Core
  party(sim, "party1")
  local me, brann, lunara = C.CanonUnit("player"), C.CanonUnit("party1"), C.CanonUnit("party2")
  sim:event("GROUP_JOINED"); sim:advance(2.1)
  equal(sent(sim)[1].message, "R", "a new member asks the leader")

  from(sim, "party2", "1:9:1/1::" .. me .. ",tank,1")
  equal(next(C.TeamIconMarks()), nil, "a member who doesn't lead is ignored")
  from(sim, "party1", "1:9:1/1::" .. me .. ",tank,1", "INSTANCE_CHAT")
  equal(next(C.TeamIconMarks()), nil, "so is a battleground's instance chat")

  from(sim, "party1", "1:4:1/2::" .. me .. ",tank,1")
  equal(next(C.TeamIconMarks()), nil, "half a change waits")
  from(sim, "party1", "1:4:2/2::" .. lunara .. ",healer,2;" .. brann .. ",bogus,1")
  equal(C.TeamIconMarks()[me].icon, "tank", "both parts arrived")
  equal(C.TeamIconMarks()[lunara].color, 2, "with the leader's colours")
  equal(C.TeamIconMarks()[brann], nil, "unknown icons are skipped")
  equal(C.TeamIconLock(), "leader", "a member still can't change them")

  from(sim, "party1", "1:5:1/1:role:")
  equal(next(C.TeamIconMarks()), nil, "a later change replaces everything")
  equal(C.TeamIconRule(), "role", "including the rule")

  sim:join()
  sim:event("GROUP_LEFT", 2)
  equal(C.TeamIconRule(), "role", "kept through a battleground")
  sim:assertHealthy()
end)

test("A raid's icons fit in several messages and arrive whole on a member's client", function()
  local leader = new("retail")
  local member = new("retail")
  local names = {}
  for i = 1, 30 do names[i] = "Teammate" .. string.char(64 + (i - 1) % 26 + 1) .. i end
  for _, sim in ipairs({ leader, member }) do
    sim.raid, sim.members = true, 31
    sim.env.IsInGroup = function() return true end
    sim.env.IsInRaid = function() return true end
    sim.units.raid31 = sim.units.player
    for i, name in ipairs(names) do sim.units["raid" .. i] = { name = name, classID = 1 + i % 9, guid = "Player-1-" .. i } end
  end
  leader.env.UnitIsGroupLeader = function(unit) return unit == "player" or unit == "raid31" end
  -- The member's client sees the leader as raid1.
  member.units.player.name = "Zed"
  member.units.raid1 = { name = "Me", classID = 8, guid = "Player-1-99" }
  member.env.UnitIsGroupLeader = function(unit) return unit == "raid1" end
  for i = 1, 30 do leader.ns.Core.SetTeamIcon("raid" .. i, i % 2 == 0 and "squadA" or "squadB") end
  leader:advance(0.5)
  local out = sent(leader)
  assert(#out >= 2, "more than one message: " .. #out)
  for _, m in ipairs(out) do
    equal(m.channel, "RAID", "on the raid channel")
    member:event("CHAT_MSG_ADDON", PREFIX, m.message, m.channel, "Me")
  end
  local count, marks = 0, member.ns.Core.TeamIconMarks()
  for _ in pairs(marks) do count = count + 1 end
  equal(count, 30, "every icon arrives")
  member:assertHealthy()
end)

test("Automatic icons: class or role, hand marks first, own colours in name order", function()
  local sim = new("retail")
  local C, W = sim.ns.Core, sim.ns.TeamIcons
  local units = party(sim)
  local brann, axel, lunara = C.CanonUnit("party1"), C.CanonUnit("party3"), C.CanonUnit("party2")
  assert(C.SetTeamIconRule("class"))
  local icons = C.TeamIconsResolved()
  equal(icons[brann].icon, "WARRIOR", "every member shows their class")
  assert(icons[brann].auto, "automatically")
  equal(icons[axel].color, axel < brann and 1 or 2, "two warriors: colours in name order")
  equal(icons[C.CanonUnit("player")].icon, "MAGE", "you too")
  C.SetTeamIcon("party1", "flag")
  equal(C.TeamIconsResolved()[brann].icon, "flag", "a hand mark beats the rule")
  equal(C.TeamIconsResolved()[axel].color, 1, "the other warrior has the first colour now")
  C.SetTeamIcon("party1", "none")
  equal(C.TeamIconsResolved()[brann], nil, "none hides the icon")
  C.SetTeamIcon("party1", nil)
  equal(C.TeamIconsResolved()[brann].icon, "WARRIOR", "clearing gives back the class icon")

  units.party2.role = "HEALER"
  units.party1.role = "TANK"
  sim.units.party3 = { name = "Sylra", classID = 11, guid = "Player-1-05" }
  sim:command("icons auto role")
  icons = C.TeamIconsResolved()
  equal(icons[brann].icon, "tank", "the tank role")
  equal(icons[lunara].icon, "healer", "the healer role")
  equal(icons[C.CanonUnit("player")].icon, "caster", "a mage casts")
  equal(icons[C.CanonUnit("party3")], nil, "a druid's damage specs are mixed: no guess")
  sim:command("icons auto bogus")
  assert(sim.messages[#sim.messages]:find("/hg icons auto off", 1, true), "an unknown rule is explained")
  sim:command("icon Brann none")
  equal(C.TeamIconsResolved()[brann], nil, "/hg icon NAME none")

  sim:command("icons")
  local rule = W.win.rule
  equal(rule:GetValue(), "role", "the window shows the rule")
  rule.byKey.off:Click()
  equal(C.TeamIconRule(), nil, "and changes it")
  sim:command("icons auto class")
  assert(W.win.list.rows[1].note:GetText():find("automatic", 1, true), "rows say which icons are automatic")
  W.Close()

  sim:command("icons test")
  W.win.rule.byKey.class:Click()
  equal(W.Icons()["sample:Vex"].icon, "ROGUE", "the sample shows the class rule")
  equal(C.TeamIconRule(), "class", "without touching your group's rule")
  W.Close()
  sim:assertHealthy()
end)
