local _, ns = ...
local Core, Util = ns.Core, ns.Util

---------------------------------------------------------------------------
-- /hga and the settings page (start-up: libs/standalone/Main.lua). The
-- panel itself is src/arena/Window.lua; it shows in arenas and duels.
---------------------------------------------------------------------------
local function Status()
  Util.Say("Arena & duels: " .. (Core.On("arena") and "on" or "off") .. " · /hga on | off | test")
end

local function Preview()
  local on = ns.ArenaPreview()
  if on == nil then return Util.Say("Leave combat first.") end
  Util.Say(on and "Preview on. Drag to move; /hga test to hide." or "Preview off.")
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
    "/hga history: match history",
    "/hga: panel status",
    "/hga on, /hga off: enable or disable",
    "/hga test: preview and move",
  },
  commands = {
    history = function() ns.MatchHistory.Open() end,
    on = function() Switch(true) end,
    off = function() Switch(false) end,
    test = Preview,
  },
  default = Status,
  settings = {
    hint = "Opens for arenas and duel challenges. Left-click target; right-click focus.",
    keys = { "arena" },
    buttons = { { "Preview", Preview }, { "Match history", function() ns.MatchHistory.Open() end, advanced = true } },
  },
})
