-- Highground Battlegrounds on its own: loads from its TOCs on Highground's
-- battleground simulator (tools/wowsim/battleground), tracks a match, saves
-- its settings and stands by next to Highground. Run from
-- addons/HighgroundBattlegrounds: luajit tests/addon_test.lua
local t = dofile("../../tools/harness.lua")("battlegrounds addon")
local battleground = dofile("../../tools/wowsim/battleground/runtime.lua")
local test, equal = t.test, t.equal

local function standalone(client, build, saved, others)
  return battleground(client, saved, function(sim, env)
    sim.otherAddons = others
    sim.addon = "HighgroundBattlegrounds" -- saved variable HighgroundBattlegroundsDB
    sim.manifest = build == 40402 and "HighgroundBattlegrounds_Cata.toc" or "HighgroundBattlegrounds.toc"
    env.GetBuildInfo = function() return "x", "1", "Oct 28 2026", build end
    function sim:command(text) self:slash("HIGHGROUNDBATTLEGROUNDS", text, "/hgbg " .. text) end
  end)
end

-- Globals named like Highground's own frames, buttons and windows.
local function highgroundNamed(env)
  local found = {}
  for name in pairs(env) do
    if type(name) == "string" and name:match("^Highground") and not name:match("^HighgroundBattlegrounds") then
      found[#found + 1] = name
    end
  end
  table.sort(found)
  return found
end

local CASES = { { "retail", 120100, "retail" }, { "retail", 16001, "forever" }, { "cata", 40402, "cata" } }

test("new Retail installs work in ordinary battlegrounds without extra alerts", function()
  local sim = standalone("retail", 120100)
  equal(sim.ns.Core.db.allBGs, true, "unrated enabled for first use")
  equal(sim.ns.Core.db.dieAlert, false, "resurrection reminder is optional")
  equal(sim.ns.Core.db.hideTracker, false, "quest tracker stays familiar")
  sim.env.C_PvP.IsRatedBattleground = function() return false end
  sim:join()
  assert(sim.ns.Core.active, "ordinary battleground activates tools")
  for _, saved in ipairs({ {}, { allBGs = false } }) do
    local legacy = standalone("retail", 120100, saved)
    equal(legacy.ns.Core.db.allBGs, true, "upgrades include unrated battlegrounds")
    legacy.rated = false
    legacy:join(907, 1803, "Seething Shore")
    assert(legacy.ns.Core.active and legacy.env.HighgroundBattlegroundsTimersFrame:IsShown(),
      "Seething Shore shows the timers after upgrade")
  end
end)

for _, case in ipairs(CASES) do
  test(case[3] .. ": quick callout settings, clicks and previews work without other panels", function()
    local sim = standalone(case[1], case[2], { timers = false, flags = false })
    local ns = sim.ns
    equal(ns.Core.db.quickCalls, false, "upgrades keep callouts opt-in")
    sim.env.GetSubZoneText = function() return "Farm" end
    local page, toggle = ns.StandaloneSettings.frame
    page.Refresh()
    for _, row in ipairs(page.rows) do if row.key == "quickCalls" then toggle = row end end
    assert(toggle and toggle:IsShown(), "toggle is in basic settings")
    toggle.scripts.OnClick(toggle)
    equal(ns.Core.db.quickCalls, true, "settings enable quick callouts")
    sim:join()
    local w = assert(sim.env.HighgroundBattlegroundsQuickCallsFrame)
    assert(w:IsShown() and not w.docks, "independent panel shown")
    w.buttons[4].scripts.OnClick(w.buttons[4], "LeftButton")
    equal(#sim.chat, 1, "one click sends one message")
    equal(sim.chat[1].text, "Need help — Farm (3+ enemies)", "chosen count and named area")
    equal(sim.chat[1].channel, "INSTANCE_CHAT", "whole battleground receives the callout")
    sim:advance(2.3)
    w.buttons[5].scripts.OnClick(w.buttons[5], "LeftButton")
    equal(#sim.chat, 2, "all clear sends once")
    equal(sim.chat[2].text, "All clear — Farm", "teammates can be told the area is safe")
    equal(table.concat(highgroundNamed(sim.env), ", "), "", "frame uses standalone names")
    sim:command("off"); sim:advance(0.3)
    assert(not w:IsShown()); equal(ns.QuickCalls.Send(1), false, "disabled addon cannot send")
    sim:command("on"); sim:advance(0.3); assert(w:IsShown())
    sim:leave(); assert(not w:IsShown())
    sim:command("test"); assert(w:IsShown() and w.preview)
    equal(w.buttons[4]:IsEnabled(), false, "preview buttons are disabled")
    equal(ns.QuickCalls.Send("3+"), false, "preview cannot send")
    sim:command("test"); assert(not w:IsShown())
    equal(#sim.chat, 2, "previews never send")
    sim:assertHealthy()
  end)

  test(case[3] .. ": loads with its own names and no kill order", function()
    local saved = {}
    local sim = standalone(case[1], case[2], saved)
    local ns = sim.ns
    equal(ns.GAME, case[3], "game detected")
    equal(ns.LABEL, "Highground Battlegrounds", "chat label from the TOC title")
    equal(ns.FRAME_PREFIX, "HighgroundBattlegrounds", "frame prefix from the folder")
    equal(ns.Core.db, saved, "HighgroundBattlegroundsDB is the settings table")
    equal(sim.env.HighgroundBattlegroundsCharDB, ns.Core.pos, "positions per character")
    equal(ns.Core.frame, nil, "no kill-order panel")
    equal(ns.Core.Score, nil, "no scoring")
    equal(ns.GetKillNow(), nil, "no kill target")
    for _, path in ipairs(sim.loaded) do
      for _, omitted in ipairs({ "Scoring", "Targeting", "ui/Rows", "Render", "Actions", "Sniper", "Panel", "/options/",
        "/hub/", "/macros/", "/bounty/", "/arena/", "/world/" }) do
        assert(not path:find(omitted, 1, true), "loads " .. path)
      end
    end
    equal(table.concat(highgroundNamed(sim.env), ", "), "", "no Highground-named globals")
    sim:command("help")
    assert(sim.messages[#sim.messages]:find("Highground Battlegrounds", 1, true), "own chat label")
  end)

  test(case[3] .. ": captures in Arathi Basin, on the windows and the map", function()
    local sim = standalone(case[1], case[2], {})
    local ns = sim.ns
    sim:join()
    assert(ns.Core.active, "active in Arathi Basin")
    sim:command("")
    assert(sim.messages[#sim.messages]:find("on in", 1, true), "/hgbg status")
    assert(sim.env.HighgroundBattlegroundsTimersFrame:IsShown(), "resurrection window shown")
    sim:poi(36)
    sim:poi(37) -- Alliance assault
    assert(ns.Timers.nodes.Stables.capEnd, "capture tracked")
    sim:advance(0.5)
    assert(sim.env.HighgroundBattlegroundsBasesFrame:IsShown(), "objective window shown")
    local pinned = false
    for _, pin in ipairs(sim.env.WorldMapFrame.pins) do
      if pin.template == "HighgroundBattlegroundsPinTemplate" then pinned = true end
    end
    assert(pinned, "map pins from its own template")
    equal(table.concat(highgroundNamed(sim.env), ", "), "", "no Highground-named frames")
    sim:leave()
    assert(not ns.Core.active, "idle after leaving")
  end)

  test(case[3] .. ": flag carrier and resurrection countdown in Warsong Gulch", function()
    local sim = standalone(case[1], case[2], {})
    sim:enemy("Carrier")
    sim:join(1460, 489, "Warsong Gulch")
    sim:event("CHAT_MSG_BG_SYSTEM_HORDE", "The Alliance flag was picked up by Carrier!")
    sim:advance(0.5)
    equal(sim:entry("Carrier").carrier, true, "core identifies carrier")
    local row = sim.env.HighgroundBattlegroundsFlagRow2
    equal(row and row.name.text, "Carrier", "flag window shows the carrier")
    assert(sim.env.HighgroundBattlegroundsFlagsFrame:IsShown(), "flag window shown")
    -- Dead: the spirit healer's countdown reaches the resurrection window.
    sim.units.player.ghost, sim.healerTime = true, 12
    sim:advance(0.5)
    local clock
    for _, r in ipairs(sim.env.HighgroundBattlegroundsTimersFrame.rows) do
      if r:IsShown() and r.time.text == "12s" then clock = r end
    end
    assert(clock, "resurrection countdown shown")
  end)
end

test("settings page saves its switches and the resurrection alert numbers", function()
  local saved = {}
  local sim = standalone("cata", 40402, saved)
  local page = sim.ns.StandaloneSettings.frame
  assert(page, "settings page built")
  page.scripts.OnShow(page)
  equal(#page.rows, 21, "battleground switches, quick callouts, timer switches and alert numbers")
  page.rows[1].scripts.OnClick(page.rows[1])
  equal(saved.allBGs, false, "every-battleground switch saved")
  local stepper
  for _, row in ipairs(page.rows) do if row.stepper and not stepper then stepper = row end end
  equal(stepper.stepper.value, 30, "resurrection alert health default")
  stepper.stepper:SetValue(40)
  equal(saved.points.dieHpPct, 40, "point value saved")
  equal(sim.ns.P("dieHpPct"), 40, "timers read it")
  local minimum
  for _, row in ipairs(page.rows) do if row.label and row.label.text:find("Minimum seconds", 1, true) then minimum = row end end
  minimum.stepper:SetValue(50)
  equal(sim.ns.P("dieResMin"), 2, "minimum above the maximum rejected")
  assert(sim.messages[#sim.messages]:find("must not exceed", 1, true), "and the reason said")
  sim:command("off")
  equal(saved.off, true, "/hgbg off saved")
  sim:join()
  assert(not sim.ns.Core.active, "off: idle in a battleground")
  sim:command("on")
  assert(sim.ns.Core.active, "on: active again")
end)

test("/hgbg test previews the windows outside a battleground", function()
  local sim = standalone("retail", 120100, {})
  sim:command("test")
  local env = sim.env
  assert(env.HighgroundBattlegroundsTimersFrame:IsShown(), "resurrection window")
  assert(env.HighgroundBattlegroundsBasesFrame:IsShown(), "objective window")
  assert(env.HighgroundBattlegroundsFlagsFrame:IsShown(), "flag window")
  sim:advance(2)
  assert(env.HighgroundBattlegroundsTimersFrame:IsShown(), "preview stays up")
  local macro = env.HighgroundBattlegroundsFlagRow2.attrs.macrotext1
  assert(macro:find("@arena1,harm", 1, true) and not macro:find("targetexact", 1, true), "rows target the arena tokens")
  sim:setCombat(true)
  sim:command("test")
  assert(env.HighgroundBattlegroundsFlagsFrame:IsShown(), "secure window stays in combat")
  sim:setCombat(false)
  sim:command("test")
  assert(not env.HighgroundBattlegroundsTimersFrame:IsShown(), "second /hgbg test hides it")
  assert(not env.HighgroundBattlegroundsFlagsFrame:IsShown(), "flag window hidden")
  sim:slash("HIGHGROUNDBATTLEGROUNDS", "", "status") -- sanity: still answers
  sim.ns.Core.SetFeature("flags", false)
  sim:command("test")
  assert(env.HighgroundBattlegroundsTimersFrame:IsShown(), "resurrection window previewed")
  assert(not env.HighgroundBattlegroundsFlagsFrame:IsShown(), "switched-off flag window not previewed")
end)

test("stands by when Highground is loaded: no events, no frames, /hgbg points to /hg", function()
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
  sim:command("test")
  assert(sim.messages[said + 1]:find("use /hg", 1, true), "/hgbg points to /hg")
  sim:join()
  sim:advance(2)
  equal(#sim.timers, 0, "no tickers")
  equal(table.concat(highgroundNamed(sim.env), ", "), "", "no Highground-named frames")
  equal(sim.env.HighgroundBattlegroundsTimersFrame, nil, "no windows")
end)

t.finish("Battlegrounds addon: " .. t.tests .. " scenarios")
