local test, newClient, equal = ...
-- Exercise the existing full-feature setup; fresh installs are covered by onboarding.
local function new(client, saved, configure) return newClient(client, saved or {}, configure) end

local function plate(sim, i, name, classID, fields)
  fields = fields or {}
  fields.name, fields.classID, fields.enemy, fields.level = name, classID, true, fields.level or 60
  sim.units["nameplate" .. i] = fields
  sim:event("NAME_PLATE_UNIT_ADDED", "nameplate" .. i)
  return fields
end

local function shownRows(sim)
  local out = {}
  for i = 1, 20 do
    local r = sim.env["HighgroundNearbyRow" .. i]
    if r and r:IsShown() then out[#out + 1] = r end
  end
  return out
end

for _, client in ipairs({ "cata", "retail" }) do
test(client .. " nearby enemies list open-world sightings, fade and are forgotten", function()
  local sim = new(client)
  sim:advance(1)
  local sounds = #sim.sounds
  plate(sim, 1, "Ganker", 4)
  sim:advance(1)
  local frame = sim.env.HighgroundNearbyFrame
  assert(frame and frame:IsVisible(), "list shows in the open world")
  local row = shownRows(sim)[1]
  equal(row.name.text, "Ganker", "enemy listed")
  equal(row.right.text, "Now", "seen now")
  equal(row.attrs.macrotext1, "/targetexact Ganker-Realm", "row targets the enemy, realm included")
  equal(#sim.sounds, sounds + 1, "new enemy alert")
  sim:advance(5)
  equal(#sim.sounds, sounds + 1, "no repeat while still in sight")

  sim.units.nameplate1 = nil -- out of sight
  sim:advance(70)
  equal(row.alpha < 1, true, "faded once unseen for a minute")
  equal(row.right.text, "1m", "time since last seen")
  sim:advance(240)
  equal(#shownRows(sim), 0, "forgotten after five minutes")
  assert(not frame:IsVisible(), "empty list hides")
end)
end

test("nearby list is capped, freezes its bindings in combat and can be switched off", function()
  local sim = new("cata")
  sim.env.HighgroundDB.nearbyRows = 2
  plate(sim, 1, "One", 1)
  sim:advance(1)
  plate(sim, 2, "Two", 2)
  sim:advance(1)
  plate(sim, 3, "Three", 3)
  sim:advance(1)
  equal(#shownRows(sim), 2, "two rows at most")
  equal(shownRows(sim)[1].name.text, "Three", "most recent first")
  equal(sim.env.HighgroundNearbyFrame.info.text, "+1", "overflow counted")

  sim.env.HighgroundDB.nearbyRows = 5
  sim:setCombat(true)
  plate(sim, 4, "Four", 5)
  sim:advance(1)
  equal(#shownRows(sim), 2, "rows don't change in combat")
  assert(sim.env.HighgroundNearbyFrame.info.text:find("after combat", 1, true), "new enemies counted in combat")
  sim:setCombat(false)
  sim:advance(1)
  equal(#shownRows(sim), 4, "list catches up after combat")
  equal(shownRows(sim)[1].attrs.macrotext1, "/targetexact Four-Realm", "bindings follow the new order")

  sim.env.HighgroundDB.nearby = false
  sim:advance(1)
  assert(not sim.env.HighgroundNearbyFrame:IsVisible(), "feature switch hides the list")
end)

test("nearby list stays out of battlegrounds and picks up Cata combat-log sightings", function()
  local sim = new("cata")
  sim.combatEvent = { sim.now, "SPELL_DAMAGE", false, "Player-1", "Sniper", 0x548, 0, "Player-2", "Me", 0x511, 0, 1 }
  sim:event("COMBAT_LOG_EVENT_UNFILTERED")
  sim:advance(1)
  equal(shownRows(sim)[1].name.text, "Sniper", "hostile player from the combat log")
  sim:join()
  assert(not sim.env.HighgroundNearbyFrame:IsVisible(), "hidden in battlegrounds")
end)

test("/hg nearby test previews the list", function()
  local sim = new("retail")
  sim:command("nearby test")
  sim:advance(1)
  assert(sim.env.HighgroundNearbyFrame:IsVisible(), "preview shown")
  equal(sim.env.HighgroundNearbyFrame.info.text, "PREVIEW", "labeled")
  local page
  for _, p in ipairs(sim.ns.Options.pages) do if p.name == "Nearby enemies" then page = p end end
  assert(page, "Nearby enemies settings page")
  sim:command("nearby test")
  sim:advance(1)
  assert(not sim.env.HighgroundNearbyFrame:IsVisible(), "preview off")
end)

test("nearby rows keep their secure macros and tooltip", function()
  local sim = new("cata")
  sim:advance(1)
  plate(sim, 1, "Ganker", 4)
  sim:advance(1)
  local row = shownRows(sim)[1]
  equal(row.attrs.type1, "macro", "left-click runs a macro")
  equal(row.attrs.type2, "macro", "right-click runs a macro")
  equal(row.attrs.macrotext1, "/targetexact Ganker-Realm", "left-click targets")
  equal(row.attrs["wb-macrotext2"], "/targetexact Ganker-Realm\n/focus", "right-click focuses")
  equal(row.attrs.macrotext2, "/targetexact Ganker-Realm\n/focus\n/targetlasttarget", "then returns")
  for _, h in ipairs(row.hooks.OnEnter or {}) do h(row) end
  equal(table.concat(sim.env.GameTooltip.lines, "|"), "Ganker-Realm|Recently seen here; the player may have moved away.|Left-click: target   Right-click: focus|Focus keeps a second target for abilities and tracking.", "tooltip")
  sim.units.nameplate1 = nil
  sim:advance(400)
  equal(row.attrs.macrotext1, nil, "forgotten row: no target macro")
  equal(row.attrs["wb-macrotext2"], "", "forgotten row: no focus body")
  equal(row.attrs.macrotext2, "", "forgotten row: no focus macro")
end)

local function said(sim, from, text)
  for i = from + 1, #sim.messages do
    if sim.messages[i]:find(text, 1, true) then return true end
  end
end

test("cata: nearby stealth and invisibility from the combat log, cast and fade", function()
  local sim = new("cata")
  sim:advance(1)
  local function log(kind, src, dst, spellId)
    sim.combatEvent = { sim.now, kind, false, "Player-1", src, src ~= "" and 0x548 or 0, 0,
      "Player-1", dst, dst ~= "" and 0x548 or 0, 0, spellId }
    sim:event("COMBAT_LOG_EVENT_UNFILTERED")
  end
  local from, sounds = #sim.messages, #sim.sounds
  log("SPELL_CAST_SUCCESS", "Sneaky", "", 1856)
  log("SPELL_AURA_APPLIED", "Sneaky", "Sneaky", 11327)
  log("SPELL_AURA_APPLIED", "Sneaky", "Sneaky", 1784)
  assert(said(sim, from, "Sneaky used Vanish nearby"), "vanish called")
  equal(#sim.messages - from, 1, "one line for vanish and its stealth")
  sim:advance(0.2) -- simultaneous cues are arbitrated before sound playback
  assert(#sim.sounds > sounds, "alert sound")
  sim:advance(1)
  assert(shownRows(sim)[1].sub.text:find("Stealth", 1, true), "row shows the stealth")
  from = #sim.messages
  sim:advance(2)
  log("SPELL_AURA_REMOVED", "Sneaky", "Sneaky", 11327)
  equal(#sim.messages, from, "vanish's own aura ending is not a fade")
  log("SPELL_AURA_REMOVED", "Sneaky", "Sneaky", 1784)
  assert(said(sim, from, "Sneaky: Stealth faded"), "fade called")

  from = #sim.messages
  sim:advance(20)
  log("SPELL_CAST_SUCCESS", "Blinky", "", 66)
  sim:advance(3)
  log("SPELL_AURA_REMOVED", "Blinky", "Blinky", 66)
  log("SPELL_AURA_APPLIED", "Blinky", "Blinky", 32612)
  equal(#sim.messages - from, 1, "one line for invisibility's two steps")
  assert(said(sim, from, "Blinky used Invisibility nearby"), "invisibility called")
  log("SPELL_AURA_REMOVED", "Blinky", "Blinky", 32612)
  assert(said(sim, from, "Blinky: Invisibility faded"), "invisibility fade called")

  sim.env.HighgroundDB.nearbyStealth = false
  from = #sim.messages
  sim:advance(20)
  log("SPELL_CAST_SUCCESS", "Sneaky", "", 1784)
  equal(#sim.messages, from, "switched off: silent")
end)

for _, build in ipairs({ 120100, 16001 }) do
test(build .. ": nearby prowl seen on a plate, faded when the enemy shows again", function()
  local sim = new("retail", nil, function(s)
    s.env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", build end
  end)
  equal(sim.ns.GAME, build == 16001 and "forever" or "retail", "game")
  sim:advance(1)
  plate(sim, 1, "Kitty", 11)
  sim:advance(1)
  local from = #sim.messages
  sim:event("UNIT_SPELLCAST_SUCCEEDED", "nameplate1", "Cast-1", 5215)
  assert(said(sim, from, "Kitty (DRUID) used Prowl nearby"), "prowl called")
  sim:event("UNIT_SPELLCAST_SUCCEEDED", "nameplate1", "Cast-2", { secret = true })
  sim.units.nameplate1 = nil
  sim:advance(10)
  equal(#sim.messages - from, 1, "secret spells and hidden time: nothing more")
  plate(sim, 1, "Kitty", 11)
  assert(said(sim, from, "Kitty (DRUID): Prowl faded"), "fade called when seen again")
end)
end

test("cata: nearby history is saved, counts encounters and kills both ways", function()
  local saved = {}
  local sim = new("cata", saved)
  sim.units.player.guid = "Player-me"
  sim:advance(1)
  local function log(kind, srcGUID, src, srcFlags, dstGUID, dst, dstFlags)
    sim.combatEvent = { sim.now, kind, false, srcGUID, src, srcFlags, 0, dstGUID, dst, dstFlags, 0, 1 }
    sim:event("COMBAT_LOG_EVENT_UNFILTERED")
  end
  plate(sim, 1, "Ganker", 4)
  sim:advance(1)
  log("SPELL_DAMAGE", "Player-2", "Ganker-Realm", 0x548, "Player-me", "Me", 0x511)
  sim:event("PLAYER_DEAD")
  log("PARTY_KILL", "Player-me", "Me", 0x511, "Player-2", "Ganker-Realm", 0x548)
  local h = saved.enemyHistory and saved.enemyHistory["Ganker-Realm"]
  assert(h, "saved in HighgroundDB.enemyHistory")
  equal(h.times, 1, "one encounter")
  equal(h.killedMe, 1, "killed you")
  equal(h.killedThem, 1, "you killed")
  equal(h.class, "ROGUE", "class kept")

  log("SPELL_DAMAGE", "Player-2", "Ganker-Realm", 0x548, "Player-me", "Me", 0x511)
  sim:advance(30)
  sim:event("PLAYER_DEAD")
  equal(h.killedMe, 1, "an old hit is not a kill")

  sim.units.nameplate1 = nil
  sim:advance(400) -- forgotten by the list
  local from = #sim.messages
  plate(sim, 1, "Ganker", 4)
  assert(said(sim, from, "seen 1 time before"), "met before: said in chat")
  assert(said(sim, from, "killed you 1, you killed 1"), "kills in the chat line")
  equal(h.times, 2, "second encounter")
  sim:advance(1)
  assert(not shownRows(sim)[1].sub.text:find("K1 D1", 1, true), "row stays focused on the sighting")
  for _, hook in ipairs(shownRows(sim)[1].hooks.OnEnter or {}) do hook(shownRows(sim)[1]) end
  assert(table.concat(sim.env.GameTooltip.lines, " "):find("Killed you 1, you killed 1", 1, true), "history remains in the tooltip")

  sim:command("nearby forget")
  equal(next(saved.enemyHistory), nil, "/hg nearby forget")
  sim.env.HighgroundDB.nearbyHistory = false
  sim.units.nameplate1 = nil
  sim:advance(400)
  plate(sim, 1, "Ganker", 4)
  equal(next(saved.enemyHistory), nil, "switched off: nothing saved")
end)

test("retail: nearby history counts honorable kills from chat and deaths from the recap", function()
  local saved = {}
  local sim = new("retail", saved)
  sim:advance(1)
  sim.units.target = { name = "Victim", classID = 8, enemy = true, level = 80 }
  sim.units.target.realm = ""
  sim:event("PLAYER_TARGET_CHANGED")
  sim:event("CHAT_MSG_COMBAT_HONOR_GAIN", "Victim dies, honorable kill Rank: Scout (Estimated Honor Points: 10)")
  equal(saved.enemyHistory.Victim.killedThem, 1, "honorable kill counted")

  local recap = {
    { timestamp = 10, sourceName = "Victim", sourceFlags = 0x548 },
    { timestamp = 12, sourceName = "Boar", sourceFlags = 0xa48 },
    { timestamp = 11, sourceName = "Victim", sourceFlags = 0x548 },
  }
  sim.env.C_DeathRecap = { GetRecapEvents = function() return recap end }
  sim:event("PLAYER_DEAD")
  sim:advance(2)
  equal(saved.enemyHistory.Victim.killedMe, 1, "recap names the enemy player")
  recap = { { timestamp = 20, sourceName = { secret = true }, sourceFlags = 0x548 } }
  sim:event("PLAYER_DEAD")
  sim:advance(2)
  equal(saved.enemyHistory.Victim.killedMe, 1, "secret recap: not counted")
end)
