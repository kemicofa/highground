-- Highground Bounties on its own: loads from its TOCs in the repository's
-- simulator (tools/wowsim), alerts, opens the board, saves, stands by.
-- Run from addons/HighgroundBounties: luajit tests/addon_test.lua
local t = dofile("../../tools/harness.lua")("bounties addon")
local new = dofile("../../tools/wowsim/runtime.lua")
local test, equal = t.test, t.equal
local SOUND = "Interface\\AddOns\\HighgroundBounties\\shared\\sounds\\bounty.ogg"

local function standalone(client, build, saved, others)
  return new(client, saved, function(s)
    s.otherAddons = others
    s.addon = "HighgroundBounties" -- saved variable HighgroundBountiesDB
    s.manifest = build >= 40000 and build < 50000 and "HighgroundBounties_Cata.toc" or "HighgroundBounties.toc"
    s.env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", build end
  end)
end

local function bountySounds(sim)
  local n = 0
  for _, s in ipairs(sim.sounds) do if s == SOUND then n = n + 1 end end
  return n
end

local function said(sim, text)
  for _, m in ipairs(sim.messages) do if m:find(text, 1, true) then return m end end
end

for _, case in ipairs({ { "retail", 120100, "retail" }, { "retail", 16001, "forever" }, { "cata", 40402, "cata" } }) do
  test(case[3] .. ": loads, alerts on a bounty target, marks its plate and opens the board with /hgb", function()
    local saved = {}
    local sim = standalone(case[1], case[2], saved)
    local ns, slash = sim.ns, sim.env.SlashCmdList.HIGHGROUNDBOUNTIES
    equal(ns.GAME, case[3], "game detected")
    equal(ns.Core.db, saved, "HighgroundBountiesDB is the settings table")
    equal(ns.Bounty.SOUND, SOUND, "sound under shared/sounds")

    slash("add 500 Ganker; camps the flight master")
    assert(said(sim, "500g on Ganker"), "bounty added")
    slash("add")
    assert(said(sim, "usage: /hgb add"), "chat lines name /hgb")
    sim:advance(1)
    equal(bountySounds(sim), 0, "no alert yet")

    sim.units.target = { name = "Ganker", classID = 4, enemy = true }
    sim:event("PLAYER_TARGET_CHANGED")
    equal(bountySounds(sim), 1, "bounty sound when targeted")
    assert(sim.notices[1] and sim.notices[1]:find("BOUNTY: Ganker %(500g, yours%)"), "center-screen announcement")
    local line = said(sim, "BOUNTY: Ganker")
    assert(line:find("Highground Bounties", 1, true) and not line:find("Bounties bounty", 1, true), "own chat label")
    local row = ns.Nearby.rows and ns.Nearby.rows[1]
    assert(row and row:IsShown() and row.who == "Ganker-Realm", "nearby list shows the target")
    assert(row.wbBounty and row.wbBounty:IsShown(), "nearby row framed in gold")

    sim.units.nameplate1 = sim.units.target
    sim.plates.nameplate1 = sim.env.CreateFrame("Frame", nil, sim.env.UIParent)
    sim:event("NAME_PLATE_UNIT_ADDED", "nameplate1")
    sim:advance(1)
    local mark = ns.Bounty.plateMarks[1]
    assert(mark and mark:IsShown(), "coin beside the nameplate")
    equal(bountySounds(sim), 1, "no repeat while in sight")

    slash("")
    local w = sim.env.HighgroundBountiesBountyFrame
    assert(w and w:IsShown(), "/hgb opens the bounty board")
    assert(w.rows[1]:IsShown() and w.rows[1].entry.name == "Ganker-Realm", "bounty on the board")
    slash("")
    assert(not w:IsShown(), "/hgb closes it")
    sim.env.HighgroundBounties_BountyBoard()
    assert(w:IsShown(), "key binding opens it")
    equal(sim.env.BINDING_NAME_HIGHGROUNDBOUNTIES_BOUNTY, "Toggle the bounty board", "binding named")

    slash("theme ember")
    equal(saved.theme, "ember", "/hgb theme")
    slash("off")
    equal(saved.bounty, false, "/hgb off saved")
    slash("nearby")
    assert(said(sim, "nearby enemies on (1 remembered)"), "/hgb nearby shows its status")
    equal(saved.nearby, nil, "and changes nothing")
    slash("nearby off")
    equal(saved.nearby, false, "/hgb nearby off saved")
    assert(sim.env.Highground == nil and sim.env.HighgroundBountyFrame == nil, "no Highground globals")
  end)
