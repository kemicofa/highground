-- Tracked enemies (world/Tracking.lua): the journal action and commands,
-- alerts from your own, shared and world sightings, the world channel's
-- watch requests and reports, list rows and map pins.
local t = dofile("../../tools/harness.lua")("tracked enemies")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local test = t.test
local function equal(actual, expected, why) t.equal(actual, expected, why or "values match") end

local HILLSBRAD, ARATHI = 1424, 1417
local CHANNEL = 7

local function setup(client, build)
  return new(client, nil, function(s, env)
    env.GetBuildInfo = function() return "x", "1", "Nov 18 2026", build end
    env.IsInGuild = function() return true end
    env.IsInGroup = function(category)
      if category ~= nil and category == env.LE_PARTY_CATEGORY_INSTANCE then return s.inBG end
      return s.grouped or s.inBG
    end
    s.mapID, s.mapName, s.area = HILLSBRAD, "Hillsbrad Foothills", "Tarren Mill"
    s.units.player.position = { x = 0.5, y = 0.4 }
    s.grouped = true
  end)
end

local function plate(sim, name, token)
  token = token or "nameplate1"
  sim.units[token] = { name = name, classID = 4, enemy = true, level = 60 }
  sim:event("NAME_PLATE_UNIT_ADDED", token)
  sim:advance(0.2)
end

local function said(sim, text)
  for i = #sim.messages, 1, -1 do
    if sim.messages[i]:find(text, 1, true) then return sim.messages[i] end
  end
end

