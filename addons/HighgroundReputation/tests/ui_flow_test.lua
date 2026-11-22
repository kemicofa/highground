local t = dofile("../../tools/harness.lua")("reputation UI flow")
local F = dofile("tests/fixture.lua")
local runtime = dofile("../../tools/wowsim/battleground/runtime.lua")
local function click(s, button)
  assert(button:IsVisible(), "action is visible in the current step")
  F.click(s, button)
end
local function new(addon, build, database, geometry)
  return F.new("Owner", { addon = addon, build = build, client = build == 40402 and "cata" or "retail",
    guild = build == 40402 and "Test Guild" or nil, runtime = addon == "Highground" and runtime or nil, database = database,
    configure = function(s) if geometry then dofile("../../tools/wowsim/geometry.lua")(s) end end })
end

for _, addon in ipairs({ "Highground", "HighgroundReputation" }) do
  for _, build in ipairs({ 120100, 16001, 40402 }) do
    t.test(addon .. " " .. build .. ": browsing a paused organization never resumes it", function()
      local s = new(addon, build)
      local W = F.W(s)
      local c = F.community(s)
      W.Disable(c)
      W.OpenOrganizations()
      local w = W.UI.window
      assert(w.rows[1]:IsVisible(), "paused organization remains available to inspect")
      click(s, w.rows[1].action)
      t.equal(c.enabled, false, "opening an organization must not change participation")
      assert(not W.CanModerate(c), "browsing must not resume moderation")
      s:assertHealthy()
    end)

    t.test(addon .. " " .. build .. ": owners and guild masters can enable, disable and resume in place", function()
      local s = new(addon, build)
      local W = F.W(s)
      W.OpenOrganizations()
      local w = W.UI.window
      assert(not w.add:IsVisible() and not w.disable:IsVisible() and not w.sync:IsVisible(), "directory only offers organization navigation")
      click(s, w.rows[1].action)
      local id = W.db.selected
      t.equal(W.Get(id), nil, "browsing a fresh organization has no saved participation")
      t.equal(W.UI.mode, "overview", "setup has its own location")
      assert(not w.tabs.blacklist:IsEnabled(), "data tabs explain that participation is off")
      click(s, w.disable)
      local c = W.Get(id)
      assert(W.CanModerate(c), "native owner or guild master explicitly enables moderation")
      local target = F.target(s, build == 16001 and "Enemy Bright-Realm" or nil)
      assert(W.Decide(c, target, "ban", { toxic = true }, "Keep this record"))
      assert(W.Match(target), "enabled blacklist applies")
      click(s, w.disable)
      assert(not W.Joined(c) and not W.CanModerate(c) and not W.Match(target), "disable stops sharing, moderation and filtering")
      t.equal(W.db.selected, id, "disable keeps the organization selected")
      t.equal(W.UI.mode, "overview", "resume stays in the same place")
      assert(w.disable:IsEnabled() and not w.sync:IsEnabled(), "enable stays reachable while synchronization is off")
      click(s, w.tabs.settings)
      assert(w.settings:IsVisible() and not w.tabs.blacklist:IsVisible(), "personal preferences have a separate scope")
      click(s, w.routeBack)
      t.equal(W.UI.mode, "overview", "Back restores participation controls")
      click(s, w.browse); click(s, w.rows[1].action)
      W.ReceiverDiscovered(id, true)
      assert(not W.Joined(c), "browsing and moderator discovery preserve the off choice")
      click(s, w.disable)
      assert(W.Joined(c) and W.CanModerate(c) and W.Match(target), "explicit enable restores the preserved blacklist")
      click(s, w.openReports)
      t.equal(W.UI.mode, "proposals", "overview leads into the report workspace")
      assert(w.add:IsVisible() and not w.sync:IsVisible() and not w.disable:IsVisible(), "report workspace has only relevant actions")
      s:assertHealthy()
    end)

    t.test(addon .. " " .. build .. ": opening a report keeps an organization off until explicitly resumed", function()
      local s = new(addon, build)
      local W, c = F.W(s), F.community(s)
      W.Disable(c)
      W.OpenReport(F.target(s, build == 16001 and "Enemy Bright-Realm" or nil), c)
      local f = W.UI.report
      f.note:SetText("Draft while disabled"); f.categories.toxic:SetChecked(true)
      assert(not W.Joined(c) and not f.submit:IsEnabled(), "reporting cannot silently override disable")
      assert(f.resume:IsVisible(), "report explains how to restore participation")
      f.community:SetValue(c.id)
      assert(not W.Joined(c), "reselecting a disabled audience does not enable it")
      click(s, f.resume)
      assert(W.Joined(c) and f.submit:IsEnabled() and not f.resume:IsVisible(), "explicit resume restores submission")
      t.equal(f.note:GetText(), "Draft while disabled", "resume retains the draft")
      click(s, f.submit)
      t.equal(W.FindCase(c, F.target(s, build == 16001 and "Enemy Bright-Realm" or nil)).active.note, "Draft while disabled", "draft saves to the selected organization")
      s:assertHealthy()
    end)

    t.test(addon .. " " .. build .. ": the off choice and its recovery survive reload", function()
      local s = new(addon, build)
      local W, c = F.W(s), F.community(s)
      W.OpenOrganizations(); click(s, W.UI.window.rows[1].action); click(s, W.UI.window.disable)
      local id, saved = c.id, W.Copy(W.db)
      s = new(addon, build, saved); W = F.W(s)
      s:advance(5)
      W.OpenOrganizations(); click(s, W.UI.window.rows[1].action)
      assert(not W.Joined(W.Get(id)), "reload and opening retain the saved opt-out")
      click(s, W.UI.window.disable)
      assert(W.CanModerate(W.Get(id)), "native owner can explicitly resume after reload")
      s:assertHealthy()
    end)

    t.test(addon .. " " .. build .. ": scoped controls fit their standalone or embedded host at large text sizes", function()
      local s = new(addon, build, nil, true)
      local W, c = F.W(s), F.community(s)
      local function apart(left, right)
        local a, b = s.bounds(left), s.bounds(right)
        assert(a[1] + a[3] <= b[1] + 0.001,
          "neighboring controls never overlap: " .. tostring(a[1] + a[3]) .. " > " .. tostring(b[1]))
      end
      local function inside(control, parent)
        local a, b = s.bounds(control), s.bounds(parent)
        assert(a[1] >= b[1] and a[2] >= b[2] and a[1] + a[3] <= b[1] + b[3] + 1
          and a[2] + a[4] <= b[2] + b[4] + 1, "action fits its visible container")
      end
      for _, scale in ipairs({ 1, 1.5 }) do
        s.ns.Core.SetFontScale(scale)
        if s.ns.Hub then s.ns.Options.OpenTool("reputation") else W.Open() end
        W.UI.SetMode("overview", c.id); W.UI.Refresh()
        local w = W.UI.window
        apart(w.browse, w.community)
        for _, group in ipairs({ w.workspaceTabs, w.pageTabs }) do
          if group.compact then inside(group.menu, w.content)
          else
            local previous
            for _, tab in ipairs(group.items) do
              if previous then apart(previous, tab) end
              inside(tab, w.content); previous = tab
            end
          end
        end
        inside(w.disable, w.overview); inside(w.openReports, w.overview)
        apart(w.disable, w.openReports); apart(w.sync, w.native)
        W.UI.SetMode("blacklist", c.id)
        apart(w.search, w.add); inside(w.add, w.content)
        W.UI.SetMode("settings")
        assert(not w.browse:IsVisible() and not w.pageTabs:IsVisible(), "preferences use only the workspace tabs")
        inside(w.workspaceTabs:Target("settings"), w.content); inside(w.heading, w.workspaceBody)
        s:assertHealthy()
      end
    end)
  end
