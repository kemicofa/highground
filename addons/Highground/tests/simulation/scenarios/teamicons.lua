local test, new, equal = ...

-- Team icons (core/TeamIcons.lua, ui/TeamIconMarks.lua, ui/TeamIcons.lua):
-- the group leader gives teammates icons outside a match; everyone sees
-- them above nameplates and on raid frames, also in a battleground.

local function forever(s)
  s.env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end
  s.env.loadstring_untainted = nil
  s.secureSnippets = false
end

-- Your party in the open world: you lead (unless leader = false), with a
-- warrior and a priest. The warrior has a nameplate and a raid frame.
local function party(sim, leader)
  sim.members = 3
  local units = {
    party1 = { name = "Brann", classID = 1, guid = "Player-1-01" },
    party2 = { name = "Lunara", classID = 5, guid = "Player-1-02" },
  }
  for token, unit in pairs(units) do sim.units[token] = unit end
  sim.env.IsInGroup = function() return true end
  sim.env.UnitIsGroupLeader = function(unit) return unit == "player" and leader ~= false end
  sim.units.nameplate5 = units.party1
  sim.plates.nameplate5 = sim.env.CreateFrame("Frame", nil, sim.env.UIParent)
  sim.units.nameplate6 = units.party2
  sim.plates.nameplate6 = sim.env.CreateFrame("Frame", nil, sim.env.UIParent)
  local frame = sim.env.CreateFrame("Button", "CompactPartyFrameMember2", sim.env.UIParent)
  frame.unit = "party1"
  return units, frame
end

