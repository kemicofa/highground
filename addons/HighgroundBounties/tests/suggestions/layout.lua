local t = ...
local H = dofile("tests/suggestions/fixture.lua")

for _, addon in ipairs({ "Highground", "HighgroundBounties", "HighgroundNearby" }) do
  t.test(addon .. ": suggestion tabs, reports and movable prompt fit all themes and large text", function()
    local s = H.new("Alice", { addon = addon, geometry = true })
    local B, Core = s.ns.Bounty, s.ns.Core
    local enemy = "Iron Shadow-RealmWithALongName"
    for _ = 1, 3 do H.death(s, enemy) end
    local row = B.Suggestions.Rows()[1]
    local toast = B.Suggestions.View.toast
    assert(toast and toast:IsShown())
    toast:ClearAllPoints(); toast:SetPoint("CENTER", s.env.UIParent, "CENTER", 140, -80)
    toast.scripts.OnDragStop(toast)
    t.equal(Core.db.windows.bountySuggestion[3], 140, "prompt position saved")
    local function fits(button)
      assert(s.bounds(button.label)[3] + 8 <= s.bounds(button)[3], button:GetText() .. " fits its button")
    end
    for _, theme in ipairs({ "highground", "ember", "parchment", "azeroth" }) do
      s.ns.Theme.Use(theme)
      for _, scale in ipairs({ 1, 1.5 }) do
        Core.SetFontScale(scale)
        B.Board.SetTab("suggestions"); B.Board.Open()
        if s.ns.Hub then s.ns.Hub.Open("bountyboard") end
        local w = B.Board.win
        for _, tab in pairs(w.tabs) do
          local outer, label, count = s.bounds(tab), s.bounds(tab.label), s.bounds(tab.count)
          assert(label[1] >= outer[1] and count[1] + count[3] <= outer[1] + outer[3], "tab label and count fit")
          assert(outer[2] + outer[4] < s.bounds(w.search)[2], "tabs clear search")
        end
        for _, button in ipairs({ w.rows[1].primary, w.rows[1].details, w.rows[1].more,
          toast.review, toast.dismiss, toast.ignore }) do fits(button) end
        assert(toast.body:GetStringHeight() <= toast.body:GetHeight(), "long names and summary fit the prompt")
        B.Suggestions.View.Details(row)
        local reports = B.Suggestions.View.details
        for _, button in ipairs({ reports.review, reports.dismiss, reports.ignore }) do fits(button) end
        assert(s.bounds(reports.scroll)[2] + s.bounds(reports.scroll)[4] < s.bounds(reports.review)[2], "reports scroll clears actions")
        reports:Hide()
        if s.ns.Hub then s.ns.Hub.win:Hide() end
      end
    end
    s:assertHealthy()
  end)
end
