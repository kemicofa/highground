local _, ns = ...
local Core, P, Kit, Theme = ns.Core, ns.Options.Profiles, ns.Kit, ns.Theme
local activities = { { "bg", "Battlegrounds" }, { "arena", "Arena" }, ns.Localization.Define({ "world", ns.Locale:Get("highground.profileassignments.open_world.41995c") }, { [2] = "highground.profileassignments.open_world.41995c" }) }

function P.CreateAssignments(parent)
  local a = CreateFrame("Frame", nil, parent)
  a.title = Theme.Text(a, "heading", "text")
  a.title:SetPoint("TOPLEFT"); ns.Localization.Bind(a.title, "highground.profileassignments.automatic_switching.fa0f83")
  a.enabled = ns.Localization.BindWidget(Kit.Toggle(a, ns.Locale:Get("highground.profileassignments.switch_by_activity.e8d421"), { width = 230, onChange = function(_, on)
    Core.pos.autoProfiles = on
    P.lastAssignment = nil; P.Automatic(); parent.RefreshProfiles()
  end }), { label = "highground.profileassignments.switch_by_activity.e8d421" })
  a.enabled:SetPoint("TOPRIGHT")
  a.scope = Theme.Text(a, "body", "textMuted")
  a.scope:SetJustifyH("LEFT"); a.scope:SetWordWrap(true)
  a.activities, a.labels = {}, {}
  for _, def in ipairs(activities) do
    local key = def[1]
    local label = Theme.Text(a, "body", "textMuted")
    label:SetText(def[2]); label:SetJustifyH("LEFT")
    local select = Kit.Select(a, { width = 180, menu = true, choices = {}, onChange = function(_, name)
      if P.Assign(name, key) then P.lastAssignment = nil; P.Automatic() end
      parent.RefreshProfiles()
    end })
    Kit.Tooltip(select, function() return { { select.label:GetText(), "text", true },
      { ns.Locale:Get("highground.profileassignments.assignment_for_this_character_and_specialization_saves.8560af"), "textMuted", true } } end)
    a.activities[key], a.labels[key] = select, label
  end
  function a:Layout(width)
    local scale = math.max(1, Core.FontScale())
    self.enabled:SetWidth(math.max(210, self.enabled.label:GetStringWidth() + 40))
    self.scope:ClearAllPoints(); self.scope:SetPoint("TOPLEFT", 0, -34); self.scope:SetWidth(width)
    self.scope:SetHeight(self.scope:GetStringHeight())
    local y = 34 + self.scope:GetHeight() + 10
    local col = (width - 24) / 3
    for i, def in ipairs(activities) do
      local label, select = self.labels[def[1]], self.activities[def[1]]
      label:ClearAllPoints(); label:SetPoint("TOPLEFT", (i - 1) * (col + 12), -y); label:SetWidth(col)
      select:ClearAllPoints(); select:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -6); select:SetWidth(col)
      select:SetHeight(32)
    end
    self:SetHeight(y + math.max(22, 18 * scale) + 32)
  end
  function a:Refresh()
    local choices = { { key = "none", label = ns.Locale:Get("highground.profileassignments.keep_current_settings.f9292b") } }
    for name in P.SortedPairs(Core.db.profiles or {}) do choices[#choices + 1] = { key = name, label = name } end
    self.enabled:SetChecked(Core.pos.autoProfiles, true)
    local info = Core.specInfo[Core.me.specID]
    self.scope:SetText(ns.Locale:Format("highground.profileassignments.value1_value3_value5_choices_save_immediately.b289f8", { value1 = (Core.me.name or UnitName("player") or ns.Locale:Get("highground.profileassignments.this_character.8dfadf")), value3 = (info and info.name or ns.Locale:Get("highground.profileassignments.current_specialization.29783e")), value5 = (Core.pos.autoProfiles and ns.Locale:Get("highground.profileassignments.on.e0049a") or ns.Locale:Get("highground.profileassignments.off.e3de5a")) }))
    for _, def in ipairs(activities) do
      local who, context = P.Context(def[1])
      local name = Core.db.profileAssignments and Core.db.profileAssignments[who] and Core.db.profileAssignments[who][context]
      local select = self.activities[def[1]]
      select:SetChoices(choices)
      select:SetValue(name and Core.db.profiles[name] and name or "none", true)
    end
  end
  return a
end

-- Existing callers land on the visible controls on the Profiles page.
function P.OpenAssignments()
  if ns.Hub then ns.Hub.Open("profiles") else ns.Options.Open() end
  return ns.Options.panel.assignments
end
ns.Util.Events({
  PLAYER_SPECIALIZATION_CHANGED = function() if ns.Options.panel:IsVisible() then ns.Options.panel.RefreshProfiles() end end,
  ACTIVE_TALENT_GROUP_CHANGED = function() if ns.Options.panel:IsVisible() then ns.Options.panel.RefreshProfiles() end end,
}, "profile assignment controls")
