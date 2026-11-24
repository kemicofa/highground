local flow = dofile("../../tests/bounty_flow.lua")
-- The tour uses the shipped renderers but never the live mutation services.
return function(addon)
  local t = dofile("../../tools/harness.lua")(addon .. " bounty feature tour")
  local equal = t.equal
  t.equal = function(a, b, why) return equal(a, b, why or "expected value") end
  local F = dofile("tests/bounties/public/fixture.lua")
  local runtime = dofile("../../tools/wowsim/battleground/runtime.lua")
  local function new(build, opts)
    opts = opts or {}
    opts.addon, opts.build, opts.client = addon, build, build == 40402 and "cata" or "retail"
    opts.runtime = function(client, saved, configure)
      return runtime(client, saved, function(s, e)
        configure(s, e); dofile("../../tools/wowsim/geometry.lua")(s)
        getmetatable(e.UIParent).__index.ClearLines = function(f) f.lines = {} end
        s.captures = 0; e.Screenshot = function() s.captures = s.captures + 1 end
      end)
    end
    return F.new("Tester", opts)
  end
  local function click(button)
    assert(button and (not button.IsEnabled or button:IsEnabled()), "action exists and is enabled")
    button.scripts.OnClick(button)
  end
  local function act(D, label)
    for _, button in ipairs(D.win.actions) do
      if button:IsShown() and button:GetText() == label then click(button); return end
    end
    error("Missing visible feature action: " .. label)
  end
  local function fire(frame, event)
    if frame.scripts[event] then frame.scripts[event](frame) end
    for _, hook in ipairs(frame.hooks[event] or {}) do hook(frame) end
  end
  local function same(a, b, path)
    path = path or "saved data"
    assert(type(a) == type(b), path .. " type changed")
    if type(a) ~= "table" then assert(a == b, path .. " changed"); return end
    for k, v in pairs(a) do same(v, b[k], path .. "." .. tostring(k)) end
    for k in pairs(b) do assert(a[k] ~= nil, path .. "." .. tostring(k) .. " was added") end
  end
  local function active(s, frame)
    t.equal(s.ns.Kit.Windows.Active(), frame, "expected window owns navigation")
    assert(frame:IsVisible(), "expected window visible")
  end
  local function fits(s, frame)
    local b = s.bounds(frame)
    assert(b[1] >= 0 and b[2] >= 0 and b[1] + b[3] <= s.env.UIParent:GetWidth() + 1
      and b[2] + b[4] <= s.env.UIParent:GetHeight() + 1, "window fits screen: " .. tostring(frame.name or "unnamed"))
  end

  for _, build in ipairs({ 40402, 120100, 16001 }) do
    t.test(build .. ": every feature is reachable, actionable and isolated from real data", function()
      local s = new(build)
      local B, C = s.ns.Bounty, s.ns.Core
      local D, P = B.Preview, B.Public
      local real = F.post(s, "RealEnemy", 25); F.flush(s)
      local draft = B.Form.Open("RealEnemy", "public")
      draft.gold:SetText("777"); draft.note:SetText("Keep my unsaved draft")
      local saved, network = P.Copy(C.db), P.Copy(P.db)
      local sent, chat, outbox = #s.sent, #s.chat, #P.outbox
      local returns = 0
      D.Start(function() returns = returns + 1 end)
      active(s, D.win); t.equal(#D.scenes, 11, "all feature chapters")
      assert(B.Poster.previewWin:IsVisible() and B.Poster.previewWin.tourDocked, "nearby popup inside tour")
      B.Poster.previewWin.scripts.OnUpdate(B.Poster.previewWin, 20)
      assert(B.Poster.previewWin:IsShown(), "sample remains available until dismissed")
      for _, scene in ipairs(D.scenes) do
        click(D.win.scenes[scene.key]); active(s, D.win)
        assert(#D.Actions(scene.key) > 0, scene.key .. " has interactive examples")
        click(D.win.details); active(s, B.Details.win)
        assert(B.Details.preview, "details remain sample-only")
        for _, button in ipairs(B.Details.win.actions) do assert(not button:IsShown(), "real actions hidden") end
        click(B.Details.win.back); active(s, D.win)
      end
      assert(D.win.progress:GetText():find("11/11", 1, true), "progress covers every chapter")
      t.equal(returns, 0, "navigation never exits tour")

      D.Select("create"); act(D, "Open sample form")
      local f = B.Form.previewWin
      assert(f ~= draft); active(s, f)
      assert(not f.customize and not f.kills:IsShown(), "sample creation uses the simple live defaults")
      click(f.action); click(f.customizeButton)
      f.gold:SetText("999999"); f.kills:SetText("3"); f.note:SetText("Sample challenge")
      assert(f.goldWarning:GetText():find("still create", 1, true), "insufficient funds only warn by default")
      click(f.expiryButtons["7d"]); t.equal(f.duration:GetText(), "7d", "horizontal expiry selection")
      click(f.expiryButtons.custom); f.duration:SetText("14d")
      for _ = 1, 3 do
        click(f.goldDetails); local g = B.GoldView.previewWin; active(s, g)
        assert(g.tracking:GetChecked() and not g.requireGold:GetChecked(), "sample defaults match feature defaults")
        t.equal(#g.rows, 3, "sample gold breakdown across characters")
        click(g.done); active(s, f)
        t.equal(f.gold:GetText(), "999999", "draft gold preserved")
        t.equal(f.duration:GetText(), "14d", "draft expiry preserved")
      end
      click(f.goldDetails); click(B.GoldView.previewWin.requireGold); click(B.GoldView.previewWin.done)
      flow.save(f); assert(f:IsVisible() and f.error:GetText():find("Not enough", 1, true), "sample requirement blocks creation")
      click(f.goldDetails); click(B.GoldView.previewWin.requireGold); click(B.GoldView.previewWin.done)
      flow.save(f); active(s, D.win)
      assert(D.state.draft and D.state.draft.gold == 999999, "sample save permitted after warning")
      assert(not B.Exchange.previewShareWin, "sharing does not interrupt saving")
      act(D, "Share sample (optional)"); active(s, B.Exchange.previewShareWin)
      assert(not B.Exchange.Decode(B.Exchange.previewShareWin.code), "sample export cannot become a real bounty")
      click(B.Exchange.previewShareWin.done); active(s, D.win)
      for _, mode in ipairs({ "personal", "guild" }) do
        act(D, "Open sample form"); click(f.modes[mode]); f.gold:SetText(mode == "personal" and "0" or "500")
        flow.save(f); active(s, D.win)
        t.equal(D.row.state, mode == "guild" and "pending" or "personal", "sample audience outcome")
      end

      D.Select("gold"); fire(D.win.money, "OnEnter")
      assert(B.GoldTooltip.frame:IsVisible(), "bag-style breakdown available on hover")
      fire(D.win.money, "OnLeave"); assert(not B.GoldTooltip.frame:IsShown())
      act(D, "Gold & settings"); local g = B.GoldView.previewWin
      local total = D.Wallet().total; click(g.tracking)
      assert(D.Wallet().total < total, "turning off account gold uses current character")
      click(g.tracking); click(g.done)

      D.Select("guild"); act(D, "Awaiting approval")
      t.equal(D.bounty.state, "pending"); act(D, "Approve sample")
      t.equal(D.bounty.state, "approved"); click(B.Matches.previewWin.details)
      t.equal(D.state.interest, "tracking"); act(D, "Reject sample")
      t.equal(D.bounty.state, "removed")
      D.Select("shared"); click(B.Matches.previewWin.ignore); t.equal(D.state.interest, "ignored")
      act(D, "Replay arrival"); click(B.Matches.previewWin.details); t.equal(D.state.interest, "tracking")
      t.equal(D.win.row.trackingLabel:GetText(), "TRACKING", "sample card reflects the tracking choice")
      act(D, "Alert settings"); local pref = B.Preferences.previewWin
      click(pref.receive); pref.threshold:SetText("9999"); click(pref.publishOptIn); click(pref.done)
      act(D, "Replay arrival"); assert(not B.Matches.previewWin:IsShown(), "sample filter settings affect arrival")
      act(D, "Alert settings"); click(pref.receive); pref.threshold:SetText("500"); click(pref.done)
      for _ = 1, 4 do act(D, "Next funding state"); click(D.win.details); click(B.Details.win.back) end
      act(D, "Replay arrival"); assert(B.Matches.previewWin:IsVisible())

      D.Select("pot"); act(D, "Add sample gold")
      local pot = B.Pot.previewWin
      pot.gold:SetText("100"); click(pot.add); active(s, D.win)
      t.equal(D.bounty.gold, 850, "pot grows in preview"); t.equal(#D.bounty.contributions, 3, "sample contributor added")
      act(D, "Add sample gold"); pot.gold:SetText("50"); click(pot.add)
      t.equal(D.bounty.gold, 900); t.equal(#D.bounty.contributions, 3, "repeat addition increases same contribution")
      click(D.win.details); assert(B.Details.win.cards[3]:IsShown()); click(B.Details.win.back)

      D.Select("exchange")
      for _, audience in ipairs({ "global", "guild", "private" }) do
        act(D, "Share sample"); local share = B.Exchange.previewShareWin
        assert(share.instructions:GetText():find("Nothing is sent", 1, true), "sample sharing clearly labelled")
        t.equal(share:GetText(), share.bountyURL, "the link is the default sharing path")
        click(share.bountyLink); assert(not B.Exchange.Decode(share:GetText()), "sample link cannot import on real board")
        assert(share.actions.options:IsShown() == (audience == "global"), "Discord is a direct global destination")
        assert(share:GetText():find(D.CODE, 1, true))
        local post = share:GetText(); click(share.done)
        act(D, "Import sample"); local imp = B.Exchange.previewImportWin
        imp.box:SetText("not an import"); click(imp.actions.review); assert(not imp.reviewed)
        imp.box:SetText(post); click(imp.actions.review)
        assert(imp.reviewText:find("SAMPLE IMPORT", 1, true), "explicit review step")
        click(imp.actions.review); active(s, D.win)
        assert(D.win.feedback:GetText():find("confirmed", 1, true), "sample import feedback")
        act(D, "Change audience")
      end

      D.Select("kill"); local proof = B.Proof.previewWin
      assert(not proof.check:IsShown(), "unconfirmed screenshot has no success check")
      act(D, "Screenshot failure"); assert(proof.retry:IsShown() and not proof.check:IsShown())
      click(proof.retry); assert(not proof.retry:IsEnabled() and proof.retry.busyBar:IsVisible()); s:advance(0.7); assert(proof.check:IsShown() and not proof.retry:IsShown(), "safe retry simulates success")
      act(D, "Next killing blow"); act(D, "Next killing blow"); act(D, "Next killing blow")
      act(D, "Another kill"); t.equal(D.state.kills, 2)
      act(D, "Approve sample kill"); assert(proof.killProgress:GetText():find("1/3", 1, true))
      click(proof.proof); active(s, B.Exchange.previewProofWin)
      assert(B.Exchange.previewProofWin:GetText():find("No kill recorded", 1, true)); click(B.Exchange.previewProofWin.done)
      act(D, "Sample claims"); local claims = D.claimsWin
      assert(not claims.actions[1]:IsEnabled(), "hunter cannot approve own report")
      click(claims.rows[3]); click(claims.actions[1]); t.equal(D.claims[3].state, "approved")
      click(claims.actions[2]); t.equal(D.claims[3].state, "paid")
      click(claims.back); active(s, D.win)
      D.Select("claims"); act(D, "Open sample claims"); claims.search:SetText("rejected")
      t.equal(#claims.items, 1, "rejected example is searchable"); click(claims.back)

      D.Select("suggestions"); act(D, "View sample reports"); local reports = B.Suggestions.View.previewWin
      click(reports.review); active(s, B.Form.previewWin); click(B.Form.previewWin.cancel)
      active(s, reports); click(reports.dismiss); active(s, D.win)
      act(D, "View sample reports"); click(reports.ignore); active(s, D.win)
      D.Stop(); t.equal(returns, 1, "one return callback on exit")
      D.Stop(); t.equal(returns, 1, "stop is idempotent")
      t.equal(s.captures, 0, "tour never calls Screenshot")
      t.equal(draft.gold:GetText(), "777"); t.equal(draft.note:GetText(), "Keep my unsaved draft")
      t.equal(P.Own("RealEnemy").id, real.id)
      same(saved, C.db); same(network, P.db)
      t.equal(#s.sent, sent); t.equal(#s.chat, chat); t.equal(#P.outbox, outbox)
      s:assertHealthy()
    end)

    t.test(build .. ": close, Escape, stop and scope changes retire every sample dialog", function()
      local s, callbacks = new(build), 0
      local B, D = s.ns.Bounty, s.ns.Bounty.Preview
      local function start(key) D.Start(function() callbacks = callbacks + 1 end, key) end
      start("create"); act(D, "Open sample form"); click(B.Form.previewWin.goldDetails)
      D.GuideCommand(""); t.equal(callbacks, 1, "command toggles off from nested settings")
      assert(not D.win:IsVisible() and not B.Form.previewWin:IsVisible() and not B.GoldView.previewWin:IsVisible())
      start("exchange"); act(D, "Share sample"); B.Exchange.previewShareWin:Hide()
      active(s, D.win); t.equal(callbacks, 1, "Escape on a child returns to tour")
      D.win:Hide(); t.equal(callbacks, 2, "Escape on root exits tour")
      start("kill"); act(D, "Sample claims"); D.GuideCommand("stop"); t.equal(callbacks, 3)
      assert(not D.claimsWin:IsVisible() and not B.Proof.previewWin:IsVisible())
      D.Select("claims"); act(D, "Open sample claims")
      click(D.claimsWin.rows[3]); click(D.claimsWin.actions[3]); t.equal(D.claims[3].state, "rejected", "sample rejection works")
      D.Stop()
      start("suggestions"); click(D.win.next); t.equal(callbacks, 4, "Finish tour returns to guide")
      start("gold"); B.Emit("scope"); t.equal(callbacks, 5, "realmset changes close sample context")
      s:assertHealthy()
    end)

    t.test(build .. ": guided samples work without constructing the large tour window", function()
      local s, returned = new(build), 0
      local B, D = s.ns.Bounty, s.ns.Bounty.Preview
      local saved, network = B.Public.Copy(s.ns.Core.db), B.Public.Copy(B.Public.db)
      local sent, chat, queued = #s.sent, #s.chat, #B.Public.outbox
      local bounty, row = D.StartGuided(function() returned = returned + 1 end, "create")
      assert(bounty == D.bounty and row == D.row and D.guided, "guided start exposes sample data")
      assert(not D.win and not B.Poster.previewWin, "guided start has no shell or automatic alert")
      local f = D.OpenCreate("personal")
      f.gold:SetText("1500"); click(f.goldDetails)
      local gold = B.GoldView.previewWin
      click(gold.requireGold); click(gold.done); active(s, f)
      flow.save(f); assert(f:IsVisible() and f.error:GetText():find("Not enough", 1, true))
      click(f.goldDetails); click(gold.requireGold); click(gold.done); flow.save(f)
      assert(D.state.draft and not D.win, "save uses sample data without a shell")
      local notices = D.state.messages.create
      assert(notices and notices:find("Sample bounty saved", 1, true))
      D.SelectGuided("shared")
      B.Matches.Show(D.bounty, true)
      local match = B.Matches.previewWin
      assert(match:IsVisible() and match:GetParent() == s.env.UIParent)
      click(match.details); t.equal(D.state.interest, "tracking")
      D.SelectGuided("kill"); D.Capture("failed")
      local proof = B.Proof.previewWin
      assert(proof:IsVisible() and proof:GetParent() == s.env.UIParent and proof.retry:IsShown())
      click(proof.retry); assert(not proof.retry:IsEnabled() and proof.retry.busyBar:IsVisible()); s:advance(0.7); assert(proof.check:IsShown(), "guided retry remains visible")
      D.AnotherKill(); assert(proof.killProgress:GetText():find("2 pending", 1, true))
      click(proof.proof); active(s, B.Exchange.previewProofWin)
      D.SelectGuided("claims")
      assert(not B.Exchange.previewProofWin:IsShown() and not proof:IsShown(), "chapter change retires previous samples")
      local claims = D.OpenClaims()
      click(claims.rows[3]); click(claims.actions[1]); click(claims.actions[2]); click(claims.back)
      D.SelectGuided("board"); B.Details.Open(D.row, true); click(B.Details.win.back)
      assert(not B.Details.win:IsShown(), "guided details Back dismisses without opening shell")
      D.Notice("Coach feedback"); D.Resume(); D.Refresh()
      assert(not D.win, "sample helpers never construct the standalone shell")
      t.equal(returned, 0, "sample navigation is not a guide exit")
      s:setCombat(true); D.Stop(); D.Stop()
      t.equal(returned, 1); assert(not D.guided and not D.state)
      same(saved, s.ns.Core.db); same(network, B.Public.db)
      t.equal(#s.sent, sent); t.equal(#s.chat, chat); t.equal(#B.Public.outbox, queued); t.equal(s.captures, 0)
      s:assertHealthy()
    end)

    t.test(build .. ": standalone and guided sessions never resurrect each other's windows", function()
      local s, returned, shows = new(build), 0, 0
      local B, D = s.ns.Bounty, s.ns.Bounty.Preview
      D.Start(); D.Select("shared"); D.Select("kill"); D.Select("create")
      D.OpenCreate(); click(B.Form.previewWin.goldDetails)
      local shell = D.win
      shell:HookScript("OnShow", function() shows = shows + 1 end)
      D.StartGuided(function() returned = returned + 1 end, "nearby")
      assert(not shell:IsShown() and not B.Form.previewWin:IsShown() and not B.GoldView.previewWin:IsShown())
      for _, owner in ipairs({ B.Poster, B.Matches, B.Proof }) do
        assert(owner.previewWin:GetParent() == s.env.UIParent, "old docked sample is detached")
      end
      D.Replay(); assert(B.Poster.previewWin:IsVisible())
      D.SelectGuided("shared"); B.Matches.Show(D.bounty, true); click(B.Matches.previewWin.ignore)
      D.SelectGuided("kill"); D.Capture("failed"); click(B.Proof.previewWin.retry)
      D.SelectGuided("claims"); D.OpenClaims(); D.Resume(); D.Notice("Guided feedback")
      s.ns.Core.SetFontScale(1.5); D.Refresh()
      t.equal(shows, 0, "hidden shell never flashes during guided flow")
      t.equal(returned, 0)
      D.Stop(); t.equal(returned, 1); assert(not D.claimsWin:IsShown())
      D.Start(nil, "nearby"); active(s, shell)
      assert(B.Poster.previewWin:GetParent() == shell.body and B.Poster.previewWin:IsVisible(), "normal tour docks again")
      D.Stop()
      D.StartGuided(function() returned = returned + 1 end, "create"); D.OpenCreate(); click(B.Form.previewWin.goldDetails)
      B.Emit("scope"); t.equal(returned, 2)
      assert(not shell:IsShown() and not B.Form.previewWin:IsShown() and not B.GoldView.previewWin:IsShown())
      D.Stop(); t.equal(returned, 2)
      s:assertHealthy()
    end)
  end

  t.test("navigation stays reachable at normal and enlarged text on short screens", function()
    local s = new(40402)
    local D = s.ns.Bounty.Preview
    for _, screen in ipairs({ { 1280, 820 }, { 1024, 720 } }) do
      s.env.UIParent:SetSize(unpack(screen))
      for _, scale in ipairs({ 1, 1.5 }) do
        s.ns.Core.SetFontScale(scale)
        D.Start()
        for _, scene in ipairs(D.scenes) do
          D.Select(scene.key); local w = D.win
          fits(s, w)
          for _, button in pairs(w.scenes) do
            assert(button.label:GetStringWidth() + 20 <= button:GetWidth(), "chapter text fits: " .. button:GetText())
          end
          for _, button in ipairs({ w.prev, w.next, w.done }) do fits(s, button) end
          local scroll, footer = s.bounds(w.scroll), s.bounds(w.progress)
          assert(scroll[2] + scroll[4] + 8 <= footer[2], "example scroll clears pinned navigation")
          for _, button in ipairs(w.actions) do
            if button:IsShown() then assert(button.label:GetStringWidth() + 20 <= button:GetWidth(), "sample action fits") end
          end
        end
        D.Select("create"); act(D, "Open sample form"); fits(s, s.ns.Bounty.Form.previewWin)
        click(s.ns.Bounty.Form.previewWin.goldDetails)
        local gold = s.ns.Bounty.GoldView.previewWin
        fits(s, gold); assert(gold.list.view:GetHeight() >= 60, "gold breakdown remains scrollable")
        click(gold.done); click(s.ns.Bounty.Form.previewWin.cancel)
        D.Select("exchange"); act(D, "Share sample"); local share = s.ns.Bounty.Exchange.previewShareWin
        fits(s, share); assert(share.scroll:GetHeight() >= 60, "copy text remains scrollable")
        click(share.done)
        D.Stop()
      end
    end
    s:assertHealthy()
  end)
  t.finish("Bounty feature tour: " .. t.tests .. " scenarios")
end
