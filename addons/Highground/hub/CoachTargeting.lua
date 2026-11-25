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
      local hidden = cue == "spectag" -- a spec the game hasn't revealed
      -- "seen": out of view, health from the last reading (held for the step).
      local hp = cue ~= "seen" and (i == 1 and 0.64 or 0.9) or nil
      enemies[key] = { key = key, display = key, class = identity[2], specID = not hidden and specs and specs[1] or nil,
        specSrc = not hidden and "live" or nil,
        testHp = hp, hpPct = hp, hpSeen = not hp and 64 or nil, lastSeen = not hp and math.huge or nil,
        yards = cue ~= "unknown" and 5 or nil,
        def = cue == "DEF", immune = cue == "IMMUNE", cc = cue == "CC",
        burnedAt = cue == "SPENT" and GetTime() or nil }
    end
  end
  return enemies
end

local function Panel(cue)
  E.Hide()
  Core.HideSpecPicker()
  -- Placement owns lock restoration and protected-frame cleanup on combat.
  ns.Setup.BeginPlacement(true, "enemies", Samples(cue))
  -- The picker normally opens on hover; the guide holds it open on Lunara.
  if cue == "spectag" then Core.ShowSpecPicker(Core.rows[1], true) end
end

local function RowPart(key)
  if key == "specPicker" then
    return Core.specPicker:IsVisible() and Core.specPicker or Core.rows[1]
  end
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
    for i, identity in ipairs({ { "Lunara", ns.Locale:Get("highground.coachtargeting.priest_healer.a30fe2"), "PRIEST" }, { "Vexa", ns.Locale:Get("highground.coachtargeting.rogue_your_target.c865b1"), "ROGUE" } }) do
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
    f.notice = Theme.Text(f, "bodyLarge", "textMuted"); f.notice:SetPoint("CENTER"); ns.Localization.Bind(f.notice, "highground.coachtargeting.enemy_nameplates_are_hidden_the_sniper_marker.391350")
    f.notice:SetJustifyH("CENTER"); f.notice:SetWordWrap(true)
  end)
end

local function Markers()
  return E.Page("targeting:markers", ns.Locale:Get("highground.coachtargeting.target_markers.c4b1df"), function(p)
    E.Text(p, "intro", ns.Locale:Get("highground.coachtargeting.lunara_is_suggested_vexa_is_your_current.48ae7f"))
    Scene(p)
    p.crosshair, p.healer = p.scene.scope, p.scene.healer
    p.crosshair.sampleOwner, p.healer.sampleOwner = p.scene, p.scene
    E.Toggle(p, "nameplates", ns.Locale:Get("highground.coachtargeting.show_sample_enemy_nameplates.7e4f83"))
    E.Toggle(p, "recommend", ns.Locale:Get("highground.coachtargeting.use_target_recommendations_in_the_sample.98610c"))
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
      self.result:SetText(d.recommend and ns.Locale:Get("highground.coachtargeting.suggested_lunara_your_target_vexa.ca3f9d") or ns.Locale:Get("highground.coachtargeting.recommendations_off_the_sniper_marker_follows_your.3d1a5e"))
    end
  end)
end

local function Setting(step, key, label)
  step.feature, step.settingLabel = key, label
  return step
