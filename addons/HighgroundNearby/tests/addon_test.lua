-- Highground Nearby on its own: loads from its TOCs in the repository's
-- simulator (tools/wowsim), lists a hostile player, saves its settings and
-- stands by next to Highground. Run from addons/HighgroundNearby:
-- luajit tests/addon_test.lua
local t = dofile("../../tools/harness.lua")("nearby addon")
local new = dofile("../../tools/wowsim/runtime.lua")
local test, equal = t.test, t.equal
local function standalone(client, build, saved, others)
  return new(client, saved, function(s)
    s.otherAddons = others
    s.addon = "HighgroundNearby" -- saved variable HighgroundNearbyDB
    s.manifest = build == 40402 and "HighgroundNearby_Cata.toc" or "HighgroundNearby.toc"
    s.env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", build end
  end)
end

local function plate(sim, i, name, classID)
  sim.units["nameplate" .. i] = { name = name, classID = classID, enemy = true, level = 60 }
  sim:event("NAME_PLATE_UNIT_ADDED", "nameplate" .. i)
end

local function shownRows(sim)
  local out = {}
  for i = 1, 20 do
    local r = sim.env["HighgroundNearbyNearbyRow" .. i]
    if r and r:IsShown() then out[#out + 1] = r end
  end
  return out
end

for _, case in ipairs({ { "cata", 40402, "cata" }, { "retail", 120100, "retail" }, { "retail", 16001, "forever" } }) do
  test(case[3] .. ": lists a hostile player seen in the open world", function()
    local saved = {}
    local sim = standalone(case[1], case[2], saved)
    local ns = sim.ns
    equal(ns.GAME, case[3], "game detected")
    equal(ns.Core.db, saved, "HighgroundNearbyDB is the settings table")
    sim:advance(1)
    local sounds = #sim.sounds
    plate(sim, 1, "Ganker", 4)
    sim:advance(1)
    local w = sim.env.HighgroundNearbyNearbyFrame
    assert(w and w:IsVisible(), "list shows")
    local row = shownRows(sim)[1]
    equal(row and row.name.text, "Ganker", "enemy listed")
    equal(row.attrs.macrotext1, "/targetexact Ganker-Realm", "row targets the enemy")
    equal(#sim.sounds, sounds + 1, "new enemy alert")
    equal(saved.enemyHistory["Ganker-Realm"].times, 1, "history saved in HighgroundNearbyDB")
    sim.env.SlashCmdList.HIGHGROUNDNEARBY("forget")
    equal(next(saved.enemyHistory), nil, "/hgn forget")
    sim.env.SlashCmdList.HIGHGROUNDNEARBY("clear")
    equal(#shownRows(sim), 0, "/hgn clear empties the list")
    assert(not w:IsVisible(), "empty list hides")
    sim.env.SlashCmdList.HIGHGROUNDNEARBY("test")
    assert(w:IsVisible() and w.info.text == "PREVIEW", "/hgn test previews")
    sim.env.SlashCmdList.HIGHGROUNDNEARBY("test")
    assert(not w:IsVisible(), "/hgn test again hides")
    sim.env.SlashCmdList.HIGHGROUNDNEARBY("theme ember")
    equal(saved.theme, "ember", "/hgn theme")
    assert(ns.Util.Say("x"):find("Highground Nearby", 1, true), "own chat label")
    assert(sim.env.Highground == nil and ns.Commands == nil, "no Highground globals or commands")
    equal(sim.env.HighgroundNearbyFrame, nil, "not Highground's frame name")
    equal(sim.env.HighgroundNearbyRow1, nil, "not Highground's row names")
  end)
end

test("settings page and own names from the TOC", function()
  local saved = {}
  local sim = standalone("retail", 16001, saved)
  local ns = sim.ns
  equal(ns.LABEL, "Highground Nearby", "chat label from the TOC title")
  equal(ns.FRAME_PREFIX, "HighgroundNearby", "frame prefix from the folder")
  equal(ns.STANDBY, false, "runs without Highground")
  local page = ns.StandaloneSettings.frame
  assert(page, "settings page built")
  page.scripts.OnShow(page)
  equal(#page.rows, 7, "switch and six settings")
  page.rows[1].scripts.OnClick(page.rows[1])
  equal(saved.nearby, false, "switch saved")
  plate(sim, 1, "Ganker", 4)
  sim:advance(1)
  equal(#shownRows(sim), 0, "switched off: nothing listed")
  sim.env.SlashCmdList.HIGHGROUNDNEARBY("on")
  equal(saved.nearby, true, "/hgn on")
  plate(sim, 1, "Ganker", 4)
  sim:advance(1)
  equal(#shownRows(sim), 1, "listed again")
  sim.env.SlashCmdList.HIGHGROUNDNEARBY("lock")
  equal(saved.locked, true, "/hgn lock")
  sim.units.nameplate1 = nil
  sim.env.SlashCmdList.HIGHGROUNDNEARBY("off")
  sim:advance(400)
  sim.env.SlashCmdList.HIGHGROUNDNEARBY("")
  assert(sim.messages[#sim.messages]:find("(0 remembered)", 1, true), "forgotten enemies not counted")
end)

test("stands by when Highground is loaded: no events, no frames, /hgn points to /hg", function()
  local saved = {}
  local sim = standalone("retail", 120100, saved, { Highground = true })
  local ns = sim.ns
  equal(ns.STANDBY, true, "standby")
  equal(ns.Core.db, nil, "saved settings untouched")
  for _, f in ipairs(sim.frames) do
    for event in pairs(f.events) do
      assert(event == "PLAYER_LOGIN", "registered " .. event .. " on standby")
    end
  end
  local said = #sim.messages
  assert(said == 1 and sim.messages[1]:find("use /hg", 1, true), "one chat line at login")
  sim.env.SlashCmdList.HIGHGROUNDNEARBY("test")
  assert(sim.messages[said + 1]:find("use /hg", 1, true), "/hgn points to /hg")
  plate(sim, 1, "Ganker", 4)
  sim:advance(2)
  equal(#sim.messages, said + 1, "events do nothing")
  for k, v in pairs(sim.env) do
    local frame = type(k) == "string" and k:match("^Highground") and k ~= "HighgroundNearbyDB" and type(v) == "table"
    assert(not frame, "created " .. tostring(k))
  end
end)
t.finish("Nearby addon: " .. t.tests .. " scenarios")
