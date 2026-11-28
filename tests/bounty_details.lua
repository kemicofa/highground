-- Poster cards and native portrait lifecycles through every consuming TOC.
return function(addon)
  local t = dofile("../../tools/harness.lua")(addon .. " bounty details")
  local new = dofile("../../tools/wowsim/battleground/runtime.lua")
  local function setup(build, saved)
    return new(build == 40402 and "cata" or "retail", saved or {}, function(s, env)
      s.addon = addon
      s.manifest = addon .. (build == 40402 and "_Cata" or "") .. ".toc"
      env.GetBuildInfo = function() return "test", "1", "", build end
      env.GetMoney = function() return 100000000 end
      env.UnitIsPlayer = function(unit)
        return s.units[unit] and s.units[unit].isPlayer ~= false or false
      end
      dofile("../../tools/wowsim/geometry.lua")(s)
    end)
  end
  local function open(B, name, scope)
    for _, row in ipairs(B.BoardModel.Rows(scope or "mine")) do
      if B.Key(row.name) == B.Key(name) then return B.Details.Open(row) end
    end
    error("No bounty row for " .. name)
  end
  local function countText(s, root, text)
    local count = 0
    for _, f in ipairs(s.frames) do
      if f.kind == "FontString" and f:IsVisible() and f:GetText() == text then
        local parent = f.parent
        while parent and parent ~= root do parent = parent.parent end
        if parent == root then count = count + 1 end
      end
    end
    return count
  end
  local function click(button) button.scripts.OnClick(button) end
  local function fits(s, card, fields)
    local outer, sections = s.bounds(card), {}
    for _, key in ipairs(fields) do
      local f = card[key]
      if f and f:IsShown() then
        local box = s.bounds(f)
        assert(box[1] >= outer[1] and box[1] + box[3] <= outer[1] + outer[3], key .. " fits card width")
        assert(box[2] >= outer[2] and box[2] + box[4] <= outer[2] + outer[4], key .. " fits card height")
        for _, previous in ipairs(sections) do
          assert(box[1] >= previous[1] + previous[3] or previous[1] >= box[1] + box[3]
            or box[2] >= previous[2] + previous[4] or previous[2] >= box[2] + box[4], key .. " does not overlap other content")
        end
        if f.kind == "FontString" then assert(f:GetHeight() >= f:GetStringHeight(), key .. " is not clipped") end
        sections[#sections + 1] = box
      end
    end
  end

  for _, build in ipairs({ 40402, 120100, 16001 }) do
    t.test(build .. ": board posters align names, portraits, rewards and footers despite different content", function()
      local s = setup(build)
      local B = s.ns.Bounty
      B.Preview.Command("board")
      local w = B.Preview.testBoard
      click(w.rows[1].details)
      assert(not B.Details.win.nextStep:IsShown(), "a fresh sample does not show claim-review instructions")
      click(B.Details.win.back)
      local entries = w.board.provider.rows("mine")
      entries[2].name = "Twelvenamesss-ARealmWithAVeryLongName"
      entries[2].gold = B.MAX_GOLD
      entries[3].location = "Last seen · A long location that needs more than one line"
      -- One tracked shared target needs an extra action alongside private cards.
      local shared = w.board.provider.rows("public")[1]
      B.Preview.state.interests = { [B.Key(shared.name)] = "tracking" }
      for _, scale in ipairs({ 0.8, 1, 1.5 }) do
        s.ns.Core.SetFontScale(scale)
        for _, width in ipairs({ 760, 560 }) do
          w:SetWidth(width)
          for _, theme in ipairs(s.ns.Theme.Names()) do
            s.ns.Theme.Use(theme); w.board.Refresh()
            local previous
            for _, card in ipairs(w.rows) do
              if card:IsShown() then
                fits(s, card, { "title", "status", "portraitWell", "name", "rewardLabel", "reward", "trackingLabel", "location", "rule", "details", "primary" })
                if previous and s.bounds(previous)[2] == s.bounds(card)[2] then
                  for _, key in ipairs({ "portraitWell", "name", "reward", "details" }) do
                    t.close(s.bounds(previous[key])[2], s.bounds(card[key])[2], key .. " aligns across neighbouring cards")
                  end
                  t.close(previous:GetHeight(), card:GetHeight(), "same outer height")
                end
                previous = card
              end
            end
          end
        end
      end
      s:assertHealthy()
    end)

    t.test(build .. ": actions stay fixed and native resize callbacks cannot pull the reader off the bottom", function()
      local s = setup(build, { bountyAnnounce = false })
      local B = s.ns.Bounty
      s.env.UIParent:SetSize(1024, 600)
      B.Add("Enemy", 500, string.rep("Watch the bridge. ", 12))
      local w = open(B, "Enemy")
      local function fire(frame, event)
        if frame.scripts[event] then frame.scripts[event](frame) end
        for _, hook in ipairs(frame.hooks[event] or {}) do hook(frame) end
      end
      for _, method in ipairs({ "SetWidth", "SetHeight", "SetSize" }) do
        local original = w.body[method]
        w.body[method] = function(self, ...)
          local width, height = self:GetWidth(), self:GetHeight()
          original(self, ...)
          if width ~= self:GetWidth() or height ~= self:GetHeight() then fire(self, "OnSizeChanged") end
        end
      end
      for _, scale in ipairs({ 1, 1.5 }) do
        s.ns.Core.SetFontScale(scale)
        for _, offset in ipairs({ 0, 100000 }) do
          w.area:Scroll(offset)
          local position = w.area.offset
          for _ = 1, 3 do B.Emit("updated") end
          t.close(w.area.offset, position, "background refresh preserves scroll position")
          t.close(w.scroll:GetVerticalScroll(), position, "native viewport agrees")
          local view, outer = s.bounds(w.scroll), s.bounds(w)
          for _, button in ipairs(w.actions) do
            if button:IsVisible() then
              local box = s.bounds(button)
              assert(box[2] >= outer[2] and box[2] + box[4] <= outer[2] + outer[4], "every action stays inside the window")
              assert(box[1] >= outer[1] and box[1] + box[3] <= outer[1] + outer[3], "every action fits the window width")
              assert(box[2] + box[4] <= view[2] or box[2] >= view[2] + view[4], "actions stay outside the scrolling content")
            end
          end
        end
        w.scroll.scripts.OnMouseWheel(w.scroll, -1000)
        local bottom = w.area.offset
        w.scroll.scripts.OnMouseWheel(w.scroll, -1); B.Details.Refresh()
        t.close(w.area.offset, bottom, "scrolling beyond the bottom never wraps to the top")
      end
      B.Add("Another", 50); open(B, "Another")
      t.equal(w.area.offset, 0, "opening a different bounty starts at its identity")
      B.Remove("Another"); B.Emit("updated")
      assert(w.area.offset <= w.area.range, "removing content still clamps to the new range")
      s:assertHealthy()
    end)

    t.test(build .. ": a personal poster shows one reward and keeps only the matching portrait", function()
      local s = setup(build, { bountyAnnounce = false })
      local B = s.ns.Bounty
      s.units.target = { name = "Nightshade", realm = "Other", classID = 4, enemy = true }
      assert(B.Add("Nightshade-Other", 500, "Watch the road"))
      local w = open(B, "Nightshade-Other")
      local card = w.cards[1]
      assert(w:GetWidth() <= 540 and card:GetWidth() <= w.body:GetWidth(), "single reward fits the compact details page")
      assert(card.compact and not card.viewport and not w.target:IsShown(), "single reward has one compact target summary")
      assert(card.title:IsShown() and card.portraitWell:GetWidth() >= 128, "details have a prominent wanted heading and portrait")
      t.equal(card.title:GetText(), "WANTED", "poster heading")
      t.equal(countText(s, w, "500g"), 1, "reward appears once on the entire details page")
      assert(not w.reward:IsShown(), "no duplicate total for a single reward")
      t.equal(card.note:GetText(), "Watch the road", "note is on the poster")
      t.equal(card.portrait.texture, "portrait:Nightshade-Other", "actual selected enemy portrait")
      assert(card.portrait:IsShown() and not card.fallback:IsShown(), "portrait replaces class icon")
      s.units.target = { name = "Nightshade", classID = 8, enemy = true }
      s:event("UNIT_PORTRAIT_UPDATE", "target"); B.Details.Refresh()
      t.equal(card.portrait.texture, "portrait:Nightshade-Other", "same name on a different realm cannot replace the likeness")
      s:advance(11)
      assert(w:IsVisible() and card:IsShown(), "details cards do not inherit the popup expiry")
      assert(B.Add("Unseen-Other", 250))
      open(B, "Unseen-Other")
      assert(card.fallback:IsShown() and not card.portrait:IsShown(), "recycled card clears the previous enemy")
      t.equal(card.portrait.texture, nil, "old portrait texture cleared")
      s.units.target = { name = "Unseen", realm = "Other", classID = 8, enemy = true, modelReady = false }
      s:event("PLAYER_TARGET_CHANGED")
      assert(not card.portrait:IsShown(), "waits for model readiness")
      s.units.target.modelReady = true; s:advance(0.6)
      t.equal(card.portrait.texture, "portrait:Unseen-Other", "open details gain a late portrait without another event")
      B.Remove("Unseen-Other"); B.Emit("updated")
      assert(not card:IsShown(), "removed bounty clears its card")
      s:assertHealthy()
    end)

    t.test(build .. ": shared posters keep each amount, note, funding and expiry distinct", function()
      local s = setup(build, { bountyReceive = true, bountyPublish = true, bountyAnnounce = false })
      local B, P = s.ns.Bounty, s.ns.Bounty.Public
      local offer = assert(P.Post("Shared-Other", 500, "2h", "First poster's terms"))
      s.units.nameplate87 = { name = "Shared", realm = "Other", classID = 4, enemy = true }
      s:event("NAME_PLATE_UNIT_ADDED", "nameplate87")
      local w = open(B, "Shared-Other", "public")
      t.equal(countText(s, w, "500g"), 1, "single shared reward appears once")
      t.equal(w.cards[1].portrait.texture, "portrait:Shared-Other", "remembered observed token supplies the portrait")
      t.equal(w.cards[1].class:GetText(), s.ns.Util.ClassName("ROGUE"), "shared card learns the observed player's class")
      local other = P.Copy(offer)
      other.id, other.contributor, other.by = "other-offer", "other-account", "Hunter-Realm"
      other.gold, other.note, other.expiresAt = 250, "Second poster's terms", offer.expiresAt + 7200
      assert(P.Merge(other, other.by)); B.Details.Refresh()
      t.equal(w.reward:GetText(), "Total pledged: 750g", "aggregate is clearly labelled")
      t.equal(countText(s, w, "500g"), 1, "first reward is not repeated")
      t.equal(countText(s, w, "250g"), 1, "second reward is not repeated")
      for i, amount in ipairs({ 500, 250 }) do
        local card = w.cards[i]
        assert(card:IsShown(), "each contribution has a card")
        t.equal(card.reward:GetText(), amount .. "g", "individual reward")
        local facts = {}
        for _, row in ipairs(card.factRows) do if row.value:IsShown() then facts[row.label:GetText()] = row.value:GetText() end end
        t.equal(facts.FUNDS, "Reported available", "funding status kept")
        assert(facts.EXPIRES and facts.EXPIRES:find(" left", 1, true), "expiry kept")
        assert(not card.portraitWell:IsShown() and not card.name:IsShown(), "contributions do not repeat target identity")
      end
      assert(w.target:IsShown(), "shared target identity appears once")
      t.equal(w.target.portrait.texture, "portrait:Shared-Other", "target header shows the actual enemy")
      t.equal(w.cards[2].note:GetText(), other.note, "contributor's own note")
      assert(P.Withdraw(offer)); B.Details.Refresh()
      assert(not w.cards[2]:IsShown() and not w.reward:IsShown(), "return to one card also removes total")
      t.equal(countText(s, w, "250g"), 1, "remaining contribution appears once")
      t.equal(countText(s, w, "500g"), 0, "withdrawn reward is absent")
      s:assertHealthy()
    end)

    t.test(build .. ": previews use a labelled selected or self portrait without placing a bounty", function()
      local s = setup(build)
      local B = s.ns.Bounty
      local sent = #s.sent
      s.units.target = { name = "Selected", realm = "Other", classID = 4, enemy = true }
      B.Preview.Select("nearby")
      local popup = B.Poster.previewWin
      t.equal(popup.portrait.texture, "portrait:Selected-Other", "selected player's real portrait in sample")
      t.equal(popup.likeness:GetText(), "SELECTED CHARACTER · SAMPLE", "selected sample labelled")
      click(popup.details)
      local w = B.Details.win
      t.equal(w.cards[1].portrait.texture, "portrait:Selected-Other", "details use the same sample identity")
      t.equal(countText(s, w, "500g"), 1, "sample page also avoids repeated rewards")
      for _, button in ipairs(w.actions) do assert(not button:IsShown(), "sample has no real bounty actions") end
      B.Preview.Stop(); s.units.target = { name = "Guard", isPlayer = false }
      B.Preview.Select("nearby")
      t.equal(popup.portrait.texture, "portrait:Me-Realm", "NPC selection uses own character")
      t.equal(popup.likeness:GetText(), "YOUR CHARACTER · SAMPLE", "self sample labelled")
      B.Preview.Stop(); s.units.target = nil; B.Preview.Select("nearby")
      t.equal(popup.portrait.texture, "portrait:Me-Realm", "no selection uses own character")
      B.Preview.Stop()
      assert(next(B.Personal()) == nil and next(B.Guild()) == nil, "no actual bounties placed")
      assert(next(B.Public.Data().offers) == nil and next(B.Public.Data().claims) == nil, "no shared records")
      t.equal(#s.sent, sent, "preview sends no messages")
      s:assertHealthy()
    end)
  end

  t.test("reused poster text grows instead of retaining a native font string's old clipping height", function()
    local s = setup(120100)
    local B = s.ns.Bounty
    B.Add("Enemy", 500, "Short note")
    local w = open(B, "Enemy")
    local note, original = w.cards[1].note, w.cards[1].note.GetStringHeight
    note.GetStringHeight = function(self)
      local height = original(self)
      return self:GetHeight() > 0 and math.min(self:GetHeight(), height) or height
    end
    local text = string.rep("A longer note must remain readable when the same poster is refreshed. ", 8)
    B.Personal()[B.Key("Enemy")].note = text; B.Details.Refresh()
    t.equal(note:GetText(), text, "all of the note is retained")
    assert(note:GetHeight() >= original(note), "natural text height is measured before clamping")
    for _, scale in ipairs({ 1, 1.5 }) do
      s.env.UIParent:SetSize(1024, 600); s.ns.Core.SetFontScale(scale)
      assert(w:GetHeight() <= 552, "the poster remains inside a short screen")
      fits(s, w.cards[1], { "title", "status", "portraitWell", "name", "class", "rewardLabel", "reward", "rule", "killProgress", "note", "owner", "location", "detail" })
      w.scroll.scripts.OnMouseWheel(w.scroll, -1000)
      local area, last = s.bounds(w.scroll), s.bounds(w.cards[1].detail)
      assert(last[2] + last[4] <= area[2] + area[4] + 1, "all bounty details remain reachable")
    end
    s:assertHealthy()
  end)

  t.test("contribution rows and scroll stay usable with enlarged text in every theme", function()
    local s = setup(120100, { bountyReceive = true, bountyPublish = true })
    local B, P = s.ns.Bounty, s.ns.Bounty.Public
    s.env.GetMoney = function() return B.MAX_GOLD * 10000 end
    local offer = assert(P.Post("Longname-Otherrealm", B.MAX_GOLD, "2h", "Watch this road and report the kill."))
    local other = P.Copy(offer)
    other.id, other.contributor, other.by = "other-offer", "other-account", "Hunter-Realm"
    assert(P.Merge(other, other.by))
    local w = open(B, "Longname-Otherrealm", "public")
    for _, scale in ipairs({ 0.8, 1, 1.5 }) do
      s.ns.Core.SetFontScale(scale)
      for _, theme in ipairs(s.ns.Theme.Names()) do
        s.ns.Theme.Use(theme)
        B.Details.Refresh()
        local first, second, body = s.bounds(w.cards[1]), s.bounds(w.cards[2]), s.bounds(w.body)
        assert(first[1] + first[3] + 8 <= second[1] or first[2] + first[4] + 8 <= second[2], "cards never overlap")
        for _, card in ipairs(w.cards) do
          local outer, sections = s.bounds(card), {}
          assert(card.compact and card.contribution, "contributions use compact rows")
          assert(outer[1] >= body[1] and outer[1] + outer[3] <= body[1] + body[3], "cards fit page width")
          for _, f in ipairs({ card.status, card.title, card.portraitWell, card.likeness, card.name, card.class,
            card.rewardLabel, card.reward, card.note, card.owner, card.detail }) do
            if f:IsShown() then
              local b = s.bounds(f)
              assert(b[1] >= outer[1] and b[1] + b[3] <= outer[1] + outer[3], "content fits card width")
              assert(b[2] >= outer[2] and b[2] + b[4] <= outer[2] + outer[4], "content fits card height")
              for _, previous in ipairs(sections) do
                assert(b[1] >= previous[1] + previous[3] or previous[1] >= b[1] + b[3]
                  or b[2] >= previous[2] + previous[4] or previous[2] >= b[2] + b[4], "poster sections never overlap")
            end
            sections[#sections + 1] = b
            if f.GetStringHeight then assert(f:GetHeight() >= f:GetStringHeight(), "full poster text remains readable") end
            end
          end
          assert(card.reward:GetStringWidth() <= card.reward:GetWidth(), "maximum reward fits")
        end
        local context, total = s.bounds(w.context), s.bounds(w.reward)
        assert(context[1] + context[3] <= total[1], "header labels never overlap")
        w.scroll.scripts.OnMouseWheel(w.scroll, -1000)
        t.close(w.scroll:GetVerticalScroll(), math.max(0, w.body:GetHeight() - w.scroll:GetHeight()), "can reach all cards and terms")
        w.scroll.scripts.OnMouseWheel(w.scroll, 1000)
        t.equal(w.scroll:GetVerticalScroll(), 0, "can return to first card")
      end
    end
    s:assertHealthy()
  end)
  t.finish("Bounty details: " .. t.tests .. " scenarios")
end
