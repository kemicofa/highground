local _, ns = ...
local Core, Util = ns.Core, ns.Util

---------------------------------------------------------------------------
-- /hga and the settings page (start-up: libs/standalone/Main.lua). The
-- panel itself is src/arena/Window.lua; it shows in arenas and duels.
---------------------------------------------------------------------------
local function Status()
  Util.Say(ns.Locale:Format("arena.main.arena_duels_value2_hga_on_off_test.5eea21", { value2 = (Core.On("arena") and "on" or "off") }))
end

local function Preview()
  local on = ns.ArenaPreview()
  if on == nil then return Util.Say(ns.Locale:Get("arena.main.leave_combat_first.b4ffad")) end
  Util.Say(on and ns.Locale:Get("arena.main.preview_on_drag_to_move_hga_test.de0f72") or ns.Locale:Get("highground.display.preview_off.90af6a"))
end

local function Switch(on)
  Core.SetFeature("arena", on)
  Util.Guard("arena", ns.Arena.Update)
  Status()
end

ns.Standalone.Start({
  command = "HIGHGROUNDARENA",
  slash = { "/hga", "/hgarena" },
  help = ns.Localization.Define({
    ns.Locale:Get("arena.main.hga_history_match_history.204230"),
    ns.Locale:Get("arena.main.hga_panel_status.a55826"),
    ns.Locale:Get("arena.main.hga_on_hga_off_enable_or_disable.e3a21a"),
    ns.Locale:Get("arena.main.hga_test_preview_and_move.c39c75"),
  }, { [1] = "arena.main.hga_history_match_history.204230", [2] = "arena.main.hga_panel_status.a55826", [3] = "arena.main.hga_on_hga_off_enable_or_disable.e3a21a", [4] = "arena.main.hga_test_preview_and_move.c39c75" }),
  commands = {
    history = function() ns.MatchHistory.Open() end,
    on = function() Switch(true) end,
    off = function() Switch(false) end,
    test = Preview,
  },
  default = Status,
  settings = ns.Localization.Define({
    hint = ns.Locale:Get("arena.main.opens_for_arenas_and_duel_challenges_left.0d2aae"),
    keys = { "arena" },
    buttons = { { "Preview", Preview }, ns.Localization.Define({ ns.Locale:Get("highground.hub.match_history.b65b77"), function() ns.MatchHistory.Open() end, advanced = true }, { [1] = "highground.hub.match_history.b65b77" }) },
  }, { hint = "arena.main.opens_for_arenas_and_duel_challenges_left.0d2aae" }),
})
