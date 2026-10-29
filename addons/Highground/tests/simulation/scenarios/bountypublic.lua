local test, new, equal = ...
for _, client in ipairs({ "cata", "retail" }) do
  test(client .. " Use target copies players regardless of hostility and preserves the bounty draft", function()
    local s = new(client, nil, function(sim)
      sim.env.UnitIsPlayer = function(unit)
        local target = sim.units[unit]
        return target and target.isPlayer ~= false and (client == "cata" and 1 or true) or false
      end
    end)
    local B = s.ns.Bounty
    local w = B.Form.Open("Draft-Other", "public")
    w.gold:SetText("500"); w.note:SetText("Keep this note"); w.duration:SetText("2h")
    local function Click() w.target.scripts.OnClick(w.target) end
    for _, target in ipairs({
      { name = "Friendly", realm = "Other Realm", enemy = false },
      { name = "Unflagged", enemy = false },
      { name = "Enemy", realm = "Other", enemy = true },
      { name = "DeadPlayer", realm = "Other", enemy = false, dead = true },
    }) do
      s.units.target = target; Click()
      equal(w.name:GetText(), target.name .. "-" .. (target.realm or "Realm"):gsub("%s", ""), "exact selected player copied")
      equal(w.error:GetText(), "", "valid player clears feedback")
    end
    local selected = w.name:GetText()
    local function Invalid(target, message)
      s.units.target = target; Click()
      assert(w.error:GetText():find(message, 1, true), "invalid selection explains what happened")
      equal(w.name:GetText(), selected, "invalid selection keeps the previous name")
    end
    Invalid(nil, "Select a player first")
    Invalid({ name = "Guard", isPlayer = false }, "not a player")
    Invalid({ name = "Pet", isPlayer = false }, "not a player")
    Invalid(s.units.player, "Select another player")
    Invalid({ name = "", enemy = true }, "name is unavailable")
    equal(w.gold:GetText(), "500", "reward retained")
    equal(w.note:GetText(), "Keep this note", "note retained")
    equal(w.duration:GetText(), "2h", "duration retained")
    equal(w.formMode, "public", "audience retained")
    assert(not B.Public.Publishing() and next(B.Public.Data().offers) == nil, "copying never opts in or publishes")
    s.units.target = { name = "Ready", enemy = false }; Click()
    equal(w.name:GetText(), "Ready-Realm", "next valid target works")
    equal(w.error:GetText(), "", "old error cleared")
    w:Hide(); B.Form.Open()
    equal(w.name:GetText(), "Ready-Realm", "creation also prefills friendly players")
    s:assertHealthy()
  end)
end

test("Highground offers shared bounties through the same board and command service", function()
  local s = new("retail", nil, function(sim)
    sim.env.GetMoney = function() return 10000000 end
    sim.env.GetServerTime = function() return math.floor(100000 + sim.now) end
  end)
  s:command("bounty shared publish on")
  s:command("bounty shared add 500 2h Enemy-Realm")
  local P = s.ns.Bounty.Public
  assert(P.Own("Enemy-Realm"), "public contribution created")
  s:command("bounty shared")
  equal(s.ns.Bounty.Board.tab, "public", "shared board tab")
  assert(s.ns.Bounty.Board.win:IsShown())
  s:command("bounty shared threshold 800")
  equal(s.ns.Core.O("bountyMinGold"), 800, "shared settings")
  s.ns.Hub.Open("bounty")
  s:assertHealthy()
end)

