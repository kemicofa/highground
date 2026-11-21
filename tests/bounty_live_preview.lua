return function(addon)
  local t = dofile("../../tools/harness.lua")(addon .. " live bounty preview")
  local fixture = dofile("../HighgroundBounties/tests/public/fixture.lua")
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
    s:slash(addon:upper(), (addon == "HighgroundBounties" and "" or "bounty ") .. text)
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

  for _, build in ipairs({ 40402, 120100, 16001 }) do
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
