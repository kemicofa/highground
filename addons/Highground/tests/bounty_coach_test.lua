local flow = dofile("../../tests/bounty_flow.lua")
local t = dofile("../../tools/harness.lua")("bounty coach")
local F = dofile("../HighgroundBounties/tests/public/fixture.lua")
local runtime = dofile("../../tools/wowsim/battleground/runtime.lua")
local function new(build)
  local s = F.new("Tester", { addon = "Highground", build = build, client = build == 40402 and "cata" or "retail",
    runtime = function(client, saved, configure)
      return runtime(client, saved, function(sim, env)
        configure(sim, env); dofile("../../tools/wowsim/geometry.lua")(sim)
        sim.captures = 0; env.Screenshot = function() sim.captures = sim.captures + 1 end
      end)
    end })
  s.ns.Core.db.reducedMotion = true; return s
end
local function click(b) assert(b and b:IsVisible() and b:IsEnabled(), "visible enabled action"); b:Click("LeftButton") end
local function expect(C, id)
  C.Update(); t.equal(C.steps[C.index].id, id, "expected stage"); t.equal(C.router:Current().name, id, "router agrees")
end
local function action(C, b, id) click(b); expect(C, id) end
local function nextStep(C, id) action(C, C.win.next, id) end
local function go(C, id)
  for i, step in ipairs(C.steps) do if step.id == id then C.Go(i); expect(C, id); return end end
  error("Missing stage " .. id)
end
local function same(a, b, path)
  path = path or "saved data"; assert(type(a) == type(b), path .. " type changed")
  if type(a) ~= "table" then assert(a == b, path .. " changed"); return end
  for k, v in pairs(a) do same(v, b[k], path .. "." .. tostring(k)) end
  for k in pairs(b) do assert(a[k] ~= nil, path .. "." .. tostring(k) .. " was added") end
