local _, ns = ...
local Core, Kit, Theme = ns.Core, ns.Kit, ns.Theme
local O = {}
ns.Onboarding = O
-- LoadSaved records first installation before filling defaults at
-- ADDON_LOADED, after the client has supplied the saved variables.
local steps = {
  { key = "panels", title = "Move panels or choose a playstyle", hint = "Try example panels before joining a match.", page = "setup" },
  { key = "features", title = "Choose what appears", hint = "Turn extra panels and markers on when you need them.", page = "general" },
  { key = "alerts", title = "Adjust alerts", hint = "Choose useful warnings, all alerts, or text without sound.", page = "alerts" },
  { key = "profile", title = "Keep a reusable setup", hint = "Optional saved copies for other characters or activities.", page = "profiles" },
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
      sub = "Quick guide · Everything here is optional", width = 660, height = 560, savedKey = "checklist",
      onClose = function() if not O.moving then O.Dismiss() end end })
    O.win = w
    w.hint = Theme.Text(w, "body", "textMuted")
    w.hint:SetPoint("TOPLEFT", 24, -80); w.hint:SetPoint("RIGHT", -24, 0)
    w.hint:SetHeight(56); w.hint:SetJustifyH("LEFT"); w.hint:SetWordWrap(true)
    w.hint:SetText("Join a battleground and your panels appear automatically. Click an enemy's name to target them, then use your abilities as usual. Settings save as you change them.")
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
    w.primary = Kit.Button(w, "Back to game", 220, 34, { tone = "accent", onClick = O.Dismiss })
    w.primary:SetPoint("BOTTOMRIGHT", -24, 24)
    function w:Refresh()
      for i, row in ipairs(self.rows) do
        local complete = O.Done(row.key)
        row.number:Set(complete and "DONE" or "+", complete and "success" or "textMuted")
        row.open:SetText(complete and "Review" or "Open")
      end
      self.progress:SetText("You do not need to complete these options to play.")
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

ns.Util.Events({
  PLAYER_LOGIN = function()
    -- No modal and no deferred surprise when combat ends. Old unfinished
    -- checklists remain available explicitly, with their progress intact.
    local state = O.State()
    state.pending = nil
    if Core.firstInstall and not state.offered then
      state.offered = true
      ns.Util.Say("Ready to play. Panels appear in battlegrounds. Open /hg for help or to move them.")
    end
  end,
}, "first login help")
ns.Commands.checklist = function() O.Open() end
