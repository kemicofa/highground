local _, ns = ...
local Core, Theme, C = ns.Core, ns.Theme, ns.Onboarding.Coach
local E = C.Examples

-- The guide feeds sample enemies into the real battleground panel. Every
-- row, tooltip, rank and status is laid out and rendered by the live UI.
local function Samples(cue)
  local enemies = {}
  for i, identity in ipairs({ { "Lunara", "PRIEST" }, { "Vexa", "ROGUE" }, { "Ashveil", "MAGE" } }) do
    if not cue or i == 1 then
      local key = identity[1] .. "-Sample"
      local specs = Core.classSpecs[identity[2]]
      enemies[key] = { key = key, display = key, class = identity[2], specID = specs and specs[1], specSrc = "live",
        testHp = i == 1 and 0.64 or 0.9, hpPct = i == 1 and 0.64 or 0.9,
        yards = cue ~= "unknown" and 5 or nil,
        def = cue == "DEF", immune = cue == "IMMUNE", cc = cue == "CC",
        burnedAt = cue == "SPENT" and GetTime() or nil }
    end
  end
  return enemies
end

local function Panel(cue)
  E.Hide()
  -- Placement owns lock restoration and protected-frame cleanup on combat.
  if not ns.Setup.placement then ns.Setup.BeginPlacement(true) end
  ns.Setup.PreviewContext("enemies", Samples(cue))
end

local function RowPart(key)
  local row = Core.rows[1]
  local part = key and row[key]
  return part and part:IsVisible() and part or row
end

local function RowStep(id, title, text, cue, part, hint)
  return { id = id, title = title, text = text, hint = hint,
    enter = function() Panel(cue) end,
    target = function() return RowPart(part) end, context = function() return Core.frame end }
end

local function Scene(p)
  E.Panel(p, "scene", 210, function(f)
    f.plates = {}
    for i, identity in ipairs({ { "Lunara", "Priest · healer", "PRIEST" }, { "Vexa", "Rogue · your target", "ROGUE" } }) do
      local plate = CreateFrame("Frame", nil, f, "BackdropTemplate")
      Theme.Backdrop(plate); plate:SetSize(200, 42)
      plate:SetPoint("CENTER", f, "CENTER", i == 1 and -120 or 120, 10)
      plate.fill = Theme.Fill(plate, "ARTWORK", ns.Util.ClassColor(identity[3]), 0.5)
      plate.fill:SetPoint("TOPLEFT", 2, -2); plate.fill:SetPoint("BOTTOMLEFT", 2, 2); plate.fill:SetWidth(140)
      plate.name = Theme.Text(plate, "heading", "text"); plate.name:SetPoint("CENTER"); plate.name:SetText(identity[1])
      plate.sub = Theme.Text(plate, "body", "textMuted"); plate.sub:SetPoint("TOP", plate, "BOTTOM", 0, -52); plate.sub:SetText(identity[2])
      f.plates[i] = plate
    end
    f.scope = Core.MakeScope(f); f.scope:Show()
    f.healer = Core.MakeHealerMark(f); f.healer:SetPoint("BOTTOM", f.plates[1], "TOP", 0, 14); f.healer:Show()
    f.notice = Theme.Text(f, "bodyLarge", "textMuted"); f.notice:SetPoint("CENTER"); f.notice:SetText("Enemy nameplates are hidden.\nThe sniper marker needs a visible nameplate.")
    f.notice:SetJustifyH("CENTER"); f.notice:SetWordWrap(true)
  end)
end

