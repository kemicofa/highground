local _, ns = ...
local Core, Theme, Kit, Hub = ns.Core, ns.Theme, ns.Kit, ns.Hub

-- Compatibility for /hg config: exact keys win, then case-insensitive keys,
-- sidebar labels and settings page names. New code can use strict Navigate.
local function Find(w, key)
  local want = type(key) == "string" and key:lower()
  if not want then return end
  for _, b in ipairs(w.nav) do if b.section.key == key then return b end end
  for _, b in ipairs(w.nav) do
    local s = b.section
    local page = ns.OptionsConfig.pages[s.key]
    if s.key:lower() == want or s.label:lower() == want or (page and page.name:lower() == want) then return b end
  end
end

local function Enter(section, to)
  local owner = Hub.ModuleRoutes[section.key]
  if owner and not ns.Modules.Active(owner) then
    section = { key = "module-" .. owner, frame = function() return Hub.BuildModules(owner) end }
  end
  -- Resolve the lazy component before releasing the current one. A missing
  -- optional feature must not change the selection or create a history entry.
  local frame = section.frame and section.frame(to)
  if not frame then return false, "Page is unavailable: " .. section.key end
  Kit.Windows.Show(Hub.win, function()
    if frame == Hub.home then
      Hub.Return()
      frame:Show()
      if Hub.RefreshHome then Hub.RefreshHome() end
    else
      if Hub.home then Hub.home:Hide() end
      Hub.Borrow(frame)
    end
  end)
  -- OnShow can run after the host becomes visible. The host/content owns
  -- the transition, so an embedded dialog must not add a second fade.
  ns.Motion.Stop(frame, 1)
  Hub.activeFrame = frame
  return true
end

local function Register(router, name, opts)
  assert(type(opts) == "table", "Expected hub route options")
  assert(opts.label == nil or type(opts.label) == "string", "A hub route label must be a string")
  assert(type(opts.frame) == "function" or opts.redirect ~= nil, "A hub route needs a lazy frame factory or redirect")
  local section = { key = name, label = opts.label or name, frame = opts.frame }
  return router:Register(name, { meta = { label = section.label }, redirect = opts.redirect,
    beforeEnter = opts.beforeEnter, beforeLeave = opts.beforeLeave, capture = opts.capture,
    enter = function(to) return Enter(section, to) end })
end

local function Changed(event)
  local w, key = Hub.win, event.to.name
  local selected = Find(w, key)
  local changed = Hub.current ~= key
  Hub.current = key
  if Core.db then Core.db.hubSection = key end
  if selected and selected.groupButton then Hub.SetGroupExpanded(selected.groupButton, true) end
  for _, b in ipairs(w.nav) do Kit.Paint(b, b == selected and "selected" or "panel") end
  Hub.LayoutNav(w)
  if changed then ns.Motion.Reveal(Hub.content, "page", Theme.Alpha("pageEnter")) end
  local parts, version = {}, Hub.Version()
  if version ~= "" then parts[1] = "V" .. version end
  parts[#parts + 1] = (ns.Games[ns.GAME] or ns.Games.retail).label
  parts[#parts + 1] = (event.to.meta and event.to.meta.label or key):upper()
  w:SetSub(table.concat(parts, "  ·  "))
  ns.Options.Profiles.RefreshContext()
end

function Hub.BuildRoutes(w)
  local router = ns.Router.New()
  Hub.router = router
  for _, section in ipairs(Hub.sections) do
    if section.key then
      Register(router, section.key, section)
    end
  end
  router:On("change", Changed)
  w.back = Kit.Button(w, "Back", 80, Theme.Size("control"), { onClick = function() Hub.Back() end })
  w.forward = Kit.Button(w, "Forward", 100, Theme.Size("control"), { onClick = function() Hub.Forward() end })
  Kit.Tooltip(w.back, { "Back", "Return to the previous page in this window." })
  Kit.Tooltip(w.forward, { "Forward", "Revisit the page you went back from." })
  w.header:SetActions({ w.back, w.forward })
  function Hub.UpdateHistory()
    local child = Hub.activeFrame and Hub.activeFrame.navigation
    w.back:SetEnabled(router:CanGo(-1) or child and child:CanGo(-1))
    w.forward:SetEnabled(router:CanGo(1) or child and child:CanGo(1))
  end
  router:On("history", Hub.UpdateHistory)
  Hub.UpdateHistory()
end

-- The router is initialized lazily with the settings pages and their frames.
function Hub.GetRouter() Hub.Build(); return Hub.router end
function Hub.RegisterRoute(name, opts) return Register(Hub.GetRouter(), name, opts) end
function Hub.Navigate(target, opts)
  local router = Hub.GetRouter()
  opts = opts or {}
  return router:Navigate(target, { replace = opts.replace, refresh = opts.refresh or not Hub.win:IsShown() })
end
function Hub.Redirect(target) return Hub.Navigate(target, { replace = true }) end
function Hub.Back()
  local router = Hub.GetRouter()
  local child = Hub.activeFrame and Hub.activeFrame.navigation
  return (child and child:CanGo(-1) and child or router):Back()
end
function Hub.Forward()
  local router = Hub.GetRouter()
  local child = Hub.activeFrame and Hub.activeFrame.navigation
  return (child and child:CanGo(1) and child or router):Forward()
end

function Hub.Show(key)
  local w = Hub.Build()
  local target = key
  if type(key) ~= "table" then
    local selected = Find(w, key)
    target = selected and selected.section.key or (Hub.router:Has(key) and key) or "home"
  end
  -- Reopening a returned page must mount it again, without pushing a duplicate.
  return Hub.router:Navigate(target, { refresh = true })
end

function Hub.Open(key)
  local router = Hub.GetRouter()
  return Hub.Show(key or router:Current() or (Core.db and Core.db.hubSection) or "home")
end

function Hub.Toggle(key)
  local w = Hub.Build()
  local b = key and Find(w, key)
  local selected = b and b.section.key or key
  if w:IsShown() and (not key or selected == Hub.current) then w:Hide() else return Hub.Open(key) end
end
