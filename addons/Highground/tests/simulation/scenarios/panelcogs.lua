local test, new, check = ...
local function equal(a, b, why) return check(a, b, why or "values match") end
local function click(button, mouse) button.scripts.OnClick(button, mouse or "LeftButton") end
local function pick(sim, anchor, text, mouse)
  click(anchor, mouse)
  local menu = sim.env.HighgroundDropdown
  assert(menu:IsShown(), "panel controls open")
  for _, row in ipairs(menu.rows) do
    if row:IsShown() and row.label:GetText() == text then
      click(row)
      assert(not menu:IsShown(), "choosing an action closes the menu")
      return
    end
  end
  error("Missing panel action: " .. text)
end

-- Check actual access, including invisible-but-shown secure windows.
local function cog(w, expected)
  assert(w and w.gear, "every HUD panel has a cogwheel")
  equal(w.gear:IsVisible(), expected, "cog visibility")
  equal(w.gear.mouseEnabled, expected, "only the visible cog accepts clicks")
end

for _, client in ipairs({ "cata", "retail" }) do
test(client .. " transparent panels preserve content, combat actions and saved appearance", function()
  local sim = new(client, { nearby = true, reducedMotion = true, locked = true })
  sim:advance(1.2)
  local C, N = sim.ns.Core, sim.ns.Nearby
  sim.ns.NearbyPreview()
  local w, row = N.win, N.rows[1]
  local fill
  w.SetBackdropColor = function(_, _, _, _, alpha) fill = alpha end
  sim.ns.ApplyOpacity()
  equal(fill, 0.65, "panel fill is translucent by default")
  equal(w.head:GetAlpha(), 0.65, "header follows panel transparency")
  equal(row.classBg:GetAlpha(), 0.65, "new rows inherit the panel transparency")
  equal(w:GetAlpha(), 1, "secure panel itself remains solid")
  equal(w.title:GetAlpha(), 1, "header text remains solid")
  equal(row:GetAlpha(), 1, "fresh enemy content remains solid")
  local backdrop = w.SetBackdrop
  w.SetBackdrop = function() error("hover must not rebuild backdrop geometry") end
  sim.mouseOver = w
  sim:advance(0.2)
  equal(fill, 1, "hover restores the fill")
  equal(w.head:GetAlpha(), 1, "hover restores the header")
  click(w.gear)
  sim.mouseOver = nil
  sim:advance(0.2)
  equal(fill, 1, "open menu keeps the panel clear")
  sim.ns.Kit.Dropdown.Hide()
  equal(fill, 0.65, "closing the menu restores transparency")
  w.SetBackdrop = backdrop
  pick(sim, w.gear, "Panel appearance")
  equal(sim.ns.Hub.current, "nearby-appearance", "cog opens its addon appearance")
  click(sim.ns.Options.byKey["nearby-appearance"].shared)
  local toggle = sim.ns.Options.appearance.transparency
  assert(toggle:GetChecked(), "Appearance shows the default-on preference")
  local binding = row:GetAttribute("macrotext1")
  sim:setCombat(true)
  toggle:SetChecked(false)
  equal(fill, 1, "transparency can be disabled in combat")
  equal(row:GetAttribute("macrotext1"), binding, "appearance does not alter secure bindings")
  sim:setCombat(false)
  sim:command("profile save Solid")
  toggle:SetChecked(true)
  sim:command("profile load Solid")
  equal(C.PanelTransparency(), false, "profiles restore the transparency preference")
  equal(toggle:GetChecked(), false, "Appearance follows the loaded profile")
  local again = new(client, sim.env.HighgroundDB)
  equal(again.ns.Core.PanelTransparency(), false, "disabled transparency survives reload")
  sim:assertHealthy(); again:assertHealthy()
end)