end
local function snapshot(s)
  local P = s.ns.Bounty.Public
  return { core = P.Copy(s.ns.Core.db), network = P.Copy(P.db), sent = #s.sent, chat = #s.chat }
end
local function unchanged(s, before)
  local after = s.ns.Bounty.Public.Copy(s.ns.Core.db)
  before.core.onboarding, after.onboarding = nil, nil
  same(before.core, after); same(before.network, s.ns.Bounty.Public.db)
  t.equal(#s.sent, before.sent, "no packets"); t.equal(#s.chat, before.chat, "no chat")
  t.equal(s.captures, 0, "no screenshot"); s:assertHealthy()
end
local function start(s, role)
  s.ns.Onboarding.Start("bounty_" .. role)
  local C = s.ns.Onboarding.Coach
  assert(C.key == "bounty_" .. role and C.running)
  return C, s.ns.Bounty.Preview, C.BountySample
end
local function inside(s, target, label)
  local b, p = s.bounds(target), s.bounds(s.env.UIParent)
  assert(b[1] >= p[1] - 1 and b[2] >= p[2] - 1 and b[1] + b[3] <= p[1] + p[3] + 1
    and b[2] + b[4] <= p[2] + p[4] + 1, label .. " fits on screen")
end
for _, build in ipairs({ 40402, 120100, 16001 }) do
  t.test(build .. ": both roles resume every native stage at large text and small height", function()
    local s = new(build)
    local B, C = s.ns.Bounty, s.ns.Onboarding.Coach
    for _, scale in ipairs({ 1, 1.5 }) do
      s.ns.Core.SetFontScale(scale); s.env.UIParent:SetSize(1280, 720)
      local before = snapshot(s)
      for _, role in ipairs({ "post", "hunt" }) do
        local seen = {}
        for _, step in ipairs(C.BountySteps(role)) do
          assert(not seen[step.id]); seen[step.id] = true
          B.Preview.StartGuided(C.BountySample.Stop); step.enter()
          local target, context = step.target(), step.context()
          assert(target and target:IsVisible(), role .. "/" .. step.id .. " visible target")
          assert(context and context:IsVisible(), "native context"); inside(s, target, role .. "/" .. step.id)
          if step.requireAction then
            local button = step.action()
            assert(button and button:IsVisible() and button:IsEnabled() or step.complete and step.complete(), role .. "/" .. step.id .. " required stage is actionable")
          end
          assert(not B.Preview.win, "no fake tour shell"); B.Preview.Stop()
        end
        assert(not seen.gold and not seen.import and not seen.pot, "no forced detours")
      end
      unchanged(s, before)
    end
  end)
  t.test(build .. ": poster reviews the exact bounty created through native buttons", function()
    local s = new(build)
    local before, B, O = snapshot(s), s.ns.Bounty, s.ns.Onboarding
    local C, D, S = start(s, "post")
    expect(C, "create"); nextStep(C, "target")
    local f = B.Form.previewWin
    local name = build == 16001 and "Wanted Player-Realm" or "SameTarget-Realm"
    B.Form.SetName(f, name); nextStep(C, "reward")
    f.gold:SetText("375")
    assert(not f.customize and not f.kills:IsShown(), "advanced conditions are optional")
    click(f.customizeButton); f.kills:SetText("2")
    f.note:SetText("The same reward throughout this guide"); nextStep(C, "save")
    assert(not B.GoldView.previewWin and not B.Exchange.previewImportWin and not B.Pot.previewWin)
    nextStep(C, "posted"); t.equal(D.state.coachBounty.name, name, "saved target")
    assert(not B.Exchange.previewShareWin, "saving does not require external sharing")
    expect(C, "posted")
    t.equal(B.Details.preview.name, name, "same wanted poster"); t.equal(B.Details.preview.gold, 375, "same reward")
    nextStep(C, "review"); t.equal(#D.claims, 1, "one incoming automatic report")
    assert(D.claimsWin:IsVisible(), "report opens without a navigation detour")
    local c = S.Claim()
    t.equal(c.name, name, "same report target"); t.equal(c.gold, 375, "same report reward")
    t.equal(c.killsRequired, 2, "same goal"); assert(c.previewManage and c.claimant ~= B.Me())
    t.equal(c.evidence, s.ns.Caps.combatLog and "observed killing blow" or "honor credit", "client evidence matches live detection")
    nextStep(C, "payment"); t.equal(c.state, "approved", "native approval")
    t.equal(S.Primary(), "Record payment", "approved report has the same next action as the live board")
    nextStep(C, "finish"); t.equal(c.state, "paid", "native payment record")
    t.equal(D.state.approved, 1, "one accepted kill toward chosen goal")
    click(C.win.next); assert(not C.running and not D.guided and O.win:IsVisible())
    t.equal(O.State().samples.bounty_post, "done", "independent poster completion")
    assert(O.State().samples.bounty_hunt ~= "done"); unchanged(s, before)
  end)
  t.test(build .. ": hunter tracks and opens an automatically created report", function()
    local s = new(build)
    local before, B = snapshot(s), s.ns.Bounty
    local C, D, S = start(s, "hunt")
    local name, reward = D.state.coachBounty.name, D.state.coachBounty.gold
    expect(C, "browse"); assert(not B.Matches.previewWin, "discovery begins at board")
    nextStep(C, "reward"); nextStep(C, "terms"); t.equal(B.Details.preview.name, name, "chosen target")
    nextStep(C, "tracking"); assert(not D.state.interest and #D.claims == 0)
    nextStep(C, "sighting"); t.equal(D.state.interest, "tracking", "native sample tracking")
    t.equal(#S.Rows("mine"), 1, "tracked card in My bounties")
    t.equal(B.Poster.previewWin.item.row.name, name, "same nearby target")
    nextStep(C, "kill"); t.equal(B.Proof.previewWin.item.bounty.name, name, "same proof target")
    t.equal(B.Proof.previewWin.item.bounty.gold, reward, "same proof reward")
    assert(#D.claims == 1, "detection automatically creates the sample report")
    local claim = S.Claim()
    assert(not claim.previewManage and claim.claimant == B.Me() and claim.state == "claimed")
    t.equal(claim.name, name, "same claim target"); t.equal(claim.gold, reward, "same claim reward")
    nextStep(C, "status"); assert(D.claimsWin.claimProfile.state:GetText():find("AWAITING REVIEW", 1, true))
    for _, button in ipairs(D.claimsWin.actions) do assert(not button:IsEnabled(), "cannot review own claim") end
    click(C.win.next); unchanged(s, before)
  end)
  t.test(build .. ": Back stays on completed stages and never resubmits", function()
    local s = new(build)
    local C, D, S = start(s, "post")
    go(C, "save"); nextStep(C, "posted"); action(C, C.win.back, "save"); expect(C, "save")
    t.equal(s.ns.Bounty.Form.previewWin.gold:GetText(), "500", "draft survives Back")
    go(C, "review"); nextStep(C, "payment"); action(C, C.win.back, "review"); expect(C, "review")
    assert(C.win.next:IsEnabled() and C.steps[C.index].action() == nil, "completed review Next")
    nextStep(C, "payment"); nextStep(C, "finish"); action(C, C.win.back, "payment"); expect(C, "payment")
    assert(C.win.next:IsEnabled())
    local previous = S.Claim()
    go(C, "save"); local f = s.ns.Bounty.Form.previewWin
    local replacement = build == 16001 and "New Target-Realm" or "NewTarget-Realm"
    s.ns.Bounty.Form.SetName(f, replacement); f.gold:SetText("650"); nextStep(C, "posted")
    assert(#D.claims == 0 and D.state.approved == 0, "saving a revised example restarts its sample review")
    go(C, "review")
    assert(S.Claim() ~= previous and S.Claim().name == replacement and S.Claim().gold == 650, "revisited flow remains coherent")
    s.ns.Onboarding.Return()
    C, D, S = start(s, "hunt")
    go(C, "tracking"); nextStep(C, "sighting")
    action(C, C.win.back, "tracking"); expect(C, "tracking"); nextStep(C, "sighting")
    go(C, "kill"); nextStep(C, "status"); action(C, C.win.back, "kill"); expect(C, "kill")
    nextStep(C, "status"); t.equal(#D.claims, 1, "no duplicate report")
    assert(S.ReportKill() == false and #D.claims == 1); s.ns.Onboarding.Return(); s:assertHealthy()
  end)
  t.test(build .. ": validation and audience changes never invent a private hunter claim", function()
    local s = new(build)
    local C, D = start(s, "post"); go(C, "save")
    local f = s.ns.Bounty.Form.previewWin
    f.gold:SetText("invalid"); nextStep(C, "save")
    assert(f.error:GetText():find("whole gold", 1, true) and C.win.next:IsEnabled())
    f.gold:SetText("999999"); D.state.requireGold = true; nextStep(C, "save")
    assert(f.error:GetText():find("Not enough", 1, true)); f.gold:SetText("500"); D.state.requireGold = false
    for _, mode in ipairs({ "personal", "guild" }) do
      s.ns.Bounty.Form.Step(f, 1); click(f.modes[mode]); flow.save(f); expect(C, "target"); assert(#D.claims == 0, "no fictional claim")
      click(f.modes.public); t.equal(f.formMode, "public", "native Shared selector activated"); go(C, "save")
    end
    go(C, "reward"); f.note:SetText("Keep this draft"); click(f.goldDetails)
    assert(s.ns.Bounty.GoldView.previewWin:IsVisible())
    nextStep(C, "reward"); assert(f:IsVisible() and f.note:GetText() == "Keep this draft")
    nextStep(C, "save"); s.ns.Onboarding.Return(); s:assertHealthy()
  end)
  t.test(build .. ": rejection and ignoring skip payment and claim creation", function()
    local s = new(build)
    local before = snapshot(s)
    local C, D = start(s, "post"); go(C, "review")
    action(C, D.claimsWin.actions[3], "finish"); action(C, C.win.back, "review")
    nextStep(C, "finish"); t.equal(D.claims[1].state, "rejected", "rejected path never pays")
    s.ns.Onboarding.Return(); local S
    C, D, S = start(s, "hunt"); go(C, "tracking"); click(S.win.rows[1].details)
    action(C, S.DetailButton("Ignore bounty alerts"), "status")
    assert(D.state.interest == "ignored" and #D.claims == 0 and #S.Rows("mine") == 0)
    click(C.win.next); unchanged(s, before)
  end)
  t.test(build .. ": persistent hooks do not capture a later Nearby sample form", function()
    local s = new(build)
    local C, D, S = start(s, "post")
    go(C, "save"); nextStep(C, "posted")
    click(S.DetailButton("Share bounty")); assert(s.ns.Bounty.Exchange.previewShareWin:IsVisible())
    click(s.ns.Bounty.Exchange.previewShareWin.done); s.ns.Onboarding.Return()
    start(s, "hunt"); go(C, "kill"); click(s.ns.Bounty.Proof.previewWin.proof); s.ns.Onboarding.Return()
    D.StartGuided(nil, "create"); local f = D.OpenCreate("public"); assert(not D.state.coachRole)
    flow.save(f)
    local share = s.ns.Bounty.Exchange.previewShareWin
    assert(not share:IsVisible() and not S.win:IsVisible(), "saving another preview does not reopen the coach or sharing")
    s.ns.Bounty.Exchange.PreviewShare(D.state.draft, "global")
    click(share.done); assert(not S.win:IsVisible(), "stale return hooks stay inactive")
    D.Stop(); s:assertHealthy()
  end)
  t.test(build .. ": retired guide stages resume at the matching simplified action", function()
    local s = new(build)
    local O, C = s.ns.Onboarding, s.ns.Onboarding.Coach
    for _, entry in ipairs({ { "post", "share", "posted" }, { "post", "poster", "posted" }, { "post", "incoming", "review" }, { "hunt", "proof", "kill" },
      { "hunt", "report_open", "kill" }, { "hunt", "report", "kill" }, { "hunt", "submitted", "status" } }) do
      O.State().samples = { ["bounty_" .. entry[1]] = entry[2] }
      start(s, entry[1]); expect(C, entry[3]); O.Return()
    end
    s:assertHealthy()
  end)

  t.test(build .. ": an idle bounty guide keeps its sample card and window without rebuilding them", function()
    local s = new(build)
    local B, C = s.ns.Bounty, s.ns.Onboarding.Coach
    local _, D, S = start(s, "hunt"); go(C, "tracking"); s:advance(1)
    local summaries, summary = 0, B.Terms.Summary
    B.Terms.Summary = function(...) summaries = summaries + 1; return summary(...) end
    local anchors, set = 0, S.win.SetPoint
    S.win.SetPoint = function(...) anchors = anchors + 1; return set(...) end
    s:advance(3)
    t.equal(summaries, 0, "unchanged sample progress is not rebuilt on every update")
    t.equal(anchors, 0, "the fitted sample window keeps its anchor")
    local status = D.state.coachRow.status
    click(S.PrimaryButton()); C.Update()
    assert(summaries > 0 and D.state.coachRow.tracking, "a sample change still refreshes the card")
    assert(D.state.coachRow.status == status, "with the same progress text")
    B.Terms.Summary, S.win.SetPoint = summary, set
    s.ns.Onboarding.Return(); s:assertHealthy()
  end)
end
t.finish("Bounty coach: " .. t.tests .. " scenarios")
