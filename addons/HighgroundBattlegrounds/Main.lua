local _, ns = ...
local Core, Util, Preview = ns.Core, ns.Util, ns.BattlegroundsPreview

---------------------------------------------------------------------------
-- Highground Battlegrounds: Highground's battleground engine, timers, flag
-- carriers and map intel (src/), without the kill order. /hgbg and the
-- settings page (start-up: libs/standalone/Main.lua).
---------------------------------------------------------------------------

-- /hgbg off: stay idle in every battleground (HighgroundBattlegroundsDB.off).
-- Wraps the engine's check (core/Lifecycle.lua); CheckZone looks it up per call.
local inBattleground = Core.InRatedBG
function Core.InRatedBG()
  return not (Core.db and Core.db.off) and inBattleground()
end

local function SetOn(on)
  Core.db.off = not on or nil
  Core.CheckZone()
  Util.Say(ns.Locale:Format("battlegrounds.main.battleground_tools_value2.92eace", { value2 = (on and "on" or "OFF") }))
end

local function Status()
  if Core.db.off then return ns.Locale:Get("battlegrounds.main.off_hgbg_on_to_turn_on.8322b1") end
  local bg = ns.GetBG()
  if Core.active then return ns.Locale:Format("battlegrounds.main.on_in_value2.c45a8e", { value2 = (bg and bg.name or GetInstanceInfo() or ns.Locale:Get("battlegrounds.main.this_battleground.5b3163")) }) end
  return ns.Locale:Get("battlegrounds.main.on_waits_for_a_battleground_settings_choose.119a8a")
end

local function TogglePreview()
  local on, changed = Preview.Toggle()
  if not changed then
    Util.Say(ns.Locale:Get("battlegrounds.main.no_preview_changes_in_combat_or_in.d7d728"))
  else
    Util.Say(on and ns.Locale:Get("battlegrounds.main.preview_on_drag_the_windows_into_place.2532c1") or ns.Locale:Get("battlegrounds.main.preview_off.c18141"))
  end
end

ns.Standalone.Start({
  command = "HIGHGROUNDBATTLEGROUNDS",
  slash = { "/hgbg", "/hgbattlegrounds" },
  help = ns.Localization.Define(ns.Localization.Define({
    ns.Locale:Get("battlegrounds.main.hgbg_history_match_journal_and_objective_timelines.cfa60c"),
    ns.Locale:Get("battlegrounds.main.hgbg_status.8f8dce"),
    ns.Locale:Get("battlegrounds.main.hgbg_on_hgbg_off_turn_the_battleground.7cae7e"),
    ns.Locale:Get("battlegrounds.main.hgbg_test_preview_the_resurrection_objective_and.907da9"),
    ns.Locale:Get("battlegrounds.main.hgbg_reset_windows_back_to_their_default.cacc79"),
    ns.Locale:Get("battlegrounds.main.hgbg_timers_hgbg_intel_what_the_timers.287fc1"),
  }, { [2] = "battlegrounds.main.hgbg_status.8f8dce" }), { [1] = "battlegrounds.main.hgbg_history_match_journal_and_objective_timelines.cfa60c", [3] = "battlegrounds.main.hgbg_on_hgbg_off_turn_the_battleground.7cae7e", [4] = "battlegrounds.main.hgbg_test_preview_the_resurrection_objective_and.907da9", [5] = "battlegrounds.main.hgbg_reset_windows_back_to_their_default.cacc79", [6] = "battlegrounds.main.hgbg_timers_hgbg_intel_what_the_timers.287fc1" }),
  commands = {
    history = function() ns.MatchHistory.Open() end,
    on = function() SetOn(true) end,
    off = function() SetOn(false) end,
    test = TogglePreview,
    reset = function()
      ns.TimersWindowReset()
      Util.Say(ns.Locale:Get("battlegrounds.main.windows_reset.e24f55"))
    end,
    timers = function() Util.Say(ns.TimersStatus()) end,
    intel = function() Util.Say(ns.IntelStatus()) end,
  },
  default = function(cmd)
    if cmd == "" then return Util.Say(Status()) end
    Util.Say(ns.Locale:Get("battlegrounds.main.unknown_command_hgbg_help_lists_them.9c8c65"))
  end,
  settings = ns.Localization.Define({
    hint = ns.Locale:Get("battlegrounds.main.join_a_battleground_and_these_panels_appear.bba551"),
    basic = { "allBGs", "timers", "flags", "intel", "quickCalls", "quickCallsDestinations", "quickCallsRoutes" },
    keys = { "allBGs", "bg10", "bg15", "bg40", "timers", "quickCalls", "quickCallsDestinations", "quickCallsRoutes",
      "objectives", "objectiveOverview", "capAlert", "capPlates", "dieAlert",
      "dieHpPct", "dieResMax", "dieResMin", "flags", "hideCarrierFrames", "sapCall", "hideTracker",
      "intel", "intelShare", "sound" },
    buttons = {
      ns.Localization.Define({ ns.Locale:Get("battlegrounds.main.preview_windows.7d7470"), TogglePreview }, { [1] = "battlegrounds.main.preview_windows.7d7470" }),
      ns.Localization.Define({ ns.Locale:Get("battlegrounds.main.reset_positions.d2ed65"), function() ns.TimersWindowReset() end, advanced = true }, { [1] = "battlegrounds.main.reset_positions.d2ed65" }),
    },
  }, { hint = "battlegrounds.main.join_a_battleground_and_these_panels_appear.bba551" }),
})
