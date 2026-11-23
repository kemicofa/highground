local _, ns = ...
local A, Kit, Theme = ns.Alerts, ns.Kit, ns.Theme
local modes = {
  ns.Localization.Define({ key = "everything", label = ns.Locale:Get("shared.alerts.everything.4a66d1"), hint = ns.Locale:Get("shared.alerts.allow_every_alert_category_including_sightings_and.a001be") }, { label = "shared.alerts.everything.4a66d1", hint = "shared.alerts.allow_every_alert_category_including_sightings_and.a001be" }),
  ns.Localization.Define({ key = "critical", label = ns.Locale:Get("highground.profilesummary.critical_only.e1206b"), hint = ns.Locale:Get("shared.alerts.focus_on_captures_objective_changes_resurrection_and.fc44e0") }, { label = "highground.profilesummary.critical_only.e1206b", hint = "shared.alerts.focus_on_captures_objective_changes_resurrection_and.fc44e0" }),
  ns.Localization.Define({ key = "objectives", label = ns.Locale:Get("shared.battlegrounds.objectives.24d505"), hint = ns.Locale:Get("shared.alerts.focus_on_bases_carriers_resurrection_and_sap.18351b") }, { label = "shared.battlegrounds.objectives.24d505", hint = "shared.alerts.focus_on_bases_carriers_resurrection_and_sap.18351b" }),
  ns.Localization.Define({ key = "quiet", label = ns.Locale:Get("highground.profilesummary.text_only.9ccbd0"), hint = ns.Locale:Get("shared.alerts.show_written_alerts_without_alert_sounds.8b71bd") }, { label = "highground.profilesummary.text_only.9ccbd0", hint = "shared.alerts.show_written_alerts_without_alert_sounds.8b71bd" }),
  -- Shown when the switches match no preset; choosing it changes nothing.
  ns.Localization.Define({ key = "custom", label = ns.Locale:Get("alerts.preset.custom"), hint = ns.Locale:Get("alerts.preset.custom_hint") }, { label = "alerts.preset.custom", hint = "alerts.preset.custom_hint" }),
}
-- Presets a player can choose (not Custom), for /hg alerts preset.
function A.PresetChoices()
  local choices = {}
  for _, def in ipairs(modes) do
    if def.key ~= "custom" then choices[#choices + 1] = { key = def.key, label = def.label } end
  end
  return choices
end

function A.PresetLabel(key)
  for _, def in ipairs(modes) do if def.key == key then return def.label end end
  return key
end

local function Describe(w, mode)
  for _, def in ipairs(modes) do
    if def.key == mode then w.description:SetText(def.label .. "\n\n" .. def.hint); return end
  end
end
local alertOwners = { "battlegrounds", "nearby", "bounties" }

function A.SoundButton(parent, def)
  local button
  local function Play(variant)
    local ok, problem = A.PlaySample(def.key, variant)
    if not ok then ns.Util.Say(problem) end
  end
  button = Kit.Button(parent, ns.Locale:Get("alerts.sample.play"), 130, 30, { onClick = function()
    if def.key == "stealth" then
      Kit.Dropdown.Open(button, { { text = ns.Locale:Get("alerts.sample.enter"), value = "enter" },
        { text = ns.Locale:Get("alerts.sample.exit"), value = "exit" } }, function(item) Play(item.value) end)
    else Play() end
  end })
  ns.Localization.Bind(button, "alerts.sample.play")
  button.label:SetPoint("LEFT", 8, 0); button.label:SetPoint("RIGHT", -8, 0); button.label:SetWordWrap(false)
  Kit.Tooltip(button, function() return { ns.Locale:Format("alerts.sample.tooltip", { action = def.label }),
    { ns.Locale:Get("alerts.sample.description"), "textMuted", true } } end)
  return button
end

local function LayoutLinks(w)
  local width = (w.body:GetWidth() - 24) / #alertOwners
  for i, owner in ipairs(alertOwners) do
    local button = w.addonLinks[owner]
    button:SetWidth(width)
    button:SetPoint("TOPLEFT", (i - 1) * (width + 12), -30)
  end
end

function A.Open(embedded)
  if not A.win then
    local profiles = ns.Options and ns.Options.Profiles
    local footer = profiles and profiles.CONTEXT_HEIGHT or 0
    local w = ns.Localization.BindWidget(Kit.Dialog((ns.FRAME_PREFIX or "Highground") .. "AlertOptions", {
      title = ns.Locale:Get("shared.alerts.alerts.f6ab69"), titleRole = "title", sub = ns.Locale:Get("highground.profilecontext.saved_automatically.5bee9c"),
      width = 640, height = 460 + footer, savedKey = "alerts" }), { title = "shared.alerts.alerts.f6ab69", sub = "highground.profilecontext.saved_automatically.5bee9c" })
    A.win = w
    w.hint = Theme.Text(w, "bodyLarge", "text")
    w.hint:SetPoint("TOPLEFT", 24, -86); w.hint:SetPoint("TOPRIGHT", -24, -86)
    w.hint:SetHeight(52); w.hint:SetJustifyH("LEFT"); w.hint:SetJustifyV("TOP"); w.hint:SetWordWrap(true)
    ns.Localization.Bind(w.hint, "shared.alerts.which_alerts_help_you_while_you_play.0a50ad")
    w.mode = Kit.Select(w, { width = 220, menu = true, choices = modes, onPreview = function(_, value)
      Describe(w, value)
    end, onChange = function(_, value)
      if value ~= "custom" then A.SetMode(value) end
      w:Refresh()
    end })
    w.mode:SetPoint("TOPLEFT", 24, -140)
    w.description = Theme.Text(w, "bodyLarge", "text")
    w.description:SetPoint("TOPLEFT", w.mode, "TOPRIGHT", 24, 0); w.description:SetPoint("TOPRIGHT", -24, -140)
    w.description:SetHeight(196); w.description:SetJustifyH("LEFT"); w.description:SetJustifyV("TOP"); w.description:SetWordWrap(true)
    if not ns.Modules then
      w.customize = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("shared.alerts.customize_categories.57e2f2"), 240, 30, { onClick = function()
        w.expanded = not w.expanded; w:Refresh()
      end }), "shared.alerts.customize_categories.57e2f2")
      w.customize:SetPoint("TOPLEFT", 24, -332)
      w.scroll = CreateFrame("ScrollFrame", nil, w, "UIPanelScrollFrameTemplate")
      w.scroll:SetPoint("TOPLEFT", 24, -378); w.scroll:SetPoint("BOTTOMRIGHT", -44, 96)
    end
    w.body = CreateFrame("Frame", nil, w.scroll or w)
    w.body:SetSize(550, #A.categories * 42)
    if w.scroll then w.scroll:SetScrollChild(w.body) end
    w.rows = {}
    if ns.Modules then
      w.linkTitle = Theme.Text(w.body, "bodyLarge", "text")
      w.linkTitle:SetPoint("TOPLEFT"); ns.Localization.Bind(w.linkTitle, "shared.alerts.addon_alerts.d0812a")
      w.addonLinks = {}
      for _, owner in ipairs(alertOwners) do
        local name = ns.Modules.byKey[owner].name
        local button = Kit.Button(w.body, name, 170, 32, { onClick = function()
          ns.Hub.Open({ name = ns.Options.addonPages[owner].settings, params = { section = "alerts" } })
        end })
        Kit.Tooltip(button, function()
          return { ns.Locale:Format("shared.alerts.name_alerts.9265f3", { name = name }), ns.Modules.Active(owner) and ns.Locale:Get("shared.alerts.open_this_addon_s_text_and_sound.7410b2")
            or ns.Locale:Get("shared.alerts.enable_this_addon_in_addons_then_reload.2a2038") }
        end)
        w.addonLinks[owner] = button
      end
      w.body:HookScript("OnSizeChanged", function() LayoutLinks(w) end)
    end
    for _, def in ipairs(A.categories) do
      if not ns.Modules or def.module == "shared" then
        local i = #w.rows + 1
        local y = (ns.Modules and 82 or 0) + (i - 1) * 42
        local row = { key = def.key }
        local label = Theme.Text(w.body, "body", "text")
        label:SetPoint("TOPLEFT", 0, -y - 4); label:SetPoint("TOPRIGHT", -380, -y - 4)
        label:SetJustifyH("LEFT"); label:SetWordWrap(true); ns.Localization.BindField(label, def, "label")
        for _, channel in ipairs({ "text", "sound" }) do
          local key = channel
          row[key] = Kit.Toggle(w.body, key == "text" and ns.Locale:Get("highground.addonpages.text.c3328c") or ns.Locale:Get("highground.addonpages.sound.b4e3ef"), { width = key == "text" and 90 or 104, onChange = function(_, on)
            A.SetChannel(def.key, key, on); w:Refresh()
          end })
          row[key]:SetPoint("TOPRIGHT", key == "text" and -270 or -150, -y)
        end
        row.play = A.SoundButton(w.body, def)
        row.play:SetPoint("TOPRIGHT", 0, -y)
        w.rows[#w.rows + 1] = row
      end
    end
    w.body:SetHeight((ns.Modules and 82 or 0) + #w.rows * 44)
    w.status = Theme.Text(w, "body", "textMuted")
    w.status:SetPoint("BOTTOMLEFT", 24, 65); w.status:SetPoint("BOTTOMRIGHT", -24, 65)
    w.status:SetJustifyH("LEFT")
    w.done = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("highground.coach.done.e9b450"), 220, 34, { tone = "accent", onClick = function()
      if ns.Onboarding and ns.Onboarding.active == "alerts" then return ns.Onboarding.Reviewed("alerts") end
      if ns.Hub then ns.Hub.Release(w) end
      w:Hide()
    end }), "highground.coach.done.e9b450")
    w.done:SetPoint("BOTTOMRIGHT", -24, 20)
    function w:Refresh()
      local mode, sounds = A.Preset(A.Settings()), ns.Core.On("sound")
      self.mode:SetValue(mode, true)
      Describe(self, mode)
      for _, row in ipairs(self.rows) do
        row.text:SetChecked(A.ChannelOn(row.key, "text"), true)
        row.sound:SetChecked(A.ChannelOn(row.key, "sound"), true)
        row.sound:SetEnabled(sounds)
      end
      local extra = 96 * math.max(0, ns.Core.FontScale() - 1)
      if self.addonLinks then
        self.body:SetPoint("TOPLEFT", 24, -332 - extra); self.body:SetPoint("TOPRIGHT", -24, -332 - extra)
        LayoutLinks(self)
        for owner, button in pairs(self.addonLinks) do button:SetEnabled(ns.Modules.Active(owner)) end
      else
        self.customize:SetText(self.expanded and ns.Locale:Get("shared.alerts.hide_category_controls.9ed53a") or ns.Locale:Get("shared.alerts.customize_categories.57e2f2"))
        self.scroll:SetShown(self.expanded == true)
        self.customize:SetPoint("TOPLEFT", 24, -332 - extra)
        self.scroll:SetPoint("TOPLEFT", 24, -378 - extra)
      end
      self:SetHeight((self.addonLinks and 580 or self.expanded and 620 or 460) + footer + extra)
      self.status:SetText(not sounds and ns.Locale:Get("alerts.master_off")
        or (self.addonLinks or self.expanded) and ns.Locale:Get("alerts.preset.status") or ns.Locale:Get("shared.alerts.you_can_change_this_any_time.70dffb"))
      self.done:SetText(ns.Onboarding and ns.Onboarding.active == "alerts" and ns.Locale:Get("shared.alerts.use_these_alerts.cf6988") or ns.Locale:Get("highground.coach.done.e9b450"))
    end
    w:HookScript("OnShow", function() w:Refresh() end)
    ns.Core.OnFontScaleChange(function() if w:IsShown() then w:Refresh() end end)
    if profiles and profiles.AttachContext then profiles.AttachContext(w, { w.status, w.done, w.scroll }) end
  end
  local w = A.win
  w:Refresh()
  if not embedded then if ns.Hub then ns.Hub.Release(w) end; w:Show() end
  return w
end
