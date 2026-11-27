local _, ns = ...
local Core, Kit, Theme, Options, L = ns.Core, ns.Kit, ns.Theme, ns.Options, ns.Locale
local S = Theme.Space

-- Copy from…: fill one battleground size's layout from another character's
-- layout (optionally every size it has) or from a saved profile. Opened
-- from the Battleground sizes card; closing returns to it.
local copy

local function SizeLabel(bracket)
  for _, def in ipairs(Options.BATTLEGROUND_SIZES) do if def.key == bracket then return L:Get(def.label) end end
  return bracket
end

-- Choices: characters with a layout for this size, then saved profiles.
local function Sources(bracket)
  local Layouts, choices = Options.Profiles.Layouts, {}
  for _, entry in ipairs(Layouts.Characters()) do
    if Layouts.Get(bracket, entry.key) then
      choices[#choices + 1] = { key = "c:" .. entry.key, character = entry.key, name = entry.name,
        label = L:Format("battlegrounds.layouts.copy_character", { name = entry.name, class = ns.Util.ClassName(entry.class) or "" }) }
    end
  end
  Options.Profiles.EnsureDefault()
  for name in Options.Profiles.SortedPairs(Core.db.profiles or {}) do
    choices[#choices + 1] = { key = "p:" .. name, profile = name, name = name,
      label = L:Format("battlegrounds.layouts.copy_profile", { name = name }) }
  end
  return choices
end

local function Build()
  local w = Kit.Dialog("HighgroundLayoutCopy", { title = L:Get("battlegrounds.layouts.copy_title"), width = 460, height = 300,
    savedKey = "layoutCopy" })
  local c = w.content
  w.fromLabel = Theme.Text(c, "body", "text")
  w.fromLabel:SetPoint("TOPLEFT", 0, -S("sm")); w.fromLabel:SetJustifyH("LEFT")
  w.from = Kit.Select(c, { width = 300, menu = true, choices = {}, onChange = function() w:Refresh() end })
  w.from:SetPoint("TOPLEFT", w.fromLabel, "BOTTOMLEFT", 0, -S("xs")); w.from:SetPoint("RIGHT")
  w.all = Kit.Toggle(c, L:Get("battlegrounds.layouts.copy_all"), { desc = "", onChange = function() w:Refresh() end })
  w.all:SetPoint("TOPLEFT", w.from, "BOTTOMLEFT", 0, -S("md")); w.all:SetPoint("RIGHT")
  w.all.label:SetWordWrap(true); w.all.desc:SetWordWrap(true)
  w.warning = Kit.Paragraph(c, "body", "warning")
  w.warning:SetPoint("TOPLEFT", w.all, "BOTTOMLEFT", 0, -S("md")); w.warning:SetPoint("RIGHT")
  w.copy = Kit.Button(c, L:Get("battlegrounds.layouts.copy_action"), 140, 32, { tone = "accent", onClick = function() w:Copy() end })
  w.copy:SetPoint("BOTTOMRIGHT")
  w.cancel = Kit.Button(c, L:Get("battlegrounds.layouts.cancel"), 120, 32, { onClick = function() w:Hide() end })
  w.cancel:SetPoint("RIGHT", w.copy, "LEFT", -S("md"), 0)

  function w:Selected()
    local value = self.from:GetValue()
    for _, choice in ipairs(self.choices or {}) do if choice.key == value then return choice end end
  end
  function w:Refresh()
    local Layouts, bracket = Options.Profiles.Layouts, self.bracket
    local size = SizeLabel(bracket)
    self:SetTitle(L:Get("battlegrounds.layouts.copy_title"))
    self:SetSub(L:Format("battlegrounds.layouts.copy_into", { size = size, character = Options.CharacterName() }))
    self.fromLabel:SetText(L:Get("battlegrounds.layouts.copy_from"))
    local choice = self:Selected()
    local character = choice and choice.character
    self.all:SetShown(character ~= nil)
    if character then
      local sizes = {}
      for _, def in ipairs(Options.BATTLEGROUND_SIZES) do
        if Layouts.Get(def.key, character) then sizes[#sizes + 1] = L:Get(def.label) end
      end
      self.all.label:SetText(L:Get("battlegrounds.layouts.copy_all"))
      self.all.desc:SetText(L:Format("battlegrounds.layouts.copy_all_desc", { name = choice.name, sizes = L:List(sizes) }))
    end
    local replaces = Layouts.Get(bracket) ~= nil
    if character and self.all:GetChecked() then
      replaces = false
      for _, key in ipairs(Core.SIZE_KEYS) do
        if Layouts.Get(key, character) and Layouts.Get(key) then replaces = true end
      end
    end
    self.warning:SetText(replaces and L:Get(character and self.all:GetChecked() and "battlegrounds.layouts.copy_replaces_all"
      or "battlegrounds.layouts.copy_replaces") or "")
    self.copy:SetText(L:Get("battlegrounds.layouts.copy_action")); Kit.FitButton(self.copy, 120)
    self.cancel:SetText(L:Get("battlegrounds.layouts.cancel")); Kit.FitButton(self.cancel, 100)
    self.copy:SetEnabled(choice ~= nil)
    local height = 0
    for _, region in ipairs({ self.fromLabel, self.warning }) do height = height + region:GetStringHeight() end
    if self.all:IsShown() then
      self.all:SetHeight(math.ceil(self.all.label:GetStringHeight() + self.all.desc:GetStringHeight() + S("md")))
      height = height + self.all:GetHeight()
    end
    self:SetHeight(Theme.Size("header") + S("md") * 6 + height + self.from:GetHeight() + self.copy:GetHeight() + S("lg") * 2)
  end
  function w:Copy()
    local choice = self:Selected()
    if not choice then return end
    local size = SizeLabel(self.bracket)
    local count = Options.Profiles.Layouts.Copy(self.bracket, { character = choice.character, profile = choice.profile,
      all = choice.character and self.all:GetChecked() })
    if count > 0 then
      ns.Util.Say(L:Format(count > 1 and "battlegrounds.layouts.copied_all" or "battlegrounds.layouts.copied",
        { name = choice.name, size = size, count = count }))
    end
    self:Hide()
    if Options.RefreshFeatures then Options.RefreshFeatures() end
  end
  Kit.OnLocale(w, function(self) if self:IsShown() then self:Refresh() end end)
  return w
end

function Options.OpenLayoutCopy(bracket)
  copy = copy or Build()
  copy.bracket = bracket
  copy.choices = Sources(bracket)
  copy.from:SetChoices(copy.choices)
  copy.from:SetValue(copy.choices[1] and copy.choices[1].key or "", true)
  copy.all:SetChecked(false, true)
  copy:Refresh()
  Kit.Windows.Show(copy)
  return copy
end
