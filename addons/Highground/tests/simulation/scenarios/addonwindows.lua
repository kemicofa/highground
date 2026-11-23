local test, new, check = ...
local function equal(a, b, why)
  if type(a) == "number" and type(b) == "number" then return check(math.abs(a - b) < 0.000001, true, why or "numbers match") end
  return check(a, b, why or "values match")
end
local F = dofile("tests/modules/fixture.lua")
local function click(button)
  assert(button and button:IsVisible() and button.enabled ~= false, "control is available")
  button.scripts.OnClick(button)
end
for _, client in ipairs({ "cata", "retail", "forever" }) do
  local function make(saved, disabled, translations)
    return new(client == "cata" and "cata" or "retail", saved, function(s, env)
      F.configure(disabled)(s, env)
      if translations then
        local load = s.load
        function s:load(path)
          if path ~= "libs/locale/frFR.lua" then load(self, path) end
          if path == "libs/locale/Highground.lua" then assert(self.ns.Locale:Register("frFR", translations)) end
        end
      end
      if client == "forever" then env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end end
      dofile("../../tools/wowsim/geometry.lua")(s)
    end)
  end
  test(client .. " configuration launches independent addon windows and reuses them", function()
    local s = make()
    local ns, O, H = s.ns, s.ns.Options, s.ns.Hub
    local tools = {
      { "battlegrounds", "history", function() return ns.MatchHistory.win end },
      { "arena", "history", function() return ns.MatchHistory.win end },
      { "nearby", "journal", function() return ns.EnemyJournal.win end },
      { "bounties", "bountyboard", function() return ns.Bounty.Board.win end },
      { "reputation", "reputation", function() return ns.Reputation.UI.window end },
      { "macros", "macros", function() return ns.Macros.Window.win end },
    }
    for _, entry in ipairs(tools) do H.Open(O.addonPages[entry[1]].settings) end
    for _, entry in ipairs(tools) do assert(not entry[3](), "settings never build a workspace") end
    for _, entry in ipairs(tools) do
      local key = O.addonPages[entry[1]].settings
      H.Open(key)
      local page = O.byKey[key]
      local history = #H.router:History()
      click(page.openTool)
      local w = assert(entry[3]())
      assert(w:IsVisible() and not H.win:IsVisible(), "only the working window is visible")
      equal(w:GetParent(), s.env.UIParent, "workspace is never reparented")
      assert(w.close:IsVisible(), "workspace has its own close button")
      equal(#H.router:History(), history, "launch does not add config visits")
      click(w.close)
      assert(not w:IsVisible() and H.win:IsVisible(), "closing returns to the configuration that launched it")
      equal(H.current, key, "on its settings")
      s:setCombat(true); click(page.openTool); s:setCombat(false)
      assert(w:IsVisible(), "ordinary working windows open in combat")
      H.Open("module-" .. entry[1])
      local module = H.BuildModules(entry[1])
      local launch
      for _, button in ipairs(module.actions) do
        if button:GetText() == page.openTool:GetText() then launch = button end
      end
      click(launch); equal(entry[3](), w, "overview launches the same window")
      local count = #s.frames
      for _ = 1, 3 do H.Open(key); click(page.openTool) end
      equal(#s.frames, count, "reopening does not create more controls")
    end
    for _, button in ipairs(H.win.nav) do
      for _, entry in ipairs(tools) do assert(button.section.key ~= entry[2], "sidebar contains configuration") end
    end
    s:assertHealthy()
  end)

  test(client .. " Reputation preferences share values without navigating the workspace", function()
    local s = make()
    local W, H, O = s.ns.Reputation, s.ns.Hub, s.ns.Options
    H.Open("reputation-settings")
    local page = O.byKey["reputation-settings"]
    local prefs = page.preferences
    assert(not W.UI.window and not W.UI.router, "preferences do not create the report browser")
    click(prefs.toggles.filter); equal(W.db.settings.filter, false)
    prefs.replyInterval:SetValue(60); prefs.replyText:SetText("Blocked by {organization}.")
    click(page.openTool)
    W.UI.SetMode("settings")
    local w = W.UI.window
    equal(w.toggles.filter:GetChecked(), false)
    equal(w.replyInterval:GetValue(), 60); equal(w.replyText:GetText(), "Blocked by {organization}.")
    click(w.resetReply); click(w.resetReply); click(w.toggles.filter)
    W.UI.SetMode("organizations"); w.search:SetText("Keep this filter")
    local history = #W.UI.router:History()
    H.Open("reputation-settings")
    equal(prefs.replyText:GetText(), W.DEFAULT_REPLY); equal(prefs.toggles.filter:GetChecked(), true)
    equal(W.UI.mode, "organizations", "configuration does not select a workspace tab")
    equal(#W.UI.router:History(), history, "configuration does not add workspace history")
    for _, scale in ipairs({ 1, 1.5 }) do
      s.ns.Core.SetFontScale(scale)
      local help, body = s.bounds(prefs.settingsHelp), s.bounds(prefs.settingsBody)
      assert(help[2] + help[4] <= body[2] + body[4], "preference help fits the scrollable content")
    end
    click(page.openTool)
    equal(w.search:GetText(), "Keep this filter", "reopening preserves workspace search")
    s:assertHealthy()
  end)

  test(client .. " launcher text follows saved language, live changes and English fallback", function()
    local translated = {
      ["tools.open.macros"] = "Ouvrir les macros",
      ["tools.open.reputation"] = "Ouvrir la réputation",
      ["tools.window.help"] = "Ouvre une fenêtre séparée. Utilisez /hg pour revenir à la configuration.",
      ["tools.window.unavailable"] = "Activez {addon} puis rechargez pour ouvrir cette fenêtre.",
      ["commands.configuration.toggle"] = "Ouvrir ou fermer la configuration Highground.",
      ["reputation.preferences.help"] = string.rep("Préférences personnelles pour les messages et les infobulles. ", 8),
    }
    local s = make({ locale = "frFR" }, { battlegrounds = true }, translated)
    local O, H, L = s.ns.Options, s.ns.Hub, s.ns.Locale
    local function tooltip(button)
      for _, hook in ipairs(button.hooks.OnEnter or {}) do hook(button) end
      local text = table.concat(s.env.GameTooltip.lines, "\n")
      for _, hook in ipairs(button.hooks.OnLeave or {}) do hook(button) end
      return text
    end
    -- Macros settings are built before saved preferences are initialized.
    equal(O.byKey["macros-settings"].openTool:GetText(), translated["tools.open.macros"])
    s.ns.Core.SetFontScale(1.5)
    for _, entry in ipairs({ { "macros", "macros" }, { "reputation", "reputation" },
      { "bounties", "bountyboard" }, { "nearby", "journal" }, { "arena", "history" } }) do
      local source = assert(L.catalogs.enUS["tools.open." .. entry[2]], "every launcher has an English source")
      H.Open(O.addonPages[entry[1]].settings)
      local button = O.byKey[O.addonPages[entry[1]].settings].openTool
      equal(button:GetText(), translated["tools.open." .. entry[2]] or source, "partial translations fall back")
      assert(button.label:GetStringWidth() <= button:GetWidth() - 20, "longer labels fit at enlarged text")
      local help = entry[2] == "history" and "Activez Battlegrounds" or translated["tools.window.help"]
      assert(tooltip(button):find(help, 1, true), "tooltip uses the selected language and named addon")
      H.Open("module-" .. entry[1])
      for _, action in ipairs(H.BuildModules(entry[1]).actions) do
        if action.tool == entry[2] then
          equal(action:GetText(), button:GetText(), "Overview shares the translated label")
          assert(action.label:GetStringWidth() <= action:GetWidth() - 20, "Overview label fits")
        end
      end
    end
    H.Open("reputation-settings")
    local prefs = O.byKey["reputation-settings"].preferences
    equal(prefs.settingsHelp:GetText(), translated["reputation.preferences.help"])
    local help, body = s.bounds(prefs.settingsHelp), s.bounds(prefs.settingsBody)
    assert(help[2] + help[4] <= body[2] + body[4], "longer preference help wraps inside scrolling content")
    H.Open("tools")
    local command
    for _, item in ipairs(O.tools.commandRows) do if item.definition.command == "" then command = item end end
    equal(command.description:GetText(), translated["commands.configuration.toggle"])
    assert(tooltip(command.button):find(translated["commands.configuration.toggle"], 1, true))
    s:command("help")
    assert(table.concat(s.messages, "\n"):find(translated["commands.configuration.toggle"], 1, true), "chat help translates display copy")
    H.Open("general"); O.general.language.select:SetValue("enUS")
    equal(O.byKey["macros-settings"].openTool:GetText(), "Open macros", "live selection updates existing launcher")
    equal(command.description:GetText(), L.catalogs.enUS["commands.configuration.toggle"])
    H.Open("macros-settings"); click(O.byKey["macros-settings"].openTool)
    assert(s.ns.Macros.Window.win:IsVisible(), "translated launcher keeps its executable route")
    s:assertHealthy()
  end)

  test(client .. " old workspace sections open their configuration and disabled tools stay closed", function()
    local destinations = { macros = "macros-settings", reputation = "reputation-settings", bountyboard = "bounty",
      journal = "nearby", history = "battlegrounds-settings" }
    for key, destination in pairs(destinations) do
      local s = make()
      s:command("config " .. key)
      equal(s.ns.Hub.current, destination, "old workspace link resolves to its configuration")
      s:assertHealthy()
    end
    local s = make(nil, { macros = true, reputation = true, bounties = true, nearby = true, battlegrounds = true })
    local O, H = s.ns.Options, s.ns.Hub
    H.Open("arena-settings")
    assert(not O.byKey["arena-settings"].openTool:IsEnabled(), "Arena cannot launch disabled Battlegrounds history")
    H.Open("module-arena")
    local history
    for _, button in ipairs(H.BuildModules("arena").actions) do
      if button:GetText() == "Open match history" then history = button end
    end
    assert(history and not history:IsEnabled(), "Overview respects the tool's owning addon")
    for _, key in ipairs({ "macros", "reputation", "bounties", "nearby" }) do
      s.ns.Hub.Open("module-" .. key)
      for _, button in ipairs(s.ns.Hub.BuildModules(key).actions) do
        assert(not button:IsEnabled(), "disabled addon launchers cannot be clicked")
      end
    end
    for _, entry in ipairs({ { "macros", "macros", "macros" }, { "reputation", "reputation", "reputation" },
      { "bountyboard", "bounty", "bounties" }, { "journal", "journal", "nearby" }, { "history", "history", "battlegrounds" } }) do
      H.Open("general"); O.OpenTool(entry[1])
      equal(H.current, "module-" .. entry[3], "tool launcher offers the owning addon switch")
      H.Open("general"); s:command(entry[2])
      equal(H.current, "module-" .. entry[3], "command offers the same addon switch")
    end
    local guide = s.ns.Onboarding
    for i, owner in ipairs({ "battlegrounds", "nearby" }) do
      guide.Open(); guide.Go("records"); guide.Explore(guide.Current().actions[i + 1])
      equal(H.current, "module-" .. owner, "guide offers the tool's owning addon switch")
      assert(not guide.exploring, "unavailable tool does not start a guide excursion")
    end
    assert(not s.ns.Macros.Window.win and not s.ns.Reputation.UI.window and not s.ns.Bounty.Board.win
      and not s.ns.EnemyJournal.win and not s.ns.MatchHistory.win, "disabled tools never build their windows")
    s:assertHealthy()
  end)

end
