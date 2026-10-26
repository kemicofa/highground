local _, ns = ...
local Core, Options = ns.Core, ns.Options
local Profiles = Options.Profiles
local Snapshot, SortedPairs = Profiles.Snapshot, Profiles.SortedPairs

-- Copy/paste window (one for export and import).
local share = CreateFrame("Frame", "WarboardShare", UIParent, "BackdropTemplate")
share:SetSize(460, 276)
share:SetPoint("CENTER")
share:SetFrameStrata("DIALOG")
share:SetBackdrop({ bgFile = Core.WHITE, edgeFile = Core.WHITE, edgeSize = 1 })
share:SetBackdropColor(Core.INK[1], Core.INK[2], Core.INK[3], 0.97)
share:SetBackdropBorderColor(Core.ACCENT[1], Core.ACCENT[2], Core.ACCENT[3], 0.8)
share:EnableMouse(true)
share:SetMovable(true)
share:RegisterForDrag("LeftButton")
share:SetScript("OnDragStart", share.StartMoving)
share:SetScript("OnDragStop", share.StopMovingOrSizing)
share:Hide()
tinsert(UISpecialFrames, "WarboardShare") -- Escape closes it
do
  share.title = Core.Text(share, "bold", 14)
  share.title:SetPoint("TOPLEFT", 12, -10)
  share.hint = Core.Text(share, "medium", 11)
  share.hint:SetPoint("TOPLEFT", share.title, "BOTTOMLEFT", 0, -3)
  share.hint:SetPoint("RIGHT", -12, 0)
  share.hint:SetJustifyH("LEFT")
  share.hint:SetTextColor(Core.MUTED[1], Core.MUTED[2], Core.MUTED[3])
  local sc = CreateFrame("ScrollFrame", "WarboardShareScroll", share, "UIPanelScrollFrameTemplate")
  sc:SetPoint("TOPLEFT", 12, -48)
  sc:SetPoint("BOTTOMRIGHT", -32, 76)
  local bg = Core.Fill(share, "BACKGROUND", 1, 1, 1, 0.05)
  bg:SetPoint("TOPLEFT", sc, -4, 4)
  bg:SetPoint("BOTTOMRIGHT", sc, 24, -4)
  share.box = CreateFrame("EditBox", nil, sc)
  share.box:SetMultiLine(true)
  share.box:SetAutoFocus(false)
  share.box:SetFontObject(ChatFontNormal)
  share.box:SetWidth(400)
  share.box:SetScript("OnEscapePressed", function()
    share:Hide()
  end)
  sc:SetScrollChild(share.box)
  share.apply = CreateFrame("Button", nil, share, "UIPanelButtonTemplate")
  share.apply:SetSize(110, 22)
  share.apply:SetPoint("BOTTOMRIGHT", -12, 10)
  local close = CreateFrame("Button", nil, share, "UIPanelButtonTemplate")
  close:SetSize(80, 22)
  close:SetPoint("RIGHT", share.apply, "LEFT", -6, 0)
  close:SetText("Close")
  close:SetScript("OnClick", function()
    share:Hide()
  end)
  share.save = CreateFrame("Button", nil, share, "UIPanelButtonTemplate")
  share.save:SetSize(120, 22)
  share.save:SetPoint("RIGHT", share.apply, "LEFT", -4, 0)
  share.save:SetText("Save as profile")
  close:ClearAllPoints()
  close:SetPoint("BOTTOMLEFT", 12, 10)
  share.nameLabel = Core.Text(share, "medium", 11)
  share.nameLabel:SetPoint("BOTTOMLEFT", 12, 48)
  share.nameLabel:SetText("Profile name")
  share.name = CreateFrame("EditBox", nil, share, "InputBoxTemplate")
  share.name:SetSize(180, 20)
  share.name:SetPoint("LEFT", share.nameLabel, "RIGHT", 10, 0)
  share.name:SetAutoFocus(false)
  share.status = Core.Text(share, "medium", 11)
  share.status:SetPoint("LEFT", share.name, "RIGHT", 10, 0)
  share.status:SetPoint("RIGHT", -12, 0)
  share.status:SetJustifyH("LEFT")
end

local function Say(msg)
  print("|cffff5533Warboard|r " .. msg)
end

local function ImportText(text)
  local snap, err = Profiles.ParseString(text)
  if not snap then
    return false, err
  end
  local prepared, validation, count, skipped = Profiles.Prepare(snap)
  if not prepared then return false, validation end
  Profiles.Apply(prepared)
  local msg = string.format("imported %d values", count)
  if skipped > 0 then
    msg = msg .. string.format(" (%d unsupported or retired values skipped)", skipped)
  end
  return true, msg
end

-- Validate, then keep it as a named profile without applying it.
local function SaveImported(text, name)
  local snap, err = Profiles.ParseString(text)
  if not snap then return false, err end
  name = Profiles.CleanName(name) or snap.name
  if not name then return false, "enter a profile name" end
  local prepared, validation = Profiles.Prepare(snap)
  if not prepared then return false, validation end
  snap.name = nil
  Core.db.profiles = Core.db.profiles or {}
  Core.db.profiles[name] = snap
  if Options.panel.RefreshProfiles then Options.panel.RefreshProfiles() end
  return true, "saved profile " .. name .. " (load it to apply)"
end

local function Status(ok, msg)
  share.status:SetText(ok and ("|cff4de673" .. msg .. "|r") or ("|cffff5555" .. msg .. "|r"))
  if ok then Say(msg) end
end

