local t = dofile("../../tools/harness.lua")("reputation update feedback")
local F = dofile("tests/reputation/fixture.lua")
local runtime = dofile("../../tools/wowsim/battleground/runtime.lua")
local function new(name, addon, build)
  return F.new(name, { addon = addon, build = build, client = build == 40402 and "cata" or "retail",
    native = build ~= 40402 and F.native("Owner") or nil, guild = build == 40402 and "Test Guild" or nil,
    runtime = addon == "Highground" and runtime or nil, configure = function(s)
      s.native[42].members["Moderator-Realm"].presence = 3
      s.rank = name == "Owner" and 0 or 5
      s.guildRoster = { { "Owner-Realm", 0 }, { "Member-Realm", 5 } }
    end })
end
local function open(s, c)
  local W = F.W(s)
  W.Open(); W.UI.SetMode("overview", c.id); W.UI.Refresh()
  return W.UI.window
end
for _, addon in ipairs({ "Highground" }) do
  for _, build in ipairs({ 40402, 120100, 16001 }) do
    t.test(addon .. " " .. build .. ": verified reply completes one locked check", function()
      local owner, member = new("Owner", addon, build), new("Member", addon, build)
      local c = F.community(owner)
      local joined = F.join(owner, member, c)
      member:advance(6)
      local W, w = F.W(member), open(member, joined)
      F.click(member, w.sync)
      local a = assert(w.updateCheck.current)
      assert(a.request and not w.sync:IsEnabled() and w.sync.busyBar:IsVisible(), "request shows pending feedback")
      w.sync.scripts.OnClick(w.sync); W.UI.Refresh()
      t.equal(w.updateCheck.current, a, "duplicate click and view refresh preserve the attempt")
      F.pump({ owner, member }, 10)
      t.equal(w.updateCheck.state, "succeeded", "only a validated snapshot completes the check")
      assert(w.sync:IsEnabled() and not w.sync.busyBar:IsShown())
      assert(w.updateStatus:GetText():find("Updates received", 1, true))
      member:assertHealthy(); owner:assertHealthy()
    end)

    t.test(addon .. " " .. build .. ": no reply, errors and participation changes release the control", function()
      local s = new("Member", addon, build)
      local W, c = F.W(s), F.community(s)
      local w = open(s, c)
      F.click(s, w.sync)
      local a = assert(w.updateCheck.current)
      assert(a.request, "native online moderator can be queried")
      W.ReceiveSnapshot(c, { transfer = "sample.1", request = a.request.id, kind = "begin", count = 2 }, "Owner-Realm")
      w.sync:RefreshBusy()
      t.equal(w.sync.label:GetText(), "Receiving…", "partial transfer is distinct from completion")
      assert(not w.sync.busyPulse.wanted and not w.sync:IsEnabled(), "measured progress keeps the control locked")
      w:Hide(); s:advance(31); open(s, c)
      t.equal(w.updateCheck.state, "failed", "reopening reconciles elapsed timeout")
      assert(w.sync:IsEnabled() and not w.sync.busyBar:IsShown())
      assert(w.updateStatus:GetText():find("No complete update", 1, true), "partial reply is never reported as success")
      F.click(s, w.sync); W.transportError = "Sharing is unavailable."; W.UI.Refresh()
      assert(w.sync:IsEnabled() and w.updateCheck.state == "failed", "transport failure restores retry")
      F.click(s, w.sync); F.click(s, w.disable)
      t.equal(w.updateCheck.state, "cancelled", "disabling participation cancels its check")
      assert(not w.sync:IsEnabled() and not w.sync.busyBar:IsShown(), "cancellation respects disabled participation")
      s:assertHealthy()
    end)
  end
end
t.finish("Reputation update feedback: " .. t.tests .. " scenarios")
