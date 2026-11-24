local _, ns = ...
local Core, P, Kit, Theme = ns.Core, ns.Options.Profiles, ns.Kit, ns.Theme
local Setup = {}
ns.Setup = Setup
Setup.presets = {
  minimal = ns.Localization.Define({ label = ns.Locale:Get("highground.setup.minimal.a711cc"), hint = ns.Locale:Get("highground.setup.keep_battleground_panels_focused_on_objectives_and.07100e"),
    killorder = false, healerMarks = false, alert = "critical" }, { label = "highground.setup.minimal.a711cc", hint = "highground.setup.keep_battleground_panels_focused_on_objectives_and.07100e" }),
  damage = ns.Localization.Define({ label = ns.Locale:Get("highground.setup.damage.7bf6d1"), hint = ns.Locale:Get("highground.setup.suggested_enemies_to_attack_a_target_crosshair.becacd"),
    killorder = true, sniper = true, healerMarks = true, alert = "everything" }, { label = "highground.setup.damage.7bf6d1", hint = "highground.setup.suggested_enemies_to_attack_a_target_crosshair.becacd" }),
  healer = ns.Localization.Define({ label = ns.Locale:Get("highground.setup.healer.6cad85"), hint = ns.Locale:Get("highground.setup.carriers_objectives_and_teammate_pressure_with_a.180005"),
    killorder = false, sniper = false, healerMarks = true, pressure = true, alert = "objectives" }, { label = "highground.setup.healer.6cad85", hint = "highground.setup.carriers_objectives_and_teammate_pressure_with_a.180005" }),
  carrier = ns.Localization.Define({ label = ns.Locale:Get("highground.setup.flag_carrier.9e4a71"), hint = ns.Locale:Get("highground.setup.carriers_and_objectives_stay_visible_resurrection_advice.b9a035"),
    killorder = false, sniper = false, dieAlert = false, flags = true, alert = "objectives" }, { label = "highground.setup.flag_carrier.9e4a71", hint = "highground.setup.carriers_and_objectives_stay_visible_resurrection_advice.b9a035" }),
  caller = ns.Localization.Define({ label = ns.Locale:Get("highground.setup.caller.3fda6d"), hint = ns.Locale:Get("highground.setup.enemy_priorities_a_target_marker_and_base.90ad75"),
    killorder = true, sniper = true, objectiveOverview = true, alert = "objectives" }, { label = "highground.setup.caller.3fda6d", hint = "highground.setup.enemy_priorities_a_target_marker_and_base.90ad75" }),
}

local markers = {
  ns.Localization.Define({ key = "sniper", label = ns.Locale:Get("highground.appearance.sniper_marker.2ac0d6"), desc = ns.Locale:Get("highground.setup.battleground_marker_on_the_suggested_enemy_or.e907e6") }, { label = "highground.appearance.sniper_marker.2ac0d6", desc = "highground.setup.battleground_marker_on_the_suggested_enemy_or.e907e6" }),
  ns.Localization.Define({ key = "healerMarks", label = ns.Locale:Get("highground.setup.healer_markers.eec5f2"), desc = ns.Locale:Get("highground.setup.green_for_friendly_healers_red_for_enemy.aff9a5") }, { label = "highground.setup.healer_markers.eec5f2", desc = "highground.setup.green_for_friendly_healers_red_for_enemy.aff9a5" }),
}

local roleDefaults = { killorder = true, sniper = false, healerMarks = false, burstMarks = false,
  pressure = false, objectiveOverview = false, timers = true, objectives = true, forecast = true, flags = true,
  dieAlert = false, sapCall = false, capAlert = true }

local function RoleValue(preset, key, choices)
  local value = preset[key]
  if value == nil then value = roleDefaults[key] end
  if choices and (key == "sniper" or key == "healerMarks") and type(choices[key]) == "boolean" then value = choices[key] end
  return value
end

