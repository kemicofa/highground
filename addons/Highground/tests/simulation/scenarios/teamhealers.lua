local test, new, equal = ...

-- Team healers (core/HealerTags.lua, ui/TeamHealers.lua): WoW Forever gives
-- every teammate the DAMAGER role, so Highground inspects teammates who can
-- heal, and the player can mark or unmark one by hand.

local function forever(s)
  s.env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end
  s.env.loadstring_untainted = nil
  s.secureSnippets = false
end

-- Forever's inspect: config -1 holds the last inspected player's trait
-- tree; trees without points are left out, as read live (2026-11-24).
-- points[guid] = { tree1, tree2, tree3 }.
local function inspection(sim, points)
  local env, asked = sim.env, {}
  local current
  env.CanInspect = function(unit) return sim.units[unit] ~= nil and not sim.units[unit].far end
  env.NotifyInspect = function(unit) asked[#asked + 1] = unit; current = env.UnitGUID(unit) end
  env.ClearInspectPlayer = function() current = nil end
  env.C_Traits = {
    GetConfigInfo = function(id) if id == -1 and current then return { ID = -1, treeIDs = { 900 } } end end,
    GetGroupDisplayInfoByTreeID = function()
      return { { groupID = 3, orderIndex = 2, displayName = "Tree3" }, { groupID = 2, orderIndex = 1, displayName = "Tree2" },
        { groupID = 1, orderIndex = 0, displayName = "Tree1" } }
    end,
    GetGroupCurrencyInfo = function(_, ids)
      local infos, spent = {}, points[current] or {}
      for _, id in ipairs(ids) do
        if (spent[id] or 0) > 0 then infos[#infos + 1] = { traitNodeGroupID = id, currencyInfos = { { spent = spent[id] } } } end
      end
      return infos
    end,
  }
  return asked
end

-- A Forever raid: you (a mage), a shaman, a rogue and a priest, everyone
-- DAMAGER. The shaman stands at a nameplate and a raid frame.
local function team(sim)
  sim.raid, sim.members = true, 4
  local units = {
    raid2 = { name = "Axel", classID = 7, role = "DAMAGER", guid = "Player-1-02" },
    raid3 = { name = "Rook", classID = 4, role = "DAMAGER", guid = "Player-1-03" },
    raid4 = { name = "Lunara", classID = 5, role = "DAMAGER", guid = "Player-1-04" },
  }
  sim.units.raid1 = sim.units.player
  sim.units.player.role = "DAMAGER"
  for token, unit in pairs(units) do sim.units[token] = unit end
  sim.units.nameplate21 = units.raid2
  sim.plates.nameplate21 = sim.env.CreateFrame("Frame", nil, sim.env.UIParent)
  local frame = sim.env.CreateFrame("Button", "CompactRaidGroup1Member2", sim.env.UIParent)
  frame.unit = "raid2"
  return units, frame
end

local function shown(pool)
  local list = {}
  for _, m in ipairs(pool) do if m:IsShown() then list[#list + 1] = m end end
  return list
end

test("WoW Forever: inspecting teammates at the gates gives healers the green cross", function()
  local sim = new("retail", nil, forever)
  local C = sim.ns.Core
  local units, frame = team(sim)
  local asked = inspection(sim, { [units.raid2.guid] = { 0, 0, 31 }, [units.raid4.guid] = { 0, 21, 0 } })
  sim:enemy("Enemy")
  sim:join()
  equal(asked[1], "raid2", "the shaman is asked first; you and the rogue never are")
  equal(#asked, 1, "one request at a time")
  equal(#shown(C.healerMarks), 0, "no cross before the answer")

  sim:event("INSPECT_READY", "Player-1-03")
  equal(C.TeamHealer("raid2"), false, "another player's answer is ignored")
  sim:event("INSPECT_READY", units.raid2.guid)
  local healer, by = C.TeamHealer("raid2")
  equal(healer, true, "31 points in Restoration")
  equal(by, "inspect", "from the inspect")
  sim:advance(0.3)
  local marks = shown(C.healerMarks)
  equal(#marks, 1, "the inspected healer gets a cross")
  equal(marks[1].anchor, sim.plates.nameplate21, "above the shaman's nameplate")
  local color = marks[1].parts[1].colorTexture
  assert(color[2] > color[1] and color[2] > color[3], "the cross is green")
  local framed = shown(C.frameHealerMarks)
  equal(#framed, 1, "and a small cross on the shaman's raid frame")
  equal(framed[1].anchor, frame, "anchored to the raid frame")

  sim:advance(1.5)
  equal(asked[#asked], "raid4", "then the priest")
  sim:advance(C.INSPECT_WAIT + 0.5)
  equal(asked[#asked], "raid4", "an unanswered teammate waits before it is asked again")
  sim:advance(C.INSPECT_RETRY)
  equal(asked[#asked], "raid4", "and is asked again")
  local before = #asked
  sim:event("INSPECT_READY", units.raid4.guid)
  equal(C.TeamHealer("raid4"), true, "21 points in Holy")
  sim:advance(30)
  equal(#asked, before, "each teammate is inspected once a match")
  equal(sim.ns.Scope.Saved("healerTags", "social")[C.CanonUnit("raid2")].healer, true, "kept for later matches")

  frame:Hide(); sim:advance(0.3)
  equal(#shown(C.frameHealerMarks), 0, "a hidden raid frame has no cross")
  sim.env.HighgroundDB.healerMarks = false; sim:advance(0.3)
  equal(#shown(C.healerMarks), 0, "healer markers off hides them")
  sim:assertHealthy()
end)

test("WoW Forever: a teammate marked by hand is never inspected, and the inspect switch stops requests", function()
  local sim = new("retail", nil, forever)
  local C = sim.ns.Core
  local units = team(sim)
  local asked = inspection(sim, { [units.raid2.guid] = { 0, 31, 0 } })
  sim:enemy("Enemy")
  sim.env.HighgroundDB.healerInspect = false
  sim:join(); sim:advance(3)
  equal(#asked, 0, "inspect switch off: no requests")
  sim.env.HighgroundDB.healerInspect = true
  sim.units.mouseover = units.raid2
  sim.env.Highground_TeamHealer()
  equal(C.TeamHealer("raid2"), true, "the key binding marks the teammate under the mouse")
  sim:advance(3)
  equal(asked[1], "raid4", "a hand mark is not inspected")
  sim.env.Highground_TeamHealer()
  equal(C.TeamHealer("raid2"), false, "pressing it again unmarks")
  sim:assertHealthy()
end)

test("/hg healer and the Team healers window mark the same teammates", function()
  local sim = new("retail", nil, forever)
  local C, W = sim.ns.Core, sim.ns.TeamHealers
  local units = team(sim)
  inspection(sim, {})
  sim:enemy("Enemy")
  sim:join()
  sim:command("healer lunara")
  equal(C.TeamHealer("raid4"), true, "by name, any case")
  sim:command("healer Rook")
  equal(C.HealerTag(C.CanonUnit("raid3")), nil, "a rogue can't be marked")
  sim:command("healer Nobody")
  sim.units.target = units.raid2
  sim:command("healer")
  equal(C.TeamHealer("raid2"), true, "without a name: your target")

  sim:command("healers")
  assert(W.win:IsShown(), "the window opens")
  equal(#W.items, 2, "one row per teammate who can heal: the shaman and the priest")
  local rows = shown(W.win.list.rows)
  equal(#rows, 2, "two rows drawn")
  local axel
  for _, row in ipairs(rows) do if row.item.unit == "raid2" then axel = row end end
  assert(axel.selected, "a marked teammate is checked")
  axel:Click()
  equal(C.TeamHealer("raid2"), false, "a click unmarks")
  assert(not axel.selected, "and clears the check")
  sim:command("healer Axel")
  assert(axel.selected, "a command updates the open window")
  W.Close()
  sim:assertHealthy()
end)

test("/hg healers test shows sample teammates without saving their marks", function()
  local sim = new("retail", nil, forever)
  local W = sim.ns.TeamHealers
  sim:command("healers test")
  assert(W.win:IsShown() and W.sample, "the sample opens")
  equal(#W.items, 4, "four sample teammates")
  local rows = shown(W.win.list.rows)
  local before = rows[4].item.healer
  rows[4]:Click()
  equal(rows[4].item.healer, not before, "a sample row toggles")
  equal(next(sim.ns.Scope.Saved("healerTags", "social")), nil, "nothing is saved")
  sim:command("healers test")
  assert(not W.win:IsShown(), "running it again stops the sample")
  sim:assertHealthy()
end)

test("Retail never inspects: the group role names healers", function()
  local sim = new("retail")
  local units = team(sim)
  local asked = inspection(sim, {})
  units.raid2.role = "HEALER"
  sim:enemy("Enemy")
  sim:join(); sim:advance(5)
  equal(#asked, 0, "no inspect requests")
  equal(sim.ns.Core.TeamHealer("raid2"), true, "the HEALER role")
  equal(#shown(sim.ns.Core.healerMarks), 1, "one green cross")
  sim:assertHealthy()
end)

test("/hg test leaves the Team healers sample to its own preview button", function()
  local sim = new("retail", nil, forever)
  local H, W, O = sim.ns.Hub, sim.ns.TeamHealers, sim.ns.Options
  H.Open("battlegrounds-previews")
  sim.ns.PreviewTests.StartAll()
  assert(H.win:IsVisible() and not (W.win and W.win:IsShown()), "starting every preview keeps the Highground window")
  sim.ns.PreviewTests.StopAll()
  local button
  for _, b in ipairs(O.byKey["battlegrounds-previews"].previews) do if b.cmd == "healers test" then button = b end end
  assert(button, "the Previews page offers the sample")
  button:Click()
  assert(W.IsSample(), "Start opens the sample")
  W.Close()
  sim:assertHealthy()
end)

test("WoW Forever finds enemies on you and on your healers by their target's name", function()
  local sim = new("retail", nil, forever)
  local C = sim.ns.Core
  C.SetElement("hero", true)
  -- The game hides whether an enemy's target is you; the name stays plain.
  local secret, isUnit = { secret = true }, sim.env.UnitIsUnit
  sim.env.UnitIsUnit = function(a, b)
    if b == "player" and a ~= "target" and a:find("target$") then return secret end
    return isUnit(a, b)
  end
  sim.raid, sim.members = true, 2
  sim.units.raid1 = sim.units.player
  local healer = { name = "Lunara", classID = 5, role = "HEALER" }
  sim.units.raid2 = healer
  local _, onYou = sim:enemy("Alpha", { yards = 10 })
  local _, onHealer = sim:enemy("Beta", { yards = 12 })
  sim:join()
  sim.units[onYou .. "target"], sim.units[onHealer .. "target"] = sim.units.player, healer
  sim:advance(0.5)
  local alpha, beta = sim:entry("Alpha"), sim:entry("Beta")
  assert(alpha.onMe and not alpha.onHealer, "your name means on you")
  assert(not beta.onMe and beta.onHealer == "Lunara-Realm", "a teammate who heals is named")
  assert(C.subtitle.text:find("1 ON YOU", 1, true), "the header counts enemies on you")
  assert(C.Explain(beta) and table.concat(beta.reasons, " "):find("targeting your healer Lunara", 1, true), "the reason names the healer")
  sim.units[onYou .. "target"] = nil
  sim:advance(0.5)
  assert(not alpha.onMe and not C.subtitle.text:find("ON YOU", 1, true), "the count clears")
  sim:assertHealthy()
end)
