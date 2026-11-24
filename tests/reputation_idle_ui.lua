return function()
local t = dofile("../../tools/harness.lua")("idle Reputation UI")
local new = dofile("../../tests/bounty_idle_fixture.lua")
for _, addon in ipairs({ "Highground" }) do
  for _, variant in ipairs({ { "cata", 40402 }, { "retail", 120100 }, { "retail", 16001 } }) do
    t.test(addon .. " " .. variant[2] .. " suspended windows stop UI work and revalidate drafts on return", function()
      local s = new(addon, variant[1], variant[2])
      local W, K, O = s.ns.Reputation, s.ns.Kit, s.ns.Organizations
      local id = variant[1] == "cata" and O.Guild().id or "club:42"
      local c = assert(W.Follow(id)); c.activated = true
      s:advance(30)
      W.Open()
      local window = W.UI.window
      W.OpenReport(nil, c)
      local report = W.UI.report
      report.name:SetText("Draft Person"); report.note:SetText("Keep this draft")
      local child = K.Dialog(nil, { title = "Nested context", child = true })
      K.Windows.Show(child)
      assert(not window:IsVisible() and not report:IsVisible(), "both Reputation surfaces are suspended")
      assert(window:GetParent() == s.env.UIParent, "Reputation keeps its independent window")
      local refresh, choices = W.UI.Refresh, W.UI.CommunityChoices
      local refreshes, choiceBuilds = 0, 0
      W.UI.Refresh = function(...) refreshes = refreshes + 1; return refresh(...) end
      W.UI.CommunityChoices = function(...) choiceBuilds = choiceBuilds + 1; return choices(...) end
      local guarded, calls, allocated = s.ns.Util.RunGuarded, 0, 0
      s.ns.Util.RunGuarded = function(stage, fn)
        if stage ~= "reputation sync" then return guarded(stage, fn) end
        local before = collectgarbage("count")
        local ok = guarded(stage, fn)
        allocated, calls = allocated + collectgarbage("count") - before, calls + 1
        return ok
      end
      collectgarbage("collect"); collectgarbage("stop")
      local ok, err = pcall(function() s:advance(60) end)
      collectgarbage("restart"); s.ns.Util.RunGuarded = guarded
      assert(ok, err)
      assert(calls >= 290, "real transport timer continues while UI is suspended")
      assert(allocated < 64, "suspended UI adds no repeated rendering: " .. allocated .. " KiB/min")
      t.equal(refreshes, 0, "hidden main window never rebuilds")
      t.equal(choiceBuilds, 0, "hidden report never rebuilds organization choices")
      W.Changed(c)
      t.equal(refreshes, 0, "native/model changes leave hidden main UI dormant")
      t.equal(choiceBuilds, 0, "model changes leave hidden draft controls dormant")
      -- No event: returning to the preserved draft must observe current access.
      if variant[1] == "cata" then s.guild = nil
      else s.native[42].members["Member-Realm"] = nil end
      child:Hide()
      assert(report:IsVisible() and not report.submit:IsEnabled(), "return rechecks lost membership")
      t.equal(report.name:GetText(), "Draft Person", "name survives suspension")
      t.equal(report.note:GetText(), "Keep this draft", "note survives suspension")
      assert(choiceBuilds > 0, "visible draft refreshes its choices on return")
      report:Hide()
      assert(window:IsVisible(), "closing the draft restores its separate window")
      s.env.UIParent:Hide()
      assert(window:IsShown() and not window:IsVisible(), "a hidden ancestor preserves the window's shown flag")
      local beforeRefreshes = refreshes
      W.Changed(c); s:advance(3)
      t.equal(refreshes, beforeRefreshes, "parent-hidden windows also stop automatic rendering")
      s.env.UIParent:Show()
      s:assertHealthy()
    end)
  end
end
t.finish("Idle Reputation UI: " .. t.tests .. " scenarios")
end
