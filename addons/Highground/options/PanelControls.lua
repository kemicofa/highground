local _, ns = ...
local Core, Kit, Options = ns.Core, ns.Kit, ns.Options
local Panels = {}
ns.PanelControls = Panels

function Panels.Locked()
  return Core.db and Core.db.locked == true
end

function Panels.Action()
  return Panels.Locked() and "Unlock panels" or "Lock panels"
end

function Panels.Hint()
  if InCombatLockdown() then return "Panels can be moved after combat ends." end
  return Panels.Locked() and "Unlock panels to drag their headers."
    or "Drag panel headers to move. Lock panels when done."
end

function Panels.Tooltip()
  return { { Panels.Locked() and "Panels locked" or "Panels unlocked", "text" },
    { Panels.Hint(), "textMuted", true },
    { "Use the cogwheel or Home to lock or unlock panels.", "textMuted", true } }
end

-- Keep a visible drag handle in Frameless mode without changing the saved
-- appearance or resizing protected panels. Standalone addons keep their look.
function ns.ShowPanelHeaders()
  return Core.db and not Panels.Locked()
end

function Core.SetPanelsLocked(locked)
  if not Core.db then return end
  Core.db.locked = locked == true
  ns.ApplyOpacity()
  Panels.Refresh()
end

function Panels.Toggle()
  GameTooltip_Hide()
  Core.SetPanelsLocked(not Panels.Locked())
  ns.Util.Say((Panels.Locked() and "Panels locked. " or "Panels unlocked. ") .. Panels.Hint())
end

function Panels.MenuItem()
  return { text = Panels.Action(), run = Panels.Toggle }
end

function Panels.Arrange()
  local allowed, problem = ns.Setup.CanArrange()
  if not allowed then return ns.Util.Say(problem) end
  ns.Setup.Open(true)
  ns.Setup.BeginPlacement()
end

function Panels.ToggleMenu(anchor)
  local items = { Panels.MenuItem(),
    { text = "Arrange panels", run = Panels.Arrange },
    { text = "Highground settings", run = Options.Open },
  }
  if Kit.Dropdown.Open(anchor, items, function(item) item.run() end,
    { width = 220 * math.max(1, Core.FontScale()) }) then
    Kit.Dropdown.Select(0, true)
  end
end

Kit.Tooltip(Core.frame, Panels.Tooltip, { anchor = "ANCHOR_RIGHT" })

function Panels.Refresh()
  if ns.Hub and ns.Hub.RefreshHome then ns.Hub.RefreshHome() end
end
ns.Util.Events({ PLAYER_REGEN_DISABLED = Panels.Refresh, PLAYER_REGEN_ENABLED = Panels.Refresh,
  PLAYER_ENTERING_WORLD = Panels.Refresh }, "panel controls")
