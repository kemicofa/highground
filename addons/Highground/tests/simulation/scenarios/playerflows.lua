local test, new, check = ...
local function equal(a, b, why) return check(a, b, why or "values match") end
test("setup previews follow the selected activity and give way to a real match", function()
  local sim = new("cata")
  sim:command("setup")
  local S, C, T = sim.ns.Setup, sim.ns.Core, sim.ns.Timers
  S.win.role:SetValue("damage"); S.win.primary.scripts.OnClick()
  sim:advance(2)
  assert(C.testMode and T.previewing and not sim.ns.Arena.preview, "only battleground previews are active")
  equal(C.db.locked, false)
  S.layoutBar.context:SetValue("arena")
  assert(sim.ns.Arena.preview and not C.testMode and not T.previewing)
  S.layoutBar.finish.scripts.OnClick(); sim:advance(0.5)
  assert(C.db.locked and C.db.setupDone)
  assert(not C.testMode and not T.previewing and not sim.ns.Arena.preview)
  S.win.primary.scripts.OnClick(); sim:command("setup")
  S.win.secondary.scripts.OnClick(); sim:joinArena()
  assert(not C.testMode and not T.previewing and not sim.ns.Arena.preview, "no sample enemies in a real arena")
  equal(sim.env.HighgroundArenaFrame.info.text, "2v2")
end)

test("Cata arena DR waits for all overlapping controls to end and expires conservatively", function()
  local sim = new("cata")
  sim:joinArena()
  sim.units.arena1 = { name = "Enemy", classID = 4, enemy = true, guid = "Player-destination" }
  local A = sim.ns.Arena
  sim:combatLog("SPELL_AURA_APPLIED", "Me", "Enemy", 853)
  sim:combatLog("SPELL_AURA_APPLIED", "Me", "Enemy", 408)
  sim:advance(0.3)
  assert(A.rows[1].dr.text:find("stun 25%", 1, true))
  sim:combatLog("SPELL_AURA_REMOVED", "Me", "Enemy", 853)
  equal(A.control["Player-destination"].stun.ends, nil, "second stun still active")
  sim:combatLog("SPELL_AURA_REMOVED", "Me", "Enemy", 408)
  local ending = A.control["Player-destination"].stun.ends
  equal(ending, sim.now + 20)
  sim:advance(1); sim:combatLog("SPELL_AURA_REMOVED", "Me", "Enemy", 408)
  equal(A.control["Player-destination"].stun.ends, ending, "duplicate removal cannot postpone the reset")
  sim:combatLog("SPELL_AURA_APPLIED", "Me", "Enemy", 853)
  assert(A.ActivityText("arena1"):find("stun immune", 1, true))
  sim:combatLog("SPELL_AURA_REMOVED", "Me", "Enemy", 853)
  sim:advance(20.1); equal(A.ActivityText("arena1"), "")
  sim:combatLog("SPELL_AURA_APPLIED", "Me", "Enemy", 44572)
  assert(A.control["Player-destination"].stun and A.control["Player-destination"]["freeze/ring"])
  sim:combatLog("UNIT_DIED", "Me", "Enemy")
  equal(A.control["Player-destination"], nil)
end)

test("Cata arena interrupt cooldowns are observed estimates and reset between matches", function()
  local sim = new("cata")
  sim:joinArena()
  sim.units.arena1 = { name = "Enemy", classID = 4, enemy = true, guid = "Player-source" }
  sim:combatLog("SPELL_CAST_SUCCESS", "Enemy", "Me", 1766)
  sim:advance(0.3)
  assert(sim.ns.Arena.rows[1].dr.text:find("~10s", 1, true))
  sim:advance(10); equal(sim.ns.Arena.ActivityText("arena1"), "")
  sim:combatLog("SPELL_CAST_SUCCESS", "Enemy", "Me", 2139)
  sim:leave(); equal(next(sim.ns.Arena.kicks), nil)
end)

test("Retail casts and crowd control send restricted data only to display widgets", function()
  local hidden, duration = { secret = true }, {}
  local sim = new("retail")
  sim:joinArena()
  sim.units.arena1 = { name = "Caster", enemy = true, classID = 8 }
  local r = sim.ns.Arena.rows[1]
  local castText, ccText
  r.castText.SetText = function(_, text) castText = text end
  r.ccText.SetText = function(_, text) ccText = text end
  sim.env.UnitCastingInfo = function(unit) if unit == "arena1" then return hidden, nil, nil, hidden, hidden end end
  sim.env.UnitCastingDuration = function(unit) if unit == "arena1" then return duration end end
  sim.env.C_UnitAuras.GetAuraDataByIndex = function(unit, _, filter)
    if unit == "arena1" and filter == "HARMFUL|CROWD_CONTROL" then
      return { name = hidden, icon = hidden, auraInstanceID = hidden, duration = hidden, expirationTime = hidden }
    end
  end
  sim.env.C_UnitAuras.GetAuraDuration = function(_, id) equal(id, hidden); return duration end
  sim:setCombat(true); sim:advance(0.5)
  equal(castText, hidden); equal(r.cast.timerDuration, duration); assert(r.cast:IsShown())
  equal(ccText, hidden); equal(r.cc.texture, hidden); equal(r.ccCD.cooldown.object, duration)
  equal(next(sim.ns.Arena.control), nil, "Retail does not infer DR from restricted auras")
  sim.env.UnitCastingInfo = function() end
  sim.env.C_UnitAuras.GetAuraDataByIndex = function() end
  sim:advance(0.3); assert(not r.cast:IsShown() and not r.cc:IsShown())
end)

