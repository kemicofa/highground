local _, ns = ...
local W = ns.Reputation
local UI = W.UI
local MODES = { "organizations", "settings", "overview", "blacklist", "proposals", "members", "history" }

local function Capture(W)
  local UI, f = W.UI, W.UI.window
  return { query = f.search:GetText(), page = UI.page, scope = UI.viewScope,
    scroll = UI.mode == "settings" and f.settings:GetVerticalScroll()
      or UI.mode == "overview" and f.overview:GetVerticalScroll() or 0 }
end

function UI.GetRouter(source)
  local W = source or W
  local UI = W.UI
  if UI.router then return UI.router end
  local router = ns.Router.New()
  UI.router = router
  for _, mode in ipairs(MODES) do
    router:Register(mode, {
      beforeEnter = function(to)
        if to.name ~= "organizations" and to.name ~= "settings" then
          local id = to.params.organization or W.db.selected
          if not id or not (W.organizations or ns.Organizations).Get(id) then return "organizations" end
          if to.name ~= "overview" and not W.Joined(W.Get(id)) then
            return { name = "overview", params = { organization = id } }
          end
        end
      end,
      capture = function() return Capture(W) end,
      enter = function(to)
        local f = W.Build()
        local state = to.state and to.state.scope == W.currentScope and to.state or {}
        UI.mode, UI.viewScope = to.name, W.currentScope
        if to.params.organization then W.db.selected = to.params.organization end
        f.search:SetText(state.query or ""); UI.page = state.page or 1
        UI.Refresh()
        -- Kit scroll areas clamp a restored offset to their current range.
        local scroll = to.name == "settings" and f.settings or to.name == "overview" and f.overview
        if scroll then scroll:SetVerticalScroll(state.scroll or 0) end
      end,
    })
  end
  return router
end

function UI.SetMode(mode, organization, source)
  local W = source or W
  return W.UI.GetRouter():Navigate({ name = mode, params = { organization = organization or W.db.selected } })
end

-- Reuse the bounded router history for tab clicks. Explicit actions such as
-- submitting a report still open fresh lists through SetMode.
function UI.SelectTab(mode, organization, source)
  local W = source or W
  local router, id = W.UI.GetRouter(), organization or W.db.selected
  local current = router:Current()
  if not current or current.name == mode and current.params.organization == id then
    return router:Navigate({ name = mode, params = { organization = id } })
  end
  local visits = router:History()
  for i = #visits, 1, -1 do
    local visit = visits[i]
    if visit.name == mode and (mode == "settings" or visit.params.organization == id)
      and visit.state and visit.state.scope == W.currentScope then
      visit.params.organization = id
      return router:Navigate(visit, { restoreState = true })
    end
  end
  return router:Navigate({ name = mode, params = { organization = id } })
end

function UI.ReturnToOrganizations(source)
  local W = source or W
  local router = W.UI.GetRouter()
  local visits, index = router:History()
  for i = index - 1, 1, -1 do
    local visit = visits[i]
    if visit.name ~= "settings" and visit.state and visit.state.scope == W.currentScope then
      return router:Navigate(visit, { restoreState = true })
    end
  end
  return W.UI.SetMode("organizations")
end

function UI.GoPage(delta, source)
  local W = source or W
  local UI = W.UI
  local page = math.max(1, math.min(UI.pages, UI.page + delta))
  if page == UI.page then return true end
  local target = UI.GetRouter():Current()
  target.state = Capture(W); target.state.page = page
  return UI.GetRouter():Navigate(target, { restoreState = true })
end
