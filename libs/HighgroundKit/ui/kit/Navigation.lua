local _, ns = ...
local Kit = ns.Kit

-- A feature exposes its page router through the frame it lends to a host.
-- Header navigation remains separate from feature actions and slot counts.
function Kit.AttachNavigation(frame, router)
  if frame.navigation == router then return end
  assert(not frame.navigation, "A window already has a page router")
  frame.navigation = router
  local back = ns.Localization.Bind(Kit.Button(frame.header, ns.Locale:Get("highground.coachview.back.b52b36"), 80, ns.Theme.Size("control"), { onClick = function() router:Back() end }), "highground.coachview.back.b52b36")
  local forward = ns.Localization.Bind(Kit.Button(frame.header, ns.Locale:Get("highground.routes.forward.ba4e72"), 100, ns.Theme.Size("control"), { onClick = function() router:Forward() end }), "highground.routes.forward.ba4e72")
  frame.routeBack, frame.routeForward = back, forward
  Kit.Tooltip(back, function() return { ns.Locale:Get("highground.coachview.back.b52b36"), ns.Locale:Get("shared.navigation.return_to_the_previous_page_in_this.b94a62") } end)
  Kit.Tooltip(forward, function() return { ns.Locale:Get("highground.routes.forward.ba4e72"), ns.Locale:Get("shared.navigation.revisit_the_next_page_in_this_tool.f715d9") } end)
  frame.header:SetNavigation({ back, forward })
  local function Refresh()
    back:SetEnabled(router:CanGo(-1)); forward:SetEnabled(router:CanGo(1))
    if ns.Hub and ns.Hub.UpdateHistory then ns.Hub.UpdateHistory() end
  end
  router:On("history", Refresh)
  Refresh()
end
