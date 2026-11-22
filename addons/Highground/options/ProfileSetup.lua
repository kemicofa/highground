local _, ns = ...
local Core, P, U = ns.Core, ns.Options.Profiles, ns.Util
local A = ns.UIConfig.appearance
-- Copy data directly. Snapshot/status checks run while settings are open;
-- encoding and decoding every table here creates avoidable strings and sorts.
-- Keep the codec's structural limits for malformed saved/imported profiles.
local function Copy(source)
  local remaining, bytes = 10000, 0
  local function Visit(value, depth)
    remaining = remaining - 1
    assert(depth <= 8 and remaining >= 0, "setup data limit")
    local kind = type(value)
    if kind == "boolean" then return value end
    if kind == "number" then
      assert(value == value and math.abs(value) ~= math.huge, "invalid number")
      return value
    end
    if kind == "string" then
      bytes = bytes + #value; assert(bytes <= 131072, "setup data too large")
      return value
    end
    assert(kind == "table", "invalid setup value")
    local result, count = {}, 0
    for key, item in pairs(value) do
      count = count + 1
      assert(count <= 2000 and (type(key) == "string" or type(key) == "number"), "invalid setup table")
      result[Visit(key, depth + 1)] = Visit(item, depth + 1)
    end
    return result
  end
  return Visit(source, 0)
end
local function Finite(v, lo, hi) return type(v) == "number" and v == v and v >= lo and v <= hi end
local function Choice(list, value)
  for _, def in ipairs(list) do if def.key == value then return true end end
  return false
end
local function Features()
  local out = {}
  for _, def in ipairs(ns.OptionsConfig.features) do if def.key and ns.OptionAvailable(def) then out[def.key] = true end end
  return out
end

function P.DefaultSetup()
  local setup = { features = {}, preferences = { reducedMotion = false, locked = false }, positions = {},
    style = {}, alerts = { mode = "everything", channels = {} }, disabledCooldowns = {}, burstModes = {} }
  for key in pairs(Features()) do setup.features[key] = Core.DEFAULTS[key] ~= false end
  for key in pairs(Core.SavedDefs) do
    if key ~= "hubSection" then setup.preferences[key] = Core.DEFAULTS[key] end
  end
  setup.preferences.theme = ns.DEFAULT_THEME
  return setup
end

local function Plain(value) return type(value) == "table" and value or {} end -- damaged saved values copy as empty

function P.SnapshotSetup()
  local positions = {}
  for _, key in ipairs(Core.POSITION_KEYS) do if Core.pos[key] then positions[key] = Copy(Core.pos[key]) end end
  local setup = { features = {}, preferences = {}, positions = positions, style = Copy(Core.StyleDB()),
    alerts = Copy(ns.Alerts.Settings()), disabledCooldowns = Copy(Plain(Core.db.disabledCooldowns)),
    burstModes = Copy(Plain(Core.db.burstModes)) }
  for key in pairs(Features()) do setup.features[key] = Core.On(key) end
  for key in pairs(Core.SavedDefs) do
    if key ~= "hubSection" and Core.db[key] ~= nil then setup.preferences[key] = Core.db[key] end
  end
  setup.preferences.reducedMotion = Core.db.reducedMotion == true
  setup.preferences.locked = Core.db.locked == true
  local placement = ns.Setup and ns.Setup.placement
  if placement then
    setup.preferences.locked = placement.locked == true
    if Core.StyleDB() == placement.style then setup.style.frameless = placement.frameless end
  end
  return setup
end

