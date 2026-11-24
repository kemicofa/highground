local _, ns = ...
local Core, Commands = ns.Core, ns.Commands
-- Command syntax shown as text: chat reads "|r" in "s|i|raid" as an escape.
local function Syntax(text) return (text:gsub("|", "||")) end
local P = {}
ns.PreviewTests = P

-- Share the catalog with the UI. Open-tool and one-shot actions are not
-- previews; each addon contributes its default sample, not every scene.
local active = {
  ["bg test"] = function() return Core.testMode or ns.Timers.previewing end,
  ["sniper test"] = function() return Core.sniperTest.on end,
  ["arena test"] = function() return ns.Arena.preview end,
  ["nearby test"] = function() return ns.Nearby.preview end,
  ["intel test"] = function() return ns.Intel.testPins end,
  ["burst test"] = function() return Core.burstTest end,
  ["pressure test"] = function() return ns.PressurePreviewActive() end,
  ["bounty test"] = function() return ns.Bounty.Preview.testing end,
}
function P.Active(command) return active[command] and not not active[command]() or false end

local function InGuide()
  return ns.Setup.placement or ns.Onboarding and ns.Onboarding.exploring and ns.Onboarding.exploring ~= "page"
end
local GUIDE_HINT = "highground.previews.finish_the_guide_or_panel_placement_before.533997"
function P.CanStart()
  local allowed = ns.Setup.CanArrange()
  if not allowed then return false, ns.Locale:Get("highground.previews.start_previews_outside_combat_battlegrounds_and_arenas.db0a71") end
  if InGuide() then return false, ns.Locale:Get(GUIDE_HINT) end
  return true
end

local function StopAppearance(module)
  local appearance = ns.Options.AppearancePreview
  if appearance and appearance.session and (not module or appearance.session.scene.module == module) then
    appearance.Stop()
  end
end

local function StopBattlegrounds()
  StopAppearance("battlegrounds")
  if not P.Active("bg test") then return end
  Core.StopTest()
  ns.Timers.previewing = nil
  ns.Timers.HideWindows()
  ns.Timers.SecureHide(ns.Flags.flagWin)
  if ns.QuickCalls then ns.QuickCalls.Update() end
  if not Core.active then
    if InCombatLockdown() and Core.frame:IsShown() then P.hiddenMain = true end
    ns.Timers.SecureHide(Core.frame)
  end
end

local function StartBattlegrounds()
  StopAppearance()
  if not Core.testMode then Core.StartTest() end
  if not ns.Timers.previewing then ns.BattlegroundsPreview.Start() end
  P.managed = true
end

local function Silent() end
local function SetPreview(command, on)
  if command == "bg test" then
    -- Also fill a partially started battleground preview.
    if on then StartBattlegrounds() else StopBattlegrounds() end
  elseif P.Active(command) ~= on then
    if not on and command == "arena test" then
      ns.Arena.preview = false; ns.Arena.Update()
    elseif not on and command == "nearby test" then
      ns.Nearby.preview = false; ns.Nearby.Update()
      if ns.WorldActivity then ns.WorldActivity.Preview(false) end
    elseif command == "bounty test" then
      ns.Bounty.Preview.Command(on and "poster" or "stop")
    else
      local verb, arg = command:match("^(%S+)%s+(.+)$")
      Commands[verb](arg, command, Silent)
    end
  end
end

function P.AnyActive()
  if InGuide() then return true end
  if ns.Options.AppearancePreview and ns.Options.AppearancePreview.session then return true end
  for _, def in ipairs(ns.CommandCatalog.previews) do
    if not def.kind and ns.OptionAvailable(def) and P.Active(def.cmd) then return true end
  end
  return false
end

function P.AllActive() return P.all == true and P.AnyActive() end

function P.StopAll()
  StopAppearance()
  if ns.Onboarding and ns.Onboarding.exploring then ns.Onboarding.StopExploring() end
  if ns.Setup.placement then ns.Setup.EndPlacement(false) end
  for _, def in ipairs(ns.CommandCatalog.previews) do
    if not def.kind and ns.OptionAvailable(def) and P.Active(def.cmd) then SetPreview(def.cmd, false) end
  end
  P.all, P.managed = nil, nil
  ns.Options.RefreshPreviews()
end

function P.StartAll()
  local allowed, problem = P.CanStart()
  if not allowed then return false, problem end
  StopAppearance()
  local count = 0
  for _, def in ipairs(ns.CommandCatalog.previews) do
    if not def.kind and ns.OptionAvailable(def) and ns.Modules.Active(def.module) then
      SetPreview(def.cmd, true)
      if P.Active(def.cmd) then count = count + 1 end
    end
  end
  P.all, P.managed = count > 0, count > 0
  if count == 0 then return false, ns.Locale:Get("highground.previews.no_enabled_addons_have_a_preview_enable.cc5858") end
  return true, ns.Locale:Get("highground.previews.addon_previews_on_hg_test_or_hg.b9132b")
end

function Commands.test(arg, msg, say)
  if arg == "stop" then P.StopAll(); say(ns.Locale:Get("highground.previews.addon_previews_off.e8dafb"))
  elseif arg ~= "" and arg ~= "all" then say(Syntax(ns.Locale:Get("shared.messages.hg_test_all_stop_hg_bg_test.477367")))
  elseif P.AllActive() then P.StopAll(); say(ns.Locale:Get("highground.previews.addon_previews_off.e8dafb"))
  else local _, message = P.StartAll(); say(message) end
end

function Commands.bg(arg, msg, say)
  -- /hg bg profiler start|stop: core/Profiler.lua.
  if arg == "profiler start" then return ns.Profiler.Start(say) end
  if arg == "profiler stop" then return ns.Profiler.Stop(say) end
  if arg ~= "test" and arg ~= "test stop" then return say(ns.Locale:Get("highground.previews.hg_bg_test_stop_preview_battleground_panels.837295")) end
  if InGuide() then return say(ns.Locale:Get(GUIDE_HINT)) end
  if arg == "test stop" or P.Active("bg test") then
    StopBattlegrounds(); return say(ns.Locale:Get("highground.previews.battleground_previews_off.fde282"))
  end
  local allowed, problem = P.CanStart()
  if not allowed then return say(problem) end
  StartBattlegrounds()
  say(ns.Locale:Get("highground.previews.battleground_previews_on_enemy_list_timers_objectives.370685"))
  say(ns.Locale:Get("highground.previews.enemy_rows_borrow_nearby_nameplate_names_when.91ff5c"))
end

local function StopForPlay()
  if P.managed then P.StopAll() end
end
-- Started on their own, these would still hide real burst markers and
-- steer the scope in the match.
local STANDALONE = { "sniper test", "burst test" }
local function OnZone()
  local kind = select(2, IsInInstance())
  if kind == "pvp" or kind == "arena" then
    StopForPlay()
    local stopped = false
    for _, command in ipairs(STANDALONE) do
      if P.Active(command) then SetPreview(command, false); stopped = true end
    end
    if stopped then ns.Options.RefreshPreviews() end
  end
end
ns.Util.Events({
  PLAYER_REGEN_DISABLED = StopForPlay,
  PLAYER_ENTERING_WORLD = OnZone,
  ZONE_CHANGED_NEW_AREA = OnZone,
  PLAYER_LOGOUT = StopForPlay,
  PLAYER_REGEN_ENABLED = function()
    if P.hiddenMain then P.hiddenMain = nil; Core.ApplyKillOrder(); Core.frame:SetAlpha(1) end
  end,
}, "addon previews")
