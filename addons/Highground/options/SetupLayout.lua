local _, ns = ...
local S, Core, Kit, Theme = ns.Setup, ns.Core, ns.Kit, ns.Theme

function S.CanArrange()
  local kind = select(2, IsInInstance())
  if InCombatLockdown() or kind == "pvp" or kind == "arena" then
    return false, ns.Locale:Get("highground.setuplayout.arrange_panels_outside_a_match_and_combat.4edd21")
  end
  return true
end

local function StopPreviews()
  Core.StopTest()
  ns.Timers.previewing = nil
  if ns.QuickCalls then ns.QuickCalls.Update() end
  ns.Timers.HideWindows()
  ns.Timers.SecureHide(ns.Flags.flagWin)
  ns.Arena.preview = false; ns.Arena.Update()
  ns.Nearby.preview = false; ns.Nearby.Update()
  if not Core.active then
    if InCombatLockdown() and Core.frame:IsShown() then S.hiddenPreview = true end
    ns.Timers.SecureHide(Core.frame)
  end
end

local function Contexts()
  local choices = {}
  if Core.On("killorder") or Core.On("timers") or Core.On("flags") or Core.On("quickCalls") then
    choices[#choices + 1] = { key = "bg", label = ns.Locale:Get("highground.setuplayout.battleground_panels.57e3c7") }
  end
  if Core.On("arena") then
    choices[#choices + 1] = { key = "arena", label = ns.Games[ns.GAME].arenaSize and ns.Locale:Get("highground.toursteps.arena_duels.53e5be") or ns.Locale:Get("highground.setuplayout.duel_panel.95349d") }
  end
  if Core.On("nearby") then choices[#choices + 1] = { key = "world", label = ns.Locale:Get("highground.profilesummary.nearby_enemies.85f5df") } end
  return choices
end

function S.PreviewContext(context, enemies)
  if not S.placement or not S.CanArrange() then return end
  StopPreviews()
  S.placement.context = context
  if context == "bg" then
    if Core.On("killorder") then Core.StartTest(S.guided) end
    ns.BattlegroundsPreview.Start()
  elseif context == "enemies" then Core.StartTest(S.guided, enemies)
  elseif context == "objectives" then ns.BattlegroundsPreview.Start(true)
  elseif context == "arena" then ns.ArenaPreview()
  elseif context == "world" then ns.NearbyPreview() end
end

local function BuildBar()
  if S.layoutBar then return S.layoutBar end
  local w = ns.Localization.BindWidget(Kit.Dialog("HighgroundSetupPlacement", { title = ns.Locale:Get("highground.setuplayout.place_your_panels.4330ba"), titleRole = "title",
    sub = ns.Locale:Get("highground.setuplayout.example_data_drag_headers_to_move.e7c352"), width = 540, height = 206 + ns.Options.Profiles.CONTEXT_HEIGHT, savedKey = "setupPlacement",
    point = { "BOTTOMLEFT", "BOTTOMLEFT", 24, 40 }, onClose = function()
      local state = S.placement
      if not state or S.guided then return end
      S.EndPlacement(false)
      if state.hub and not Kit.Windows.switching then ns.Hub.Open() end
    end }), { title = "highground.setuplayout.place_your_panels.4330ba", sub = "highground.setuplayout.example_data_drag_headers_to_move.e7c352" })
  S.layoutBar = w
  w.hint = Theme.Text(w, "body", "text")
  w.hint:SetPoint("TOPLEFT", 20, -74); w.hint:SetPoint("RIGHT", -20, 0)
  w.hint:SetHeight(48); w.hint:SetJustifyH("LEFT"); w.hint:SetJustifyV("TOP"); w.hint:SetWordWrap(true)
  ns.Localization.Bind(w.hint, "highground.setuplayout.drag_panel_headers_to_move_them_choose.56ea69")
  w.context = Kit.Select(w, { width = 236, menu = true, choices = {}, onChange = function(_, key) S.PreviewContext(key) end })
  w.context:SetPoint("TOPLEFT", 20, -132)
  w.finish = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("highground.coach.done.e9b450"), 200, 34, { tone = "accent", onClick = function()
    local state = S.placement
    if not state then return end
    S.EndPlacement(true)
    if ns.Onboarding and ns.Onboarding.active == "panels" then return ns.Onboarding.Reviewed("panels") end
    -- Closing the examples is the end of placement, with no extra setup
    -- completion screen or request to save a named profile.
    S.stage = nil
    if state.hub then ns.Hub.Open() end
  end }), "highground.coach.done.e9b450")
  w.finish:SetPoint("BOTTOMRIGHT", -20, 16)
  w.back = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("highground.coachview.back.b52b36"), 80, 26, { onClick = function()
    local state = S.placement
    if not state then return end
    S.EndPlacement(false, true)
    -- Back leaves placement for the Highground page that started it.
    if state.hub and not state.inHub then return ns.Hub.Open() end
    S.ShowStage("role", state.inHub)
  end }), "highground.coachview.back.b52b36")
  w.back:SetPoint("BOTTOMLEFT", 20, 16)
  ns.Options.Profiles.AttachContext(w, { w.finish, w.back })
  return w
