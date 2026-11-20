return function(addon)
  local t = dofile("../../tools/harness.lua")(addon .. " bounty steps")
  local fixture = dofile("../HighgroundBounties/tests/public/fixture.lua")
  local flow = dofile("../../tests/bounty_flow.lua")
  local runtime = dofile("../../tools/wowsim/battleground/runtime.lua")
  local function new(build, name, saved)
    return fixture.new(name or "Poster", { addon = addon, build = build, client = build == 40402 and "cata" or "retail", saved = saved or {},
      runtime = function(client, db, configure)
        return runtime(client, db, function(s, env)
          configure(s, env); dofile("../../tools/wowsim/geometry.lua")(s)
        end)
      end })
  end
  for _, build in ipairs({ 40402, 120100, 16001 }) do
    t.test(build .. ": three visible steps validate before posting and preserve edits", function()
      local s = new(build)
      local B = s.ns.Bounty
      local w = B.Form.Open(nil, "public")
      t.equal(w.step, 1, "target is first")
      assert(w.name:IsVisible() and not w.gold:IsVisible() and not w.review:IsVisible())
      assert(not w.steps[2]:IsEnabled() and not w.steps[3]:IsEnabled(), "cannot skip validation")
      flow.click(w.action)
      assert(w.error:GetText() ~= "" and w.step == 1 and not B.Public.Publishing())
      w.name:SetText("Enemy-Realm"); flow.click(w.action)
      t.equal(w.step, 2, "reward is second")
      assert(w.gold:IsVisible() and not w.name:IsVisible() and not w.kills:IsVisible())
      flow.click(w.action)
      assert(w.error:GetText():find("at least 1g", 1, true) and w.step == 2)
      w.gold:SetText("25"); flow.click(w.customizeButton); w.kills:SetText("3")
      flow.click(w.expiryButtons["2h"]); w.note:SetText("Watch the bridge")
      flow.click(w.action)
      t.equal(w.step, 3, "review is third")
      assert(w.review:IsVisible() and not w.gold:IsVisible() and not w.kills:IsVisible())
      t.equal(w.review.audience:GetText(), "Shared board", "audience is explicit")
      t.equal(w.review.metrics[1].value:GetText(), "3", "kill goal matches the draft")
      t.equal(w.review.metrics[2].value:GetText(), "2h", "expiry matches the draft")
      t.equal(w.review.metrics[3].value:GetText(), "75g", "maximum reward includes every kill")
      assert(w.reviewPoster:IsVisible() and w.reviewPoster.title:GetText() == "WANTED", "review uses the actual wanted poster")
      t.equal(w.reviewPoster.reward:GetText(), "25g", "poster shows the draft reward per kill")
      t.equal(w.reviewPoster.note:GetText(), "Watch the bridge", "note is previewed on the poster")
      assert(not B.Public.Own("Enemy") and not B.Public.Publishing(), "review is not a commitment")
      flow.click(w.previous); w.gold:SetText("40"); flow.click(w.action)
      t.equal(w.review.metrics[3].value:GetText(), "120g", "review reflects edits")
      t.equal(w.reviewPoster.reward:GetText(), "40g", "poster also reflects reward edits")
      t.equal(w.action:GetText(), "Enable sharing & publish", "final action explains its opt-in")
      flow.click(w.action)
      local offer = assert(B.Public.Own("Enemy"))
      t.equal(offer.gold, 40, "exact reviewed amount saved")
      t.equal(offer.killsRequired, 3, "exact reviewed goal saved")
      t.equal(fixture.count(B.Public.Data().offers), 1, "one confirmation creates one reward")
      assert(B.Public.Publishing() and not B.Public.Receiving(), "independent receiving preference retained")
      s:assertHealthy()
    end)

    t.test(build .. ": draft posters follow the target without publishing or keeping a stale portrait", function()
      local s = new(build)
      local B = s.ns.Bounty
      s.units.target = { name = "Enemy", realm = "Realm", classID = 4, enemy = true }
      local w = B.Form.Open("Enemy-Realm", "personal")
      local sent = #s.sent
      flow.click(w.action); flow.click(w.action)
      local poster = w.reviewPoster
      t.equal(poster.portrait.texture, "portrait:Enemy-Realm", "preview uses the selected target's portrait")
      t.equal(poster.reward:GetText(), "No gold reward", "tracking-only draft has no invented reward")
      t.equal(w.review.audience:GetText(), "Only me", "private audience is distinct")
      assert(not w.review.metrics[2]:IsVisible(), "private drafts do not display the shared expiry")
      t.equal(w.review.metrics[3].value:GetText(), "0g", "tracking-only draft has no gold commitment")
      flow.click(w.steps[1]); w.name:SetText("Different-Realm")
      flow.click(w.action); w.note:SetText("New note"); flow.click(w.action)
      assert(not poster.portrait:IsShown() and poster.fallback:IsShown(), "changed target clears the previous portrait")
      t.equal(poster.name:GetText(), s.ns.Core.DisplayName("Different-Realm"), "poster follows target edits")
      t.equal(poster.note:GetText(), "New note", "poster follows note edits")
      s:advance(12)
      assert(poster:IsVisible(), "inline draft never expires like a sighting alert")
      assert(next(B.Personal()) == nil and next(B.Public.Data().offers) == nil and not B.Public.Publishing(), "preview creates no bounty")
      t.equal(#s.sent, sent, "review never sends the draft or its portrait")
      s:assertHealthy()
    end)

    t.test(build .. ": step navigation and settings preserve a draft without publishing", function()
      local s = new(build)
      local B = s.ns.Bounty
      local w = B.Form.Open("Enemy", "public")
      flow.click(w.action); w.gold:SetText("50"); w.note:SetText("Keep this draft")
      flow.click(w.goldDetails); flow.click(B.GoldView.win.done)
      t.equal(w.step, 2, "settings return to the reward step")
      t.equal(w.note:GetText(), "Keep this draft", "settings keep the draft")
      flow.click(w.action); flow.click(w.steps[1])
      t.equal(w.step, 1, "completed steps can be revisited")
      flow.click(w.action); t.equal(w.gold:GetText(), "50", "going back keeps the amount")
      flow.click(w.previous); flow.click(w.cancel)
      assert(not B.Public.Publishing() and not B.Public.Own("Enemy") and next(B.Personal()) == nil, "cancel never posts")
      s:assertHealthy()
    end)

    t.test(build .. ": sharing and claiming are visible and ownership controls funding", function()
      local s, hunter = new(build), new(build, "Hunter", { bountyReceive = true })
      local B, H = s.ns.Bounty, hunter.ns.Bounty
      local original = assert(B.Public.Post("Enemy", 100, "2h", "", true))
      local w = B.Details.Open(B.BoardModel.Rows("mine")[1])
      assert(not w.more and not w.cards[1].addGold:IsVisible(), "owner has no More menu or self contribution")
      assert(flow.action(w, "Edit reward"):IsVisible())
      flow.click(flow.action(w, "Share bounty"))
      local share = B.Exchange.shareWin
      assert(share:IsVisible() and share:GetText() == share.bountyURL, "one default sharing format")
      assert(share.instructions:GetText():find("Import bounty", 1, true), "recipient action is explicit")
      assert(H.Public.Merge(B.Public.Copy(original), original.by))
      local row = H.BoardModel.Rows("public")[1]
      w = H.Details.Open(row)
      assert(w.cards[1].addGold:IsVisible(), "another player can fund it")
      flow.click(flow.action(w, "Claim reward"))
      local claim = assert(H.Ledger.ForBounty(row))
      assert(H.Ledger.win:IsVisible(), "claim opens its review status")
      local count = fixture.count(H.Public.Data().claims)
      w = H.Details.Open(row); flow.click(flow.action(w, "View report"))
      t.equal(fixture.count(H.Public.Data().claims), count, "existing claim is opened without duplication")
      t.equal(claim.claimant, H.Me(), "hunter owns the report")
      s:assertHealthy(); hunter:assertHealthy()
    end)

    t.test(build .. ": each step and its actions fit at normal and enlarged text", function()
      local s = new(build)
      local B = s.ns.Bounty
      for _, scale in ipairs({ 1, 1.5 }) do
        s.ns.Core.SetFontScale(scale)
        if s.ns.Hub then s.ns.Hub.Open("bountyboard") end
        local w = B.Form.Open("Enemy", "public")
        w.gold:SetText("50")
        w.note:SetText(string.rep("Watch the road. ", 8))
        for step = 1, 3 do
          t.equal(w.step, step, "visible step")
          for _, button in ipairs({ w.action, w.previous, w.cancel, unpack(w.steps) }) do
            if button:IsVisible() then assert(button.label:GetStringWidth() + 8 <= button:GetWidth(), "step labels fit") end
          end
          local fields, feedback = s.bounds(w.fields), s.bounds(w.error)
          local progress = s.bounds(w.stepper)
          assert(progress[2] + progress[4] + 16 <= fields[2], "all progress labels clear the form body")
          for index, button in ipairs(w.steps) do
            t.equal(button.state, index < step and "complete" or index == step and "current" or "upcoming", "progress follows the form")
          end
          assert(fields[2] + fields[4] + 2 <= feedback[2], "fields clear validation feedback")
          if step == 3 then
            local poster, summary, body = s.bounds(w.reviewPoster), s.bounds(w.review), s.bounds(w.fields.body)
            assert(poster[1] >= body[1] and poster[1] + poster[3] <= body[1] + body[3] + 0.01, "poster fits the form width")
            assert(poster[2] + poster[4] <= body[2] + body[4] + 0.01, "poster is fully reachable in the scroll body")
            assert(poster[1] + poster[3] <= summary[1] or poster[2] + poster[4] <= summary[2], "summary sits beside or below the poster")
            for _, field in ipairs({ w.reviewPoster.name, w.reviewPoster.note, w.review.audience, w.review.audienceHint,
              w.review.conditions, w.terms }) do
              assert(field:GetHeight() >= field:GetStringHeight(), "review text wraps without clipping")
            end
            local sections = { w.review.hero, w.review.stats, w.review.conditionsLabel, w.review.conditions, w.review.nextLabel, w.terms }
            for i, section in ipairs(sections) do
              local bounds = s.bounds(section)
              assert(bounds[1] >= summary[1] and bounds[1] + bounds[3] <= summary[1] + summary[3] + 0.01, "review sections fit their column")
              assert(bounds[2] + bounds[4] <= summary[2] + summary[4] + 0.01, "review height includes its last section")
              if i > 1 then
                local previous = s.bounds(sections[i - 1])
                assert(previous[2] + previous[4] <= bounds[2], "review sections do not overlap")
              end
            end
            w.fields:Scroll(10000)
            local view = s.bounds(w.fields.view)
            local last = s.bounds(w.reviewPoster)
            assert(last[2] + last[4] <= view[2] + view[4] + 0.01, "the bottom of a long poster remains reachable")
          end
          if step < 3 then flow.click(w.action) end
        end
        w:Hide()
      end
      s:assertHealthy()
    end)
  end
  t.finish()
end