end

test("settings page: bounty and nearby keys, switches save, button opens the board", function()
  local saved = {}
  local sim = standalone("retail", 16001, saved)
  local ns = sim.ns
  equal(ns.LABEL, "Highground Bounties", "chat label from the TOC title")
  equal(ns.FRAME_PREFIX, "HighgroundBounties", "frame prefix from the folder")
  equal(ns.STANDBY, false, "runs without Highground")
  local page = ns.StandaloneSettings.frame
  assert(page, "settings page built")
  page.scripts.OnShow(page)
  equal(#page.rows, 16, "bounty, nearby and sound settings")
  equal(page.rows[2]:GetChecked(), true, "bounty markers on by default")
  equal(page.rows[5]:GetChecked(), false, "telling the group off by default")
  page.rows[5].scripts.OnClick(page.rows[5])
  equal(saved.bountyTellGroup, true, "one click turns it on")
  for _, def in ipairs(ns.OptionsConfig.features) do
    if def.key == "bounty" then assert(def.desc:find("/hgb", 1, true), "bounty switch names /hgb") end
    if def.key == "sound" then assert(not def.desc:find("GO", 1, true), "sound switch lists only this addon's") end
  end
  page.rows[1].scripts.OnClick(page.rows[1])
  equal(saved.bounty, false, "bounty switch saved")
  equal(ns.Bounty.Enabled(), false, "alerts read the same switch")
  sim.env.SlashCmdList.HIGHGROUNDBOUNTIES("add Sneak")
  sim.units.target = { name = "Sneak", classID = 4, enemy = true }
  sim:event("PLAYER_TARGET_CHANGED")
  equal(bountySounds(sim), 0, "no alert with bounties off")
  local open
  for _, child in ipairs(page.children) do
    if child.text == "Open bounty board" then open = child end
  end
  assert(open, "button on the page")
  open.scripts.OnClick(open)
  assert(sim.env.HighgroundBountiesBountyFrame:IsShown(), "button opens the board")
end)

test("stands by when Highground is loaded: no events, no frames, /hgb points to /hg", function()
  local saved = {}
  local sim = standalone("retail", 120100, saved, { Highground = true })
  local ns = sim.ns
  equal(ns.STANDBY, true, "standby")
  equal(ns.Core.db, nil, "saved settings untouched")
  for _, f in ipairs(sim.frames) do
    for event in pairs(f.events) do
      assert(event == "PLAYER_LOGIN", "registered " .. event .. " on standby")
    end
    local name = f.GetName and f:GetName()
    assert(not (name and name:find("^Highground")), "named frame on standby: " .. tostring(name))
  end
  local count = #sim.messages
  assert(count == 1 and sim.messages[1]:find("use /hg", 1, true), "one chat line at login")
  sim.env.SlashCmdList.HIGHGROUNDBOUNTIES("")
  equal(sim.env.HighgroundBountiesBountyFrame, nil, "no bounty board")
  assert(sim.messages[count + 1]:find("use /hg", 1, true), "/hgb points to /hg")
  sim.env.HighgroundBounties_BountyBoard()
  equal(sim.env.HighgroundBountiesBountyFrame, nil, "key binding opens nothing")
  sim.units.target = { name = "Ganker", classID = 4, enemy = true }
  sim:event("PLAYER_TARGET_CHANGED")
  sim:event("CHAT_MSG_ADDON", "HighgroundB", "1:Q", "GUILD", "Boss-Realm")
  sim:advance(10)
  equal(#sim.messages, count + 2, "events do nothing")
  equal(#sim.sent, 0, "nothing sent")
end)
t.finish("Bounties addon: " .. t.tests .. " scenarios")
