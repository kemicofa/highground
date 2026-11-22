local flow = dofile("../../tests/bounty_flow.lua")
-- Navigation, incoming wanted posters and share/import flows in real addon TOCs.
return function(addon)
  local t = dofile("../../tools/harness.lua")(addon .. " bounty UX")
  local F = dofile("../HighgroundBounties/tests/public/fixture.lua")
  local runtime = dofile("../../tools/wowsim/battleground/runtime.lua")
  local function new(name, build, opts)
    opts = opts or {}
    opts.addon, opts.build, opts.client = addon, build, build == 40402 and "cata" or "retail"
    opts.runtime = function(client, saved, configure)
      return runtime(client, saved, function(s, e)
        configure(s, e)
        dofile("../../tools/wowsim/geometry.lua")(s)
        s.ruleset = opts.ruleset or "PvE"
        e.Enum = e.Enum or {}; e.Enum.GameRule = { HardcoreRuleset = 10, RPRuleset = 11, PvPRuleset = 12 }
        e.C_GameRules = { IsGameRuleActive = function(rule)
          return rule == 10 and s.ruleset == "Hardcore" or rule == 11 and (s.ruleset == "RP" or s.ruleset == "RP-PvP")
            or rule == 12 and (s.ruleset == "PvP" or s.ruleset == "RP-PvP")
        end }
      end)
    end
    return F.new(name, opts)
  end
  local function click(button) button.scripts.OnClick(button) end
  local function action(w, label)
    for _, button in ipairs(w.actions) do if button:GetText() == label then return button end end
    error("Missing action: " .. label)
  end
  local function onlyTool(s, expected)
    t.equal(s.ns.Kit.Windows.Active(), expected, "expected destination owns navigation")
    local roots = 0
    for w in pairs(s.ns.Kit.Windows.entries) do
      local p, hosted = w:GetParent(), false
      while p do hosted = hosted or s.ns.Kit.Windows.entries[p] ~= nil; p = p:GetParent() end
      if not hosted and w:IsVisible() then roots = roots + 1 end
    end
    t.equal(roots, 1, "exactly one foreground tool")
  end
  local function incoming(a, h, name, gold)
    local p = F.post(a, name, gold)
    assert(h.ns.Bounty.Public.Merge(F.P(a).Copy(p), p.by))
    return p
  end
  local function scan(s)
    s.now = math.max(s.now, (s.ns.Bounty.Public.quietUntil or 0) + 1)
    s.ns.Bounty.Matches.Scan()
  end

  for _, build in ipairs({ 40402, 120100, 16001 }) do
    t.test(build .. ": a new bounty needs no custom hunt settings and keeps explicit changes on return", function()
      local s = new("Poster", build)
      local B = s.ns.Bounty
      local w = B.Form.Open("Enemy", "personal")
      click(w.action)
      assert(not w.kills:IsShown() and not w.methodButtons.fall:IsShown(), "optional hunt choices start collapsed")
      t.equal(w.kills:GetText(), "1", "one kill by default")
      assert(w.huntSummary:GetText():find("Any finish", 1, true), "default terms stay visible")
      click(w.customizeButton); w.kills:SetText("3"); click(w.methodButtons.fall)
      click(w.goldDetails); click(B.GoldView.win.done)
      assert(w.customize and w.kills:IsShown() and w.selectedMethods.fall, "draft choices survive settings")
      click(w.customizeButton); w.gold:SetText("10"); flow.save(w)
      local b = assert(B.Personal()[B.Key("Enemy")])
      t.equal(b.killsRequired, 3, "collapsing options does not discard the selected goal")
      t.equal(b.killMethods, "fall", "selected finish preserved")
      w = B.Form.Open("Enemy", "personal"); click(w.action)
      assert(w.customize and w.kills:IsShown(), "editing a custom bounty exposes its existing terms")
      s:assertHealthy()
    end)

    t.test(build .. ": settings opens once and returns to the exact draft, direct and from configuration", function()
      local s = new("Poster", build)
      local B = s.ns.Bounty
      B.Add("Enemy", 500)
      for _, hosted in ipairs(s.ns.Hub and { false, true } or { false }) do
        B.Board.Open()
        if hosted then s.ns.Hub.Open("bounty"); click(s.ns.Options.byKey.bounty.openTool) end
        local f, shows = B.Form.Open("Enemy", "personal"), 0
        f.gold:SetText("732"); f.note:SetText("Keep my draft"); f.kills:SetText("3"); f.duration:SetText("2h")
        f:HookScript("OnShow", function() shows = shows + 1 end)
        f.fields:Scroll(100)
        local offset = f.fields.offset
        for i = 1, 4 do
          shows = 0; click(f.goldDetails)
          local settings = B.GoldView.win
          t.equal(shows, 0, "opening settings never bounces through the form")
          assert(settings:IsVisible() and not f:IsVisible())
          onlyTool(s, settings)
          B.GoldView.Open(); onlyTool(s, settings)
          click(settings.done)
          t.equal(shows, 1, "exactly one return to editor")
          assert(f:IsVisible() and not settings:IsVisible())
          t.equal(f.gold:GetText(), "732", "amount retained")
          t.equal(f.note:GetText(), "Keep my draft", "note retained")
          t.equal(f.kills:GetText(), "3", "kill goal retained")
          t.equal(f.duration:GetText(), "2h", "expiry retained")
          t.equal(f.fields.offset, offset, "scroll position retained")
          if hosted then assert(not s.ns.Hub.win:IsVisible() and B.Board.win:GetParent() == s.env.UIParent) end
          onlyTool(s, f)
        end
        f:Hide(); B.Board.win:Hide()
        if hosted then s.ns.Hub.win:Hide() end
      end
      s:assertHealthy()
    end)

    t.test(build .. ": cards open full posters and popup-to-page navigation cannot resurrect old screens", function()
      local s = new("Poster", build)
      local B = s.ns.Bounty
      for _, name in ipairs({ "Enemy", "Other", "Third" }) do B.Add(name, 500) end
      B.Board.Open(); if s.ns.Hub then s.ns.Options.OpenTool("bountyboard") end
      local board = B.Board.win
      board.search:SetText("Enemy"); board.list:Scroll(80)
      local offset = board.list.offset
      board.rows[1].scripts.OnMouseUp(board.rows[1], "LeftButton")
      local poster = B.Details.win
      assert(poster:IsVisible() and not board:IsVisible() and not poster.bountyPage)
      onlyTool(s, poster); click(poster.back)
      assert(board:IsVisible()); t.equal(board.search:GetText(), "Enemy", "search retained")
      t.equal(board.list.offset, offset, "poster returns to same scroll position")
      click(board.rows[1].details); click(action(poster, "Edit reward"))
      local f = B.Form.win
      assert(f:IsVisible() and not poster:IsVisible(), "editor replaces poster in one action")
      onlyTool(s, f); click(f.goldDetails)
      local other = s.ns.Kit.Dialog(nil, { title = "Another tool" }); other:Show()
      onlyTool(s, other); other:Hide()
      assert(not f:IsVisible() and not poster:IsVisible() and not B.GoldView.win:IsVisible(), "old return path abandoned")
      s:assertHealthy()
    end)

    t.test(build .. ": a foreign filter match preserves editors and tracking never pledges gold", function()
      local a, h = new("Poster", build), new("Hunter", build, { saved = { bountyReceive = true, bountyMinGold = 400 } })
      local B = h.ns.Bounty
      incoming(a, h, "First", 500); incoming(a, h, "Second", 600); incoming(a, h, "Third", 700)
      local form = B.Form.Open("Draft", "personal"); form.note:SetText("Unfinished")
      local settings = B.GoldView.Open()
      local reserved, count = B.Public.Reserved(), F.count(B.Public.Data().offers)
      scan(h)
      local w = assert(B.Matches.win)
      assert(w:IsVisible() and w.status:GetText():find("FILTER MATCH", 1, true))
      assert(w.location:GetText():find("no sighting reported", 1, true))
      assert(next(B.seen) == nil and settings:IsVisible(), "arrival is not a sighting or a navigation event")
      onlyTool(h, settings)
      local tracked = w.bounty.name
      click(w.details)
      t.equal(B.Matches.State(tracked), "tracking", "tracking saved")
      assert(w:IsVisible() and w.bounty.name ~= tracked and #B.Matches.queue == 1, "one queued poster advanced")
      local rows = B.BoardModel.Rows("mine")
      t.equal(#rows, 1, "tracked target appears in My bounties")
      t.equal(rows[1].name, tracked, "correct target tracked")
      assert(rows[1].owner:find("other players", 1, true), "reward ownership retained")
      local ignored = w.bounty.name; click(w.ignore)
      t.equal(B.Matches.State(ignored), "ignored", "ignore saved")
      t.equal(B.Find(ignored, true), nil, "ignore suppresses sightings")
      assert(w:IsVisible() and #B.Matches.queue == 0, "ignore advances exactly one poster")
      w:Hide(); scan(h); assert(not w:IsShown(), "same offers never repeat")
      t.equal(B.Public.Reserved(), reserved, "tracking creates no gold commitment")
      t.equal(F.count(B.Public.Data().offers), count, "tracking creates no duplicate offer")
      assert(next(B.Personal()) == nil, "tracking creates no private bounty")
      click(settings.done); t.equal(form.note:GetText(), "Unfinished", "open draft untouched")
      local reloaded = new("Hunter", build, { saved = B.Public.Copy(h.ns.Core.db), network = B.Public.Copy(B.Public.db) })
      scan(reloaded)
      t.equal(reloaded.ns.Bounty.Matches.State(ignored), "ignored", "ignore survives reload")
      t.equal(reloaded.ns.Bounty.Matches.State(tracked), "tracking", "tracking survives reload")
      assert(not reloaded.ns.Bounty.Matches.win, "dismissed arrival stays dismissed after reload")
      h:assertHealthy(); reloaded:assertHealthy()
    end)

    t.test(build .. ": incoming posters fit without scrolling and keep actions fixed", function()
      local a, h = new("Poster", build), new("Hunter", build, { saved = { bountyReceive = true } })
      h.env.UIParent:SetSize(1024, 600); h.ns.Core.SetFontScale(1.5)
      incoming(a, h, "Enemy", 500); scan(h)
      local B, w = h.ns.Bounty, assert(h.ns.Bounty.Matches.win)
      assert(not w.viewport and w:GetHeight() <= 552, "incoming poster fits without scrolling")
      local action = h.bounds(w.details)
      for _ = 1, 3 do B.Matches.Refresh(); B.Emit("updated") end
      t.close(h.bounds(w.details)[2], action[2], "background updates preserve action placement")
      local outer = h.bounds(w)
      for _, button in ipairs({ w.details, w.ignore }) do
        local box = h.bounds(button)
        assert(box[2] >= outer[2] and box[2] + box[4] <= outer[2] + outer[4], "actions remain inside the popup")
      end
      incoming(a, h, "Different", 600)
      B.Matches.Show(B.Public.Find("Different"))
      t.equal(w.bounty.name, B.Public.Name("Enemy"), "queuing another target preserves the current poster")
      click(w.close)
      t.equal(w.bounty.name, B.Public.Name("Different"), "dismissal advances to the queued target")
      assert(w:GetHeight() <= 552, "the next target also fits without scrolling")
      h:assertHealthy()
    end)

    t.test(build .. ": incoming posters honor funding, ownership, thresholds and notification preferences", function()
      local a, h = new("Poster", build), new("Hunter", build, { saved = { bountyPublish = true, bountyReceive = true, bountyMinGold = 600 } })
      local B = h.ns.Bounty
      F.post(h, "Own", 900); incoming(a, h, "Low", 500)
      local funded = incoming(a, h, "Unknown", 700)
      B.Public.Data().offers[funded.id].funds = "unknown"
      scan(h); assert(not B.Matches.win, "own, low and unknown rewards do not trigger")
      h.ns.Core.SetOption("bountyMinGold", 400)
      h.ns.Core.SetOption("bountyAnnounce", false); scan(h); assert(not B.Matches.win)
      h.ns.Core.SetOption("bountyAnnounce", true)
      h.ns.Alerts.Settings().channels.bounty = { text = false }
      scan(h); assert(not B.Matches.win, "text mute respected")
      h.ns.Alerts.Settings().channels.bounty.text = true; scan(h)
      local w = assert(B.Matches.win)
      t.equal(w.bounty.name, "Low-Realm", "lowering threshold discovers a matching reward")
      B.Public.Data().offers[B.Public.Find("Low").contributions[1].id].state = "withdrawn"
      B.Emit("publicChanged"); assert(not w:IsShown(), "withdrawal dismisses stale match")
      local fresh = incoming(a, h, "Fresh", 800); scan(h); assert(w:IsShown())
      h.now = h.now + B.Public.FUNDS_TTL + 1
      scan(h); assert(not w:IsShown(), "stale funding dismisses an open notification without a network event")
      local received = B.Public.Data().offers[fresh.id]
      received.checkedAt = B.Public.Now(); B.Emit("publicChanged"); scan(h)
      assert(not w:IsShown(), "funding heartbeats do not repeat a dismissed offer")
      h:assertHealthy()
    end)

    t.test(build .. ": tracking has a visible reversal and preserves rewards and reports after reload", function()
      local a, h = new("Poster", build), new("Hunter", build)
      local B = h.ns.Bounty
      incoming(a, h, "Enemy", 500)
      B.Board.SetTab("public"); B.Board.Open()
      local card = B.Board.win.rows[1]
      t.equal(card.trackingLabel:GetText(), "NOT TRACKING", "untracked reward is explicit")
      click(card.primary)
      t.equal(card.trackingLabel:GetText(), "TRACKING", "tracking updates immediately")
      click(card.primary)
      t.equal(card.trackingLabel:GetText(), "NOT TRACKING · ALERTS OFF", "stopped state is explicit")
      t.equal(#B.BoardModel.Rows("mine"), 0, "stopped foreign target leaves My bounties")
      t.equal(B.Find("Enemy", true), nil, "stopped target cannot trigger sighting alerts")
      click(card.primary)
      assert(B.BoardActions.Report(card.entry))
      local report = assert(B.Ledger.ForBounty(card.entry))
      local count = F.count(B.Public.Data().claims)
      click(B.Ledger.win.back); click(card.details)
      local function Choose(label)
        click(flow.action(B.Details.win, label))
      end
      Choose("Stop tracking")
      t.equal(F.count(B.Public.Data().claims), count, "stopping preserves kill reports")
      t.equal(B.Details.win.actions[1]:GetText(), "View report", "existing report remains the next action")
      assert(B.Public.Find("Enemy"), "the reward remains on the shared board")
      B.Add("Private", 0)
      B.Details.Open(B.BoardModel.Rows("mine")[1])
      Choose("Stop tracking")
      assert(B.Personal()[B.Key("Private")], "stopping preserves a private target")
      local again = new("Hunter", build, { saved = B.Public.Copy(h.ns.Core.db), network = B.Public.Copy(B.Public.db) })
      local R = again.ns.Bounty
      t.equal(R.Matches.State("Enemy"), "ignored", "stopped state survives reload")
      t.equal(R.Matches.State("Private"), "ignored", "private tracking choice survives reload")
      assert(R.Public.Data().claims[report.id], "report survives reload")
      assert(not R.Matches.Tracking(R.BoardModel.Rows("mine")[1]), "retained private record is not silently tracked again")
      h:assertHealthy(); again:assertHealthy()
    end)

    t.test(build .. ": approved guild matches work with global receiving off and retain the poster", function()
      local s = new("Hunter", build, { guild = "Guild", roster = { { "Poster-Realm", 0 } }, saved = { bountyReceive = false } })
      local B = s.ns.Bounty
      B.Receive(B.Scope.Wrap("1:A,GuildEnemy-Realm,700,Poster-Realm,1000,A,Poster-Realm,Guild target"), "Poster-Realm")
      scan(s)
      local w = assert(B.Matches.win)
      t.equal(w.bounty.name, "GuildEnemy-Realm", "approved guild arrival")
      assert(w.owner:GetText():find("guild", 1, true))
      click(w.details)
      local row = B.BoardModel.Rows("mine")[1]
      assert(row and row.guild and row.owner:find("Poster", 1, true), "tracking does not claim ownership")
      assert(not B.Public.Receiving() and next(B.Personal()) == nil)
      s:assertHealthy()
    end)

    t.test(build .. ": complete posts and code-only exports import without copying instructions or links", function()
      local a, h = new("Poster", build), new("Hunter", build)
      local B, H = a.ns.Bounty, h.ns.Bounty
      local p = F.post(a, "Enemy", 500)
      local w = B.Exchange.Show(p, "global")
      t.equal(w:GetText(), w.bountyURL, "one default sharing format")
      assert(w.post:find(w.bountyURL or w.code, 1, true) and not w.post:find("https://", 1, true))
      assert(w.hint:GetText():find("optional", 1, true))
      assert(H.Exchange.Decode(w.post), "recipient imports the whole post")
      assert(H.Exchange.Decode(w.code:sub(1, 80) .. "\n" .. w.code:sub(81)), "wrapped raw codes remain importable")
      local otherCode = B.Exchange.Encode(F.post(a, "Different", 250), "global")
      assert(not H.Exchange.Decode(w.post .. "\n" .. otherCode), "ambiguous posts rejected")
      assert(not w.actions.chat:IsShown(), "global offers use the complete contribution link")
      click(w.actions.options)
      t.equal(B.Exchange.destinationWin:GetText(), B.Exchange.URL("board") or B.Exchange.INVITE, "Discord uses a separate browser address dialog")
      click(B.Exchange.destinationWin.done)
      t.equal(w:GetText(), w.bountyURL, "Discord navigation keeps the bounty link intact")
      H.Board.Open(); click(H.Board.win.import)
      local import = H.Exchange.importWin
      import.box:SetText(w.post); click(import.actions.review)
      assert(import.reviewed and next(H.Public.Data().offers) == nil, "review before saving")
      click(import.actions.review)
      local received = H.Public.Data().offers[p.id]
      assert(received and received.imported and received.funds == "unknown", "import preserves unverified funding")
      a.env.UIParent:SetSize(1024, 600); a.ns.Core.SetFontScale(1.5)
      for _, button in ipairs({ w.bountyLink, w.actions.options, w.done }) do
        assert(button:GetWidth() >= button.label:GetStringWidth() + 10, "copy controls fit enlarged text")
      end
      assert(w:GetHeight() <= 560 and w.well:GetHeight() >= 48, "sharing keeps a usable copy field on short screens")
      local payload, instruction = a.bounds(w.well), a.bounds(w.destination)
      assert(payload[2] + payload[4] + 8 <= instruction[2], "copy field and next step do not overlap")
      local contribution = B.Pot.Open(p)
      assert(contribution:GetHeight() <= 560, "contribution dialog fits a short screen")
      contribution.gold:SetText("550")
      t.equal(contribution.targetCard.reward:GetText(), "550g", "large-text preview includes your selected gold")
      contribution.content:Scroll(10000)
      local view, terms = a.bounds(contribution.content.view), a.bounds(contribution.terms)
      assert(terms[2] + terms[4] <= view[2] + view[4] + 1, "all contribution terms can be read")
      local footer, content = a.bounds(contribution.add), a.bounds(contribution.content)
      assert(content[2] + content[4] + 8 <= footer[2], "confirmation stays separate from scrolling content")
      click(contribution.cancel); t.equal(p.gold, 500, "cancelling the preview changes no reward")
      a:assertHealthy(); h:assertHealthy()
    end)

    t.test(build .. ": preview claims keep structured details and review actions with distinct footer controls", function()
      local s = new("Hunter", build)
      local B = s.ns.Bounty
      B.Preview.Select("kill")
      local w = B.Preview.OpenClaims()
      assert(w.claimProfile and w.claimProfile:IsVisible())
      t.equal(w.claimProfile.reward:GetText(), "500g", "selected kill reward")
      t.equal(w.claimProfile.state.label:GetText(), "SAMPLE · AWAITING REVIEW", "explicit sample state")
      click(w.rows[3]); click(w.actions[1])
      assert(w.claimProfile.state.label:GetText():find("APPROVED", 1, true))
      assert(w.claimProfile.next:GetText():find("Pay the hunter", 1, true))
      for _, scale in ipairs({ 1, 1.5 }) do
        s.ns.Core.SetFontScale(scale)
        local back, action = s.bounds(w.back), s.bounds(w.actions[3])
        assert(back[1] + back[3] < action[1], "back never overlaps reject")
        local content = s.bounds(w.claimProfile)
        local last = s.bounds(w.claimProfile.next)
        assert(last[2] + last[4] <= content[2] + content[4], "all claim fields reachable by scrolling")
      end
      assert(next(B.Ledger.All()) == nil and next(B.Public.Data().claims) == nil, "preview never writes real claims")
      s:assertHealthy()
    end)
  end

  t.test("Forever tracking, ignores and arrival deduplication stay within their realmset", function()
    local a, h = new("Poster", 16001), new("Hunter", 16001)
    local B = h.ns.Bounty
    incoming(a, h, "Enemy", 500); scan(h); click(B.Matches.win.ignore)
    assert(B.Matches.State("Enemy") == "ignored")
    h.ruleset = "PvP"; B.Scope.Check()
    assert(B.Matches.State("Enemy") == nil and not B.Matches.win:IsShown())
    B.Matches.Set("Enemy", "tracking")
    h.ruleset = "PvE"; B.Scope.Check()
    t.equal(B.Matches.State("Enemy"), "ignored", "original realmset choice retained")
    scan(h); assert(not B.Matches.win:IsShown())
    h:assertHealthy()
  end)
  t.finish()
end
