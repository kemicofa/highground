local _, ns = ...
local Core, Theme, Kit, Hub = ns.Core, ns.Theme, ns.Kit, ns.Hub

-- Compatibility for /hg config: exact keys win, then case-insensitive keys,
-- sidebar labels and settings page names. New code can use strict Navigate.
local aliases = { checklist = "addons", ["feature guide"] = "addons",
  ["panels and features"] = "general", ["help and previews"] = "tools", ["general"] = "general",
  ["nearby settings"] = "nearby", ["bounty settings"] = "bounty", ["nearby enemies"] = "nearby", ["guild bounties"] = "bounty" }
-- Saved sections and /hg config links from before workspaces opened separately.
local workspaces = { macros = "macros-settings", reputation = "reputation-settings", bountyboard = "bounty",
  journal = "nearby", history = "battlegrounds-settings" }
local labels = { ["macro builder"] = "macros", ["player reputation"] = "reputation", ["bounty board"] = "bountyboard",
  ["enemy journal"] = "journal", ["match history"] = "history" }
for key, target in pairs(workspaces) do aliases[key] = target end
for label, key in pairs(labels) do aliases[label] = workspaces[key] end
local function Find(w, key)
  key = type(key) == "string" and (aliases[key:lower()] or key) or key
  local want = type(key) == "string" and key:lower()
  if not want then return end
  for _, b in ipairs(w.nav) do if b.section.key == key then return b end end
  for _, b in ipairs(w.nav) do if b.section.key:lower() == want then return b end end
  for _, b in ipairs(w.nav) do
    local s = b.section
    local page = ns.OptionsConfig.pages[s.key]
    if s.key:lower() == want or s.label:lower() == want or (page and page.name:lower() == want) then return b end
  end
end

local function Enter(section, to)
  local config = ns.OptionsConfig.pages[section.key]
  local owner = config and config.module or Hub.ModuleRoutes[section.key]
  if owner and not ns.Modules.Active(owner) then
    section = { key = "module-" .. owner, frame = function() return Hub.BuildModules(owner) end }
  end
  -- Resolve the lazy component before releasing the current one. A missing
  -- optional feature must not change the selection or create a history entry.
  local frame = section.frame and section.frame(to)
  if not frame then return false, ns.Locale:Format("highground.routes.page_is_unavailable_section_key.fdf871", { section_key = section.key }) end
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
  local page = ns.Options.byKey[section.key]
  if page then
    -- Each visit starts a settings page at the top; Back/Forward keep its scroll.
    if page.visit ~= Hub.visit and page.scroll then page.visit = Hub.visit; page.scroll:SetVerticalScroll(0) end
    ns.Options.RefreshPage(page)
    if to.params.section == "alerts" and page.ScrollToAlerts then page.ScrollToAlerts() end
  end
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
  if selected and selected.groupButton then Hub.SetGroupExpanded(selected.groupButton, true) end
  for _, b in ipairs(w.nav) do Kit.Paint(b, b == selected and "selected" or "panel") end
  Hub.LayoutNav(w)
  if changed then ns.Motion.Reveal(Hub.content, "page", Theme.Alpha("pageEnter")) end
  local parts, version = {}, Hub.Version()
  if version ~= "" then parts[1] = "V" .. version end
  parts[#parts + 1] = (ns.Games[ns.GAME] or ns.Games.retail).label
  parts[#parts + 1] = ns.Text.Upper(event.to.meta and event.to.meta.label or key)
  w:SetSub(table.concat(parts, "  ·  "))
end

function Hub.BuildRoutes(w)
  local router = ns.Router.New()
  Hub.router = router
  for _, section in ipairs(Hub.sections) do
    if section.key then
      Register(router, section.key, section)
    end
  end
  router:Register("checklist", { redirect = "addons" })
  for key, target in pairs(workspaces) do Register(router, key, { redirect = target }) end
  router:On("change", Changed)
  router:On("cancel", function(event) Hub.refusal = event.stage end)
  w.back = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("highground.coachview.back.b52b36"), 80, Theme.Size("control"), { onClick = function() Hub.Back() end }), "highground.coachview.back.b52b36")
  w.forward = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("highground.routes.forward.ba4e72"), 100, Theme.Size("control"), { onClick = function() Hub.Forward() end }), "highground.routes.forward.ba4e72")
  Kit.Tooltip(w.back, function() return { "Back", ns.Locale:Get("highground.routes.return_to_the_previous_page_in_this.0afe99") } end)
  Kit.Tooltip(w.forward, function() return { "Forward", ns.Locale:Get("highground.routes.revisit_the_page_you_went_back_from.d62d81") } end)
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

-- Opening the hub after it was closed starts a new visit (hub/Hub.lua).
local function Go(target, opts)
  local router = Hub.GetRouter()
  if Hub.ended and not Hub.win:IsShown() then
    Hub.visit = Hub.visit + 1
    Hub.ResetNav(Hub.win)
    Hub.refusal = nil
    local ok, failure = router:Reset(target)
    -- A page that refuses to leave (an unsaved draft) reopens instead.
    if ok or Hub.refusal ~= "guard" or not router:Current() then return ok, failure end
    target = router:Current()
  end
  return router:Navigate(target, opts)
end

function Hub.Navigate(target, opts)
  local w = Hub.Build()
  opts = opts or {}
  return Go(target, { replace = opts.replace, refresh = opts.refresh or not w:IsShown() })
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
  return Go(target, { refresh = true })
end

function Hub.Open(key)
  local router = Hub.GetRouter()
  return Hub.Show(key or not Hub.ended and router:Current() or "home")
end

function Hub.Toggle(key)
  local w = Hub.Build()
  local b = key and Find(w, key)
  local selected = b and b.section.key or key
  if w:IsShown() and (not key or selected == Hub.current) then w:Hide() else return Hub.Open(key) end
end

-- A reload started from the hub reopens it on the same page.
function Hub.Reload()
  if Core.db and Hub.win and Hub.win:IsShown() then Core.db.hubReopen = Hub.current end
  local ok, problem = ns.Modules.Reload()
  if not ok and Core.db then Core.db.hubReopen = nil end
  return ok, problem
end

ns.Util.Events({ PLAYER_LOGIN = function()
  local key = Core.db and Core.db.hubReopen
  if not key then return end
  Core.db.hubReopen = nil
  Hub.Open(key)
end }, "hub reopen")
