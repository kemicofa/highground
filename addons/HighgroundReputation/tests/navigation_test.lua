local t = dofile("../../tools/harness.lua")("reputation navigation")
local F = dofile("tests/fixture.lua")
local bg = dofile("../../tools/wowsim/battleground/runtime.lua")

for _, addon in ipairs({ "Highground", "HighgroundReputation" }) do
  for _, case in ipairs({ { "retail", 120100 }, { "retail", 16001 }, { "cata", 40402 } }) do
    t.test(addon .. " " .. case[2] .. ": tabs, organization guards and child dialogs share routing", function()
      local s = F.new("Owner", { addon = addon, client = case[1], build = case[2],
        guild = case[1] == "cata" and "Test Guild" or nil, runtime = addon == "Highground" and bg or nil })
      local W = F.W(s)
      local c = F.community(s)
      for i = 1, 20 do
        local name = "Enemy" .. (case[2] == 16001 and " Bright" or "") .. string.char(64 + i) .. "-Realm"
        W.Decide(c, F.target(s, name), "ban", { toxic = true }, "")
      end
      if s.ns.Hub then s.ns.Hub.Open("reputation") else W.Open() end
      local UI, w = W.UI, W.UI.window
      local router = UI.GetRouter()
      UI.SetMode("blacklist", c.id)
      w.search:SetText("Enemy")
      local stop = router:BeforeEach(function() return false end)
      F.click(s, w.next); t.equal(UI.page, 1, "page control obeys navigation guards")
      stop(); F.click(s, w.next)
      local page = UI.page
      assert(page > 1, "list has more than one page")
      F.click(s, w.routeBack); t.equal(UI.page, 1, "Back returns to previous list page")
      t.equal(w.search:GetText(), "Enemy", "page navigation keeps search")
      F.click(s, w.routeForward); t.equal(UI.page, page, "Forward returns to next list page")
      UI.SetMode("settings")
      F.click(s, w.routeBack)
      t.equal(UI.mode, "blacklist", "Back selects prior tab")
      t.equal(w.search:GetText(), "Enemy", "filter recovered")
      t.equal(UI.page, page, "page recovered")
      local visits = #router:History()
      for _ = 1, 3 do
        assert(UI.SetMode("blacklist", c.id))
        t.equal(w.search:GetText(), "Enemy", "selected tab retains filter")
        t.equal(UI.page, page, "selected tab retains page")
        t.equal(#router:History(), visits, "selected tab does not duplicate history")
        assert(router:CanGo(1), "selected tab preserves Forward")
      end
      F.click(s, w.routeForward); t.equal(UI.mode, "settings", "Forward selects settings")
      W.OpenReport(F.target(s, case[2] == 16001 and "New Enemy-Realm" or "NewEnemy-Realm"), c)
      local report, windows = UI.report, s.ns.Kit.Windows
      report.note:SetText("Unsaved report")
      t.equal(windows.router:Current().name, windows.entries[report].route, "report uses window routing")
      local nested = s.ns.Kit.CopyBox(nil, { title = "Review context" })
      nested:Open(); nested:Hide()
      assert(report:IsVisible(), "nested dialog returns to report")
      t.equal(report.note:GetText(), "Unsaved report", "draft survives nested dialog")
      report:Hide()
      assert(w:IsVisible(), "report returns to workspace")
      t.equal(UI.mode, "settings", "tab survives report")
      W.Disable(c)
      assert(router:Back())
      t.equal(router:Current().name, "organizations", "history redirects when organization is disabled")
      t.equal(UI.mode, "organizations", "unavailable tab never displayed")
      s:assertHealthy()
    end)
  end
end

t.finish("Reputation navigation: " .. t.tests .. " scenarios")
