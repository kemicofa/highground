local _, ns = ...
local Core, Kit, Panels = ns.Core, ns.Kit, ns.PanelControls

function Panels.Arrange()
  local allowed, problem = ns.Setup.CanArrange()
  if not allowed then return ns.Util.Say(problem) end
  ns.Setup.Open(true)
  ns.Setup.BeginPlacement()
end

Kit.Tooltip(Core.frame, Panels.Tooltip, { anchor = "ANCHOR_RIGHT" })
