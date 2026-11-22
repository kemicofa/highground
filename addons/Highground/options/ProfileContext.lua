local _, ns = ...
local Core, P, Kit, Theme = ns.Core, ns.Options.Profiles, ns.Kit, ns.Theme
local A = ns.UIConfig.appearance
P.CONTEXT_HEIGHT = 40

-- Compare effective settings, so restoring a default clears Modified even
-- when a setter stores the default explicitly. Empty lazy tables don't count.
local function Comparable(snap, tuningOnly)
  local prepared = P.Prepare(snap)
  if not prepared then return end
  if tuningOnly then prepared.setup = nil end
  local setup = prepared.setup
  if setup then
    local s = setup.style
    for key, choices in pairs({ font = A.fonts, bar = A.bars, barColor = A.barColors,
      borderColor = A.borderColors, healthStyle = A.healthStyles }) do s[key] = s[key] or choices[1].key end
    s.fontScale, s.border, s.frameless = s.fontScale or 1, s.border or A.border.default, s.frameless == true
    s.hideHero = nil -- old unused field; current visibility lives in hide.hero
    s.scales, s.hide = s.scales or {}, s.hide or {}
    s.layouts = s.layouts or {}
    for _, owner in ipairs({ "arena", "nearby" }) do
      if s.layouts[owner] == nil then
        local compact = setup.features.compact
        if compact == nil then compact = setup.preferences.compact end
        s.layouts[owner] = compact == true
      end
    end
    for _, def in ipairs(A.panels) do s.scales[def.key] = s.scales[def.key] or 1 end
    for _, def in ipairs(A.elements) do s.hide[def.key] = s.hide[def.key] == true end
    s.hide.hero = s.hide.hero ~= false
    for _, layout in ipairs({ "normal", "compact" }) do
      s[layout] = s[layout] or {}
      for _, def in ipairs(A.metrics) do
        s[layout][def.key] = s[layout][def.key] or Core.MetricDefault(def.key, layout == "compact")
      end
    end
    for key in pairs(Core.SavedDefs) do
      if key ~= "hubSection" and setup.preferences[key] == nil then setup.preferences[key] = Core.DEFAULTS[key] end
    end
    setup.preferences.theme = setup.preferences.theme or ns.DEFAULT_THEME
    setup.preferences.locked = setup.preferences.locked == true
    setup.preferences.reducedMotion = setup.preferences.reducedMotion == true
    setup.alerts.mode = setup.alerts.mode or "everything"
    setup.alerts.channels = setup.alerts.channels or {}
    for _, def in ipairs(ns.Alerts.categories) do
      local channel = setup.alerts.channels[def.key] or {}
      setup.alerts.channels[def.key] = { text = channel.text ~= false, sound = channel.sound ~= false }
    end
  end
  return prepared
end

-- Profile status is local state, not a wire payload. Comparing normalized
-- values avoids sorting keys and allocating serialized strings twice per poll.
local function Equal(a, b)
  if a == b then return true end
  if type(a) ~= type(b) then return false end
  -- Exports round numbers through tostring. A stepper can produce the same
  -- value with a tiny binary rounding difference after an imported load.
  if type(a) == "number" then return tostring(a) == tostring(b) end
  if type(a) ~= "table" then return false end
  for key, value in pairs(a) do if not Equal(value, b[key]) then return false end end
  for key in pairs(b) do if a[key] == nil then return false end end
  return true
end

-- Poll the inputs without building snapshots. Keep one bounded copy of the
-- relevant values, updating it in place so nested edits are noticed even when
-- a caller writes settings directly. Normalization only runs after a change.
local observed = { options = {}, features = {}, preferences = {}, positions = {} }
local tables = { "points", "weights", "specRatings", "disabledCooldowns", "burstModes" }
local extraPreferences = { "reducedMotion", "locked" }
local remaining, modified
local function Observe(into, key, value, depth)
  remaining = remaining - 1
  if remaining < 0 or (depth or 0) > 10 then return true end
  local old = into[key]
  if type(value) ~= "table" then into[key] = value; return old ~= value end
  local changed = type(old) ~= "table"
  if changed then old = {}; into[key] = old end
  for field, item in pairs(value) do
    if remaining < 0 then return true end
    changed = Observe(old, field, item, (depth or 0) + 1) or changed
  end
  for field in pairs(old) do
    if value[field] == nil then old[field], changed = nil, true end
  end
  return changed
