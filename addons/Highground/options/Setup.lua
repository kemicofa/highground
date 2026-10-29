local _, ns = ...
local Core, P, Kit, Theme = ns.Core, ns.Options.Profiles, ns.Kit, ns.Theme
local Setup = {}
ns.Setup = Setup
Setup.presets = {
  minimal = { label = "Minimal", hint = "Objectives and flag carriers, with only critical alerts.",
    killorder = false, sniper = false, healerMarks = false, burstMarks = false, pressure = false, nearby = false, bounty = false, alert = "critical" },
  damage = { label = "Damage", hint = "Enemy priorities, healer markers and opportunities to attack.", killorder = true, sniper = true, healerMarks = true, alert = "critical" },
  healer = { label = "Healer", hint = "Carriers, objectives and teammate pressure, with a quieter enemy display.",
    killorder = false, sniper = false, healerMarks = true, pressure = true, alert = "objectives" },
  carrier = { label = "Flag carrier", hint = "Carriers and objectives stay visible. Resurrection advice is disabled.",
    killorder = false, sniper = false, dieAlert = false, flags = true, alert = "objectives" },
  caller = { label = "Caller", hint = "Enemy priorities, shared map sightings and base status for coordinating the team.",
    killorder = true, sniper = true, intel = true, intelShare = true, objectiveOverview = true, alert = "objectives" },
}

function Setup.Apply(role, keepBackup)
  local preset = Setup.presets[role]
  if not preset then return false, "Unknown role." end
  if InCombatLockdown() then return false, "Apply the preset after combat." end
  if not keepBackup then P.SaveProfile("Before role preset") end
  local roleFeatures = { killorder = true, sniper = true, healerMarks = true, burstMarks = true,
    pressure = true, nearby = true, bounty = true, intel = true, intelShare = true, objectiveOverview = true,
    arena = true, timers = true, objectives = true, flags = true, dieAlert = true, sapCall = true, capAlert = true, compact = true }
  for _, def in ipairs(ns.OptionsConfig.features) do
    if roleFeatures[def.key] and ns.OptionAvailable(def) then
      local value = preset[def.key]
      if value == nil then value = def.key ~= "compact" end
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
    local w = Kit.Dialog("HighgroundSetup", { title = "CHOOSE YOUR ROLE", titleRole = "title", width = 640, height = 480 + P.CONTEXT_HEIGHT,
      sub = "Step 1 of 2", savedKey = "setup" })
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
    local ready = CreateFrame("Frame", nil, w); ready:SetAllPoints(); w.ready = ready
    w.summary = Theme.Text(ready, "heading", "success")
    w.summary:SetPoint("TOPLEFT", 24, -90); w.summary:SetPoint("TOPRIGHT", -24, -90); w.summary:SetJustifyH("LEFT")
    local saved = Theme.Text(ready, "bodyLarge", "text")
    saved:SetPoint("TOPLEFT", 24, -130); saved:SetPoint("TOPRIGHT", -24, -130)
    saved:SetHeight(152); saved:SetJustifyH("LEFT"); saved:SetJustifyV("TOP"); saved:SetWordWrap(true)
    saved:SetText("Your settings and positions are saved. Panels are locked.\nUse the cogwheel or Home to unlock and move them.\n\nA named profile is an optional copy you can save on Profiles.")
    w.status = Theme.Text(w, "body", "textMuted")
    w.status:SetPoint("BOTTOMLEFT", 24, 70); w.status:SetPoint("BOTTOMRIGHT", -24, 70)
    w.status:SetHeight(52); w.status:SetJustifyH("LEFT"); w.status:SetJustifyV("BOTTOM"); w.status:SetWordWrap(true)
    w.primary = Kit.Button(w, "", 230, 34, { tone = "accent", onClick = function()
      if Setup.stage == "ready" then
        if ns.Hub then ns.Hub.Release(w) end
        w:Hide(); Setup.stage, w.didApply = nil, nil
        return
      end
      local ok, problem = Setup.CanArrange()
      if not ok then return Message(w, problem, true) end
      ok, problem = Setup.Apply(w.chosen, w.didApply)
      if not ok then return Message(w, problem, true) end
      w.didApply = true
      Setup.BeginPlacement()
    end })
    w.primary:SetPoint("BOTTOMRIGHT", -24, 22)
    w.secondary = Kit.Button(w, "Use current settings", 220, 34, { onClick = function()
      if Setup.stage == "ready" then
        if ns.Hub then ns.Hub.Release(w) end
        w:Hide(); Setup.stage = nil; ns.Hub.Open("profiles")
        return
      end
      local ok, problem = Setup.BeginPlacement()
      if not ok then Message(w, problem, true) end
    end })
    w.secondary:SetPoint("BOTTOMLEFT", 24, 22)
    function w:Refresh()
      local done = Setup.stage == "ready"
      self.choose:SetShown(not done); self.ready:SetShown(done)
      self.chosen = self.chosen or Core.db.setupRole or "minimal"
      if not Setup.presets[self.chosen] then self.chosen = "minimal" end
      local preset = Setup.presets[self.chosen]
      self.role:SetValue(self.chosen, true); self.hint:SetText(preset.label .. "\n\n" .. preset.hint)
      self:SetTitle(done and "YOU'RE READY" or "CHOOSE YOUR ROLE")
      self:SetSub(done and "Saved automatically" or "Step 1 of 2")
      self.summary:SetText((Setup.presets[Core.db.setupRole] or { label = "Your" }).label .. " setup saved")
      self.primary:SetText(done and "Done" or ("Use " .. preset.label .. " setup"))
      self.secondary:SetText(done and "Open Profiles" or "Use current settings")
      Message(self, done and "Use Open Profiles below to name this setup, reuse it or set up automatic switching."
        or "Next, arrange your panels. Your current settings are backed up before a role is applied.")
    end
    w:HookScript("OnShow", function() w:Refresh() end)
    w:HookScript("OnHide", function()
      if Setup.stage == "ready" then Setup.stage = nil end
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