local function Markers()
  return E.Page("targeting:markers", "TARGET MARKERS", function(p)
    E.Text(p, "intro", "Lunara is suggested. Vexa is your current target.")
    Scene(p)
    p.crosshair, p.healer = p.scene.scope, p.scene.healer
    p.crosshair.sampleOwner, p.healer.sampleOwner = p.scene, p.scene
    E.Toggle(p, "nameplates", "Show sample enemy nameplates")
    E.Toggle(p, "recommend", "Use target recommendations in the sample")
    E.Text(p, "result", "", "bodyLarge", "accent")
    function p:Refresh(d)
      self.nameplates:SetChecked(d.nameplates, true); self.recommend:SetChecked(d.recommend, true)
      for i, plate in ipairs(self.scene.plates) do
        plate:SetShown(d.nameplates); plate:SetSize(180, 42 * math.max(1, Core.FontScale()))
        plate:ClearAllPoints(); plate:SetPoint("CENTER", self.scene, "CENTER", i == 1 and -110 or 110, 10)
      end
      local scope = self.scene.scope
      scope:ClearAllPoints(); scope:SetPoint("CENTER", self.scene.plates[d.recommend and 1 or 2], "BOTTOM", 0, -26)
      Core.PaintScope(scope, false)
      scope:SetShown(d.nameplates); self.scene.healer:SetShown(d.nameplates)
      self.scene.notice:SetShown(not d.nameplates)
      self.result:SetText(d.recommend and "Suggested: Lunara · Your target: Vexa" or "Recommendations off: the sniper marker follows your target, Vexa.")
    end
  end)
end

local function Setting(step, key, label)
  step.feature, step.settingLabel = key, label
  return step
end

local function MarkerStep(...)
  local step = E.Step(...)
  local enter = step.enter
  step.enter = function(state)
    if ns.Setup.placement then ns.Setup.EndPlacement(false) end
    enter(state)
  end
  return step
end

E.Register("markers", {
  initial = function() return { nameplates = true, recommend = true } end,
  steps = function() return {
    Setting(MarkerStep("crosshair", "The sniper marker shows the suggestion",
      "It points to Lunara. Your selected target is still Vexa; you decide whether to switch. This sample uses your saved style, colours and skull choice. Battlegrounds → Appearance → Sniper marker offers the new sight or Legacy crosshair, separate colours, placement and size. Head placement is approximate.",
      Markers, "crosshair", "Try /hg sniper test on a target with a visible nameplate, then /hg go for the kill-window look. Lower health speeds up the pulse; Reduced motion keeps it steady. Repeat /hg sniper test to stop."), "sniper", "Enable Sniper marker in game"),
    Setting(MarkerStep("healer", "This cross marks a healer", "The red cross identifies a known enemy healer. Friendly healers use a green cross.", Markers, "healer"), "healerMarks", "Enable healer marks in game"),
    MarkerStep("nameplates", "Keep enemy nameplates visible", "Turn sample nameplates off, then on. In game, these markers need visible nameplates too.", Markers, "nameplates"),
    MarkerStep("recommend", "Try following your own target", "Turn sample recommendations off. The sniper marker moves to Vexa, your current target.", Markers, "recommend"),
  } end,
})

function C.EnemySteps()
  local steps = {
    Setting(RowStep("enemy", "Your battleground enemy list", "This is your actual enemy panel with sample opponents. Hover a row for its details. In play, left-click targets and right-click keeps that enemy as your focus.", nil, nil,
      "Sample rows do not change your target or focus. Panel controls save your real preferences."), "killorder", "Enable enemy list in game"),
    RowStep("priority", "Read the recommendation rank", "The rank suggests who to attack; NOW marks the reachable suggestion. Rows use your current appearance and ordering settings.", nil, "rank",
      "If you have hidden rank numbers in Battlegrounds Appearance, the guide highlights the row instead."),
    RowStep("protection", "DEF means defense active", "Lunara has an observed defensive ability running. The real row shows DEF and dims its content.", "DEF", "pipText",
      "Status labels follow your Battlegrounds Appearance settings. Next shows that defense ending."),
    RowStep("opening", "The defense has ended", "Lunara's defensive ability has ended. SPENT marks the recent change; you still choose when to attack.", "SPENT", "pipText",
      "SPENT lasts briefly. Replay shows the defense ending again."),
    RowStep("immunity", "IMMUNE means damage is blocked", "An observed immunity prevents damage. The recommendation excludes this enemy until the immunity ends.", "IMMUNE", "pipText"),
    RowStep("control", "CC marks breakable crowd control", "Attacking this enemy may break the effect. Your target behavior settings decide whether to preserve that crowd control.", "CC", "pipText"),
    RowStep("unknown", "Unknown distance stays unknown", "The -- distance means there is no reliable range observation. It does not mean zero yards, and this enemy cannot be a reachable recommendation.", "unknown", "dist"),
  }
  for _, step in ipairs(E.Start("markers")) do steps[#steps + 1] = step end
  return steps
end
