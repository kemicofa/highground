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
