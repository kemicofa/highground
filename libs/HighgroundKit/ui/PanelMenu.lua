local _, ns = ...
local Core, Kit, Panels = ns.Core, ns.Kit, ns.PanelControls

-- Highground supplies its guided placement flow. Standalones unlock and
-- show their existing previews; the same menu can end the preview.
function Panels.Arrange()
  if InCombatLockdown() then return ns.Util.Say(Panels.Hint()) end
  Core.SetPanelsLocked(false)
  if ns.BattlegroundsPreview then
    if not ns.Timers.previewing then ns.BattlegroundsPreview.Start() end
  elseif ns.ArenaPreview then
    if not ns.Arena.preview and not ns.Arena.InArena() then ns.ArenaPreview() end
  elseif ns.NearbyPreview and not ns.Nearby.preview then
    ns.NearbyPreview()
  end
  ns.Util.Say(Panels.Hint())
end

local function Settings(page)
  if ns.Hub then ns.Hub.Open(page)
  elseif ns.StandaloneSettings then ns.StandaloneSettings.Open(page) end
end

function Panels.Items(key)
  local owner = key == "nearbyPoint" and "nearby" or key == "arenaPoint" and "arena" or "battlegrounds"
  local pages = ns.Options and ns.Options.addonPages and ns.Options.addonPages[owner]
  local context = owner == "nearby" and "world" or owner == "arena" and "arena" or "bg"
  local items = { Panels.MenuItem(), { text = ns.Locale:Get("highground.home.arrange_panels.e82274"), run = function() Panels.Arrange(context) end,
    hint = InCombatLockdown() and ns.Locale:Get("highground.profilecontext.after_combat.09bba6") or nil } }
  local function Add(text, run) items[#items + 1] = { text = text, run = run } end
  -- Battleground panels show, and their changes go to, one size.
  local CS = ns.CharacterSettings
  if CS and owner == "battlegrounds" and pages then
    table.insert(items, 1, { text = ns.Locale:Format("sizes.menu", { size = CS.Label(CS.Editing()) }),
      run = function() Settings(pages.settings) end })
  end
  local function EndPreview(run)
    items[#items + 1] = { text = ns.Locale:Get("shared.panelmenu.end_preview.8df98c"), hint = InCombatLockdown() and ns.Locale:Get("highground.profilecontext.after_combat.09bba6") or nil,
      run = function()
        if InCombatLockdown() then return ns.Util.Say(Panels.Hint()) end
        run()
      end }
  end
  local page, label = "general", ns.Locale:Get("shared.panelmenu.highground_settings.9e5345")
  if key == "enemies" then
    Add(ns.Locale:Get("shared.panelmenu.show_5_enemies.926916"), function() Core.SetRows(5) end)
    Add(ns.Locale:Get("shared.panelmenu.show_10_enemies.54a0a8"), function() Core.SetRows(10) end)
    Add(ns.Locale:Get("shared.panelmenu.show_all_enemies.d00af0"), function() Core.SetRows(Core.MAX_ROWS) end)
  elseif key == "nearbyPoint" then
    page, label = "nearby", ns.Locale:Get("shared.panelmenu.nearby_settings.d0fb8d")
    if ns.EnemyJournal then Add(ns.Locale:Get("highground.hub.enemy_journal.1dbc52"), function() ns.EnemyJournal.Open() end) end
    Add(ns.Locale:Get("nearby.main.clear_recent_sightings.e0162d"), function() ns.NearbyClear() end)
    if ns.Nearby.preview then EndPreview(function() ns.NearbyPreview() end) end
  elseif key == "arenaPoint" then
    label = ns.Locale:Get("shared.panelmenu.arena_settings.84b45c")
    if ns.MatchHistory then Add(ns.Locale:Get("highground.hub.match_history.b65b77"), function() ns.MatchHistory.Open() end) end
    if ns.Arena.preview then EndPreview(function() ns.ArenaPreview() end) end
  else
    page, label = "timers", ns.Locale:Get("highground.toursteps.battleground_settings.08240b")
    if key == "quickCallsPoint" or key == "flagsPoint" then page = "general" end
    if ns.MatchHistory then Add(ns.Locale:Get("highground.hub.match_history.b65b77"), function() ns.MatchHistory.Open() end) end
    if ns.Timers and ns.Timers.previewing and ns.BattlegroundsPreview then
      EndPreview(function() ns.BattlegroundsPreview.Stop() end)
    end
  end
  Add(ns.Locale:Get("shared.panelmenu.panel_appearance.5ce38c"), function() Settings(pages and pages.appearance or "appearance") end)
  Add(label, function() Settings(pages and pages.settings or page) end)
  if pages then Add(ns.Locale:Get("highground.hub.previews_and_guide.e53405"), function() Settings(pages.previews) end) end
  return items
end

function Panels.ToggleMenu(anchor)
  if Kit.Dropdown.Open(anchor, Panels.Items(anchor.key), function(item) item.run() end,
    { width = (InCombatLockdown() and 350 or 220) * math.max(1, Core.FontScale()), onClose = Panels.RefreshGears }) then
    Kit.Dropdown.Select(0, true)
  end
  Panels.Refresh()
end
