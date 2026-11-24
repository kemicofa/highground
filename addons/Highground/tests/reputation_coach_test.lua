-- Run from addons/Highground: luajit tests/reputation_coach_test.lua
local t = dofile("../../tools/harness.lua")("reputation coach")
local F = dofile("tests/reputation/fixture.lua")
local runtime = dofile("../../tools/wowsim/battleground/runtime.lua")

local function new(build)
  return F.new("Tester", { addon = "Highground", build = build, client = build == 40402 and "cata" or "retail",
    runtime = function(client, settings, configure)
      return runtime(client, settings, function(s, e)
        configure(s, e); dofile("../../tools/wowsim/geometry.lua")(s)
      end)
    end })
end
local function click(button)
  assert(button and button:IsVisible() and (not button.IsEnabled or button:IsEnabled()), "visible, enabled native action")
  button.scripts.OnClick(button)
  for _, hook in ipairs(button.hooks.OnClick or {}) do hook(button) end
end
local function same(a, b, path)
  path = path or "saved data"
  assert(type(a) == type(b), path .. " type changed")
  if type(a) ~= "table" then assert(a == b, path .. " changed"); return end
  for k, v in pairs(a) do same(v, b[k], path .. "." .. tostring(k)) end
  for k in pairs(b) do assert(a[k] ~= nil, path .. "." .. tostring(k) .. " was added") end
end
local function expect(C, id)
  C.Update(); t.equal(C.steps[C.index].id, id, "guide follows the native click")
  t.equal(C.router:Current().name, id, "guide router agrees")
end
local function action(C, button, id) click(button); expect(C, id) end
local function resume(s, C, U)
  action(C, U.window.disable, "updates")
  click(U.window.sync)
  assert(not U.window.sync:IsEnabled() and U.window.sync.busyBar:IsVisible(), "sample check is pending")
  s:advance(0.9); expect(C, "report_open")
end
local function start(s)
  local C = s.ns.Onboarding.Coach
  s.ns.Onboarding.Start("reputation")
  assert(C.running and C.key == "reputation", "guide launches from the native Reputation chapter")
  return C, C.ReputationSample, C.ReputationSample.provider.UI
