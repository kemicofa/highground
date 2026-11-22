local _, ns = ...
local M, Hub, Kit, Theme = ns.Modules, ns.Hub, ns.Kit, ns.Theme
local pages = {}

local actions = {
  battlegrounds = { ns.Localization.Define({ "behavior", ns.Locale:Get("highground.modules.targeting.c4ac40") }, { [2] = "highground.modules.targeting.c4ac40" }), ns.Localization.Define({ "history", ns.Locale:Get("highground.hub.match_history.b65b77") }, { [2] = "highground.hub.match_history.b65b77" }) },
  arena = { ns.Localization.Define({ "history", ns.Locale:Get("highground.hub.match_history.b65b77") }, { [2] = "highground.hub.match_history.b65b77" }) },
  nearby = { ns.Localization.Define({ "journal", ns.Locale:Get("highground.hub.enemy_journal.1dbc52") }, { [2] = "highground.hub.enemy_journal.1dbc52" }) },
  bounties = { ns.Localization.Define({ "bountyboard", ns.Locale:Get("highground.modules.open_bounty_board.69b5a7") }, { [2] = "highground.modules.open_bounty_board.69b5a7" }) },
  reputation = { ns.Localization.Define({ "reputation", ns.Locale:Get("highground.modules.open_reputation.bdc1fb") }, { [2] = "highground.modules.open_reputation.bdc1fb" }) },
  macros = { ns.Localization.Define({ "macros", ns.Locale:Get("highground.modules.open_macros.56744c") }, { [2] = "highground.modules.open_macros.56744c" }) },
}
for _, module in ipairs(M.list) do
  local pages, links = ns.Options.addonPages[module.key], actions[module.key]
  table.insert(links, 1, ns.Localization.Define({ pages.settings, ns.Locale:Get("highground.hub.settings.c7f73b") }, { [2] = "highground.hub.settings.c7f73b" }))
  if pages.appearance then table.insert(links, 2, ns.Localization.Define({ pages.appearance, ns.Locale:Get("highground.hub.appearance.41def7") }, { [2] = "highground.hub.appearance.41def7" })) end
  links[#links + 1] = ns.Localization.Define({ pages.previews, ns.Locale:Get("highground.hub.previews_and_guide.e53405") }, { [2] = "highground.hub.previews_and_guide.e53405" })
end

local function Status(def)
  if not M.Installed(def.key) then return ns.Locale:Get("highground.modules.install_the_full_highground_bundle_and_restart.1a3d75") end
  local selected = M.Selected(def.key)
  if M.Pending(def.key) then return selected and ns.Locale:Get("highground.modules.off_now_enables_after_reload.e91b79") or ns.Locale:Get("highground.modules.on_now_disables_after_reload.fcfe7b") end
  return M.Active(def.key) and ns.Locale:Get("highground.modules.enabled_for_this_character.7bdd27") or ns.Locale:Get("highground.modules.disabled_for_this_character.f001b0")
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
    ns.Localization.Bind(notice.title, "highground.modules.recommended_remove_extra_standalone_addons.787e18")
    notice.title:SetPoint("RIGHT", -16, 0); notice.title:SetWordWrap(true)
    notice.text = Theme.Text(notice, "body", "text")
    notice.text:SetPoint("TOPLEFT", notice.title, "BOTTOMLEFT", 0, -8)
    notice.text:SetPoint("RIGHT", -16, 0); notice.text:SetJustifyH("LEFT"); notice.text:SetWordWrap(true)
    notice.text:SetText(ns.Locale:Format("highground.modules.highground_already_includes_these_remove_only_these.b1a936", { value2 = table.concat(names, ", ") }))
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
  p.guide = ns.Localization.Bind(Kit.Button(p, ns.Locale:Get("highground.home.how_addons_work.de4bbc"), 170, 28, { onClick = function() ns.Onboarding.Start("addons") end }), "highground.home.how_addons_work.de4bbc")
  p.header:SetActions({ p.guide })
  p.hint = Theme.Text(p, "body", "textMuted")
  p.hint:SetPoint("TOPLEFT", 20, -64); p.hint:SetPoint("TOPRIGHT", -20, -64)
  p.hint:SetHeight(54); p.hint:SetJustifyH("LEFT"); p.hint:SetWordWrap(true)
  ns.Localization.Bind(p.hint, "highground.modules.highground_includes_all_six_features_no_standalone.3bf9dc")
  local scroll = Kit.ScrollArea(p)
  p.scroll = scroll
  scroll:SetPoint("TOPLEFT", 0, -126); scroll:SetPoint("BOTTOMRIGHT", -12, 66)
  p.notice = Hub.AddonNotice(scroll.body)
  p.rows, p.actions = {}, {}
  local y = 0
  for _, def in ipairs(M.list) do
    if def.key == key then
      local row = ns.Localization.BindWidget(Kit.Toggle(scroll.body, def.name, { desc = def.description, onChange = function(_, enabled)
        local ok, problem = M.SetEnabled(def.key, enabled)
        p.problem = not ok and problem or nil
        p.Refresh()
      end }), { label = ns.Localization.Key(def, "name") })
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
    local button = Kit.Button(scroll.body, action[2], 290, 34, { onClick = function()
      Hub.Show(action[1])
    end })
    button:SetPoint("TOPLEFT", 20, -y)
    p.actions[#p.actions + 1] = button
    y = y + 46
  end
  p.status = Theme.Text(p, "body", "textMuted")
  p.status:SetPoint("BOTTOMLEFT", 20, 18); p.status:SetPoint("RIGHT", -202, 0)
  p.status:SetHeight(40); p.status:SetJustifyH("LEFT"); p.status:SetWordWrap(true)
  p.reload = ns.Localization.Bind(Kit.Button(p, ns.Locale:Get("highground.modules.reload_to_apply.1f4e74"), 172, 34, { tone = "accent", onClick = function()
    local ok, problem = M.Reload()
    p.problem = not ok and problem or nil
    p.Refresh()
  end }), "highground.modules.reload_to_apply.1f4e74")
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
      button:SetEnabled(M.Active(key))
      offset = offset + 46
    end
    scroll.body:SetHeight(offset); scroll:Refresh()
    local pending = M.Pending()
    p.reload:SetShown(pending); p.reload:SetEnabled(not combat)
    p.status:SetText(p.problem or (combat and ns.Locale:Get("highground.modules.change_addons_after_combat.77ccf7")
      or pending and ns.Locale:Get("highground.modules.reload_when_you_re_ready_to_apply.ae9dfa") or ns.Locale:Get("highground.modules.no_addon_changes_pending.184cb9")))
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
