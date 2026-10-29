local _, ns = ...
local Core, Kit, Theme = ns.Core, ns.Kit, ns.Theme
local O = {}
ns.Onboarding = O
-- LoadSaved records first installation before filling defaults at
-- ADDON_LOADED, after the client has supplied the saved variables.
local steps = {
  { key = "panels", title = "Choose a role and place panels", hint = "Start with a preset or keep your own settings.", page = "setup" },
  { key = "features", title = "Choose what you want to see", hint = "Review your feature switches. Keeping the defaults is fine.", page = "general" },
  { key = "alerts", title = "Choose your alerts", hint = "Decide how much text and sound you want.", page = "alerts" },
  { key = "profile", title = "Save a named profile", hint = "Optional. Reuse your setup on other characters or activities.", page = "profiles" },
}
O.steps = steps

function O.State()
  if type(Core.db.onboarding) ~= "table" then Core.db.onboarding = {} end
  local state = Core.db.onboarding
  if type(state.steps) ~= "table" then state.steps = {} end
  return state
end

function O.Done(key)
  if key == "panels" then return Core.db.setupDone == true end
  if key == "profile" then
    for name in pairs(Core.db.profiles or {}) do if name ~= "Before role preset" then return true end end
    return false
  end
  local state = Core.db.onboarding
  return type(state) == "table" and type(state.steps) == "table" and state.steps[key] == true or false
end

function O.Mark(key)
  O.State().steps[key] = true
  if O.win then O.win:Refresh() end
end

local function Hide(release)
  O.moving = true
  if release then ns.Hub.Release(O.win) end
  if O.win then O.win:Hide() end
  O.moving = nil
end

function O.Dismiss()
  local state = O.State()
  state.dismissed, state.pending, O.active = true, nil, nil
  Hide(true)
end

function O.Return()
  if ns.Hub.win then ns.Hub.win:Hide() end
  if ns.Setup.win then ns.Setup.win:Hide() end
  if ns.Alerts.win then ns.Alerts.win:Hide() end
  O.active = nil
  O.Open()
end

function O.Reviewed(key)
  O.Mark(key)
  if O.active == key then O.Return() end
end

function O.Start(key)
  for _, step in ipairs(steps) do
    if step.key == key then
      O.active = key
      O.State().dismissed = nil
      Hide(true)
      ns.Hub.Open(step.page)
      if key == "profile" and ns.Options.panel.profileName:GetText() == "" then
        local preset = ns.Setup.presets[Core.db.setupRole]
        ns.Options.panel.profileName:SetText((preset and preset.label or "My") .. " setup")
      end
      return
    end
  end
end

function O.Open(embedded)
  if not O.win then
    local w = Kit.Dialog("HighgroundChecklist", { title = "HIGHGROUND", titleRole = "title",
      sub = "Your setup checklist", width = 660, height = 560, savedKey = "checklist",
      onClose = function() if not O.moving then O.Dismiss() end end })
    O.win = w
    w.hint = Theme.Text(w, "body", "textMuted")
    w.hint:SetPoint("TOPLEFT", 24, -80); w.hint:SetPoint("RIGHT", -24, 0)
    w.hint:SetHeight(56); w.hint:SetJustifyH("LEFT"); w.hint:SetWordWrap(true)
    w.hint:SetText("Make Highground work for you in three steps. Your settings save automatically. You can dismiss this checklist and reopen it from Home.")
    w.rows = {}
    for i, step in ipairs(steps) do
      local row = CreateFrame("Frame", nil, w)
      row:SetPoint("TOPLEFT", 24, -154 - (i - 1) * 78); row:SetPoint("RIGHT", -24, 0); row:SetHeight(74)
      row.number = Kit.Chip(row, tostring(i), "textMuted", 58)
      row.number:SetPoint("TOPLEFT", 0, -2)
      row.title = Theme.Text(row, "heading", "text")
      row.title:SetPoint("TOPLEFT", 72, 0); row.title:SetPoint("RIGHT", -108, 0)
      row.title:SetJustifyH("LEFT"); row.title:SetWordWrap(true)
      row.title:SetText(step.title)
      row.hint = Theme.Text(row, "body", "textMuted")
      row.hint:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -6); row.hint:SetPoint("RIGHT", -108, 0)
      row.hint:SetJustifyH("LEFT"); row.hint:SetWordWrap(true); row.hint:SetText(step.hint)
      row.open = Kit.Button(row, "Open", 96, 30, { onClick = function() O.Start(step.key) end })
      row.open:SetPoint("TOPRIGHT", 0, -8)
      row.key = step.key; w.rows[i] = row
    end
    w.progress = Theme.Text(w, "body", "textMuted")
    w.progress:SetPoint("BOTTOMLEFT", 24, 66); w.progress:SetPoint("RIGHT", -24, 0); w.progress:SetJustifyH("LEFT")
    w.dismiss = Kit.Button(w, "Dismiss checklist", 200, 34, { onClick = function()
      O.Dismiss()
    end })
    w.dismiss:SetPoint("BOTTOMLEFT", 24, 24)
    w.primary = Kit.Button(w, "Continue setup", 220, 34, { tone = "accent", onClick = function()
      for i = 1, 3 do if not O.Done(steps[i].key) then return O.Start(steps[i].key) end end
      local state = O.State()
      state.complete, state.pending, O.active = true, nil, nil
      Hide(true)
    end })
    w.primary:SetPoint("BOTTOMRIGHT", -24, 24)
    function w:Refresh()
      local done = 0
      for i, row in ipairs(self.rows) do
        local complete = O.Done(row.key)
        if complete and i <= 3 then done = done + 1 end
        row.number:Set(complete and "DONE" or (i <= 3 and tostring(i) or "+"), complete and "success" or "textMuted")
        row.open:SetText(complete and "Review" or (i == 4 and "Save" or "Start"))
      end
      self.progress:SetText(string.format("%d of 3 essentials complete · Named profiles are optional", done))
      self.primary:SetText(done == 3 and "Finish setup" or (done == 0 and "Start setup" or "Continue setup"))
    end
    w:HookScript("OnShow", function() w:Refresh() end)
  end
  local state = O.State()
  state.offered, state.pending = true, nil
  O.win:Refresh()
  if not embedded then
    if ns.Setup.placement then ns.Setup.EndPlacement(false) end
    ns.Hub.Release(O.win); O.win:Show()
  end
  return O.win
end

local function Offer()
  local state = Core.db and Core.db.onboarding
  if type(state) ~= "table" or not state.pending or state.dismissed or state.complete then return end
  local kind = select(2, IsInInstance())
  if InCombatLockdown() or kind == "pvp" or kind == "arena" then return end
  -- Someone already using the addon should keep the screen they opened.
  if (ns.Hub.win and ns.Hub.win:IsShown()) or (ns.Setup.win and ns.Setup.win:IsShown()) or ns.Setup.placement then
    state.pending, state.offered = nil, true
    return
  end
  O.Open()
end
ns.Util.Events({
  PLAYER_LOGIN = function()
    if Core.firstInstall and type(Core.db.onboarding) ~= "table" then O.State().pending = true end
    C_Timer.After(1, Offer)
  end,
  PLAYER_ENTERING_WORLD = function() C_Timer.After(1, Offer) end,
  PLAYER_REGEN_ENABLED = Offer,
}, "first login checklist")
ns.Commands.checklist = function() O.Open() end
