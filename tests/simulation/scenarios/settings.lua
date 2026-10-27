local test, new, equal = ...

test("invalid profile imports are rejected atomically across all setting types", function()
  local sim = new("cata")
  sim:command("points killPer 9")
  local profiles, db = sim.ns.Options.Profiles, sim.env.WarboardDB
  for _, value in ipairs({ "w.range=-3", "w.range=6", "s.MAGE.1.k=999", "o.executePct=2",
    "p.focusMaxAllies=-5", "p.focusMaxAllies=2.5", "p.killPer=1e999", "p.killPer=nope",
    "p.defensiveUp=25", "o.protectCC=1", "o.goWindow=30;o.spentWindow=10",
    "p.dieResMin=11;p.dieResMax=10" }) do
    local points = db.points
    local ok, err = profiles.ImportText("WB1;f=cata;p.killPer=3;" .. value)
    equal(ok, false, "reject " .. value)
    assert(type(err) == "string" and #err > 0, "specific validation feedback")
    equal(db.points, points, "failed import preserves current table")
    equal(db.points.killPer, 9, "failed import preserves current value")
  end
end)

test("commands and actual UI inputs use the same validation as imports", function()
  local sim = new("cata")
  local db, core = sim.env.WarboardDB, sim.ns.Core
  sim:command("weight range -3")
  equal(core.W("range"), 1, "negative command multiplier rejected")
  sim:command("exec 200")
  equal(db.executePct, 0.35, "invalid execute command rejected")
  sim:command("points focusMaxAllies 2.5")
  equal(core.P("focusMaxAllies"), 5, "fractional teammate cap rejected")
  for _, row in ipairs(sim.ns.Options.rows) do
    if row.key == "focusMaxAllies" then
      row.box:SetText("-5"); row.box.scripts.OnEnterPressed(row.box)
      equal(row.box:GetText(), "5", "invalid UI input restores the current value")
      row.box:SetText("3"); row.box.scripts.OnEnterPressed(row.box)
      equal(core.P("focusMaxAllies"), 3, "valid UI input applies")
    end
  end
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
  local db, core = sim.env.WarboardDB, sim.ns.Core
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

test("behavior settings round-trip and an invalid named profile leaves current tuning intact", function()
  local sim = new("cata")
  local core, profiles, db = sim.ns.Core, sim.ns.Options.Profiles, sim.env.WarboardDB
  assert(core.SetTuning("option", "protectCC", false))
  assert(core.SetTuning("option", "switchMargin", 5))
  assert(core.SetTuning("option", "goWindow", 0))
  assert(core.SetTuning("option", "liveSort", true))
  profiles.SaveProfile("Custom")
  local exported = profiles.ExportString(profiles.Snapshot())
  assert(profiles.Decode64(exported):find("o.protectCC=false", 1, true), "false boolean is exportable")
  assert(profiles.ImportText("WB1;f=cata;p.carrierKeyCap=500;p.ccUp=-5;p.kit42292=7"))
  equal(db.protectCC, true, "omitted behavior resets to its default")
  equal(core.P("trinketDown"), 7, "old profiles keep the supported alias")
  equal(db.points.carrierKeyCap, nil, "old special cases cannot return")
  assert(profiles.ImportText(exported))
  equal(db.protectCC, false, "boolean false round-trips")
  equal(db.goWindow, 0, "zero disables GO and round-trips")
  equal(db.liveSort, true, "list policy round-trips")
  db.profiles.Bad = { points = { killPer = 9999 } }
  local before = db.points
  equal(profiles.LoadProfile("Bad"), false, "invalid named profile rejected")
  equal(db.points, before, "named-profile validation is transactional")
  assert(profiles.LoadProfile("Custom"))
  equal(db.switchMargin, 5, "valid named profile restores behavior")
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
  for _, row in ipairs(sim.ns.Options.rows) do
    if row.key == "flagCarrier" then equal(row.defaultLabel.text, "effective 45", "CTF modifier is visible") end
  end
  equal(sim.ns.Core.SettingDefs.point.ccUp, nil, "CC penalty has no remaining control")
  equal(sim.ns.Core.SettingDefs.point.carrierKeyCap, nil, "Barkskin cap has no remaining control")
end)

test("window positions are saved per character, seeded from the old shared layout", function()
  local shared = { point = { "LEFT", "LEFT", 10, 20 }, timersPoint = { "TOP", "TOP", 5, -50 } }
  local first = new("cata", shared)
  local char = first.env.WarboardCharDB
  equal(char.point[3], 10, "existing panel position carried over")
  equal(char.timersPoint[4], -50, "existing timer position carried over")
  local panel = first.env.WarboardFrame
  equal(panel:GetPoint(), "LEFT", "panel placed from the character's position")
  panel:ClearAllPoints()
  panel:SetPoint("CENTER", first.env.UIParent, "CENTER", 99, 1)
  panel.scripts.OnDragStop(panel)
  equal(char.point[1], "CENTER", "drag saved for this character")
  equal(shared.point[1], "LEFT", "shared layout untouched")
  first:command("reset")
  equal(char.point, nil, "reset clears this character's position")
  local second = new("cata", shared)
  equal(second.env.WarboardCharDB.point[1], "LEFT", "another character keeps its own position")
  equal(new("cata").env.WarboardCharDB.point, nil, "fresh install has no saved position")
end)

test("root page exports, imports and saves a profile, and follows the theme", function()
  local sim = new("retail")
  local O, db = sim.ns.Options, sim.env.WarboardDB
  local root = O.panel
  root:Show()
  local P, share = O.Profiles, O.Profiles.share
  sim:command("points killPer 9")
  root.profileName:SetText("Mine")
  local buttons = root.profileButtons
  buttons.Save.scripts.OnClick(buttons.Save)
  equal(db.profiles.Mine.points.killPer, 9, "Save stores the profile")
  equal(root.profileChips[1].text, "Mine", "chip for the saved profile")
  equal(root.profileChips[1].label.wbToken, "gold", "active profile chip is gold")
  buttons.Export.scripts.OnClick(buttons.Export)
  assert(share:IsShown(), "export opens the copy box")
  local text = share:GetText()
  assert(text:match("^[%w%+/=]+$"), "export is base64")
  assert(sim.ns.Codec.Decode64(text):match("^WB1;n=Mine;"), "named export")
  equal(share.actions.apply:IsShown(), false, "export has no Apply")

  sim:command("points killPer 3")
  buttons.Import.scripts.OnClick(buttons.Import)
  equal(share:GetText(), "", "import starts empty")
  share.box:SetText(text)
  equal(share.name:GetText(), "Mine", "name read from the paste")
  share.actions.apply.scripts.OnClick(share.actions.apply)
  equal(sim.ns.Core.P("killPer"), 9, "Apply restores the exported value")
  equal(share.status.wbToken, "success", "success colour")
  share.name:SetText("Copy")
  share.actions.save.scripts.OnClick(share.actions.save)
  equal(db.profiles.Copy.points.killPer, 9, "Save as profile")
  equal(root.profileChips[1].text, "Copy", "chips update (sorted)")
  equal(root.profileChips[2].text, "Mine", "second chip")
  share.box:SetText("WB1;f=retail;p.killPer=nope")
  share.actions.apply.scripts.OnClick(share.actions.apply)
  equal(share.status.wbToken, "error", "invalid import shows an error")
  equal(sim.ns.Core.P("killPer"), 9, "and changes nothing")

  local T = sim.ns.Theme
  assert(T.Register("test", { color = { accent = { 0.9, 0.1, 0.2 }, gold = { 0.5, 0.5, 0.5 }, textMuted = { 0.2, 0.3, 0.4 } } }))
  assert(T.Use("test"))
  local near = function(a, b, why) assert(math.abs(a - b) < 0.0001, why) end
  near(O.openHub.bg.colorTexture[1], 0.9, "Open Warboard repainted")
  near(root.profileList.textColor[1], 0.2, "muted text repainted")
  near(root.profileChips[2].label.textColor[1], 0.5, "active chip repainted")
  near(share.actions.apply.bg.colorTexture[1], 0.9, "copy box repainted")
end)
