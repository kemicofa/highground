local t = dofile("../../tools/harness.lua")("reputation forms")
local F = dofile("tests/fixture.lua")
local bg = dofile("../../tools/wowsim/battleground/runtime.lua")
local test, equal = t.test, t.equal

for _, addon in ipairs({ "Highground", "HighgroundReputation" }) do
  for _, case in ipairs({ { "retail", 120100 }, { "retail", 16001 }, { "cata", 40402 } }) do
    test(addon .. " " .. case[2] .. ": both report entry points survive organization updates", function()
      local forever = case[2] == 16001
      local s = F.new(forever and "Owner Bright" or "Owner", { addon = addon, client = case[1], build = case[2],
        guild = case[1] == "cata" and "Test Guild" or nil, runtime = addon == "Highground" and bg or nil })
      local W, c = F.W(s), F.community(s)
      for _, entry in ipairs({ "button", "context" }) do
        local name = (forever and "Enemy Bright" or "Enemy") .. "-OtherRealm"
        local target = F.target(s, name, entry == "context" and "Player-9-Enemy" or nil)
        if entry == "button" then
          if s.ns.Hub then s.ns.Options.OpenTool("reputation") else W.Open() end
          F.click(s, W.UI.window.add)
          W.UI.report.name:SetText(name)
        else
          local entries = W.MenuEntries({ name = name, guid = target.guid })
          equal(entries[1].text, "Add to blacklist...", "player context action")
          entries[1].run()
          equal(W.UI.report.name:GetText(), forever and "Enemy Bright" or name, "shared player-name presentation")
        end
        local f = W.UI.report
        f.categories.toxic:SetChecked(true)
        f.note:SetText("Unsaved explanation")
        local draftName = f.name:GetText()
        for _, event in ipairs({ "GUILD_ROSTER_UPDATE", "GUILD_RANKS_UPDATE", "PLAYER_GUILD_UPDATE",
          "CLUB_MEMBERS_UPDATED", "CLUB_MEMBER_PRESENCE_UPDATED", "CLUB_UPDATED", "CLUB_MEMBER_ROLE_UPDATED",
          "CLUB_MEMBER_REMOVED", "CLUB_REMOVED", "PLAYER_ENTERING_WORLD" }) do
          -- These events describe routine changes or other members/groups.
          s:event(event, 99, 2)
          s:advance(0.2)
          assert(f:IsVisible(), entry .. " editor survives " .. event)
          equal(f.community:GetValue(), c.id, "audience stays selected")
          equal(f.name:GetText(), draftName, "player draft stays intact")
          equal(f.note:GetText(), "Unsaved explanation", "explanation stays intact")
          assert(f.categories.toxic:GetChecked() and f.submit:IsEnabled(), "category and access preserved")
        end
        F.click(s, f.submit)
        assert(not f:IsShown(), "successful submission closes the dialog")
        local row = assert(W.FindCase(c, target))
        equal(row.active.note, "Unsaved explanation", "draft submitted")
        equal(row.active.target.name, name, "full identity retained")
        equal(row.active.target.guid, target.guid, "known GUID retained despite presentation")
      end
      s:assertHealthy()
    end)
  end
end

test("unavailable membership and role changes preserve drafts without changing their audience", function()
  local s = F.new("Owner")
  local W, c = F.W(s), F.community(s)
  s.native[43] = W.Copy(s.native[42]); s.native[43].name = "Another community"
  local other = assert(W.Enable("club:43"))
  W.OpenReport(F.target(s), c)
  local f = W.UI.report
  f.note:SetText("Still writing"); f.categories.scamming:SetChecked(true)
  local member = s.native[42].members[W.Me()]
  s.clubsLoading = true
  s:event("CLUBS_LOADED")
  assert(f:IsVisible() and not f.submit:IsEnabled(), "loading pauses submission without closing")
  equal(f.community:GetValue(), c.id, "unavailable audience retained")
  s.clubsLoading = false
  s:event("CLUBS_LOADED")
  assert(f.submit:IsEnabled(), "native access restores submission")
  s.native[42].members[W.Me()] = nil
  s:event("CLUB_REMOVED", 42)
  assert(f:IsVisible() and not f.submit:IsEnabled(), "leaving pauses submission without discarding draft")
  equal(f.community:GetValue(), c.id, "another enabled group is never selected automatically")
  equal(f.note:GetText(), "Still writing", "draft survives lost access")
  s.native[42].members[W.Me()] = member
  member.role = nil
  s:event("CLUB_SELF_MEMBER_ROLE_UPDATED", 42)
  assert(not f.submit:IsEnabled(), "unknown role cannot silently change the action")
  member.role = 4
  s:event("CLUB_SELF_MEMBER_ROLE_UPDATED", 42)
  equal(f.submit.label:GetText(), "Queue proposal", "demotion queues a proposal until a moderator answers")
  assert(f:IsVisible() and f.submit:IsEnabled(), "member can keep writing")
  F.click(s, f.submit)
  local report = assert(W.OwnReport(c, F.target(s)))
  equal(report.note, "Still writing", "draft becomes a proposal")
  equal(W.Count(c.operations), 0, "no moderator decision after demotion")
  equal(W.Count(other.reports), 0, "other organization receives nothing")
  W.OpenReport(F.target(s), c)
  W.Disable(c)
  assert(f:IsVisible() and not f.submit:IsEnabled(), "feature opt-out also preserves the draft")
  f.community:SetValue(other.id)
  assert(f.submit:IsEnabled(), "explicit audience change rechecks access")
  s:assertHealthy()
end)

