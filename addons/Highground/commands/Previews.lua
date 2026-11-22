local _, ns = ...
local Core, Commands = ns.Core, ns.Commands
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
local GUIDE_HINT = "Finish the guide or panel placement before starting previews."
function P.CanStart()
  local allowed = ns.Setup.CanArrange()
  if not allowed or ns.Arena.duel then return false, "Start previews outside combat, battlegrounds, arenas and duels." end
  if InGuide() then return false, GUIDE_HINT end
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
  if count == 0 then return false, "No enabled addons have a preview. Enable an addon and reload first." end
  return true, "Addon previews on. /hg test or /hg test stop finishes them. Macros and Reputation have guides instead."
end

function Commands.test(arg, msg, say)
  if arg == "stop" then P.StopAll(); say("Addon previews off.")
  elseif arg ~= "" and arg ~= "all" then say("/hg test [all||stop] · /hg bg test for battleground panels")
  elseif P.AllActive() then P.StopAll(); say("Addon previews off.")
  else local _, message = P.StartAll(); say(message) end
end

function Commands.bg(arg, msg, say)
  if arg ~= "test" and arg ~= "test stop" then return say("/hg bg test [stop]: preview battleground panels") end
  if InGuide() then return say(GUIDE_HINT) end
  if arg == "test stop" or P.Active("bg test") then
    StopBattlegrounds(); return say("Battleground previews off.")
  end
  local allowed, problem = P.CanStart()
  if not allowed then return say(problem) end
  StartBattlegrounds()
  say("Battleground previews on: enemy list, timers, objectives and flag carriers use your settings. /hg bg test to stop.")
  say("Enemy rows borrow nearby nameplate names when available; other rows are samples. /hg sniper test previews the target marker.")
end

local function StopForPlay()
  if P.managed then P.StopAll() end
end
local function OnZone()
  local kind = select(2, IsInInstance())
  if kind == "pvp" or kind == "arena" then StopForPlay() end
end
ns.Util.Events({
  PLAYER_REGEN_DISABLED = StopForPlay,
  PLAYER_ENTERING_WORLD = OnZone,
  ZONE_CHANGED_NEW_AREA = OnZone,
  DUEL_REQUESTED = StopForPlay,
  DUEL_TO_THE_DEATH_REQUESTED = StopForPlay,
  PLAYER_LOGOUT = StopForPlay,
  PLAYER_REGEN_ENABLED = function()
    if P.hiddenMain then P.hiddenMain = nil; Core.ApplyKillOrder(); Core.frame:SetAlpha(1) end
  end,
}, "addon previews")