end

local function InputsChanged(saved)
  -- Mirror Snapshot/SnapshotSetup inputs, excluding records and other profiles.
  remaining = 10000
  local db = Core.db
  local changed = Observe(observed, "saved", saved)
  for _, key in ipairs(tables) do changed = Observe(observed, key, db[key]) or changed end
  for key in pairs(Core.SettingDefs.option) do changed = Observe(observed.options, key, Core.O(key)) or changed end
  for _, def in ipairs(ns.OptionsConfig.features) do
    if def.key and ns.OptionAvailable(def) then
      changed = Observe(observed.features, def.key, Core.On(def.key)) or changed
    end
  end
  for key in pairs(Core.SavedDefs) do
    if key ~= "hubSection" then changed = Observe(observed.preferences, key, db[key]) or changed end
  end
  for _, key in ipairs(extraPreferences) do
    changed = Observe(observed.preferences, key, db[key]) or changed
  end
  for _, key in ipairs(Core.POSITION_KEYS) do changed = Observe(observed.positions, key, Core.pos[key]) or changed end
  local style, placement = Core.StyleDB(), ns.Setup and ns.Setup.placement
  changed = Observe(observed, "style", style) or changed
  changed = Observe(observed, "alerts", ns.Alerts.Settings()) or changed
  changed = Observe(observed, "placementLocked", placement and placement.locked == true) or changed
  changed = Observe(observed, "placementFrameless", placement and style == placement.style and placement.frameless) or changed
  return changed
end

function P.ActiveState()
  local db = Core.db or {}
  local name = type(db.activeProfile) == "string" and db.activeProfile
  local saved = name and db.profiles and db.profiles[name]
  local state = { name = saved and name or nil }
  local changed = (saved or ns.Options.panel:IsVisible()) and InputsChanged(saved)
  if changed then P.revision = (P.revision or 0) + 1 end
  state.revision = P.revision or 0
  if saved then
    if changed or modified == nil then
      local current, original = Comparable(P.Snapshot(), saved.setup == nil), Comparable(saved)
      modified = not current or not original or not Equal(current, original)
    end
    state.modified = modified
    state.label = ns.Locale:Format("highground.profilecontext.active_profile_name.3eaf23", { name = name })
    state.status = state.modified and ns.Locale:Get("highground.profilecontext.modified.19a532") or ns.Locale:Get("highground.profilecontext.saved_copy.1bbc68")
  elseif type(db.importedProfileName) == "string" then
    state.label = ns.Locale:Format("highground.profilecontext.active_profile_db_importedprofilename.b5eadf", { db_importedProfileName = db.importedProfileName })
    state.status = ns.Locale:Get("highground.profilecontext.imported_copy.51f85a")
  else
    state.label, state.status = ns.Locale:Get("highground.profilecontext.current_settings.fbbfb4"), ns.Locale:Get("highground.profilecontext.saved_automatically.5bee9c")
  end
  if P.pending then
    state.pending = P.pending.profileName or P.pending.importedProfileName or ns.Locale:Get("highground.profilecontext.imported_setup.684da1")
    state.status = ns.Locale:Get("highground.profilecontext.after_combat.09bba6")
  end
  return state
end

local bars, cached, at = {}, nil, -1
local function Current(force)
  local now = GetTime()
  if force or not cached or now - at >= 0.5 then cached, at = P.ActiveState(), now end
  return cached
end