test(client .. " compact battleground backgrounds brighten as one column", function()
  local sim = new(client, { locked = true, reducedMotion = true, compact = true })
  sim:enemy("Enemy"); sim:join(1460, 489, "Warsong Gulch")
  local C, P = sim.ns.Core, sim.ns.PanelControls
  local flags, timers = sim.ns.Flags.flagWin, sim.env.HighgroundTimersFrame
  equal(C.head.bg:GetAlpha(), 0.65, "enemy panel is transparent while idle")
  equal(flags.head:GetAlpha(), 0.65, "carrier panel is transparent while idle")
  equal(timers.head:GetAlpha(), 0.65, "timer panel is transparent while idle")
  sim.mouseOver = timers
  sim:advance(0.2)
  equal(C.head.bg:GetAlpha(), 1, "hovering timers brightens the enemy panel")
  equal(flags.head:GetAlpha(), 1, "hovering timers brightens the carrier panel")
  click(C.gear)
  sim.mouseOver = nil
  sim:advance(0.2)
  equal(timers.head:GetAlpha(), 1, "the column stays clear while its menu is open")
  sim.ns.Kit.Dropdown.Hide()
  equal(flags.head:GetAlpha(), 0.65, "closing the menu fades the entire column")
  local row = C.rows[1]
  row.entry.dead = true; C.Render()
  assert(math.abs(row.classBg:GetAlpha() - 0.26) < 0.00001, "dead enemies retain their dimmed surface")
  sim.mouseOver = flags; P.RefreshGears()
  equal(row.classBg:GetAlpha(), 0.4, "hover preserves dead-enemy dimming")
  equal(row.hp.bg:GetAlpha(), 0, "hover keeps the full-row health backing hidden")
  sim:setCombat(true)
  C.SetFeature("flags", false)
  sim.ns.Timers.SecureHide(flags)
  sim.mouseOver = nil; P.RefreshGears(); sim:advance(0.2)
  equal(flags:GetAlpha(), 0, "fading backgrounds cannot reveal a combat-hidden panel")
  sim:assertHealthy()
end)

test(client .. " nearby-only and arena-only frameless panels retain quick actions", function()
  local sim = new(client, { nearby = true, locked = true, reducedMotion = true, style = { frameless = true } })
  local C, P = sim.ns.Core, sim.ns.PanelControls
  sim:advance(1.2)
  local nearby = sim.ns.Nearby.win
  assert(not C.frame:IsShown(), "enemy board is absent in the open world")
  equal(sim.ns.Nearby.shownCount, 0, "empty nearby panel still has controls")
  cog(nearby, true)
  equal(nearby.title:GetAlpha(), 0)
  equal(nearby.gear:GetAlpha(), 0.25, "locked cog stays discoverable")
  nearby.gear:Hide()
  sim:advance(0.2)
  cog(nearby, true)
  pick(sim, nearby.gear, "Unlock panels")
  equal(C.db.locked, false); equal(nearby.title:GetAlpha(), 1); equal(nearby.gear:GetAlpha(), 1)
  pick(sim, nearby.gear, "Lock panels")
  click(nearby.gear)
  equal(nearby.gear:GetAlpha(), 1, "open menu holds the cog at full opacity")
  for _, item in ipairs(sim.ns.Kit.Dropdown.Items()) do
    assert(not item.text:find("Show 5", 1, true), "nearby does not change battleground row counts")
  end
  sim.ns.Kit.Dropdown.Hide()
  equal(nearby.gear:GetAlpha(), 0.25, "closing the menu restores the idle opacity")
  sim.mouseOver = nearby
  sim:advance(0.2); equal(nearby.gear:GetAlpha(), 1, "hover anywhere in the panel reveals its cog")
  sim.mouseOver = nil
  sim:advance(0.2); equal(nearby.gear:GetAlpha(), 0.25)
  pick(sim, nearby.gear, "Nearby settings")
  equal(sim.ns.Hub.current, "nearby")

  sim:joinArena()
  local arena = sim.ns.Arena.win
  cog(nearby, false); cog(arena, true)
  assert(not C.frame:IsShown(), "arena controls work without the enemy board")
  sim:setCombat(true)
  pick(sim, arena.gear, "Unlock panels")
  assert(P.Hint():find("after combat", 1, true))
  local moved = 0
  arena.StartMoving = function() moved = moved + 1 end
  arena.scripts.OnDragStart(arena); equal(moved, 0, "secure panel stays fixed in combat")
  click(arena.gear)
  equal(sim.ns.Kit.Dropdown.Items()[2].hint, "After combat", "placement explains the combat restriction")
  sim.ns.Kit.Dropdown.Hide()
  sim:setCombat(false)
  arena.scripts.OnDragStart(arena); equal(moved, 1, "unlocking permits movement after combat")
end)