end
local function Sound(step, category)
  step.sound = category
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
    Sound(Setting(ns.Localization.Define(MarkerStep("crosshair", ns.Locale:Get("highground.coachtargeting.the_sniper_marker_shows_the_suggestion.d28836"),
      ns.Locale:Get("highground.coachtargeting.it_points_to_lunara_your_selected_target.7e9f71"),
      Markers, "crosshair", ns.Locale:Get("highground.coachtargeting.try_hg_sniper_test_on_a_target.72718a")), { title = "highground.coachtargeting.the_sniper_marker_shows_the_suggestion.d28836", text = "highground.coachtargeting.it_points_to_lunara_your_selected_target.7e9f71", hint = "highground.coachtargeting.try_hg_sniper_test_on_a_target.72718a" }), "sniper", ns.Locale:Get("highground.coachtargeting.enable_sniper_marker_in_game.53767b")), "lockon"),
    Setting(ns.Localization.Define(MarkerStep("healer", ns.Locale:Get("highground.coachtargeting.this_cross_marks_a_healer.3e70f2"), ns.Locale:Get("highground.coachtargeting.the_red_cross_identifies_a_known_enemy.f8294e"), Markers, "healer"), { title = "highground.coachtargeting.this_cross_marks_a_healer.3e70f2", text = "highground.coachtargeting.the_red_cross_identifies_a_known_enemy.f8294e" }), "healerMarks", ns.Locale:Get("highground.coachtargeting.enable_healer_marks_in_game.8c2663")),
    Setting(ns.Localization.Define(MarkerStep("teamhealers", ns.Locale:Get("highground.coachtargeting.mark_your_team_s_healers.c6dd22"), ns.Locale:Get("highground.coachtargeting.when_the_game_doesn_t_name_a.3443fe"), Markers, "healer", ns.Locale:Get("highground.coachtargeting.hover_over_a_teammate_and_press_your.717813")), { title = "highground.coachtargeting.mark_your_team_s_healers.c6dd22", text = "highground.coachtargeting.when_the_game_doesn_t_name_a.3443fe", hint = "highground.coachtargeting.hover_over_a_teammate_and_press_your.717813" }), "healerMarks", ns.Locale:Get("highground.coachtargeting.enable_healer_marks_in_game.8c2663")),
    Setting(ns.Localization.Define(MarkerStep("nameplates", ns.Locale:Get("highground.coachtargeting.keep_enemy_nameplates_visible.183b52"), ns.Locale:Get("highground.coachtargeting.turn_sample_nameplates_off_then_on_in.61ded4"), Markers, "nameplates", ns.Locale:Get("highground.coachtargeting.in_game_battlegrounds_settings_nameplates_sets_their.9d5201")), { title = "highground.coachtargeting.keep_enemy_nameplates_visible.183b52", text = "highground.coachtargeting.turn_sample_nameplates_off_then_on_in.61ded4", hint = "highground.coachtargeting.in_game_battlegrounds_settings_nameplates_sets_their.9d5201" }), "sniper", ns.Locale:Get("highground.coachtargeting.enable_sniper_marker_in_game.53767b")),
    Setting(ns.Localization.Define(MarkerStep("recommend", ns.Locale:Get("highground.coachtargeting.try_following_your_own_target.acd537"), ns.Locale:Get("highground.coachtargeting.turn_sample_recommendations_off_the_sniper_marker.02c850"), Markers, "recommend"), { title = "highground.coachtargeting.try_following_your_own_target.acd537", text = "highground.coachtargeting.turn_sample_recommendations_off_the_sniper_marker.02c850" }), "killorder"),
  } end,
})