-- Callers supply the controls anchored to the bottom of their window.
-- Reserve a footer outside the scrolling content. Embedded pages use the
-- hub's footer and regain their own when opened in Blizzard settings.
function P.AttachContext(owner, controls, onLayout)
  if owner.profileContext then return owner.profileContext end
  local anchors = {}
  for _, object in ipairs(controls or {}) do
    local points = {}
    for i = 1, object:GetNumPoints() do
      local point, relative, relativePoint, x, y = object:GetPoint(i)
      if type(relative) == "number" or relative == nil then
        x, y, relative, relativePoint = relative or 0, relativePoint or 0, owner, point
      end
      points[#points + 1] = { point, relative, relativePoint, x or 0, y or 0 }
    end
    anchors[#anchors + 1] = { object = object, points = points }
  end
  local bar = CreateFrame("Button", nil, owner)
  owner.profileContext = bar; bars[#bars + 1] = bar
  bar:SetPoint("BOTTOMLEFT", 1, 1); bar:SetPoint("BOTTOMRIGHT", -1, 1)
  bar:SetHeight(P.CONTEXT_HEIGHT - 2)
  Theme.Fill(bar, "BACKGROUND", "surface"):SetAllPoints()
  local line = Theme.Fill(bar, "ARTWORK", "border")
  line:SetPoint("TOPLEFT"); line:SetPoint("TOPRIGHT"); line:SetHeight(1)
  bar.state = Theme.Text(bar, "body", "textMuted")
  bar.state:SetPoint("RIGHT", -16, 0); bar.state:SetJustifyH("RIGHT"); bar.state:SetWordWrap(false)
  bar.label = Theme.Text(bar, "body", "text")
  bar.label:SetPoint("LEFT", 16, 0); bar.label:SetPoint("RIGHT", bar.state, "LEFT", -20, 0)
  bar.label:SetJustifyH("LEFT"); bar.label:SetWordWrap(false)
  bar:SetScript("OnClick", function()
    if ns.Hub then
      if owner ~= ns.Hub.win then
        owner:Hide()
        if HideUIPanel and SettingsPanel then pcall(HideUIPanel, SettingsPanel) end
      end
      ns.Hub.Open("profiles")
      local name = P.ActiveState().name
      if name then
        local panel = ns.Options.panel
        panel.SelectProfile(name)
      end
    else ns.Options.Open() end
  end)
  Kit.Tooltip(bar, function()
    local state = Current(true)
    local lines = { { state.label, "text", true }, { ns.Locale:Get("highground.profilecontext.active_settings_save_automatically.6543b7"), "textMuted", true } }
    lines[#lines + 1] = { state.name and ns.Locale:Get("highground.profilecontext.a_named_profile_is_a_separate_copy.14793c")
      or ns.Locale:Get("highground.profilecontext.save_a_named_profile_to_keep_a.b5701c"), "textMuted", true }
    if state.pending then lines[#lines + 1] = { ns.Locale:Format("highground.profilecontext.after_combat_state_pending.39caf5", { state_pending = state.pending }), "warning", true } end
    lines[#lines + 1] = { ns.Locale:Get("highground.profilecontext.click_to_open_profiles.b1aa16"), "accent", false }
    return lines
  end, { anchor = "ANCHOR_TOP" })
  function bar:Refresh(force)
    local embedded = ns.Hub and ns.Hub.content and owner:GetParent() == ns.Hub.content
    local state = Core.db and Current(force)
    local relevant = state and (state.name or state.pending or Core.db.importedProfileName)
    local visible = not embedded and not not relevant
    local inset = visible and P.CONTEXT_HEIGHT or 0
    if self.inset ~= inset then
      self.inset = inset
      for _, entry in ipairs(anchors) do
        entry.object:ClearAllPoints()
        for _, point in ipairs(entry.points) do
          local p, relative, rp, x, y = unpack(point)
          entry.object:SetPoint(p, relative, rp, x, y + (relative == owner and rp:find("BOTTOM") and inset or 0))
        end
      end
      if onLayout then onLayout(inset) end
    end
    self:SetShown(visible)
    if not Core.db or not self:IsVisible() then return end
    if self.lastState == state then return end
    self.lastState = state
    ns.Localization.BindField(self.label, state, "label"); self.state:SetText(state.status)
    Theme.Paint(self.state, (state.modified or state.pending) and "warning" or "textMuted")
  end
  local elapsed = 0
  bar:SetScript("OnUpdate", function(self, dt)
    elapsed = elapsed + dt
    if elapsed >= 0.5 then elapsed = 0; self:Refresh() end
  end)
  owner:HookScript("OnShow", function() bar:Refresh(true) end)
  bar:Refresh()
  return bar
end

function P.RefreshContext()
  cached = nil
  for _, bar in ipairs(bars) do bar:Refresh() end
end

P.AttachContext(ns.Options.panel, {}, function() if Core.db and ns.Options.panel:IsVisible() then ns.Options.panel.LayoutProfiles() end end)
for _, page in ipairs(ns.Options.pages) do
  P.AttachContext(page.frame, { page.scroll })
end
local share = P.share
P.AttachContext(share, {}, function() share:LayoutProfileShare() end)