test("macro history can undo creation and import review keeps its reviewed contents", function()
  local sim = new("cata")
  local M = sim.ns.Macros
  assert(M.Save("Kick", "/cast Kick", true))
  assert(M.Backups.Undo(M.Backups.All()[1])); equal(#sim.macros, 0)
  M.Share.ShowImport()
  M.Share.window.box:SetText(M.Share.Encode({ { name = "Kick", body = "/cast Kick" } }))
  M.Share.Review(false)
  M.Share.window.box:SetText("a broken replacement string")
  equal(M.Share.window.list, nil)
  equal(M.Share.review:GetFrameStrata(), "FULLSCREEN_DIALOG", "review is above the paste dialog")
  local import = M.Share.review.actions[4]; import.scripts.OnClick(import)
  equal(#sim.macros, 1); equal(sim.macros[1].name, "Kick", "imports the reviewed snapshot")
  local plan = M.Share.Plan({ { name = " Kick ", body = "/cast Kick" }, { name = "Kick", body = "/cast Blind" } }, false)
  equal(plan, nil, "whitespace cannot conceal a duplicate name")
end)

test("full profile decoder rejects corrupt, duplicate and oversized data", function()
  local sim = new("cata")
  local codec = sim.ns.Codec
  local value = { off = false, text = "line\nwith:delimiters", nested = { [45438] = true } }
  local decoded = assert(codec.Unpack(codec.Pack(value)))
  equal(decoded.off, false); equal(decoded.text, value.text); assert(decoded.nested[45438])
  for _, input in ipairs({ "t1:s3:foo", "t2:s1:ab0s1:ab1", "t999999:", "n3:inf", "b2", "b1trailing", string.rep("x", 131073) }) do
    equal(codec.Unpack(input), nil, "malformed input rejected")
  end
  local cycle = {}; cycle.cycle = cycle
  equal(pcall(codec.Pack, cycle), false, "cyclic local data cannot hang serialization")
end)

test("claim review permissions follow the originating guild across character changes", function()
  local sim = new("cata")
  sim.guild, sim.rank = "Original Guild", 0
  local B = sim.ns.Bounty
  local claim = B.Ledger.Record({ name = "Enemy-Realm", by = "Poster-Realm", at = 1, gold = 20, state = "approved" }, "Member-Realm")
  assert(B.Ledger.CanManage(claim))
  sim.guild = "Another Guild"
  equal(B.Ledger.CanManage(claim), false, "new guild officer cannot settle an old guild's claim")
end)

test("localized node messages resolve declined names through client area identifiers", function()
  local sim = new("cata")
  sim:join()
  sim.ns.Timers.nodes = { ["Écurie"] = { name = "Écurie" } }
  sim.env.GetLocale = function() return "frFR" end
  sim.env.C_Map.GetAreaInfo = function(id) if id == 3424 then return "Écurie" end end
  equal(sim.ns.LocalizedChat("Porteur a attaqué les écuries !"), "Porteur has assaulted the Écurie!")
  sim.ns.Timers.nodes = { ["Ферма"] = { name = "Ферма" } }
  sim.env.GetLocale = function() return "ruRU" end
  sim.env.C_Map.GetAreaInfo = function(id) if id == 3420 then return "Ферма" end end
  equal(sim.ns.LocalizedChat("Враг штурмует ферму!"), "Враг has assaulted the Ферма!")
  sim:event("CHAT_MSG_BG_SYSTEM_HORDE", "Орда захватила ферму!")
  equal(sim.ns.Timers.chatTaken["Ферма"], sim.now, "localized objective reaches the timer parser")
end)

test("a newer tuning-only profile cancels a queued full profile", function()
  local sim = new("cata")
  local P, C = sim.ns.Options.Profiles, sim.ns.Core
  C.db.sniper = false; P.SaveProfile("Queued")
  C.db.sniper = true
  sim:setCombat(true); assert(P.LoadProfile("Queued")); assert(P.pending)
  assert(P.ImportText("WB1;o.executePct=0.15"))
  sim:setCombat(false)
  equal(C.db.sniper, true, "the older queued setup cannot overwrite a newer choice")
  equal(C.db.executePct, 0.15)
end)

test("base overview distinguishes fresh sightings and warns once for an urgent friendly base", function()
  local sim = new("cata")
  sim:join()
  local T, Intel = sim.ns.Timers, sim.ns.Intel
  T.nodes = {
    Farm = { name = "Farm", hasGraveyard = true, owner = "A", assault = "H", capEnd = sim.now + 8 },
    Stables = { name = "Stables", hasGraveyard = true, owner = "A" },
  }
  Intel.intel = {
    fresh = { area = "Farm", t = sim.now - 5, how = "seen" },
    stale = { area = "Farm", t = sim.now - 31, how = "seen" },
    dead = { area = "Farm", t = sim.now, how = "seen", dead = true },
  }
  local rows, before = {}, #sim.messages
  T.AddOverview(rows, sim.now)
  equal(rows[2].tag, "CONTEST", "urgent base comes first after the plan")
  assert(rows[2].text:find("1 seen 5s ago", 1, true))
  equal(#sim.messages, before + 1)
  T.AddOverview({}, sim.now + 0.5); equal(#sim.messages, before + 1, "warning does not repeat each update")
end)
