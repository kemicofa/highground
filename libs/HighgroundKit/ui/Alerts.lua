local _, ns = ...
local A, Kit, Theme = ns.Alerts, ns.Kit, ns.Theme
local modes = {
  { key = "essential", label = "Essentials", hint = "Objective warnings, attack openings, nearby enemies, enemy stealth and bounty alerts. Target-lock alerts stay quiet." },
  { key = "everything", label = "Everything", hint = "Allow every alert category, including sightings and target locks." },
  { key = "critical", label = "Critical only", hint = "Focus on captures, objective changes, resurrection and kill windows." },
  { key = "objectives", label = "Objectives", hint = "Focus on bases, carriers, resurrection and sap opportunities." },
  { key = "quiet", label = "Text only", hint = "Show written alerts without alert sounds." },
}
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
    local w = Kit.Dialog((ns.FRAME_PREFIX or "Highground") .. "AlertOptions", {
      title = "ALERTS", titleRole = "title", sub = "Saved automatically",
      width = 640, height = 460 + footer, savedKey = "alerts" })
    A.win = w
    w.hint = Theme.Text(w, "bodyLarge", "text")
    w.hint:SetPoint("TOPLEFT", 24, -86); w.hint:SetPoint("TOPRIGHT", -24, -86)
    w.hint:SetHeight(52); w.hint:SetJustifyH("LEFT"); w.hint:SetJustifyV("TOP"); w.hint:SetWordWrap(true)
    w.hint:SetText("Which alerts help you while you play?")
    w.mode = Kit.Select(w, { width = 220, menu = true, choices = modes, onPreview = function(_, value)
      Describe(w, value)
    end, onChange = function(_, value)
      A.SetMode(value); w:Refresh()
    end })
    w.mode:SetPoint("TOPLEFT", 24, -140)
    w.description = Theme.Text(w, "bodyLarge", "text")
    w.description:SetPoint("TOPLEFT", w.mode, "TOPRIGHT", 24, 0); w.description:SetPoint("TOPRIGHT", -24, -140)
    w.description:SetHeight(196); w.description:SetJustifyH("LEFT"); w.description:SetJustifyV("TOP"); w.description:SetWordWrap(true)
    if not ns.Modules then
      w.customize = Kit.Button(w, "Customize categories", 240, 30, { onClick = function()
        w.expanded = not w.expanded; w:Refresh()
      end })
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
      w.linkTitle:SetPoint("TOPLEFT"); w.linkTitle:SetText("Addon alerts")
      w.addonLinks = {}
      for _, owner in ipairs(alertOwners) do
        local name = ns.Modules.byKey[owner].name
        local button = Kit.Button(w.body, name, 170, 32, { onClick = function()
          ns.Hub.Open({ name = ns.Options.addonPages[owner].settings, params = { section = "alerts" } })
        end })
        Kit.Tooltip(button, function()
          return { name .. " alerts", ns.Modules.Active(owner) and "Open this addon's text and sound controls."
            or "Enable this addon in Addons, then reload to use its alert settings." }
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
        label:SetJustifyH("LEFT"); label:SetWordWrap(true); label:SetText(def.label)
        for _, channel in ipairs({ "text", "sound" }) do
          local key = channel
          row[key] = Kit.Toggle(w.body, key == "text" and "Text" or "Sound", { width = key == "text" and 90 or 104, onChange = function(_, on)
            local settings = A.Settings()
            settings.channels[def.key] = settings.channels[def.key] or {}
            settings.channels[def.key][key] = on
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
    w.done = Kit.Button(w, "Done", 220, 34, { tone = "accent", onClick = function()
      if ns.Onboarding and ns.Onboarding.active == "alerts" then return ns.Onboarding.Reviewed("alerts") end
      if ns.Hub then ns.Hub.Release(w) end
      w:Hide()
    end })
    w.done:SetPoint("BOTTOMRIGHT", -24, 20)
    function w:Refresh()
      local settings, mode = A.Settings(), A.Settings().mode or "everything"
      self.mode:SetValue(mode, true)
      Describe(self, mode)
      for _, row in ipairs(self.rows) do
        local v = settings.channels[row.key] or {}
        if row.text then row.text:SetChecked(v.text ~= false, true); row.sound:SetChecked(v.sound ~= false, true) end
      end
      local extra = 96 * math.max(0, ns.Core.FontScale() - 1)
      if self.addonLinks then
        self.body:SetPoint("TOPLEFT", 24, -332 - extra); self.body:SetPoint("TOPRIGHT", -24, -332 - extra)
        LayoutLinks(self)
        for owner, button in pairs(self.addonLinks) do button:SetEnabled(ns.Modules.Active(owner)) end
      else
        self.customize:SetText(self.expanded and "Hide category controls" or "Customize categories")
        self.scroll:SetShown(self.expanded == true)
        self.customize:SetPoint("TOPLEFT", 24, -332 - extra)
        self.scroll:SetPoint("TOPLEFT", 24, -378 - extra)
      end
      self:SetHeight((self.addonLinks and 580 or self.expanded and 620 or 460) + footer + extra)
      self.status:SetText((self.addonLinks or self.expanded) and "Your shared alert level also applies to each addon’s text and sound controls." or "You can change this any time.")
      self.done:SetText(ns.Onboarding and ns.Onboarding.active == "alerts" and "Use these alerts" or "Done")
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
