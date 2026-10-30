local _, ns = ...
local Core, P, U = ns.Core, ns.Options.Profiles, ns.Util
local A = ns.UIConfig.appearance
local function Copy(t) return ns.Codec.Unpack(ns.Codec.Pack(t)) end
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

function P.SnapshotSetup()
  local positions = {}
  for _, key in ipairs(Core.POSITION_KEYS) do if Core.pos[key] then positions[key] = Copy(Core.pos[key]) end end
  local setup = { features = {}, preferences = {}, positions = positions, style = Copy(Core.StyleDB()),
    alerts = Copy(ns.Alerts.Settings()), disabledCooldowns = Copy(Core.db.disabledCooldowns or {}),
    burstModes = Copy(Core.db.burstModes or {}) }
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
  setup.preferences.objectiveChannel = Core.db.objectiveChannel or "i"
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
      if key == "objectiveChannel" then assert(({ i = true, raid = true, party = true, s = true })[value], "invalid callout channel")
      elseif key == "reducedMotion" or key == "locked" then assert(type(value) == "boolean", "invalid motion preference")
      elseif Core.SavedDefs[key] and key ~= "hubSection" then assert(Core.SavedValid(Core.SavedDefs[key], value), "invalid " .. key)
      else setup.preferences[key] = nil end
    end
    local anchors = { TOP = true, TOPLEFT = true, TOPRIGHT = true, LEFT = true, CENTER = true, RIGHT = true,
      BOTTOM = true, BOTTOMLEFT = true, BOTTOMRIGHT = true }
    local positions = {}; for _, key in ipairs(Core.POSITION_KEYS) do positions[key] = true end
    for key, v in pairs(setup.positions) do
      assert(positions[key] and type(v) == "table" and anchors[v[1]] and anchors[v[2]]
        and Finite(v[3], -10000, 10000) and Finite(v[4], -10000, 10000), "invalid window position")
    end
    Style(setup.style)
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
  local who = Core.CanonUnit("player") or "player"
  return who, tostring(Core.me.specID or Core.me.class or "unknown") .. ":" .. (activity or (kind == "arena" and "arena" or kind == "pvp" and "bg" or "world"))
end

function P.Assign(name, activity)
  if name ~= "none" and not (Core.db.profiles and Core.db.profiles[name]) then return false, "Choose a saved profile." end
  if not ({ bg = true, arena = true, world = true })[activity] then return false, "Choose an activity." end
  local who, context = P.Context(activity)
  Core.db.profileAssignments = Core.db.profileAssignments or {}
  Core.db.profileAssignments[who] = Core.db.profileAssignments[who] or {}
  Core.db.profileAssignments[who][context] = name ~= "none" and name or nil
  return true, "Assignment saved for this character and specialization."
end

function P.Automatic()
  if not Core.db or not Core.pos or not Core.pos.autoProfiles then return end
  local who, context = P.Context()
  local name = Core.db.profileAssignments and Core.db.profileAssignments[who] and Core.db.profileAssignments[who][context]
  local signature = who .. context .. tostring(name)
  if name and P.lastAssignment ~= signature then
    if P.LoadProfile(name) then P.lastAssignment = signature; U.Say("profile: " .. name .. (InCombatLockdown() and " (after combat)" or "")) end
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
