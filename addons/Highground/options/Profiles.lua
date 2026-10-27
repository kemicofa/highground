local _, ns = ...
local Core, Options, Theme, Kit = ns.Core, ns.Options, ns.Theme, ns.Kit
local Profiles = Options.Profiles
local S = Theme.Space

---------------------------------------------------------------------------
-- Profile actions: named profiles (HighgroundDB.profiles[name] = snapshot),
-- import and export, and the copy/paste window. The root page's profile
-- bar (options/Root.lua) calls these.
---------------------------------------------------------------------------

local function Refresh()
  if Options.panel.RefreshProfiles then Options.panel.RefreshProfiles() end
end

-- Validate and apply an exported string. true, message or false, error.
function Profiles.ImportText(text)
  local snap, err = Profiles.ParseString(text)
  if not snap then return false, err end
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
function Profiles.SaveImported(text, name)
  local snap, err = Profiles.ParseString(text)
  if not snap then return false, err end
  name = Profiles.CleanName(name) or snap.name
  if not name then return false, "enter a profile name" end
  local prepared, validation = Profiles.Prepare(snap)
  if not prepared then return false, validation end
  snap.name = nil
  Core.db.profiles = Core.db.profiles or {}
  Core.db.profiles[name] = snap
  Refresh()
  return true, "saved profile " .. name .. " (load it to apply)"
end

function Profiles.SaveProfile(name)
  Core.db.profiles = Core.db.profiles or {}
  Core.db.profiles[name] = Profiles.Snapshot()
end

function Profiles.LoadProfile(name)
  local snap = Core.db.profiles and Core.db.profiles[name]
  if not snap then return false end
  local prepared, err = Profiles.Prepare(snap)
  if not prepared then return false, err end
  Profiles.Apply(prepared)
  Core.db.activeProfile = name
  return true
end

-- true when a profile of that name existed.
function Profiles.DeleteProfile(name)
  if not (name and Core.db.profiles and Core.db.profiles[name]) then return false end
  Core.db.profiles[name] = nil
  if Core.db.activeProfile == name then Core.db.activeProfile = nil end
  return true
end

-- Copy/paste window, shared by export and import.
local share
local function Status(ok, msg)
  share:SetStatus(msg, ok and "success" or "error")
  if ok then ns.Util.Say(msg) end
end

share = Kit.CopyBox("HighgroundShare", {
  title = "PROFILE", width = 480, height = 300,
  buttons = {
    { key = "save", label = "Save as profile", width = 110,
      onClick = function(c) Status(Profiles.SaveImported(c:GetText(), c.name:GetText())) end },
    { key = "apply", label = "Apply", width = 80, tone = "accent",
      onClick = function(c) Status(Profiles.ImportText(c:GetText())) end },
  },
  -- Fill the name from a pasted export.
  onText = function(c, text)
    if c.mode ~= "import" or c.name:GetText() ~= "" then return end
    local snap = Profiles.ParseString(text)
    if snap and snap.name then c.name:SetText(snap.name) end
  end,
})
-- Name box in the footer, between Close and the actions.
share.name = Kit.Input(share, 120, "Name")
share.name:SetPoint("LEFT", share.done, "RIGHT", S("xl") + S("xl") + S("sm"), 0)
share.name.caption:ClearAllPoints()
share.name.caption:SetPoint("RIGHT", share.name, "LEFT", -S("sm"), 0)

local function Mode(mode)
  share.mode = mode
  local import = mode == "import"
  share.actions.apply:SetShown(import)
  share.actions.save:SetShown(import)
  share.name:SetShown(import)
  share.name.caption:SetShown(import)
end

-- Export a saved profile by name, or your current settings under that name.
function Profiles.ShowExport(name)
  name = Profiles.CleanName(name) or Core.db.activeProfile
  local saved = name and Core.db.profiles and Core.db.profiles[name]
  Mode("export")
  share.name:SetText(name or "")
  share:Open("EXPORT PROFILE" .. (name and (": " .. name:upper()) or ""),
    (saved and "Saved profile" or "Your current settings") .. ". Ctrl+C to copy; only changed values are included.",
    Profiles.ExportString(saved or Profiles.Snapshot(), name), true)
end

function Profiles.ShowImport()
  Mode("import")
  share.name:SetText("")
  share:Open("IMPORT PROFILE",
    "Paste a profile (Ctrl+V). Apply replaces your values; Save as profile keeps it.", "")
end

Profiles.share = share
