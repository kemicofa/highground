local _, ns = ...
local Core, Theme, Kit, Hub = ns.Core, ns.Theme, ns.Kit, ns.Hub
local shortcuts = {
  ns.Localization.Define({ "addons", "Addons", ns.Locale:Get("highground.home.visit_enable_or_learn_each_highground_addon.3072ef") }, { [3] = "highground.home.visit_enable_or_learn_each_highground_addon.3072ef" }),
  ns.Localization.Define({ "alerts", "Alerts", ns.Locale:Get("highground.home.choose_warnings_and_sounds.87357b") }, { [3] = "highground.home.choose_warnings_and_sounds.87357b" }),
}

function Hub.BuildHome(content)
  local h = CreateFrame("Frame", nil, content)
  h:SetAllPoints(); Hub.home = h
  h.card = Kit.Card(h, 144, { titleRole = "display", strip = "brand", featured = true })
  h.card:SetPoint("TOPLEFT"); h.card:SetPoint("RIGHT")
  h.card:EnableMouse(false)
  h.crest = Kit.Crest(h.card, 104)
  h.crest:SetPoint("LEFT", h.card, "LEFT", 16, 0)
  h.eyebrow = Theme.Text(h.card, "label", "accent")
  h.eyebrow:SetPoint("TOPLEFT", 140, -20)
  ns.Localization.Bind(h.eyebrow, "highground.home.field_status.7d2cb5")
  h.where = h.card.title
  h.where:ClearAllPoints(); h.where:SetPoint("TOPLEFT", 140, -42); h.where:SetPoint("RIGHT", -16, 0)
  h.where:SetWordWrap(false)
  h.state = Theme.Text(h.card, "body", "textMuted")
  h.state:SetPoint("TOPLEFT", 140, -86); h.state:SetPoint("RIGHT", -16, 0)
  h.state:SetHeight(44); h.state:SetJustifyH("LEFT"); h.state:SetWordWrap(true)

  h.guide = Kit.Card(h, 156, { titleRole = "cardTitle" })
  h.guide:SetPoint("TOPLEFT", 0, -164); h.guide:SetPoint("RIGHT")
  h.guide.title:ClearAllPoints(); h.guide.title:SetPoint("TOPLEFT", 16, -16)
  h.guide:EnableMouse(false)
  h.guideHint = Theme.Text(h.guide, "body", "textMuted")
  h.guideHint:SetPoint("TOPLEFT", 16, -46); h.guideHint:SetPoint("RIGHT", -16, 0)
  h.guideHint:SetHeight(40); h.guideHint:SetJustifyH("LEFT"); h.guideHint:SetWordWrap(true)
  h.start = ns.Localization.Bind(Kit.Button(h.guide, ns.Locale:Get("highground.home.back_to_game.ff6a1c"), 190, 32, { tone = "accent", onClick = function()
    Hub.win:Hide()
  end }), "highground.home.back_to_game.ff6a1c")
  h.start:SetPoint("BOTTOMLEFT", 16, 16)
  h.arrange = ns.Localization.Bind(Kit.Button(h.guide, ns.Locale:Get("highground.home.preview_and_move_panels.4d665c"), 270, 32, { onClick = function()
    ns.PanelControls.Arrange()
  end }), "highground.home.preview_and_move_panels.4d665c")
  h.arrange:SetPoint("BOTTOMRIGHT", -16, 16)
  Kit.Tooltip(h.arrange, function()
    local allowed, problem = ns.Setup.CanArrange()
    return { ns.Locale:Get("highground.home.arrange_panels.e82274"), allowed and ns.Locale:Get("highground.home.show_example_panels_and_drag_their_headers.f2b676") or problem }
  end)

  local title = ns.Localization.BindWidget(Kit.Section(h, ns.Locale:Get("highground.home.optional_changes.573fe4")), { [0] = "highground.home.optional_changes.573fe4" })
  title:SetPoint("TOPLEFT", 4, -340)
  h.shortcuts = {}
  for i, def in ipairs(shortcuts) do
    local key, y = def[1], -368 - math.floor((i - 1) / 2) * 82
    local b = Kit.Button(h, def[2], 330, 72, { onClick = function() Hub.Show(key) end })
    if i % 2 == 1 then
      b:SetPoint("TOPLEFT", h, "TOPLEFT", 0, y); b:SetPoint("TOPRIGHT", h, "TOP", -8, y)
    else
      b:SetPoint("TOPLEFT", h, "TOP", 8, y); b:SetPoint("TOPRIGHT", h, "TOPRIGHT", 0, y)
    end
    b.label:ClearAllPoints(); b.label:SetPoint("TOPLEFT", 16, -12)
    b.label:SetPoint("RIGHT", -16, 0); b.label:SetJustifyH("LEFT")
    b.hint = Theme.Text(b, "body", "textMuted")
    b.hint:SetPoint("TOPLEFT", 16, -40); b.hint:SetPoint("RIGHT", -16, 0)
    b.hint:SetJustifyH("LEFT"); b.hint:SetText(def[3])
    if key == "addons" and #ns.Modules.StandaloneAddons() > 0 then
      ns.Localization.Bind(b, "highground.home.extra_addons_found.2aebec")
      ns.Localization.Bind(b.hint, "highground.home.see_what_to_remove_and_keep.64f6e2")
    end
    b.key = key; h.shortcuts[i] = b
  end
  h.tools = ns.Localization.Bind(Kit.Button(h, ns.Locale:Get("highground.home.how_addons_work.de4bbc"), 240, 30, { tone = "accent", onClick = function() ns.Onboarding.Start("addons") end }), "highground.home.how_addons_work.de4bbc")
  h.tools:SetPoint("TOPLEFT", 0, -468)
  h.community = ns.Localization.Bind(Kit.Button(h, ns.Locale:Get("highground.community.join_discord.7ec699"), 220, 30, { onClick = ns.Community.Join }), "highground.community.join_discord.7ec699")
  h.community:SetPoint("LEFT", h.tools, "RIGHT", 12, 0)
  Kit.Tooltip(h.community, function() return { ns.Locale:Get("highground.home.highground_discord.d5280c"), ns.Locale:Get("highground.home.copy_the_invite_for_addon_help_discussions.4dfff5") } end)
  h.panelLock = Kit.Button(h, "", 190, 30, { onClick = function() ns.PanelControls.Toggle() end })
  h.panelLock:SetPoint("TOPRIGHT", 0, -468)
  Kit.Tooltip(h.panelLock, ns.PanelControls.Tooltip)
  h.help = Theme.Text(h, "body", "textMuted")
  h.help:SetPoint("TOPLEFT", 0, -518); h.help:SetPoint("RIGHT")
  h.help:SetHeight(48); h.help:SetJustifyH("LEFT"); h.help:SetJustifyV("TOP"); h.help:SetWordWrap(true)
  h:Hide()