local function Style(style)
  assert(type(style) == "table", "invalid appearance")
  local choices = { font = A.fonts, bar = A.bars, barColor = A.barColors, borderColor = A.borderColors, healthStyle = A.healthStyles }
  for key, v in pairs(style) do
    if choices[key] then assert(Choice(choices[key], v), "invalid " .. key)
    elseif key == "frameless" or key == "hideHero" then assert(type(v) == "boolean", "invalid " .. key)
    elseif key == "fontScale" then assert(Finite(v, A.fontScale.min, A.fontScale.max), "invalid text size")
    elseif key == "border" then assert(Finite(v, A.border.min, A.border.max), "invalid border")
    elseif key == "layouts" then
      assert(type(v) == "table", "invalid panel layouts")
      for owner, compact in pairs(v) do
        assert((owner == "arena" or owner == "nearby") and type(compact) == "boolean", "invalid panel layout")
      end
    elseif key == "scales" or key == "hide" or key == "normal" or key == "compact" then
      assert(type(v) == "table", "invalid appearance group")
      for field, value in pairs(v) do
        if key == "scales" then assert(Choice(A.panels, field) and Finite(value, A.panelScale.min, A.panelScale.max), "invalid panel scale")
        elseif key == "hide" then
          -- The kill-target card uses hide.hero but is outside the enemy-row catalog.
          assert((field == "hero" or Choice(A.elements, field)) and type(value) == "boolean", "invalid row element: " .. tostring(field))
        else
          assert(Core.MetricDef(field), "invalid dimension")
          local lo, hi = Core.MetricRange(field, key == "compact")
          assert(Finite(value, lo, hi), "invalid dimension")
        end
      end
    else error("unknown appearance setting: " .. tostring(key)) end
  end
end

function P.PrepareSetup(source)
  if source == nil then return nil end
  local ok, result = pcall(function()
    assert(type(source) == "table", "invalid setup")
    local setup = Copy(source)
    assert(setup, "invalid setup data")
    for _, key in ipairs({ "features", "preferences", "positions", "style", "alerts", "disabledCooldowns", "burstModes" }) do
      assert(type(setup[key] or {}) == "table", "invalid " .. key); setup[key] = setup[key] or {}
    end
    local features = Features()
    for key, value in pairs(setup.features) do
      assert(type(value) == "boolean", "invalid switch")
      if not features[key] then setup.features[key] = nil end
    end
    for key, value in pairs(setup.preferences) do
      if key == "reducedMotion" or key == "locked" then assert(type(value) == "boolean", "invalid motion preference")
      elseif Core.SavedDefs[key] and key ~= "hubSection" then assert(Core.SavedValid(Core.SavedDefs[key], value), "invalid " .. key)
      else setup.preferences[key] = nil end
    end
    -- Feature switches apply after preferences. Compare their effective value
    -- when older exports or a preset candidate contain both representations.
    for key, value in pairs(setup.features) do
      if Core.SavedDefs[key] then setup.preferences[key] = value end
    end
    local anchors = { TOP = true, TOPLEFT = true, TOPRIGHT = true, LEFT = true, CENTER = true, RIGHT = true,
      BOTTOM = true, BOTTOMLEFT = true, BOTTOMRIGHT = true }
    local positions = {}; for _, key in ipairs(Core.POSITION_KEYS) do positions[key] = true end
    for key, v in pairs(setup.positions) do
      assert(positions[key] and type(v) == "table" and anchors[v[1]] and anchors[v[2]]
        and Finite(v[3], -10000, 10000) and Finite(v[4], -10000, 10000), "invalid window position")
    end
    Style(setup.style)
    Core.NormalizePanelStyle(setup.style, setup.features.compact or setup.preferences.compact)
    local alerts = setup.alerts
    assert(alerts.mode == nil or ({ essential = true, everything = true, critical = true, objectives = true, quiet = true })[alerts.mode], "invalid alert preset")
    assert(type(alerts.channels or {}) == "table", "invalid alert channels")
    local known = {}; for _, def in ipairs(ns.Alerts.categories) do known[def.key] = true end
    for key, value in pairs(alerts.channels or {}) do
      assert(known[key] and type(value) == "table", "invalid alert category")
      for channel, on in pairs(value) do assert((channel == "text" or channel == "sound") and type(on) == "boolean", "invalid alert channel") end
    end
    for key, value in pairs(setup.disabledCooldowns) do assert(Finite(key, 1, 10000000) and type(value) == "boolean", "invalid cooldown preference") end
    for key, value in pairs(setup.burstModes) do assert(Finite(key, 1, 10000000) and type(value) == "string"
      and ({ auto = true, purge = true, cc = true, off = true })[value], "invalid burst preference") end
    return setup
  end)
  return ok and result or nil, not ok and tostring(result) or nil
