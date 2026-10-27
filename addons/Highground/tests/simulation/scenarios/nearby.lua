local test, new, equal = ...

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
  equal(row.right.text, "now", "seen now")
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
  assert(sim.env.HighgroundNearbyFrame.info.text:find("new"), "new enemies counted in combat")
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
  equal(table.concat(sim.env.GameTooltip.lines, "|"), "Ganker-Realm|Left-click: target   Right-click: focus", "tooltip")
  sim.units.nameplate1 = nil
  sim:advance(400)
  equal(row.attrs.macrotext1, nil, "forgotten row: no target macro")
  equal(row.attrs["wb-macrotext2"], "", "forgotten row: no focus body")
  equal(row.attrs.macrotext2, "", "forgotten row: no focus macro")
end)
