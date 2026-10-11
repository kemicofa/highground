local _, ns = ...
local Core, Options = ns.Core, ns.Options
local Profiles = Options.Profiles
local Snapshot, SortedPairs = Profiles.Snapshot, Profiles.SortedPairs

-- Copy/paste window (one for export and import).
local share = CreateFrame("Frame", "WarboardShare", UIParent, "BackdropTemplate")
share:SetSize(460, 240)
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
  sc:SetPoint("BOTTOMRIGHT", -32, 40)
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
  share.status = Core.Text(share, "medium", 11)
  share.status:SetPoint("BOTTOMLEFT", 12, 14)
  share.status:SetPoint("RIGHT", close, "LEFT", -8, 0)
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

local function ShowExport()
  share.title:SetText("EXPORT PROFILE")
  share.hint:SetText("Ctrl+C to copy. Only values you changed are included.")
  local text = Profiles.ExportString(Snapshot())
  share.box:SetText(text)
  share.apply:Hide()
  share.status:SetText("")
  share:Show()
  share.box:SetFocus()
  share.box:HighlightText()
end

local function ShowImport()
  share.title:SetText("IMPORT PROFILE")
  share.hint:SetText("Paste a WB1;... string (Ctrl+V), then Import. Replaces your current values.")
  share.box:SetText("")
  share.apply:SetText("Import")
  share.apply:Show()
  share.apply:SetScript("OnClick", function()
    local ok, msg = ImportText(share.box:GetText())
    share.status:SetText(ok and ("|cff4de673" .. msg .. "|r") or ("|cffff5555" .. msg .. "|r"))
    if ok then
      Say(msg)
    end
  end)
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
  export:SetPoint("TOPRIGHT", -16, -88)
  import:SetPoint("RIGHT", export, "LEFT", -4, 0)
  local list = p:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  list:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
  list:SetPoint("RIGHT", import, "LEFT", -10, 0)
  list:SetJustifyH("LEFT")
  list:SetWordWrap(false)

  p.RefreshProfiles = function()
    local names = {}
    for n in SortedPairs(Core.db.profiles or {}) do
      names[#names + 1] = n == Core.db.activeProfile and ("|cffffd100" .. n .. "|r") or n
    end
    list:SetText(#names > 0 and ("Saved: " .. table.concat(names, ", ")) or "No saved profiles yet")
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
  export:SetScript("OnClick", ShowExport)
end
Options.Profiles.ShowExport = ShowExport
Options.Profiles.ShowImport = ShowImport
Options.Profiles.ImportText = ImportText
Options.Profiles.SaveProfile = SaveProfile
Options.Profiles.LoadProfile = LoadProfile
Options.Profiles.SortedPairs = SortedPairs
