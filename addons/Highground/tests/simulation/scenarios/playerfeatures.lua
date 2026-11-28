local test, newClient, check = ...
-- Exercise the existing full-feature setup; fresh installs are covered by onboarding.
local function new(client, saved, configure) return newClient(client, saved or {}, configure) end
local function equal(a, b, why) return check(a, b, why or "values match") end

test("configuration links resolve tools to settings and preserve embedded setup pages", function()
  local sim = new("cata")
  for _, key in ipairs({ "setup", "alerts", "history", "journal" }) do
    sim:command(key)
    sim:command("config " .. key)
    local hub = sim.ns.Hub
    equal(hub.current, ({ history = "battlegrounds-settings", journal = "nearby" })[key] or key)
    assert(hub.win:IsShown())
    hub.Show(key)
    assert(hub.win:IsShown(), "reopening a borrowed section keeps the hub")
    sim:assertHealthy()
  end
  sim:command("bounty claims"); sim:command("macros history")
  assert(not sim.ns.Bounty.Ledger.win:IsShown(), "macro history replaces the claims page")
  assert(sim.ns.Macros.Backups.win:IsShown())
end)

test("full profiles restore appearance, toggles, tracking and positions after combat", function()
  local sim = new("cata")
  local P, C, CS = sim.ns.Options.Profiles, sim.ns.Core, sim.ns.CharacterSettings
  C.db.sniper, C.db.theme = false, "parchment"
  C.db.style = { fontScale = 1.1, hide = { mana = true } }
  C.db.disabledCooldowns = { [45438] = true }
  C.pos.arenaPoint = { "LEFT", "LEFT", 20, 40 }
  sim.ns.Alerts.SetMode("quiet")
  local exported = P.ExportString(P.Snapshot(), "Healer alt")
  C.db.sniper, C.db.theme, C.db.style = true, "ember", {}
  C.db.disabledCooldowns, C.pos.arenaPoint = {}, nil
  local ok, _, index = CS.Import(exported)
  assert(ok, "a full profile imports")
  sim:setCombat(true)
  equal(select(1, CS.Copy({ import = index }, "battlegrounds")), false, "no copying in combat")
  equal(C.db.sniper, true, "nothing changes in combat")
  sim:setCombat(false)
  for _, addon in ipairs(sim.ns.SettingsParts.ADDONS) do
    assert(CS.Copy({ import = index }, addon), "copies " .. addon)
  end
  equal(C.db.sniper, false, "switches restored"); equal(C.db.theme, "parchment", "theme restored")
  equal(C.db.style.fontScale, 1.1, "text size restored"); equal(C.pos.arenaPoint[3], 20, "position restored")
  assert(C.db.disabledCooldowns[45438], "tracking restored")
  equal(sim.ns.Alerts.Preset(C.db.alerts), "quiet", "alerts restored")
  local bad = P.Snapshot(); bad.setup.positions.arenaPoint[3] = math.huge
  local before = C.db.style
  equal(P.Prepare(bad), nil, "an invalid position is rejected"); equal(C.db.style, before, "invalid setup is atomic")
end)

test("role presets change the battleground size being edited only", function()
  local sim = new("cata")
  local C, CS = sim.ns.Core, sim.ns.CharacterSettings
  C.db.highestRank = false
  assert(CS.Select("bg15"))
  assert(sim.ns.Setup.Apply("carrier"))
  equal(C.db.dieAlert, false, "the preset applies"); equal(C.On("sniper"), false, "to 15v15")
  equal(C.db.highestRank, false, "and leaves Macros alone")
  assert(CS.Select("bg10"))
  equal(C.On("sniper"), true, "10v10 keeps its own settings")
  equal(C.db.highestRank, false, "Macros is not per size")
  sim:assertHealthy()
end)