function C.EnemySteps()
  local steps = {
    Setting(ns.Localization.Define(RowStep("enemy", ns.Locale:Get("highground.coachtargeting.your_battleground_enemy_list.62d16e"), ns.Locale:Get("highground.coachtargeting.this_is_your_actual_enemy_panel_with.9e06eb"), nil, nil,
      ns.Locale:Get("highground.coachtargeting.sample_rows_do_not_change_your_target.7affdd")), { title = "highground.coachtargeting.your_battleground_enemy_list.62d16e", text = "highground.coachtargeting.this_is_your_actual_enemy_panel_with.9e06eb", hint = "highground.coachtargeting.sample_rows_do_not_change_your_target.7affdd" }), "killorder", ns.Locale:Get("highground.coachtargeting.enable_enemy_list_in_game.ba1d59")),
    ns.Localization.Define(RowStep("priority", ns.Locale:Get("highground.coachtargeting.read_the_recommendation_rank.0f34cd"), ns.Locale:Get("highground.coachtargeting.the_rank_suggests_who_to_attack_now.24df75"), nil, "rank",
      ns.Locale:Get("highground.coachtargeting.if_you_have_hidden_rank_numbers_in.6c1e0c")), { title = "highground.coachtargeting.read_the_recommendation_rank.0f34cd", text = "highground.coachtargeting.the_rank_suggests_who_to_attack_now.24df75", hint = "highground.coachtargeting.if_you_have_hidden_rank_numbers_in.6c1e0c" }),
    ns.Localization.Define(RowStep("protection", ns.Locale:Get("highground.coachtargeting.def_means_defense_active.f657f0"), ns.Locale:Get("highground.coachtargeting.lunara_has_an_observed_defensive_ability_running.cef387"), ns.Locale:Get("highground.coachtargeting.def.6dae29"), "pipText",
      ns.Locale:Get("highground.coachtargeting.status_labels_follow_your_battlegrounds_appearance_setting.ca7153")), { title = "highground.coachtargeting.def_means_defense_active.f657f0", text = "highground.coachtargeting.lunara_has_an_observed_defensive_ability_running.cef387", hint = "highground.coachtargeting.status_labels_follow_your_battlegrounds_appearance_setting.ca7153" }),
    Sound(ns.Localization.Define(RowStep("opening", ns.Locale:Get("highground.coachtargeting.the_defense_has_ended.eab6dc"), ns.Locale:Get("highground.coachtargeting.lunara_s_defensive_ability_has_ended_spent.297484"), ns.Locale:Get("highground.coachtargeting.spent.c9d21d"), "pipText",
      ns.Locale:Get("highground.coachtargeting.spent_lasts_briefly_replay_shows_the_defense.870b3f")), { title = "highground.coachtargeting.the_defense_has_ended.eab6dc", text = "highground.coachtargeting.lunara_s_defensive_ability_has_ended_spent.297484", hint = "highground.coachtargeting.spent_lasts_briefly_replay_shows_the_defense.870b3f" }), "go"),
    ns.Localization.Define(RowStep("immunity", ns.Locale:Get("highground.coachtargeting.immune_means_damage_is_blocked.f27940"), ns.Locale:Get("highground.coachtargeting.an_observed_immunity_prevents_damage_the_recommendation.2686ec"), ns.Locale:Get("highground.coachtargeting.immune.4c42ca"), "pipText"), { title = "highground.coachtargeting.immune_means_damage_is_blocked.f27940", text = "highground.coachtargeting.an_observed_immunity_prevents_damage_the_recommendation.2686ec" }),
    ns.Localization.Define(RowStep("control", ns.Locale:Get("highground.coachtargeting.cc_marks_breakable_crowd_control.5e7301"), ns.Locale:Get("highground.coachtargeting.attacking_this_enemy_may_break_the_effect.270e22"), ns.Locale:Get("highground.coachtargeting.cc.c5a976"), "pipText"), { title = "highground.coachtargeting.cc_marks_breakable_crowd_control.5e7301", text = "highground.coachtargeting.attacking_this_enemy_may_break_the_effect.270e22" }),
    ns.Localization.Define(RowStep("unknown", ns.Locale:Get("highground.coachtargeting.unknown_distance_stays_unknown.01e741"), ns.Locale:Get("highground.coachtargeting.the_distance_means_there_is_no_reliable.630799"), "unknown", "dist"), { title = "highground.coachtargeting.unknown_distance_stays_unknown.01e741", text = "highground.coachtargeting.the_distance_means_there_is_no_reliable.630799" }),
    ns.Localization.Define(RowStep("lastseen", ns.Locale:Get("highground.coachtargeting.muted_health_is_the_last_reading.7d5664"), ns.Locale:Get("highground.coachtargeting.lunara_left_your_view_so_her_bar.bbf3e8"), "seen", "hp"), { title = "highground.coachtargeting.muted_health_is_the_last_reading.7d5664", text = "highground.coachtargeting.lunara_left_your_view_so_her_bar.bbf3e8" }),
    ns.Localization.Define(RowStep("spectag", ns.Locale:Get("highground.coachtargeting.spectag.title"), ns.Locale:Get("highground.coachtargeting.spectag.text"), "spectag", "specPicker",
      ns.Locale:Get("highground.coachtargeting.spectag.hint")), { title = "highground.coachtargeting.spectag.title", text = "highground.coachtargeting.spectag.text", hint = "highground.coachtargeting.spectag.hint" }),
  }
  for _, step in ipairs(E.Start("markers")) do steps[#steps + 1] = step end
  return steps
end
