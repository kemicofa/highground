local _, ns = ...
local Core, Util = ns.Core, ns.Util

---------------------------------------------------------------------------
-- /hga and the settings page (shared start-up: standalone/Main.lua). The
-- panel itself is shared/arena/Window.lua; it shows in arenas only.
---------------------------------------------------------------------------
local function Status()
  Util.Say("arena enemy panel " .. (Core.On("arena") and "on" or "OFF")
    .. " (left-click target, right-click focus) | /hga on | off | test")
end

local function Preview()
  local on = ns.ArenaPreview()
  if on == nil then return Util.Say("not in combat") end
  Util.Say("arena panel preview " .. (on and "ON: drag it into place, /hga test again to hide" or "off"))
end

local function Switch(on)
  Core.SetFeature("arena", on)
  Util.Guard("arena", ns.Arena.Update)
  Status()
end

ns.Standalone.Start({
  command = "HIGHGROUNDARENA",
  slash = { "/hga", "/hgarena" },
  help = {
    "/hga: is the panel on",
    "/hga on, /hga off: show the panel in arenas, or not",
    "/hga test: place the panel outside an arena (again to hide)",
  },
  commands = {
    on = function() Switch(true) end,
    off = function() Switch(false) end,
    test = Preview,
  },
  default = Status,
  settings = {
    hint = "In an arena, one row per opponent: left-click targets, right-click focuses, also in combat. Each row shows the opponent's PvP trinket cooldown.",
    keys = { "arena" },
    buttons = { { "Preview the panel", Preview } },
  },
})
