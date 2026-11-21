local flow = dofile("../../tests/bounty_flow.lua")
-- Real saved variables, funding paths, creation UI and bag hover hooks.
return function(addon)
  local t = dofile("../../tools/harness.lua")(addon .. " account gold")
  local equal = t.equal
  t.equal = function(a, b, why) return equal(a, b, why or "value") end
  local F = dofile("../HighgroundBounties/tests/public/fixture.lua")
  local runtime = dofile("../../tools/wowsim/battleground/runtime.lua")
  local function new(name, build, opts)
    opts = opts or {}
    opts.addon, opts.build, opts.client = addon, build, build == 40402 and "cata" or "retail"
    opts.runtime = function(client, saved, configure)
      return runtime(client, saved, function(s, e)
        configure(s, e)
        s.ruleset = opts.ruleset or "PvE"
        s.regionalNames = opts.regionalNames
        if opts.missingRealm then e.GetNormalizedRealmName = nil end
        e.Enum = e.Enum or {}
        e.Enum.GameRule = { HardcoreRuleset = 10, RPRuleset = 11, PvPRuleset = 12 }
        e.C_GameRules = { IsGameRuleActive = function(rule)
          return rule == 10 and s.ruleset == "Hardcore" or rule == 11 and (s.ruleset == "RP" or s.ruleset == "RP-PvP")
            or rule == 12 and (s.ruleset == "PvP" or s.ruleset == "RP-PvP")
        end }
        if opts.faction then e.UnitFactionGroup = function() return opts.faction end end
      end)
    end
    return F.new(name, opts)
  end
  local function click(b) b.scripts.OnClick(b) end
  local function fire(frame, event)
    if frame.scripts[event] then frame.scripts[event](frame) end
    for _, hook in ipairs(frame.hooks[event] or {}) do hook(frame) end
  end
  local function switch(s, rule) s.ruleset = rule; s:event("PLAYER_ENTERING_WORLD") end
  local function Copy(s) return s.ns.Bounty.Public.Copy(s.env.HighgroundBountyNetworkDB) end

  for _, build in ipairs({ 40402, 120100, 16001 }) do
    t.test(build .. ": tracking defaults on; the requirement defaults off and warns as you type", function()
      local s = new("Alice", build, { gold = 2, saved = {} })
      local B = s.ns.Bounty
      assert(B.Gold.Enabled() and not B.Gold.Required())
      local w = B.Form.Open("Enemy-Other", "public")
      w.gold:SetText("500")
      assert(w.goldWarning:GetText():find("Insufficient gold", 1, true))
      assert(w.goldWarning:GetText():find("still create", 1, true))
      assert(w.action:IsEnabled())
      flow.save(w)
      local p = assert(B.Public.Own("Enemy-Other"))
      t.equal(p.gold, 500); t.equal(p.funds, "insufficient", "no false funding report")
      t.equal(B.Public.Find(p.name).gold, 0, "unfunded reward is not advertised as funded")
      assert(F.said(s, "Insufficient gold") > 0)
      local other = assert(B.Form.Open("Other-Other", "personal"))
      other.gold:SetText("500"); flow.save(other)
      assert(B.Personal()[B.Key("Other-Other")], "default also permits private rewards")
    end)

    t.test(build .. ": opting into enforcement blocks all creation paths and unreadable balances", function()
      local s = new("Alice", build, { gold = 2, guild = "Guild", saved = { bountyRequireGold = true, bountyPublish = true } })
      local B = s.ns.Bounty
      t.equal(B.Public.Post("Enemy", 500), nil)
      t.equal(B.Add("Private", 500), nil)
      local private = assert(B.Add("Private", 2))
      s.money = 0; s:event("PLAYER_MONEY")
      t.equal(B.Submit(private.name), nil, "guild checks again at publication")
      local w = B.Form.Open("Enemy", "public"); w.gold:SetText("500"); flow.save(w)
      assert(w:IsShown() and w.error:GetText():find("Insufficient", 1, true))
      w.gold:SetText("1"); t.equal(w.error:GetText(), "")
      s.money = nil; s:event("PLAYER_MONEY")
      t.equal(B.Public.Post("Unknown", 1), nil)
      s.ns.Core.SetOption("bountyRequireGold", false)
      t.equal(assert(B.Public.Post("Unknown", 1)).funds, "unknown", "warning-only permits unknown funds honestly")
      assert(B.Add("NoReward", 0), "tracking without reward remains possible")
    end)

    t.test(build .. ": alt gold funds a reward; account commitments cannot be allocated twice", function()
      local bank = new("Bank", build, { gold = 900 })
      local main = new("Alice", build, { gold = 100, network = Copy(bank), saved = { bountyRequireGold = true, bountyPublish = true } })
      local B = main.ns.Bounty
      t.equal(B.Gold.Total(), 1000 * 10000)
      t.equal(#B.Gold.Rows(), 2)
      local p = F.post(main, "Enemy", 800)
      t.equal(p.funds, "available")
      local alt = new("Bank", build, { gold = 900, network = Copy(main), saved = { bountyRequireGold = true, bountyPublish = true } })
      t.equal(alt.ns.Bounty.Public.Available(), 200 * 10000)
      t.equal(alt.ns.Bounty.Public.Post("Second", 201), nil, "same account cannot double allocate")
      t.equal(alt.ns.Bounty.Public.Post("Enemy", 800), nil, "author permissions unchanged")
      t.equal(F.post(alt, "Second", 200).funds, "available")
      main.money = 50 * 10000; main:event("PLAYER_MONEY")
      t.equal(B.Gold.Total(), 950 * 10000, "live money updates ledger")
      local reload = new("Alice", build, { gold = 50, network = Copy(main) })
      t.equal(reload.ns.Bounty.Gold.Total(), 950 * 10000, "reload does not double count current character")
      main.ns.Core.SetOption("bountyAccountGold", false)
      t.equal(B.Gold.Total(), 50 * 10000, "tracking off uses carried gold")
    end)

    t.test(build .. ": paid and withdrawn obligations release account reservations at the right time", function()
      local a = new("Alice", build, { gold = 1000 })
      local p = F.post(a, "Enemy", 800, "5m")
      assert(a.ns.Bounty.Public.Withdraw(p))
      local alt = new("Bank", build, { gold = 0, network = Copy(a) })
      local P = alt.ns.Bounty.Public
      t.equal(P.Available(), 200 * 10000)
      alt.now = alt.now + P.CLAIM_WINDOW + 1
      t.equal(P.Available(), 1000 * 10000)
      local offer = P.Data().offers[p.id]
      offer.state = "claimed"
      P.Data().claims.debt = { pledge = p.id, state = "approved", gold = 800 }
      t.equal(P.Available(), 200 * 10000, "approved debt remains reserved")
      offer.state = "paid"; P.Data().claims.debt.state = "paid"
      t.equal(P.Available(), 1000 * 10000)
    end)

    t.test(build .. ": guild obligations survive character changes without double counting claims", function()
      local a = new("Alice", build, { gold = 1000, guild = "Guild", rank = 0 })
      local B = a.ns.Bounty
      assert(B.Add("Enemy", 800)); local b = assert(B.Submit("Enemy"))
      local c = B.Ledger.Record(b, "Hunter-Realm"); assert(B.Ledger.Change(c, "approved"))
      local bank = new("Bank", build, { gold = 0, network = Copy(a) })
      t.equal(bank.ns.Bounty.Public.Available(), 200 * 10000, "offline guild pledge and approved claim are one hold")
    end)

    t.test(build .. ": the breakdown preserves a draft and the funding setting updates its warning", function()
      local s = new("Alice", build, { gold = 2 })
      local B = s.ns.Bounty
      local w = B.Form.Open("Enemy-Other", "public")
      click(w.action); w.gold:SetText("500"); w.note:SetText("Keep this draft")
      click(w.goldDetails)
      local gold = B.GoldView.win
      assert(gold:IsVisible()); assert(not gold.requireGold:GetChecked())
      assert(gold.rows[1]:GetText():find("Alice", 1, true))
      gold.requireGold:SetChecked(true)
      assert(B.Gold.Required())
      assert(w.goldWarning:GetText():find("turn off Require", 1, true))
      click(gold.done)
      assert(w:IsVisible()); t.equal(w.gold:GetText(), "500"); t.equal(w.note:GetText(), "Keep this draft")
      s.ns.Core.SetOption("fontScale", 1.5)
      B.Form.Layout(w); B.GoldView.Refresh()
      assert(w.fieldY[w.note] > w.fieldY[w.gold] + w.gold:GetHeight(), "warning and settings have dedicated layout space")
    end)

    t.test(build .. ": bag coin hover shows the breakdown without replacing click or hover handlers", function()
      local s = new("Alice", build, { gold = 123 })
      local e, B = s.env, s.ns.Bounty
      getmetatable(e.UIParent).__index.ClearLines = function(f) f.lines = {} end
      local money = e.CreateFrame("Frame", "ContainerFrame1MoneyFrame", e.UIParent)
      money.GoldButton = e.CreateFrame("Button", nil, money)
      local entered, picked = 0, 0
      money.GoldButton:SetScript("OnEnter", function() entered = entered + 1 end)
      money.GoldButton:SetScript("OnClick", function() picked = picked + 1 end)
      s:event("ADDON_LOADED", "Blizzard_Bags")
      s:event("BAG_UPDATE_DELAYED")
      fire(money.GoldButton, "OnEnter")
      local tip = assert(B.GoldTooltip.frame)
      assert(tip:IsShown() and table.concat(tip.lines, " "):find("123g", 1, true))
      t.equal(entered, 1, "idempotent hooks preserve native hover")
      click(money.GoldButton); t.equal(picked, 1, "coin pickup unchanged")
      fire(money.GoldButton, "OnLeave"); assert(not tip:IsShown())
      s.ns.Core.SetOption("bountyAccountGold", false)
      fire(money.GoldButton, "OnEnter"); assert(not tip:IsShown())
    end)
  end

  t.test("realm scopes isolate gold, while factions in the same economy share it", function()
    local a = new("Alice", 120100, { gold = 1000, faction = "Alliance" })
    F.post(a, "Enemy", 800)
    local h = new("HordeAlt", 120100, { gold = 10, faction = "Horde", network = Copy(a) })
    t.equal(h.ns.Bounty.Gold.Total(), 1010 * 10000)
    t.equal(h.ns.Bounty.Public.Available(), 210 * 10000, "cross-faction obligation included")
    local far = new("Elsewhere", 120100, { gold = 50, realm = "Elsewhere", network = Copy(a) })
    t.equal(far.ns.Bounty.Gold.Total(), 50 * 10000)
    t.equal(far.ns.Bounty.Public.Available(), 50 * 10000)
  end)

  t.test("native PLAYER MoneyFrame hooks work for bag replacements and remain additive", function()
    local s = new("Alice", 120100, { gold = 123 })
    local e, B = s.env, s.ns.Bounty
    getmetatable(e.UIParent).__index.ClearLines = function(f) f.lines = {} end
    local entered, left = 0, 0
    e.MoneyFrame_OnEnter = function() entered = entered + 1 end
    e.MoneyFrame_OnLeave = function() left = left + 1 end
    e.hooksecurefunc = function(name, hook)
      local original = e[name]
      e[name] = function(...) original(...); hook(...) end
    end
    B.GoldTooltip.Install(); B.GoldTooltip.Install()
    local frame = e.CreateFrame("Frame", nil, e.UIParent); frame.moneyType = "PLAYER"
    e.MoneyFrame_OnEnter(frame)
    t.equal(entered, 1); assert(B.GoldTooltip.frame:IsShown())
    e.MoneyFrame_OnLeave(frame)
    t.equal(left, 1); assert(not B.GoldTooltip.frame:IsShown())
    frame.moneyType = "STATIC"; e.MoneyFrame_OnEnter(frame)
    assert(not B.GoldTooltip.frame:IsShown(), "item prices do not gain a player wallet tooltip")
  end)

  t.test("renames keep one balance, unreadable current gold is unknown, and invalid saved balances are ignored", function()
    local bank = new("Bank", 120100, { gold = 900 })
    local s = new("Alice", 120100, { gold = 100, network = Copy(bank) })
    local B = s.ns.Bounty
    s.units.player.name = "Alicia"; s:event("PLAYER_MONEY")
    t.equal(B.Gold.Total(), 1000 * 10000); t.equal(#B.Gold.Rows(), 2)
    t.equal(B.Gold.Rows()[1].name, "Alicia-Realm")
    B.Public.db.gold.characters.bad = { name = "Broken-Realm", balance = math.huge, scope = B.Scope.Key(), seenAt = B.Public.Now() }
    t.equal(B.Gold.Total(), 1000 * 10000)
    s.money = nil; s:event("PLAYER_MONEY")
    t.equal(B.Gold.Total(), nil); t.equal(B.Gold.Rows()[1].balance, nil)
    s.money = 0; s:event("PLAYER_MONEY")
    local p = F.post(s, "Enemy", 1500)
    t.equal(B.Public.Reserved(), 1500 * 10000, "underfunded commitments show their full amount")
    local packet = s.ns.Codec.Unpack(B.Public.Encode("offer", p))
    t.equal(packet.walletScope, nil); t.equal(packet.gold, nil); t.equal(packet.characters, nil)
    local function Private(value)
      if type(value) == "table" then
        for key, v in pairs(value) do
          assert(key ~= "walletScope" and key ~= "characters" and key ~= "balance", "wallet fields stay local")
          Private(v)
        end
      else assert(value ~= "Bank-Realm" and value ~= 900 * 10000, "alt names and balances stay local") end
    end
    Private(packet)
  end)

  t.test("Forever uses actual rulesets, including different backend realm names in one ruleset", function()
    local a = new("Alice", 16001, { gold = 900, realm = "Backend-A", ruleset = "PvP" })
    local b = new("Bank", 16001, { gold = 100, realm = "Backend-B", ruleset = "PvP", network = Copy(a) })
    t.equal(b.ns.Bounty.Gold.Total(), 1000 * 10000)
    t.equal(a.ns.Bounty.Public.Scope(), b.ns.Bounty.Public.Scope(), "realmset controls public network scope")
    for _, rule in ipairs({ "PvE", "RP", "RP-PvP", "Hardcore" }) do
      local other = new("Other", 16001, { gold = 50, realm = "Backend-A", ruleset = rule, network = Copy(b) })
      t.equal(other.ns.Bounty.Gold.Total(), 50 * 10000, rule .. " excludes other ruleset funds")
    end
  end)

  t.test("Forever switching isolates private, guild, shared, claims and portraits, then restores them", function()
    local s = new("Alice", 16001, { gold = 1000, guild = "Guild", rank = 0 })
    local B, P = s.ns.Bounty, s.ns.Bounty.Public
    local private = assert(B.Add("Private", 10))
    B.Ledger.Record(private, B.Me())
    assert(B.Add("GuildTarget", 100)); assert(B.Submit("GuildTarget"))
    local p = F.post(s, "PublicTarget", 100)
    B.Portraits.Save({ name = p.name, guid = "", displayID = 19723, class = "ROGUE", race = 1, sex = 2, at = P.Now() })
    B.Form.Open(private.name); B.GoldView.Open()
    local oldScope, oldData = P.Scope(), P.Data()
    local oldPacket = P.Encode("offer", p)
    switch(s, "PvP")
    assert(P.Scope() ~= oldScope and P.Data() ~= oldData)
    t.equal(#B.All(), 0); t.equal(#B.Ledger.All(), 0)
    t.equal(B.Portraits.Record(p.name), nil)
    assert(not B.Form.win:IsVisible() and not B.GoldView.win:IsVisible())
    for _, msg in ipairs(P.outbox) do assert(not (msg.text and msg.text == oldPacket)) end
    assert(B.Add("OnlyPvP", 20))
    switch(s, "PvE")
    -- The recorded private kill is complete, so the live-alert lookup may
    -- omit it. Switching rulesets must still restore the original record.
    assert(B.Entry("Private") == private and B.Find("GuildTarget") and B.Find("PublicTarget"))
    t.equal(B.Find("OnlyPvP"), nil); t.equal(#B.Ledger.All(), 1)
    assert(B.Portraits.Record(p.name))
  end)

  t.test("Forever rejects other-ruleset wire data and keeps ambiguous legacy lists archived", function()
    local a = new("Alice", 16001, { guild = "Guild", rank = 0, ruleset = "PvE" })
    F.post(a, "Enemy", 100); assert(a.ns.Bounty.Add("GuildTarget", 100)); assert(a.ns.Bounty.Submit("GuildTarget"))
    local b = new("Bob", 16001, { guild = "Guild", rank = 0, ruleset = "PvE", roster = { { "Alice-Realm", 0 } } })
    local packets, guildPackets = F.flush(a), {}
    F.deliver(a, b, packets)
    while #a.ns.Bounty.queue > 0 do
      a.ns.Bounty.Flush()
      guildPackets[#guildPackets + 1] = a.sent[#a.sent]
    end
    F.deliver(a, b, guildPackets)
    assert(b.ns.Bounty.Find("Enemy") and b.ns.Bounty.Find("GuildTarget"), "matching realmsets share both public and guild bounties")
    switch(b, "PvP")
    F.deliver(a, b, packets)
    F.deliver(a, b, guildPackets)
    t.equal(#b.ns.Bounty.All(), 0)
    local legacy = { bountyPersonal = { old = { name = "Old-Realm", gold = 1, state = "personal" } } }
    local upgraded = new("Alice", 16001, { saved = legacy })
    t.equal(#upgraded.ns.Bounty.All(), 0, "unknown legacy realmset is not guessed")
    assert(legacy.bountyPersonal.old, "legacy data is retained")
  end)

  for _, ruleset in ipairs({ "PvE", "PvP", "RP", "RP-PvP", "Hardcore" }) do
    t.test("Forever typed names use " .. ruleset .. " when the realm name is unavailable", function()
      for _, missing in ipairs({ false, true }) do
        local s = new("Alice Smith", 16001, { realm = "", ruleset = ruleset, regionalNames = true, missingRealm = missing })
        local B, C = s.ns.Bounty, s.ns.Core
        for _, mode in ipairs({ "personal", "public" }) do
          local enemy = mode == "personal" and "River Mist" or "Silver Thorn"
          local w = B.Form.Open(nil, mode)
          w.name:SetText("  " .. enemy .. "  "); w.gold:SetText("10")
          flow.save(w)
          assert(not w:IsShown(), "typed name creates a bounty without Use target: " .. w.error:GetText())
          local bounty = assert(mode == "personal" and B.Personal()[B.Key(enemy)] or B.Public.Own(enemy))
          t.equal(C.DisplayName(bounty.name), enemy, "full character name is preserved and trimmed")
          t.equal(B.Public.Name(bounty.name), bounty.name, "saved identity is valid for sharing")
          s.units.target = { name = enemy, classID = 4, enemy = true }
          t.equal(C.CanonUnit("target"), bounty.name, "typed and observed identities match")
          assert(B.Find(C.CanonUnit("target")), "the created bounty matches a later sighting")
          s.units.target = nil
        end
        local w = B.Form.Open(nil, "public")
        w.name:SetText("Alice Smith"); flow.click(w.action)
        t.equal(w.step, 1, "manual names still reject the current character")
        assert(w.error:GetText() ~= "")
        local otherRule = ruleset == "PvP" and "PvE" or "PvP"
        switch(s, otherRule)
        t.equal(#B.All(), 0, "typed bounties stay in their original ruleset")
        switch(s, ruleset)
        assert(B.Find("River Mist") and B.Find("Silver Thorn"), "returning restores typed bounties")
        s:assertHealthy()
      end
    end)
  end

  for _, build in ipairs({ 40402, 120100 }) do
    t.test(build .. ": typed bounty names default locally and accept an explicit cross-realm target", function()
      local s = new("Alice", build)
      local B = s.ns.Bounty
      for _, mode in ipairs({ "personal", "public" }) do
        local enemy = mode == "personal" and "Enemy" or "Rival"
        for _, input in ipairs({ enemy, enemy .. "-Area 52" }) do
          local w = B.Form.Open(nil, mode)
          w.name:SetText("  " .. input .. "  "); w.gold:SetText("10")
          flow.save(w)
          assert(not w:IsShown(), "typed name is accepted: " .. w.error:GetText())
        end
        local localName, remoteName = enemy .. "-Realm", enemy .. "-Area52"
        local localBounty = assert(mode == "personal" and B.Personal()[B.Key(localName)] or B.Public.Own(localName))
        local remoteBounty = assert(mode == "personal" and B.Personal()[B.Key(remoteName)] or B.Public.Own(remoteName))
        assert(localBounty ~= remoteBounty, "same character name on another realm is a separate target")
        t.equal(localBounty.name, localName, "no suffix defaults to the local realm")
        t.equal(remoteBounty.name, remoteName, "realm spaces normalize without losing the explicit realm")
      end
      s:assertHealthy()
    end)
  end

  t.test("Forever name components keep full identities while all bounty presentation omits suffixes", function()
    local s = new("Alice Smith", 16001, { realm = "Backend-A" })
    local C, B = s.ns.Core, s.ns.Bounty
    local n = assert(C.CharacterName("Enemy Person-Backend-B"))
    t.equal(n.name, "Enemy Person"); t.equal(n.realm, "Backend-B")
    t.equal(n.full, "Enemy Person-Backend-B"); t.equal(n.key, "enemy person-backend-b")
    t.equal(n:ToString(), "Enemy Person"); t.equal(tostring(n), "Enemy Person")
    assert(B.Add(n.full, 100))
    local row = B.BoardModel.Rows("mine")[1]
    local details = B.Details.Open(row)
    t.equal(details.cards[1].name:GetText(), "Enemy Person")
    assert(not details.cards[1].owner:GetText():find("Backend", 1, true))
    local w = B.Form.Open(n.full)
    t.equal(w.name:GetText(), "Enemy Person")
    w.gold:SetText("200"); flow.save(w)
    t.equal(B.Personal()[n.key].gold, 200, "editing preserves hidden full target identity")
    t.equal(B.Personal()[B.Key("Enemy Person")], nil, "no copy under our backend realm")
    local c = B.Ledger.Record(B.Personal()[n.key], "Hunter Name-Backend-C")
    c.reviewedBy = "Officer Name-Backend-D"
    assert(not B.Ledger.Entry(c).detail:find("Backend", 1, true))
    t.equal(assert(C.CharacterName("No Suffix")).full, "No Suffix-Backend-A")
    local retail = new("Alice", 120100)
    t.equal(retail.ns.Core.DisplayName("Enemy-Other"), "Enemy-Other", "cross-realm display unchanged on Retail")
    t.equal(retail.ns.Core.DisplayName("Enemy-Realm"), "Enemy")
  end)

  t.finish("Account gold, rulesets and names: " .. t.tests .. " scenarios")
end
