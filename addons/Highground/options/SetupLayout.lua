local _, ns = ...
local S, Core, Kit, Theme = ns.Setup, ns.Core, ns.Kit, ns.Theme

function S.CanArrange()
  local kind = select(2, IsInInstance())
  if InCombatLockdown() or kind == "pvp" or kind == "arena" then
    return false, "Arrange panels outside a match and combat. You can keep playing and return to setup later."
  end
  return true
end

local function StopPreviews()
  Core.StopTest()
  ns.Timers.previewing = nil
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
  if Core.On("killorder") or Core.On("timers") or Core.On("flags") then
    choices[#choices + 1] = { key = "bg", label = "Battleground panels" }
  end
  if Core.On("arena") then choices[#choices + 1] = { key = "arena", label = "Arena panel" } end
  if Core.On("nearby") then choices[#choices + 1] = { key = "world", label = "Nearby enemies" } end
  return choices
end

function S.PreviewContext(context)
  if not S.placement or not S.CanArrange() then return end
  StopPreviews()
  S.placement.context = context
  if context == "bg" then
    if Core.On("killorder") then Core.StartTest() end
    ns.BattlegroundsPreview.Start()
  elseif context == "arena" then ns.ArenaPreview()
  elseif context == "world" then ns.NearbyPreview() end
end

local function BuildBar()
  if S.layoutBar then return S.layoutBar end
  local w = Kit.Dialog("HighgroundSetupPlacement", { title = "PLACE YOUR PANELS", titleRole = "title",
    sub = "Example data · Drag headers to move", width = 540, height = 206 + ns.Options.Profiles.CONTEXT_HEIGHT, savedKey = "setupPlacement",
    point = { "BOTTOMLEFT", "BOTTOMLEFT", 24, 40 }, onClose = function()
      if S.placement then S.EndPlacement(false) end
    end })
  S.layoutBar = w
  w.hint = Theme.Text(w, "body", "text")
  w.hint:SetPoint("TOPLEFT", 20, -74); w.hint:SetPoint("RIGHT", -20, 0)
  w.hint:SetHeight(48); w.hint:SetJustifyH("LEFT"); w.hint:SetJustifyV("TOP"); w.hint:SetWordWrap(true)
  w.hint:SetText("Drag panel headers to move them. Choose another set below to arrange those panels too.")
  w.context = Kit.Select(w, { width = 236, menu = true, choices = {}, onChange = function(_, key) S.PreviewContext(key) end })
  w.context:SetPoint("TOPLEFT", 20, -132)
  w.finish = Kit.Button(w, "Done", 200, 34, { tone = "accent", onClick = function()
    local state = S.placement
    if not state then return end
    S.EndPlacement(true)
    if ns.Onboarding and ns.Onboarding.active == "panels" then return ns.Onboarding.Return() end
    -- Closing the examples is the end of placement, with no extra setup
    -- completion screen or request to save a named profile.
    S.stage = nil
  end })
  w.finish:SetPoint("BOTTOMRIGHT", -20, 16)
  w.back = Kit.Button(w, "Back", 80, 26, { onClick = function()
    local state = S.placement
    if not state then return end
    S.EndPlacement(false, true)
    S.ShowStage("role", state.inHub)
  end })
  w.back:SetPoint("BOTTOMLEFT", 20, 16)
  ns.Options.Profiles.AttachContext(w, { w.finish, w.back })
  return w
end

function S.BeginPlacement()
  local allowed, problem = S.CanArrange()
  if not allowed then return false, problem end
  if S.placement then return true end
  local w, style = S.win, Core.StyleDB()
  local state = { locked = Core.db.locked, style = style, frameless = style.frameless,
    inHub = ns.Hub and w and w:GetParent() == ns.Hub.content }
  S.transitioning = true
  if ns.Hub then ns.Hub.Release(w); if ns.Hub.win then ns.Hub.win:Hide() end end
  if w then w:Hide() end
  S.transitioning = nil
  S.placement, S.stage = state, "place"
  Core.db.locked, style.frameless = false, false
  Core.ApplyStyle()
  local bar, choices = BuildBar(), Contexts()
  bar.context:SetChoices(choices)
  bar.context:SetShown(#choices > 1)
  local context = choices[1] and choices[1].key
  bar.context:SetValue(context, true)
  bar.hint:SetText(context and (#choices > 1
    and "These panels show example data. Drag their headers to move them, then choose another set below."
    or "These panels show example data. Drag their headers to move them, then finish setup.")
    or "Your panels are switched off. Finish setup to keep those settings; you can enable panels later in Features.")
  S.PreviewContext(context)
  bar:Show()
  return true
end

function S.EndPlacement(done, keepBackup)
  local state = S.placement
  if not state then return end
  S.placement, S.stage = nil, done and "ready" or "role"
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
