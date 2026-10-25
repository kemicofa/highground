local _, ns = ...
local Core = ns.Core

-- Public accessors for the subsystems loaded after core (map, timers,
-- flags, arena, world, focus).
ns.enemies = Core.enemies
ns.specInfo = Core.specInfo
ns.CanonUnit = Core.CanonUnit
ns.GetDB = function()
  return Core.db
end
ns.GetPositions = function()
  return Core.pos
end
ns.IsActive = function()
  return Core.active and not Core.testMode
end
ns.GetKillNow = function()
  return Core.PriorityOn() and Core.killNow or nil
end
ns.GetAllyFaction = function()
  return Core.allyFaction
end
ns.FlagStacks = Core.FlagStacks
ns.GetBG = function()
  return Core.currentBG
end
ns.P = Core.P

-- Resolved rules are immutable configuration for the current client and mode.
ns.GetBGRules = function()
  return Core.currentBG and Core.currentBG.rules
end
