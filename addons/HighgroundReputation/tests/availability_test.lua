local t = dofile("../../tools/harness.lua")("reputation availability")
local F = dofile("tests/fixture.lua")
local test, equal = t.test, t.equal

local function offline(native)
  native[42].members["Owner-Realm"].presence = 3
  native[42].members["Moderator-Realm"].presence = 3
end

local function packet(W, name, enabled, id)
  id = id or "club:42"
  local probe = assert(W.probes[id .. ":" .. name])
  return { kind = "presence", community = id, request = probe.request, revision = 1, enabled = enabled }
end

test("Forever moderator discovery and queued whispers stay within the native ruleset", function()
  for _, addon in ipairs({ "HighgroundReputation", "Highground" }) do
    local native = F.native("Owner")
    native[42].members["Owner-Realm"].presence = 3
    local foreign = native[42].members["Moderator-Realm"]
    foreign.name, foreign.guid = "Rex Gadgetz", "Player-2-303"
    native[42].members["Local Bright-Realm"] = {
      name = "Local Bright", guid = "Player-1-202", role = 3, presence = 1, memberId = 99,
    }
    local s = F.new("Member", { addon = addon, native = native, build = 16001, ruleset = "RP-PvP",
      runtime = addon == "Highground" and dofile("../../tools/wowsim/battleground/runtime.lua") or nil,
      configure = function(sim, e)
        sim.sameServer = { ["Player-1-202"] = true, ["Player-2-303"] = false }
        e.PlayerLocation = { CreateFromGUID = function(_, guid) return { guid = guid } end }
        e.C_PlayerInfo = { UnitIsSameServer = function(location) return sim.sameServer[location.guid] end }
      end })
    local W, c = F.W(s), F.community(s)
    W.Discover(c.id, true)
    equal(W.probes[c.id .. ":Rex Gadgetz-Realm"], nil, "foreign moderator is never probed")
    assert(W.probes[c.id .. ":Local Bright-Realm"], "same-ruleset moderator is discovered")
    F.pump({ s }, 25)
    assert(#s.sent > 0, "discovery sends to eligible moderators")
    for _, message in ipairs(s.sent) do
      equal(message.target, "Local Bright", "only same-ruleset moderators receive addon whispers")
    end
    W.Discover(c.id, true)
    assert(#W.outbox > 0, "discovery still has pending whispers")
    local before = #s.sent
    s.sameServer["Player-1-202"] = false
    W.Flush()
    equal(#s.sent, before, "queued messages stop before the next send when recipient eligibility changes")
    equal(#W.outbox, 0, "ineligible recipient removed from retry queue")
    equal(W.Availability(c.id).code, "offline", "foreign moderators do not appear available for local proposals")
    s:assertHealthy()
  end
end)

test("only native owners, leaders, moderators and permitted guild ranks can enable", function()
  for _, role in ipairs({ 1, 2, 3, 4, 0 }) do
    local s = F.new("Owner")
    local W = F.W(s)
    s.native[42].members[W.Me()].role = role ~= 0 and role or nil
    local f = W.Open()
    W.UI.SetMode("organizations")
    equal(f.rows[1].action.label:GetText(), role > 0 and role < 4 and "Enable" or "Open", "role controls the action")
    equal(W.Enable("club:42") ~= nil, role > 0 and role < 4, "model enforces the same permission")
    s:assertHealthy()
  end
  for _, rank in ipairs({ 0, 1, 3, 5 }) do
    local s = F.new("Owner", { client = "cata", guild = "Guild", configure = function(sim, e)
      sim.rank = rank
      e.C_GuildInfo = { GuildControlGetRankFlags = function(index) return { true, [22] = index == 4 } end }
    end })
    local W, id = F.W(s), s.ns.Organizations.Guild().id
    local f = W.Open()
    W.UI.SetMode("organizations")
    equal(f.rows[1].action.label:GetText(), (rank == 0 or rank == 3) and "Enable" or "Open", "native flags, not rank number")
    equal(W.Enable(id) ~= nil, rank == 0 or rank == 3, "guild activation checks native permissions")
  end
end)

test("confirmed enablement survives an account switch while moderators are offline", function()
  local native = F.native("Owner")
  local owner = F.new("Owner", { native = native })
  local W, c = F.W(owner), F.community(owner)
  offline(native)
  local alt = F.new("Member", { native = native, database = W.Copy(W.db) })
  local A = F.W(alt)
  local ac = assert(A.Get(c.id))
  assert(ac.activated and A.Joined(ac), "same account remembers the enabled organization")
  equal(A.CanModerate(ac), false, "alt does not inherit native authority")
  equal(A.Availability(c.id).code, "offline", "saved enablement does not imply a receiver is online")
  local f = A.Open()
  A.UI.SetMode("organizations")
  assert(f.rows[1].hint:GetText():find("Enabled", 1, true))
  equal(f.rows[1].action.label:GetText(), "Open", "alt never needs to enable again")
end)

test("fresh members discover enablement without pressing Enable or opening the UI", function()
  local native = F.native("Owner")
  local owner = F.new("Owner", { native = native })
  local member = F.new("Member", { native = native })
  local W, M, c = F.W(owner), F.W(member), F.community(owner)
  assert(W.Decide(c, F.target(owner), "ban", { toxic = true }, "Approved explanation"))
  equal(M.Get(c.id), nil, "fresh member has no local organization")
  F.pump({ owner, member }, 35)
  local mc = assert(M.Get(c.id))
  assert(mc.activated and mc.synced and M.Match(F.target(member)), "verified moderator discovers and syncs automatically")
  equal(M.Availability(c.id).code, "ready", "eligible receiver detected")
  M.Disable(mc)
  F.pump({ owner, member }, 100)
  assert(not M.Joined(mc), "later announcements respect an explicit personal pause")
  assert(W.Joined(c), "pausing a member does not disable the organization for others")
end)

test("guild members discover and deliver through an officer on each supported client", function()
  for _, build in ipairs({ 40402, 120100, 16001 }) do
    local function options(rank)
      return { client = build == 40402 and "cata" or "retail", build = build, guild = "Guild", configure = function(s, e)
        s.rank = rank
        s.guildRoster = { { "Owner-Realm", 3 }, { "Member-Realm", 5 } }
        e.C_GuildInfo = { GuildControlGetRankFlags = function(index) return { true, [22] = index == 4 } end }
        if e.C_Club then e.C_Club.GetGuildClubId = function() return 77 end end
      end }
    end
    local officer, member = F.new("Owner", options(3)), F.new("Member", options(5))
    local W, M, id = F.W(officer), F.W(member), officer.ns.Organizations.Guild().id
    local c = assert(W.Enable(id))
    F.pump({ officer, member }, 35)
    local mc = assert(M.Get(id))
    assert(mc.activated and mc.synced, "officer enables and synchronizes without a guildmaster")
    local r = assert(M.Submit(mc, F.target(member, build == 16001 and "Enemy Person" or "Enemy-Realm"), { toxic = true }, "Guild report"))
    F.pump({ officer, member }, 20)
    equal(c.reports[r.id].note, "Guild report", "guild officer receives proposal")
    equal(M.db.pending[r.id], nil, "guild officer receipt clears queue")
  end
end)

test("wrapped availability guidance clears the form controls and workspace footer", function()
  local bg = dofile("../../tools/wowsim/battleground/runtime.lua")
  for _, addon in ipairs({ "HighgroundReputation", "Highground" }) do
    local s = F.new("Member", { native = F.native("Owner"), addon = addon,
      runtime = addon == "Highground" and bg or nil,
      configure = function(sim) dofile("../../tools/wowsim/geometry.lua")(sim) end })
    local W, c = F.W(s), F.community(s)
    for _, scale in ipairs({ 1, 1.5 }) do
      s.ns.Core.SetFontScale(scale)
      if s.ns.Hub then s.ns.Hub.Open("reputation") else W.Open() end
      W.OpenReport(F.target(s), c)
      F.pump({ s }, 30)
      local f = W.UI.report
      local hint, status, submit = s.bounds(f.hint), s.bounds(f.status), s.bounds(f.submit)
      assert(hint[2] + hint[4] < status[2], "warning and validation text never overlap")
      assert(status[2] + 72 < submit[2], "validation has room above the action")
      assert(f:GetHeight() <= 720, "report fits a small screen")
      f:Hide()
      W.UI.Refresh()
      local w = W.UI.window
      local row, footer = s.bounds(w.rows[W.UI.pageSize]), s.bounds(w.status)
      assert(row[2] + row[4] < footer[2], "wrapped status remains below the last list row")
      s:assertHealthy()
    end
  end
end)

test("a queued proposal survives reload and sends automatically when an enabled moderator returns", function()
  local native = F.native("Owner")
  local owner = F.new("Owner", { native = native })
  local W, c = F.W(owner), F.community(owner)
  offline(native)
  local member = F.new("Member", { native = native })
  local M = F.W(member)
  local f = M.Open()
  assert(f.add:IsEnabled(), "reporting is available before discovery")
  F.click(member, f.add)
  local form = M.UI.report
  equal(form.submit.label:GetText(), "Queue proposal", "offline action describes local storage")
  form.name:SetText("Enemy-Realm"); form.categories.toxic:SetChecked(true); form.note:SetText("Private evidence")
  F.click(member, form.submit)
  local mc = M.Get(c.id)
  local report = assert(M.OwnReport(mc, F.target(member)))
  assert(M.db.pending[report.id] and report.delivery == "queued")
  equal(M.UI.mode, "proposals", "submission returns to its delivery status")
  assert(f.rows[1].hint:GetText():find("Queued", 1, true))
  member = F.new("Member", { native = native, database = M.Copy(M.db) })
  M = F.W(member)
  assert(M.db.pending[report.id], "durable delivery queue")
  native[42].members["Owner-Realm"].presence = 1
  member:event("CLUB_MEMBER_PRESENCE_UPDATED", 42, 1)
  F.pump({ owner, member }, 35)
  equal(c.reports[report.id].note, "Private evidence", "automatically delivered to the returning moderator")
  equal(M.db.pending[report.id], nil, "receipt clears pending delivery")
  equal(M.Get(c.id).reports[report.id].delivery, "received", "received is distinct from approval")
  assert(not M.Match(F.target(member)), "receipt never blacklists the player")
end)

test("an online moderator with the addon off gives setup guidance and enabling releases the queue", function()
  local native = F.native("Owner")
  native[42].members["Moderator-Realm"].presence = 3
  local owner = F.new("Owner", { native = native })
  local member = F.new("Member", { native = native })
  local W, M = F.W(owner), F.W(member)
  local mc = assert(M.Follow("club:42"))
  local r = assert(M.Submit(mc, F.target(member), { scamming = true }, "Wait for setup"))
  F.pump({ owner, member }, 25)
  local state = M.Availability(mc.id)
  equal(state.code, "not_enabled", "explicit disabled response is distinct from offline")
  assert(state.message:find("Owner", 1, true) and state.message:find("Ask them to enable", 1, true), "named manual request guidance")
  equal(W.Get(mc.id), nil, "discovery does not enable the moderator or copy the private report")
  assert(M.db.pending[r.id], "proposal stays queued")
  M.OpenReport(F.target(member), mc)
  equal(M.UI.report.submit.label:GetText(), "Queue proposal", "disabled organization still accepts a queue")
  assert(M.UI.report.hint:GetText():find("turned off", 1, true))
  local c = assert(W.Enable(mc.id))
  F.pump({ owner, member }, 20)
  assert(c.reports[r.id] and not M.db.pending[r.id], "enablement announces availability without waiting for the next poll")
  equal(M.UI.report.submit.label:GetText(), "Submit proposal", "open draft updates when a receiver becomes ready")
  W.Disable(c)
  F.pump({ owner, member }, 5)
  equal(M.Availability(mc.id).code, "not_enabled", "paused reviewer no longer receives")
  assert(mc.activated, "one moderator pausing does not erase confirmed organization enablement")
  assert(W.Follow(c.id))
  F.pump({ owner, member }, 5)
  equal(M.Availability(mc.id).code, "ready", "resuming announces readiness immediately")
end)

test("unanswered probes warn without claiming the addon is definitely absent", function()
  local s = F.new("Member", { native = F.native("Owner") })
  local W, c = F.W(s), F.community(s)
  local report = assert(W.Submit(c, F.target(s), { toxic = true }, "Not sent without a receiver"))
  W.OpenReport(F.target(s), c)
  equal(W.Availability(c.id).code, "checking", "discovery grace period")
  F.pump({ s }, 30)
  local state = W.Availability(c.id)
  equal(state.code, "not_detected", "online native moderators did not answer")
  assert(state.label:find("Addon not detected", 1, true))
  assert(state.message:find("installed and enabled", 1, true))
  assert(W.UI.report.hint:GetText():find("not answered", 1, true), "form shows the warning")
  assert(W.db.pending[report.id], "silence never counts as receipt")
  for _, item in ipairs(W.outbox) do assert(item.packet.kind ~= "report", "private notes wait for a confirmed receiver") end
  s:event("CHAT_MSG_ADDON", "HighgroundN", "1|" .. W.Scope() .. "|reputation=1", "WHISPER", "Owner-Realm")
  equal(W.Availability(c.id).code, "update", "capability alone does not prove feature enablement")
  assert(W.db.pending[report.id])
end)

test("only correlated current native moderator replies confirm readiness", function()
  local s = F.new("Member", { native = F.native("Owner") })
  local W = F.W(s)
  W.Discover("club:42", true)
  local p = packet(W, "Owner-Realm", true)
  W.Handle(p, "Outsider-Realm"); W.Handle(p, "Member-Realm")
  equal(W.Get("club:42"), nil, "untrusted senders cannot activate")
  local stale = W.Copy(p); stale.request = "stale.request"
  W.Handle(stale, "Owner-Realm")
  equal(W.Get("club:42"), nil, "unsolicited reply cannot activate")
  s.native[42].members["Owner-Realm"].role = 4
  W.Handle(p, "Owner-Realm")
  equal(W.Get("club:42"), nil, "demoted sender cannot activate")
  s.native[42].members["Owner-Realm"].role = 1
  W.Handle(p, "Owner-Realm")
  local c = assert(W.Get("club:42"))
  assert(c.activated and W.ReviewerReady(c.id, "Owner-Realm"))
  s.native[42].members["Owner-Realm"].presence = 3
  s:event("CLUB_MEMBER_PRESENCE_UPDATED", 42, s.native[42].members["Owner-Realm"].memberId)
  assert(not W.ReviewerReady(c.id, "Owner-Realm"), "offline transition retires readiness")
  s.native[42].members["Owner-Realm"].presence = 1
  assert(not W.ReviewerReady(c.id, "Owner-Realm"), "relogin must answer a fresh check")
  s.rosterLoading = true
  equal(W.Availability(c.id).code, "loading", "unavailable roster is not mistaken for absent addons")
end)

test("lost receipt and stale revision cannot discard a queued amendment", function()
  local native = F.native("Owner")
  local owner = F.new("Owner", { native = native })
  local member = F.new("Member", { native = native })
  local W, M, c = F.W(owner), F.W(member), F.community(owner)
  local mc = F.join(owner, member, c)
  local r = assert(M.Submit(mc, F.target(member), { toxic = true }, "First version"))
  local amended = assert(M.Submit(mc, F.target(member), { scamming = true }, "Updated evidence"))
  M.Handle({ kind = "report_received", community = c.id, id = r.id, revision = r.revision }, "Owner-Realm")
  assert(M.db.pending[r.id], "old revision receipt does not acknowledge amendment")
  M.Handle({ kind = "report_received", community = c.id, id = r.id, revision = amended.revision }, "Moderator-Realm")
  -- An unsolicited native moderator receipt is not delivery evidence.
  assert(M.db.pending[r.id], "only an actual recipient may acknowledge the report")
  local handle = W.Handle
  W.Handle = function(p, sender)
    handle(p, sender)
    if p.kind == "report" then
      for i = #W.outbox, 1, -1 do if W.outbox[i].packet.kind == "report_received" then table.remove(W.outbox, i) end end
    end
  end
  F.pump({ owner, member }, 30)
  assert(c.reports[r.id] and M.db.pending[r.id], "transport acknowledgement alone never clears pending delivery")
  W.Handle = handle
  F.pump({ owner, member }, 110)
  equal(M.db.pending[r.id], nil, "idempotent retry obtains receipt")
  equal(c.reports[r.id].revision, 2, "latest revision delivered exactly once")
end)

test("pending reports cannot leak across memberships, rulesets or reporting characters", function()
  local native = F.native("Owner")
  offline(native)
  local s = F.new("Member", { native = native, build = 16001 })
  local W, c = F.W(s), F.community(s)
  local r = assert(W.Submit(c, F.target(s, "Enemy Person"), { toxic = true }, "Private"))
  local alt = F.new("Owner", { native = native, build = 16001, database = W.Copy(W.db) })
  local A = F.W(alt)
  assert(A.DeliveryText(A.Get(c.id), A.Get(c.id).reports[r.id]):find("Log into Member", 1, true))
  A.SendReports(A.Get(c.id))
  assert(A.db.pending[r.id], "another character cannot impersonate the reporter")
  s.ruleset = "PvP"; W.Reconcile()
  equal(W.Get(c.id), nil, "separate ruleset does not load the organization")
  assert(W.db.pending[r.id], "other scope's pending report is retained")
  s.ruleset = "PvE"; W.Reconcile()
  native[42].members[W.Me()] = nil
  s:event("CLUB_REMOVED", 42)
  W.SendReports(c)
  equal(#W.outbox, 0, "removed native membership blocks pending transmissions")
end)

test("background discoveries preserve the selected audience and newer readiness wins", function()
  local native = F.native("Owner")
  native[43] = { name = "Second community", members = native[42].members }
  local s = F.new("Member", { native = native })
  local W = F.W(s)
  local first = assert(W.Follow("club:42"))
  W.OpenReport(F.target(s), first)
  W.UI.report.note:SetText("Keep my audience")
  W.Discover("club:43", true)
  local p = packet(W, "Owner-Realm", true, "club:43")
  W.Handle(p, "Owner-Realm")
  equal(W.db.selected, first.id, "background discovery does not select another organization")
  equal(W.UI.report.community:GetValue(), first.id, "open draft audience remains unchanged")
  equal(W.UI.report.note:GetText(), "Keep my audience", "discovery preserves the draft")
  local newer = W.Copy(p); newer.revision, newer.enabled = 2, false
  W.Handle(newer, "Owner-Realm")
  W.Handle(p, "Owner-Realm")
  equal(W.ReviewerReady("club:43", "Owner-Realm"), false, "reordered old enabled response cannot revive a paused reviewer")
  assert(W.Get("club:43").activated, "pause does not erase the organization's confirmed activation")
end)

test("legacy snapshots still confirm a receiver and game restrictions keep reports queued", function()
  local native = F.native("Owner")
  native[42].members["Moderator-Realm"].presence = 3
  local owner = F.new("Owner", { native = native })
  local member = F.new("Member", { native = native })
  local W, M, c = F.W(owner), F.W(member), F.community(owner)
  W.HandlePresence = function() end -- Existing v1 addons do not implement discovery.
  local mc = assert(M.Follow(c.id))
  local r = assert(M.Submit(mc, F.target(member), { toxic = true }, "Legacy receiver"))
  member.addonLocked = true
  F.pump({ owner, member }, 20)
  assert(M.db.pending[r.id] and not c.reports[r.id], "game restrictions do not acknowledge or lose a report")
  assert(M.Status(mc):find("paused by the game", 1, true))
  equal(M.Availability(mc.id).code, "restricted", "form readiness reflects game restrictions")
  assert(M.DeliveryText(mc, mc.reports[r.id]):find("Sharing paused", 1, true), "queued status explains the restriction")
  member.addonLocked = false
  F.pump({ owner, member }, 40)
  assert(mc.synced and c.reports[r.id], "legacy snapshot confirms the actual feature receiver")
  equal(M.db.pending[r.id], nil, "legacy receipt clears delivery")
  native[42].members["Moderator-Realm"].presence = 1
  local moderator = F.new("Moderator", { native = native })
  local R = F.W(moderator)
  local rc = assert(R.Follow(c.id))
  F.pump({ owner, moderator }, 35)
  assert(rc.activated and rc.synced, "legacy moderator confirms a new moderator's organization")
  equal(rc.reports[r.id].note, "Legacy receiver", "private notes commit only after the authorized snapshot is verified")
end)

test("legacy migration preserves confirmation without treating member opt-in as activation", function()
  local native = F.native("Owner")
  offline(native)
  for _, synced in ipairs({ true, false }) do
    local s = F.new("Member", { native = native })
    local W, c = F.W(s), F.community(s)
    c.activated, c.synced = nil, synced
    local reloaded = F.new("Member", { native = native, database = W.Copy(W.db) })
    equal(F.W(reloaded).Get(c.id).activated, synced, "only a legacy confirmation establishes enablement")
  end
end)

t.finish("Reputation availability: " .. t.tests .. " scenarios")
