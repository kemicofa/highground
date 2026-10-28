-- Highground Arena on its own: loads from its TOCs in the repository's
-- simulator (tools/wowsim), shows the arena panel, previews, saves.
-- Run from addons/HighgroundArena: luajit tests/addon_test.lua
local t = dofile("../../tools/harness.lua")("arena addon")
local new = dofile("../../tools/wowsim/runtime.lua")
local test, equal = t.test, t.equal
local function standalone(client, build, saved, others)
  return new(client, saved, function(s)
    s.otherAddons = others
    s.addon = "HighgroundArena" -- saved variable HighgroundArenaDB
    s.manifest = build == 40402 and "HighgroundArena_Cata.toc" or "HighgroundArena.toc"
    s.env.GetBuildInfo = function() return "1.0.0", "1", "Oct 28 2026", build end
  end)
end

local function enterArena(sim)
  sim.instanceType = "arena"
  sim:event("PLAYER_ENTERING_WORLD")
  sim:advance(1)
end

local function opponent(sim, i, name, classID, fields)
  fields = fields or {}
  fields.name, fields.classID, fields.enemy = name, classID, true
  sim.units["arena" .. i] = fields
  return fields
end

for _, case in ipairs({ { "retail", 120100, "retail" }, { "retail", 16001, "forever" }, { "cata", 40402, "cata" } }) do
  test(case[3] .. ": loads, shows one clickable row per arena opponent", function()
    local saved = {}
    local sim = standalone(case[1], case[2], saved)
    local ns, env = sim.ns, sim.env
    equal(ns.GAME, case[3], "game detected")
    equal(ns.Core.db, saved, "HighgroundArenaDB is the settings table")
    equal(env.HighgroundArenaArenaFrame, nil, "no panel outside an arena")
    enterArena(sim)
    local rogue = opponent(sim, 1, "Sneak", 4, { health = 30 })
    opponent(sim, 2, "Healer", 5)
    sim:advance(0.5)
    local panel, row1 = env.HighgroundArenaArenaFrame, env.HighgroundArenaArenaRow1
    assert(panel and panel:IsVisible(), "panel shows in an arena")
    equal(panel.info.text, "2v2", "bracket shown")
    assert(env.HighgroundArenaArenaRow2:IsVisible() and not env.HighgroundArenaArenaRow3:IsVisible(), "one row per opponent")
    equal(row1.attrs.unit, "arena1", "row bound to its arena token")
    equal(row1.name.text, "Sneak", "row names the opponent")
    equal(row1.right.text, "30%", "row shows health")
    equal(row1.trinket.shown, true, "trinket icon shown")
    sim:setCombat(true)
    sim:click(row1, "LeftButton")
    assert(sim.units.target == rogue, "left-click targets in combat")
    sim:setCombat(false)
    sim.instanceType = nil
    sim:event("PLAYER_ENTERING_WORLD")
    sim:advance(0.5)
    assert(not panel:IsVisible(), "panel hides outside arenas")
    sim.env.SlashCmdList.HIGHGROUNDARENA("help")
    assert(ns.Util.Say("x"):find("Highground Arena", 1, true), "own chat label")
    assert(env.HighgroundArenaFrame == nil and env.Highground == nil and ns.Commands == nil,
      "no Highground globals or commands")
  end)
end

test("/hga test previews the panel, /hga off keeps it hidden", function()
  local saved = {}
  local sim = standalone("retail", 120100, saved)
  local env = sim.env
  sim:slash("HIGHGROUNDARENA", "test")
  assert(env.HighgroundArenaArenaFrame:IsVisible(), "preview shows the panel")
  equal(env.HighgroundArenaArenaRow1.name.text, "Rogue", "preview rows filled")
  sim:slash("HIGHGROUNDARENA", "test")
  assert(not env.HighgroundArenaArenaFrame:IsVisible(), "preview toggles off")
  sim:setCombat(true)
  sim:slash("HIGHGROUNDARENA", "test")
  assert(not env.HighgroundArenaArenaFrame:IsVisible(), "no preview in combat")
  sim:setCombat(false)
  sim:slash("HIGHGROUNDARENA", "off")
  equal(saved.arena, false, "switch saved")
  enterArena(sim)
  opponent(sim, 1, "Sneak", 4)
  sim:advance(0.5)
  assert(not env.HighgroundArenaArenaFrame:IsVisible(), "switched-off panel stays hidden")
  sim:slash("HIGHGROUNDARENA", "on")
  assert(env.HighgroundArenaArenaFrame:IsVisible(), "switched back on")
end)

test("settings page and own names from the TOC", function()
  local saved = {}
  local sim = standalone("cata", 40402, saved)
  local ns, env = sim.ns, sim.env
  equal(ns.LABEL, "Highground Arena", "chat label from the TOC title")
  equal(ns.FRAME_PREFIX, "HighgroundArena", "frame prefix from the folder")
  equal(ns.STANDBY, false, "runs without Highground")
  local page = ns.StandaloneSettings.frame
  assert(page, "settings page built")
  page.scripts.OnShow(page)
  equal(#page.rows, 1, "the arena panel switch")
  equal(page.rows[1].checked, true, "on by default")
  enterArena(sim)
  opponent(sim, 1, "Sneak", 4)
  sim:advance(0.5)
  assert(env.HighgroundArenaArenaFrame:IsVisible(), "panel shown")
  page.rows[1].scripts.OnClick(page.rows[1])
  equal(saved.arena, false, "switch saved")
  sim:advance(0.5)
  assert(not env.HighgroundArenaArenaFrame:IsVisible(), "switching off hides the panel")
end)

test("stands by when Highground is loaded: no events, no panel, /hga points to /hg", function()
  local saved = {}
  local sim = standalone("retail", 120100, saved, { Highground = true })
  local ns, env = sim.ns, sim.env
  equal(ns.STANDBY, true, "standby")
  equal(ns.Core.db, nil, "saved settings untouched")
  for _, f in ipairs(sim.frames) do
    for event in pairs(f.events) do
      assert(event == "PLAYER_LOGIN", "registered " .. event .. " on standby")
    end
    assert(not (f.name and f.name:match("^Highground")), "named frame on standby: " .. tostring(f.name))
    assert(not f.scripts.OnUpdate, "no polling on standby")
  end
  local said = #sim.messages
  assert(said == 1 and sim.messages[1]:find("use /hg", 1, true), "one chat line at login")
  env.SlashCmdList.HIGHGROUNDARENA("test")
  equal(env.HighgroundArenaArenaFrame, nil, "no preview")
  assert(sim.messages[said + 1]:find("use /hg", 1, true), "/hga points to /hg")
  enterArena(sim)
  opponent(sim, 1, "Sneak", 4)
  sim:advance(0.5)
  equal(env.HighgroundArenaArenaFrame, nil, "no panel in an arena")
end)
t.finish("Arena addon: " .. t.tests .. " scenarios")
