local flow = dofile("../../tests/bounty_flow.lua")
return function(addon)
  local t = dofile("../../tools/harness.lua")(addon .. " bounty kills and sharing")
  local F = dofile("../HighgroundBounties/tests/public/fixture.lua")
  local runtime = dofile("../../tools/wowsim/battleground/runtime.lua")
  local function new(name, build, opts)
    opts = opts or {}
    opts.addon, opts.build, opts.client = addon, build, build == 40402 and "cata" or "retail"
    opts.runtime = function(client, saved, configure)
      return runtime(client, saved, function(s, e)
        configure(s, e)
        s.ruleset, s.screenshots = opts.ruleset or "PvE", 0
        e.Enum = e.Enum or {}; e.Enum.GameRule = { HardcoreRuleset = 10, RPRuleset = 11, PvPRuleset = 12 }
        e.C_GameRules = { IsGameRuleActive = function(rule)
          return rule == 10 and s.ruleset == "Hardcore" or rule == 11 and (s.ruleset == "RP" or s.ruleset == "RP-PvP")
            or rule == 12 and (s.ruleset == "PvP" or s.ruleset == "RP-PvP")
        end }
        e.Screenshot = function() s.screenshots = s.screenshots + 1 end
        e.COMBATLOG_HONORGAIN = "%s dies, honorable kill Rank: %s (Estimated Honor Points: %d)"
      end)
    end
    return F.new(name, opts)
  end
  local function click(button) button.scripts.OnClick(button) end
  local function kill(s, name)
    if s.ns.Caps.combatLog then
      s.env.CombatLogGetCurrentEventInfo = function()
        return 1, "PARTY_KILL", false, s.env.UnitGUID("player"), s.ns.Bounty.Me(), 0, 0, "Player-1-Enemy", name, 0x440
      end
      s:event("COMBAT_LOG_EVENT_UNFILTERED")
    else s:event("CHAT_MSG_COMBAT_HONOR_GAIN", name .. " dies, honorable kill Rank: Scout (Estimated Honor Points: 10)") end
  end

  for _, build in ipairs({ 40402, 120100, 16001 }) do
    t.test(build .. ": free, numeric and 1g bounties all capture kills; checkmark waits for success", function()
      for _, gold in ipairs({ "", "1", "1g" }) do
        local s = new("Hunter", build, { saved = { nearbyHistory = false, bountyAnnounce = false, bountyMinGold = 500 } })
        local B = s.ns.Bounty
        local w = B.Form.Open("Enemy-Realm", "personal")
        w.gold:SetText(gold); flow.save(w)
        t.equal(B.Personal()[B.Key("Enemy")].gold, gold == "" and 0 or 1, "amount accepted")
        kill(s, "Enemy-Realm")
        local proof = assert(B.Proof.win)
        assert(proof:IsShown() and not proof.check:IsShown(), "kill poster shows without a premature checkmark")
        t.equal(proof.title:GetText(), s.ns.Caps.combatLog and "KILLED" or "HONOR CREDIT", "evidence-specific title")
        s:event("SCREENSHOT_SUCCEEDED")
        assert(not proof.check:IsShown(), "an unrelated completion before our capture cannot confirm it")
        s:advance(0.3); t.equal(s.screenshots, 1, "one screenshot after poster renders")
        s:event("SCREENSHOT_SUCCEEDED")
        assert(proof.check:IsShown() and proof.item.screenshot, "only success confirms capture")
        assert(proof.captureStatus:GetText():find("saved successfully", 1, true))
        click(proof.proof)
        assert(not B.Exchange.copyWin:GetText():find("discord", 1, true), "private proof stays private")
        s:assertHealthy()
      end
    end)

    t.test(build .. ": capture failure and missing completion stay unchecked and can retry", function()
      local s = new("Hunter", build)
      local B = s.ns.Bounty
      B.Add("Enemy", "1g"); kill(s, "Enemy-Realm"); s:advance(0.3)
      local w = B.Proof.win
      s:event("SCREENSHOT_FAILED")
      assert(not w.check:IsShown() and w.retry:IsShown())
      click(w.retry); s:advance(0.3); t.equal(s.screenshots, 2, "retry calls Screenshot again")
      s:advance(9); assert(not w.check:IsShown() and w.captureStatus:GetText():find("not confirmed", 1, true))
      s:event("SCREENSHOT_SUCCEEDED"); assert(not w.check:IsShown(), "late unrelated success cannot certify timed out capture")
      click(w.retry); s:advance(0.3); s:event("SCREENSHOT_SUCCEEDED"); assert(w.check:IsShown())
      s:assertHealthy()
    end)

    t.test(build .. ": a previous attempt's timeout cannot fail a retry of the same kill", function()
      local s = new("Hunter", build)
      local B = s.ns.Bounty
      B.Add("Enemy", "1g"); kill(s, "Enemy-Realm"); s:advance(0.3)
      local w = B.Proof.win
      s:event("SCREENSHOT_FAILED")
      s:advance(5)
      click(w.retry); s:advance(0.3)
      local retry = B.Proof.capture.current
      s:advance(3.1) -- original request's deadline, before the retry's deadline
      assert(B.Proof.capture:IsCurrent(retry), "old timeout cannot consume retry")
      t.equal(w.item.captureState, "pending", "retry remains pending")
      assert(not w.close:IsEnabled() and not w.retry:IsShown(), "pending UI stays consistent")
      s:event("SCREENSHOT_SUCCEEDED")
      t.equal(w.item.captureState, "succeeded", "retry can succeed")
      assert(w.check:IsShown() and w.close:IsEnabled())
      s:advance(9)
      assert(w.check:IsShown(), "finished attempt's timer cannot undo success")
      s:assertHealthy()
    end)

    t.test(build .. ": unavailable screenshot API and closing a scheduled capture release the operation", function()
      local s = new("Hunter", build)
      local B = s.ns.Bounty
      B.Add("Enemy", "1g"); s.env.Screenshot = nil; kill(s, "Enemy-Realm")
      local w = B.Proof.win
      t.equal(w.item.captureState, "unavailable", "unsupported capture is explicit")
      assert(w.close:IsEnabled() and not w.retry:IsShown() and not B.Proof.active)
      assert(w.captureStatus:GetText():find("screenshot key", 1, true), "manual fallback explained")
      s.env.Screenshot = function() s.screenshots = s.screenshots + 1 end
      B.Proof.Capture(w.item)
      local item, attempt = w.item, B.Proof.capture.current
      w:Hide(); s:advance(0.3)
      t.equal(s.screenshots, 0, "closed poster's scheduled screenshot never runs")
      t.equal(item.captureState, "cancelled", "close retires item")
      assert(not item.capturing and not item.requested and not B.Proof.capture:IsCurrent(attempt))
      s:event("SCREENSHOT_SUCCEEDED")
      assert(not item.screenshot, "cancelled attempt stays unconfirmed")
      s:assertHealthy()
    end)

    t.test(build .. ": creator sets count and preferences and funds the whole hunt", function()
      local s = new("Poster", build, { gold = 2, saved = { bountyRequireGold = true } })
      local B = s.ns.Bounty
      local w = B.Form.Open("Enemy", "public")
      w.gold:SetText("1g"); w.kills:SetText("3"); click(w.methodButtons.fall); click(w.methodButtons.wand)
      flow.save(w); assert(w.error:GetText():find("Insufficient", 1, true))
      s.money = 50000; s:event("PLAYER_MONEY"); flow.save(w)
      local p = assert(B.Public.Own("Enemy"))
      t.equal(p.killsRequired, 3, "count saved")
      t.equal(p.killMethods, "fall.wand", "button choices saved")
      t.equal(B.Public.Reserved(), 30000, "all three gold reserved")
      assert(not B.Exchange.copyWin or not B.Exchange.copyWin:IsShown(), "publishing returns to the board without a sharing chore")
      assert(B.Exchange.Show(p, "global"):GetText():find("HGB2%-GLOBAL:"), "offline export remains optional")
      B.Form.Open("Enemy", "public"); t.equal(w.kills:GetText(), "3", "edit keeps count")
      assert(w.selectedMethods.fall and w.selectedMethods.wand)
      s:assertHealthy()
    end)

    t.test(build .. ": repeated kills pay per approval, deduplicate and stop at the requested count", function()
      local a, h = new("Poster", build), new("Hunter", build)
      local P, H = a.ns.Bounty.Public, h.ns.Bounty.Public
      local p = assert(P.Post("Enemy", 1, "2h", "", nil, { killsRequired = 3, killMethods = "fall" }))
      P.QueueOffer(p, h.ns.Bounty.Me()); F.deliver(a, h)
      for n = 1, 3 do
        local at = H.Now()
        assert(H.Claim("Enemy", true, at)); assert(H.Claim("Enemy", true, at))
        t.equal(F.count(H.Data().claims), n, "duplicate event is one claim")
        F.deliver(h, a)
        local c
        for _, item in pairs(P.Data().claims) do if item.killedAt == at then c = item end end
        assert(c and P.ChangeClaim(c, "approved"))
        t.equal(p.killsAwarded, n, "accepted kill count")
        assert(P.ChangeClaim(c, "paid")); F.deliver(a, h)
        t.equal(P.Reserved(), (3 - n) * 10000, "only unfilled kills remain reserved")
        t.equal(p.state, n == 3 and "paid" or "active", "paying an early kill keeps bounty active")
        a:advance(10); h:advance(10)
      end
      assert(not H.Claim("Enemy"), "completed bounty rejects another kill")
      a:assertHealthy(); h:assertHealthy()
    end)

    t.test(build .. ": offline global import preserves terms without trusting funding or identity", function()
      local a, h = new("Poster", build), new("Hunter", build, { saved = {} })
      local B, HB = a.ns.Bounty, h.ns.Bounty
      local p = assert(B.Public.Post("Enemy", 1, "2h", "Optional bonus by agreement", nil, { killsRequired = 3, killMethods = "fall.drown" }))
      local code = assert(B.Exchange.Encode(p, "global"))
      local packet = assert(HB.Exchange.Decode(code))
      local imported = assert(HB.Exchange.Import(packet))
      assert(imported.imported and HB.Public.Receiving())
      t.equal(imported.funds, "unknown", "offline funding is unverified")
      t.equal(imported.killsRequired, 3, "offline count preserved")
      assert(not HB.Public.CanManage(imported) and not HB.Public.Publishing(), "import does not become creator or broadcaster")
      assert(HB.Find("Enemy", true), "imported low-gold bounty remains usable for alerts")
      kill(h, "Enemy-Realm"); h:advance(0.3); h:event("SCREENSHOT_SUCCEEDED")
      local proof = HB.Proof.win
      assert(proof.item.global and proof.check:IsShown())
      click(proof.proof)
      assert(HB.Exchange.copyWin:GetText():find("discord", 1, true), "global proof points to Discord")
      assert(not HB.Exchange.Import(packet), "same contribution cannot be duplicated")
      B.Public.QueueOffer(p, HB.Me()); F.deliver(a, h)
      assert(not HB.Public.Data().offers[p.id].imported, "real creator update replaces offline assertions")
      a:assertHealthy(); h:assertHealthy()
    end)

    t.test(build .. ": private and guild export codes preserve audience and never offer Discord posting", function()
      local a, h = new("Poster", build, { guild = "Guild", rank = 0 }), new("Hunter", build, { guild = "Guild" })
      local B, HB = a.ns.Bounty, h.ns.Bounty
      local b = assert(B.Add("Enemy", 1, "", { killsRequired = 2, killMethods = "ambush" }))
      for _, audience in ipairs({ "private", "guild" }) do
        if audience == "guild" then b = assert(B.Submit("Enemy")) end
        local code = assert(B.Exchange.Encode(b, audience))
        assert(code:find("HGB[23]%-" .. audience:upper() .. ":"))
        local data = assert(HB.Exchange.Decode(code))
        local copy = assert(HB.Exchange.Import(data))
        t.equal(copy.importAudience, audience, "origin audience retained")
        t.equal(copy.state, "personal", "import cannot grant guild approval")
        assert(not next(HB.Guild()), "no automatic guild publication")
        local window = B.Exchange.Show(b, audience)
        assert(not window:GetText():find("https://discord", 1, true), "no Discord link for private/guild exports")
        local chat = assert(B.Share.Encode(b))
        t.equal(assert(HB.Share.Decode(chat)).importAudience, audience, "chat links label audience too")
      end
      a:assertHealthy(); h:assertHealthy()
    end)
  end

  t.test("guild multi-kill reports, settlement replay and funding stay scoped to each death", function()
    local a = new("Poster", 16001, { guild = "Guild", rank = 0 })
    local h = new("Hunter", 16001, { guild = "Guild", roster = { { "Poster-Realm", 0 } } })
    local B, H = a.ns.Bounty, h.ns.Bounty
    assert(B.Add("Enemy", 1, "", { killsRequired = 3, killMethods = "fall.control.wand" }))
    local b = assert(B.Submit("Enemy"))
    H.Receive(B.Scope.Wrap(B.Encode(b)), B.Me())
    t.equal(H.Guild()[H.Key("Enemy")].killsRequired, 3, "guild terms synchronized")
    for n = 1, 3 do
      a:advance(10); h:advance(10)
      local at = h.env.time()
      assert(H.Claim("Enemy", true, at))
      B.Receive(B.Scope.Wrap("4:K,Enemy-Realm," .. at .. "," .. b.at), H.Me())
      local claim = B.Ledger.All()[1]
      assert(B.Ledger.Change(claim, "approved"))
      local wire = B.Ledger.Encode(claim)
      H.Receive(B.Scope.Wrap(wire), B.Me())
      t.equal(H.Ledger.All()[1].state, "approved", "only this kill is approved")
      assert(B.Ledger.Change(claim, "paid"))
      H.Receive(B.Scope.Wrap(B.Ledger.Encode(claim)), B.Me())
      t.equal(H.Ledger.All()[1].state, "paid", "payment follows the correct death")
      t.equal(B.Public.Reserved(), (3 - n) * 10000, "guild budget releases paid slots")
    end
    t.equal(B.Ledger.Progress(b), 3, "three guild deaths recorded")
    local extra = B.Ledger.Record(b, "Another-Realm", a.env.time() + 1)
    assert(not extra, "no fourth guild report after completion")
    local late = new("Latecomer", 16001, { guild = "Guild", roster = { { "Poster-Realm", 0 } } })
    late.now = a.now + 20
    late.ns.Bounty.Receive(B.Scope.Wrap(B.Encode(b)), B.Me())
    for _, c in ipairs(B.Ledger.All()) do late.ns.Bounty.Receive(B.Scope.Wrap(B.Ledger.Encode(c)), B.Me()) end
    t.equal(late.ns.Bounty.Ledger.Progress(late.ns.Bounty.Guild()[B.Key("Enemy")]), 3, "late sync restores settled kill count")
    a:assertHealthy(); h:assertHealthy(); late:assertHealthy()
  end)

  t.test("imports reject malformed terms, expired offers and local authority fields", function()
    local a, h = new("Poster", 16001), new("Hunter", 16001)
    local B, H = a.ns.Bounty, h.ns.Bounty
    local offer = assert(B.Public.Post("Enemy", 1, "5m", "", nil, { killsRequired = 2, killMethods = "drown" }))
    local code = assert(B.Exchange.Encode(offer, "global"))
    local function tamper(change)
      local kind, encoded = code:match("^(HGB2%-GLOBAL:)(.+)$")
      local packet = assert(a.ns.Codec.Unpack(a.ns.Codec.Decode64(encoded)))
      change(packet)
      return kind .. a.ns.Codec.Encode64(a.ns.Codec.Pack(packet))
    end
    assert(not H.Exchange.Decode(tamper(function(p) p.bounty.killsRequired = 0 end)))
    assert(not H.Exchange.Decode(tamper(function(p) p.bounty.killMethods = "fall.fake" end)))
    assert(not H.Exchange.Decode(tamper(function(p) p.audience = "guild" end)))
    local packet = assert(H.Exchange.Decode(tamper(function(p)
      p.bounty.walletScope, p.bounty.guild, p.bounty.history = "fake", "FakeGuild", { fake = true }
    end)))
    assert(not packet.bounty.walletScope and not packet.bounty.guild and not packet.bounty.history, "local authority fields discarded")
    h.now = h.now + 301
    assert(not H.Exchange.Decode(code), "expired snapshot cannot reopen bounty")
    assert(not H.Exchange.Import(packet), "expiry rechecked after review")
  end)

  t.test("two rapid kills each capture once and unrelated screenshot events do not certify another kill", function()
    local s = new("Hunter", 16001)
    local B = s.ns.Bounty
    B.Add("First", 1); B.Add("Second", 1)
    kill(s, "First-Realm"); kill(s, "First-Realm"); kill(s, "Second-Realm")
    s:advance(0.3); t.equal(s.screenshots, 1, "duplicate first event not recaptured")
    s:event("SCREENSHOT_SUCCEEDED")
    local w = B.Proof.win
    t.equal(w.item.bounty.name, "Second-Realm", "second target receives its own poster")
    assert(not w.check:IsShown(), "first screenshot does not certify second capture")
    s:advance(0.3); t.equal(s.screenshots, 2, "second capture requested")
    s:event("SCREENSHOT_SUCCEEDED"); assert(w.check:IsShown())
    s:assertHealthy()
  end)

  t.test("import review displays the full offer, protects replacement, and rechecks expiry", function()
    local a, h = new("Poster", 16001), new("Hunter", 16001)
    local B, H = a.ns.Bounty, h.ns.Bounty
    local p = assert(B.Public.Post("Enemy", 1, "5m", "Bonus only by agreement", nil, { killsRequired = 3, killMethods = "fall.wand" }))
    local code = assert(B.Exchange.Encode(p, "global"))
    local w = H.Exchange.OpenImport(code)
    click(w.actions.review)
    for _, detail in ipairs({ "GLOBAL", "Poster", "3 kills", "1g per approved kill", "Fall damage", "Wand finish", "Bonus only by agreement", "Expires:" }) do
      assert(w:GetText():find(detail, 1, true), "review contains " .. detail)
    end
    assert(not next(H.Public.Data().offers), "review alone imports nothing")
    h.now = h.now + 301
    click(w.actions.review)
    assert(w:IsShown() and w.status:GetText():find("expired", 1, true), "expiry checked at confirmation")
    a.now = h.now -- The poster also observes the original offer expiring.
    local private = assert(B.Add("Enemy", 1, "Keep private"))
    local privateCode = assert(B.Exchange.Encode(private, "private"))
    H.Add("Enemy", 2, "Original")
    w = H.Exchange.OpenImport(privateCode); click(w.actions.review)
    assert(w:GetText():find("REPLACES YOUR PRIVATE", 1, true))
    H.Add("Enemy", 5, "Changed during review")
    click(w.actions.review)
    t.equal(H.Personal()[H.Key("Enemy")].gold, 5, "changed local bounty needs another confirmation")
    assert(w:GetText():find("Changed during review", 1, true))
    click(w.actions.review)
    t.equal(H.Personal()[H.Key("Enemy")].gold, 1, "confirmed replacement imports")
    h:assertHealthy()
  end)

  t.test("the shared data migration preserves old offers and payment obligations", function()
    local a = new("Poster", 16001)
    local B = a.ns.Bounty
    local p = assert(B.Public.Post("Enemy", 1))
    local old = B.Public.Copy(a.env.HighgroundBountyNetworkDB)
    old.version = 1
    local again = new("Poster", 16001, { network = old })
    t.equal(again.env.HighgroundBountyNetworkDB.version, 3, "new schema protects completion authority from older clients")
    t.equal(again.ns.Bounty.Public.Data().offers[p.id].gold, 1, "existing offer retained")
    t.equal(again.env.HighgroundBountyNetworkDB.id, B.Public.db.id, "contributor identity retained")
    again:assertHealthy()
  end)

  t.test("Forever imports and proof links respect ruleset; named honor does not guess a target", function()
    local a, h = new("Poster", 16001), new("Hunter", 16001, { ruleset = "RP-PvP" })
    local p = assert(a.ns.Bounty.Public.Post("Enemy", 1))
    local code = assert(a.ns.Bounty.Exchange.Encode(p, "global"))
    assert(not h.ns.Bounty.Exchange.Decode(code), "cross-ruleset import rejected")
    local B = h.ns.Bounty
    assert(B.Exchange.URL("proof"):find(B.Exchange.channels["RP-PvP"].proof, 1, true))
    B.Add("Enemy Longname", 1)
    kill(h, "Enemy-Realm"); assert(not B.Proof.win, "first name alone does not prove exact identity")
    h:event("CHAT_MSG_COMBAT_HONOR_GAIN", { secret = true }); assert(not B.Proof.win)
    kill(h, "Enemy Longname-Realm"); assert(B.Proof.win)
    h.ruleset = "PvE"; h:event("PLAYER_ENTERING_WORLD")
    assert(not B.Proof.win:IsShown() and not B.Proof.active, "switching ruleset clears proof and pending screenshot")
    h:event("SCREENSHOT_SUCCEEDED"); assert(not B.Proof.win.check:IsShown())
  end)
  t.finish("Bounty kills, terms and exports: " .. t.tests .. " scenarios")
end
