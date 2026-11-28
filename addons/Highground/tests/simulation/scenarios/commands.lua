local test, newClient, equal = ...
-- Exercise the existing full-feature setup; fresh installs are covered by onboarding.
local function new(client, saved, configure) return newClient(client, saved or {}, configure) end

test("command dispatch preserves profile names, import case and settings aliases", function()
  local sim = new("cata")
  local db, CS, P = sim.env.HighgroundDB, sim.ns.CharacterSettings, sim.ns.Options.Profiles
  local function find(name)
    for _, item in ipairs(CS.Profiles("battlegrounds")) do if item.name == name then return item end end
  end
  sim:command("points killPer 9")
  local code = P.ExportString(P.Snapshot(), "Assault Setup")
  sim:command("points killPer 2")
  sim:command("import " .. code)
  assert(find("Assault Setup"), "profile name keeps original case")
  equal(db.points.killPer, 2, "importing applies nothing")
  sim:command("profile copy battlegrounds assault setup")
  equal(db.points.killPer, 9, "copying the import restores scoring")
  sim:command("import WB1;f=cata;p.killPer=7;s.MAGE.1.k=8")
  local plain
  for _, item in ipairs(CS.Profiles("battlegrounds")) do
    if item.kind == "import" and item.name ~= "Assault Setup" then plain = item end
  end
  assert(plain, "a plain old code imports")
  sim:command("profile copy battlegrounds " .. plain.name)
  equal(db.points.killPer, 7, "import keeps numeric values")
  equal(db.specRatings[8001].k, 8, "class token case survives command parser")
  sim:command("options")
  assert(sim.env.HighgroundHub:IsShown(), "options alias opens the Highground window")
  sim.env.HighgroundHub:Hide()
  sim:command("config blizzard")
  assert(sim.ns.Options.panel:IsShown(), "config blizzard opens the actual settings panel")
  sim:command("weight range 2")
  equal(db.weights.range, 2, "weight command dispatches")
  local before = #sim.messages
  sim:command("weight")
  assert(#sim.messages > before + 1, "empty weight argument lists coefficients")
  sim:command("rows invalid")
  equal(db.rows, 40, "invalid numeric input preserves settings")
  sim:command("scale invalid")
  equal(db.scale, 0.8, "invalid scale preserves settings")
  sim:command("profile delete Assault Setup")
  equal(find("Assault Setup"), nil, "named profile deletion dispatches")
end)

test("diagnostic and display commands operate on the running addon", function()
  local sim = new("cata")
  sim:enemy("Enemy")
  sim:join()
  for _, command in ipairs({ "why", "kit", "err", "clearerr", "probe", "map", "intel", "timers", "help" }) do
    local before = #sim.messages
    sim:command(command)
    assert(#sim.messages > before, command .. " must produce feedback")
  end
  sim:command("call")
  assert(sim.chatDraft:find("Enemy", 1, true), "call command prepares selected target")
  sim:command("lock")
  equal(sim.env.HighgroundDB.locked, true, "lock saved")
  sim:command("unlock")
  equal(sim.env.HighgroundDB.locked, false, "unlock saved")
  sim:command("sniper test")
  sim:command("go")
  equal(sim.ns.Core.sniperTest.go, true, "sniper preview gets its own GO command")
  sim:command("sniper test")
  sim:command("go")
  assert(sim.ns.Test.order[1].burnedAt, "normal GO command previews current enemy")
end)

test("/hg sound mutes every Highground sound", function()
  local sim = new("cata")
  local Core = sim.ns.Core
  sim.env.HighgroundDB.sniperSound = 1
  local before = #sim.sounds
  Core.PlaySniperSound()
  sim:advance(0.2)
  equal(#sim.sounds, before + 1, "lock-on sound plays")
  sim:command("sound")
  equal(sim.env.HighgroundDB.sound, false, "sound switched off")
  Core.PlaySniperSound()
  sim:advance(0.2)
  equal(#sim.sounds, before + 1, "lock-on sound muted")
  sim.units.nameplate1 = { name = "Ganker", classID = 4, enemy = true, level = 60 }
  sim:event("NAME_PLATE_UNIT_ADDED", "nameplate1")
  sim:advance(1)
  equal(#sim.sounds, before + 1, "nearby alert muted")
end)

test("Addon pages run previews and Help and commands lists every command", function()
  local sim = new("cata")
  local page
  for _, p in ipairs(sim.ns.Options.pages) do if p.name == "Help and commands" then page = p end end
  assert(page, "Help and commands page")
  local main
  sim.ns.Hub.Open("battlegrounds-previews")
  for _, b in ipairs(sim.ns.Options.byKey["battlegrounds-previews"].previews) do if b.cmd == "bg test" then main = b end end
  main.scripts.OnClick(main)
  sim:advance(1)
  assert(sim.ns.Core.testMode, "Main panel button runs /hg bg test")
  main.scripts.OnClick(main)
  sim:advance(1)
  assert(not sim.ns.Core.testMode, "clicking again stops the preview")
  for _, module in ipairs(sim.ns.Modules.list) do
    sim.ns.Hub.Open(sim.ns.Options.addonPages[module.key].previews)
    for _, button in ipairs(sim.ns.Options.byKey[sim.ns.Options.addonPages[module.key].previews].previews) do
      if button.enabled ~= false then button.scripts.OnClick(button); sim:advance(0.5) end
      if button.enabled ~= false then button.scripts.OnClick(button); sim:advance(0.5) end
    end
  end
  -- Aliases are declared explicitly; pipes inside argument choices are not verbs.
  for command in pairs(sim.ns.CommandCatalog.byCommand) do
    local verb = command:match("^%S+")
    assert(not verb or sim.ns.Commands[verb], "listed command exists: " .. command)
  end
  local retail = new("retail")
  retail.ns.Hub.Open("battlegrounds-previews")
  for _, b in ipairs(retail.ns.Options.byKey["battlegrounds-previews"].previews) do
    assert(b.cmd ~= "burst test", "Cata-only previews hidden on Retail")
  end
end)

test("minimap button opens settings and a quick menu, moves and can be switched off", function()
  local compartment
  local sim = new("retail", nil, function(s)
    s.env.AddonCompartmentFrame = { RegisterAddon = function(_, item) compartment = item end }
  end)
  local b = sim.env.HighgroundMinimapButton
  assert(b and b:IsShown(), "button at the minimap")
  equal(b.icon.texture, sim.ns.Core.BRAND_ICON, "minimap uses the compact Highground mark")
  equal(compartment.icon, b.icon.texture, "addon compartment uses the same brand mark")
  b.scripts.OnClick(b, "RightButton")
  local menu = sim.env.HighgroundDropdown
  assert(menu and menu:IsShown(), "right-click menu")
  local macros
  for _, row in ipairs(menu.rows) do if row:IsShown() and row.label:GetText() == "Macros" then macros = row end end
  macros.scripts.OnClick(macros)
  assert(sim.env.HighgroundMacroFrame:IsShown(), "menu opens the macros window")
  assert(not menu:IsShown(), "menu closes")
  b.scripts.OnClick(b, "RightButton")
  local reputation
  for _, row in ipairs(menu.rows) do if row:IsShown() and row.label:GetText() == "Reputation" then reputation = row end end
  assert(reputation, "minimap menu includes Reputation")
  reputation.scripts.OnClick(reputation)
  equal(sim.ns.Reputation.UI.window:GetParent(), sim.env.UIParent, "shortcut opens a separate window")
  assert(sim.ns.Reputation.UI.window:IsVisible(), "shortcut opens the Reputation workspace")
  assert(not menu:IsShown(), "Reputation shortcut closes the menu")
  sim.env.GetCursorPosition = function() return 100, 0 end
  b.scripts.OnDragStart(b)
  b.scripts.OnUpdate(b, 0.1)
  b.scripts.OnDragStop(b)
  equal(sim.env.HighgroundDB.minimapAngle, 0, "dragging saves the angle")
  for _, p in ipairs(sim.ns.Options.pages) do
    if p.key == "general" then
      sim.env.HighgroundDB.minimap = false
      sim.ns.MinimapButton.Apply()
    end
  end
  assert(not b:IsShown(), "General page switch hides it")
end)

test("/hg help prints every catalog command available on the client", function()
  for _, client in ipairs({ "cata", "retail" }) do
    local sim = new(client)
    local before = #sim.messages
    sim:command("help")
    local out = table.concat(sim.messages, "\n", before + 1)
    assert(out:find("you: ", 1, true), "spec line")
    assert(out:find("Key Bindings", 1, true), "keybind hint")
    for _, row in ipairs(sim.ns.CommandCatalog.commands) do
      if row[2] then
        local shown = out:find((row[1]:gsub("|", "||")), 1, true) ~= nil -- pipes printed as text
        local expected = not (row.cata and client == "retail") and not (row.caps and not sim.ns.Caps[row.caps])
        equal(shown, expected, client .. " help lists " .. row[1])
      end
    end
  end
end)

test("/hg arena off goes through Core.SetFeature and refreshes the General page", function()
  local sim = new("cata")
  local box
  sim.ns.Options.BuildPage("arena-settings")
  for _, cb in ipairs(sim.ns.Options.featureBoxes) do if cb.key == "arena" then box = cb end end
  sim.ns.Options.RefreshFeatures() -- the General page as shown
  assert(box and box:GetChecked(), "arena switch starts on")
  local set = sim.ns.Core.SetFeature
  local seen
  sim.ns.Core.SetFeature = function(key, on) seen = key; return set(key, on) end
  sim:command("arena off")
  sim.ns.Core.SetFeature = set
  equal(seen, "arena", "command uses Core.SetFeature")
  equal(sim.env.HighgroundDB.arena, false, "arena saved off")
  assert(not box:GetChecked(), "General page checkbox follows")
  assert(sim.messages[#sim.messages]:find("Arena: off", 1, true), "status line")
end)

test("WoW Forever has no Arena command, page or switch", function()
  local sim = new("retail", nil, function(_, env)
    env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end
  end)
  local C = sim.ns.CommandCatalog
  equal(C.byCommand.arena, nil, "no catalog entry")
  equal(sim.ns.Commands.arena, nil, "no handler")
  for _, page in ipairs(sim.ns.Options.pages) do sim.ns.Options.BuildPage(page) end
  for _, cb in ipairs(sim.ns.Options.featureBoxes) do assert(cb.key ~= "arena", "no Arena switch") end
  equal(sim.ns.Onboarding.Find("arena"), nil, "no Arena guide chapter")
  sim:command("arena on")
  equal(sim.env.HighgroundDB.arena, nil, "the setting is untouched")
  assert(not sim.ns.Core.On("arena"), "Arena features stay off")
  for _, section in ipairs(sim.ns.Hub.Sections()) do
    assert(section.module ~= "arena" and not (section.key or ""):find("arena", 1, true), "no Arena hub entries")
  end
  sim:assertHealthy()
end)

test("probe reports every result, including values after a nil", function()
  local sim = new("cata")
  local enemy = sim:enemy("Probed")
  sim:join()
  sim.units.target = enemy
  sim.env.GetRaidTargetIndex = function() return nil, "second" end
  sim:command("probe")
  local line
  for _, message in ipairs(sim.messages) do if message:find("GetRaidTargetIndex = ", 1, true) then line = message end end
  assert(line and line:find("nil, second", 1, true), "nil gap keeps later results: " .. tostring(line))
  local saved = sim.env.HighgroundDB.lastProbe
  assert(saved and #saved.lines > 0, "probe saved for SavedVariables")
end)