end

t.test("personal preferences work before joining or enabling an organization", function()
  local s = F.new("Owner", { native = {} })
  local W = F.W(s)
  local w = W.Open()
  click(s, w.tabs.settings)
  assert(w.settings:IsVisible() and not w.community:IsVisible(), "preferences do not pretend to belong to an organization")
  click(s, w.toggles.filter)
  t.equal(W.db.settings.filter, false, "global preference can be changed without a membership")
  click(s, w.workspaceTabs.buttons.organizations)
  t.equal(W.UI.mode, "organizations", "preferences return to the directory")
  s:assertHealthy()
end)

t.test("participation controls affect only the explicitly selected organization", function()
  local s = F.new("Owner")
  local W, first = F.W(s), F.community(s)
  s.native[43] = W.Copy(s.native[42]); s.native[43].name = "Second community"
  local second = assert(W.Enable("club:43"))
  W.Open(); W.UI.SetMode("overview", first.id)
  local w = W.UI.window
  click(s, w.disable)
  assert(not W.Joined(first) and W.Joined(second), "disabling the selected organization does not fall back to another one")
  w.community:SetValue(second.id)
  t.equal(W.db.selected, second.id, "explicit selection changes the control's audience")
  click(s, w.disable)
  assert(not W.Joined(first) and not W.Joined(second), "second organization can be disabled independently")
  w.community:SetValue(first.id)
  assert(not W.Joined(first), "switching organizations keeps them off")
  click(s, w.disable)
  assert(W.Joined(first) and not W.Joined(second), "enabling restores only the selected organization")
  s:assertHealthy()
end)

t.test("an existing follower can explicitly enable moderation after gaining a native role", function()
  local s = F.new("Member", { native = F.native("Owner") })
  local W, c = F.W(s), F.community(s)
  s.native[42].members[W.Me()].role = 3
  W.Open(); W.UI.SetMode("overview", c.id)
  assert(not W.CanModerate(c), "following alone did not enable moderation")
  click(s, W.UI.window.openReports)
  assert(W.CanModerate(c), "explicit moderation action rechecks the current native role")
  t.equal(W.UI.mode, "proposals", "moderator enters the review workspace")
  s:assertHealthy()
end)

t.finish("Reputation UI flow: " .. t.tests .. " scenarios")
