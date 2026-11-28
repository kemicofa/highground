local test, new, equal = ...

test("slash edits update open settings without refreshing hidden pages", function()
  local s = new("cata")
  local O = s.ns.Options
  s.ns.Hub.Open("multipliers"); s.ns.Hub.Open("priority"); s:advance(0.02)
  local row
  for _, candidate in ipairs(O.rows) do if candidate.key == "killPer" then row = candidate end end
  assert(row, "the visible priority input exists")
  local hidden = 0
  local refresh = O.byKey.multipliers.RefreshBehavior
  O.byKey.multipliers.RefreshBehavior = function() hidden = hidden + 1; if refresh then refresh() end end
  s:command("points killPer 9")
  equal(s.ns.Core.P("killPer"), 9, "command changes runtime score")
  equal(row.box:GetText(), "9", "open input reflects command")
  s:command("points killPer reset")
  equal(row.box:GetText(), "6", "open input reflects command reset")
  equal(hidden, 0, "hidden settings stay idle")
  s:assertHealthy()
end)

test("target tuning labels follow saved and live language choices", function()
  local s = new("cata", { locale = "frFR" })
  local O, L = s.ns.Options, s.ns.Locale
  s.ns.Hub.Open("behavior")
  s.ns.Hub.Open("priority")
  s.ns.Hub.Open("multipliers")
  local rows = {}
  for _, row in ipairs(O.rows) do
    if row.key == "switchMargin" or row.key == "killPer" or row.key == "kill" then rows[#rows + 1] = row end
  end
  equal(#rows, 3, "behavior, points and multipliers have real controls")
  for _, locale in ipairs({ "frFR", "ruRU", "enUS" }) do
    s.ns.Localization.SetPreference(locale)
    for _, row in ipairs(rows) do
      equal(row.label:GetText(), L:Get(s.ns.Localization.Key(row.source, "desc")), "translated row " .. row.key)
    end
  end
  s:assertHealthy()
end)

test("cooldown tracking search and bulk controls clear translated help at large text sizes", function()
  local s = new("cata", nil, function(s) dofile("../../tools/wowsim/geometry.lua")(s) end)
  s.ns.Hub.Open("tracking")
  s.ns.Core.SetFontScale(1.5)
  local page = s.ns.Options.byKey.tracking
  local frameCount = #s.frames
  for _, locale in ipairs({ "enUS", "frFR", "ruRU", "deDE" }) do
    s.ns.Localization.SetPreference(locale); s:advance(0.02)
    local hint, caption, bar, body = s.bounds(page.hint), s.bounds(page.search.caption), s.bounds(page.toolbar), s.bounds(page.scroll)
    assert(hint[2] + hint[4] <= caption[2], "search caption clears wrapped help in " .. locale)
    assert(bar[2] + bar[4] <= body[2], "scrolling spells clear all toolbar rows in " .. locale)
    for _, button in ipairs({ page.trackShown, page.untrackShown }) do
      local b = s.bounds(button)
      assert(b[1] >= bar[1] and b[1] + b[3] <= bar[1] + bar[3] + 0.01, "bulk action fits translated toolbar")
    end
  end
  equal(#s.frames, frameCount, "language/layout changes reuse existing controls")
  local offensive = s.ns.Locale:Get("highground.tracking.offensive.d05a4a")
  page.search:SetText(offensive)
  local matches = 0
  for _, cb in ipairs(page.trackingBoxes) do
    if cb.matches then matches = matches + 1; equal(cb.entry[3], "burst", "search uses current translated kind") end
  end
  assert(matches > 0, "translated category search finds spells")
  page.untrackShown:GetScript("OnClick")(page.untrackShown)
  for _, cb in ipairs(page.trackingBoxes) do
    if cb.matches then equal(s.ns.Core.db.disabledCooldowns[cb.spellID], true, "bulk action reaches saved tracking") end
  end
  page.trackShown:GetScript("OnClick")(page.trackShown)
  for _, cb in ipairs(page.trackingBoxes) do
    if cb.matches then equal(s.ns.Core.db.disabledCooldowns[cb.spellID], nil, "track restores runtime default") end
  end
  s:assertHealthy()
end)

test("invalid profile imports are rejected atomically across all setting types", function()
  local sim = new("cata")
  sim:command("points killPer 9")
  local P, CS, db = sim.ns.Options.Profiles, sim.ns.CharacterSettings, sim.env.HighgroundDB
  local function Count() return #(db.profileImports or {}) end
  for _, value in ipairs({ "w.range=-3", "w.range=6", "s.MAGE.1.k=999", "o.executePct=2",
    "p.focusMaxAllies=-5", "p.focusMaxAllies=2.5", "p.killPer=1e999", "p.killPer=nope",
    "p.defensiveUp=25", "o.protectCC=1", "o.goWindow=30;o.spentWindow=10",
    "p.dieResMin=11;p.dieResMax=10" }) do
    local points, imports = db.points, Count()
    local text = "WB1;f=cata;p.killPer=3;" .. value
    local prepared, problem = P.Prepare(assert(P.ParseString(text)))
    equal(prepared, nil, "validation rejects " .. value)
    assert(type(problem) == "string" and #problem > 0, "specific validation feedback")
    local ok, err = CS.Import(text)
    equal(ok, false, "reject " .. value)
    assert(type(err) == "string" and #err > 0, "the import says why")
    equal(Count(), imports, "a rejected import adds nothing")
    equal(db.points, points, "failed import preserves current table")
    equal(db.points.killPer, 9, "failed import preserves current value")
  end
  local Codec = sim.ns.Codec
  local bad = Codec.Encode64("WB2;n=Bad;f=cata;a=battlegrounds;x=" .. Codec.Encode64(Codec.Pack({
    bg10 = { points = { killPer = 3 } }, bg40 = { points = { killPer = 9999 } } })))
  equal(select(1, CS.Import(bad)), false, "one invalid size rejects the whole code")
  equal(Count(), 0, "and adds nothing")
  equal(db.points.killPer, 9, "and changes nothing")
end)

test("commands and actual UI inputs use the same validation as imports", function()
  local sim = new("cata")
  local db, core = sim.env.HighgroundDB, sim.ns.Core
  sim:command("weight range -3")
  equal(core.W("range"), 1, "negative command multiplier rejected")
  sim:command("exec 200")
  equal(db.executePct, 0.35, "invalid execute command rejected")
  sim:command("points focusMaxAllies 2.5")
  equal(core.P("focusMaxAllies"), 5, "fractional teammate cap rejected")
  sim.ns.Options.pointPages.live.frame:Show()
  local tested
  for _, row in ipairs(sim.ns.Options.rows) do
    if row.key == "focusMaxAllies" then
      tested = true
      row.box:SetText("-5"); row.box.scripts.OnEnterPressed(row.box)
      equal(row.box:GetText(), "5", "invalid UI input restores the current value")
      row.box:SetText("3"); row.box.scripts.OnEnterPressed(row.box)
      equal(core.P("focusMaxAllies"), 3, "valid UI input applies")
    end
  end
  assert(tested, "the visible page contains the teammate cap input")
  local ok = core.SetTuning("weight", "range", 0 / 0)
  equal(ok, false, "NaN cannot enter tuning")
end)

test("saved tuning repairs invalid values and removes obsolete special cases", function()
  local sim = new("cata", {
    points = { kit42292 = 11, trinketDown = 4, carrierKeyCap = 99, ccUp = -100,
      focusMaxAllies = -5, killPer = math.huge, kit123456 = 2, dieResMin = 50, dieResMax = 2 },
    weights = { range = -3, cc = 2 }, executePct = 2, protectCC = false,
    goWindow = 30, spentWindow = 10, specRatings = { [8001] = { k = 999, i = 9 } },
  })
  local db, core = sim.env.HighgroundDB, sim.ns.Core
  equal(core.P("trinketDown"), 11, "canonical trinket migration retains its effective value")
  equal(db.points.kit42292, nil, "alias removed")
  equal(db.points.carrierKeyCap, nil, "Barkskin special cap removed")
  equal(db.points.ccUp, nil, "obsolete CC penalty removed")
  equal(db.weights.cc, nil, "obsolete CC multiplier removed")
  equal(db.points.kit123456, nil, "unknown spell override removed")
  equal(core.P("killPer"), 6, "nonfinite saved points reset")
  equal(core.P("focusMaxAllies"), 5, "invalid saved count resets")
  equal(core.W("range"), 1, "invalid saved multiplier resets")
  equal(db.executePct, 0.35, "invalid saved threshold resets")
  equal(db.protectCC, false, "explicit false survives normalization")
  equal(db.goWindow, 10, "related timing bounds repaired")
  equal(core.P("dieResMin"), 2, "invalid timer pair resets together")
  equal(core.P("dieResMax"), 10, "invalid timer pair resets together")
  equal(db.specRatings[8001].k, nil, "invalid saved rating removed")
  equal(db.specRatings[8001].i, 9, "valid saved rating preserved")
end)

test("behavior settings round-trip and an invalid saved profile leaves current tuning intact", function()
  local sim = new("cata")
  local core, profiles, CS, db = sim.ns.Core, sim.ns.Options.Profiles, sim.ns.CharacterSettings, sim.env.HighgroundDB
  local function Apply(code)
    local ok, _, index = CS.Import(code)
    return ok and CS.Copy({ import = index }, "battlegrounds")
  end
  assert(core.SetTuning("option", "protectCC", false))
  assert(core.SetTuning("option", "switchMargin", 5))
  assert(core.SetTuning("option", "goWindow", 0))
  assert(core.SetTuning("option", "liveSort", true))
  local saved = CS.Export("battlegrounds")
  local exported = profiles.ExportString(profiles.Snapshot())
  assert(profiles.Decode64(exported):find("o.protectCC=false", 1, true), "false boolean is exportable")
  assert(Apply("WB1;f=cata;p.carrierKeyCap=500;p.ccUp=-5;p.kit42292=7"))
  equal(db.protectCC, true, "omitted behavior resets to its default")
  equal(core.P("trinketDown"), 7, "old profiles keep the supported alias")
  equal(db.points.carrierKeyCap, nil, "old special cases cannot return")
  assert(Apply(exported))
  equal(db.protectCC, false, "boolean false round-trips")
  equal(db.goWindow, 0, "zero disables GO and round-trips")
  equal(db.liveSort, true, "list policy round-trips")
  -- A profile an older version saved without checking it.
  db.profileImports[#db.profileImports + 1] = { name = "Bad", received = 0, snap = { points = { killPer = 9999 } } }
  local before = db.points
  equal(CS.Copy({ import = #db.profileImports }, "battlegrounds"), false, "invalid saved profile rejected")
  equal(db.points, before, "copy validation is transactional")
  assert(core.SetTuning("option", "switchMargin", 1))
  assert(Apply(saved))
  equal(db.switchMargin, 5, "a valid export restores behavior")
end)

test("target behavior preview explains exclusions and effective battleground values", function()
  local sim = new("cata")
  sim:enemy("Blocked", { marker = 8, buffs = { { spellId = 45438 } } })
  sim:enemy("Available")
  sim:join(206, 489, "Warsong Gulch")
  local behavior
  for _, page in ipairs(sim.ns.Options.pages) do if page.name == "Target behavior" then behavior = page end end
  assert(behavior)
  behavior.frame:Show()
  assert(behavior.preview.text:find("Recommended: Available", 1, true))
  assert(behavior.preview.text:find("immune", 1, true))
  assert(behavior.preview.text:find("impact", 1, true), "preview includes score components")
  sim.ns.Options.pointPages.objectives.frame:Show()
  local tested
  for _, row in ipairs(sim.ns.Options.rows) do
    if row.key == "flagCarrier" then
      tested = true
      equal(row.defaultLabel.text, "effective 45", "CTF modifier is visible")
    end
  end
  assert(tested, "the visible page contains the flag carrier score")
  equal(sim.ns.Core.SettingDefs.point.ccUp, nil, "CC penalty has no remaining control")
  equal(sim.ns.Core.SettingDefs.point.carrierKeyCap, nil, "Barkskin cap has no remaining control")
end)

test("window positions are saved per character, seeded from the old shared layout", function()
  local shared = { point = { "LEFT", "LEFT", 10, 20 }, timersPoint = { "TOP", "TOP", 5, -50 } }
  local first = new("cata", shared)
  local char = first.env.HighgroundCharDB
  equal(char.point[3], 10, "existing panel position carried over")
  equal(char.timersPoint[4], -50, "existing timer position carried over")
  local panel = first.env.HighgroundFrame
  equal(panel:GetPoint(), "LEFT", "panel placed from the character's position")
  panel:ClearAllPoints()
  panel:SetPoint("CENTER", first.env.UIParent, "CENTER", 99, 1)
  panel.scripts.OnDragStop(panel)
  equal(char.point[1], "CENTER", "drag saved for this character")
  equal(shared.point[1], "LEFT", "shared layout untouched")
  first:command("reset")
  equal(char.point, nil, "reset clears this character's position")
  local second = new("cata", shared)
  equal(second.env.HighgroundCharDB.point[1], "LEFT", "another character keeps its own position")
  equal(new("cata").env.HighgroundCharDB.point, nil, "fresh install has no saved position")
end)

test("settings pages use kit controls: toggle, stepper and theme repaint", function()
  local sim = new("retail")
  local Options, Core, T = sim.ns.Options, sim.ns.Core, sim.ns.Theme
  local function page(name)
    for _, p in ipairs(Options.pages) do if p.name == name then p.frame:Show(); return p end end
  end
  local general = assert(page("Shared preferences"))
  local minimap
  for _, cb in ipairs(Options.featureBoxes) do if cb.key == "minimap" then minimap = cb end end
  assert(minimap and minimap:GetChecked(), "minimap switch starts on")
  local button = sim.env.HighgroundMinimapButton
  assert(button:IsShown(), "minimap button shown")
  minimap.scripts.OnClick(minimap)
  equal(Core.On("minimap"), false, "toggle switches the feature off")
  equal(minimap:GetChecked(), false, "toggle shows it")
  assert(not button:IsShown(), "side effect: minimap button hidden")
  minimap.scripts.OnClick(minimap)
  equal(Core.On("minimap"), true, "and back on")
  assert(button:IsShown(), "button back")

  Options.pointPages.priority.frame:Show()
  local row
  for _, r in ipairs(Options.rows) do if r.key == "killPer" then row = r end end
  assert(row and row.stepper, "scoring row has a stepper")
  row.stepper.plus.scripts.OnClick(row.stepper.plus)
  equal(Core.P("killPer"), 7, "+ adds one step")
  equal(sim.env.HighgroundDB.points.killPer, 7, "saved")
  equal(row.box:GetText(), "7", "box shows it")
  sim.shift = true
  row.stepper.minus.scripts.OnClick(row.stepper.minus)
  sim.shift = false
  equal(Core.P("killPer"), 2, "shift-click steps by five")
  row.reset.scripts.OnClick(row.reset)
  equal(sim.env.HighgroundDB.points.killPer, nil, "x restores the default")
  local said = #sim.messages
  sim.shift = true
  for _ = 1, 3 do row.stepper.minus.scripts.OnClick(row.stepper.minus) end
  sim.shift = false
  equal(Core.P("killPer"), 0, "- stops at the lowest value")
  assert(Core.SetTuning("point", "killPer", 498))
  sim.shift = true; row.stepper.plus.scripts.OnClick(row.stepper.plus); sim.shift = false
  row.stepper.plus.scripts.OnClick(row.stepper.plus)
  equal(Core.P("killPer"), 500, "+ stops at the highest value")
  equal(#sim.messages, said, "steps at a limit print no error")

  local nearby = Options.byKey["nearby-appearance"]
  nearby.frame:Show()
  local rows = nearby.nearbyRows
  equal(Core.O("nearbyRows"), 5, "a fresh install lists five nearby enemies")
  rows.reset.scripts.OnClick(rows.reset)
  equal(Core.O("nearbyRows"), 10, "Default is the setting's default")
  equal(rows.reset:IsEnabled(), false, "and then has nothing to reset")
  sim.shift = true
  for _ = 1, 3 do rows.stepper.plus.scripts.OnClick(rows.stepper.plus) end
  sim.shift = false
  equal(Core.O("nearbyRows"), 20, "+ stops at the most nearby enemies")
  equal(#sim.messages, said, "steps at a limit print no error")

  local title = general.title
  local before = title.textColor[1]
  assert(T.Register("optionsTest", { color = { titleText = { 0.2, 0.9, 0.3 } } }))
  assert(T.Use("optionsTest"))
  assert(math.abs(title.textColor[1] - 0.2) < 0.0001 and before ~= 0.2, "page header repainted")
  assert(T.Use("highground"))
  equal(title.textColor[1], before, "and back")
end)

test("damaged saved settings reset on load; legacy dialog positions move to windows", function()
  local saved = { sniperVersion = 4, soundVersion = 2, rows = "x", minimapAngle = {}, scale = 9,
    markIcon = 2.5, markMode = "laser", callChannel = "guild", sniperColor = "plaid", sniperSound = 99,
    compact = "yes", theme = 4, hubSection = "bounty", sniperY = -80, sound = false,
    bountyPoint = { "TOP", "TOP", 4, -30 }, macroPoint = { "LEFT", "LEFT", 1, 2 },
    hubPoint = "broken", windows = { macros = { "RIGHT", "RIGHT", 7, 8 } } }
  local sim = new("cata", saved)
  local db, core = sim.env.HighgroundDB, sim.ns.Core
  equal(db, saved, "same saved table")
  equal(db.rows, core.DEFAULTS.rows, "wrong type reset")
  equal(db.minimapAngle, nil, "table angle dropped")
  equal(db.scale, core.DEFAULTS.scale, "out of range reset")
  equal(db.markIcon, core.DEFAULTS.markIcon, "fractional icon reset")
  equal(db.markMode, core.DEFAULTS.markMode, "unknown mode reset")
  equal(db.callChannel, "s", "unknown channel reset")
  equal(db.sniperColor, core.SNIPER_DEFAULT, "unknown colour reset")
  equal(db.sniperSound, core.DEFAULTS.sniperSound, "unknown sound reset")
  equal(db.compact, false, "string switch reset")
  equal(db.theme, nil, "non-string theme dropped")
  equal(db.hubSection, "bounty", "valid section kept")
  equal(db.sniperY, -80, "valid offset kept")
  equal(db.sound, false, "valid switch kept")
  equal(db.windows.bounty[1], "TOP", "bounty position migrated")
  equal(db.windows.bounty[4], -30, "bounty offset migrated")
  equal(db.windows.macros[1], "RIGHT", "existing window position wins")
  equal(db.windows.hub, nil, "damaged legacy position skipped")
  equal(sim.ns.Kit.SavedPoint("bounty")[3], 4, "kit reads the migrated position")
  saved.bountyPoint = { "BOTTOM", "BOTTOM", 5, 6 }
  local again = new("cata", saved)
  equal(again.env.HighgroundDB.windows.bounty[1], "BOTTOM", "copy follows the old key until the kit saves")
  local frame = again.env.CreateFrame("Frame", nil, again.env.UIParent)
  frame:SetPoint("LEFT", again.env.UIParent, "LEFT", 9, 9)
  again.ns.Kit.SavePoint("bounty", frame)
  local third = new("cata", saved)
  equal(third.env.HighgroundDB.windows.bounty[1], "LEFT", "kit-saved position is not overwritten")
end)

test("root page exports, imports and copies a profile, and follows the theme", function()
  local sim = new("retail")
  local O, CS, Core, db = sim.ns.Options, sim.ns.CharacterSettings, sim.ns.Core, sim.env.HighgroundDB
  local root = O.panel
  root:Show()
  sim:command("points killPer 9")
  root.export:Click()
  local export = sim.env.HighgroundProfileExport
  assert(export:IsShown(), "export opens the copy box")
  local text = export:GetText()
  assert(text:match("^[%w%+/=]+$"), "export is base64")
  assert(sim.ns.Codec.Decode64(text):find("WB2;n=" .. CS.Name() .. ";", 1, true) == 1, "named after this character")
  equal(export.actions.add, nil, "export has no Add")
  export:Hide()

  sim:command("points killPer 3")
  root.import:Click()
  local import = sim.env.HighgroundProfileImport
  equal(import:GetText(), "", "import starts empty")
  import.box:SetText(text)
  import.actions.add:Click()
  equal(import.status.wbToken, "success", "success colour")
  equal(Core.P("killPer"), 3, "adding an import applies nothing")
  local row
  for _, r in ipairs(root.rows) do if r:IsShown() and r.item.kind == "import" then row = r end end
  assert(row, "the import is listed")
  row.copy:Click(); row.copy:Click()
  equal(Core.P("killPer"), 9, "copying restores the exported value")
  local count = #db.profileImports
  import.box:SetText("WB1;f=retail;p.killPer=nope")
  import.actions.add:Click()
  equal(import.status.wbToken, "error", "invalid import shows an error")
  equal(#db.profileImports, count, "and adds nothing")
  equal(Core.P("killPer"), 9, "and changes nothing")

  local T = sim.ns.Theme
  assert(T.Register("test", { color = { accent = { 0.9, 0.1, 0.2 }, gold = { 0.5, 0.5, 0.5 }, textMuted = { 0.2, 0.3, 0.4 } } }))
  assert(T.Use("test"))
  local near = function(a, b, why) assert(math.abs(a - b) < 0.0001, why) end
  near(import.actions.add.bg.colorTexture[1], 0.9, "copy box action repainted")
  near(root.hint.textColor[1], 0.2, "page text repainted")
  near(row.detail.textColor[1], 0.2, "profile rows repainted")
end)
