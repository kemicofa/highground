local _, ns = ...
local Core, Options, Theme, Kit = ns.Core, ns.Options, ns.Theme, ns.Kit
local p = Options.panel
local PAD = Theme.Space("xl")

local head = Theme.Text(p, "title", "titleText")
head:SetPoint("TOPLEFT", PAD, -PAD); head:SetText("PROFILES")
local hint = Theme.Text(p, "body", "textMuted")
hint:SetPoint("TOPLEFT", PAD, -62); hint:SetPoint("TOPRIGHT", -PAD, -62)
hint:SetHeight(54); hint:SetJustifyH("LEFT"); hint:SetWordWrap(true)
hint:SetText("Your active settings save automatically. Named profiles are separate copies you can update, load or share.")

-- Keep naming, saving and loading outside the scrolling sharing options.
-- A partially clipped Save button otherwise looks like an unexplained bar.
local scroll = Kit.ScrollArea(p)
p.profileScroll = scroll
scroll:SetPoint("TOPLEFT", 0, -392); scroll:SetPoint("BOTTOMRIGHT", -PAD, 16)
local body = scroll.body

Options.openHub = Kit.Button(p, "Open Highground", 150, 28, { onClick = function()
  if HideUIPanel and SettingsPanel then pcall(HideUIPanel, SettingsPanel) end
  if ns.Hub then ns.Hub.Open() end
end })
Options.openHub:SetPoint("TOPRIGHT", -PAD, -PAD)

local name = Kit.Input(p, 280, "Name your current setup")
name:SetPoint("TOPLEFT", PAD, -146)
p.profileName = name
p.profileButtons = {}
local function Name()
  return Options.Profiles.CleanName(name:GetText())
end
local function Status(text, failed)
  p.profileStatus:SetText(text or "")
  Theme.Paint(p.profileStatus, failed and "danger" or "success")
end
local function Button(key, label, width, parent, onClick, tone)
  local b = Kit.Button(parent or p, label, width, 32, { tone = tone, onClick = onClick })
  p.profileButtons[key] = b
  return b
end
local save = Button("Save", "Save profile", 200, p, function()
  local n = Name()
  if not n then return Status("Enter a name for this setup.", true) end
  Options.Profiles.SaveProfile(n)
  Core.db.activeProfile = n
  Core.db.importedProfileName = nil
  p.RefreshProfiles()
  p.savedProfiles:SetValue(n, true)
  Status("Saved “" .. n .. "”. This copy is available to your other characters.")
  if ns.Onboarding and ns.Onboarding.active == "profile" then ns.Onboarding.Reviewed("profile") end
end, "accent")
save:SetPoint("LEFT", name, "RIGHT", 16, 0)
p.profileStatus = Theme.Text(p, "body", "textMuted")
p.profileStatus:SetPoint("TOPLEFT", PAD, -190); p.profileStatus:SetPoint("TOPRIGHT", -PAD, -190)
p.profileStatus:SetHeight(48); p.profileStatus:SetJustifyH("LEFT"); p.profileStatus:SetWordWrap(true)

p.profileList = Theme.Text(p, "heading", "text")
p.profileList:SetPoint("TOPLEFT", PAD, -248)
p.savedProfiles = Kit.Select(p, { width = 280, menu = true, choices = {}, onChange = function()
  p.RefreshProfiles(); Status("")
end })
p.savedProfiles:SetPoint("TOPLEFT", PAD, -285)
local load = Button("Load", "Load profile", 200, p, function()
  local n = p.savedProfiles:GetValue()
  local ok, problem = Options.Profiles.LoadProfile(n)
  if ok then name:SetText(n) end
  p.RefreshProfiles()
  Status(ok and ("Loaded “" .. n .. "”" .. (Options.Profiles.pending and " · applies after combat." or "."))
    or problem or "Choose a saved profile.", not ok)
end)
load:SetPoint("LEFT", p.savedProfiles, "RIGHT", 16, 0)

