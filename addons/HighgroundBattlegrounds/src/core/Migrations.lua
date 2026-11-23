local _, ns = ...
local Core = ns.Core

---------------------------------------------------------------------------
-- Saved variables: create HighgroundDB / HighgroundCharDB (a standalone
-- addon's: ns.SAVED_VARIABLE and its CharDB), fill defaults,
-- reset damaged values (Core.ValidateSaved, core/Settings.lua) and run the
-- one-time upgrades. Called once from ADDON_LOADED (core/Events.lua).
---------------------------------------------------------------------------

-- Old account-wide dialog positions -> HighgroundDB.windows[key]
-- (ui/kit/Dialog.lua). Copies are marked legacy and refreshed each load
-- while the module still saves the old key; the first Kit.SavePoint
-- replaces the copy, after which the old key is ignored.
Core.LEGACY_WINDOWS = { bountyPoint = "bounty", macroPoint = "macros", hubPoint = "hub" }

-- A damaged marker (not a number) reruns its idempotent upgrade instead of
-- stopping the load.
local function Versioned(db, field, version, fn)
  ns.Saved.Migrate(db, field, version, fn)
end

local function MigrateWindows(db)
  for legacy, key in pairs(Core.LEGACY_WINDOWS) do
    local p = db[legacy]
    if type(p) == "table" and type(p[1]) == "string" and type(p[2]) == "string"
      and type(p[3]) == "number" and type(p[4]) == "number" then
      if type(db.windows) ~= "table" then db.windows = {} end
      local current = db.windows[key]
      if current == nil or (type(current) == "table" and current.legacy) then
        db.windows[key] = { p[1], p[2], p[3], p[4], legacy = true }
      end
    end
  end
end

-- Per-character window positions, seeded once from the old account-wide
-- ones so an existing layout doesn't move.
local function SeedPositions(db, pos)
  if pos.seeded then return end
  for _, key in ipairs(Core.POSITION_KEYS) do
    if pos[key] == nil and type(db[key]) == "table" then
      pos[key] = { unpack(db[key]) }
    end
  end
  pos.seeded = true
end

local ACCOUNT = ns.SAVED_VARIABLE or "HighgroundDB"
local CHARACTER = ACCOUNT:gsub("DB$", "CharDB")

local function MigrateSniper(db)
  if type(db.sniperVersion) == "number" and db.sniperVersion >= 5 then return end
  local function Upgrade(settings)
    local placement = settings.sniperPlacement
    if (placement == nil or placement == "body") and (settings.sniperY == nil or settings.sniperY == -62)
      and (settings.sniperX == nil or settings.sniperX == 0) then
      settings.sniperPlacement, settings.sniperY = "head", -24
    else
      settings.sniperPlacement = placement or "body"
      if settings.sniperY == nil then
        settings.sniperY = placement == "head" and -24 or settings.sniperPlacement == "body" and -40 or 0
      end
    end
  end
  Upgrade(db) -- move the old untouched body default; keep custom placements
  for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
    local setup = type(profile) == "table" and profile.setup
    if type(setup) == "table" and type(setup.preferences) == "table" then Upgrade(setup.preferences) end
  end
  db.sniperVersion = 5
end

function Core.LoadSaved()
  Core.firstInstall = type(_G[ACCOUNT]) ~= "table"
  local db = type(_G[ACCOUNT]) == "table" and _G[ACCOUNT] or {}
  _G[ACCOUNT] = db
  Core.db = db
  if Core.firstInstall then
    ns.ApplyFirstRunDefaults(db)
    if not ns.SAVED_VARIABLE then db.locked = true end
  end
  MigrateSniper(db)
  for k, v in pairs(Core.DEFAULTS) do
    if db[k] == nil then
      db[k] = type(v) == "table" and {} or v
    end
  end
  Core.ValidateSaved(db)
  ns.InitializeUIScale()
  for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
    if type(profile) == "table" and type(profile.points) == "table" then ns.NormalizePointSettings(profile.points) end
  end
  Versioned(db, "battlegroundScopeVersion", 2, function()
    -- Enable unrated matches on upgrades, including saved setups that can
    -- load automatically on entry. Later scope choices survive reloads.
    db.allBGs = true
    for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
      local setup = type(profile) == "table" and profile.setup
      if type(setup) == "table" and type(setup.features) == "table" then setup.features.allBGs = true end
    end
  end)
  Versioned(db, "soundVersion", 2, function()
    db.sniperSound = 1 -- custom lock-on sound is the new default
  end)
  Versioned(db, "sniperThemeVersion", 2, function()
    -- Gold was the default ring. It now follows the theme (gold in Highground);
    -- other presets and custom colours stay.
    local function Upgrade(settings)
      if settings.sniperColor == "gold" then settings.sniperColor = "theme" end
    end
    Upgrade(db)
    for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
      local setup = type(profile) == "table" and profile.setup
      if type(setup) == "table" and type(setup.preferences) == "table" then Upgrade(setup.preferences) end
    end
  end)
  Versioned(db, "rowsVersion", 3, function()
    -- Rows used to default to 10, then to 5 on new installs: show the whole
    -- enemy team instead, in saved setups too.
    local function Upgrade(settings)
      if settings.rows == 10 or settings.rows == 5 then settings.rows = Core.MAX_ROWS end
    end
    Upgrade(db)
    for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
      local setup = type(profile) == "table" and profile.setup
      if type(setup) == "table" and type(setup.preferences) == "table" then Upgrade(setup.preferences) end
    end
  end)
  Versioned(db, "gyLearnedVersion", 2, function()
    -- Start areas learned before the side was confirmed may carry the
    -- wrong team (cross-faction games); they are relearned on release.
    for _, list in pairs(type(db.gyLearned) == "table" and db.gyLearned or {}) do
      if type(list) == "table" then
        for i = #list, 1, -1 do
          if type(list[i]) == "table" and list[i].fromPlace then table.remove(list, i) end
        end
      end
    end
  end)
  -- Spec history now lives in scoped storage; only drop the empty stub older
  -- defaults recreated on every load. Populated legacy records stay.
  if type(db.history) == "table" and next(db.history) == nil then db.history = nil end
  MigrateWindows(db)
  Core.pos = type(_G[CHARACTER]) == "table" and _G[CHARACTER] or {}
  _G[CHARACTER] = Core.pos
  SeedPositions(db, Core.pos)
  if ns.Localization then ns.Localization.Initialize(db) end
  return db
end