-- Export a saved profile by name, or your current settings under that name.
local function ShowExport(name)
  name = Profiles.CleanName(name) or Core.db.activeProfile
  local saved = name and Core.db.profiles and Core.db.profiles[name]
  share.title:SetText("EXPORT PROFILE" .. (name and (": " .. name:upper()) or ""))
  share.hint:SetText((saved and "Saved profile" or "Your current settings") .. ". Ctrl+C to copy; only changed values are included.")
  local text = Profiles.ExportString(saved or Snapshot(), name)
  share.box:SetText(text)
  share.apply:Hide()
  share.save:Hide()
  share.name:SetText(name or "")
  share.status:SetText("")
  share:Show()
  share.box:SetFocus()
  share.box:HighlightText()
end

local function ShowImport()
  share.title:SetText("IMPORT PROFILE")
  share.hint:SetText("Paste an exported profile (Ctrl+V). Apply replaces your current values; Save as profile keeps it for later.")
  share.box:SetText("")
  share.name:SetText("")
  share.box:SetScript("OnTextChanged", function(self)
    local snap = Profiles.ParseString(self:GetText())
    if snap and snap.name and share.name:GetText() == "" then share.name:SetText(snap.name) end
  end)
  share.apply:SetText("Apply")
  share.apply:Show()
  share.apply:SetScript("OnClick", function() Status(ImportText(share.box:GetText())) end)
  share.save:Show()
  share.save:SetScript("OnClick", function() Status(SaveImported(share.box:GetText(), share.name:GetText())) end)
  share.status:SetText("")
  share:Show()
  share.box:SetFocus()
end

-- Named profiles (WarboardDB.profiles[name] = snapshot).
local function SaveProfile(name)
  Core.db.profiles = Core.db.profiles or {}
  Core.db.profiles[name] = Snapshot()
end

local function LoadProfile(name)
  local snap = Core.db.profiles and Core.db.profiles[name]
  if not snap then
    return false
  end
  local prepared, err = Profiles.Prepare(snap)
  if not prepared then return false, err end
  Profiles.Apply(prepared)
  Core.db.activeProfile = name
  return true
end

-- Profile bar on the options page.
do
  local p = Options.panel
  local function Btn(text, w)
    local b = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    b:SetSize(w or 70, 22)
    b:SetText(text)
    return b
  end
  local label = p:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  label:SetPoint("TOPLEFT", 16, -62)
  label:SetText("Profile")
  local name = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
  name:SetSize(120, 20)
  name:SetPoint("LEFT", label, "RIGHT", 12, 0)
  name:SetAutoFocus(false)
  local save, load, del = Btn("Save"), Btn("Load"), Btn("Delete")
  save:SetPoint("LEFT", name, "RIGHT", 6, 0)
  load:SetPoint("LEFT", save, "RIGHT", 4, 0)
  del:SetPoint("LEFT", load, "RIGHT", 4, 0)
  local import, export = Btn("Import", 80), Btn("Export", 80)
  import:SetPoint("LEFT", del, "RIGHT", 16, 0)
  export:SetPoint("LEFT", import, "RIGHT", 4, 0)
  local list = p:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  list:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
  list:SetJustifyH("LEFT")
  -- Saved profiles as buttons: click one to put its name in the box.
  p.profileChips = {}
  local MAX_CHIPS = 6
  for i = 1, MAX_CHIPS do
    local chip = Btn("", 80)
    chip:SetHeight(18)
    chip:SetScript("OnClick", function(self) name:SetText(self.profile) end)
    chip:Hide()
    p.profileChips[i] = chip
  end

  p.RefreshProfiles = function()
    local names = {}
    for n in SortedPairs(Core.db.profiles or {}) do names[#names + 1] = n end
    list:SetText(#names > 0 and "Saved:" or "No saved profiles yet")
    local prev = list
    for i, chip in ipairs(p.profileChips) do
      local n = names[i]
      chip.profile = n
      if n then
        chip:SetText(n == Core.db.activeProfile and ("|cffffd100" .. n .. "|r") or n)
        chip:SetWidth(math.min(120, 20 + #n * 6))
        chip:ClearAllPoints()
        chip:SetPoint("LEFT", prev, "RIGHT", prev == list and 6 or 3, 0)
        prev = chip
      end
      chip:SetShown(n ~= nil)
    end
    if name:GetText() == "" and Core.db.activeProfile then
      name:SetText(Core.db.activeProfile)
    end
  end
  local function Name()
    local n = (name:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
    return n ~= "" and n or nil
  end
  save:SetScript("OnClick", function()
    local n = Name()
    if n then
      SaveProfile(n)
      Core.db.activeProfile = n
      Say("saved profile " .. n)
      p.RefreshProfiles()
    end
  end)
  load:SetScript("OnClick", function()
    local n = Name()
    if n then
      local ok, err = LoadProfile(n)
      Say(ok and ("loaded profile " .. n) or err or ("no profile named " .. n))
    end
  end)
  del:SetScript("OnClick", function()
    local n = Name()
    if n and Core.db.profiles and Core.db.profiles[n] then
      Core.db.profiles[n] = nil
      if Core.db.activeProfile == n then
        Core.db.activeProfile = nil
      end
      Say("deleted profile " .. n)
      name:SetText("")
      p.RefreshProfiles()
    end
  end)
  import:SetScript("OnClick", ShowImport)
  export:SetScript("OnClick", function() ShowExport(Name()) end)
end
Options.Profiles.ShowExport = ShowExport
Options.Profiles.ShowImport = ShowImport
Options.Profiles.ImportText = ImportText
Options.Profiles.SaveImported = SaveImported
Options.Profiles.share = share
Options.Profiles.SaveProfile = SaveProfile
Options.Profiles.LoadProfile = LoadProfile
Options.Profiles.SortedPairs = SortedPairs
