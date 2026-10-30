local test, newClient, check = ...
-- Exercise the existing full-feature setup; fresh installs are covered by onboarding.
local function new(client, saved, configure) return newClient(client, saved or {}, configure) end
local function equal(a, b, why) return check(a, b, why or "values match") end

test("player tools open directly and inside the hub without releasing their parent", function()
  local sim = new("cata")
  for _, key in ipairs({ "setup", "alerts", "calls", "history", "journal" }) do
    sim:command(key)
    sim:command("config " .. key)
    local hub = sim.ns.Hub
    equal(hub.current, key)
    assert(hub.win:IsShown())
    hub.Show(key)
    assert(hub.win:IsShown(), "reopening a borrowed section keeps the hub")
    sim:assertHealthy()
  end
  sim:command("bounty claims"); sim:command("macros history")
  assert(sim.ns.Bounty.Ledger.win:IsShown())
  assert(sim.ns.Macros.Backups.win:IsShown())
end)

test("full profiles restore appearance, toggles, tracking and positions after combat", function()
  local sim = new("cata")
  local P, C = sim.ns.Options.Profiles, sim.ns.Core
  C.db.sniper, C.db.theme = false, "parchment"
  C.db.style = { fontScale = 1.1, hide = { mana = true } }
  C.db.disabledCooldowns = { [45438] = true }
  C.pos.arenaPoint = { "LEFT", "LEFT", 20, 40 }
  sim.ns.Alerts.SetMode("quiet")
  P.SaveProfile("Healer alt")
  local exported = P.ExportString(P.Snapshot())
  C.db.sniper, C.db.theme, C.db.style = true, "ember", {}
  C.db.disabledCooldowns, C.pos.arenaPoint = {}, nil
  sim:setCombat(true)
  assert(P.ImportText(exported))
  equal(C.db.sniper, true, "secure layout waits for combat")
  sim:setCombat(false)
  equal(C.db.sniper, false); equal(C.db.theme, "parchment")
  equal(C.db.style.fontScale, 1.1); equal(C.pos.arenaPoint[3], 20)
  assert(C.db.disabledCooldowns[45438]); equal(C.db.alerts.mode, "quiet")
  local bad = P.Snapshot(); bad.setup.positions.arenaPoint[3] = math.huge
  local before = C.db.style
  equal(P.Prepare(bad), nil); equal(C.db.style, before, "invalid setup is atomic")
end)

test("role presets keep a backup and activity assignments switch full profiles", function()
  local sim = new("cata")
  local C, P = sim.ns.Core, sim.ns.Options.Profiles
  C.db.highestRank = false
  assert(sim.ns.Setup.Apply("carrier"))
  equal(C.db.dieAlert, false); equal(C.db.highestRank, false)
  assert(C.db.profiles["Before role preset"])
  C.db.sniper = false; P.SaveProfile("Arena setup")
  assert(P.Assign("Arena setup", "arena")); C.pos.autoProfiles = true
  C.db.sniper = true
  sim:joinArena()
  equal(C.db.sniper, false, "arena assignment loaded")
  equal(C.db.activeProfile, "Arena setup")
end)

test("callouts prepare location and count without sending or replacing a draft", function()
  local sim = new("cata")
  sim:join()
  sim.env.GetSubZoneText = function() return "Farm" end
  sim:command("calls incoming 3")
  sim:advance(0.1)
  equal(#sim.chat, 0)
  assert(sim.chatDraft:find("Incoming 3", 1, true))
  assert(sim.chatDraft:find("Farm", 1, true))
  local draft = sim.chatDraft
  equal(sim.ns.ObjectiveCalls.Draft("clear"), false)
  equal(sim.chatDraft, draft)
  equal(sim.ns.ObjectiveCalls.Draft("incoming", "bad"), false)
end)

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
  sim.env.GetLocale = function() return "koKR" end
  equal(sim.ns.LocalizedChat("적이 호드 깃발을 손에 넣었습니다!"), "The Horde Flag was picked up by 적!")
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
