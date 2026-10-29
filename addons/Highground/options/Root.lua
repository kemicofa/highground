local _, ns = ...
local Core, Options, Theme, Kit = ns.Core, ns.Options, ns.Theme, ns.Kit
local S, Z = Theme.Space, Theme.Size

---------------------------------------------------------------------------
-- Root settings page (Options > AddOns > Highground, also the hub's Profiles
-- page): reset, Open Highground, the profile bar and the page list. Profile
-- actions live in options/Profiles.lua and are looked up per click.
---------------------------------------------------------------------------
local p = Options.panel
local PAD = S("xl")
local MAX_CHIPS = 6

local head = Theme.Text(p, "display", "titleText")
head:SetPoint("TOPLEFT", PAD, -PAD)
head:SetText("Highground")
local hint = Theme.Text(p, "body", "textMuted")
hint:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -S("sm"))
hint:SetPoint("RIGHT", -PAD, 0)
hint:SetJustifyH("LEFT")
hint:SetText("Profiles and target tuning. Turn features on or off on General; preview them and see every /hg command on Test and commands.")

Options.resetAll = Kit.Button(p, "Reset tuning", 110, nil, { onClick = function()
  Core.ResetTuning()
  Options.RefreshAllRows()
  Options.PointsChanged()
end })
Options.resetAll:SetPoint("TOPRIGHT", -PAD, -PAD)

-- The same settings, in Highground's own window (hub/Hub.lua).
Options.openHub = Kit.Button(p, "Open Highground", 130, nil, { tone = "accent", onClick = function()
  if HideUIPanel and SettingsPanel then pcall(HideUIPanel, SettingsPanel) end
  if ns.Hub then ns.Hub.Open() end
end })
Options.openHub:SetPoint("RIGHT", Options.resetAll, "LEFT", -S("md"), 0)

-- Profile bar: name box, actions, saved profiles as chips.
local name = Kit.Input(p, 140, "Profile")
name:SetPoint("TOPLEFT", PAD, -80)
p.profileName = name

local function Name()
  local n = ns.Util.Trim(name:GetText())
  return n ~= "" and n or nil
end

local Say = ns.Util.Say

local ACTIONS = {
  { "Save", 60, function()
    local n = Name()
    if not n then return end
    Options.Profiles.SaveProfile(n)
    Core.db.activeProfile = n
    Say("saved profile " .. n)
    p.RefreshProfiles()
  end },
  { "Load", 60, function()
    local n = Name()
    if not n then return end
    local ok, err = Options.Profiles.LoadProfile(n)
    Say(ok and ("loaded profile " .. n) or err or ("no profile named " .. n), not ok and "error" or nil)
    p.RefreshProfiles()
  end },
  { "Delete", 60, function()
    local n = Name()
    if n and Options.Profiles.DeleteProfile(n) then
      Say("deleted profile " .. n)
      name:SetText("")
      p.RefreshProfiles()
    end
  end },
  { "Import", 70, function() Options.Profiles.ShowImport() end, S("lg") },
  { "Export", 70, function() Options.Profiles.ShowExport(Name()) end },
}
local prev = name
p.profileButtons = {}
for _, def in ipairs(ACTIONS) do
  local b = Kit.Button(p, def[1], def[2], nil, { onClick = def[3] })
  b:SetPoint("LEFT", prev, "RIGHT", def[4] or S("sm"), 0)
  p.profileButtons[def[1]] = b
  prev = b
end

local list = Theme.Text(p, "body", "textMuted")
list:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -S("lg"))
list:SetJustifyH("LEFT")
p.profileList = list

-- Click a chip to put its name in the box; the active profile is gold.
p.profileChips = {}
for i = 1, MAX_CHIPS do
  local chip = Kit.Button(p, "", 80, Z("row"), { onClick = function(self) name:SetText(self.profile) end })
  chip:Hide()
  p.profileChips[i] = chip
end

function p.RefreshProfiles()
  local names = {}
  for n in Options.Profiles.SortedPairs(Core.db.profiles or {}) do names[#names + 1] = n end
  list:SetText(#names > 0 and "Saved:" or "No saved profiles yet")
  local last = list
  for i, chip in ipairs(p.profileChips) do
    local n = names[i]
    chip.profile = n
    if n then
      chip:SetText(n)
      Kit.Paint(chip, "surface", n == Core.db.activeProfile and "gold" or "text")
      chip:SetWidth(math.min(120, 20 + #n * 6))
      chip:ClearAllPoints()
      chip:SetPoint("LEFT", last, "RIGHT", last == list and S("md") or S("xs") + 1, 0)
      last = chip
    end
    chip:SetShown(n ~= nil)
  end
  if name:GetText() == "" and Core.db.activeProfile then name:SetText(Core.db.activeProfile) end
end

Options.pageList = Theme.Text(p, "bodyLarge")
Options.pageList:SetPoint("TOPLEFT", PAD, -150)
Options.pageList:SetPoint("RIGHT", -PAD, 0)
Options.pageList:SetJustifyH("LEFT")
Options.pageList:SetSpacing(S("sm"))
Options.pageList:SetText("Open General to turn features such as resurrection timers or the arena panel on or off, and to set panel scale and opacity. "
  .. (ns.Kits and "Open Cooldown tracking to choose spells, or another subpage to tune target priorities and alerts."
  or "Open another subpage to tune target priorities or resurrection alerts."))
