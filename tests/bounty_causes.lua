return function(addon)
  local t = dofile("../../tools/harness.lua")(addon .. " killing blows")
  local F = dofile("../HighgroundBounties/tests/public/fixture.lua")
  local runtime = dofile("../../tools/wowsim/battleground/runtime.lua")
  local function new(name, opts)
    opts = opts or {}
    opts.addon, opts.client, opts.epoch = addon, opts.client or "cata", 0
    opts.runtime = runtime
    local s = F.new(name, opts)
    s.env.Screenshot = function() end
    return s
  end
  local function event(s, sub, payload, source, name)
    s.env.CombatLogGetCurrentEventInfo = function()
      return s.now, sub, false, source or s.env.UnitGUID("player"), "Hunter", 0, 0,
        "Player-1-Enemy", name or "Enemy-Realm", 0x440, 0, unpack(payload or {})
    end
    s:event("COMBAT_LOG_EVENT_UNFILTERED")
  end
  local function finish(s) s:advance(0.3); s:event("SCREENSHOT_SUCCEEDED") end

  t.test("fatal damage records spell IDs, melee, periodic damage, pets and environment", function()
    local cases = {
      { "SPELL_DAMAGE", { 5308, "Execute", 1, 300, 0 }, "Execute" },
      { "SPELL_PERIODIC_DAMAGE", { 589, "Shadow Word: Pain", 32, 50, 3 }, "Shadow Word: Pain (damage over time)" },
      { "RANGE_DAMAGE", { 5019, "Shoot", 1, 90, 2 }, "Shoot" },
      { "DAMAGE_SHIELD", { 467, "Thorns", 8, 40, 0 }, "Thorns (damage shield)" },
      { "DAMAGE_SPLIT", { 1234, "Shared damage", 1, 40, 1 }, "Shared damage" },
      { "SPELL_INSTAKILL", { 1234, "Instant death", 1 }, "Instant death" },
      { "SWING_DAMAGE", { 90, 0 }, "Melee attack" },
      { "SPELL_DAMAGE", { 17253, "Bite", 1, 50, 0 }, "Bite (pet)", "Pet-1-Hunter" },
      { "ENVIRONMENTAL_DAMAGE", { "FALLING", 500, 20 }, "Fall damage", "Environment" },
      { "ENVIRONMENTAL_DAMAGE", { "DROWNING", 500, 0 }, "Drowning", "Environment" },
    }
    for _, case in ipairs(cases) do
      local s = new("Hunter")
      local B = s.ns.Bounty
      s.units.pet = { guid = "Pet-1-Hunter" }
      B.Add("Enemy", 1)
      event(s, case[1], case[2], case[4]); event(s, "PARTY_KILL")
      finish(s)
      local c = assert(B.Ledger.All()[1])
      t.equal(B.Kills.CauseText(c.cause), case[3], "recorded cause")
      t.equal(#B.Kills.History(), 1, "damage and kill credit are one death")
      assert(B.Proof.win.detail:GetText():find(case[3], 1, true), "proof names cause")
      assert(B.Ledger.Entry(c).detail:find(case[3], 1, true), "history names cause")
      assert(B.Exchange.Proof(B.Proof.win.item):GetText():find(case[3], 1, true), "copyable proof names cause")
      if c.cause.spellName then t.equal(c.cause.spellID, case[2][1], "spell identity saved") end
      s:assertHealthy()
    end
  end)

  t.test("nonfatal damage cannot supply a guessed killing blow or claim an environmental death", function()
    local s = new("Hunter")
    local B = s.ns.Bounty
    B.Add("Enemy", 1)
    event(s, "SPELL_DAMAGE", { 5308, "Execute", 1, 30, -1 })
    t.equal(#B.Kills.History(), 0, "ordinary damage is not a kill")
    event(s, "PARTY_KILL")
    t.equal(B.Ledger.All()[1].cause, nil, "last cast is not fatal evidence")
    assert(B.Proof.win.detail:GetText():find("Cause unavailable", 1, true))
    finish(s); s:advance(10)
    event(s, "ENVIRONMENTAL_DAMAGE", { "FALLING", 500, 0 }, "Environment")
    finish(s)
    t.equal(#B.Kills.History(), 2, "observed fall is retained")
    t.equal(#B.Ledger.All(), 1, "a nearby fall does not grant hunter credit")
    t.equal(B.Proof.win.item.evidence, "observed death", "observation is labelled honestly")
    s:assertHealthy()
  end)

  t.test("private repeat kills update both posters, stop at the goal and retain each cause on reload", function()
    local s = new("Hunter")
    local B = s.ns.Bounty
    local b = assert(B.Add("Enemy", 1, "", { killsRequired = 2 }))
    B.Poster.Show(b, "Test zone")
    local popup = assert(B.Poster.win)
    for n = 1, 3 do
      event(s, "SPELL_DAMAGE", { 5308, "Execute", 1, 100, 0 }); event(s, "PARTY_KILL")
      finish(s)
      assert(B.Proof.win.killProgress:GetText():find(math.min(n, 2) .. "/2 kills recorded", 1, true))
      if n == 1 then assert(popup.killProgress:GetText():find("1/2", 1, true), "open wanted poster updates immediately") end
      s:advance(10)
    end
    t.equal(#B.Ledger.All(), 2, "requested reward count is capped")
    t.equal(#B.Kills.History(), 3, "later kills remain in private history")
    assert(B.Proof.win.killProgress:GetText():find("Complete", 1, true))
    B.Details.Open(B.BoardModel.Rows("mine")[1])
    assert(B.Details.win.cards[1].detail:GetText():find("Execute", 1, true))
    local reload = new("Hunter", { saved = B.Public.Copy(s.ns.Core.db) })
    t.equal(#reload.ns.Bounty.Kills.History(), 3, "history survives reload")
    t.equal(reload.ns.Bounty.Ledger.All()[1].cause.spellID, 5308, "claim retains spell identity")
    s:assertHealthy(); reload:assertHealthy()
  end)

  t.test("shared causes survive transport and approval; progress distinguishes pending from accepted kills", function()
    local a, h = new("Poster"), new("Hunter")
    local B, H = a.ns.Bounty, h.ns.Bounty
    local p = assert(B.Public.Post("Enemy", 1, "2h", "", nil, { killsRequired = 2 }))
    B.Public.QueueOffer(p, H.Me())
    F.deliver(a, h)
    for n = 1, 2 do
      event(h, "SPELL_DAMAGE", { 5308, "Execute", 1, 100, 0 }); event(h, "PARTY_KILL")
      finish(h); F.deliver(h, a)
      local c
      for _, report in pairs(B.Public.Data().claims) do if report.state == "claimed" then c = report end end
      assert(c and c.cause.spellID == 5308, "poster receives fatal spell")
      assert(H.Proof.win.killProgress:GetText():find("pending review", 1, true))
      local forged = B.Public.Copy(c); forged.cause.spellName = "Different spell"
      assert(not B.Public.ReceiveClaim(forged, H.Me()), "cause is immutable on retries")
      assert(B.Public.ChangeClaim(c, "approved")); F.deliver(a, h)
      assert(H.Proof.win.killProgress:GetText():find(n .. "/2 kills approved", 1, true), "approval updates open proof")
      assert(B.Public.ChangeClaim(c, "paid")); F.deliver(a, h)
      a:advance(35); h:advance(35)
    end
    assert(H.Proof.win.killProgress:GetText():find("Complete", 1, true))
    assert(not H.Public.Claim("Enemy"), "completed contribution cannot pay again")
    a:assertHealthy(); h:assertHealthy()
  end)

  t.test("guild reports and settlement replay preserve fatal evidence", function()
    local a = new("Poster", { guild = "Guild", rank = 0 })
    local h = new("Hunter", { guild = "Guild", roster = { { "Poster-Realm", 0 } } })
    local B, H = a.ns.Bounty, h.ns.Bounty
    B.Add("Enemy", 1, "", { killsRequired = 2 }); assert(B.Submit("Enemy"))
    local b = assert(B.Guild()[B.Key("Enemy")])
    H.Receive(B.Encode(b), B.Me())
    event(h, "SPELL_DAMAGE", { 5308, "Execute", 1, 100, 0 }); finish(h)
    while #H.queue > 0 do H.Flush() end
    F.flush(h)
    F.deliver(h, a, h.sent)
    local c = assert(B.Ledger.All()[1])
    t.equal(c.evidence, "observed killing blow", "guild evidence retained")
    t.equal(c.cause.spellID, 5308, "guild spell retained")
    assert(B.Ledger.Change(c, "approved")); H.Receive(B.Ledger.Encode(c), B.Me())
    assert(H.Proof.win.killProgress:GetText():find("1/2 kills approved", 1, true), "guild settlement updates proof")
    local late = new("Late", { guild = "Guild", roster = { { "Poster-Realm", 0 } } })
    late.ns.Bounty.Receive(B.Encode(b), B.Me()); late.ns.Bounty.Receive(B.Ledger.Encode(c), B.Me())
    t.equal(late.ns.Bounty.Ledger.All()[1].cause.spellID, 5308, "replay carries cause to late members")
    a:assertHealthy(); h:assertHealthy(); late:assertHealthy()
  end)

  t.test("malformed causes are rejected and restricted clients retain an explicit unknown cause", function()
    local s = new("Hunter", { client = "retail", build = 16001 })
    local B = s.ns.Bounty
    for _, bad in ipairs({ "Execute", { event = "made-up" }, { event = "SPELL_DAMAGE", spellID = -1, spellName = "Execute" },
      { event = "SPELL_DAMAGE", spellID = 5308, spellName = "|Hlink" }, { event = "SWING_DAMAGE", extra = {} } }) do
      assert(not B.Kills.ValidCause(bad))
    end
    B.Add("Enemy", 1)
    B.Kills.Honor(nil, "Enemy-Realm dies, honorable kill")
    assert(B.Proof.win and B.Proof.win.detail:GetText():find("Cause unavailable", 1, true))
    t.equal(B.Kills.History()[1].evidence, "honor credit", "assist is not upgraded to a confirmed killing blow")
    t.equal(B.Ledger.All()[1].cause, nil, "no invented spell on restricted clients")
    s:assertHealthy()
  end)
  t.test("a detected kill reports imported private rewards and retries without global opt-in", function()
    local a, h = new("Poster", { saved = {} }), new("Hunter", { saved = {} })
    local B, H = a.ns.Bounty, h.ns.Bounty
    local original = assert(B.Add("Enemy", 50, "", { killsRequired = 2 }))
    local code = assert(B.Exchange.Encode(original, "private"))
    assert(H.Exchange.Import(assert(H.Exchange.Decode(code))))
    event(h, "SPELL_DAMAGE", { 5308, "Execute", 1, 100, 0 }); finish(h)
    local localClaim = assert(H.Ledger.All()[1])
    assert(H.Kills.Confirmed(localClaim), "hunter's combat log confirms the killing blow")
    assert(localClaim.state == "claimed", "kill confirmation does not approve someone else's reward")
    F.flush(h) -- The poster was offline for the first delivery.
    H.Public.RetryClaims(); F.deliver(h, a)
    local c = assert(B.Ledger.All()[1])
    t.equal(c.claimant, H.Me(), "original poster receives the automatic report")
    t.equal(c.cause.spellID, 5308, "evidence reaches the private reviewer")
    assert(not B.Kills.Confirmed(c), "a remote report is not a locally witnessed kill")
    H.Public.RetryClaims(); F.deliver(h, a)
    t.equal(#B.Ledger.All(), 1, "retry cannot duplicate the death")
    assert(not H.Public.Receiving() and not H.Public.Publishing(), "private hunt stays private")
    a:assertHealthy(); h:assertHealthy()
  end)

  t.test("one kill reaches shared, guild and personal rewards without duplicate manual reporting", function()
    local a = new("Poster")
    local g = new("GuildPoster", { guild = "Guild", rank = 0 })
    local h = new("Hunter", { guild = "Guild", roster = { { "GuildPoster-Realm", 0 } } })
    local H = h.ns.Bounty
    local shared = assert(a.ns.Bounty.Public.Post("Enemy", 10, "2h", "", nil, { killsRequired = 3 }))
    a.ns.Bounty.Public.QueueOffer(shared, H.Me()); F.deliver(a, h)
    assert(g.ns.Bounty.Add("Enemy", 20, "", { killsRequired = 3 }))
    local guild = assert(g.ns.Bounty.Submit("Enemy"))
    H.Receive(g.ns.Bounty.Encode(guild), g.ns.Bounty.Me())
    assert(H.Add("Enemy", 0, "", { killsRequired = 3 }))
    event(h, "SPELL_DAMAGE", { 5308, "Execute", 1, 100, 0 }); finish(h)
    t.equal(F.count(H.Public.Data().claims), 1, "shared reward reported")
    t.equal(#H.Ledger.All(), 2, "guild reward and private history both recorded")
    local row = H.BoardModel.Rows("mine")[1]
    t.equal(H.BoardActions.Primary(row), "View report", "report replaces the manual action")
    h:advance(10)
    assert(H.BoardActions.Report(row)); assert(H.BoardActions.Report(row))
    t.equal(F.count(H.Public.Data().claims), 1, "viewing the report cannot create a second claim")
    t.equal(#H.Ledger.All(), 2, "private and guild reports also remain unique")
    assert(H.Ledger.win.entry and H.Ledger.win.entry.claim.name == "Enemy-Realm", "opens this target's report")
    while #H.queue > 0 do H.Flush() end
    F.deliver(h, g, h.sent)
    t.equal(#g.ns.Bounty.Ledger.All(), 1, "guild poster receives automatic evidence")
    F.deliver(h, a, h.sent)
    local A, claim = a.ns.Bounty, assert(F.claim(a))
    t.equal(A.BoardActions.Primary(A.BoardModel.Rows("mine")[1]), "Review report", "poster sees the review action")
    assert(A.Public.ChangeClaim(claim, "approved"))
    local own = A.BoardModel.Rows("mine")[1]
    t.equal(A.BoardActions.Primary(own), "Record payment", "approval makes payment the next action")
    A.BoardActions.Run(nil, own)
    assert(A.Ledger.win.actions[2]:IsEnabled(), "opens the approved report ready to record manual payment")
    a:assertHealthy(); g:assertHealthy(); h:assertHealthy()
  end)

  t.test("matching the name cannot claim a contribution tied to a different target GUID", function()
    local a, b, h = new("First"), new("Second"), new("Hunter")
    local p = assert(a.ns.Bounty.Public.Post("Enemy", 10))
    local q = assert(b.ns.Bounty.Public.Post("Enemy", 20))
    F.flush(a); F.flush(b)
    p.guid, q.guid = "Player-1-SomeoneElse", "Player-1-Enemy"
    a.ns.Bounty.Public.QueueOffer(p, h.ns.Bounty.Me()); b.ns.Bounty.Public.QueueOffer(q, h.ns.Bounty.Me())
    F.deliver(a, h); F.deliver(b, h)
    event(h, "SPELL_DAMAGE", { 5308, "Execute", 1, 100, 0 }); finish(h)
    local H = h.ns.Bounty
    t.equal(F.count(H.Public.Data().claims), 1, "only the exact identity is claimed")
    t.equal(F.claim(h).pledge, q.id, "matching contribution")
    t.equal(#H.Proof.win.item.bounty.contributions, 1, "proof excludes the different target")
    t.equal(H.Proof.win.details:GetText(), "View report", "one next action after detection")
    H.Proof.win.details:Click("LeftButton")
    t.equal(H.Ledger.win.entry.claim.id, F.claim(h).id, "popup opens the corresponding report")
    assert(H.Ledger.win.claimProfile.fields[3].value:GetText():find("confirmed by your combat log", 1, true))
    h.now = h.now + H.Public.CLAIM_WINDOW + 1; H.Ledger.win:Refresh()
    assert(H.Ledger.win.claimProfile.next:GetText():find("window closed", 1, true), "unacknowledged delivery does not silently wait forever")
    h:assertHealthy()
  end)

  t.test("honor credit and screenshots never upgrade assists to confirmed killing blows", function()
    local s = new("Hunter", { client = "retail", build = 16001 })
    local B = s.ns.Bounty
    B.Add("Enemy", 0)
    B.Kills.Honor(nil, "Enemy-Realm dies, honorable kill"); finish(s)
    local c, w = B.Ledger.All()[1], B.Proof.win
    assert(w.check:IsShown() and w.captureStatus:GetText():find("saved successfully", 1, true))
    assert(not B.Kills.Confirmed(c) and w.status:GetText():find("UNCONFIRMED", 1, true))
    w.details:Click("LeftButton")
    assert(B.Ledger.win.claimProfile.fields[3].value:GetText():find("may include assists", 1, true))
    for _, button in ipairs(B.Ledger.win.actions) do assert(not button:IsEnabled(), "private history needs no self-payment") end
    s:assertHealthy()
  end)
  t.finish("Killing blows and live progress: " .. t.tests .. " scenarios")
end
