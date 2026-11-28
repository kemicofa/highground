local _, ns = ...
local Core, P, Parts = ns.Core, ns.Options.Profiles, ns.SettingsParts

---------------------------------------------------------------------------
-- Settings per character and addon, and the Battlegrounds addon's per size:
-- 10v10, 15v15, epic and open-world fights. HighgroundDB.characters[key] =
-- { name, class, updated, addons = { battlegrounds = { bg10, bg15, bg40,
-- world }, arena, nearby, bounties, macros, shared } } holds snapshots
-- (options/SettingsParts.lua) account-wide, so another character can copy
-- them. The live settings every feature reads hold this character's, with
-- the Battlegrounds addon's for one size (HighgroundCharDB.liveScope).
--
-- One size is edited at a time: a match's or a world fight's while it lasts,
-- otherwise the one picked (HighgroundCharDB.scope). Every settings page,
-- command, guide button and preset changes that size only.
---------------------------------------------------------------------------
local CS = {}
ns.CharacterSettings = CS
CS.SCOPES = { "bg10", "bg15", "bg40", "world" }
CS.SCOPE_SET = { bg10 = true, bg15 = true, bg40 = true, world = true }
-- Sample team per size for Preview.
CS.TEAM = { bg10 = 10, bg15 = 15, bg40 = 40, world = 5 }
local listeners = {}

-- The character's GUID; its name while the game has no GUID yet.
function CS.Key()
  local guid = UnitGUID and UnitGUID("player")
  if type(guid) == "string" and guid ~= "" then return guid end
  local name = UnitName and UnitName("player")
  return type(name) == "string" and name ~= "" and "name:" .. name or nil
end

local function Store() return ns.Saved.Table(Core.db, "characters") end
function CS.Entry(key, create)
  key = key or CS.Key()
  local entry = key and Core.db and type(Core.db.characters) == "table" and Core.db.characters[key]
  if type(entry) ~= "table" or type(entry.addons) ~= "table" then
    if not (create and key and Core.db) then return nil end
    entry = { addons = {} }
    Store()[key] = entry
  end
  return entry
end

function CS.Name() return Core.me.name or UnitName("player") or "" end
-- "15v15 battlegrounds", "Open-world fights".
function CS.Label(scope) return ns.Locale:Get("sizes.label." .. (CS.SCOPE_SET[scope] and scope or "bg10")) end