test("bounty overview and claims stay above the embedded board with direct action paths", function()
  local s = new("cata", { bountyPublish = true, bountyReceive = true }, function(sim)
    dofile("../../tools/wowsim/geometry.lua")(sim)
    sim.env.GetMoney = function() return 100000000 end
    local methods = getmetatable(sim.env.UIParent).__index
    methods.SetBackdropColor = function(frame, ...) frame.backdropColor = { ... } end
  end)
  local B, steps = s.ns.Bounty, 0
  local function Click(button) steps = steps + 1; button.scripts.OnClick(button) end
  assert(B.Add("Private-Other", 100, "Watch this target"))
  s.ns.Hub.Open("bountyboard")
  local board = B.Board.win
  equal(board:GetParent(), s.ns.Hub.content, "board remains embedded")
  Click(board.rows[1].primary)
  B.Form.win.gold:SetText("150"); Click(B.Form.win.action)
  equal(steps, 2, "editing and saving needs two actions")
  equal(B.Personal()[B.Key("Private-Other")].gold, 150, "direct edit saved")

  steps = 0; Click(board.rows[1].details)
  local overview = B.Details.win
  equal(steps, 1, "one action opens the complete overview")
  equal(overview.target:GetText(), "Private-Other", "selected target is clear")
  assert(overview.cards[1].detail:GetText():find("Watch this target", 1, true), "note visible without selecting a second list")
  equal(overview:GetFrameStrata(), "FULLSCREEN_DIALOG", "overview is above board children")
  equal(overview.backdropColor[4], 1, "overview backdrop is opaque")
  equal(overview:GetAlpha(), 1, "overview entrance cannot reveal board text")
  Click(overview.actions[1])
  equal(steps, 2, "editor remains one action from the overview")
  assert(B.Form.win:IsShown() and not overview:IsShown(), "editor replaces overview")
  Click(B.Form.win.cancel)

  local personal = B.Personal()[B.Key("Private-Other")]
  local claim = B.Ledger.Record(personal, B.Me())
  steps = 0; Click(board.claims)
  local ledger = B.Ledger.win
  equal(ledger:GetFrameStrata(), "FULLSCREEN_DIALOG", "claims is above board children")
  equal(ledger.backdropColor[4], 1, "claims backdrop is opaque")
  equal(ledger:GetAlpha(), 1, "claims entrance cannot reveal board text")
  Click(ledger.actions[1])
  equal(steps, 2, "opening claims and reviewing the selected claim needs two actions")
  equal(claim.state, "approved", "claim reviewed")
  Click(ledger.close)

  assert(B.Public.Post("Shared-Other", 500, "2h", "Your offer"))
  local other = B.Public.Copy(B.Public.Own("Shared-Other"))
  other.id, other.contributor, other.by, other.note = "other-pledge", "other-account", "Poster-Other", "Another offer"
  assert(B.Public.Merge(other, other.by))
  B.Board.SetTab("public")
  steps = 0; Click(board.rows[1].details)
  equal(overview.reward:GetText(), "1000g", "combined total matches this board")
  assert(overview.cards[1]:IsShown() and overview.cards[2]:IsShown(), "both contributors visible without another selection")
  Click(overview.actions[2])
  equal(steps, 2, "reporting a shared kill requires two actions")
  local sent = 0; for _ in pairs(B.Public.Data().claims) do sent = sent + 1 end
  equal(sent, 1, "report reaches only the other contributor")
  Click(overview.actions[3])
  assert(ledger:IsShown() and not overview:IsShown(), "claims replaces overview instead of stacking")
  Click(ledger.close); Click(board.rows[1].details)
  assert(overview:IsShown() and not ledger:IsShown(), "cached overview reopens on the correct layer")
  for _, scale in ipairs({ 1, 1.5 }) do
    s.ns.Core.SetFontScale(scale)
    local first, second = s.bounds(overview.cards[1]), s.bounds(overview.cards[2])
    assert(first[2] + first[4] + 8 <= second[2], "contributor cards do not overlap at enlarged text")
    for _, button in ipairs(overview.actions) do
      if button:IsShown() then assert(s.bounds(button.label)[3] + 12 <= s.bounds(button)[3], "action text fits") end
    end
  end
  s:assertHealthy()
end)

local function Hover(s, frame)
  s.env.GameTooltip.lines = {}
  if frame.scripts.OnEnter then frame.scripts.OnEnter(frame) end
  for _, callback in ipairs(frame.hooks.OnEnter or {}) do callback(frame) end
  return table.concat(s.env.GameTooltip.lines, "\n")
end

