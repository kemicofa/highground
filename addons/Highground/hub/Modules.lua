local _, ns = ...
local M, Hub, Kit, Theme = ns.Modules, ns.Hub, ns.Kit, ns.Theme
local pages = {}

local actions = {
  battlegrounds = { { "behavior", "Targeting" }, { "history", tool = true } },
  arena = { { "history", tool = true } },
  nearby = { { "journal", tool = true } },
  bounties = { { "bountyboard", tool = true } },
  reputation = { { "reputation", tool = true } },
  macros = { { "macros", tool = true } },
}
for _, module in ipairs(M.list) do
  local pages, links = ns.Options.addonPages[module.key], actions[module.key]
  table.insert(links, 1, { pages.settings, "Settings" })
  if pages.appearance then table.insert(links, 2, { pages.appearance, "Appearance" }) end
  links[#links + 1] = { pages.previews, "Previews and guide" }
end

local function Status(def)
  if not M.Installed(def.key) then return "Install the full Highground bundle and restart WoW to use this switch." end
  local selected = M.Selected(def.key)
  if M.Pending(def.key) then return selected and "Off now · enables after reload" or "On now · disables after reload" end
  return M.Active(def.key) and "Enabled for this character" or "Disabled for this character"
end

function Hub.AddonNotice(parent)
  local notice
  local extras = M.StandaloneAddons()
  if #extras > 0 then
    local names = {}
    for _, def in ipairs(extras) do names[#names + 1] = "Highground " .. def.name .. " (" .. def.standalone .. ")" end
    notice = Kit.Card(parent, 100, { titleRole = "cardTitle", strip = "warning" })
    notice:SetPoint("TOPLEFT", 20, 0); notice:SetPoint("TOPRIGHT", -20, 0)
    notice:EnableMouse(false)
    notice.title:SetText("Recommended: remove extra standalone addons")
    notice.title:SetPoint("RIGHT", -16, 0); notice.title:SetWordWrap(true)
    notice.text = Theme.Text(notice, "body", "text")
    notice.text:SetPoint("TOPLEFT", notice.title, "BOTTOMLEFT", 0, -8)
    notice.text:SetPoint("RIGHT", -16, 0); notice.text:SetJustifyH("LEFT"); notice.text:SetWordWrap(true)
    notice.text:SetText("Highground already includes these. Remove only these separate downloads:\n"
      .. table.concat(names, ", ") .. ".\n\n1. Close WoW.\n2. Uninstall the listed standalone downloads in your addon manager, or delete only their listed folders.\n3. Reinstall Highground, then restart WoW."
      .. "\n\nKEEP Highground, all HighgroundModule folders, HighgroundBountyData and HighgroundReputationData. Keep both data addons enabled or Highground cannot load.")
  end
  return notice
end

function Hub.BuildModules(key)
  local id = key
  if pages[id] then return pages[id] end
  local p = CreateFrame("Frame", nil, Hub.content)
  p:SetAllPoints(); p:Hide(); pages[id] = p
  p.header = Kit.Header(p, { title = M.byKey[key].name:upper(), padding = 20 })
  p.header:SetPoint("TOPLEFT"); p.header:SetPoint("TOPRIGHT")
  p.guide = Kit.Button(p, "How addons work", 170, 28, { onClick = function() ns.Onboarding.Start("addons") end })
  p.header:SetActions({ p.guide })
  p.hint = Theme.Text(p, "body", "textMuted")
  p.hint:SetPoint("TOPLEFT", 20, -64); p.hint:SetPoint("TOPRIGHT", -20, -64)
  p.hint:SetHeight(54); p.hint:SetJustifyH("LEFT"); p.hint:SetWordWrap(true)
  p.hint:SetText("Highground includes all six features. No standalone downloads are needed. Keep the bundled module folders and both required data addons. Use these switches to turn features off, then reload.")
  local scroll = Kit.ScrollArea(p)
  p.scroll = scroll
  scroll:SetPoint("TOPLEFT", 0, -126); scroll:SetPoint("BOTTOMRIGHT", -12, 66)
  p.notice = Hub.AddonNotice(scroll.body)
  p.rows, p.actions = {}, {}
  local y = 0
  for _, def in ipairs(M.list) do
    if def.key == key then
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
  for _, action in ipairs(actions[key]) do
    local button = Kit.Button(scroll.body, action.tool and ns.Options.ToolLabel(action[1]) or action[2], 290, 34, { onClick = function()
      if action.tool then ns.Options.OpenTool(action[1]) else Hub.Show(action[1]) end
    end })
    button.tool = action.tool and action[1]
    if button.tool then ns.Options.BindToolLabel(button, button.tool) end
    button:SetPoint("TOPLEFT", 20, -y)
    p.actions[#p.actions + 1] = button
    y = y + 46
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
    p.hint:SetHeight(math.max(54, p.hint:GetStringHeight()))
    scroll:SetPoint("TOPLEFT", 0, -64 - p.hint:GetHeight() - 12)
    scroll:Refresh()
    local offset = 0
    if p.notice then
      local titleHeight, textHeight = p.notice.title:GetStringHeight(), p.notice.text:GetStringHeight()
      p.notice.title:SetHeight(titleHeight); p.notice.text:SetHeight(textHeight)
      p.notice:SetHeight(titleHeight + textHeight + 40)
      offset = p.notice:GetHeight() + 16
    end
    p.switchOffset = offset
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
      button:SetEnabled(M.Active(key) and (not button.tool or ns.Options.ToolAvailable(button.tool)))
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
  nearby = "nearby", journal = "nearby", timers = "battlegrounds",
  behavior = "battlegrounds", priority = "battlegrounds", objectives = "battlegrounds",
  live = "battlegrounds", cooldowns = "battlegrounds", tracking = "battlegrounds",
  burst = "battlegrounds", specs = "battlegrounds", multipliers = "battlegrounds",
}