end

function S.BeginPlacement(guided)
  local allowed, problem = S.CanArrange()
  if not allowed then return false, problem end
  if S.placement then return true end
  if ns.PreviewTests and ns.PreviewTests.managed then ns.PreviewTests.StopAll() end
  local w, style = S.win, Core.StyleDB()
  local hub = ns.Hub and ns.Hub.win
  local state = { locked = Core.db.locked, style = style, frameless = style.frameless,
    inHub = hub and w and w:GetParent() == ns.Hub.content, hub = hub and hub:IsShown() }
  S.transitioning = true
  if ns.Hub then ns.Hub.Suspend(); ns.Hub.Release(w) end
  if w then w:Hide() end
  S.transitioning = nil
  S.placement, S.stage, S.guided = state, "place", guided == true
  Core.db.locked, style.frameless = false, false
  Core.ApplyStyle()
  local bar, choices = BuildBar(), Contexts()
  bar.context:SetChoices(choices)
  bar.context:SetShown(#choices > 1)
  local context = choices[1] and choices[1].key
  bar.context:SetValue(context, true)
  bar.hint:SetText(context and (#choices > 1
    and ns.Locale:Get("highground.setuplayout.these_panels_show_example_data_drag_their.73c66c")
    or ns.Locale:Get("highground.setuplayout.these_panels_show_example_data_drag_their.7326d1"))
    or ns.Locale:Get("highground.setuplayout.your_panels_are_switched_off_finish_setup.501a91"))
  S.PreviewContext(context)
  bar:SetShown(not S.guided)
  return true
end

function S.EndPlacement(done, keepBackup)
  local state = S.placement
  if not state then return end
  S.placement, S.stage, S.guided = nil, done and "ready" or "role", nil
  if S.win and not keepBackup then S.win.didApply = nil end
  Core.db.locked = done and true or state.locked
  if done then Core.db.setupDone = true end
  if Core.StyleDB() == state.style then state.style.frameless = state.frameless end
  StopPreviews()
  Core.ApplyStyle(); Core.ApplyKillOrder()
  S.layoutBar:Hide()
end

ns.Util.Events({
  PLAYER_REGEN_DISABLED = function() if S.placement then S.EndPlacement(false) end end,
  PLAYER_REGEN_ENABLED = function()
    if S.hiddenPreview then
      S.hiddenPreview = nil
      Core.ApplyKillOrder(); Core.frame:SetAlpha(1)
    end
  end,
  PLAYER_ENTERING_WORLD = function()
    local kind = select(2, IsInInstance())
    if S.placement and (kind == "pvp" or kind == "arena") then S.EndPlacement(false) end
  end,
  PLAYER_LOGOUT = function() if S.placement then S.EndPlacement(false) end end,
}, "setup placement")
