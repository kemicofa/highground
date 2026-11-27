local test, new, equal = ...

-- Quick ways to give team icons: the panel offered when you lead a new group
-- (ui/TeamIconPanel.lua) and the Team icon entry in right-click menus
-- (ui/TeamIconMenu.lua).

-- Retail menus, collected per tag as the game would call them.
local function menus(s)
  s.menus = {}
  s.env.Menu = { ModifyMenu = function(tag, callback)
    s.menus[tag] = s.menus[tag] or {}
    table.insert(s.menus[tag], callback)
  end }
end

local function node(text, run)
  local n = { text = text, run = run, children = {} }
  function n:CreateButton(label, fn)
    local child = node(label, fn)
    self.children[#self.children + 1] = child
    return child
  end
  function n:CreateDivider() self.children[#self.children + 1] = { divider = true, children = {} } end
  function n:CreateTitle() end
  return n
end

-- The Team icon entry of a unit's menu, or nil.
local function entry(sim, tag, unit)
  local root = node()
  for _, callback in ipairs(sim.menus[tag] or {}) do callback(nil, root, { unit = unit }) end
  for _, child in ipairs(root.children) do
    if child.text == "Team icon" then return child end
  end
end

local function find(n, text)
  for _, child in ipairs(n.children) do
    if child.text and child.text:find(text, 1, true) then return child end
  end
end

local function party(sim, leader)
  sim.members = 3
  sim.units.party1 = { name = "Brann", classID = 1, guid = "Player-1-01" }
  sim.units.party2 = { name = "Lunara", classID = 5, guid = "Player-1-02" }
  sim.env.IsInGroup = function() return true end
  sim.env.UnitIsGroupLeader = function(unit) return unit == (leader or "player") end
end

test("Leading a new group offers the quick panel once; X, a battleground or leaving closes it", function()
  local sim = new("retail")
  local C, P = sim.ns.Core, sim.ns.TeamIconPanel
  party(sim)
  sim:event("GROUP_ROSTER_UPDATE")
  assert(P.Shown(), "the leader of a new group sees the panel")
  P.frame.class:Click()
  equal(C.TeamIconRule(), "class", "Class icons turns the class rule on")
  assert(P.frame.status:GetText():find("Class", 1, true), "and says so")
  P.frame.role:Click()
  equal(C.TeamIconRule(), "role", "Role icons")
  C.SetTeamIcon("party1", "flag")
  P.frame.remove:Click()
  equal(C.TeamIconRule(), nil, "Remove all ends the rule")
  equal(next(C.TeamIconMarks()), nil, "and clears hand marks")
  P.frame.close:Click()
  assert(not P.Shown(), "X closes it")
  sim:event("GROUP_ROSTER_UPDATE")
  assert(not P.Shown(), "it stays closed for this group")

  sim:command("icons panel")
  assert(P.Shown(), "/hg icons panel brings it back")
  sim:command("icons panel")
  assert(not P.Shown(), "and hides it again")
  sim:command("icons")
  sim.ns.TeamIcons.win.panel:Click()
  assert(P.Shown(), "so does the window's Quick panel button")
  sim.ns.TeamIcons.Close()

  sim:join()
  assert(not P.Shown(), "entering a battleground closes it")
  sim:leave()
  sim.env.IsInGroup = function() return false end
  sim:event("GROUP_LEFT", 1)
  party(sim)
  sim:event("GROUP_ROSTER_UPDATE")
  assert(P.Shown(), "a new group offers it again")
  sim:assertHealthy()
end)

test("Members and players who turned it off never see the panel by itself", function()
  local sim = new("retail")
  local P = sim.ns.TeamIconPanel
  party(sim, "party1")
  sim:event("GROUP_ROSTER_UPDATE"); sim:event("PARTY_LEADER_CHANGED")
  assert(not P.Shown(), "not for a member")
  sim:command("icons panel")
  assert(not P.frame.class:IsEnabled(), "shown by hand, its buttons are locked for a member")
  assert(P.frame.status:GetText():find("leader", 1, true), "and it says why")
  P.Hide()

  sim.env.HighgroundDB.teamIconPanel = false
  sim.env.UnitIsGroupLeader = function(unit) return unit == "player" end
  sim:event("PARTY_LEADER_CHANGED")
  assert(not P.Shown(), "the Quick panel switch keeps it away")
  sim.env.HighgroundDB.teamIconPanel = nil
  sim:event("PARTY_LEADER_CHANGED")
  assert(P.Shown(), "becoming leader offers it when the switch is on")
  sim:assertHealthy()
end)

test("Right-click a group member: Team icon sets roles at once, others in submenus", function()
  local sim = new("retail", nil, menus)
  local C = sim.ns.Core
  party(sim)
  local menu = entry(sim, "MENU_UNIT_PARTY", "party1")
  assert(menu, "the leader's menu for a party member has Team icon")
  local tank = find(menu, "Tank")
  assert(tank and tank.text:find("|T", 1, true), "roles at the first level, with their icon")
  tank.run()
  equal(C.TeamIconMarks()[C.CanonUnit("party1")].icon, "tank", "a click sets it")
  local other, class = find(menu, "Other"), find(menu, "Class")
  assert(find(other, "Flag carrier") and #other.children == #C.TEAM_ICON_OTHERS, "the other icons in a submenu")
  equal(#class.children, #C.TeamIconClasses(), "and every class")
  assert(not find(menu, "Automatic"), "no Automatic without a rule")
  find(menu, "No icon").run()
  equal(C.TeamIconMarks()[C.CanonUnit("party1")], nil, "No icon clears it")
  C.SetTeamIconRule("class")
  assert(find(entry(sim, "MENU_UNIT_PARTY", "party1"), "Automatic"), "Automatic under a rule")
  assert(entry(sim, "MENU_UNIT_SELF", "player"), "you can mark yourself")

  sim.units.stranger = { name = "Stranger", classID = 4 }
  equal(entry(sim, "MENU_UNIT_PLAYER", "stranger"), nil, "nothing for players outside the group")
  sim.env.UnitIsGroupLeader = function() return false end
  equal(entry(sim, "MENU_UNIT_PARTY", "party1"), nil, "nothing for a member")
  sim.env.UnitIsGroupLeader = function(unit) return unit == "player" end
  sim:join()
  equal(entry(sim, "MENU_UNIT_RAID_PLAYER", "party1"), nil, "nothing in a battleground, where it would break the menu")
  sim:assertHealthy()
end)