test("demotion retires private history while preserving report and reason drafts", function()
  local s = F.new("Owner", { configure = function(sim) dofile("../../tools/wowsim/geometry.lua")(sim) end })
  local W, c = F.W(s), F.community(s)
  local target = F.target(s)
  assert(W.Decide(c, target, "ban", { toxic = true }, "Public explanation"))
  assert(W.MergeReport(c, { id = "private.report", account = "private.member", by = "Member-Realm",
    target = target, categories = { toxic = true }, note = "Private reporter note", revision = 1, at = W.Now() }, "Member-Realm"))
  W.Open(); W.OpenDetails(c, W.FindCase(c, target))
  local details = W.UI.details
  assert(details.text:GetText():find("Private reporter note", 1, true), "moderator can review private notes")
  local approve, revoke, dismiss = s.bounds(details.approve), s.bounds(details.revoke), s.bounds(details.dismiss)
  assert(approve[1] + approve[3] < revoke[1] and revoke[1] + revoke[3] < dismiss[1], "moderator actions sit in one row without overlap")
  assert(dismiss[1] + dismiss[3] <= s.bounds(details)[1] + s.bounds(details)[3], "and fit inside the dialog")
  local function Resize(width)
    -- The simulator does not raise OnSizeChanged; run the native hooks.
    details:SetWidth(width)
    if details.scripts.OnSizeChanged then details.scripts.OnSizeChanged(details) end
    for _, hook in ipairs(details.hooks.OnSizeChanged or {}) do hook(details) end
  end
  Resize(420)
  local narrow = s.bounds(details)
  assert(s.bounds(details.dismiss)[1] + s.bounds(details.dismiss)[3] <= narrow[1] + narrow[3], "a narrower dialog wraps its actions")
  Resize(640)
  s.ns.Core.SetFontScale(1.5)
  local wide = s.bounds(details)
  for _, button in ipairs({ details.approve, details.revoke, details.dismiss }) do
    local b = s.bounds(button)
    assert(b[1] + b[3] <= wide[1] + wide[3], "enlarged text keeps every action inside the dialog")
  end
  s.ns.Core.SetFontScale(1)
  W.OpenReport(target, c)
  W.UI.report.note:SetText("Draft decision")
  s.native[42].members[W.Me()].role = 4
  s:event("CLUB_SELF_MEMBER_ROLE_UPDATED", 42)
  assert(W.UI.report:IsVisible(), "demotion preserves active report")
  equal(details.text:GetText(), "", "hidden history no longer contains private notes")
  W.UI.report:Hide()
  assert(not details:IsShown(), "closing report cannot return to obsolete moderator history")
  s.native[42].members[W.Me()].role = 1
  s:event("CLUB_SELF_MEMBER_ROLE_UPDATED", 42)
  W.OpenDetails(c, W.FindCase(c, target)); W.OpenReason(c, target, "revoke")
  local reason = W.UI.reason
  reason.reason:SetText("Draft correction")
  s:event("CLUB_MEMBER_PRESENCE_UPDATED", 42, 2)
  assert(reason:IsVisible() and reason.submit:IsEnabled(), "routine updates preserve the reason editor")
  s.native[42].members[W.Me()].role = 4
  s:event("CLUB_SELF_MEMBER_ROLE_UPDATED", 42)
  assert(reason:IsVisible() and not reason.submit:IsEnabled(), "demotion blocks the privileged action")
  equal(reason.reason:GetText(), "Draft correction", "reason draft retained")
  s:assertHealthy()
end)

test("Forever name edits resolve a new identity and ruleset changes retire old dialogs", function()
  local s = F.new("Owner Bright", { build = 16001 })
  local W, c = F.W(s), F.community(s)
  local original = F.target(s, "Enemy Bright-OtherRealm", "Player-9-Enemy")
  W.OpenReport(original, c)
  local f = W.UI.report
  equal(f.name:GetText(), "Enemy Bright", "surname kept, realm hidden")
  f.name:SetText("Different Person"); f.categories.toxic:SetChecked(true)
  F.click(s, f.submit)
  local changed = F.target(s, "Different Person-Realm")
  local row = assert(W.FindCase(c, changed))
  equal(row.active.target.guid, "", "editing the name discards the old GUID")
  equal(row.active.target.name, changed.name, "typed name uses the current realm")
  equal(W.FindCase(c, original), nil, "original player is unaffected")
  W.OpenReport(original, c)
  local nested = s.ns.Kit.CopyBox(nil, { title = "Nested context" })
  nested:Open()
  s.ruleset = "PvP"
  s:event("PLAYER_ENTERING_WORLD")
  nested:Hide()
  assert(not f:IsShown(), "return history cannot revive a draft from the previous ruleset")
  s:assertHealthy()
end)

