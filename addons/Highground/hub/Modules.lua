local _, ns = ...
local M, Hub, Kit, Theme = ns.Modules, ns.Hub, ns.Kit, ns.Theme
local pages = {}

local actions = {
  battlegrounds = { { "general", "Panels and features", "Battleground" }, { "behavior", "Targeting" },
    { "calls", "Team callouts" }, { "history", "Match history" } },
  arena = { { "general", "Arena and duel settings", "Arena" }, { "history", "Match history" } },
  nearby = { { "nearby", "Nearby settings" }, { "journal", "Enemy journal" } },
  bounties = { { "bountyboard", "Open bounty board" }, { "bounty", "Bounty settings" } },
  reputation = { { "reputation", "Open reputation" } },
  macros = { { "macros", "Open macros" }, { "general", "Macro settings", "Spells and macros" } },
}

local function Status(def)
  if not M.Installed(def.key) then return "Install the full Highground bundle and restart WoW to use this switch." end
  local selected = M.Selected(def.key)
  if M.Pending(def.key) then return selected and "Off now · enables after reload" or "On now · disables after reload" end
  return M.Active(def.key) and "Enabled for this character" or "Disabled for this character"
end

function Hub.BuildModules(key)
  local id = key or "all"
  if pages[id] then return pages[id] end
  local p = CreateFrame("Frame", nil, Hub.content)
  p:SetAllPoints(); p:Hide(); pages[id] = p
  p.header = Kit.Header(p, { title = key and M.byKey[key].name:upper() or "ADDONS", padding = 20 })
  p.header:SetPoint("TOPLEFT"); p.header:SetPoint("TOPRIGHT")
  p.guide = Kit.Button(p, "How addons work", 170, 28, { onClick = function() ns.Onboarding.Start("addons") end })
  p.header:SetActions({ p.guide })
  p.hint = Theme.Text(p, "body", "textMuted")
  p.hint:SetPoint("TOPLEFT", 20, -64); p.hint:SetPoint("TOPRIGHT", -20, -64)
  p.hint:SetHeight(54); p.hint:SetJustifyH("LEFT"); p.hint:SetWordWrap(true)
  p.hint:SetText("Choose which addons run for this character, just like WoW’s AddOn List. Changes apply after reload. Your settings and records are kept.")
  local scroll = Kit.ScrollArea(p)
  scroll:SetPoint("TOPLEFT", 0, -126); scroll:SetPoint("BOTTOMRIGHT", -12, 66)
  p.rows, p.actions = {}, {}
  local y = 0
  for _, def in ipairs(M.list) do
    if not key or def.key == key then
      local row = Kit.Toggle(scroll.body, def.name, { desc = def.description, onChange = function(_, enabled)
        local ok, problem = M.SetEnabled(def.key, enabled)
        p.problem = not ok and problem or nil
        p.Refresh()
      end })
      row:SetPoint("TOPLEFT", 20, -y); row:SetPoint("RIGHT", -20, 0)
      row.label:SetWordWrap(true); row.desc:SetWordWrap(true)
      row.status = Theme.Text(scroll.body, "body", "textMuted")
      row.status:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, -4); row.status:SetPoint("RIGHT", -20, 0)
      row.status:SetWordWrap(true); row.status:SetJustifyH("LEFT")
      row.module = def
      p.rows[#p.rows + 1] = row
      y = y + 120
    end
  end
  if key then
    for _, action in ipairs(actions[key]) do
      local button = Kit.Button(scroll.body, action[2], 290, 34, { onClick = function()
        Hub.Show(action[1])
        if action[3] then ns.Options.general.SelectGroup(action[3]) end
      end })
      button:SetPoint("TOPLEFT", 20, -y)
      p.actions[#p.actions + 1] = button
      y = y + 46
    end
  end
  p.status = Theme.Text(p, "body", "textMuted")
  p.status:SetPoint("BOTTOMLEFT", 20, 18); p.status:SetPoint("RIGHT", -202, 0)
  p.status:SetHeight(40); p.status:SetJustifyH("LEFT"); p.status:SetWordWrap(true)
  p.reload = Kit.Button(p, "Reload to apply", 172, 34, { tone = "accent", onClick = function()
    local ok, problem = M.Reload()
    p.problem = not ok and problem or nil
    p.Refresh()
  end })
  p.reload:SetPoint("BOTTOMRIGHT", -20, 20)
  function p.Refresh()
    if p.refreshing then return end
    p.refreshing = true
    scroll:Refresh()
    local offset = 0
    local combat = InCombatLockdown()
    for _, row in ipairs(p.rows) do
      local def = row.module
      row:SetChecked(M.Selected(def.key) == true, true)
      row:SetEnabled(M.Installed(def.key) and not combat)
      row.status:SetText(Status(def))
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", 20, -offset)
      row:SetPoint("TOPRIGHT", -20, -offset)
      local height = math.max(40, row.label:GetStringHeight() + row.desc:GetStringHeight() + 10)
      row:SetHeight(height)
      local statusHeight = math.max(16, row.status:GetStringHeight())
      row.status:SetHeight(statusHeight)
      offset = offset + height + statusHeight + 12
    end
    for _, button in ipairs(p.actions) do
      button:SetPoint("TOPLEFT", 20, -offset)
      button:SetEnabled(M.Active(key))
      offset = offset + 46
    end
    scroll.body:SetHeight(offset); scroll:Refresh()
    local pending = M.Pending()
    p.reload:SetShown(pending); p.reload:SetEnabled(not combat)
    p.status:SetText(p.problem or (combat and "Change addons after combat."
      or pending and "Reload when you’re ready to apply these changes." or "No addon changes pending."))
    p.refreshing = nil
  end
  p:SetScript("OnShow", p.Refresh)
  p:HookScript("OnSizeChanged", p.Refresh)
  ns.Core.OnFontScaleChange(function() if p:IsVisible() then p.Refresh() end end)
  return p
end

-- Refresh only visible controls on relevant events, never on a timer.
ns.Util.Events({ PLAYER_REGEN_ENABLED = function()
  for _, p in pairs(pages) do if p:IsVisible() then p.Refresh() end end
end, PLAYER_REGEN_DISABLED = function()
  for _, p in pairs(pages) do if p:IsVisible() then p.Refresh() end end
end }, "addon controls")

Hub.ModuleRoutes = {
  bountyboard = "bounties", bounty = "bounties", reputation = "reputation", macros = "macros",
  nearby = "nearby", journal = "nearby", calls = "battlegrounds", timers = "battlegrounds",
  behavior = "battlegrounds", priority = "battlegrounds", objectives = "battlegrounds",
  live = "battlegrounds", cooldowns = "battlegrounds", tracking = "battlegrounds",
  burst = "battlegrounds", specs = "battlegrounds", multipliers = "battlegrounds",
}
