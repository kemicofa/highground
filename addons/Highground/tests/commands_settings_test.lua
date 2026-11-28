-- Argument modes of the settings commands (commands/Settings.lua): saved
-- values, validation, chat feedback, reloads and combat deferral.
-- Run from addons/Highground: luajit tests/commands_settings_test.lua
local t = dofile("../../tools/harness.lua")("settings commands")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local C = dofile("tests/support/commands.lua")
local equal, run, has = t.equal, C.run, C.has
-- A /reload: settings are saved on logout; the character keeps its own.
local function reload(sim)
  sim:event("PLAYER_LOGOUT")
  return new(sim.client, sim.env.HighgroundDB, function(_, env) env.HighgroundCharDB = sim.env.HighgroundCharDB end)
end

t.test("/hg points lists overrides, matches keys in any case and validates values", function()
  local sim = new("cata", {})
  local db, default = sim.env.HighgroundDB, sim.ns.Core.POINT_DEFAULT.killPer
  local out = run(sim, "points")
  assert(has(out, "all points at default"), "nothing overridden")
  out = run(sim, "points KILLPER 9")
  equal(db.points.killPer, 9, "key matched without case")
  assert(has(out, "killPer = 9"), "saved value confirmed")
  out = run(sim, "points")
  assert(has(out, "killPer = 9 (default " .. default .. ")"), "override listed with its default")
  assert(has(out, "/hg points KEY reset"), "reset hint")
  out = run(sim, "points killPer -5")
  equal(db.points.killPer, 9, "out-of-range value rejected")
  assert(has(out, "killPer must be 0"), "range explained: " .. out)
  out = run(sim, "points killPer lots")
  equal(db.points.killPer, 9, "non-numeric value ignored")
  assert(has(out, "/hg points NAME VALUE|reset  "), "usage for a non-numeric value: " .. out)
  out = run(sim, "points killPer")
  equal(db.points.killPer, 9, "a name alone never resets")
  assert(has(out, "killPer = 9 (default " .. default .. ")"), "a name alone shows the value: " .. out)
  assert(has(out, "/hg points NAME VALUE|reset"), "and how to change it")
  out = run(sim, "points nonsense 3")
  assert(has(out, "Unknown scoring value. In /hg config, see Battlegrounds → Target priority, Objectives, Live signals"),
    "the Highground window pages: " .. out)
  equal(reload(sim).ns.Core.db.points.killPer, 9, "override survives reload")
  out = run(sim, "points killPer reset")
  equal(db.points.killPer, nil, "reset drops the override")
  assert(has(out, "killPer reset to " .. default), "reset confirmed")
end)

t.test("/hg weight sets, validates and resets multipliers", function()
  local sim = new("cata", {})
  local db = sim.env.HighgroundDB
  local out = run(sim, "weights")
  assert(has(out, "range     x1.0") and has(out, "/hg weight reset"), "every multiplier listed: " .. out)
  out = run(sim, "weight range 2.5")
  equal(db.weights.range, 2.5, "multiplier saved")
  assert(has(out, "range coefficient: x2.5"), "confirmed")
  out = run(sim, "weights")
  assert(has(out, "range     x2.5"), "list shows the new value")
  for _, bad in ipairs({ "weight range 9", "weight range lots", "weight nonsense 2" }) do
    out = run(sim, bad)
    equal(db.weights.range, 2.5, bad .. " keeps the multiplier")
  end
  assert(has(run(sim, "weight range 9"), "range must be 0"), "range explained")
  assert(has(run(sim, "weight nonsense 2"), "unknown weight or value"), "unknown multiplier")
  run(sim, "weight cooldowns 0.5")
  out = run(sim, "weight reset")
  equal(next(db.weights), nil, "all multipliers reset")
  assert(has(out, "reset to 1.0"), "reset confirmed")
  equal(next(reload(sim).ns.Core.db.weights), nil, "reset survives reload")
end)