end

function Hub.RefreshHome()
  local h = Hub.home
  if not h then return end
  local _, kind = IsInInstance()
  local bg = ns.GetBG and ns.GetBG()
  local active = ns.IsActive and ns.IsActive()
  if kind == "pvp" then
    h.where:SetText((bg and bg.name or ns.Locale:Get("highground.home.battleground.19d4bd")):upper())
    h.state:SetText(active and ns.Locale:Get("highground.home.click_an_enemy_s_name_to_target.72eb70")
      or ns.Locale:Get("highground.home.panels_are_off_for_this_match_open.1b052d"))
  elseif kind == "arena" then
    ns.Localization.Bind(h.where, "highground.home.arena.28ee94")
    h.state:SetText(Core.On("arena") and ns.Locale:Get("highground.home.left_click_an_opponent_to_target_right.552ba5")
      or ns.Locale:Get("highground.home.your_arena_panel_is_off_enable_it.473c2f"))
  elseif ns.Arena and ns.Arena.duel then
    ns.Localization.Bind(h.where, "highground.home.duel.c539e2")
    h.state:SetText(Core.On("arena") and ns.Locale:Get("highground.home.duel_panel_active_left_click_target_right.21b690")
      or ns.Locale:Get("highground.home.your_duel_panel_is_off_enable_it.08cfbb"))
  else
    ns.Localization.Bind(h.where, "highground.home.open_world.a4f95b")
    h.state:SetText(ns.Locale:Format("highground.home.panels_open_for_battlegrounds_arenas_and_duels.c2bf18", { value2 = (Core.On("nearby") and ns.Locale:Get("highground.home.on.6c6ccf") or ns.Locale:Get("highground.home.off_enable_it_in_nearby_settings.8cf48b")) }))
  end
  h.card:SetStrip("brand")
  ns.Localization.Bind(h.guide.title, "highground.home.you_re_ready_to_play.ead6eb")
  ns.Localization.Bind(h.guideHint, "highground.home.no_setup_is_required_join_a_match.b62a93")
  h.arrange:SetEnabled(not InCombatLockdown() and kind ~= "pvp" and kind ~= "arena")
  h.panelLock:SetText(ns.PanelControls.Action())
  h.help:SetText(ns.Locale:Format("highground.home.value1_value2_your_settings_and_positions_save.a83dac", { value1 = (ns.PanelControls.Locked() and ns.Locale:Get("highground.home.panels_locked.4a91c7") or ns.Locale:Get("highground.home.panels_unlocked.30cc9d")), value2 = ns.PanelControls.Hint() }))
end