local function last(sim) return sim.messages[#sim.messages] or "" end

local function shown(pool)
  local list = {}
  for _, b in pairs(pool) do if b:IsShown() then list[#list + 1] = b end end
  return list
end

test("The group leader gives teammates icons; the same icon gets its own outline colour", function()
  local sim = new("retail", nil, forever)
  local C = sim.ns.Core
  local _, frame = party(sim)
  equal(C.TeamIconLock(), nil, "the leader of a group outside a match may change icons")
  assert(C.SetTeamIcon("party1", "flag"), "the warrior carries the flag")
  local plate = C.teamIconPlates.nameplate5
  assert(plate and plate:IsShown(), "a badge above the warrior's nameplate")
  equal(plate.anchor, sim.plates.nameplate5, "anchored to the plate")
  equal(plate.icon.texture, C.TEAM_ICON_SHEET, "a symbol from the icon sheet")
  local framed = C.teamIconFrames.CompactPartyFrameMember2
  assert(framed and framed:IsShown() and framed.anchor == frame, "and on the warrior's party frame")

  assert(C.SetTeamIcon("party2", "flag"), "a second flag icon")
  local marks = C.TeamIconMarks()
  equal(marks[C.CanonUnit("party1")].color, 1, "the first keeps the first colour")
  equal(marks[C.CanonUnit("party2")].color, 2, "the second gets the next")
  equal(C.teamIconPlates.nameplate6.ring.wbToken, "teamIcon2", "drawn in that colour")
  assert(C.SetTeamIcon("party2", "PRIEST"), "a class icon")
  equal(marks[C.CanonUnit("party2")].color, 1, "the only priest icon: the first colour again")
  assert(C.teamIconPlates.nameplate6.icon.texture ~= C.TEAM_ICON_SHEET, "class icons come from the game")
  frame.unit = "party2"; sim:advance(1.1)
  equal(C.teamIconFrames.CompactPartyFrameMember2.iconID, "PRIEST", "a frame moved to another member follows within a second")
  frame.unit = "party1"; sim:advance(1.1)

  equal(select(2, C.SetTeamIcon("party1", "nothing")), "icon", "an unknown icon is refused")
  sim.units.stranger = { name = "Stranger", classID = 4 }
  equal(select(2, C.SetTeamIcon("stranger", "tank")), "unit", "only group members get icons")
  assert(C.SetTeamIcon("party1", nil), "clearing")
  sim:advance(1.1)
  equal(#shown(C.teamIconPlates), 1, "the warrior's badge is gone")
  equal(#shown(C.teamIconFrames), 0, "from the frame too")
  sim:assertHealthy()
end)

test("Only the group leader, and never in a match; icons set before stay through the battleground", function()
  local sim = new("retail", nil, forever)
  local C = sim.ns.Core
  party(sim, false)
  equal(C.TeamIconLock(), "leader", "a member can't change icons")
  equal(select(2, C.SetTeamIcon("party1", "tank")), "leader", "and is told why")
  sim.env.UnitIsGroupLeader = function(unit) return unit == "player" end
  assert(C.SetTeamIcon("party1", "tank"), "the leader can")
  sim.chatLockdown = true
  equal(C.TeamIconLock(), "blocked", "not while the game blocks addon messages")
  sim.chatLockdown = false

  sim:join()
  equal(C.TeamIconLock(), "match", "not in a battleground")
  equal(select(2, C.SetTeamIcon("party1", "healer")), "match", "a change is refused")
  sim:advance(1.1)
  assert(C.teamIconPlates.nameplate5:IsShown(), "the icon set before the match still shows")
  equal(C.teamIconPlates.nameplate5.iconID, "tank", "unchanged")
  sim:event("GROUP_LEFT", 2)
  assert(next(C.TeamIconMarks()), "leaving the battleground's group keeps the icons")
  sim:leave()
  sim.env.IsInGroup = function() return false end
  sim:event("GROUP_LEFT", 1)
  equal(next(C.TeamIconMarks()), nil, "leaving your own group drops them")
  equal(C.TeamIconLock(), "group", "and outside a group nobody changes them")
  sim:assertHealthy()
end)

test("Beside a healer cross the icon moves left; switches hide plates and frames", function()
  local sim = new("retail")
  local C = sim.ns.Core
  local units = party(sim)
  units.party2.role = "HEALER"
  C.SetTeamIcon("party2", "squadA")
  sim:join(); sim:advance(1.1)
  local badge = C.teamIconPlates.nameplate6
  assert(badge:IsShown(), "the healer's icon shows")
  assert(badge.x < 0, "left of the green cross")
  sim.env.HighgroundDB.teamIconPlates = false; sim:advance(1.1)
  assert(not badge:IsShown(), "Team icons on nameplates off hides plate badges")
  sim.env.HighgroundDB.teamIconPlates = nil
  sim.env.HighgroundDB.teamIcons = false; sim:advance(1.1)
  equal(#shown(C.teamIconPlates) + #shown(C.teamIconFrames), 0, "Team icons off hides them all")
  sim:assertHealthy()
end)

test("/hg icon, the picker and the Team icons window set the same icons", function()
  local sim = new("retail", nil, forever)
  local C, W = sim.ns.Core, sim.ns.TeamIcons
  party(sim)
  sim:command("icon brann tank")
  equal(C.TeamIconMarks()[C.CanonUnit("party1")].icon, "tank", "by name and icon, any case")
  assert(last(sim):find("Brann now has the Tank team icon", 1, true), "and says so")
  sim:command("icon Brann clear")
  equal(C.TeamIconMarks()[C.CanonUnit("party1")], nil, "clear removes it")
  sim:command("icon Nobody tank")
  assert(last(sim):find("Nobody", 1, true), "an unknown name is reported")
  sim.units.target = sim.units.party2
  sim:command("icon healer")
  equal(C.TeamIconMarks()[C.CanonUnit("party2")].icon, "healer", "without a name: your target")

  sim.units.mouseover = sim.units.party1
  sim.env.Highground_TeamIcon()
  assert(W.PickerShown(), "the key opens the picker for the member under the mouse")
  local mage
  for _, b in ipairs(sim.ns.TeamIconPicker.frame.buttons) do if b.icon == "MAGE" then mage = b end end
  assert(mage, "class icons are offered")
  mage:Click()
  equal(C.TeamIconMarks()[C.CanonUnit("party1")].icon, "MAGE", "a click sets it")
  assert(not W.PickerShown(), "and closes the picker")

  sim:command("icons")
  assert(W.win:IsShown(), "the window opens")
  equal(#W.items, 3, "one row per group member, you included")
  local rows, brann = shown(W.win.list.rows)
  for _, row in ipairs(rows) do if row.item.unit == "party1" then brann = row end end
  assert(brann.badge:IsShown(), "a member's icon shows in their row")
  brann:Click()
  assert(W.PickerShown(), "a row opens the picker")
  sim.ns.TeamIconPicker.frame.none:Click()
  equal(C.TeamIconMarks()[C.CanonUnit("party1")], nil, "No icon clears it")
  assert(not brann.badge:IsShown(), "the open window follows")

  sim:command("icons clear")
  equal(next(C.TeamIconMarks()), nil, "/hg icons clear clears every icon")
  sim.env.UnitIsGroupLeader = function() return false end
  sim:event("PARTY_LEADER_CHANGED")
  assert(not brann:IsEnabled(), "rows lock for a member")
  assert(W.win.hint:GetText():find("leader", 1, true), "and say why")
  W.Close()
  sim:assertHealthy()
end)

test("/hg icons test shows sample teammates without saving their icons", function()
  local sim = new("retail", nil, forever)
  local W = sim.ns.TeamIcons
  sim:command("icons test")
  assert(W.IsSample(), "the sample opens without a group")
  equal(#W.items, 6, "six sample teammates")
  local rows = shown(W.win.list.rows)
  rows[6]:Click()
  sim.ns.TeamIconPicker.frame.buttons[1]:Click()
  assert(W.sampleMarks[rows[6].item.key], "a sample row takes an icon")
  equal(W.sampleMarks["sample:Thornik"].color, 2, "the second healer has the second colour")
  equal(next(sim.ns.Scope.Saved("teamIcons", "social").marks or {}), nil, "nothing is saved")
  sim:command("icons test")
  assert(not W.win:IsShown(), "running it again stops the sample")

  local H, O = sim.ns.Hub, sim.ns.Options
  H.Open("battlegrounds-previews")
  local button
  for _, b in ipairs(O.byKey["battlegrounds-previews"].previews) do if b.cmd == "icons test" then button = b end end
  assert(button, "the Previews page offers the sample")
  button:Click()
  assert(W.IsSample(), "Start opens it")
  W.Close()
  sim:assertHealthy()
end)