test("bounty creation separates the draft from browsing and explains every action", function()
  local s = new("cata", nil, function(sim) sim.env.GetMoney = function() return 10000000 end end)
  s:command("bounty shared")
  local B, board = s.ns.Bounty, s.ns.Bounty.Board.win
  assert(board.create:IsShown() and not B.Form.win, "browsing has one visible creation entry point")
  board.create.scripts.OnClick(board.create)
  local w = B.Form.win
  equal(w.action:GetText(), "Enable sharing & publish", "opt-in is on the publish action")
  w.name:SetText("Enemy"); w.gold:SetText("500"); w.duration:SetText("2h")
  for _, input in ipairs({ w.name, w.gold, w.duration, w.note }) do input.scripts.OnEnterPressed(input) end
  equal(B.Entry("Enemy"), nil, "Enter advances the draft without posting")
  w.action.scripts.OnClick(w.action)
  equal(B.Public.Own("Enemy").gold, 500, "explicit action publishes")
  assert(not w:IsShown(), "creation closes after success")
  equal(board.rows[1].entry.visibility, "Shared", "My bounties says where it is visible")
  local prefs = B.Preferences.Open()
  prefs.threshold:SetFocus(); prefs.threshold:SetText("900"); B.Board.Refresh()
  equal(prefs.threshold:GetText(), "900", "background refresh preserves typing")
  prefs.threshold:ClearFocus()
  equal(s.ns.Core.O("bountyMinGold"), 900, "field saves on blur")
  equal(B.Public.Own("Enemy").gold, 500, "alert minimum never changes the reward")
  for _, frame in ipairs({ w.name, w.gold, w.note, w.duration, w.target, w.action, w.cancel,
    prefs.receive, prefs.publishOptIn, prefs.threshold, prefs.done, board.search, board.create, board.browse,
    board.alerts, board.sync, board.claims, board.review, board.prev, board.next, board.rows[1].primary, board.rows[1].details }) do
    assert(Hover(s, frame):find("\n"), "control has an explanation")
  end
  for _, tab in pairs(board.tabs) do assert(Hover(s, tab):find("\n"), "tab scope explained") end
  for _, mode in pairs(w.modes) do assert(Hover(s, mode):find("\n"), "audience explained") end
  w = B.Form.Open("Private", "personal")
  assert(not w.duration:IsShown() and not w.duration.caption:IsShown(), "duration only belongs to a shared contribution")
  w.action.scripts.OnClick(w.action)
  equal(B.Entry("Private").state, "personal", "private action stays private")
  w = B.Form.Open("GuildTarget", "guild"); w.action.scripts.OnClick(w.action)
  assert(w.error:GetText():find("Join a guild", 1, true), "unavailable guild action explains how to proceed")
  equal(B.Entry("GuildTarget"), nil, "failed submission does not save an unintended private bounty")
  s:assertHealthy()
end)

test("bounty board and creation controls fit enlarged text and the embedded window", function()
  local s = new("cata", nil, function(sim) dofile("../../tools/wowsim/geometry.lua")(sim) end)
  s.ns.Theme.Use("azeroth")
  local B = s.ns.Bounty
  for _, name in ipairs({ "Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot", "Golf", "Hotel" }) do assert(B.Add(name, 50)) end
  B.Board.Open()
  local w = B.Board.win
  local function CheckBoard()
    B.Board.Layout(w); B.Board.Refresh()
    local window, footer = s.bounds(w), s.bounds(w.alerts)
    assert(footer[1] - window[1] >= 20, "footer clears left ornament")
    assert(window[2] + window[4] - footer[2] - footer[4] >= 12, "footer clears bottom border")
    for _, tab in pairs(w.tabs) do
      local r = s.bounds(tab)
      assert(r[1] >= window[1] and r[1] + r[3] <= window[1] + window[3], "tabs fit inside board")
    end
    for _, row in ipairs(w.rows) do if row:IsShown() then
      local r = s.bounds(row)
      assert(r[2] + r[4] + 10 <= footer[2], "list does not overlap footer")
    end end
    for _, button in ipairs({ w.create, w.alerts, w.claims, w.sync }) do
      assert(s.bounds(button.label)[3] + 8 <= s.bounds(button)[3], "button label fits")
    end
    w.next.scripts.OnClick(w.next)
    assert(w.rows[1].entry and w.prev:IsEnabled(), "more entries are accessible")
  end
  for _, scale in ipairs({ 1, 1.5 }) do
    s.ns.Core.SetFontScale(scale); CheckBoard()
    s.ns.Hub.Open("bountyboard"); CheckBoard()
    s.ns.Hub.win:Hide(); B.Board.Open()
    local f = B.Form.Open("Enemy", "public")
    for _, mode in ipairs({ "personal", "guild", "public" }) do
      B.Form.SetMode(f, mode)
      for _, input in ipairs({ f.name, f.gold, f.note, f.duration }) do if input:IsShown() then
        local r, caption = s.bounds(input), s.bounds(input.caption)
        assert(caption[2] + caption[4] + 2 <= r[2], "field caption fits above input")
      end end
      local action, label = s.bounds(f.action), s.bounds(f.action.label)
      assert(label[3] + 8 <= action[3], "publish label fits at maximum text size")
      local hint, caption = s.bounds(f.audienceHint), s.bounds(f.name.caption)
      assert(hint[2] + hint[4] + 2 <= caption[2], "audience explanation clears name label")
      local terms, error = s.bounds(f.terms), s.bounds(f.error)
      assert(terms[2] + terms[4] <= error[2], "terms do not obscure validation errors")
    end
    f:Hide()
  end
  s:assertHealthy()
end)
