return function(addon)
  local t = dofile("../../tools/harness.lua")(addon .. " live bounty preview")
  local fixture = dofile("tests/bounties/public/fixture.lua")
  local runtime = dofile("../../tools/wowsim/battleground/runtime.lua")
  local flow = dofile("../../tests/bounty_flow.lua")
  local function new(build)
    return fixture.new("Tester", { addon = addon, build = build, client = build == 40402 and "cata" or "retail", saved = {},
      runtime = function(client, saved, configure)
        return runtime(client, saved, function(s, e)
          configure(s, e); dofile("../../tools/wowsim/geometry.lua")(s)
          s.captures = 0; e.Screenshot = function() s.captures = s.captures + 1 end
        end)
      end })
  end
  local function command(s, text)
    s:slash(addon:upper(), "bounty " .. text)
  end
  local function fit(s, w)
    assert(not w.viewport, "gameplay posters have no nested scroll area")
    assert(w:GetHeight() <= s.env.UIParent:GetHeight() - 48, "poster fits without scrolling")
    local outer = s.bounds(w)
    for _, field in ipairs({ "status", "title", "name", "reward", "location", "details", "secondaryAction", "retry", "captureStatus" }) do
      local f = w[field]
      if f and f:IsVisible() then
        local b = s.bounds(f)
        assert(b[1] >= outer[1] and b[1] + b[3] <= outer[1] + outer[3], field .. " fits horizontally")
        assert(b[2] >= outer[2] and b[2] + b[4] <= outer[2] + outer[4], field .. " fits vertically")
      end
    end
  end
  local function same(a, b)
    assert(type(a) == type(b), "saved data type unchanged")
    if type(a) ~= "table" then assert(a == b, "saved data value unchanged"); return end
    for key, value in pairs(a) do same(value, b[key]) end
    for key in pairs(b) do assert(a[key] ~= nil, "no sample records saved") end
  end

  for _, build in ipairs({ 40402, 120100, 16001 }) do
    t.test(build .. ": board refresh locks repeated requests and finishes its response window", function()
      local s = new(build)
      local B = s.ns.Bounty
      B.Board.Open(); B.Board.SetTab("public")
      local w = B.Board.win
      flow.click(w.browse)
      local attempt = assert(B.Board.refreshAttempt)
      assert(not w.sync:IsEnabled() and w.sync.busyBar:IsVisible(), "enabling browsing shares refresh feedback")
      w.sync.scripts.OnClick(w.sync); B.Board.Refresh()
      t.equal(B.Board.refreshAttempt, attempt, "duplicate clicks cannot extend the wait")
      s:advance(13)
      assert(w.sync:IsEnabled() and not w.sync.busyBar:IsShown(), "response window releases refresh even without peers")
      assert(w.viewHint:IsVisible() and w.viewHint:GetText():find("Refresh window finished", 1, true), "empty boards explain the outcome")
      flow.click(w.sync); B.Public.transportError = "Could not join the bounty channel."; B.Board.Refresh()
      assert(w.sync:IsEnabled() and not w.sync.busyBar:IsShown(), "transport errors release the control")
      flow.click(w.sync); B.Board.SetTab("mine")
      assert(not B.Board.refreshAttempt, "changing boards retires the previous response window")
      s:assertHealthy()
    end)

    t.test(build .. ": sample refresh and screenshot retry show local pending work", function()
      local s = new(build)
      local B, D = s.ns.Bounty, s.ns.Bounty.Preview
      command(s, "test board")
      local w = D.testBoard
      flow.click(w.sync)
      assert(not w.sync:IsEnabled() and w.sync.busyBar:IsVisible())
      s:advance(0.9)
      assert(w.sync:IsEnabled() and not w.sync.busyBar:IsShown(), "sample refresh completes locally")
      flow.click(w.sync); command(s, "test stop"); command(s, "test board")
      assert(w.sync:IsEnabled(), "new sample sessions never inherit pending refreshes")
      command(s, "test kill"); B.Preview.Capture("failed")
      local proof = B.Proof.previewWin
      flow.click(proof.retry); proof.retry.scripts.OnClick(proof.retry)
      assert(not proof.retry:IsEnabled() and proof.retry.busyBar:IsVisible())
      s:advance(0.4)
      assert(not proof.retry:IsEnabled(), "the initial sample completion cannot complete a retry")
      D.Capture("failed"); flow.click(proof.retry); s:advance(0.3)
      assert(not proof.retry:IsEnabled(), "an earlier retry callback cannot complete a newer retry")
      command(s, "test stop"); s:advance(1)
      assert(not proof:IsVisible(), "late retry callback cannot reopen a retired sample")
      t.equal(s.captures, 0, "sample retry never calls Screenshot")
      t.equal(#s.sent, 0, "sample refresh never sends packets")
      t.equal(#s.chat, 0, "sample refresh never sends chat")
      s:assertHealthy()
    end)

    t.test(build .. ": test opens gameplay UI with normal placement, timing and queue behavior", function()
      local s = new(build)
      local B, D = s.ns.Bounty, s.ns.Bounty.Preview
      s.units.target = { name = "Enemy", realm = "Realm", classID = 4, enemy = true }
      local b = assert(B.Add("Enemy", 500))
      B.Poster.Show(b, "Tarren Mill")
      local live = B.Poster.win
      command(s, "test")
      local w = assert(B.Poster.previewWin)
      assert(D.testing and not D.win and w:IsVisible(), "no tour shell")
      t.equal(w:GetParent(), s.env.UIParent, "popup belongs to gameplay UI")
      assert(w:IsMovable() and not w.tourDocked)
      t.equal(w:GetWidth(), live:GetWidth(), "same width as live")
      t.equal(w:GetHeight(), live:GetHeight(), "same height as live")
      local _, _, _, x, y = w:GetPoint()
      local _, _, _, lx, ly = live:GetPoint()
      t.equal(x, lx, "same horizontal placement"); t.equal(y, ly, "same vertical placement")
      assert(s.ns.Nearby.test and s.ns.Nearby.win:IsVisible(), "sample uses the actual Nearby panel")
      local remaining = w.remaining
      s.mouseOver = w; s:advance(2)
      t.close(w.remaining, remaining, "hover pauses the live timer")
      s.mouseOver = nil
      local other = B.Public.Copy(D.bounty); other.name = "Another-Realm"
      B.Poster.Show(other, "Tarren Mill", nil, true)
      t.equal(#B.Poster.previewPending, 1, "sample alerts queue")
      flow.click(w.close)
      t.equal(w.item.bounty.name, other.name, "dismiss advances the sample queue")
      w.scripts.OnDragStart(w)
      local dragged = w.remaining; s:advance(2)
      t.close(w.remaining, dragged, "dragging pauses the live timer")
      w:ClearAllPoints(); w:SetPoint("TOPRIGHT", s.env.UIParent, "TOPRIGHT", -80, -70)
      w.scripts.OnDragStop(w)
      s:advance(11); assert(not w:IsShown(), "sample expires normally")
      command(s, "test")
      assert(not D.testing and not s.ns.Nearby.test, "same command stops the session")
      t.equal(B.Personal()[B.Key("Enemy")], b, "real bounty retained")
      B.Poster.Show(b, "Tarren Mill")
      local _, _, _, savedX, savedY = live:GetPoint()
      t.equal(savedX, -80, "test dragging configures live alert placement")
      t.equal(savedY, -70, "test dragging saves the vertical position")
      s:assertHealthy()
    end)

    t.test(build .. ": guide and test retire each other's parenting and use separate sample boards", function()
      local s = new(build)
      local B, D = s.ns.Bounty, s.ns.Bounty.Preview
      command(s, "guide")
      assert(D.win:IsVisible() and B.Poster.previewWin.tourDocked)
      command(s, "test")
      assert(D.testing and not D.win:IsVisible())
      local w = B.Poster.previewWin
      assert(w:GetParent() == s.env.UIParent and w:IsMovable() and not w.tourDocked)
      flow.click(w.details)
      assert(B.Details.win:IsVisible() and B.Details.preview)
      flow.click(B.Details.win.back)
      assert(D.testBoard:IsVisible(), "View bounty returns to the real board with sample data")
      flow.click(D.testBoard.tabs.public)
      flow.click(D.testBoard.rows[1].primary)
      t.equal(D.state.interest, "tracking", "board actions update the sample")
      command(s, "test create")
      local form = B.Form.previewWin
      form.name:SetText("NewEnemy"); form.gold:SetText("25"); flow.save(form)
      assert(D.testBoard:IsVisible() and D.state.draft.gold == 25, "sample creation returns to board")
      command(s, "test kill"); s:advance(0.4)
      assert(B.Proof.previewWin.check:IsShown(), "sample screenshot result appears")
      t.equal(s.captures, 0, "preview takes no screenshots")
      command(s, "guide shared")
      assert(not D.testing and D.win:IsVisible() and not D.testBoard:IsVisible())
      command(s, "test match")
      assert(B.Matches.previewWin:GetParent() == s.env.UIParent and not B.Matches.previewWin.tourDocked)
      flow.click(B.Matches.previewWin.details)
      t.equal(D.state.interest, "tracking", "arrival action stays local")
      command(s, "test stop")
      assert(not D.scene and not B.Matches.previewWin:IsShown())
      if s.ns.Onboarding then
        local O = s.ns.Onboarding
        O.Start("bounty_hunt")
        local guideBoard = assert(B.Board.previews.Preview.win)
        assert(O.Coach.running and D.guided and guideBoard:IsVisible())
        command(s, "test board")
        assert(not O.Coach.running and not guideBoard:IsVisible(), "test retires the guided coach")
        assert(D.testBoard:IsVisible() and D.testBoard ~= guideBoard, "guide and test own separate boards")
        D.testBoard.search:SetText("No matching sample")
        command(s, "test stop"); command(s, "test board")
        t.equal(D.testBoard.search:GetText(), "", "new session starts with unfiltered samples")
        O.Start("bounty_hunt")
        assert(O.Coach.running and D.guided and not D.testing and not D.testBoard:IsVisible())
        O.StopExploring()
      end
      assert(next(B.Personal()) == nil and next(B.Public.Data().offers) == nil and next(B.Public.Data().claims) == nil)
      assert(not B.Public.Publishing() and not B.Public.Receiving())
      t.equal(#s.sent, 0, "test and guide send no addon messages")
      t.equal(#s.chat, 0, "test and guide send no chat")
      s:assertHealthy()
    end)

    t.test(build .. ": test board has distinct searchable samples, pending submissions and editable rewards", function()
      local s = new(build)
      local B, D = s.ns.Bounty, s.ns.Bounty.Preview
      assert(B.Add("RealEnemy", 25))
      local saved, network = B.Public.Copy(s.ns.Core.db), B.Public.Copy(B.Public.Data())
      local sent, chat = #s.sent, #s.chat
      command(s, "test board")
      local w = D.testBoard
      local provider = w.board.provider
      for _, tab in ipairs({ "mine", "guild", "public" }) do
        flow.click(w.tabs[tab])
        local entries, seen = provider.rows(tab), {}
        t.equal(#entries, 3, tab .. " starts with three sample cards")
        for i, entry in ipairs(entries) do
          assert(not seen[entry.name] and entry.preview, "distinct sample targets")
          seen[entry.name] = true
          t.equal(w.rows[i].entry, entry, "sample rendered in the real board")
          flow.click(w.rows[i].details)
          t.equal(D.bounty.name, entry.name, "details select the clicked target")
          t.equal(D.bounty.gold, entry.gold, "details preserve its reward")
          t.equal(D.claims[1].name, entry.name, "sample claims follow the selected target")
          if D.bounty.contributions then
            local total = 0
            for _, contribution in ipairs(D.bounty.contributions) do
              t.equal(contribution.name, entry.name, "contribution belongs to this target")
              total = total + contribution.gold
            end
            t.equal(total, entry.gold, "contributions add up to the displayed reward")
          end
          flow.click(B.Details.win.back)
        end
      end
      flow.click(w.tabs.guild); flow.click(w.review)
      t.equal(w.rows[1].entry.state, "pending", "approval filter shows pending sample")
      assert(not w.rows[2]:IsShown(), "approved samples are filtered out")
      flow.click(w.review)
      flow.click(w.tabs.mine); w.search:SetText("RoguePreview")
      t.equal(w.rows[1].entry.class, "ROGUE", "search finds the requested target")
      assert(not w.rows[2]:IsShown(), "search hides other cards")
      flow.click(w.rows[1].details)
      flow.click(flow.action(B.Details.win, "Edit reward"))
      local form = B.Form.previewWin
      form.gold:SetText("425"); flow.save(form)
      t.equal(w.rows[1].entry.gold, 425, "edited card refreshes")
      t.equal(w.rows[1].entry.class, "ROGUE", "editing preserves sample identity")
      t.equal(#provider.rows("mine"), 3, "editing replaces the sample without a duplicate")
      w.search:SetText("")
      t.equal(w.rows[1].entry.gold, 500, "other personal reward unchanged")
      flow.click(w.create)
      form.name:SetText("FreshPreview"); form.gold:SetText("55"); flow.save(form)
      assert(#provider.rows("public", "FreshPreview") == 1, "new sample is added independently")
      t.equal(provider.rows("mine", "RoguePreview")[1].gold, 425, "new draft does not overwrite the edit")
      w.search:SetText("RoguePreview"); flow.click(w.rows[1].details)
      local remove = flow.action(B.Details.win, "Remove bounty")
      flow.click(remove)
      t.equal(remove:GetText(), "Confirm removal", "sample removal uses the real confirmation")
      t.equal(#provider.rows("mine", "RoguePreview"), 1, "the first click removes nothing")
      flow.click(remove)
      t.equal(#provider.rows("mine", "RoguePreview"), 0, "confirming removes the sample from this session")
      assert(w:IsVisible() and not B.Details.win:IsShown(), "removal returns to the sample board")
      w.search:SetText("")
      command(s, "test stop"); command(s, "test board")
      t.equal(provider.rows("mine", "RoguePreview")[1].gold, 250, "new session resets sample edits")
      t.equal(#provider.rows("public"), 3, "new session discards created samples")
      command(s, "test stop")
      same(saved, s.ns.Core.db); same(network, B.Public.Data())
      t.equal(#s.sent, sent, "sample board sends no addon messages")
      t.equal(#s.chat, chat, "sample board sends no chat")
      s:assertHealthy()
    end)

    t.test(build .. ": tracking and added gold affect only the selected sample target", function()
      local s = new(build)
      local B, D = s.ns.Bounty, s.ns.Bounty.Preview
      command(s, "test board")
      local w = D.testBoard
      local provider = w.board.provider
      flow.click(w.tabs.public)
      local first, second = w.rows[2].entry, w.rows[3].entry
      flow.click(w.rows[2].primary)
      assert(first.tracking and not second.tracking, "tracking does not affect other targets")
      t.equal(#provider.rows("mine"), 4, "only the tracked target joins My bounties")
      flow.click(w.rows[3].primary)
      t.equal(#provider.rows("mine"), 5, "another target can be tracked independently")
      flow.click(w.rows[2].primary)
      assert(not first.tracking and second.tracking, "stopping one target keeps the other tracked")
      local function add(index, amount, ownGold)
        flow.click(w.rows[index].details)
        local bounty = D.bounty
        flow.click(B.Details.win.cards[1].addGold)
        local pot = B.Pot.previewWin
        t.equal(pot.ownGold, ownGold or 0, "contribution summary uses only this target's gold")
        pot.gold:SetText(tostring(amount)); flow.click(pot.add)
        t.equal(D.bounty, bounty, "added gold stays on the selected bounty")
        flow.click(B.Details.win.back)
        return bounty
      end
      local a = add(2, 100)
      local b = add(3, 200)
      add(2, 50, 100)
      t.equal(a.gold, 1050, "first target has its own increases")
      t.equal(b.gold, 1700, "second target has its own increase")
      t.equal(#a.contributions, 3, "repeat addition updates the same contribution")
      t.equal(#b.contributions, 3, "second target gets a separate contribution")
      assert(a.contributions[3] ~= b.contributions[3], "contributions are not shared between targets")
      t.equal(a.contributions[3].gold, 150, "first contribution total")
      t.equal(b.contributions[3].gold, 200, "second contribution total")
      flow.click(w.rows[2].details)
      local claims = D.claims
      claims[1].state = "rejected"
      flow.click(B.Details.win.back); flow.click(w.rows[3].details)
      assert(D.claims ~= claims and D.claims[1].state == "claimed", "claim review belongs to one target")
      flow.click(B.Details.win.back); flow.click(w.rows[2].details)
      t.equal(D.claims, claims, "returning to a target retains its claim state")
      flow.click(B.Details.win.back); flow.click(w.tabs.guild)
      local guild = add(2, 75)
      t.equal(guild.gold, 1075, "guild sample accepts added gold")
      t.equal(#guild.contributions, 2, "guild pot preserves the original and added reward")
      t.equal(guild.contributions[1].gold, 1000, "original guild reward unchanged")
      t.equal(guild.contributions[2].contract.audience, "guild", "added gold follows the guild terms")
      command(s, "test stop")
      assert(next(B.Personal()) == nil and next(B.Public.Data().offers) == nil and next(B.Public.Data().claims) == nil)
      t.equal(#s.sent, 0, "no sample traffic")
      t.equal(#s.chat, 0, "no sample chat")
      s:assertHealthy()
    end)

    t.test(build .. ": preview layouts fit small screens and enlarged text; stop leaves live alerts alone", function()
      local s = new(build)
      local B = s.ns.Bounty
      for _, screen in ipairs({ { 1024, 600 }, { 1280, 720 }, { 1920, 1080 } }) do
        s.env.UIParent:SetSize(unpack(screen))
        for _, scale in ipairs({ 0.7, 1, 1.5 }) do
          s.ns.Core.SetFontScale(scale)
          for _, key in ipairs({ "poster", "match", "kill" }) do
            command(s, "test " .. key)
            fit(s, key == "poster" and B.Poster.previewWin or key == "match" and B.Matches.previewWin or B.Proof.previewWin)
            if key == "kill" then B.Preview.Capture("failed"); fit(s, B.Proof.previewWin) end
          end
        end
      end
      s.ns.Core.SetFontScale(0.7)
      command(s, "test kill")
      local width = B.Proof.previewWin:GetWidth()
      s.ns.Core.SetFontScale(1.5)
      assert(B.Proof.previewWin:GetWidth() > width, "visible kill preview follows text-size changes")
      fit(s, B.Proof.previewWin)
      s.env.UIParent:SetSize(1024, 600)
      B.Preview.bounty.name = "Twelvenamesss-ARealmWithAVeryLongName"
      B.Preview.bounty.gold = B.MAX_GOLD
      B.Preview.Capture("failed")
      fit(s, B.Proof.previewWin)
      assert(B.Proof.previewWin.name:GetHeight() >= B.Proof.previewWin.name:GetStringHeight(), "long realm stays readable")
      local b = assert(B.Add("RealEnemy", 500))
      B.Poster.Show(b, "Tarren Mill")
      local live = B.Poster.win
      command(s, "test stop")
      assert(live:IsShown() and live.item.bounty == b, "stopping samples preserves live alert")
      s:setCombat(true); command(s, "test")
      assert(not B.Preview.testing, "secure previews do not start in combat")
      s:setCombat(false); command(s, "test"); s:setCombat(true)
      assert(not B.Preview.testing, "combat retires the sample session")
      s:setCombat(false); s:assertHealthy()
    end)
  end
  t.finish("Live bounty previews: " .. t.tests .. " scenarios")
end
