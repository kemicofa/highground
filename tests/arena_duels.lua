-- Both owners load the same duel panel through their real manifests.
return function(addon)
  local t = dofile("../../tools/harness.lua")(addon .. " duels")
  local new = dofile("../../tools/wowsim/battleground/runtime.lua")
  local test = t.test
  local function equal(actual, expected, why) t.equal(actual, expected, why or "duel state") end
  local function setup(build, saved, configure)
    return new(build == 40402 and "cata" or "retail", saved or {}, function(s, env)
      s.addon = addon
      s.manifest = addon .. (build == 40402 and "_Cata" or "") .. ".toc"
      env.GetBuildInfo = function() return "x", "1", "Nov 19 2026", build end
      env.StartDuel, env.CancelDuel = function() end, function() end
      env.DUEL_COUNTDOWN, env.DUEL_STARTED, env.DUEL_CANCELLED = "Duel starting: %d", "Duel starting!", "Duel cancelled."
      if configure then configure(s, env) end
    end)
  end
  local function player(sim, token, name, class, health)
    local unit = { name = name, classID = class or 4, health = health or 72, guid = "Player-" .. name }
    sim.units[token] = unit
    return unit
  end
  local function countdown(sim, seconds)
    sim:event("CHAT_MSG_SYSTEM", string.format(sim.env.DUEL_COUNTDOWN, seconds or 3))
  end
  local function hidden(sim)
    local win = sim.ns.Arena.win
    return not win or not win:IsVisible() or win:GetAlpha() == 0
  end

  for _, build in ipairs({ 16001, 120100, 40402 }) do
    test(build .. ": challenge opens immediately; countdown and combat keep one opponent", function()
      local sim = setup(build)
      local opponent = player(sim, "nameplate1", "Sneak", 4, 72)
      local bystander = player(sim, "target", "Bystander", 8, 10)
      sim:event("DUEL_REQUESTED", "Sneak-Realm")
      local A = sim.ns.Arena
      assert(A.win and A.win:IsVisible(), "request shows the panel without waiting for a tick")
      equal(A.win.title.text, "DUEL")
      equal(A.win.info.text, "Requested")
      equal(A.shownCount, 1, "one duel opponent")
      assert(A.rows[1]:IsVisible() and not A.rows[2]:IsVisible())
      equal(A.rows[1].name.text, "Sneak")
      equal(A.rows[1].right.text, "72%", "observe the challenger, not our current target")
      equal(A.rows[1].attrs.macrotext1, "/targetexact Sneak-Realm")
      assert(not A.rows[1].number:IsShown(), "no arena slot label in duels")
      assert(A.rows[1].trinket:IsShown() and A.rows[1].trinketState.text == "?", "missing timing is explicitly unknown")
      equal(A.rows[1]:GetHeight(), 70, "compact duel row")
      countdown(sim)
      equal(A.win.info.text, "Starts in 3")
      sim:advance(1.25)
      equal(A.win.info.text, "Starts in 2")
      sim:setCombat(true)
      sim:click(A.rows[1], "RightButton")
      equal(sim.units.focus, opponent, "focus opponent in combat")
      equal(sim.units.target, bystander, "keep the previous target")
      sim:click(A.rows[1], "LeftButton")
      equal(sim.units.target, opponent, "target opponent in combat")
      sim:advance(2.1)
      equal(A.win.info.text, "Active")
      sim:event("DUEL_FINISHED")
      assert(hidden(sim), "finishing during combat fades the panel immediately")
      sim:setCombat(false)
      assert(not A.win:IsVisible(), "hide protected frame after combat")
      equal(A.duel, nil)
      equal(next(A.seen), nil, "no stale opponent")
    end)
  end

  test("Forever outgoing challenge preserves surnames and secure clicks without snippets", function()
    local sim = setup(16001, {}, function(s)
      s.regionalNames, s.secureSnippets = true, false
    end)
    local opponent = player(sim, "target", "River Mist", 8)
    sim.units.nameplate1 = opponent
    sim.env.StartDuel("target", true)
    local A = sim.ns.Arena
    assert(A.win:IsVisible(), "outgoing request opens immediately")
    equal(A.rows[1].name.text, "River Mist", "full Forever character name")
    equal(A.rows[1].attrs.macrotext1, "/targetexact River Mist")
    local bystander = player(sim, "target", "Stone Hand", 1)
    countdown(sim)
    sim:setCombat(true)
    sim:click(A.rows[1], "RightButton")
    equal(sim.units.focus, opponent)
    equal(sim.units.target, bystander)
    sim:click(A.rows[1], "LeftButton")
    equal(sim.units.target, opponent)
  end)

  test("localized countdown alone activates before combat and ignores ordinary timers", function()
    local sim = setup(16001, {}, function(_, env) env.StartDuel = nil end)
    player(sim, "target", "Caster", 8)
    sim:event("START_TIMER", 0, 3, 3)
    sim:event("CHAT_MSG_SYSTEM", "Someone else's countdown: 3")
    assert(hidden(sim), "unrelated countdowns do not start duels")
    sim.env.DUEL_COUNTDOWN = "Début du duel : %1$d (secondes)."
    sim:event("CHAT_MSG_SYSTEM", "Début du duel : 3 (secondes).")
    local A = sim.ns.Arena
    assert(A.win:IsVisible())
    equal(A.rows[1].name.text, "Caster")
    equal(A.win.info.text, "Starts in 3")
    sim:event("UI_INFO_MESSAGE", 1, "Début du duel : 2 (secondes).")
    equal(A.win.info.text, "Starts in 2")
    sim:event("CHAT_MSG_SYSTEM", sim.env.DUEL_STARTED)
    equal(A.win.info.text, "Active")
    sim:event("DUEL_OUTOFBOUNDS")
    equal(A.win.info.text, "Out of bounds")
    sim:event("DUEL_INBOUNDS")
    equal(A.win.info.text, "Active")
  end)

  test("missing or secret observations never turn another player into the opponent", function()
    local sim = setup(16001)
    player(sim, "target", "Bystander", 8, 12)
    sim:event("DUEL_REQUESTED", "Sneak-Realm")
    local A, secret = sim.ns.Arena, { secret = true }
    equal(A.rows[1].name.text, "Sneak")
    equal(A.rows[1].right.text, "unseen")
    sim.units.nameplate1 = { name = secret, guid = secret, classID = 4 }
    sim:advance(0.3)
    equal(A.rows[1].right.text, "unseen")
    local opponent = player(sim, "nameplate1", "Sneak", 4, 72)
    sim:advance(0.3)
    equal(A.rows[1].right.text, "72%")
    countdown(sim)
    sim:setCombat(true)
    player(sim, "nameplate1", "Stranger", 1, 10)
    sim:advance(0.3)
    equal(A.rows[1].name.text, "Sneak", "remembered through nameplate reuse")
    equal(A.rows[1].right.text, "unseen")
    equal(A.rows[1].attrs.macrotext1, "/targetexact Sneak-Realm", "binding never follows the reused token")
    sim.units.nameplate2 = opponent
    sim:advance(0.3)
    equal(A.rows[1].right.text, "72%", "reacquire the same opponent on a new token")
    sim:click(A.rows[1])
    equal(sim.units.target, opponent)
  end)

  test("cancelled, declined and expired requests clear immediately or time out", function()
    local sim = setup(16001)
    player(sim, "target", "Sneak")
    sim.env.StartDuel("target")
    sim.env.CancelDuel()
    assert(hidden(sim), "local cancellation")
    sim:event("DUEL_REQUESTED", "Sneak-Realm")
    sim:event("DUEL_FINISHED")
    assert(hidden(sim), "declined challenge")
    sim:event("DUEL_REQUESTED", "Sneak-Realm")
    sim:event("CHAT_MSG_SYSTEM", sim.env.DUEL_CANCELLED)
    assert(hidden(sim), "localized cancellation")
    sim.env.StartDuel("target")
    sim:setCombat(true)
    sim:advance(61)
    assert(hidden(sim), "unrelated combat does not accept an expired request")
    sim:setCombat(false)
    sim.units.target = nil
    sim.env.StartDuel("target")
    assert(hidden(sim), "missing target is not an opponent named target")
    sim.env.StartDuel("Sneak\n/focus")
    assert(hidden(sim), "invalid names cannot enter secure macros")
  end)

  test("disabled, preview and consecutive duel lifecycles stay consistent", function()
    local sim = setup(16001, { arena = false })
    player(sim, "target", "Sneak")
    sim:event("DUEL_REQUESTED", "Sneak-Realm")
    assert(hidden(sim), "explicit off is respected")
    sim.ns.Core.SetFeature("arena", true)
    sim:advance(0.3)
    assert(not hidden(sim), "re-enable the current challenge")
    sim:event("DUEL_FINISHED")
    sim.ns.ArenaPreview()
    local A = sim.ns.Arena
    equal(A.shownCount, 1, "Forever previews a duel")
    sim:event("DUEL_REQUESTED", "Other-Realm")
    assert(not A.preview, "real challenge replaces samples")
    equal(A.rows[1].name.text, "Other")
    equal(A.rows[1].attrs.macrotext1, "/targetexact Other-Realm")
    sim.ns.ArenaPreview()
    assert(not A.preview, "preview cannot replace an actual duel")
    sim:event("PLAYER_ENTERING_WORLD")
    assert(hidden(sim), "world transition clears a pending duel")
    equal(A.duel, nil)
    sim:joinArena()
    equal(A.win.title.text, "ARENA")
    equal(A.rows[1].attrs.unit, "arena1", "arena token restored after duels")
    equal(A.rows[1].attrs.type1, "target")
    equal(A.rows[1].attrs.macrotext1, nil)
    assert(A.rows[2]:IsVisible() and A.rows[1].number:IsShown())
  end)

  test("late duel detection waits for protected frame changes without errors", function()
    local sim = setup(16001)
    player(sim, "target", "Sneak")
    sim:setCombat(true)
    countdown(sim)
    assert(hidden(sim), "cannot create protected rows during lockdown")
    sim:setCombat(false)
    assert(not hidden(sim), "deferred panel opens as soon as combat permits")
    equal(sim.ns.Arena.rows[1].name.text, "Sneak")
  end)

  test("a second duel in combat never exposes the previous opponent's binding", function()
    local sim = setup(16001)
    player(sim, "nameplate1", "Sneak")
    sim:event("DUEL_REQUESTED", "Sneak-Realm")
    countdown(sim)
    sim:setCombat(true)
    sim:event("DUEL_FINISHED")
    sim:event("DUEL_REQUESTED", "Other-Realm")
    countdown(sim)
    assert(hidden(sim), "old binding stays hidden until it can be replaced")
    sim:setCombat(false)
    assert(not hidden(sim))
    equal(sim.ns.Arena.rows[1].name.text, "Other")
    equal(sim.ns.Arena.rows[1].attrs.macrotext1, "/targetexact Other-Realm")
  end)

  test("duel casts and health accept restricted data when trinket APIs are unavailable", function()
    local secret, duration = { secret = true }, {}
    local sim = setup(16001, {}, function(_, env)
      env.C_PvP.RequestCrowdControlSpell = function() error("duels have no arena trinket API") end
      env.UnitCastingInfo = function(unit) if unit == "target" then return secret, nil, nil, secret, secret end end
      env.UnitCastingDuration = function() return duration end
    end)
    local opponent = player(sim, "target", "Caster", 8)
    opponent.health, opponent.maxHealth = secret, secret
    sim:event("DUEL_REQUESTED", "Caster-Realm")
    local row = sim.ns.Arena.rows[1]
    assert(row.cast:IsShown(), "cast displays restricted text")
    equal(row.castText.text, tostring(secret))
    assert(row.trinket:IsShown() and row.trinketState.text == "?")
    assert(not row.trinketCD:IsShown(), "no invented cooldown")
    sim:event("ARENA_COOLDOWNS_UPDATE")
  end)

  test("stealth alerts watch only the duel opponent and stop after the duel", function()
    local sim = setup(16001, { nearby = false })
    local opponent = player(sim, "nameplate1", "Sneak")
    local bystander = player(sim, "nameplate2", "Other")
    opponent.enemy, bystander.enemy = true, true
    sim:event("DUEL_REQUESTED", "Sneak-Realm")
    countdown(sim)
    sim:event("UNIT_SPELLCAST_SUCCEEDED", "nameplate2", "Cast-1", 1784)
    equal(#sim.sounds, 0, "nearby bystanders stay quiet")
    sim:event("UNIT_SPELLCAST_SUCCEEDED", "nameplate1", "Cast-2", 1784)
    sim:advance(0.2)
    equal(#sim.sounds, 1, "duel opponent triggers stealth cue")
    sim:event("DUEL_FINISHED")
    sim:advance(2)
    sim:event("UNIT_SPELLCAST_SUCCEEDED", "nameplate1", "Cast-3", 1784)
    sim:advance(0.2)
    equal(#sim.sounds, 1, "no duel alerts after finish")
  end)

  test("Cata duel combat logs ignore bystanders, including hostile players", function()
    local sim = setup(40402, { nearby = false })
    player(sim, "target", "Sneak")
    sim:event("DUEL_REQUESTED", "Sneak-Realm")
    countdown(sim)
    local function cast(name, flags)
      sim.combatEvent = { sim.now, "SPELL_CAST_SUCCESS", false, "Player-" .. name, name .. "-Realm", flags, 0,
        "Player-" .. name, name .. "-Realm", flags, 0, 1784 }
      sim:event("COMBAT_LOG_EVENT_UNFILTERED")
    end
    cast("Other", 0x548)
    equal(#sim.sounds, 0, "hostile bystander does not trigger duel alerts")
    cast("Sneak", 0x511)
    sim:advance(0.2)
    equal(#sim.sounds, 1, "the named duel opponent is watched regardless of faction")
  end)

  if addon == "HighgroundArena" then
    test("standby does not hook duel actions", function()
      local sim = setup(16001, {}, function(s) s.otherAddons = { Highground = true } end)
      player(sim, "target", "Sneak")
      sim.env.StartDuel("target")
      sim:event("DUEL_REQUESTED", "Sneak-Realm")
      assert(hidden(sim))
      equal(sim.ns.Arena.duel, nil)
    end)
  end
  t.finish("Duels: " .. t.tests .. " scenarios")
end