end

function P.ApplySetup(setup)
  if not setup then return end
  if ns.Setup and ns.Setup.placement then ns.Setup.EndPlacement(false) end
  for key in pairs(Core.SavedDefs) do if key ~= "hubSection" then Core.db[key] = setup.preferences[key] or Core.DEFAULTS[key] end end
  for key, value in pairs(setup.preferences) do Core.db[key] = value end
  for key, value in pairs(setup.features) do Core.db[key] = value end
  for _, key in ipairs(Core.POSITION_KEYS) do Core.pos[key] = setup.positions[key] and Copy(setup.positions[key]) end
  for _, key in ipairs({ "style", "alerts", "disabledCooldowns", "burstModes" }) do Core.db[key] = Copy(setup[key]) end
  Core.ApplyStyle()
  Core.SetFontScale(Core.FontScale())
  if Core.frame then Core.PlaceDockHead(Core.frame) end
  for _, win in ipairs(ns.Timers and ns.Timers.windows or {}) do ns.Timers.PlaceWin(win) end
  if ns.MinimapButton then ns.MinimapButton.Apply() end
  Core.CheckZone(); Core.ApplyKillOrder()
  if ns.PanelControls then ns.PanelControls.Refresh() end
end

function P.Context(activity)
  U.call(Core.UpdateMe)
  local kind = select(2, IsInInstance())
  local who = ns.Scope.Character() or "player"
  return who, tostring(Core.me.specID or Core.me.class or "unknown") .. ":" .. (activity or (kind == "arena" and "arena" or kind == "pvp" and "bg" or "world"))
end

ns.Scope.Listen(function() P.pending, P.lastAssignment = nil, nil end)

function P.Assign(name, activity)
  if name ~= "none" and not (Core.db.profiles and Core.db.profiles[name]) then return false, ns.Locale:Get("highground.settings.choose_a_saved_profile.5c404b") end
  if not ({ bg = true, arena = true, world = true })[activity] then return false, ns.Locale:Get("highground.profilesetup.choose_an_activity.609d3d") end
  local who, context = P.Context(activity)
  ns.Saved.Table(ns.Saved.Table(Core.db, "profileAssignments"), who)[context] = name ~= "none" and name or nil
  return true, ns.Locale:Get("highground.profilesetup.assignment_saved_for_this_character_and_specialization.c4e1b1")
end

function P.Automatic()
  P.MigrateDefault()
  if not Core.db or not Core.pos then return end
  if not Core.pos.autoProfiles then
    if P.pending and P.pending.automaticAssignment then P.pending = nil end
    return
  end
  local who, context = P.Context()
  local name = Core.db.profileAssignments and Core.db.profileAssignments[who] and Core.db.profileAssignments[who][context]
  local signature = who .. context .. tostring(name)
  if P.pending and P.pending.automaticAssignment and P.pending.automaticAssignment ~= signature then P.pending = nil end
  if name and P.lastAssignment ~= signature then
    if P.LoadProfile(name) then
      P.lastAssignment = signature
      if P.pending then P.pending.automaticAssignment = signature end
      U.Say(ns.Locale:Format("highground.profilesetup.profile_name_value3.ed3d26", { name = name, value3 = (InCombatLockdown() and ns.Locale:Get("highground.profilesetup.after_combat.5a00b1") or "") }))
    end
  elseif not name then P.lastAssignment = nil end
end

U.Events({
  PLAYER_REGEN_ENABLED = function()
    if P.pending then local setup = P.pending; P.pending = nil; P.Apply(setup) end
    P.Automatic()
  end,
  PLAYER_ENTERING_WORLD = P.Automatic, PLAYER_SPECIALIZATION_CHANGED = P.Automatic,
  ACTIVE_TALENT_GROUP_CHANGED = P.Automatic, PLAYER_TALENT_UPDATE = P.Automatic,
}, "profile switching")