t.test("/hg live and /hg all toggle and persist their switches", function()
  local sim = new("cata", {})
  local Core = sim.ns.Core
  local live = Core.O("liveSort")
  local out = run(sim, "live")
  equal(Core.O("liveSort"), not live, "live sorting toggled")
  assert(has(out, live and "off (stable order" or "on (defensives"), "state named")
  run(sim, "live")
  equal(Core.O("liveSort"), live, "toggled back")
  local all = Core.SizeEnabled("unrated")
  out = run(sim, "all")
  equal(Core.SizeEnabled("unrated"), not all, "unrated 10v10 toggled")
  assert(has(out, all and "Unrated 10v10 matches: off" or "Unrated 10v10 matches: on"), "switch named: " .. out)
  equal(sim.env.HighgroundCharDB.battlegroundSizes.unrated, not all, "saved for this character")
  equal(reload(sim).ns.Core.SizeEnabled("unrated"), not all, "switch survives reload")
end)

t.test("/hg rows, scale and opacity clamp values and print help for non-numbers", function()
  local sim = new("cata", {})
  local db, Core = sim.env.HighgroundDB, sim.ns.Core
  for _, case in ipairs({ { "rows 0", 1 }, { "rows 3.7", 3 }, { "rows 99", Core.MAX_ROWS } }) do
    local out = run(sim, case[1])
    equal(db.rows, case[2], case[1])
    assert(has(out, "Enemies shown: " .. case[2]), case[1] .. " confirmed")
  end
  run(sim, "scale 0.01")
  equal(db.scale, Core.THEME.scale.min, "scale clamps to the minimum")
  run(sim, "scale 9")
  equal(db.scale, Core.THEME.scale.max, "scale clamps to the maximum")
  local out = run(sim, "opacity 1000")
  assert(has(out, "background opacity: 100%"), "opacity clamps: " .. out)
  out = run(sim, "opacity 35")
  assert(has(out, "background opacity: 35%"), "opacity set")
  local rows, scale = db.rows, db.scale
  for _, command in ipairs({ "rows many", "scale big", "opacity half", "exec low" }) do
    local before = #sim.messages
    out = run(sim, command)
    equal(#sim.messages, before + 1, command .. " prints one line")
    local syntax = sim.ns.CommandCatalog.byId[command:match("^%S+")][1]
    assert(has(out, syntax .. "  "), command .. " prints its usage: " .. out)
  end
  equal(db.rows, rows, "rows kept")
  equal(db.scale, scale, "scale kept")
end)

t.test("/hg exec reports the saved threshold without rounding it down", function()
  local sim = new("cata", {})
  local db = sim.env.HighgroundDB
  for _, pct in ipairs({ 29, 57, 35 }) do
    local out = run(sim, "exec " .. pct)
    equal(db.executePct, pct / 100, "threshold saved")
    assert(has(out, "below " .. pct .. "%"), "exec " .. pct .. " reported as " .. out)
  end
  local out = run(sim, "exec 2")
  equal(db.executePct, 0.35, "out-of-range threshold rejected")
  assert(has(out, "executePct must be"), "range explained")
end)

t.test("Retail sets the execute threshold that colours its execute marks", function()
  local sim = new("retail", {})
  local out = run(sim, "exec 50")
  equal(sim.env.HighgroundDB.executePct, 0.5, "threshold saved on Retail")
  assert(has(out, "below 50%"), "confirmed")
  assert(sim.ns.OptionAvailable(sim.ns.CommandCatalog.byId.exec), "listed in Help and commands on Retail")
  sim.ns.Hub.Open("behavior")
  local page, row = sim.ns.Options.byKey.behavior
  for _, r in ipairs(page.rows or {}) do if r.key == "executePct" then row = r end end
  assert(row, "Target behavior offers the execute threshold on Retail")
end)

t.test("WoW Forever hides aura and orb scoring from its pages and commands", function()
  local function forever(_, env) env.GetBuildInfo = function() return "1.60.1", "71037", "Nov 20 2026", 16001 end end
  local function rows(sim, key)
    sim.ns.Hub.Open(key)
    local keys = {}
    for _, r in ipairs(sim.ns.Options.byKey[key].rows or {}) do keys[r.key] = true end
    return keys
  end
  local function choices(sim)
    local keys = {}
    for _, key in ipairs(sim.ns.CommandCatalog.byId["points-value"].fields[1].choices()) do keys[key] = true end
    return keys
  end
  local hidden = {
    live = { "spent", "burst", "defensiveUp" }, objectives = { "orbCarrier", "orbPerPct" },
    behavior = { "goWindow", "spentWindow" }, multipliers = { "spent", "burst", "defensive" },
  }
  local kept = { live = "rangeFar", objectives = "flagCarrier", behavior = "switchMargin", multipliers = "range" }

  local sim = new("retail", {}, forever)
  equal(sim.ns.GAME, "forever", "Forever client")
  for page, keys in pairs(hidden) do
    local shown = rows(sim, page)
    assert(shown[kept[page]], page .. " keeps " .. kept[page])
    for _, key in ipairs(keys) do assert(not shown[key], page .. " hides " .. key) end
  end
  local db = sim.env.HighgroundDB
  local out = run(sim, "points defensiveUp -5")
  equal((db.points or {}).defensiveUp, nil, "hidden point refused")
  assert(has(out, "Unknown scoring value"), "refused as unknown: " .. out)
  out = run(sim, "weight burst 2")
  equal((db.weights or {}).burst, nil, "hidden multiplier refused")
  assert(has(out, "unknown weight"), "refused as unknown: " .. out)
  out = run(sim, "weights")
  assert(has(out, "range") and not has(out, "defensive x"), "weights lists only usable multipliers: " .. out)
  local offered = choices(sim)
  assert(offered.killPer and not offered.spent and not offered.orbCarrier, "Edit a scoring value offers usable keys")

  sim = new("retail", {})
  for page, keys in pairs(hidden) do
    local shown = rows(sim, page)
    for _, key in ipairs(keys) do assert(shown[key], "Retail " .. page .. " keeps " .. key) end
  end
  run(sim, "points defensiveUp -5")
  equal(sim.env.HighgroundDB.points.defensiveUp, -5, "Retail still sets it")
  assert(has(run(sim, "weights"), "defensive x"), "Retail lists the defensive multiplier")
  offered = choices(sim)
  assert(offered.spent and offered.orbCarrier and not offered.gearPer, "Retail offers its own keys only")
end)

t.test("layout commands wait for the end of combat and then apply", function()
  local sim = new("cata", {})
  local Core = sim.ns.Core
  sim:enemy("Enemy")
  sim:join()
  local scale = Core.frame:GetScale()
  sim:setCombat(true)
  local out = run(sim, "scale 1.2")
  equal(sim.env.HighgroundDB.scale, 1.2, "scale saved in combat")
  equal(Core.frame:GetScale(), scale, "protected panel keeps its scale in combat")
  assert(has(out, "UI scale: 120% (applies after combat)"), "deferral explained")
  out = run(sim, "rows 1")
  assert(has(out, "Enemies shown: 1 (updates after combat)"), "rows deferred")
  out = run(sim, "compact")
  equal(sim.env.HighgroundDB.compact, true, "compact saved in combat")
  equal(Core.compact, false, "layout waits")
  assert(has(out, "compact layout: on (applies after combat)"), "compact deferred")
  sim:setCombat(false)
  sim:advance(0.5)
  assert(Core.frame:GetScale() ~= scale, "scale applied after combat")
  equal(Core.compact, true, "compact applied after combat")
  out = run(sim, "compact")
  equal(Core.compact, false, "plain toggle applies at once")
  assert(has(out, "compact layout: off") and not has(out, "after combat"), "no deferral note")
  out = run(sim, "compact off")
  equal(Core.compact, false, "explicit off stays off")
end)

t.test("/hg nearby switches the list, counts sightings and clears them", function()
  local sim = new("cata", {})
  sim:advance(1)
  sim.units.nameplate1 = { name = "Ganker", classID = 4, enemy = true, level = 60 }
  sim:event("NAME_PLATE_UNIT_ADDED", "nameplate1")
  sim:advance(1)
  local out = run(sim, "nearby")
  assert(has(out, "nearby enemies on (1 remembered)"), "status counts sightings: " .. out)
  out = run(sim, "nearby off")
  equal(sim.env.HighgroundDB.nearby, false, "list saved off")
  assert(has(out, "nearby enemies OFF"), "off reported")
  run(sim, "nearby on")
  out = run(sim, "nearby clear")
  equal(next(sim.ns.Nearby.seen), nil, "sightings cleared")
  assert(has(out, "nearby enemies cleared"), "clear confirmed")
  assert(next(sim.ns.NearbyHistory.All()), "history kept by clear")
  out = run(sim, "nearby forget")
  equal(next(sim.ns.NearbyHistory.All()), nil, "history forgotten")
  assert(has(out, "Enemy history forgotten. Tracked enemies and bounty targets stay."), "forget confirmed")
  out = run(sim, "nearby later")
  assert(has(out, "| /hg nearby on | off | test | clear | forget"), "unknown word prints status and choices")
end)

t.test("/hg theme lists themes and switches by name in any case", function()
  local sim = new("cata", {})
  local Theme = sim.ns.Theme
  local out = run(sim, "theme")
  assert(has(out, Theme.Current() .. " (on)"), "current theme marked: " .. out)
  out = run(sim, "theme EMBER")
  equal(Theme.Current(), "ember", "theme switched")
  assert(has(out, "theme: Ember"), "label confirmed")
  out = run(sim, "theme nope")
  equal(Theme.Current(), "ember", "unknown theme ignored")
  assert(has(out, "no theme named nope"), "unknown theme explained")
  equal(reload(sim).ns.Theme.Current(), "ember", "theme survives reload")
end)

t.test("/hg profile lists, copies and deletes by name and reports missing names", function()
  local sim = new("cata", {})
  local db, P = sim.env.HighgroundDB, sim.ns.Options.Profiles
  local out = run(sim, "profile")
  assert(has(out, "No other Battlegrounds profiles yet."), "nothing kept yet: " .. out)
  local code = P.ExportString(P.Snapshot(), "Arena Night")
  run(sim, "points killPer 9")
  out = run(sim, "import " .. code)
  assert(has(out, "Arena Night added to Profiles"), "an import is kept under its name: " .. out)
  equal(db.points.killPer, 9, "importing does not apply it")
  out = run(sim, "profile")
  assert(has(out, "Battlegrounds profiles: Arena Night."), "kept names listed: " .. out)
  out = run(sim, "profile copy battlegrounds Missing One")
  assert(has(out, "No profile by that name has these settings."), "missing profile explained: " .. out)
  out = run(sim, "  profile copy battlegrounds Arena Night  ")
  assert(has(out, "Copied Arena Night's Battlegrounds settings."), "spaces around a command and its name are ignored: " .. out)
  equal(db.points.killPer, nil, "the two-part name is kept whole and copied")
  out = run(sim, "profile delete Me")
  assert(has(out, "No profile by that name has these settings."), "this character's own settings cannot be deleted: " .. out)
  out = run(sim, "profile copy nowhere Arena Night")
  assert(has(out, "/hg profile copy ADDON NAME"), "usage for an unknown addon: " .. out)
  out = run(sim, "profile delete Arena Night")
  assert(has(out, "Deleted Arena Night."), "kept profile deleted: " .. out)
  assert(has(run(sim, "profile"), "No other Battlegrounds profiles yet."), "and no longer listed")
  out = run(sim, "profile share")
  assert(has(out, "Press Enter to share"), "share prepares a chat link")
end)

t.test("/hg config opens a named page or the Blizzard panel", function()
  local sim = new("cata", {})
  run(sim, "config behavior")
  assert(sim.env.HighgroundHub:IsShown(), "Highground window opened")
  equal(sim.ns.Hub.current, "behavior", "named page selected")
  sim.env.HighgroundHub:Hide()
  run(sim, "config")
  equal(sim.ns.Hub.current, "home", "plain config after closing starts at Home")
end)

-- The game owns these values (C_CVar): Highground keeps no copy.
for _, client in ipairs({ "cata", "retail" }) do
  local friends = client == "cata" and "nameplateShowFriends" or "nameplateShowFriendlyPlayers"

  t.test(client .. " /hg nameplates shows and changes the game's nameplate settings", function()
    local sim = new(client, {})
    local out = run(sim, "nameplates")
    assert(has(out, "Nameplates: range 45 yards, always show OFF, friendly players OFF."), "status: " .. out)
    out = run(sim, "nameplates range 60")
    equal(sim.cvars.nameplateMaxDistance, "60", "range written to the game")
    assert(has(out, "range 60 yards"), "new range confirmed: " .. out)
    out = run(sim, "nameplates range 100")
    equal(sim.cvars.nameplateMaxDistance, "60", "kept within the allowed range")
    assert(has(out, "20 to 60 yards"), "allowed range explained: " .. out)
    sim.cvarMax.nameplateMaxDistance = 41
    out = run(sim, "nameplates range 50")
    equal(sim.cvars.nameplateMaxDistance, "41", "the game's own cap applies")
    assert(has(out, "The game limits nameplate range to 41 yards."), "cap reported: " .. out)
    out = run(sim, "nameplates range far")
    assert(has(out, "/hg nameplates range YARDS"), "usage for a non-number: " .. out)
    run(sim, "nameplates all on")
    equal(sim.cvars.nameplateShowAll, "1", "all units")
    out = run(sim, "nameplates friends on")
    equal(sim.cvars[friends], "1", "friendly players use this client's setting")
    assert(has(out, "always show on, friendly players on"), "both confirmed: " .. out)
    out = run(sim, "nameplates friends maybe")
    assert(has(out, "/hg nameplates friends on|off"), "usage for a bad switch: " .. out)
    sim:setCombat(true)
    out = run(sim, "nameplates all off")
    equal(sim.cvars.nameplateShowAll, "1", "unchanged in combat")
    assert(has(out, "Leave combat to change nameplate settings."), "combat explained: " .. out)
    sim:setCombat(false)
    sim.cvars[friends] = nil
    out = run(sim, "nameplates friends on")
    assert(has(out, "This game client has no such nameplate setting."), "missing setting explained: " .. out)
    assert(has(run(sim, "nameplates"), "friendly players ?"), "missing setting shown as unknown")
  end)

  t.test(client .. " Battlegrounds settings change nameplates and lock in combat", function()
    local sim = new(client, {})
    sim.ns.Hub.Open("battlegrounds-settings")
    local page = sim.ns.Options.byKey["battlegrounds-settings"]
    local range, all, friend = page.nameplateRange, page.nameplateToggles[1], page.nameplateToggles[2]
    equal(range.box:GetText(), "45", "shows the game's range")
    equal(all:GetChecked(), false, "shows the game's switch")
    range.plus.scripts.OnClick(range.plus)
    equal(sim.cvars.nameplateMaxDistance, "46", "plus adds a yard")
    range.box:SetText("60"); range.box.scripts.OnEnterPressed(range.box)
    equal(sim.cvars.nameplateMaxDistance, "60", "typed range applied")
    equal(range.plus.enabled, false, "plus stops at the maximum")
    all.scripts.OnClick(all); friend.scripts.OnClick(friend)
    equal(sim.cvars.nameplateShowAll, "1", "always show written")
    equal(sim.cvars[friends], "1", "friendly players written")
    run(sim, "nameplates all off")
    equal(all:GetChecked(), false, "a command updates the open page")
    sim:setCombat(true)
    equal(all.enabled, false, "switches lock in combat")
    equal(range.minus.enabled, false, "range locks in combat")
    assert(page.nameplateNote:GetText():find("Leave combat", 1, true), "combat explained")
    sim:setCombat(false)
    sim.cvars.nameplateShowAll = "1" -- changed in the game's own options
    page.RefreshBehavior()
    equal(all:GetChecked(), true, "refresh reads the game's value")
    equal(all.enabled, true, "unlocked after combat")
    equal(page.nameplateNote:GetText(), "20 to 60 yards. The game may cap it lower.", "range explained")
  end)
end

t.finish("Settings commands: " .. t.tests .. " tests")