local function sent(sim, start)
  local out = {}
  for _, m in ipairs(sim.sent) do
    if m.prefix == "HighgroundW" and m.channel == "CHANNEL" and m.message:sub(1, #start) == start then out[#out + 1] = m end
  end
  return out
end

-- The realm/faction channel, joined.
local function joinWorld(sim)
  sim.ns.Peers.ChannelID = function() return CHANNEL end
  sim.ns.Peers.CHANNEL = sim.ns.Peers.CHANNEL or "HighgroundUsersPvP"
  sim:command("nearby watch on")
end

local function world(sim, text, sender, name)
  sim:event("CHAT_MSG_ADDON", "HighgroundW", text, "CHANNEL", sender or "Scout-Realm", "", 0, CHANNEL,
    name or sim.ns.Peers.CHANNEL)
end

for _, case in ipairs({ { "cata", 40402 }, { "retail", 120100 }, { "retail", 16001 } }) do
  local client, build = unpack(case)

  test(build .. ": track from the journal and by command, with the list and limit", function()
    local sim = setup(client, build)
    local T, J = sim.ns.Tracking, sim.ns.EnemyJournal
    plate(sim, "Ganker")
    local w = J.Open()
    w:Refresh()
    local track
    for _, b in ipairs(w.actions) do if b.action.label == "Track" then track = b end end
    assert(track, "the journal has a Track action")
    w.entry = w.items[1]
    track.scripts.OnClick(track)
    assert(T.Get("Ganker-Realm"), "tracked from the journal")
    assert(w.items[1].summary:find("Tracked", 1, true), "the journal shows and finds tracked enemies")
    track.scripts.OnClick(track)
    equal(T.Get("Ganker-Realm"), nil, "Stop tracking")
    sim:command("nearby track ganker")
    assert(T.Get("Ganker-Realm"), "a typed name finds the saved enemy, ignoring case")
    assert(said(sim, "Tracking Ganker"))
    sim.units.target = { name = "Targeted", classID = 8, enemy = true, level = 60 }
    sim:command("nearby track target")
    assert(T.Get("Targeted-Realm") or T.Get("Targeted"), "your target")
    sim:command("nearby untrack Targeted")
    equal(#T.List(), 1)
    for i = 2, T.MAX do T.Set("Other" .. i .. "-Realm", true) end
    local ok, why = T.Set("OneTooMany-Realm", true)
    assert(not ok and why:find(tostring(T.MAX), 1, true), "at most twenty")
    sim:command("nearby tracked")
    assert(said(sim, "Tracked enemies: " .. T.MAX .. "/" .. T.MAX))
    sim:assertHealthy()
  end)

  test(build .. ": the journal filters tracked and bounty enemies and never deletes them", function()
    local sim = setup(client, build)
    local T, J, B, H = sim.ns.Tracking, sim.ns.EnemyJournal, sim.ns.Bounty, sim.ns.NearbyHistory
    local function click(button) button.scripts.OnClick(button) end
    local function keys(w)
      local out = {}
      for i, e in ipairs(w.items) do out[i] = e.key end
      table.sort(out)
      return table.concat(out, ",")
    end
    for i, name in ipairs({ "Ganker", "Wanted", "Plain" }) do plate(sim, name, "nameplate" .. i) end
    assert(T.Set("Ganker-Realm", true))
    assert(B.Add("Wanted-Realm", 100))
    sim:command("journal tracked")
    local w = J.win
    assert(w:IsVisible(), "/hg journal tracked opens the journal")
    equal(w.filter:GetValue(), "tracked"); equal(keys(w), "Ganker-Realm")
    sim:command("journal bounty"); equal(keys(w), "Wanted-Realm", "/hg journal bounty")
    click(w.filter.byKey.all); equal(keys(w), "Ganker-Realm,Plain-Realm,Wanted-Realm", "the All choice")
    click(w.filter.byKey.tracked); equal(keys(w), "Ganker-Realm", "the Tracked choice")
    click(w.routeBack); equal(w.filter:GetValue(), "all", "Back returns to the previous filter")
    click(w.routeForward); equal(w.filter:GetValue(), "tracked")
    local delete
    for _, b in ipairs(w.actions) do if b.action.label == "Delete entry" then delete = b end end
    click(delete)
    assert(H.All()["Ganker-Realm"], "a tracked enemy is never deleted")
    assert(w.status:GetText():find("Ganker is tracked", 1, true), "Delete says why: " .. w.status:GetText())
    click(w.filter.byKey.bounty); click(delete)
    assert(H.All()["Wanted-Realm"], "a bounty target is never deleted")
    assert(w.status:GetText():find("Wanted has a bounty", 1, true), "Delete says why: " .. w.status:GetText())
    assert(B.Add("Plain-Realm", 50)); sim:advance(1.1)
    equal(keys(w), "Plain-Realm,Wanted-Realm", "a new bounty joins the open filter within a second")
    assert(T.Set("Ganker-Realm", false))
    sim:command("journal tracked"); equal(#w.items, 0)
    assert(w.detail:GetText():find("No tracked enemies", 1, true), "an empty filter says how to fill it")
    sim:command("journal"); equal(w.filter:GetValue(), "all", "/hg journal shows everyone")
    sim:command("journal later"); assert(said(sim, "Usage: /hg journal [all|tracked|bounty]"))
    w:Hide()
    sim.ns.Options.OpenCommand(sim.ns.CommandCatalog.byId["nearby tracked"])
    assert(w:IsVisible() and w.filter:GetValue() == "tracked", "the tracked list's control opens the Tracked filter")
    sim:assertHealthy()
  end)

  test(build .. ": alerts say where a tracked enemy is, once per zone and gap, never when muted", function()
    local sim = setup(client, build)
    local T, H = sim.ns.Tracking, sim.ns.NearbyHistory
    sim:command("nearby track Bob")
    plate(sim, "Bob")
    assert(said(sim, "Tracked enemy near you: Bob · Hillsbrad Foothills (Tarren Mill)"), "your own sighting")
    local sounds = #sim.sounds
    assert(sounds > 0, "the tracked enemy cue plays")
    sim.units.nameplate1 = nil
    sim:event("NAME_PLATE_UNIT_REMOVED", "nameplate1")
    sim:advance(5)
    sim:event("CHAT_MSG_ADDON", "HighgroundW", "1:" .. HILLSBRAD .. ":Bob-Realm,ROGUE,60,4000,4000,60,1,", "PARTY", "Ally-Realm")
    sim:advance(0.2)
    equal(#sim.sounds, sounds, "the same zone within two minutes stays quiet")
    sim:event("CHAT_MSG_ADDON", "HighgroundW", "1:" .. ARATHI .. ":Bob-Realm,ROGUE,60,4000,4000,60,0,", "GUILD", "Officer-Realm")
    sim:advance(0.2)
    assert(said(sim, "seen by Officer (guild)"), "another zone alerts again with who saw it")
    local h = T.Get("Bob-Realm")
    equal(h.report.by, "Officer-Realm"); equal(h.report.via, "guild")
    H.SetMuted(h, true)
    sim:advance(200)
    local count = #sim.messages
    sim:event("CHAT_MSG_ADDON", "HighgroundW", "1:" .. HILLSBRAD .. ":Bob-Realm,ROGUE,60,4000,4000,60,0,", "PARTY", "Ally-Realm")
    sim:advance(0.2)
    equal(#sim.messages, count, "muted enemies stay quiet")
    sim:command("nearby tracking off")
    H.SetMuted(h, false)
    sim:advance(200)
    count = #sim.messages
    plate(sim, "Bob", "nameplate2")
    for i = count + 1, #sim.messages do
      assert(not sim.messages[i]:find("Tracked", 1, true), "the switch turns tracking alerts off")
    end
    sim:assertHealthy()
  end)

  test(build .. ": tracked enemies are listed from any zone and pinned apart on the map", function()
    local sim = setup(client, build)
    local N, W = sim.ns.Nearby, sim.ns.WorldMap
    sim:command("nearby track Bob")
    sim:event("CHAT_MSG_ADDON", "HighgroundW", "1:" .. ARATHI .. ":Bob-Realm,ROGUE,60,2000,2000,60,0,;Other-Realm,MAGE,60,2000,2000,60,0,", "GUILD", "Officer-Realm")
    N.Update()
    local row
    for _, r in ipairs(N.rows) do if r:IsShown() and r.who == "Bob" then row = r end end
    assert(row, "listed though seen in another zone")
    assert(row.sub.text:find("^Tracked"), "marked tracked")
    for _, r in ipairs(N.rows) do assert(not (r:IsShown() and r.who == "Other"), "untracked enemies of other zones stay off the list") end
    local pins = W.Pins(ARATHI)
    local tracked, others = nil, 0
    for _, p in ipairs(pins) do
      if p.sortKey == "tracked:Bob" then tracked = p elseif p.sortKey then others = others + 1 end
    end
    assert(tracked and tracked.mark and tracked.label == "Bob", "a marked, named pin")
    equal(others, 1, "not grouped with the enemy beside it")
    sim:assertHealthy()
  end)

  if client ~= "cata" then
    test(build .. ": watching with everyone asks, answers and reads reports in the world channel only", function()
      local sim = setup(client, build)
      local T, N = sim.ns.Tracking, sim.ns.Nearby
      sim:command("nearby track Bob")
      sim:advance(2)
      assert(sim.ns.Core.O("nearbyTrackWorld"), "on by default")
      equal(#sent(sim, "1T:"), 0, "nothing tells others whom you track before the users channel is joined")
      joinWorld(sim)
      sim:advance(2)
      local asks = sent(sim, "1T:")
      equal(#asks, 1); equal(asks[1].message, "1T:Bob-Realm"); equal(asks[1].target, CHANNEL)
      -- Someone asks for Evil; you see Evil: one rough report.
      world(sim, "1T:Evil-Realm;Me-Realm")
      plate(sim, "Evil")
      local reports = sent(sim, "1R:")
      equal(#reports, 1)
      equal(reports[1].message, "1R:" .. HILLSBRAD .. ":Evil-Realm,ROGUE,60,10,8,0,Tarren Mill", "a grid cell and the sub-zone")
      plate(sim, "Evil", "nameplate2")
      equal(#sent(sim, "1R:"), 1, "one report a minute")
      -- A report of yours.
      world(sim, "1R:" .. HILLSBRAD .. ":Bob-Realm,ROGUE,60,3,4,10,Southshore")
      sim:advance(0.2)
      assert(said(sim, "Tracked: Bob · around Hillsbrad Foothills (Southshore) · reported by Scout"))
      local e = N.seen.Bob
      equal(e.via, "world"); equal(e.x, 3.5 / 20); equal(e.y, 4.5 / 20)
      -- Another channel, your own messages and watch off: ignored.
      local count = #sim.messages
      world(sim, "1R:" .. HILLSBRAD .. ":Bob-Realm,ROGUE,60,3,4,0,Elsewhere", "Scout-Realm", "Trade")
      world(sim, "1R:" .. HILLSBRAD .. ":Bob-Realm,ROGUE,60,3,4,0,Elsewhere", "Me-Realm")
      sim:advance(200)
      equal(#sim.messages, count, "another channel and your own messages are ignored")
      sim:command("nearby watch off")
      count = #sim.messages
      world(sim, "1R:" .. HILLSBRAD .. ":Bob-Realm,ROGUE,60,3,4,0,Elsewhere")
      sim:advance(0.2)
      equal(#sim.messages, count, "nothing is read with watching off")
      equal(T.Get("Bob-Realm").report.area, "Southshore")
      sim:advance(700)
      equal(#sent(sim, "1T:"), 1, "no requests while watching is off")
      sim:assertHealthy()
    end)
  end
end

t.finish("Tracked enemies: " .. t.tests .. " scenarios, " .. t.failures .. " failures")
