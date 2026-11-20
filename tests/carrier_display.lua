-- Live and preview carrier rows, including native restricted health widgets.
return function(addon)
  local t = dofile("../../tools/harness.lua")(addon .. " carrier display")
  local new = dofile("../../tools/wowsim/battleground/runtime.lua")
  local function equal(a, b, why) t.equal(a, b, why or "carrier display") end
  local function setup(build, configure)
    return new(build == 40402 and "cata" or "retail", {}, function(s, env)
      s.addon = addon
      s.manifest = addon .. (build == 40402 and "_Cata" or "") .. ".toc"
      env.GetBuildInfo = function() return "test", "1", "", build end
      dofile("../../tools/wowsim/geometry.lua")(s)
      local methods = getmetatable(env.UIParent).__index
      methods.SetStatusBarColor = function(f, ...) f.statusColor = { ... } end
      if configure then configure(s, env, methods) end
    end)
  end
  local function carrier(sim)
    sim:join(1460, 489, "Warsong Gulch")
    local unit = { name = "Longenemyname", enemy = true, classID = 8, health = 64 }
    sim.units.arena1 = unit
    sim:event("CHAT_MSG_BG_SYSTEM_HORDE", "The Alliance flag was picked up by Longenemyname!")
    sim:advance(0.5)
    return sim.ns.Flags.frows[2], unit
  end
  local function above(sim, a, b)
    local x, y = sim.bounds(a), sim.bounds(b)
    assert(x[2] + x[4] <= y[2], "text and health occupy separate lines")
  end

  for _, build in ipairs({ 40402, 120100, 16001 }) do
    t.test(build .. ": readable carriers fit normal, compact and large text without rebinding in combat", function()
      local sim = setup(build)
      local row, unit = carrier(sim)
      equal(row.hpText.text, "64%")
      equal(row.bar.value, 0.64)
      equal(row.bar.statusColor[4], 1, "health is independent of faint row tints")
      for _, compact in ipairs({ false, true, false }) do
        sim.ns.SetCompact(compact)
        for _, scale in ipairs({ 1, 1.5, 1 }) do
          sim.ns.Core.SetFontScale(scale)
          local title = sim.ns.Flags.flagWin.title
          assert(title:GetStringWidth() <= title:GetWidth(), "empty header info does not truncate the panel title")
          assert(row.icon:GetWidth() >= 32, "class icon stays readable in both layouts")
          above(sim, row.name, row.bar); above(sim, row.bar, row.tag)
          local icon, name = sim.bounds(row.icon), sim.bounds(row.name)
          assert(icon[1] + icon[3] <= name[1], "portrait never overlaps the name")
          local tag, timing = sim.bounds(row.tag), sim.bounds(row.right)
          assert(tag[1] + tag[3] <= timing[1], "carrier team and timing stay separate")
          local a, b = sim.bounds(sim.ns.Flags.frows[1]), sim.bounds(row)
          assert(a[2] + a[4] <= b[2], "health does not stretch rows over each other")
        end
      end
      local binding, height = row.attrs.macrotext1, row:GetHeight()
      sim:setCombat(true)
      sim.ns.Core.SetFontScale(1.5)
      sim.ns.Theme.Use("parchment")
      equal(row.bar.statusColor[4], 1, "theme switches keep the live health opaque")
      equal(row:GetHeight(), height, "combat defers geometry")
      equal(row.attrs.macrotext1, binding, "combat preserves secure targeting")
      unit.health = 0; sim:advance(0.5)
      equal(row.bar.value, 0, "zero health never becomes a full bar")
      sim:setCombat(false); sim:advance(0.5)
      assert(row:GetHeight() > height, "deferred large text layout applies")
      sim.units.arena1 = nil; sim:advance(0.5)
      equal(row.hpText.text, "?", "unknown health is explicit")
      equal(row.bar.value, 0, "unseen carrier does not reuse the last reading")
      sim:event("CHAT_MSG_BG_SYSTEM_HORDE", "Longenemyname captured the Alliance flag!")
      sim:advance(0.5)
      assert(not row.hpText:IsShown() and not row.healthTextBg:IsShown(), "empty slots clear health text")
      sim:assertHealthy()
    end)
  end

  for _, build in ipairs({ 120100, 16001 }) do
    t.test(build .. ": restricted health is drawn and formatted only by native widgets", function()
      local secret, curve = { secret = true }, {}
      local sim = setup(build, function(_, env, methods)
        env.CurveConstants = { ScaleTo100 = curve }
        env.UnitHealthPercent = function() return secret end
        methods.SetFormattedText = function(f, fmt, value) f.formatted = { fmt, value } end
      end)
      local row, unit = carrier(sim)
      unit.health, unit.maxHealth = secret, secret
      sim:setCombat(true); sim:advance(0.5)
      equal(row.bar.value, secret, "restricted health is forwarded directly")
      equal(row.hpText.formatted[2], secret, "percentage formatting stays native")
      equal(row.bar.statusColor[4], 1)
      sim:assertHealthy()
    end)
  end

  t.test("preview shows the same opaque health and clears stale empty-slot state", function()
    local sim = setup(16001)
    sim.ns.Flags.BuildFlags()
    local row = sim.ns.Flags.frows[1]
    row.hpText:Hide()
    assert(sim.ns.BattlegroundsPreview.Start())
    equal(row.hpText.text, "82%")
    equal(row.bar.value, 0.82)
    equal(row.bar.statusColor[4], 1)
    assert(row.hpText:IsShown() and row.healthTextBg:IsShown())
    sim.ns.SetCompact(true)
    assert(not row.healthTextBg:IsShown(), "compact percentage sits above the thin bar")
    sim:assertHealthy()
  end)
  t.finish("Carrier display: " .. t.tests .. " scenarios")
end