p.more = Kit.Button(p, "Sharing and more options", 250, 30, { onClick = function()
  p.expanded = not p.expanded; p.RefreshProfiles()
  scroll:Scroll(0)
end })
p.more:SetPoint("TOPLEFT", PAD, -344)
p.advanced = body
p.shareInfo = Theme.Text(p.advanced, "body", "textMuted")
p.shareInfo:SetPoint("TOPLEFT", PAD, 0); p.shareInfo:SetPoint("TOPRIGHT", -PAD, 0)
p.shareInfo:SetJustifyH("LEFT"); p.shareInfo:SetJustifyV("TOP"); p.shareInfo:SetWordWrap(true)
local import = Button("Import", "Import profile", 160, p.advanced, function() Options.Profiles.ShowImport() end)
local export = Button("Export", "Export selected", 160, p.advanced, function()
  Options.Profiles.ShowExport(p.savedProfiles:GetValue())
end)
export:SetPoint("LEFT", import, "RIGHT", 12, 0)
local chat = Button("Chat", "Share in chat", 160, p.advanced, function()
  local ok, message = Options.Profiles.Chat.ToChat(p.savedProfiles:GetValue())
  Status(message, not ok)
  ns.Util.Say(message)
end)
chat:SetPoint("LEFT", export, "RIGHT", 12, 0)
local delete = Button("Delete", "Delete selected", 160, p.advanced, function()
  local n = p.savedProfiles:GetValue()
  if n and Options.Profiles.DeleteProfile(n) then
    p.RefreshProfiles(); Status("Deleted “" .. n .. "”. Your active settings are unchanged.")
  end
end)
Options.profileSwitching = Kit.Button(p.advanced, "Automatic switching", 220, 30, { onClick = function()
  Options.Profiles.OpenAssignments()
end })
Options.resetAll = Kit.Button(p.advanced, "Reset target tuning", 200, 30, { onClick = function()
  Core.ResetTuning(); Options.RefreshAllRows(); Options.PointsChanged()
  Status("Target tuning reset. Your features and panel positions are unchanged.")
end })
Options.resetAll:SetPoint("LEFT", Options.profileSwitching, "RIGHT", 12, 0)

function p.RefreshProfiles()
  scroll:Refresh()
  local choices = {}
  for n in Options.Profiles.SortedPairs(Core.db.profiles or {}) do choices[#choices + 1] = { key = n, label = n } end
  local selected = p.savedProfiles:GetValue()
  p.savedProfiles:SetChoices(choices)
  if selected and Core.db.profiles and Core.db.profiles[selected] then p.savedProfiles:SetValue(selected, true) end
  local hasProfiles = #choices > 0
  p.profileList:SetText(hasProfiles and "Load a saved setup" or "No named profiles yet · Save your setup above")
  p.savedProfiles:SetShown(hasProfiles); load:SetShown(hasProfiles)
  export:SetEnabled(hasProfiles); delete:SetEnabled(hasProfiles)
  scroll:SetShown(p.expanded == true)
  p.more:SetText(p.expanded and "Hide extra options" or "Sharing and more options")
  local selectedProfile = Core.db.profiles and Core.db.profiles[p.savedProfiles:GetValue()]
  local scope = selectedProfile and not selectedProfile.setup
    and "This older profile includes targeting scores, weights, specialization ratings and targeting behavior only."
    or Options.PROFILE_CONTENTS
  p.shareInfo:SetText(scope .. "\n" .. Options.PROFILE_EXCLUSIONS .. "\n\n"
    .. (hasProfiles and "Sharing sends the selected saved copy. Update that profile first to include later changes."
      or "Share in chat sends your current setup. Save a named copy above to reuse it later.")
    .. "\nChat links show your character/realm and the profile name.")
  local height = math.max(60, p.shareInfo:GetStringHeight() or 96) + 16
  import:SetPoint("TOPLEFT", PAD, -height)
  Options.profileSwitching:SetPoint("TOPLEFT", PAD, -height - 50)
  delete:SetPoint("TOPLEFT", PAD, -height - 100)
  body:SetHeight(height + 144)
  scroll:Refresh()
  local n = Name()
  save:SetText(n and Core.db.profiles and Core.db.profiles[n] and "Update profile" or "Save profile")
  if Options.openHub then Options.openHub:SetShown(not (ns.Hub and p:GetParent() == ns.Hub.content)) end
  if Options.Profiles.RefreshContext then Options.Profiles.RefreshContext() end
end
local function Layout()
  scroll:Refresh()
  if Core.db and Options.Profiles then p.RefreshProfiles() end
end
p:HookScript("OnSizeChanged", Layout)
p:HookScript("OnShow", function() Layout(); scroll:Scroll(0) end)
Core.OnFontScaleChange(Layout)
name:HookScript("OnTextChanged", function()
  if Core.db and p.RefreshProfiles then
    local n = Name()
    save:SetText(n and Core.db.profiles and Core.db.profiles[n] and "Update profile" or "Save profile")
  end
end)