end
local function unchanged(s, core, network, sent, chat)
  local after = s.ns.Reputation.Copy(s.ns.Core.db)
  core.onboarding, after.onboarding = nil, nil
  same(core, after); same(network, s.ns.Reputation.db)
  t.equal(#s.sent, sent, "no report or sync messages")
  t.equal(#s.chat, chat, "no chat or automatic replies")
  s:assertHealthy()
end

for _, build in ipairs({ 40402, 120100, 16001 }) do
  t.test(build .. ": every saved stage opens a visible native control", function()
    local s = new(build)
    local C, W = s.ns.Onboarding.Coach, s.ns.Reputation
    local core, network = W.Copy(s.ns.Core.db), W.Copy(W.db)
    local sent, chat = #s.sent, #s.chat
    for _, scale in ipairs({ 1, 1.5 }) do
      s.ns.Core.SetFontScale(scale); s.env.UIParent:SetSize(1280, 720)
      core = W.Copy(s.ns.Core.db)
      for _, step in ipairs(C.ReputationSteps()) do
        step.enter()
        local target, context = step.target(), step.context()
        assert(target and target:IsVisible(), step.id .. " has a visible native control")
        assert(context and context:IsVisible(), step.id .. " has a native window context")
        local b, p = s.bounds(target), s.bounds(s.env.UIParent)
        assert(b[1] >= p[1] and b[2] >= p[2] and b[1] + b[3] <= p[1] + p[3] + 1
          and b[2] + b[4] <= p[2] + p[4] + 1, step.id .. " control fits on screen")
        assert(not C.Examples.win, "no substitute practice screen")
        C.ReputationSample.Stop(); C.Native.Stop()
      end
      unchanged(s, core, network, sent, chat)
    end
  end)

  t.test(build .. ": real form and moderation buttons lead through the guide", function()
    local s = new(build)
    local W = s.ns.Reputation
    local core, network, sent, chat = W.Copy(s.ns.Core.db), W.Copy(W.db), #s.sent, #s.chat
    local C, R, U = start(s)
    expect(C, "organization"); assert(not C.win.next:IsEnabled())
    action(C, U.window.rows[1].action, "participation"); resume(s, C, U)
    assert(not U.report, "form waits for its actual opener")
    action(C, U.window.add, "proposal")
    local report = U.report
    report.note:SetText("Observed example encounter")
    action(C, report.submit, "proposals_open")
    assert(R.data.row.pending == 1 and not R.data.row.active, "proposal is not an approved decision")
    action(C, U.window.tabs.proposals, "moderation"); action(C, U.window.openReports, "details_open")
    action(C, U.window.rows[1].action, "review")
    assert(U.details.text:GetText():find("Observed example encounter", 1, true))
    action(C, U.details.approve, "approve")
    t.equal(report.note:GetText(), "Observed example encounter", "native review preserves the report note")
    action(C, report.submit, "return")
    assert(R.data.row.active and R.data.row.pending == 0)
    action(C, U.details.close, "blacklist_open")
    action(C, U.window.tabs.blacklist, "decision")
    action(C, U.window.rows[1].action, "history")
    assert(U.details.text:GetText():find("BLACKLISTED", 1, true), "actual history renders the decision")
    action(C, U.details.close, "overview_open")
    action(C, U.window.tabs.overview, "pause")
    action(C, U.window.disable, "resume")
    assert(not R.provider.Joined(R.provider.Get()), "sample is paused")
    action(C, U.window.disable, "settings_open")
    action(C, U.window.tabs.settings, "settings")
    click(U.window.toggles.filter); click(U.window.toggles.reply); click(U.window.toggles.tooltip)
    U.window.replyInterval:SetValue(60); U.window.replyText:SetText("Sample reply")
    assert(R.provider.db.settings.filter == false and R.provider.db.settings.replyInterval == 60)
    click(U.window.resetReply); click(U.window.resetReply)
    t.equal(U.window.replyText:GetText(), W.DEFAULT_REPLY, "confirmed native reset updates sample only")
    local visits = #U.router:History()
    click(U.window.tabs.settings)
    t.equal(U.mode, "settings", "selected Preferences tab stays open")
    t.equal(#U.router:History(), visits, "selected Preferences tab adds no history")
    click(C.win.next)
    expect(C, "settings_return")
    click(U.window.workspaceTabs.buttons.organizations); C.Update()
    assert(not R.data and not U.window:IsVisible(), "Done retires sample state and windows")
    unchanged(s, core, network, sent, chat)
  end)

  t.test(build .. ": invalid forms stay open and native reason controls use sample data", function()
    local s = new(build)
    local C, R, U = start(s)
    action(C, U.window.rows[1].action, "participation"); resume(s, C, U); action(C, U.window.add, "proposal")
    U.report.categories.other:SetChecked(false, true)
    action(C, U.report.submit, "proposal")
    assert(U.report.status:GetText():find("category", 1, true) and not C.win.next:IsEnabled())
    U.report.categories.other:SetChecked(true, true)
    action(C, U.report.submit, "proposals_open"); action(C, U.window.tabs.proposals, "moderation"); action(C, U.window.openReports, "details_open")
    action(C, U.window.rows[1].action, "review")
    action(C, U.details.dismiss, "review")
    assert(U.reason:IsVisible() and U.reason.kind == "dismiss")
    click(U.reason.submit); assert(U.reason:IsVisible() and U.reason.status:GetText():find("required", 1, true))
    U.reason.reason:SetText("Example evidence was insufficient"); action(C, U.reason.submit, "overview_open")
    assert(R.data.row.pending == 0 and not R.data.row.active and R.data.row.state == "dismissed")
    local P = R.provider
    assert(P.Decide(P.Get(), R.data.row.target, "ban", { other = true }, "Sample review"))
    P.OpenDetails(P.Get(), R.data.row); click(U.details.revoke)
    U.reason.reason:SetText("Example entry corrected"); click(U.reason.submit)
    assert(not R.data.row.active and R.data.row.state == "revoked" and #R.data.row.actions == 3)
    C.Stop(); C.Native.Stop(); s:assertHealthy()
  end)

  t.test(build .. ": cancel and revoke keep routing tied to the visible native dialog", function()
    local s = new(build)
    local C, R, U = start(s)
    action(C, U.window.rows[1].action, "participation"); resume(s, C, U); action(C, U.window.add, "proposal")
    action(C, U.report.close, "report_open"); action(C, U.window.add, "proposal")
    action(C, U.report.submit, "proposals_open"); action(C, U.window.tabs.proposals, "moderation"); action(C, U.window.openReports, "details_open")
    action(C, U.window.rows[1].action, "review"); action(C, U.details.approve, "approve")
    action(C, U.report.close, "review"); action(C, U.details.approve, "approve")
    action(C, U.report.submit, "return")
    assert(U.details.text:GetText():find("BLACKLISTED", 1, true), "returned native history is current")
    action(C, U.details.close, "blacklist_open"); action(C, U.window.tabs.blacklist, "decision")
    action(C, U.window.rows[1].action, "history")
    action(C, U.details.revoke, "history"); assert(U.reason:IsVisible(), "opening a child is not treated as closing history")
    U.reason.reason:SetText("Corrected sample entry")
    action(C, U.reason.submit, "overview_open")
    assert(not R.data.row.active and R.data.row.state == "revoked", "continuing does not recreate a revoked decision")
    s.ns.Onboarding.StopExploring(); s:assertHealthy()
  end)

  t.test(build .. ": sample navigation and sync keep live UI and storage intact", function()
    local s = new(build)
    local W, C = s.ns.Reputation, s.ns.Onboarding.Coach
    local live = W.Open(); W.UI.SetMode("organizations")
    local handler, router = live.add.scripts.OnClick, W.UI.router
    local core, network, sent, chat = W.Copy(s.ns.Core.db), W.Copy(W.db), #s.sent, #s.chat
    local _, R, U = start(s)
    assert(U.window ~= live and U.router ~= router and not U.window.savedKey)
    action(C, U.window.rows[1].action, "participation"); resume(s, C, U)
    click(U.window.tabs.overview); click(U.window.sync); click(U.window.native)
    click(U.window.tabs.members); assert(U.window.rows[1]:IsVisible())
    U.window.search:SetText("Officer"); click(U.window.rows[1].action)
    click(U.window.tabs.history); click(U.window.tabs.settings)
    U.window.replyText:SetText("Only sample preferences")
    click(U.window.routeBack); click(U.window.tabs.overview); click(U.window.disable)
    t.equal(U.mode, "overview", "native pause retains the organization and its resume action")
    t.equal(live.add.scripts.OnClick, handler, "live callbacks are never replaced")
    t.equal(W.UI.router, router, "live router is never replaced")
    t.equal(W.UI.mode, "organizations", "live tab stays unchanged")
    C.Stop(); C.Native.Stop()
    unchanged(s, core, network, sent, chat)
  end)
end
t.finish("Reputation coach: " .. t.tests .. " scenarios")
