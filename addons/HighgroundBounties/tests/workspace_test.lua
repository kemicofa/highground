local t = dofile("../../tools/harness.lua")("bounty workspace")
local F = dofile("tests/public/fixture.lua")
local function Click(button) assert(button.scripts.OnClick)(button) end
local function Make(addon, client, build)
  local runtime = dofile("../../tools/wowsim/" .. (addon == "Highground" and "battleground/" or "") .. "runtime.lua")
  return F.new("Hunter", { addon = addon, client = client, build = build, saved = {}, runtime = function(game, saved, configure)
    return runtime(game, saved, function(s, e) dofile("../../tools/wowsim/geometry.lua")(s); configure(s, e) end)
  end })
end

local function Page(s, w)
  local board = s.ns.Bounty.Board.win
  t.equal(board.page, w, "active bounty page")
  t.equal(w:GetParent(), board, "page belongs to the board")
  assert(w:IsVisible() and not board.browser:IsVisible(), "one bounty surface is visible")
  t.equal(w.close:IsShown(), board:IsMovable(), "embedded pages use the hub close button")
  local a, b = s.bounds(w), s.bounds(board)
  for i = 1, 4 do assert(math.abs(a[i] - b[i]) < 0.01, "page keeps the board bounds") end
end

for _, addon in ipairs({ "Highground", "HighgroundBounties", "HighgroundNearby" }) do
  for _, client in ipairs({ { "retail", 120100 }, { "retail", 16001 }, { "cata", 40402 } }) do
    t.test(addon .. " " .. client[2] .. ": first bounty explains the workflow and returns to the same workspace", function()
      local s = Make(addon, client[1], client[2])
      local B = s.ns.Bounty
      if s.ns.Hub then s.ns.Hub.Open("bountyboard") else B.Board.Open() end
      local w = B.Board.win
      assert(w.guide:IsVisible() and w.create:IsVisible() and w.explore:IsVisible(), "empty board has useful starting actions")
      assert(not w.search:IsVisible() and not w.next:IsVisible(), "no empty search or pagination")
      assert(not w.tabs.suggestions:IsVisible(), "suggestions are secondary")
      assert(w.guide.steps[3].body:GetText():find("Claims & payments", 1, true), "reward flow explained before posting")
      Click(w.create)
      local form = B.Form.win
      Page(s, form)
      t.equal(form.formMode, "personal", "first bounty starts private")
      form.name:SetText("Rival-Other"); Click(form.action)
      t.equal(B.Personal()["rival-other"].gold, 0, "private tracking needs no gold")
      assert(not form:IsVisible() and w.browser:IsVisible(), "save returns to the list")
      assert(w.viewHint:GetText():find("Private bounty saved", 1, true), "save explains what happens next")
      assert(not B.Public.Publishing() and not B.Public.Receiving(), "private creation never opts into sharing")
      w.search:SetText("Rival")
      Click(w.rows[1].details); Page(s, B.Details.win); Click(B.Details.win.back)
      t.equal(w.search:GetText(), "Rival", "back keeps the search")
      Click(w.help)
      assert(w.guide:IsVisible() and not w.rows[1]:IsVisible(), "help replaces the list in place")
      Click(w.help)
      assert(w.rows[1]:IsVisible() and w.search:GetText() == "Rival", "help returns to the same results")
      Click(w.alerts)
      local menu = s.ns.Kit.Dropdown.Frame()
      t.equal(menu.items[1].text, "Bounty suggestions", "suggestions remain discoverable")
      Click(menu.rows[1])
      t.equal(B.Board.tab, "suggestions", "tools open suggestions")
      s:assertHealthy()
    end)
  end

  t.test(addon .. ": empty boards explain membership, opt-ins and search without changing a draft", function()
    local s = Make(addon, "retail")
    local B = s.ns.Bounty
    B.Board.Open()
    local w = B.Board.win
    Click(w.explore)
    assert(w.browse:IsVisible() and w.empty:GetText():find("private targets stay private", 1, true), "shared opt-in is explained")
    Click(w.create)
    local form = B.Form.win
    t.equal(form.formMode, "public", "shared creation uses the correct audience")
    form.name:SetText("Draft"); form.gold:SetText("500"); Click(form.cancel)
    assert(not B.Public.Publishing() and not B.Public.Receiving() and not B.Public.Own("Draft"), "back discards without opting in")
    Click(w.browse)
    assert(B.Public.Receiving() and not B.Public.Publishing(), "browsing only enables receiving")
    assert(not w.browse:IsVisible() and w.sync:IsVisible(), "waiting board offers refresh")
    assert(w.guide.title:GetText():find("Waiting", 1, true), "empty network is not described as disabled")
    B.Board.SetTab("guild")
    assert(w.empty:GetText():find("Join a guild", 1, true), "missing membership is explained")
    Click(w.create)
    t.equal(form.formMode, "personal", "no-guild fallback creates a private target")
    form.name:SetText("Rival"); Click(form.action)
    w.search:SetText("Missing")
    assert(w.emptyAction:IsVisible() and not w.rows[1]:IsVisible(), "no matches offers a clear search action")
    Click(w.emptyAction)
    assert(w.rows[1]:IsVisible(), "clearing search restores the bounty")
    s:assertHealthy()
  end)

  t.test(addon .. ": hunters can read, report and follow a reward in the same window", function()
    local s, poster = Make(addon, "cata"), F.new("Poster", { client = "cata" })
    local B = s.ns.Bounty
    s.ns.Core.SetOption("bountyReceive", true)
    B.Public.TransportTick()
    local offer = F.post(poster, "Rival-Other", 500)
    F.P(poster).QueueOffer(offer, B.Me()); F.deliver(poster, s)
    B.Board.SetTab("public"); B.Board.Open()
    local w = B.Board.win
    w.search:SetText("Rival")
    assert(w.rows[1]:IsVisible(), "received reward is visible; offers=" .. F.count(B.Public.Data().offers))
    assert(not w.rows[1].primary:IsVisible(), "hunter has one clear View bounty action: " .. w.rows[1].primary:GetText())
    Click(w.rows[1].details)
    local details = B.Details.win
    Page(s, details)
    t.equal(details.actions[1]:GetText(), "Report kill", "hunter's first action reports the kill")
    t.equal(details.actions[2]:GetText(), "Add a reward", "funding a bounty is a separate action")
    Click(details.actions[1])
    t.equal(F.count(B.Public.Data().claims), 1, "report is recorded once")
    Click(details.actions[3]); Page(s, B.Ledger.win)
    assert(not details:IsVisible(), "claims replaces details")
    assert(not B.Ledger.win.actions[1]:IsEnabled(), "hunter cannot approve their own report")
    Click(B.Ledger.win.back)
    t.equal(B.Board.tab, "public", "claims returns to the shared board")
    t.equal(w.search:GetText(), "Rival", "claims keeps the original query")
    t.equal(s.money, 100000000, "reports never move gold")
    B.Preferences.Open(); Page(s, B.Preferences.win)
    w:Hide()
    assert(not B.Preferences.win:IsVisible() and not w.page, "closing the workspace leaves no detached page")
    B.Board.Open()
    assert(w.browser:IsVisible(), "reopening returns to a usable board")
    s:assertHealthy()
  end)

  t.test(addon .. ": workspace pages fit every theme at ordinary and enlarged text", function()
    local s = Make(addon, "retail")
    local B = s.ns.Bounty
    if s.ns.Hub then s.ns.Hub.Open("bountyboard") else B.Board.Open() end
    local w = B.Board.win
    local function Fits(button)
      assert(button.label:GetStringWidth() + 8 <= button:GetWidth(), button:GetText() .. " fits")
    end
    for _, theme in ipairs({ "highground", "ember", "parchment", "azeroth" }) do
      s.ns.Theme.Use(theme)
      for _, scale in ipairs({ 1, 1.5 }) do
        s.ns.Core.SetFontScale(scale)
        for _, button in ipairs({ w.create, w.explore, w.alerts, w.claims, w.help }) do Fits(button) end
        local claims, help = s.bounds(w.claims), s.bounds(w.help)
        assert(claims[1] + claims[3] + 4 <= help[1], "footer actions stay separate")
        local form = B.Form.Open("Rival", "public")
        Page(s, form)
        for _, button in ipairs({ form.cancel, form.action, form.target }) do Fits(button) end
        assert(form.fields.view:GetHeight() > 140, "draft has a usable scrolling viewport")
        local fields, error = s.bounds(form.fields), s.bounds(form.error)
        assert(fields[2] + fields[4] + 2 <= error[2], "fields clear validation feedback")
        local back, action = s.bounds(form.cancel), s.bounds(form.action)
        assert(back[1] + back[3] + 8 <= action[1], "back and save never overlap")
        form.note:SetFocus()
        local note, viewport = s.bounds(form.note), s.bounds(form.fields.view)
        assert(note[2] >= viewport[2] and note[2] + note[4] <= viewport[2] + viewport[4], "keyboard focus keeps the note visible")
        form.fields:Scroll(form.fields.range)
        local terms, view = s.bounds(form.terms), s.bounds(form.fields.view)
        assert(terms[2] + terms[4] <= view[2] + view[4], "all instructions remain reachable by scrolling")
        Click(form.cancel)
        local prefs = B.Preferences.Open(); Page(s, prefs); Fits(prefs.done); Click(prefs.done)
        local ledger = B.Ledger.Open(); Page(s, ledger); Fits(ledger.back)
        assert(ledger.emptyGuide:IsVisible() and not ledger.search:IsVisible() and not ledger.actions[1]:IsVisible(), "empty claims explains the next action without unused controls")
        for _, row in ipairs(ledger.rows) do assert(not row:IsVisible(), "empty claims has no blank rows") end
        Click(ledger.back)
      end
    end
    s:assertHealthy()
  end)
end
t.finish("Bounty workspace: " .. t.tests .. " scenarios")
