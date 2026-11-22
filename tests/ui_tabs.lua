-- Exercised through every retained host manifest by ui_components.lua.
return function(s, t, fire)
  local K, Core, Theme = s.ns.Kit, s.ns.Core, s.ns.Theme
  t.test("page tabs confirm navigation, preserve selection and disable menu destinations", function()
    local calls, allow = 0, false
    local tabs = K.TabGroup(s.env.UIParent, { width = 800, items = {
      { key = "list", label = "Organizations" }, { key = "settings", label = "Personal preferences" },
    }, onSelect = function(group, key)
      calls = calls + 1
      if not allow then return false end
      return group:SetSelected(key)
    end })
    t.equal(tabs.selected, "list", "one initial page")
    assert(not tabs:Request("settings"), "blocked navigation is reported")
    t.equal(tabs.selected, "list", "rejected navigation keeps the old page")
    allow = true; fire(tabs.buttons.settings, "OnClick")
    assert(tabs.buttons.settings.selected and not tabs.buttons.list.selected, "only the accepted page is selected")
    fire(tabs.buttons.settings, "OnClick")
    t.equal(calls, 2, "selecting the active page never invokes navigation again")
    assert(tabs.buttons.settings.line:IsShown() and not tabs.buttons.list.line:IsShown(), "only the selected tab has its accent line")
    s.ns.Core.db.reducedMotion = true; tabs:SetSelected("list"); s.ns.Core.db.reducedMotion = nil
    t.equal(tabs.buttons.list.line:GetAlpha(), 1, "reduced motion shows the selection mark at once")
    allow = false; tabs:SetSelected("settings"); allow = true
    tabs:SetItemEnabled("list", false)
    assert(not tabs:Request("list")); t.equal(calls, 2, "disabled destinations cannot navigate")
    tabs:SetWidth(180); tabs:Layout()
    assert(tabs.compact and tabs:Target("settings") == tabs.menu, "compact guide targets the page menu")
    fire(tabs.menu, "OnClick")
    assert(K.Dropdown.Items()[1].disabled and not K.Dropdown.Frame().rows[1]:IsEnabled(), "unavailable pages remain visible and disabled")
    assert(not K.Dropdown.Accept(1) and K.Dropdown.IsShown(), "disabled menu choices cannot be accepted")
    tabs:SetItemEnabled("list", true)
    assert(not K.Dropdown.IsShown(), "availability changes retire the old menu snapshot")
    fire(tabs.menu, "OnClick"); assert(K.Dropdown.Accept(1))
    t.equal(tabs.selected, "list", "compact menu confirms selection through the same owner")
    fire(tabs.menu, "OnClick"); tabs:Hide()
    assert(not K.Dropdown.IsShown(), "closing a page retires its compact menu synchronously")
  end)

  t.test("tab layout reuses frames and follows labels, counts, fonts and themes", function()
    local scale, theme = Core.FontScale(), Theme.Current()
    local tabs = K.TabGroup(s.env.UIParent, { width = 800, items = {
      { key = "reports", label = "Reports" }, { key = "history", label = "Decision history" },
    } })
    local writes, regions = 0, { tabs, tabs.menu, tabs.buttons.reports, tabs.buttons.history }
    for _, region in ipairs(regions) do
      for _, method in ipairs({ "SetPoint", "ClearAllPoints", "SetSize", "SetHeight" }) do
        local native = region[method]
        region[method] = function(...) writes = writes + 1; return native(...) end
      end
    end
    local frames = #s.frames
    local function OwnedFrames()
      local count = 0
      for _, frame in ipairs(s.frames) do
        local parent = frame
        while parent and parent ~= tabs do parent = parent:GetParent() end
        if parent == tabs then count = count + 1 end
      end
      return count
    end
    local owned = OwnedFrames()
    for _ = 1, 30 do tabs:Layout(); tabs:SetSelected("reports"); tabs:SetItemEnabled("history", true) end
    t.equal(writes, 0, "unchanged layout performs no geometry writes")
    t.equal(#s.frames, frames, "unchanged refresh creates no frames")
    local needed = tabs.buttons.reports.tabWidth + tabs.buttons.history.tabWidth
    tabs:SetWidth(needed + 1); tabs:Layout()
    assert(not tabs.compact)
    tabs:SetCount("reports", 1200)
    assert(tabs.compact, "counts participate in fitting the complete strip")
    tabs:SetCount("reports", nil); assert(not tabs.compact)
    Core.SetFontScale(1.5)
    assert(tabs.compact, "enlarged labels use the page menu without clipping")
    tabs:SetSelected("history")
    Theme.Use(theme == "parchment" and "ember" or "parchment")
    t.equal(tabs.selected, "history", "theme changes keep selection")
    Core.SetFontScale(scale); Theme.Use(theme)
    tabs:SetWidth(800); tabs:Layout()
    assert(not tabs.compact and tabs:Target("history") == tabs.buttons.history, "wide layouts restore native tabs")
    t.equal(OwnedFrames(), owned, "font, theme and count changes reuse the controls")
    tabs:Hide()
  end)
end
