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
