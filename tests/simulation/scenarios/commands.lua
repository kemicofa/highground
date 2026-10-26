local test, new, equal = ...

test("command dispatch preserves profile names, import case and settings aliases", function()
  local sim = new("cata")
  local db = sim.env.WarboardDB
  sim:command("points killPer 9")
  sim:command("profile save Assault Setup")
  sim:command("points killPer 2")
  sim:command("profile load Assault Setup")
  equal(db.points.killPer, 9, "profile restores scoring")
  equal(db.activeProfile, "Assault Setup", "profile name keeps original case")
  sim:command("import WB1;f=cata;p.killPer=7;s.MAGE.1.k=8")
  equal(db.points.killPer, 7, "import applies numeric values")
  equal(db.specRatings[8001].k, 8, "class token case survives command parser")
  sim:command("options")
  assert(sim.ns.Options.panel:IsShown(), "options alias opens actual settings panel")
  sim:command("weight range 2")
  equal(db.weights.range, 2, "weight command dispatches")
  local before = #sim.messages
  sim:command("weight")
  assert(#sim.messages > before + 1, "empty weight argument lists coefficients")
  sim:command("rows invalid")
  equal(db.rows, 40, "invalid numeric input preserves settings")
  sim:command("scale invalid")
  equal(db.scale, 0.8, "invalid scale preserves settings")
  sim:command("profile delete Assault Setup")
  equal(db.profiles["Assault Setup"], nil, "named profile deletion dispatches")
end)

test("diagnostic and display commands operate on the running addon", function()
  local sim = new("cata")
  sim:enemy("Enemy")
  sim:join()
  for _, command in ipairs({ "why", "kit", "err", "clearerr", "probe", "map", "intel", "timers", "help" }) do
    local before = #sim.messages
    sim:command(command)
    assert(#sim.messages > before, command .. " must produce feedback")
  end
  sim:command("call")
  assert(sim.chatDraft:find("Enemy", 1, true), "call command prepares selected target")
  sim:command("lock")
  equal(sim.env.WarboardDB.locked, true, "lock saved")
  sim:command("unlock")
  equal(sim.env.WarboardDB.locked, false, "unlock saved")
  sim:command("sniper test")
  sim:command("go")
  equal(sim.ns.Core.sniperTest.go, true, "sniper preview gets its own GO command")
  sim:command("sniper test")
  sim:command("go")
  assert(sim.ns.order[1].burnedAt, "normal GO command previews current enemy")
end)

test("/wb sound mutes every Warboard sound", function()
  local sim = new("cata")
  local Core = sim.ns.Core
  sim.env.WarboardDB.sniperSound = 1
  local before = #sim.sounds
  Core.PlaySniperSound()
  equal(#sim.sounds, before + 1, "lock-on sound plays")
  sim:command("sound")
  equal(sim.env.WarboardDB.sound, false, "sound switched off")
  Core.PlaySniperSound()
  equal(#sim.sounds, before + 1, "lock-on sound muted")
  sim.units.nameplate1 = { name = "Ganker", classID = 4, enemy = true, level = 60 }
  sim:event("NAME_PLATE_UNIT_ADDED", "nameplate1")
  sim:advance(1)
  equal(#sim.sounds, before + 1, "nearby alert muted")
end)

test("Test and commands settings page runs previews and lists every command", function()
  local sim = new("cata")
  local page
  for _, p in ipairs(sim.ns.Options.pages) do if p.name == "Test and commands" then page = p end end
  assert(page, "Test and commands page")
  local main
  for _, b in ipairs(page.previews) do if b.cmd == "test" then main = b end end
  main.scripts.OnClick(main)
  sim:advance(1)
  assert(sim.ns.Core.testMode, "Main panel button runs /wb test")
  main.scripts.OnClick(main)
  sim:advance(1)
  assert(not sim.ns.Core.testMode, "clicking again stops the preview")
  for _, b in ipairs(page.previews) do
    b.scripts.OnClick(b)
    sim:advance(0.5)
    b.scripts.OnClick(b)
    sim:advance(0.5)
  end
  -- every listed command exists
  for _, text in ipairs(page.commands) do
    for cmd in text:gmatch("/wb (%a+)") do
      assert(sim.ns.Commands[cmd], "listed command exists: " .. cmd)
    end
    for cmd in text:gmatch("|%s+(%a+)") do
      assert(sim.ns.Commands[cmd] or cmd == "ping" or cmd == "share", "listed alias exists: " .. cmd)
    end
  end
  local retail = new("retail")
  for _, p in ipairs(retail.ns.Options.pages) do
    if p.name == "Test and commands" then
      for _, b in ipairs(p.previews) do assert(b.cmd ~= "burst test", "Cata-only previews hidden on Retail") end
    end
  end
end)