-- Build a candidate without touching the current setup or starting placement.
function Setup.ProfileSnapshot(role)
  local preset = Setup.presets[role]
  if not preset then return nil, ns.Locale:Get("highground.setup.unknown_playstyle_preset.c73b09") end
  local snap = P.Snapshot()
  for key in pairs(roleDefaults) do
    if snap.setup.features[key] ~= nil then snap.setup.features[key] = RoleValue(preset, key) end
  end
  ns.Alerts.ApplyPreset(snap.setup.alerts, preset.alert)
  return snap
end

function Setup.Apply(role, keepBackup, choices)
  local preset = Setup.presets[role]
  if not preset then return false, ns.Locale:Get("highground.setup.unknown_role.2e02d6") end
  if InCombatLockdown() then return false, ns.Locale:Get("highground.setup.apply_the_preset_after_combat.e171a2") end
  P.EnsureDefault()
  -- A battleground playstyle does not change open-world tools, arena choices,
  -- layout, sharing or unrelated preferences.
  for _, def in ipairs(ns.OptionsConfig.features) do
    if roleDefaults[def.key] ~= nil and ns.OptionAvailable(def) then
      Core.db[def.key] = RoleValue(preset, def.key, choices)
    end
  end
  ns.Alerts.SetMode(preset.alert)
  Core.db.setupRole = role
  Core.ApplyStyle(); Core.CheckZone(); Core.ApplyKillOrder()
  if ns.MinimapButton then ns.MinimapButton.Apply() end
  ns.Options.RefreshFeatures()
  return true, ns.Locale:Format("profiles.preset.applied", { preset = preset.label })
end

local function Message(w, text, failed)
  w.status:SetText(text or "")
  Theme.Paint(w.status, failed and "danger" or "textMuted")
end

function Setup.ShowStage(stage, inHub)
  Setup.stage = stage
  local w = Setup.Open(true)
  w:Refresh()
  if inHub and ns.Hub then ns.Hub.Open("setup")
  else if ns.Hub then ns.Hub.Release(w) end; w:Show() end
end