function CS.Listen(fn) listeners[#listeners + 1] = fn end
local function Changed() for _, fn in ipairs(listeners) do fn() end end
CS.Changed = Changed

-- The size a match or world fight fixes, or nil.
function CS.Locked()
  if select(2, IsInInstance()) == "pvp" then return Core.CurrentBracket() or Core.pos.liveScope end
  if Core.context == "world" then return "world" end
end
function CS.Selected()
  local scope = Core.pos and Core.pos.scope
  return CS.SCOPE_SET[scope] and scope or "bg10"
end
-- The size the live settings should hold.
local function Target() return CS.Locked() or CS.Selected() end
-- The size changes go to: the live one, also while a switch waits for combat.
function CS.Editing()
  if CS.waiting and CS.SCOPE_SET[Core.pos.liveScope] then return Core.pos.liveScope end
  return Target()
end

local function Load(addon, snap)
  local prepared = type(snap) == "table" and P.Prepare(snap)
  if prepared then Parts.Write(addon, prepared) end
  return prepared ~= nil
end
CS.LoadPart = Load

-- The live settings into this character's copies.
function CS.Save()
  if not CS.loaded then return end
  local entry = CS.Entry(nil, true)
  if not entry then return end
  entry.name, entry.class, entry.updated = CS.Name(), Core.me.class or select(2, UnitClass("player")), time()
  local bg = ns.Saved.Table(entry.addons, "battlegrounds")
  for _, addon in ipairs(Parts.ADDONS) do
    if addon ~= "battlegrounds" then entry.addons[addon] = Parts.Capture(addon) end
  end
  if CS.SCOPE_SET[Core.pos.liveScope] then bg[Core.pos.liveScope] = Parts.Capture("battlegrounds") end
end

-- Show the Battlegrounds settings of the size being edited.
function CS.Update()
  if CS.busy or not CS.loaded or not (Core.db and Core.pos) then return end
  local target, live = Target(), Core.pos.liveScope
  if target == live then return end
  if InCombatLockdown() then CS.waiting = true; return end
  CS.busy, CS.waiting = true, nil
  local entry = CS.Entry(nil, true)
  local bg = ns.Saved.Table(entry.addons, "battlegrounds")
  if CS.SCOPE_SET[live] then bg[live] = Parts.Capture("battlegrounds") end
  Core.pos.liveScope = target
  if not Load("battlegrounds", bg[target]) then bg[target] = Parts.Capture("battlegrounds") end
  Parts.Refresh()
  CS.busy = nil
  Changed()
end

-- Pick the size to edit outside matches and world fights.
function CS.Select(scope)
  if not CS.SCOPE_SET[scope] or CS.Locked() then return false end
  Core.pos.scope = scope
  CS.Update()
  if CS.preview and CS.preview.scope ~= scope then
    CS.preview.scope = scope
    ns.PreviewTests.StartBattlegrounds(CS.TEAM[scope])
  end
  Changed()
  return true
end

---------------------------------------------------------------------------
-- Preview: sample panels for the size being edited, at their real places
-- and unlocked, so they can be dragged while its settings change.
---------------------------------------------------------------------------
function CS.Previewing() return CS.preview ~= nil end
function CS.CanPreview()
  if CS.Locked() or not ns.PreviewTests then return false end
  return ns.PreviewTests.CanStart() == true
end

function CS.StopPreview()
  local state = CS.preview
  if not state then return true end
  CS.preview = nil
  ns.PreviewTests.StopBattlegrounds()
  Core.db.locked = state.locked
  if Core.StyleDB() == state.style then state.style.frameless = state.frameless end
  Core.ApplyStyle("frameless")
  Changed()
  return true
end

function CS.TogglePreview()
  if CS.preview then return CS.StopPreview() end
  if CS.Locked() then return false, ns.Locale:Get("sizes.preview.blocked") end
  local allowed, problem = ns.PreviewTests.CanStart()
  if not allowed then return false, problem end
  local scope, style = CS.Editing(), Core.StyleDB()
  CS.preview = { scope = scope, locked = Core.db.locked, style = style, frameless = style.frameless }
  Core.db.locked, style.frameless = false, false
  Core.ApplyStyle("frameless")
  ns.PreviewTests.StartBattlegrounds(CS.TEAM[scope])
  -- Samples belong to the settings window: closing it ends them.
  local hub = ns.Hub and ns.Hub.win
  if hub and not CS.hubHooked then CS.hubHooked = true; hub:HookScript("OnHide", function() CS.StopPreview() end) end
  Changed()
  return true
end

-- Copy the edited size's settings over other sizes. targets: { scope = true }.
function CS.CopyScope(targets)
  if InCombatLockdown() then return 0 end
  CS.Save()
  local from = Core.pos.liveScope
  local bg = CS.Entry(nil, true).addons.battlegrounds
  local count = 0
  for scope in pairs(targets) do
    if CS.SCOPE_SET[scope] and scope ~= from and bg[from] then bg[scope] = ns.Saved.Copy(bg[from]); count = count + 1 end
  end
  Changed()
  return count
end

---------------------------------------------------------------------------
-- Loading a character
---------------------------------------------------------------------------
-- A character seen for the first time starts as a copy of the live settings,
-- which are the last character's. Battleground layouts saved by an older
-- version become its sizes; a setup kept aside during a match is its base.
local function Seed(key)
  local entry = CS.Entry(key, true)
  local old = type(Core.pos.sizeLayout) == "table" and Core.pos.sizeLayout.stash
  local base = type(old) == "table" and type(old.snap) == "table" and old.snap or P.Snapshot()
  for _, addon in ipairs(Parts.ADDONS) do
    if addon ~= "battlegrounds" then
      entry.addons[addon] = Parts.Filter(base, addon)
      if base ~= nil and old then Load(addon, entry.addons[addon]) end
    end
  end
  local layouts = type(Core.db.sizeLayouts) == "table" and type(Core.db.sizeLayouts[key]) == "table" and Core.db.sizeLayouts[key] or {}
  local bg = {}
  for _, scope in ipairs(CS.SCOPES) do
    local layout = layouts[scope]
    bg[scope] = Parts.Filter(type(layout) == "table" and type(layout.snap) == "table" and layout.snap or base, "battlegrounds")
  end
  entry.addons.battlegrounds = bg
  if type(Core.db.sizeLayouts) == "table" then Core.db.sizeLayouts[key] = nil end
  for _, field in ipairs({ "sizeLayout", "layoutEdit", "rememberLayouts", "autoProfiles" }) do Core.pos[field] = nil end
  return entry
end

-- Named profiles from older versions become imports; only the built-in
-- Default and automatic switching go.
local function MigrateAccount()
  local db = Core.db
  if db.characterSettingsVersion == 1 then return end
  local imports = ns.Saved.Table(db, "profileImports")
  for name, snap in P.SortedPairs(type(db.profiles) == "table" and db.profiles or {}) do
    if name ~= "Default" and type(snap) == "table" then
      imports[#imports + 1] = { name = name, received = time(), snap = snap }
    end
  end
  for _, field in ipairs({ "profiles", "activeProfile", "importedProfileName", "profileAssignments", "profileDefaultVersion" }) do
    db[field] = nil
  end
  db.characterSettingsVersion = 1
end

function CS.Login()
  local key = CS.Key()
  if not (key and Core.db and Core.pos) then return end
  MigrateAccount()
  local entry = CS.Entry(key) or Seed(key)
  -- The live settings already hold this character's after a reload or when
  -- it was the last one played; otherwise load them.
  if Core.db.liveCharacter ~= key or not CS.SCOPE_SET[Core.pos.liveScope] then
    for _, addon in ipairs(Parts.ADDONS) do
      if addon ~= "battlegrounds" then Load(addon, entry.addons[addon]) end
    end
    Core.pos.liveScope = nil
  end
  Core.db.liveCharacter = key
  entry.name, entry.class = CS.Name(), Core.me.class or select(2, UnitClass("player"))
  CS.loaded = true
  CS.Update()
  Changed()
end

ns.Util.Events({
  PLAYER_LOGIN = CS.Login,
  PLAYER_LOGOUT = function() CS.StopPreview(); CS.Save() end,
  PLAYER_REGEN_DISABLED = CS.StopPreview,
  -- Entering or leaving a match locks or frees the size even without a swap.
  PLAYER_ENTERING_WORLD = function() CS.StopPreview(); CS.Update(); if CS.loaded then Changed() end end,
  ZONE_CHANGED_NEW_AREA = CS.Update,
  -- Rated and Blitz flags can arrive late and change the size.
  PVP_MATCH_STATE_CHANGED = CS.Update, PVP_MATCH_ACTIVE = CS.Update,
  PLAYER_REGEN_ENABLED = function() if CS.waiting then CS.waiting = nil; CS.Update(); Changed() end end,
}, "character settings")

CS.Listen(function() if ns.Options.RefreshScopeBars then ns.Options.RefreshScopeBars() end end)
