local _, ns = ...
local Core, P, Kit, Theme, L = ns.Core, ns.Options.Profiles, ns.Kit, ns.Theme, ns.Locale
-- Battlegrounds switch by size in Battlegrounds settings (P.Layouts).
local activities = { { "arena", "profiles.activity.arena" }, { "world", "profiles.activity.world" } }
if not ns.Games[ns.GAME].arenaSize then table.remove(activities, 1) end -- no arenas on WoW Forever

function P.CreateAssignments(parent)
  local a = CreateFrame("Frame", nil, parent)
  a.enabled = Kit.Toggle(a, L:Get("profiles.switching.title"), { width = 210, onChange = function(_, on)
    Core.pos.autoProfiles = on
    P.lastAssignment = nil; P.Automatic(); parent.RefreshProfiles()
  end })
  a.enabled:SetPoint("TOPRIGHT")
  a.scope = Theme.Text(a, "body", "textMuted")
  a.scope:SetJustifyH("LEFT"); a.scope:SetWordWrap(true)
  a.activities, a.labels = {}, {}
  for _, def in ipairs(activities) do
    local key = def[1]
    local label = Theme.Text(a, "body", "textMuted")
    label:SetText(L:Get(def[2])); label:SetJustifyH("LEFT"); label:SetWordWrap(true)
    local select = Kit.Select(a, { width = 180, menu = true, choices = {}, onChange = function(_, name)
      if P.Assign(name ~= "" and name or nil, key) then P.lastAssignment = nil; P.Automatic() end
      parent.RefreshProfiles()
    end })
    Kit.Tooltip(select, function() return { { select.label:GetText(), "text", true },
      { L:Get("profiles.switching.hint"), "textMuted", true } } end)
    a.activities[key], a.labels[key] = select, label
  end
  a.sizesLabel = Theme.Text(a, "body", "textMuted")
  a.sizesLabel:SetJustifyH("LEFT"); a.sizesLabel:SetWordWrap(true)
  a.sizes = Kit.Button(a, L:Get("battlegrounds.sizes.title"), 180, 32, { onClick = function() ns.Options.ShowBattlegroundSizes() end })
  Kit.Tooltip(a.sizes, function() return { { L:Get("battlegrounds.sizes.title"), "text", true },
    { L:Get("profiles.switching.sizes_hint"), "textMuted", true } } end)
  function a:Layout(width)
    self.enabled:ClearAllPoints(); self.enabled:SetPoint("TOPLEFT")
    self.enabled:SetWidth(width); self.enabled:SetHeight(28)
    self.scope:ClearAllPoints(); self.scope:SetPoint("TOPLEFT", self.enabled, "BOTTOMLEFT", 0, -6); self.scope:SetWidth(width)
    self.scope:SetHeight(self.scope:GetStringHeight())
    local y = self.enabled:GetHeight() + 6 + self.scope:GetHeight() + 10
    for i, def in ipairs(activities) do
      local label, select = self.labels[def[1]], self.activities[def[1]]
      label:ClearAllPoints(); label:SetPoint("TOPLEFT", 0, -y - 5); label:SetWidth(width * 0.48 - 8)
      label:SetHeight(label:GetStringHeight())
      local height = math.max(32, label:GetHeight() + 10)
      select:ClearAllPoints(); select:SetPoint("TOPLEFT", width * 0.48, -y); select:SetWidth(width * 0.52)
      select:SetHeight(height)
      y = y + height + 8
    end
    local sizes = self.sizes:IsShown()
    self.sizesLabel:SetShown(sizes)
    if sizes then
      self.sizesLabel:ClearAllPoints(); self.sizesLabel:SetPoint("TOPLEFT", 0, -y - 5); self.sizesLabel:SetWidth(width * 0.48 - 8)
      self.sizesLabel:SetHeight(self.sizesLabel:GetStringHeight())
      local height = math.max(32, self.sizesLabel:GetHeight() + 10)
      self.sizes:ClearAllPoints(); self.sizes:SetPoint("TOPLEFT", width * 0.48, -y); self.sizes:SetWidth(width * 0.52)
      self.sizes:SetHeight(height)
      y = y + height + 8
    end
    self:SetHeight(y - 8)
  end
  function a:Refresh()
    -- Empty names cannot be saved, so this never shadows a named profile.
    local choices = { { key = "", label = L:Get("profiles.switching.keep") } }
    for name in P.SortedPairs(Core.db.profiles or {}) do choices[#choices + 1] = { key = name, label = name } end
    self.enabled:SetChecked(Core.pos.autoProfiles, true)
    self.enabled.label:SetText(L:Get("profiles.switching.title"))
    self.scope:SetText(Core.me.name or UnitName("player") or "")
    self.sizes:SetShown(ns.Modules.Active("battlegrounds"))
    self.sizesLabel:SetText(L:Get("profiles.activity.bg"))
    self.sizes:SetText(L:Get("battlegrounds.sizes.title"))
    for _, def in ipairs(activities) do
      self.labels[def[1]]:SetText(L:Get(def[2]))
      local who, context = P.Context(def[1])
      local name = Core.db.profileAssignments and Core.db.profileAssignments[who] and Core.db.profileAssignments[who][context]
      local select = self.activities[def[1]]
      select:SetChoices(choices)
      select:SetValue(name and Core.db.profiles[name] and name or "", true)
    end
  end
  return a
end

-- Existing callers land on the visible controls on the Profiles page.
function P.OpenAssignments()
  if ns.Hub then ns.Hub.Open("profiles") else ns.Options.Open() end
  return ns.Options.panel.assignments
end

