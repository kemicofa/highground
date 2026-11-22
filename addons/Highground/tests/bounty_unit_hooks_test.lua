-- Bounty lines on player tooltips and "put a bounty" in player menus
-- (bounty/Driver.lua), with the modern tooltip/menu APIs and the older
-- OnTooltipSetUnit hook. Run from addons/Highground: luajit tests/bounty_unit_hooks_test.lua
local t = dofile("../../tools/harness.lua")("bounty unit hooks")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local equal = t.equal

-- Modern clients: tooltip post-calls and menu callbacks are recorded.
local function modern(sim, env)
  sim.tipCalls, sim.menus = {}, {}
  env.Enum = env.Enum or {}
  env.Enum.TooltipDataType = { Unit = 1 }
  env.TooltipDataProcessor = { AddTooltipPostCall = function(kind, callback)
    if kind == 1 then sim.tipCalls[#sim.tipCalls + 1] = callback end
  end }
  env.Menu = { ModifyMenu = function(tag, callback)
    sim.menus[tag] = sim.menus[tag] or {}
    table.insert(sim.menus[tag], callback)
  end }
end

-- A unit tooltip: GetUnit names the hovered unit; lines are collected.
local function tooltip(unit)
  local tip = { lines = {} }
  function tip:GetUnit() return unit and "Name", unit end
  function tip:AddLine(text) self.lines[#self.lines + 1] = text end
  return tip
end

local function hover(sim, unit)
  local tip = tooltip(unit)
  for _, callback in ipairs(sim.tipCalls) do callback(tip) end
  return table.concat(tip.lines, "\n")
end

local function menu(sim, tag, unit)
  local root = { buttons = {} }
  function root:CreateDivider() self.divider = true end
  function root:CreateButton(text, run)
    local button = { text = text, run = run, CreateButton = function() end } -- other addons add submenus
    self.buttons[#self.buttons + 1] = button
    return button
  end
  for _, callback in ipairs(sim.menus[tag] or {}) do callback(nil, root, { unit = unit }) end
  for _, button in ipairs(root.buttons) do
    if button.text == "Highground: put a bounty" then return button, root end
  end
end

t.test("player tooltips name a personal bounty's reward and poster", function()
  local sim = new("retail", {}, modern)
  sim.units.mouseover = { name = "Wanted", enemy = true }
  equal(hover(sim, "mouseover"), "", "no bounty: tooltip unchanged")
  sim:command("bounty add 250 Wanted")
  local text = hover(sim, "mouseover")
  assert(text:find("Bounty: 250", 1, true) and text:find("from Me", 1, true), "reward and poster: " .. text)
  sim.units.mouseover = { name = "Bystander", enemy = true }
  equal(hover(sim, "mouseover"), "", "other players unchanged")
  equal(hover(sim, nil), "", "tooltips without a unit unchanged")
  sim.env.HighgroundDB.bounty = false
  sim.units.mouseover = { name = "Wanted", enemy = true }
  equal(hover(sim, "mouseover"), "", "bounties switched off")
end)

t.test("shared bounties show reported funds, contributions and pledges in the singular for one", function()
  local sim = new("retail", {}, modern)
  sim.units.mouseover = { name = "Shared", enemy = true }
  sim:command("bounty shared receive on")
  sim:command("bounty shared publish on")
  sim:command("bounty shared add 300 2h Shared")
  sim:advance(1)
  local text = hover(sim, "mouseover")
  assert(text:find("Shared bounty: ", 1, true) and text:find("with funds reported available", 1, true), "funds: " .. text)
  assert(text:find("1 contribution; ", 1, true) and text:find("pledged", 1, true), "one contribution, singular: " .. text)
  local B = sim.ns.Bounty
  local b = B.Find(sim.ns.Core.CanonUnit("mouseover"))
  B.AnnounceShared(b, true)
  assert(sim.messages[#sim.messages]:find("(1 contribution).", 1, true), "shared alert: " .. sim.messages[#sim.messages])
  B.Announce(b, nil, true)
  local said = table.concat(sim.messages, "\n", #sim.messages - 1)
  assert(said:find("1 contribution; funds reported available", 1, true), "sighting alert: " .. said)
  equal(B.Contributions(2, "; more"), "2 contributions; more", "plural")
  equal(B.Contributions(0), "0 contributions", "zero is plural")
end)

t.test("player menus offer to put a bounty on other players only", function()
  local sim = new("retail", {}, modern)
  sim.units.target = { name = "Ganker", enemy = true }
  local button, root = menu(sim, "MENU_UNIT_TARGET", "target")
  assert(button and root.divider, "entry added after a divider")
  button.run()
  assert(sim.ns.Bounty.Board.win and sim.ns.Bounty.Board.win:IsShown(), "board opened for that player")
  equal(menu(sim, "MENU_UNIT_PLAYER", "player"), nil, "not on yourself")
  equal(menu(sim, "MENU_UNIT_PLAYER", nil), nil, "not without a unit")
  for _, tag in ipairs({ "MENU_UNIT_ENEMY_PLAYER", "MENU_UNIT_FOCUS", "MENU_UNIT_PLAYER" }) do
    assert(sim.menus[tag], "hooked " .. tag)
  end
end)

-- Menus built in PvP instances or under addon restrictions can hold secret
-- sizes; an addon entry taints the build and the menu fails to lay out.
t.test("player menus add nothing in battlegrounds, arenas or under addon restrictions", function()
  local sim = new("retail", {}, modern)
  sim.units.target = { name = "Ganker", enemy = true }
  sim.inBG = true
  equal(menu(sim, "MENU_UNIT_TARGET", "target"), nil, "battleground")
  sim.inBG, sim.inArena = false, true
  equal(menu(sim, "MENU_UNIT_FOCUS", "target"), nil, "arena")
  sim.inArena = false
  local active = {}
  sim.env.Enum.AddOnRestrictionType = { Combat = 0, Encounter = 1, ChallengeMode = 2, PvPMatch = 3, Map = 4, Chat = 5 }
  sim.env.C_RestrictedActions = { IsAddOnRestrictionActive = function(kind) return active[kind] == true end }
  for kind = 0, 4 do
    active = { [kind] = true }
    equal(menu(sim, "MENU_UNIT_ENEMY_PLAYER", "target"), nil, "restriction " .. kind)
  end
  active = { [5] = true }
  assert(menu(sim, "MENU_UNIT_ENEMY_PLAYER", "target"), "chat lockdown keeps the entry")
  active = {}
  assert(menu(sim, "MENU_UNIT_ENEMY_PLAYER", "target"), "back once restrictions lift")
end)

t.test("clients without tooltip post-calls hook OnTooltipSetUnit", function()
  local sim = new("cata", {})
  sim.units.mouseover = { name = "Wanted", enemy = true }
  sim:command("bounty add 50 Wanted")
  local tip = sim.env.GameTooltip
  tip.GetUnit = function() return "Wanted", "mouseover" end
  tip.lines = {}
  for _, hook in ipairs(tip.hooks.OnTooltipSetUnit or {}) do hook(tip) end
  local text = table.concat(tip.lines, "\n")
  assert(text:find("Bounty: 50", 1, true), "line added through the script hook: " .. text)
end)

t.finish("Bounty unit hooks: " .. t.tests .. " tests")
