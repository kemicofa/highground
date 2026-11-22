local _, ns = ...
local Core, Kit, Panels = ns.Core, ns.Kit, ns.PanelControls

function Panels.Arrange(context)
  local allowed, problem = ns.Setup.CanArrange()
  if not allowed then return ns.Util.Say(problem) end
  ns.Setup.Open(true)
  if ns.Setup.BeginPlacement() and context then
    ns.Setup.PreviewContext(context)
    ns.Setup.layoutBar.context:SetValue(context, true)
  end
end

Kit.Tooltip(Core.frame, Panels.Tooltip, { anchor = "ANCHOR_RIGHT" })
