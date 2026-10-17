local test, new, equal = ...

local function anchor(frame)
  local p = frame.points[#frame.points]
  return p and p[2]
end

test("compact layout slims the panels and docks battleground windows under the main panel", function()
  local sim = new("cata")
  sim:enemy("Alpha")
  sim:join()
  sim:poi(36)
  sim:poi(37) -- an assault opens the objectives window
  sim:advance(1)
  local core, env = sim.ns.Core, sim.env
  equal(core.rows[1]:GetHeight(), 34, "normal two-line rows")
  equal(env.WarboardFrame:GetWidth(), 320, "normal width")
  assert(anchor(env.WarboardBasesFrame) == env.UIParent, "windows placed on their own")

  sim:command("compact on")
  sim:advance(1)
  equal(env.WarboardDB.compact, true, "saved")
  equal(core.rows[1]:GetHeight(), 20, "single-line rows")
  equal(env.WarboardFrame:GetWidth(), 250, "slim width")
  equal(env.WarboardBasesFrame:GetWidth(), 250, "docked windows share the width")
  equal(core.head.footer:IsShown(), false, "no footer")
  equal(core.hero.detail:IsShown(), false, "one-line hero")
  local below = anchor(env.WarboardBasesFrame)
  assert(below == env.WarboardFrame or below == env.WarboardTimersFrame, "objectives docked into the column")
  assert(anchor(env.WarboardTimersFrame) == env.WarboardFrame, "resurrection window hangs under the main panel")

  -- Dragging a docked window moves the column and saves the main position.
  env.WarboardFrame.points = { { "TOPLEFT", env.UIParent, "TOPLEFT", 40, -60 } }
  env.WarboardBasesFrame.scripts.OnDragStart(env.WarboardBasesFrame)
  env.WarboardBasesFrame.scripts.OnDragStop(env.WarboardBasesFrame)
  equal(env.WarboardCharDB.point[3], 40, "column position saved from the main panel")
  assert(anchor(env.WarboardBasesFrame) ~= env.UIParent, "window stays docked after the drag")

  -- Toggling in combat waits for combat to end (protected panels).
  sim:setCombat(true)
  sim:command("compact off")
  sim:advance(1)
  equal(core.rows[1]:GetHeight(), 20, "unchanged during combat")
  sim:setCombat(false)
  sim:advance(1)
  equal(core.rows[1]:GetHeight(), 34, "normal rows after combat")
  equal(env.WarboardFrame:GetWidth(), 320, "normal width after combat")
  assert(anchor(env.WarboardBasesFrame) == env.UIParent, "windows undocked to their own spots")
end)

test("background opacity applies to every panel surface and is saved", function()
  local sim = new("cata")
  sim:join()
  local core = sim.ns.Core
  equal(core.surfaces[1]:GetAlpha(), 0.45, "transparent by default")
  sim:command("opacity 20")
  equal(sim.env.WarboardDB.bgAlpha, 0.2, "saved")
  for _, t in ipairs(core.surfaces) do equal(t:GetAlpha(), 0.2, "surface follows the setting") end
  sim:command("opacity 500")
  equal(sim.env.WarboardDB.bgAlpha, 1, "clamped")
end)

test("compact Warsong Gulch docks the flag carriers under the main panel", function()
  local sim = new("cata")
  sim:enemy("Alpha")
  sim:command("compact on")
  sim:join(1460, 489, "Warsong Gulch")
  sim:advance(1)
  local env = sim.env
  assert(env.WarboardFlagsFrame and env.WarboardFlagsFrame:IsShown(), "flag window shown")
  assert(anchor(env.WarboardFlagsFrame) == env.WarboardFrame, "flags hang under the main panel")
  assert(anchor(env.WarboardTimersFrame) == env.WarboardFlagsFrame, "resurrection timers under the flags")
  equal(sim.ns.Flags.frows[1]:GetHeight(), 22, "single-line carrier rows")
end)

test("appearance settings restyle panels, rows and windows", function()
  local sim = new("cata")
  sim:enemy("Alpha")
  sim:join()
  sim:advance(1)
  local core, env = sim.ns.Core, sim.env
  local row = core.rows[1]
  assert(env.WarboardFrame.backdrop and env.WarboardFrame.backdrop.edgeSize == 1, "framed by default")

  core.SetFrameless(true)
  equal(env.WarboardFrame.backdrop, nil, "frameless drops the panel fill and border")
  equal(core.head.title:GetAlpha(), 0, "frameless hides the title bar")
  equal(core.head.footer:IsShown(), false, "frameless hides the footer")
  equal(env.WarboardDB.style.frameless, true, "saved")
  core.SetFrameless(false)
  equal(core.head.title:GetAlpha(), 1, "title bar returns")

  core.SetBorderSize(3)
  equal(env.WarboardFrame.backdrop.edgeSize, 3, "border size applies")
  core.SetBorderSize(0)
  equal(env.WarboardFrame.backdrop.edgeFile, nil, "no border at zero")

  core.SetMetric("row", 40, false)
  core.SetMetric("width", 400, false)
  equal(row:GetHeight(), 40, "row height applies")
  equal(env.WarboardFrame:GetWidth(), 400, "panel width applies")
  core.SetElement("rank", false)
  core.SetElement("icon", false)
  equal(row.rank:IsShown(), false, "rank number hidden")
  equal(row.icon:IsShown(), false, "icon hidden")
  equal(row.name.points[1][2], 9, "name moves left into the freed space")

  core.SetStyleChoice("bar", "blizzard")
  equal(row.hp.barTexture, "Interface\\TargetingFrame\\UI-StatusBar", "bar texture applies to rows")

  sim:command("arena test")
  core.SetPanelScale("arena", 1.5)
  equal(env.WarboardArenaFrame:GetScale(), env.WarboardDB.scale * 1.5, "arena panel scales on its own")
  equal(env.WarboardFrame:GetScale(), env.WarboardDB.scale, "main panel keeps the UI scale")
  equal(env.WarboardArenaRow1.bar.barTexture, "Interface\\TargetingFrame\\UI-StatusBar", "arena bars follow the texture")

  -- In combat sizes wait; fonts and bars do not.
  sim:setCombat(true)
  core.SetMetric("row", 30, false)
  equal(row:GetHeight(), 40, "row height waits for combat to end")
  sim:setCombat(false)
  sim:advance(1)
  equal(row:GetHeight(), 30, "row height applies after combat")

  core.ResetStyle()
  equal(row:GetHeight(), 34, "reset restores the theme row height")
  equal(row.icon:IsShown(), true, "reset shows the icon again")
end)

test("arena and flag carrier rows show spec icons when the spec is known", function()
  local sim = new("cata")
  sim:command("arena test")
  local r = sim.env.WarboardArenaRow1
  local core = sim.ns.Core
  local id = assert(core.specByName.ROGUE.Subtlety, "Subtlety known")
  equal(r.icon.texture, core.specInfo[id].icon, "preview rogue shows the Subtlety icon")
  assert(sim.env.WarboardArenaRow3.icon.texture ~= nil, "every preview row has a spec icon")
end)

test("/wb test shows enemies at different health and mana", function()
  local sim = new("cata")
  sim:command("test")
  sim:advance(0.5)
  local core = sim.ns.Core
  local seen, low, oom, dead = {}, false, false, false
  for _, r in ipairs(core.rows) do
    local e = r.entry
    if e then
      seen[r.hp.value] = true
      if e.testHp and e.testHp > 0 and e.testHp <= sim.env.WarboardDB.executePct then
        low = true
        equal(r.exec:GetAlpha(), 1, "execute outline on a low test enemy")
      end
      if e.manaPct then
        equal(r.mana:IsShown(), not e.dead, "mana bar on living mana users")
        equal(r.mana.value, e.manaPct, "mana bar shows the test value")
        oom = oom or e.manaPct < 0.05
      elseif not e.dead then
        equal(r.mana:IsShown(), false, "no mana bar without mana")
      end
      dead = dead or e.dead
    end
  end
  local values = 0
  for _ in pairs(seen) do values = values + 1 end
  assert(values >= 5, "test rows span several health values")
  assert(low and oom and dead, "test covers execute range, an empty healer and a dead enemy")
  core.SetElement("mana", false)
  sim:advance(0.5)
  for _, r in ipairs(core.rows) do equal(r.mana:IsShown(), false, "mana bar can be switched off") end
  sim:command("test")

  local retail = new("retail")
  retail:command("test")
  retail:advance(0.5)
  for _, r in ipairs(retail.ns.Core.rows) do
    equal(r.entry and r.entry.manaPct or nil, nil, "retail preview shows no enemy mana")
  end
end)

test("a seen enemy's mana fills the mana bar on Cata", function()
  local sim = new("cata")
  sim:enemy("Healer", { mana = 30000, maxMana = 100000 })
  sim:join()
  sim:advance(0.5)
  local r = sim.env.WarboardRow1
  equal(r.mana:IsShown(), true, "mana bar shown")
  equal(r.mana.value, 0.3, "mana fraction")
end)

test("health fills the row with a percentage; the thin line style remains", function()
  local sim = new("cata")
  sim:command("test")
  sim:advance(0.5)
  local core = sim.ns.Core
  local low
  for _, r in ipairs(core.rows) do
    if r.entry and r.entry.testHp == 0.28 then low = r end
  end
  assert(low, "test enemy under the execute threshold")
  equal(core.HealthFill(), true, "fill is the default health style")
  local top
  for _, p in ipairs(low.hp.points) do if p[1] == "TOPLEFT" then top = p end end
  assert(top, "health spans the row's height")
  assert(low.hp:GetFrameLevel() < low.content:GetFrameLevel(), "texts and icons draw over the fill")
  equal(low.hpText.text, "28%", "health percentage")
  equal(low.hpText:IsShown(), true, "percentage shown")
  assert(low.mana:GetHeight() >= 3, "mana is a readable bar")

  core.SetStyleChoice("barColor", "health")
  equal(core.BarColor({ r = 0, g = 0, b = 1 }, nil, 0.28).r, 1, "low health turns the bar red")
  equal(core.BarColor({ r = 0, g = 0, b = 1 }, nil, nil).b, 1, "unreadable health keeps the class color")

  core.SetStyleChoice("healthStyle", "line")
  for _, p in ipairs(low.hp.points) do assert(p[1] ~= "TOPLEFT", "line style is a bottom line") end
  equal(low.hp:GetHeight(), 3, "line keeps its height setting")
  core.SetElement("healthText", false)
  sim:advance(0.5)
  equal(low.hpText:IsShown(), false, "percentage can be hidden")
  sim:command("test")

  local retail = new("retail")
  retail:command("test")
  retail:advance(0.5)
  for _, r in ipairs(retail.ns.Core.rows) do
    if r.entry then equal(r.hpText:IsShown(), false, "retail cannot read health, so no percentage") end
  end
end)
