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

local defaultOwner
local function Preserve(name, base)
  local db = Core.db
  if not db.profiles[name] then return end
  local renamed, suffix = base, 2
  while db.profiles[renamed] do renamed = base .. " (" .. suffix .. ")"; suffix = suffix + 1 end
  db.profiles[renamed], db.profiles[name] = db.profiles[name], nil
  if db.activeProfile == name then db.activeProfile = renamed end
  for _, assignments in pairs(type(db.profileAssignments) == "table" and db.profileAssignments or {}) do
    for context, assigned in pairs(type(assignments) == "table" and assignments or {}) do
      if assigned == name then assignments[context] = renamed end
    end
  end
  return renamed
end

-- Old Default entries were editable snapshots. Preserve them and their
-- references, then install the built-in baseline once per loaded database.
function Profiles.MigrateDefault()
  local db = Core.db
  if not db or defaultOwner == db and db.profileDefaultVersion == 2 and db.profiles and db.profiles.Default then return end
  ns.Saved.Table(db, "profiles")
  if db.profileDefaultVersion ~= 2 then
    Profiles.previousDefault = Preserve("Default", "Previous Default")
    Preserve("Before role preset", "Previous setup")
  end
  db.profiles.Default = Profiles.DefaultSnapshot()
  db.profileDefaultVersion, defaultOwner = 2, db
end

function Profiles.EnsureDefault()
  Profiles.MigrateDefault()
  return Core.db.profiles.Default
end

ns.Util.Events({ PLAYER_LOGIN = Profiles.MigrateDefault }, "profile default migration")

-- Validate and apply an exported string. true, message or false, error.
function Profiles.ImportText(text)
  local snap, err = Profiles.ParseString(text)
  if not snap then return false, err end
  local prepared, validation, count, skipped = Profiles.Prepare(snap)
  if not prepared then return false, validation end
  prepared.importedProfileName = snap.name or "Imported setup"
  Profiles.Apply(prepared)
  local msg = prepared.setup and string.format("imported full setup (%d tuning values)", count) or string.format("imported %d values", count)
  if Profiles.pending then msg = msg .. "; applies after combat" end
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
  if name == "Default" then return false, ns.Locale:Get("profiles.default.read_only") end
  local prepared, validation = Profiles.Prepare(snap)
  if not prepared then return false, validation end
  snap.name = nil
  Core.db.profiles = Core.db.profiles or {}
  Core.db.profiles[name] = snap
  Refresh()
  return true, "saved profile " .. name .. " (load it to apply)"
end

function Profiles.SaveProfile(name, snapshot)
  name = Profiles.CleanName(name)
  if not name then return false, ns.Locale:Get("profiles.workspace.name_required") end
  if name == "Default" then return false, ns.Locale:Get("profiles.default.read_only") end
  Core.db.profiles = Core.db.profiles or {}
  Core.db.profiles[name] = snapshot or Profiles.Snapshot()
  return true
end

function Profiles.LoadProfile(name)
  Profiles.EnsureDefault()
  local snap = Core.db.profiles and Core.db.profiles[name]
  if not snap then return false end
  local prepared, err = Profiles.Prepare(snap)
  if not prepared then return false, err end
  prepared.profileName = name
  Profiles.Apply(prepared)
  return true
end

-- true when a profile of that name existed.
function Profiles.DeleteProfile(name)
  if not (name and Core.db.profiles and Core.db.profiles[name]) then return false end
  if name == "Default" then return false, ns.Locale:Get("profiles.default.read_only") end
  Core.db.profiles[name] = nil
  if Core.db.activeProfile == name then Core.db.activeProfile = nil end
  if Profiles.pending and Profiles.pending.profileName == name then Profiles.pending = nil end
  for _, assignments in pairs(type(Core.db.profileAssignments) == "table" and Core.db.profileAssignments or {}) do
    for context, assigned in pairs(type(assignments) == "table" and assignments or {}) do
      if assigned == name then assignments[context] = nil end
    end
  end
  return true
end