function Setup.Open(embedded)
  if not Setup.win then
    local w = ns.Localization.BindWidget(Kit.Dialog("HighgroundSetup", { title = ns.Locale:Get("highground.setup.playstyle_presets.a5e5cb"), titleRole = "title", width = 640, height = 560 + P.CONTEXT_HEIGHT,
      sub = ns.Locale:Get("highground.setup.choose_then_apply.48dedd"), savedKey = "setup" }), { title = "highground.setup.playstyle_presets.a5e5cb", sub = "highground.setup.choose_then_apply.48dedd" })
    Setup.win = w
    local choose = CreateFrame("Frame", nil, w); choose:SetAllPoints(); w.choose = choose
    local prompt = Theme.Text(choose, "heading", "text")
    prompt:SetPoint("TOPLEFT", 24, -84); ns.Localization.Bind(prompt, "highground.setup.what_do_you_want_to_focus_on.d67376")
    local choices = {}
    for _, key in ipairs({ "minimal", "damage", "healer", "carrier", "caller" }) do
      choices[#choices + 1] = { key = key, label = Setup.presets[key].label }
    end
    w.role = Kit.Select(choose, { width = 220, menu = true, choices = choices, onPreview = function(_, key)
      w.hint:SetText(Setup.presets[key].label .. "\n\n" .. Setup.presets[key].hint)
    end, onChange = function(_, key)
      w.chosen, w.markerChoices = key, nil; w:Refresh()
    end })
    w.role:SetPoint("TOPLEFT", 24, -128)
    w.hint = Theme.Text(choose, "bodyLarge", "text")
    w.hint:SetPoint("TOPLEFT", w.role, "TOPRIGHT", 24, 0); w.hint:SetPoint("TOPRIGHT", choose, "TOPRIGHT", -24, -128)
    w.hint:SetHeight(152); w.hint:SetJustifyH("LEFT"); w.hint:SetJustifyV("TOP"); w.hint:SetWordWrap(true)
    for i, def in ipairs(markers) do
      local toggle = ns.Localization.BindWidget(Kit.Toggle(choose, def.label, { desc = def.desc, onChange = function(_, on)
        w.markerChoices[def.key] = on
      end }), { label = ns.Localization.Key(def, "label"), desc = ns.Localization.Key(def, "desc") })
      toggle:SetPoint(i == 1 and "TOPLEFT" or "TOPRIGHT", i == 1 and 24 or -24, -304)
      toggle:SetHeight(96)
      toggle.label:SetWordWrap(true); toggle.desc:SetWordWrap(true)
      w[def.key] = toggle
    end
    local function MarkerWidths()
      for _, def in ipairs(markers) do w[def.key]:SetWidth((w:GetWidth() - 72) / 2) end
    end
    w:HookScript("OnSizeChanged", MarkerWidths)
    MarkerWidths()
    w.status = Theme.Text(w, "body", "textMuted")
    w.status:SetPoint("BOTTOMLEFT", 24, 70); w.status:SetPoint("BOTTOMRIGHT", -24, 70)
    w.status:SetHeight(52); w.status:SetJustifyH("LEFT"); w.status:SetJustifyV("BOTTOM"); w.status:SetWordWrap(true)
    w.primary = Kit.Button(w, "", 230, 34, { tone = "accent", onClick = function()
      local ok, problem = Setup.CanArrange()
      if not ok then return Message(w, problem, true) end
      ok, problem = Setup.Apply(w.chosen, w.didApply, w.markerChoices)
      if not ok then return Message(w, problem, true) end
      w.didApply = true
      Setup.BeginPlacement()
    end })
    w.primary:SetPoint("BOTTOMRIGHT", -24, 22)
    w.secondary = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("highground.setup.use_current_settings.f728f2"), 220, 34, { onClick = function()
      local ok, problem = Setup.BeginPlacement()
      if not ok then Message(w, problem, true) end
    end }), "highground.setup.use_current_settings.f728f2")
    w.secondary:SetPoint("BOTTOMLEFT", 24, 22)
    function w:Refresh()
      self.chosen = self.chosen or Core.db.setupRole or "damage"
      if not Setup.presets[self.chosen] then self.chosen = "damage" end
      local preset = Setup.presets[self.chosen]
      if not self.markerChoices then
        self.markerChoices = {}
        for _, def in ipairs(markers) do self.markerChoices[def.key] = preset[def.key] == true end
      end
      for _, def in ipairs(markers) do self[def.key]:SetChecked(self.markerChoices[def.key], true) end
      self.role:SetValue(self.chosen, true); self.hint:SetText(preset.label .. "\n\n" .. preset.hint)
      self:SetTitle(ns.Locale:Get("highground.setup.playstyle_presets.a5e5cb"))
      self:SetSub(ns.Locale:Get("highground.setup.choose_then_apply.48dedd"))
      self.primary:SetText(ns.Locale:Format("highground.setup.use_preset_label_setup.7ed80e", { preset_label = preset.label }))
      ns.Localization.Bind(self.secondary, "highground.setup.move_current_panels.953145")
      Message(self, ns.Locale:Get("profiles.preset.hint"))
    end
    w:HookScript("OnShow", function() w:Refresh() end)
    w:HookScript("OnHide", function()
      if not Setup.transitioning then w.didApply, w.markerChoices = nil, nil end
    end)
    P.AttachContext(w, { w.primary, w.secondary, w.status })
  end
  local w = Setup.win
  if Setup.placement then
    if not embedded then Setup.layoutBar:Show(); return w end
    Setup.EndPlacement(false)
  end
  if not w.didApply then w.markerChoices = nil end
  w:Refresh()
  if not embedded then if ns.Hub then ns.Hub.Release(w) end; w:Show() end
  return w
end