test("Forever numeric realm suffixes accept the screenshot's full name through both entry points", function()
  for _, entry in ipairs({ "button", "context" }) do
    local s = F.new("Owner Bright", { build = 16001, guild = "Highground", configure = function(sim, e)
      e.GetNormalizedRealmName = function() return "93" end
      sim.units.player.realm = "93"
      sim.guildRoster[1][1] = "Owner Bright-93"
    end })
    local W = F.W(s)
    local c = assert(W.Enable(s.ns.Organizations.Guild().id))
    if entry == "button" then
      W.Open(); F.click(s, W.UI.window.add)
      W.UI.report.name:SetText("Efa Arianwen")
    else
      local entries = W.MenuEntries({ name = "Efa Arianwen", server = "93", guid = "Player-93-Example" })
      entries[1].run()
      equal(W.UI.report.name:GetText(), "Efa Arianwen", "internal numeric realm hidden")
    end
    local f = W.UI.report
    f.categories.toxic:SetChecked(true); f.categories.scamming:SetChecked(true)
    f.note:SetText("Explanation")
    F.click(s, f.submit)
    assert(not f:IsShown(), entry .. " saves the valid identity: " .. f.status:GetText())
    local target = F.target(s, "Efa Arianwen-93")
    assert(W.ValidTarget(target), "full stored name passes the same validation as separate name and realm")
    equal(W.Target("Efa2 Arianwen-93"), nil, "character name validation still rejects digits")
    local row = assert(W.FindCase(c, target))
    equal(row.active.target.name, "Efa Arianwen-93", "numeric realm remains part of stored identity")
    equal(row.active.target.guid, entry == "context" and "Player-93-Example" or "", "context GUID is preserved")
    s:assertHealthy()
  end
end)

test("WoW Forever without realm names uses the ruleset identity for typed and seen players", function()
  for _, rule in ipairs({ "PvP", "RP-PvP" }) do
    local s = F.new("Owner Bright", { build = 16001, ruleset = rule, configure = function(sim, e)
      e.GetNormalizedRealmName = function() return "" end
      sim.units.player.realm, sim.regionalNames = "", true
      sim.native[42].members["Owner Bright-Realm"].name = "Owner Bright"
    end })
    local W, C, c = F.W(s), s.ns.Core, F.community(s)
    equal(W.Me(), "Owner Bright-" .. rule, "own identity carries the ruleset suffix")
    local target = assert(W.Target("Efa Arianwen"))
    equal(target.name, C.Canon("Efa Arianwen"), "typed name resolves like Core.Canon")
    W.Command("report Efa Arianwen")
    local f = W.UI.report
    assert(f:IsShown(), "/hgrep report accepts a name without a realm")
    equal(f.name:GetText(), "Efa Arianwen", "no realm shown")
    f.categories.toxic:SetChecked(true); f.note:SetText("Explanation")
    F.click(s, f.submit)
    assert(not f:IsShown(), "the form saves the name: " .. f.status:GetText())
    equal(assert(W.FindCase(c, target)).active.target.name, target.name, "stored with the ruleset suffix")
    s.units.target = { name = "Efa Arianwen", guid = "Player-9-Efa" }
    local seen = assert(W.Unit("target"))
    equal(seen.name, C.CanonUnit("target"), "a seen unit matches the typed identity")
    assert(W.Match(seen), "the blacklist matches the player in view")
    assert(W.ChatFilter(nil, "CHAT_MSG_SAY", unpack(F.chat("Efa Arianwen"))), "chat from the player is hidden")
    s.env.C_GameRules = nil
    local none, err = W.Target("Efa Arianwen")
    equal(none, nil, "no identity while the ruleset is unreadable")
    assert(not err:lower():find("realm", 1, true), "never asks for a realm: " .. err)
    s:assertHealthy()
  end
end)

test("moderation history names each decision instead of its internal kind", function()
  local s = F.new("Owner")
  local W, c = F.W(s), F.community(s)
  local target = F.target(s)
  assert(W.Decide(c, target, "ban", { toxic = true }, "Public explanation"))
  W.Open(); W.OpenDetails(c, W.FindCase(c, target))
  local text = W.UI.details.text:GetText()
  assert(text:find("\nBLACKLISTED - ", 1, true), "decision label: " .. text)
  assert(not text:find("\nBAN - ", 1, true), "no internal operation kind")
end)

t.finish("Reputation forms: " .. t.tests .. " scenarios")
