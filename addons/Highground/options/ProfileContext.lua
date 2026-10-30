local _, ns = ...
local Core, P, Kit, Theme = ns.Core, ns.Options.Profiles, ns.Kit, ns.Theme
local A = ns.UIConfig.appearance
P.CONTEXT_HEIGHT = 40

-- Compare effective settings, so restoring a default clears Modified even
-- when a setter stores the default explicitly. Empty lazy tables don't count.
local function Signature(snap, tuningOnly)
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
    for _, def in ipairs(A.panels) do s.scales[def.key] = s.scales[def.key] or 1 end
    for _, def in ipairs(A.elements) do s.hide[def.key] = s.hide[def.key] == true end
    s.hide.hero = s.hide.hero == true
    for _, layout in ipairs({ "normal", "compact" }) do
      s[layout] = s[layout] or {}
      for _, def in ipairs(A.metrics) do
        s[layout][def.key] = s[layout][def.key] or Core.MetricDefault(def.key, layout == "compact")
      end
    end
    for key in pairs(Core.SavedDefs) do
      if key ~= "hubSection" and setup.preferences[key] == nil then setup.preferences[key] = Core.DEFAULTS[key] end
    end
    setup.preferences.theme = setup.preferences.theme or "highground"
    setup.preferences.locked = setup.preferences.locked == true
    setup.preferences.reducedMotion = setup.preferences.reducedMotion == true
    setup.preferences.objectiveChannel = setup.preferences.objectiveChannel or "i"
    setup.alerts.mode = setup.alerts.mode or "everything"
    setup.alerts.channels = setup.alerts.channels or {}
    for _, def in ipairs(ns.Alerts.categories) do
      local channel = setup.alerts.channels[def.key] or {}
      setup.alerts.channels[def.key] = { text = channel.text ~= false, sound = channel.sound ~= false }
    end
  end
  return ns.Codec.Pack(prepared)
end

function P.ActiveState()
  local db = Core.db or {}
  local name = type(db.activeProfile) == "string" and db.activeProfile
  local saved = name and db.profiles and db.profiles[name]
  local state = { name = saved and name or nil }
  if saved then
    local current, original = Signature(P.Snapshot(), saved.setup == nil), Signature(saved)
    state.modified = not current or not original or current ~= original
    state.label = "Active profile: " .. name
    state.status = state.modified and "Modified" or "Saved copy"
  elseif type(db.importedProfileName) == "string" then
    state.label = "Active profile: " .. db.importedProfileName
    state.status = "Imported copy"
  else
    state.label, state.status = "Current settings", "Saved automatically"
  end
  if P.pending then
    state.pending = P.pending.profileName or P.pending.importedProfileName or "Imported setup"
    state.status = "After combat"
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
        panel.profileName:SetText(name); panel.savedProfiles:SetValue(name, true); panel.RefreshProfiles()
      end
    else ns.Options.Open() end
  end)
  Kit.Tooltip(bar, function()
    local state = Current(true)
    local lines = { { state.label, "text", true }, { "Active settings save automatically.", "textMuted", true } }
    lines[#lines + 1] = { state.name and "A named profile is a separate copy. Use Update profile to include your latest changes."
      or "Save a named profile to keep a reusable copy of this setup.", "textMuted", true }
    if state.pending then lines[#lines + 1] = { "After combat: " .. state.pending, "warning", true } end
    lines[#lines + 1] = { "Click to open Profiles.", "accent", false }
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
    self.label:SetText(state.label); self.state:SetText(state.status)
    Theme.Paint(self.state, (state.modified or state.pending) and "warning" or "textMuted")
  end
  bar:SetScript("OnUpdate", function(self) self:Refresh() end)
  owner:HookScript("OnShow", function() bar:Refresh(true) end)
  bar:Refresh()
  return bar
end

function P.RefreshContext()
  cached = nil
  for _, bar in ipairs(bars) do bar:Refresh() end
end

P.AttachContext(ns.Options.panel, { ns.Options.panel.profileScroll })
for _, page in ipairs(ns.Options.pages) do
  if page == ns.Options.general then
    P.AttachContext(page.frame, { page.review, page.saved }, function(inset)
      page.scroll:SetPoint("BOTTOMRIGHT", -30, (ns.Onboarding and ns.Onboarding.active == "features" and 64 or 10) + inset)
    end)
  else P.AttachContext(page.frame, { page.scroll }) end
end
local share = P.share
P.AttachContext(share, { share.done, share.status, share.actions.save, share.actions.apply, share.well })