test(client .. " compact cog follows visible panels when the enemy board or carrier vanishes", function()
  local sim = new(client, { locked = true, reducedMotion = true })
  local C = sim.ns.Core
  sim:enemy("Enemy"); sim:join(1460, 489, "Warsong Gulch")
  local flags, timers = sim.ns.Flags.flagWin, sim.env.HighgroundTimersFrame
  cog(C.frame, true); cog(flags, true); cog(timers, true)
  sim:command("compact on")
  C.SetFrameless(true)
  cog(C.frame, true); cog(flags, false); cog(timers, false)
  sim.mouseOver = timers
  sim:advance(0.2); equal(C.gear:GetAlpha(), 1, "hovering any member reveals the column's cog")
  sim.mouseOver = nil
  click(C.gear)
  C.SetFeature("killorder", false)
  assert(not sim.ns.Kit.Dropdown.IsShown(), "hiding the menu's owner closes it")
  cog(C.frame, false); cog(flags, true); cog(timers, false)
  pick(sim, flags.gear, "Unlock panels")
  equal(C.db.locked, false, "remaining panels can unlock the whole column")
  pick(sim, flags.gear, "Lock panels")

  sim:setCombat(true)
  sim.ns.Timers.SecureHide(flags)
  assert(flags:IsShown() and flags:GetAlpha() == 0, "combat hiding retains the secure frame")
  cog(flags, false); cog(timers, true)
  click(timers.gear)
  flags:SetAlpha(1)
  sim.ns.PanelControls.RefreshGears()
  cog(flags, true); cog(timers, false)
  assert(not sim.ns.Kit.Dropdown.IsShown(), "handoff closes the previous owner's menu")
  sim:setCombat(false)
  sim:command("compact off")
  cog(flags, true); cog(timers, true)
  C.SetFeature("killorder", true)
  cog(C.frame, true)
  sim:leave()
  cog(C.frame, false); cog(flags, false); cog(timers, false)
end)
end

test("cog fades reverse smoothly and reduced motion settles them", function()
  local sim = new("retail", { nearby = true, locked = true })
  sim:advance(1.2)
  local w = sim.ns.Nearby.win
  equal(w.gear:GetAlpha(), 0.25)
  sim.mouseOver = w
  sim.ns.PanelControls.RefreshGears()
  sim:advance(0.05)
  assert(w.gear:GetAlpha() > 0.25 and w.gear:GetAlpha() <= 1)
  assert(w.head:GetAlpha() > 0.65 and w.head:GetAlpha() < 1, "background also fades smoothly")
  sim.mouseOver = nil
  sim:advance(0.3); equal(w.gear:GetAlpha(), 0.25)
  equal(w.head:GetAlpha(), 0.65, "reversing a fade returns to idle transparency")
  sim.mouseOver = w
  sim.ns.PanelControls.RefreshGears()
  sim:advance(0.05)
  sim.ns.Core.db.reducedMotion = true
  sim.ns.Motion.Refresh()
  equal(w.gear:GetAlpha(), 1)
  equal(w.head:GetAlpha(), 1, "reduced motion settles the background immediately")
  sim.mouseOver = nil
  sim:advance(0.1); equal(w.gear:GetAlpha(), 0.25)
end)

test("HUD header controls fit normal, compact and enlarged text layouts", function()
  local sim = new("cata", {}, function(s) dofile("../../tools/wowsim/geometry.lua")(s) end)
  local C = sim.ns.Core
  sim.ns.NearbyPreview(); sim.ns.ArenaPreview(); sim.ns.BattlegroundsPreview.Start()
  C.SetFeature("quickCalls", true)
  for _, compact in ipairs({ false, true }) do
    sim.ns.SetCompact(compact)
    for _, scale in ipairs({ 1, 1.5 }) do
      C.SetFontScale(scale)
      for _, theme in ipairs({ "highground", "azeroth" }) do
        sim.ns.Theme.Use(theme)
        for _, w in ipairs(sim.ns.Timers.windows) do
          local frame, gear, title = sim.bounds(w), sim.bounds(w.gear), sim.bounds(w.title)
          assert(gear[1] >= frame[1] and gear[1] + gear[3] <= frame[1] + frame[3], "cog fits inside panel width")
          local header = w.key == "quickCallsPoint" and w.head:GetHeight() or select(2, sim.ns.Timers.Geometry(w))
          assert(gear[2] >= frame[2] and gear[2] + gear[4] <= frame[2] + header + 0.001,
            w.key .. ": cog does not intercept the first row")
          assert(title[3] > 0 and title[1] + title[3] < gear[1], "title reserves space for the cog")
          if (w.info:GetText() or "") == "" then
            assert(w.title:GetStringWidth() * sim.geometryScale(w.title) <= title[3], w.key .. ": title is not cut short")
          end
          if w.info:IsShown() then
            local info = sim.bounds(w.info)
            assert(info[1] + info[3] < gear[1], "live count stays beside the cog")
            assert(title[1] + title[3] < info[1], "title cannot overlap live count")
          end
        end
      end
    end
  end
end)
