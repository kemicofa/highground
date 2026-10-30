local _, ns = ...
local Core, P, Kit, Theme = ns.Core, ns.Options.Profiles, ns.Kit, ns.Theme
local Setup = {}
ns.Setup = Setup
Setup.presets = {
  minimal = { label = "Minimal", hint = "Keep battleground panels focused on objectives and flag carriers.",
    killorder = false, healerMarks = false, alert = "critical" },
  damage = { label = "Damage", hint = "Suggested enemies to attack, healer markers and objective timers.", killorder = true, healerMarks = true, alert = "essential" },
  healer = { label = "Healer", hint = "Carriers, objectives and teammate pressure, with a quieter enemy display.",
    killorder = false, sniper = false, healerMarks = true, pressure = true, alert = "objectives" },
  carrier = { label = "Flag carrier", hint = "Carriers and objectives stay visible. Resurrection advice is disabled.",
    killorder = false, sniper = false, dieAlert = false, flags = true, alert = "objectives" },
  caller = { label = "Caller", hint = "Enemy priorities, a target marker and base status for coordinating the team.",
    killorder = true, sniper = true, objectiveOverview = true, alert = "objectives" },
}

function Setup.Apply(role, keepBackup)
  local preset = Setup.presets[role]
  if not preset then return false, "Unknown role." end
  if InCombatLockdown() then return false, "Apply the preset after combat." end
  if not keepBackup then P.SaveProfile("Before role preset") end
  -- A battleground playstyle does not change open-world tools, arena choices,
  -- layout, sharing or unrelated preferences.
  local roleDefaults = { killorder = true, sniper = false, healerMarks = false, burstMarks = false,
    pressure = false, objectiveOverview = false, timers = true, objectives = true, flags = true,
    dieAlert = false, sapCall = false, capAlert = true }
  for _, def in ipairs(ns.OptionsConfig.features) do
    if roleDefaults[def.key] ~= nil and ns.OptionAvailable(def) then
      local value = preset[def.key]
      if value == nil then value = roleDefaults[def.key] end
      Core.db[def.key] = value
    end
  end
  ns.Alerts.SetMode(preset.alert)
  Core.db.setupRole = role
  Core.ApplyStyle(); Core.CheckZone(); Core.ApplyKillOrder()
  if ns.MinimapButton then ns.MinimapButton.Apply() end
  ns.Options.RefreshFeatures()
  return true, preset.label .. " applied. Your previous setup is saved as ‘Before role preset’."
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
    local w = Kit.Dialog("HighgroundSetup", { title = "PLAYSTYLE PRESETS", titleRole = "title", width = 640, height = 480 + P.CONTEXT_HEIGHT,
      sub = "Optional · Your settings save automatically", savedKey = "setup" })
    Setup.win = w
    local choose = CreateFrame("Frame", nil, w); choose:SetAllPoints(); w.choose = choose
    local prompt = Theme.Text(choose, "heading", "text")
    prompt:SetPoint("TOPLEFT", 24, -84); prompt:SetText("What do you want to focus on?")
    local choices = {}
    for _, key in ipairs({ "minimal", "damage", "healer", "carrier", "caller" }) do
      choices[#choices + 1] = { key = key, label = Setup.presets[key].label }
    end
    w.role = Kit.Select(choose, { width = 220, menu = true, choices = choices, onPreview = function(_, key)
      w.hint:SetText(Setup.presets[key].label .. "\n\n" .. Setup.presets[key].hint)
    end, onChange = function(_, key)
      w.chosen = key; w:Refresh()
    end })
    w.role:SetPoint("TOPLEFT", 24, -128)
    w.hint = Theme.Text(choose, "bodyLarge", "text")
    w.hint:SetPoint("TOPLEFT", w.role, "TOPRIGHT", 24, 0); w.hint:SetPoint("TOPRIGHT", choose, "TOPRIGHT", -24, -128)
    w.hint:SetHeight(152); w.hint:SetJustifyH("LEFT"); w.hint:SetJustifyV("TOP"); w.hint:SetWordWrap(true)
    w.status = Theme.Text(w, "body", "textMuted")
    w.status:SetPoint("BOTTOMLEFT", 24, 70); w.status:SetPoint("BOTTOMRIGHT", -24, 70)
    w.status:SetHeight(52); w.status:SetJustifyH("LEFT"); w.status:SetJustifyV("BOTTOM"); w.status:SetWordWrap(true)
    w.primary = Kit.Button(w, "", 230, 34, { tone = "accent", onClick = function()
      local ok, problem = Setup.CanArrange()
      if not ok then return Message(w, problem, true) end
      ok, problem = Setup.Apply(w.chosen, w.didApply)
      if not ok then return Message(w, problem, true) end
      w.didApply = true
      Setup.BeginPlacement()
    end })
    w.primary:SetPoint("BOTTOMRIGHT", -24, 22)
    w.secondary = Kit.Button(w, "Use current settings", 220, 34, { onClick = function()
      local ok, problem = Setup.BeginPlacement()
      if not ok then Message(w, problem, true) end
    end })
    w.secondary:SetPoint("BOTTOMLEFT", 24, 22)
    function w:Refresh()
      self.chosen = self.chosen or Core.db.setupRole or "damage"
      if not Setup.presets[self.chosen] then self.chosen = "damage" end
      local preset = Setup.presets[self.chosen]
      self.role:SetValue(self.chosen, true); self.hint:SetText(preset.label .. "\n\n" .. preset.hint)
      self:SetTitle("PLAYSTYLE PRESETS")
      self:SetSub("Optional · Your settings save automatically")
      self.primary:SetText("Use " .. preset.label .. " setup")
      self.secondary:SetText("Move current panels")
      Message(self, "A preset changes battleground tools and alerts. Your current setup is backed up first.")
    end
    w:HookScript("OnShow", function() w:Refresh() end)
    w:HookScript("OnHide", function()
      if not Setup.transitioning then w.didApply = nil end
    end)
    P.AttachContext(w, { w.primary, w.secondary, w.status })
  end
  local w = Setup.win
  if Setup.placement then
    if not embedded then Setup.layoutBar:Show(); return w end
    Setup.EndPlacement(false)
  end
  w:Refresh()
  if not embedded then if ns.Hub then ns.Hub.Release(w) end; w:Show() end
  return w
end
