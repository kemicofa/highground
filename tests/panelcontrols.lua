-- Shared integration scenarios, run from each standalone HUD addon's folder.
return function(addon)
  local t = dofile("../../tools/harness.lua")("standalone panel controls")
  local new = dofile(addon == "HighgroundBattlegrounds" and "../../tools/wowsim/battleground/runtime.lua"
    or "../../tools/wowsim/runtime.lua")
  local function click(button) button.scripts.OnClick(button, "LeftButton") end
  local function pick(sim, gear, text)
    click(gear)
    local menu = sim.ns.Kit.Dropdown.Frame()
    assert(menu and menu:IsShown(), "cog opens a menu")
    for _, row in ipairs(menu.rows) do
      if row:IsShown() and row.label:GetText() == text then click(row); return end
    end
    error("Missing action: " .. text)
  end
  for _, case in ipairs({ { "retail", 120100 }, { "retail", 16001 }, { "cata", 40402 } }) do
    t.test(addon .. " " .. case[2] .. " keeps panel controls reachable without Highground", function()
      local saved = { locked = true, reducedMotion = true }
      local sim = new(case[1], saved, function(s, env)
        s.addon = addon
        env.GetBuildInfo = function() return "x", "1", "Nov 4 2026", case[2] end
      end)
      local ns, C = sim.ns, sim.ns.Core
      if ns.BattlegroundsPreview then ns.BattlegroundsPreview.Start()
      elseif ns.ArenaPreview then ns.ArenaPreview()
      else ns.Nearby.Update() end
      local shown, first = 0
      for _, w in ipairs(ns.Timers.windows) do
        if w:IsVisible() then
          shown, first = shown + 1, first or w
          assert(w.gear:IsVisible() and w.gear.mouseEnabled, "each independent panel has a clickable cog")
          t.equal(w.gear:GetAlpha(), 0.25, "locked cog is faded")
        end
      end
      assert(shown > 0, "panels show without the battleground enemy board")
      pick(sim, first.gear, "Unlock panels")
      t.equal(saved.locked, false, "unlock uses the standalone's own settings")
      local moved = 0
      first.StartMoving = function() moved = moved + 1 end
      first.scripts.OnDragStart(first)
      t.equal(moved, 1, "unlock enables dragging")
      pick(sim, first.gear, "Lock panels")
      first.scripts.OnDragStart(first)
      t.equal(moved, 1, "lock prevents dragging")
      pick(sim, first.gear, "Arrange panels")
      t.equal(saved.locked, false, "standalone arrangement unlocks panels")
      assert((ns.Timers and ns.Timers.previewing) or (ns.Arena and ns.Arena.preview)
        or (ns.Nearby and ns.Nearby.preview), "arrangement offers sample data")
      if ns.SetCompact then
        ns.SetCompact(true)
        local cogs = 0
        for _, w in ipairs(ns.Timers.windows) do if w.gear:IsVisible() then cogs = cogs + 1 end end
        t.equal(cogs, 1, "standalone battleground column has exactly one cog")
        ns.SetCompact(false)
      end
      pick(sim, first.gear, "Panel appearance")
      local page = ns.StandaloneSettings.frame
      page:Show()
      assert(not page.more, "settings need no expansion button")
      for _, row in ipairs(page.rows) do assert(row:IsVisible(), "every setting is available immediately") end
      assert(page.transparencyToggle:IsVisible() and page.transparencyToggle:GetChecked(),
        "panel transparency is on by default and available in Appearance")
      sim.mouseOver = nil
      sim:advance(0.2)
      t.close(first.head:GetAlpha(), 0.65, "idle panel background is translucent")
      sim.mouseOver = first
      sim:advance(0.2)
      t.equal(first.head:GetAlpha(), 1, "hover restores the background")
      sim.mouseOver = nil
      sim:advance(0.2)
      sim:setCombat(true)
      page.transparencyToggle:SetChecked(false)
      t.equal(saved.panelTransparency, false, "transparency preference is saved")
      t.equal(first.head:GetAlpha(), 1, "disabling transparency applies in combat")
      page.opacity:SetValue(40)
      t.close(first.head:GetAlpha(), 0.4, "standalone background opacity applies immediately")
      page.transparencyToggle:SetChecked(true)
      t.close(first.head:GetAlpha(), 0.26, "idle fade respects custom opacity")
      page.opacity:SetValue(0)
      t.equal(first.head:GetAlpha(), 0, "zero opacity is preserved")
      page.opacity:SetValue(40)
      page.transparencyToggle:SetChecked(false)
      sim:setCombat(false)
      local key = first.gear.key
      local settings = key == "arenaPoint" and "Arena settings" or key == "nearbyPoint" and "Nearby settings"
        or "Battleground settings"
      local opened = 0
      ns.StandaloneSettings.Open = function() opened = opened + 1 end
      pick(sim, first.gear, settings)
      t.equal(opened, 1, "settings route to this standalone addon")
      sim:setCombat(true)
      pick(sim, first.gear, "Lock panels")
      pick(sim, first.gear, "Unlock panels")
      t.equal(C.db.locked, false, "controls work in combat")
      pick(sim, first.gear, "End preview")
      assert(sim.messages[#sim.messages]:find("after combat", 1, true), "preview cannot resize secure rows in combat")
      sim:setCombat(false)
      pick(sim, first.gear, "End preview")
      sim:assertHealthy()
      local reloaded = new(case[1], saved, function(s, env)
        s.addon = addon
        env.GetBuildInfo = function() return "x", "1", "Nov 4 2026", case[2] end
      end)
      local reloadedPage = reloaded.ns.StandaloneSettings.frame
      reloadedPage:Show()
      t.equal(reloadedPage.transparencyToggle:GetChecked(), false, "disabled transparency survives reload")
      t.equal(reloadedPage.opacity:GetValue(), 40, "custom opacity survives reload")
      reloaded:assertHealthy()
    end)
  end
  t.finish("Standalone panel controls: " .. t.tests .. " scenarios")
end