-- Copy/paste window, shared by export and import.
local share
local function ReviewAction(c, save)
  local snap = Profiles.ParseString(c:GetText())
  local rows = snap and Profiles.Review(snap, Profiles.EnsureDefault())
  local ok, message
  if save then ok, message = Profiles.SaveImported(c:GetText(), c.name:GetText())
  else ok, message = Profiles.ImportText(c:GetText()) end
  if ok and rows then
    Profiles.SetReviewText(c.review, { ns.Locale:Format("profiles.workspace.changes", { count = #rows }), rows }, true)
  end
  c:SetStatus(message, ok and "success" or "error")
  return ok
end
share = Kit.CopyBox("HighgroundShare", {
  title = "PROFILE", width = 760, height = 660, below = 300,
  buttons = {
    { key = "save", label = "Save as profile", width = 110,
      onClick = function(c) ReviewAction(c, true) end },
    { key = "apply", label = "Apply", width = 80, tone = "accent",
      onClick = function(c) ReviewAction(c, false) end },
  },
  -- Fill the name from a pasted export.
  onText = function(c, text)
    if c.mode ~= "import" then return end
    local snap = Profiles.ParseString(text)
    if snap and snap.name and c.name:GetText() == "" then c.name:SetText(snap.name) end
    if Profiles.UpdateImportReview then Profiles.UpdateImportReview() end
  end,
})
-- Name box in the footer, between Close and the actions.
share.name = Kit.Input(share, 120, "Name")
share.name:SetPoint("LEFT", share.done, "RIGHT", S("xl") + S("xl") + S("sm"), 0)
share.name.caption:ClearAllPoints()
share.name.caption:SetPoint("RIGHT", share.name, "LEFT", -S("sm"), 0)
share.exportSource = Kit.Select(share, { width = 300, menu = true, choices = {}, onChange = function(_, source)
  if source == "current" then Profiles.ShowExport(false) else Profiles.ShowExport(source:sub(9)) end
end })
share.exportSource:SetPoint("LEFT", share.done, "RIGHT", 16, 0)
share.chat = Kit.Button(share, "Share in chat", 180, 32, { onClick = function()
  local ok, message = Profiles.Chat.ToChat(share.exportName)
  share:SetStatus(message, ok and "success" or "error")
end })
share.chat:SetPoint("BOTTOMRIGHT", -S("xl"), S("xl"))
share.review = Kit.ScrollText(share.below, { role = "body", bottomPadding = 8 })
share.review:SetAllPoints()
function share:LayoutProfileShare()
  if not Core.db or self.layingOut then return end
  self.layingOut = true
  local scale, pad = math.max(1, Core.FontScale()), S("lg")
  local bottom = pad + (self.profileContext and self.profileContext.inset or 0)
  local height = 30 * scale
  for _, b in ipairs({ self.done, self.chat, self.actions.save, self.actions.apply }) do
    b:SetWidth(b.label:GetStringWidth() + 24); b:SetHeight(height)
  end
  self.done:ClearAllPoints(); self.done:SetPoint("BOTTOMLEFT", pad, bottom)
  self.chat:ClearAllPoints(); self.chat:SetPoint("BOTTOMRIGHT", -pad, bottom)
  self.actions.apply:ClearAllPoints(); self.actions.apply:SetPoint("BOTTOMRIGHT", -pad, bottom)
  self.name:ClearAllPoints(); self.name:SetPoint("LEFT", self.done, "RIGHT", self.name.caption:GetStringWidth() + 24, 0)
  self.name:SetWidth(math.max(100, self:GetWidth() - pad * 2 - self.done:GetWidth() - self.name.caption:GetStringWidth()
    - self.actions.save:GetWidth() - self.actions.apply:GetWidth() - 56))
  self.name:SetHeight(height)
  self.exportSource:ClearAllPoints(); self.exportSource:SetPoint("LEFT", self.done, "RIGHT", 16, 0)
  self.exportSource:SetPoint("RIGHT", self.chat, "LEFT", -16, 0); self.exportSource:SetHeight(height)
  self.status:ClearAllPoints(); self.status:SetPoint("BOTTOMLEFT", pad, bottom + height + 8)
  self.status:SetPoint("RIGHT", -pad, 0); self.status:SetHeight(32 * scale)
  self.status:SetWordWrap(true); self.status:SetJustifyV("BOTTOM")
  self.hint:SetHeight(self.hint:GetStringHeight())
  self.well:ClearAllPoints(); self.well:SetPoint("TOPLEFT", self.hint, "BOTTOMLEFT", 0, -8)
  self.well:SetPoint("BOTTOMRIGHT", -pad, bottom + height + 16 + 32 * scale)
  local reviewHeight = math.min(300, math.max(80, self.well:GetHeight() * 0.6))
  self.scroll:SetPoint("BOTTOMRIGHT", self.well, "BOTTOMRIGHT", -S("xl") - S("md"), self.mode == "import" and reviewHeight + 8 or S("sm"))
  self.below:SetHeight(reviewHeight)
  self.review:Refresh()
  self.layingOut = nil
end
function Profiles.UpdateImportReview()
  if share.mode ~= "import" then return end
  local snap, problem = Profiles.ParseString(share:GetText())
  local name = Profiles.CleanName(share.name:GetText()) or snap and snap.name
  local previous = name and Core.db.profiles and Core.db.profiles[name]
  local rows, err
  if snap then rows, err = Profiles.Review(snap, Profiles.EnsureDefault()) end
  local sections = rows and { ns.Locale:Format("profiles.workspace.changes", { count = #rows }), rows }
    or { err or problem }
  if rows then
    if name == "Default" then sections[#sections + 1] = ns.Locale:Get("profiles.default.read_only") end
    sections[#sections + 1] = Options.PROFILE_EXCLUSIONS
  end
  Profiles.SetReviewText(share.review, sections, true); share.review:Scroll(0)
  share.actions.save:SetText(previous and "Update profile" or "Save as profile")
  share.actions.save:SetEnabled(rows ~= nil and name ~= "Default")
  share:LayoutProfileShare()
end
share.name:HookScript("OnTextChanged", function() if share.review then Profiles.UpdateImportReview() end end)
share:HookScript("OnShow", function() share:LayoutProfileShare() end)
share:HookScript("OnSizeChanged", function() share:LayoutProfileShare() end)
Core.OnFontScaleChange(function() if share:IsVisible() then share:LayoutProfileShare() end end)

local function Mode(mode)
  share.mode = mode
  local import = mode == "import"
  share.actions.apply:SetShown(import)
  share.actions.save:SetShown(import)
  share.name:SetShown(import)
  share.name.caption:SetShown(import)
  share.exportSource:SetShown(not import); share.chat:SetShown(not import)
  share.below:SetShown(import)
  share:SetHeight(import and 660 or 380)
  share:LayoutProfileShare()
end

-- Export a saved profile by name, or your current settings under that name.
function Profiles.ShowExport(name)
  local current = name == false
  name = not current and (Profiles.CleanName(name) or Core.db.activeProfile) or nil
  local saved = name and Core.db.profiles and Core.db.profiles[name]
  Mode("export")
  share.exportName = saved and name or nil
  local choices = { { key = "current", label = "Current settings" } }
  for key in Profiles.SortedPairs(Core.db.profiles or {}) do choices[#choices + 1] = { key = "profile:" .. key, label = "Saved: " .. key } end
  share.exportSource:SetChoices(choices)
  share.exportSource:SetValue(saved and ("profile:" .. name) or "current", true)
  share.name:SetText(name or "")
  share:Open("EXPORT PROFILE" .. (name and (": " .. name:upper()) or ""),
    (saved and "Saved profile" or "Your current setup") .. ". Ctrl+C to copy and share with another character.",
    Profiles.ExportString(saved or Profiles.Snapshot(), name), true)
  share:LayoutProfileShare()
end

function Profiles.ShowImport()
  Mode("import")
  share.name:SetText("")
  share:Open("IMPORT PROFILE",
    "Paste a profile (Ctrl+V). Apply replaces your values; Save as profile keeps it.", "")
  share:LayoutProfileShare()
end

Profiles.share = share