for _, game in ipairs({ "cata", "retail", "forever" }) do
  test(game .. " retired Team callouts links fall back safely without touching chat", function()
    local sim = new(game == "cata" and "cata" or "retail", { hubSection = "calls" }, function(_, env)
      if game == "forever" then env.GetBuildInfo = function() return "1.60.1", "1", "", 16001 end end
    end)
    sim:command("")
    equal(sim.ns.Hub.current, "home", "obsolete saved section falls back to Home")
    sim:command("config calls")
    equal(sim.ns.Hub.current, "home", "obsolete links fall back to Home")
    sim:join()
    sim.env.ChatFrame_OpenChat("/w Friend unfinished message")
    for _, command in ipairs({ "calls", "calls incoming 3 Farm", "calls help", "calls clear", "calls escort" }) do
      sim:command(command)
    end
    sim:advance(0.1)
    equal(sim.chatDraft, "/w Friend unfinished message")
    equal(#sim.chat, 0)
    equal(sim.ns.ObjectiveCalls, nil, "removed window is not loaded")
    for _, section in ipairs(sim.ns.Hub.Sections()) do assert(section.key ~= "calls") end
    for _, item in ipairs(sim.ns.PanelControls.Items("quickCallsPoint")) do assert(item.text ~= "Team callouts") end
    sim:assertHealthy()
  end)
end

test("alert arbitration chooses urgent sound and honors channel preferences", function()
  local sim = new("cata")
  local A, played = sim.ns.Alerts, {}
  A.Emit("nearby", "enemy", "Nearby", function() played[#played + 1] = "nearby" end)
  A.Emit("capture", "base", "Capture", function() played[#played + 1] = "capture" end)
  sim:advance(0.2)
  equal(#played, 1); equal(played[1], "capture")
  A.SetMode("quiet")
  A.Emit("capture", "next", "Still readable", function() played[#played + 1] = "bad" end)
  sim:advance(2)
  equal(#played, 1)
  A.SetMode("critical")
  local count = #sim.messages
  A.Emit("nearby", "second", "Should be hidden")
  equal(#sim.messages, count)
  -- A switch turned on after a preset wins: nothing filters it again.
  A.SetChannel("lockon", "sound", true)
  equal(A.Preset(A.Settings()), "custom")
  sim:command("alerts preset loud")
  equal(A.Preset(A.Settings()), "custom", "an unknown preset changes nothing")
  assert(sim.messages[#sim.messages]:find("quiet = Text only", 1, true), "and lists the presets")
  sim:command("alerts preset quiet")
  equal(A.Preset(A.Settings()), "quiet", "the command sets every switch like the Alerts window")
  A.SetChannel("lockon", "sound", true)
  A.Emit("lockon", "target", nil, function() played[#played + 1] = "lockon" end)
  sim:advance(0.2)
  equal(played[#played], "lockon")
end)

test("secret arena and flag health goes straight to the display widget", function()
  local sim = new("retail")
  local secret = { secret = true }
  sim:joinArena()
  sim.units.arena1 = { name = "Enemy", enemy = true, classID = 4 }
  sim.env.UnitHealthPercent = function() return secret end
  sim.env.UnitHealth = function() return secret end
  sim.env.UnitHealthMax = function() return secret end
  sim:advance(0.3)
  equal(sim.ns.Arena.rows[1].bar.value, secret)
  local bar = sim.env.CreateFrame("StatusBar")
  local hp, drawn = sim.ns.Hud.Health(bar, "arena1")
  equal(hp, nil); equal(drawn, true); equal(bar.value, secret)
end)

test("resurrection advice excludes flag and orb carriers", function()
  local sim = new("cata")
  sim:join(1460, 489, "Warsong Gulch")
  local T = sim.ns.Timers
  sim.units.player.health = 5
  T.MyGraveyard = function() return { label = "Home" } end
  T.NextWave = function() return sim.now + 5 end
  assert(T.GoodTimeToDie(sim.now))
  sim:event("CHAT_MSG_BG_SYSTEM_ALLIANCE", "The Horde flag was picked up by Me!")
  equal(T.GoodTimeToDie(sim.now), nil)
  local retail = new("retail")
  retail:join(417, 998, "Temple of Kotmogu")
  retail.units.player.buffs = { { spellId = 121164 } }
  assert(retail.ns.PlayerHasObjective())
end)

test("completed match history saves result, personal stats and observed timeline once", function()
  local sim = new("retail")
  sim.env.C_PvP.GetActiveMatchWinner = function() return 1 end
  sim.env.C_PvP.GetActiveMatchDuration = function() return 123 end
  sim:join()
  sim.scores[#sim.scores + 1] = { name = "Me-Realm", faction = 1, killingBlows = 4, deaths = 2, damageDone = 12000, ratingChange = 10 }
  sim:event("CHAT_MSG_BG_SYSTEM_ALLIANCE", "The Alliance has taken the stables!")
  sim:event("PVP_MATCH_COMPLETE")
  local H = sim.ns.MatchHistory
  equal(#H.All(), 1); equal(H.All()[1].result, "Win")
  equal(H.All()[1].duration, 123); equal(H.All()[1].stats.killingBlows, 4)
  equal(H.All()[1].stats.ratingChange, 10); assert(#H.All()[1].events > 0)
  sim:event("PVP_MATCH_COMPLETE"); sim:leave()
  equal(#H.All(), 1, "no duplicate result on exit")
  H.Open(); H.win.search:SetText("Win"); equal(#H.win.items, 1)
end)

-- The same character back in the same battleground after a /reload or a
-- reconnect: saved data carried over, the match clock moved on.
local function rejoin(sim, after, complete)
  local again = new(sim.client, sim.env.HighgroundDB, function(s)
    s.now = sim.now + after
    s.mapID, s.instanceID, s.mapName, s.inBG = sim.mapID, sim.instanceID, sim.mapName, true
    s.matchStart, s.matchComplete = sim.matchStart, complete
  end)
  again:event("PLAYER_ENTERING_WORLD"); again:event("UPDATE_BATTLEFIELD_SCORE")
  again:advance(1)
  return again, again.ns.MatchHistory
end

test("a reload on the final scoreboard keeps the match saved once", function()
  local sim = new("cata")
  sim.env.GetBattlefieldWinner = function() return sim.matchComplete and 1 or nil end
  sim:join(); sim:advance(30)
  sim.matchComplete = true
  sim:event("UPDATE_BATTLEFIELD_SCORE")
  equal(#sim.ns.MatchHistory.All(), 1)
  local again, H = rejoin(sim, 20, true)
  again.env.GetBattlefieldWinner = function() return 1 end
  again:event("UPDATE_BATTLEFIELD_SCORE"); again:advance(2)
  again:event("PVP_MATCH_COMPLETE"); again:leave()
  equal(#H.All(), 1, "still one match")
  again:assertHealthy()
end)

test("a long disconnect resumes the same match; one that ended meanwhile is saved as left early", function()
  local sim = new("cata")
  sim:join(); sim:advance(60)
  sim:event("CHAT_MSG_BG_SYSTEM_ALLIANCE", "The Alliance has taken the stables!")
  sim:advance(2)
  local again, H = rejoin(sim, 300, false)
  assert(H.current.events[1].text:find("stables", 1, true), "back five minutes later: the same record")
  again.matchComplete = true
  again:event("PVP_MATCH_COMPLETE"); again:leave()
  equal(#H.All(), 1); assert(H.All()[1].events[1].text:find("stables", 1, true), "saved with its first part")
  local gone = new("cata", again.env.HighgroundDB)
  gone:join(); gone:advance(60)
  local later = new("cata", gone.env.HighgroundDB, function(s) s.now = gone.now + 1800 end)
  later:event("PLAYER_ENTERING_WORLD"); later:advance(1)
  local all = later.ns.MatchHistory.All()
  equal(#all, 2, "the match left by the disconnect is kept")
  equal(all[1].result, "Left early")
  assert(all[1].duration >= 60 and all[1].duration <= 62, "lasting until it was last seen, not the half hour away")
  later:assertHealthy()
end)

test("enemy journal searches notes and muted encounters stay recorded without alerts", function()
  local sim = new("cata")
  local N, H = sim.ns.Nearby, sim.ns.NearbyHistory
  N.Note("Enemy-Realm", "ROGUE", 85, "Guild")
  local h = H.All()["Enemy-Realm"]
  h.note, h.muted = "Defends the mine", true
  sim.ns.EnemyJournal.Open()
  local w = sim.ns.EnemyJournal.win
  w.search:SetText("mine"); equal(#w.items, 1)
  sim:advance(1)
  local messages, sounds = #sim.messages, #sim.sounds
  N.Hid("Enemy-Realm", 1784)
  sim.env.GetMoney = function() return 50 * 10000 end
  local bounty = assert(sim.ns.Bounty.Add("Enemy-Realm", 50, "Muted"))
  sim.ns.Bounty.Announce(bounty, "test")
  sim:advance(1)
  equal(#sim.messages, messages); equal(#sim.sounds, sounds)
  assert(H.Muted("Enemy"), "short and full names match")
  assert(h.last, "muting does not delete history")
end)

test("bounty claims survive removal and only authorized reviewers settle them", function()
  local sim = new("cata")
  local B = sim.ns.Bounty
  local bounty = assert(B.Add("Enemy", 500, "Wanted"))
  assert(B.Claim("Enemy")); assert(B.Claim("Enemy"))
  local L, c = B.Ledger, B.Ledger.All()[1]
  equal(#L.All(), 1, "duplicate report coalesced")
  equal(L.Change(c, "paid"), false, "approval first")
  assert(L.Change(c, "approved")); assert(L.Change(c, "paid"))
  B.Remove("Enemy"); equal(#L.All(), 1); equal(c.state, "paid")
  equal(L.Change(c, "rejected"), false, "paid claim is final")
  local other = L.Record({ name = "Other-Realm", gold = 10, by = "Someone-Realm", at = 1, state = "approved" }, "Member-Realm")
  equal(L.Change(other, "approved"), false)
end)

test("macro undo restores the selected tab and refuses to overwrite later manual edits", function()
  local sim = new("cata")
  local M = sim.ns.Macros
  sim.macros = { { name = "Kick", body = "/cast Kick", perCharacter = false },
    { name = "Kick", body = "/cast [@focus] Kick", perCharacter = true } }
  assert(M.Save("Kick", "/cast [@arena1] Kick", true))
  equal(sim.macros[1].body, "/cast Kick", "general untouched")
  local backup = M.Backups.All()[1]
  assert(M.Backups.Undo(backup))
  equal(sim.macros[2].body, "/cast [@focus] Kick")
  assert(M.Save("Kick", "/cast [@arena2] Kick", true))
  sim.macros[2].body = "/cast [@arena3] Kick"
  equal(M.Backups.Undo(M.Backups.All()[1]), false)
end)

test("selective macro imports skip conflicts and validate names before any writes", function()
  local sim = new("cata")
  local M = sim.ns.Macros
  sim.macros = { { name = "Kick", body = "/cast Kick", perCharacter = false } }
  M.Share.ShowImport()
  M.Share.window.box:SetText(M.Share.Encode({ { name = "Kick", body = "/cast [@focus] Kick" }, { name = "Blind", body = "/cast Blind" } }))
  M.Share.Review(false)
  equal(M.Share.decisions[1].action, "skip")
  M.Share.decisions[1] = { action = "rename", name = "Focus Kick" }
  local plan = assert(M.Share.Plan(M.Share.window.list, false, M.Share.decisions))
  assert(M.Share.Import(false, plan)); equal(#sim.macros, 3)
  equal(sim.macros[1].body, "/cast Kick")
  M.Share.decisions[1].name = "Kick"
  equal(M.Share.Plan(M.Share.window.list, false, M.Share.decisions), nil)
end)

test("localized flag, orb and node announcements use recorded game formats", function()
  local sim = new("cata", nil, function(_, env) env.GetLocale = function() return "frFR" end end)
  sim:enemy("Porteur"); sim:join(1460, 489, "Goulet des Chanteguerres")
  sim:event("CHAT_MSG_BG_SYSTEM_HORDE", "Le drapeau de l'Alliance a été ramassé par Porteur !")
  assert(sim:entry("Porteur").carrier)
  equal(sim.ns.Flags.carriers.H.name, "Porteur")
  sim:event("CHAT_MSG_BG_SYSTEM_HORDE", "Porteur a pris le drapeau de l'Alliance !")
  equal(sim:entry("Porteur").carrier, false)
  sim.ns.Timers.nodes.Ferme = { name = "Ferme" }
  assert(sim.ns.LocalizedChat("Porteur a attaqué la ferme !"):find("has assaulted the Ferme!", 1, true))
  local korean = new("cata", nil, function(_, env) env.GetLocale = function() return "koKR" end end)
  equal(korean.ns.LocalizedChat("적이 호드 깃발을 손에 넣었습니다!"), "The Horde Flag was picked up by 적!")
end)

test("localized macro presets resolve spell IDs and preserve secure conditions", function()
  local sim = new("cata", nil, function(_, env) env.GetLocale = function() return "frFR" end end)
  local M = sim.ns.Macros
  local names = { [1766] = "Coup de pied", [1784] = "Camouflage", [82676] = "Anneau de givre" }
  M.Host.SpellName = function(id) return names[id] end
  local body = assert(M.Build({ spell = "Kick", target = "focus", kind = "harm", stopcast = true }))
  assert(body:find("[@focus,harm,nodead] Coup de pied", 1, true))
  equal(M.LocalBody("/run print('Kick')\n/cast !Stealth", "cata"), "/run print('Kick')\n/cast !Camouflage")
  equal(M.Needs({ spell = "Kick" }, "cata")[1], "Coup de pied")
  equal(M.LocalSpell("Ring of Frost", "cata"), "Anneau de givre", "Cata uses its original spell identifier")
end)

test("cart and epic status uses observed widgets and messages without fabricated countdowns", function()
  local sim = new("retail")
  local W = sim.env.C_UIWidgetManager
  W.GetTopCenterWidgetSetID = function() return 1 end
  W.GetAllWidgetsBySetID = function() return { { widgetID = 22 } } end
  W.GetTextWithStateWidgetVisualizationInfo = function() return { shownState = 1, text = "Lava cart: Alliance" } end
  sim:join(423, 727, "Silvershard Mines"); sim:advance(1.1)
  local M = sim.ns.Timers.Mechanics
  equal(M.rows[1].text, "Lava cart: Alliance"); equal(M.rows[1].left, nil)
  sim:event("CHAT_MSG_BG_SYSTEM_ALLIANCE", "The Alliance delivered a cart!")
  local rows = sim.ns.Timers.ObjectiveRows(sim.now)
  local event
  for _, r in ipairs(rows) do if r.tag == "EVENT" then event = r end end
  assert(event and event.text:find("delivered", 1, true))
  sim:leave(); sim:advance(1.1); equal(#M.rows, 0)
end)

test("match history shows a result card, scoreboard tiles and readable objectives", function()
  local sim = new("retail", nil, function(s)
    s.env.GetBuildInfo = function() return "1.60.1", "1", "", 16001 end -- WoW Forever hides ruleset suffixes
    dofile("../../tools/wowsim/geometry.lua")(s)
  end)
  local H, Core = sim.ns.MatchHistory, sim.ns.Core
  local spec = next(Core.specInfo)
  local events = {}
  for i = 1, 14 do
    events[i] = { at = i * 61, text = "The Alliance Flag was picked up by Someone With A Long Surname, event " .. i .. "!" }
  end
  local list = H.All()
  list[1] = { id = "full", name = "Warsong Gulch", result = "Win", character = "Me Myself-RP-PvP", game = "forever",
    started = sim.env.time() - 600, duration = 932, spec = spec, events = events,
    stats = { killingBlows = 2, honorableKills = 28, deaths = 3, honorGained = 269, damageDone = 5956, healingDone = 0, ratingChange = 0 } }
  list[2] = { id = "empty", name = "Arathi Basin", result = "Left early", character = "Me Myself-RP-PvP", game = "forever",
    started = sim.env.time() - 1200, duration = 250, stats = {}, events = {} }
  local w = H.Open()
  local p, row = w.profile, w.rows[1]
  equal(row.label:GetText(), "Warsong Gulch")
  equal(row.summary:GetText(), "Win · 15:32", "the row names the result and duration")
  assert(row.icon:IsShown(), "the row shows the spec icon")
  equal(p.state:GetText(), "WIN")
  equal(p.name:GetText(), "Warsong Gulch")
  equal(p.player:GetText(), Core.specInfo[spec].name .. " · Me Myself", "spec and player without the ruleset suffix")
  assert(not p.when:GetText():find("forever", 1, true), "the raw game id is not shown")
  assert(p.emblem:IsShown() and p.icon.texture == Core.specInfo[spec].icon, "the card shows the spec icon")
  assert(not w.detail:IsShown(), "structured sections replace the plain-text block")
  local values = {}
  for _, cell in ipairs(p.metrics) do if cell:IsShown() then values[#values + 1] = cell.value:GetText() end end
  equal(#values, 6, "a rating change of zero is left out")
  equal(values[1], "2"); equal(values[2], "28"); equal(values[3], "3"); equal(values[6], "0")
  equal(p.eventsNote:GetText(), "Latest 11 of 14. Full timeline lists them all.")
  equal(p.events[1].text:GetText(), events[4].text, "the latest events are listed")
  equal(p.events[11].text:GetText(), events[14].text)
  local function contains(parent, child)
    local a, b = sim.bounds(parent), sim.bounds(child)
    assert(b[1] >= a[1] - 0.01 and b[1] + b[3] <= a[1] + a[3] + 0.01, "text stays within its section width")
    assert(b[2] >= a[2] - 0.01 and b[2] + b[4] <= a[2] + a[4] + 0.01, "section includes every line of text")
  end
  local function fits()
    for _, field in ipairs({ p.state, p.name, p.player, p.when }) do contains(p.hero, field) end
    for _, cell in ipairs(p.metrics) do
      if cell:IsShown() then contains(cell, cell.value); contains(cell, cell.label); contains(p.stats, cell) end
    end
    for _, line in ipairs(p.events) do
      if line.text:IsShown() then
        contains(w.detailBody, line.text)
        assert(line.text:GetHeight() >= line.text:GetStringHeight(), "event text has enough height")
        local at, text = sim.bounds(line.at), sim.bounds(line.text)
        assert(at[1] + at[3] <= text[1], "times keep their own column")
      end
    end
    local scroll, action = sim.bounds(w.detailScroll), sim.bounds(w.actions[1])
    assert(scroll[2] + scroll[4] <= action[2], "fixed actions stay outside scrolling details")
  end
  for _, theme in ipairs(sim.ns.Theme.Names()) do
    sim.ns.Theme.Use(theme)
    for _, scale in ipairs({ 1, 1.5 }) do
      Core.SetFontScale(scale)
      w:SetWidth(620); w:Refresh(); fits()
      w:SetWidth(800); w:Refresh(); fits()
    end
  end
  w:Select("empty")
  equal(p.state:GetText(), "LEFT EARLY")
  assert(not p.stats:IsShown(), "no tiles without reported stats")
  equal(p.eventsNote:GetText(), "No objective events were observed.")
  assert(not p.events[1].text:IsShown())
  w.search:SetText("Me Myself"); equal(#w.items, 2, "search uses the display name")
end)
