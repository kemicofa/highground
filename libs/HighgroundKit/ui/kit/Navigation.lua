local _, ns = ...
local Kit = ns.Kit

-- A feature exposes its page router through the frame it lends to a host.
-- Header navigation remains separate from feature actions and slot counts.
function Kit.AttachNavigation(frame, router)
  if frame.navigation == router then return end
  assert(not frame.navigation, "A window already has a page router")
  frame.navigation = router
  local back = Kit.Button(frame.header, "Back", 80, ns.Theme.Size("control"), { onClick = function() router:Back() end })
  local forward = Kit.Button(frame.header, "Forward", 100, ns.Theme.Size("control"), { onClick = function() router:Forward() end })
  frame.routeBack, frame.routeForward = back, forward
  Kit.Tooltip(back, { "Back", "Return to the previous page in this tool." })
  Kit.Tooltip(forward, { "Forward", "Revisit the next page in this tool." })
  frame.header:SetNavigation({ back, forward })
  local function Refresh()
    back:SetEnabled(router:CanGo(-1)); forward:SetEnabled(router:CanGo(1))
    if ns.Hub and ns.Hub.UpdateHistory then ns.Hub.UpdateHistory() end
  end
  router:On("history", Refresh)
  Refresh()
end
