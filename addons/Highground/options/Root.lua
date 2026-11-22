local _, ns = ...
local Core, O, Theme, Kit, L = ns.Core, ns.Options, ns.Theme, ns.Kit, ns.Locale
local P, p = O.Profiles, O.panel
local PAD = Theme.Space("xl")
local function T(key, values) return values and L:Format("profiles.workspace." .. key, values) or L:Get("profiles.workspace." .. key) end
p.mode, p.profileRows, p.profileButtons = "browse", {}, {}
p.header = Kit.Header(p, { title = T("title"), titleRole = "title", padding = PAD })
p.header:SetPoint("TOPLEFT"); p.header:SetPoint("TOPRIGHT")
local Text = Kit.Paragraph
p.current = Text(p, "body", "text")
p.assignmentScroll = Kit.ScrollArea(p)
p.assignments = P.CreateAssignments(p)
p.assignments:SetParent(p.assignmentScroll.body)
p.profileList = Text(p, "heading")
p.listScroll = Kit.ScrollArea(p)
p.detail = CreateFrame("Frame", nil, p)
p.detailTitle = Text(p.detail, "heading")
p.detailHint = Text(p.detail, "body", "textMuted")
p.profileName = Kit.Input(p, 220, T("name")); p.profileName:SetMaxLetters(40)
p.source = Kit.Select(p, { label = T("source"), width = 180, menu = true, choices = {}, onChange = function()
  p.RefreshProfiles(); p.profileScroll:Scroll(0)
end })
p.reviewTitle = Text(p.detail, "body", "accent")
p.profileScroll = P.CreateComparison(p.detail)
p.defaultInfo = CreateFrame("Frame", nil, p.detail)
Theme.Fill(p.defaultInfo, "BACKGROUND", "surface"):SetAllPoints()
p.defaultInfo.title = Text(p.defaultInfo, "heading", "accent")
p.defaultInfo.title:SetPoint("TOPLEFT", 24, -24); p.defaultInfo.title:SetPoint("TOPRIGHT", -24, -24)
p.defaultInfo.body = Kit.ScrollText(p.defaultInfo, { role = "bodyLarge", bottomPadding = 8 })
p.defaultInfo.body:SetPoint("TOPLEFT", p.defaultInfo.title, "BOTTOMLEFT", 0, -16)
p.defaultInfo.body:SetPoint("BOTTOMRIGHT", -16, 16)
p.profileStatus = Text(p, "body", "textMuted")
-- Action rows size buttons to their labels, wrap when narrow, and grow for
-- labels that need two lines in longer translations.
p.footer = Kit.Toolbar(p, { height = 30, fitHeight = true })
p.actions = Kit.Toolbar(p.detail, { height = 30, rowGap = 6, fitHeight = true })
local function Status(text, failed)
  p.statusText = text or ""
  Kit.StatusText(p.profileStatus, p.statusText, failed and "danger" or nil)
end
local function WrapLabel(button)
  button.label:ClearAllPoints(); button.label:SetPoint("LEFT", 12, 0); button.label:SetPoint("RIGHT", -12, 0)
  button.label:SetWordWrap(true)
  return button
end
local function Button(key, label, parent, fn, tone)
  local button = WrapLabel(Kit.Button(parent, T(label), 140, 32, { tone = tone, onClick = fn }))
  p.profileButtons[key] = button
  return button
end
local function Selected() return Core.db.profiles and Core.db.profiles[p.selected] end
function p.SelectProfile(name)
  if not (Core.db.profiles and Core.db.profiles[name]) then return end
  p.example = nil
  p.selected, p.mode, p.showAll = name, "browse", false
  p.profileButtons.Delete:Disarm()
  p.profileName:SetText(name)
  Status(""); p.RefreshProfiles(); p.profileScroll:Scroll(0)
end
p.savedProfiles = { GetValue = function() return p.selected end,
  SetValue = function(_, name, silent) if silent then p.selected = name else p.SelectProfile(name) end end }
function p.NewProfile(copy)
  p.example = nil
  p.mode, p.showAll = "create", false
  p.profileButtons.Delete:Disarm()
  p.copySource = copy and p.selected or nil
  p.profileName:SetText(""); p.source.value = p.copySource and "copy" or "current"
  Status(""); p.RefreshProfiles(); p.profileScroll:Scroll(0); p.profileName:SetFocus()
end
local function Candidate()
  local source = p.source:GetValue()
  if source == "default" then return P.EnsureDefault()
  elseif source == "copy" then return Core.db.profiles[p.copySource]
  elseif source and source:match("^preset:") then return ns.Setup.ProfileSnapshot(source:sub(8)) end
  return P.Snapshot()
end
local function MarkGuide()
  if ns.Onboarding and ns.Onboarding.active == "profile" then
    if ns.Onboarding.exploring == "native" then ns.Onboarding.Mark("profile") else ns.Onboarding.Reviewed("profile") end
  end
end
Button("New", "new", p, function() p.NewProfile() end)
Button("Save", "replace", p.actions, function()
  if p.mode == "create" then
    local name = P.CleanName(p.profileName:GetText())
    if not name then return Status(T("name_required"), true) end
    if name == "Default" then return Status(L:Get("profiles.default.read_only"), true) end
    if Core.db.profiles[name] then return Status(T("name_exists"), true) end
    local snapshot = p.reviewCandidate
    if not snapshot then return Status(T("choose"), true) end
    local ok, err = P.SaveImported(P.ExportString(snapshot, name), name)
    if not ok then return Status(err, true) end
    p.selected, p.mode = name, "browse"
    P.LoadProfile(name)
    Status(T(P.pending and "created_pending" or "created", { name = name }))
  elseif p.mode == "replace" and p.selected ~= "Default" then
    local ok, err = P.SaveProfile(p.selected, p.reviewCandidate)
    if not ok then return Status(err, true) end
    Core.db.activeProfile, Core.db.importedProfileName = p.selected, nil
    p.mode = "browse"
    Status(T("saved", { name = p.selected }))
  else return Status(L:Get("profiles.default.read_only"), true) end
  p.RefreshProfiles(); MarkGuide()
end, "accent")
Button("Load", "apply", p.actions, function()
  local ok, err = P.LoadProfile(p.selected)
  if not ok then return Status(err or T("choose"), true) end
  Status(T(P.pending and "pending" or "applied", { name = p.selected }))
  p.RefreshProfiles()
end, "accent")
Button("Update", "update", p.actions, function()
  if p.selected == "Default" then return Status(L:Get("profiles.default.read_only"), true) end
  p.mode, p.showAll = "replace", false
  p.profileButtons.Delete:Disarm()
  Status(""); p.RefreshProfiles(); p.profileScroll:Scroll(0)
end)
Button("Copy", "duplicate", p.actions, function()
  if p.mode == "create" or p.mode == "replace" then p.SelectProfile(p.selected) else p.NewProfile(true) end
end)
Button("Details", "all", p.detail, function()
  p.showAll = not p.showAll; p.RefreshProfiles(); p.profileScroll:Scroll(0)
end)
for _, key in ipairs({ "Save", "Load", "Update", "Copy" }) do p.actions:Add(p.profileButtons[key]) end
p.footer:Add(Button("Import", "import", p.footer, function() P.ShowImport() end))
p.footer:Add(Button("Export", "export", p.footer, function() P.ShowExport(p.selected) end))
p.footer:Add(Button("Chat", "share", p.footer, function()
  local ok, message = P.Chat.ToChat(p.selected); Status(message, not ok)
end))
-- Deleting needs a second click; selecting another profile, changing mode,
-- leaving the page or hiding the button cancels the pending confirmation.
local deletePrompt
p.profileButtons.Delete = p.footer:Add(WrapLabel(Kit.ConfirmButton(p.footer, T("delete"), { confirm = T("confirm_delete"),
  -- A confirmation belongs to the profile it was armed for.
  subject = function() return p.selected end,
  onArm = function()
    deletePrompt = T("delete_confirm", { name = p.selected })
    Status(deletePrompt); p.LayoutProfiles()
  end,
  onDisarm = function()
    if p.statusText == deletePrompt then Status("") end
    deletePrompt = nil -- every disarming path refreshes or hides the page
  end,
  onConfirm = function()
    local name = p.selected
    if name == "Default" then return end
    local ok, err = P.DeleteProfile(name)
    if not ok then return Status(err, true) end
    p.selected = nil
    p.RefreshProfiles(); Status(T("deleted", { name = name }))
  end })))
O.openHub = Kit.Button(p, T("open"), 150, 28, { onClick = function()
  if HideUIPanel and SettingsPanel then pcall(HideUIPanel, SettingsPanel) end
  if ns.Hub then ns.Hub.Open() end
end })
p.header:SetActions({ O.openHub })

-- Saved profiles: a bounded window of recycled rows.
p.listView = Kit.VirtualList(p.listScroll, { gap = 6, inset = 2, max = 24,
  rowHeight = function() return Kit.Scale(24) + 24 end,
  create = function(body)
    local button = Kit.Button(body, "", 150, 48, { onClick = function(self) p.SelectProfile(self.profileName) end })
    button.label:ClearAllPoints(); button.label:SetPoint("TOPLEFT", 12, -9); button.label:SetPoint("RIGHT", -12, 0)
    button.label:SetJustifyH("LEFT"); button.label:SetWordWrap(false)
    button.note = Text(button, "body", "textMuted")
    button.note:SetPoint("TOPLEFT", button.label, "BOTTOMLEFT", 0, -4); button.note:SetPoint("RIGHT", -12, 0)
    button.note:SetWordWrap(false)
    Kit.Tooltip(button, function(self) return { { self.profileName or "", "text", true },
      { self.profileName == "Default" and L:Get("profiles.default.read_only") or T("selection_hint"), "textMuted", true } } end)
    return button
  end,
  render = function(button, choice)
    button.profileName = choice.key; button:SetText(choice.label)
    button.note:SetText(T(choice.key == "Default" and "read_only" or choice.key == Core.db.activeProfile
      and (p.activeState.modified and "applied_edited" or "applied_badge") or "saved_badge"))
    Kit.Paint(button, p.selected == choice.key and p.mode ~= "create" and "selected" or "surface")
  end })
p.profileRows = p.listView.rows

function p.LayoutProfiles()
  if p.layingOut then return end
  p.layingOut = true
  local scale = math.max(1, Core.FontScale())
  local width = math.max(520, p:GetWidth()) - PAD * 2
  local inset = p.profileContext and p.profileContext.inset or 0
  p.current:ClearAllPoints(); p.current:SetPoint("TOPLEFT", PAD + 160, -13)
  p.current:SetWidth(math.max(180, width - 160 - (O.openHub:IsShown() and 170 or 0)))
  p.current:SetHeight(p.current:GetStringHeight())
  local top = math.max(64, p.current:GetHeight() + 28)
  Kit.Place(p.footer, "BOTTOMLEFT", p, "BOTTOMLEFT", PAD, 12 + inset)
  p.footer:Layout(width)
  p.profileStatus:ClearAllPoints(); p.profileStatus:SetPoint("BOTTOMLEFT", p.footer, "TOPLEFT", 0, 8)
  p.profileStatus:SetWidth(width); p.profileStatus:SetHeight(math.max(22 * scale, p.profileStatus:GetStringHeight()))
  local bottom = 12 + inset + p.footer:GetHeight() + 8 + p.profileStatus:GetHeight() + 20
  local side = math.min(230, width * 0.34)
  p.profileButtons.New:SetWidth(side)
  p.profileButtons.New:SetHeight(math.max(32 * scale, p.profileButtons.New.label:GetStringHeight() + 12))
  p.assignments:ClearAllPoints(); p.assignments:SetPoint("TOPLEFT")
  p.assignments:SetWidth(side - 16); p.assignments:Layout(side - 16)
  local reserved = 30 * scale + 24 * scale + 30 + p.profileButtons.New:GetHeight() + 28
  local available = math.max(96, p:GetHeight() - top - bottom - reserved)
  p.assignmentScroll:ClearAllPoints(); p.assignmentScroll:SetPoint("BOTTOMLEFT", PAD, bottom)
  p.assignmentScroll:SetSize(side, math.min(available, p.assignments:GetHeight()))
  p.assignmentScroll.body:SetHeight(p.assignments:GetHeight()); p.assignmentScroll:Refresh()
  p.profileList:ClearAllPoints(); p.profileList:SetPoint("TOPLEFT", PAD, -top); p.profileList:SetWidth(side)
  p.profileButtons.New:ClearAllPoints(); p.profileButtons.New:SetPoint("BOTTOMLEFT", p.assignmentScroll, "TOPLEFT", 0, 18)
  p.listScroll:ClearAllPoints(); p.listScroll:SetPoint("TOPLEFT", PAD, -top - 30 * scale)
  p.listScroll:SetPoint("BOTTOMLEFT", p.profileButtons.New, "TOPLEFT", 0, 10); p.listScroll:SetWidth(side)
  p.detail:ClearAllPoints(); p.detail:SetPoint("TOPLEFT", PAD + side + 20, -top); p.detail:SetPoint("BOTTOMRIGHT", -PAD, bottom)
  local detailWidth = width - side - 20
  p.detailTitle:ClearAllPoints(); p.detailTitle:SetPoint("TOPLEFT"); p.detailTitle:SetWidth(detailWidth)
  p.detailTitle:SetHeight(p.detailTitle:GetStringHeight())
  p.detailHint:ClearAllPoints(); p.detailHint:SetPoint("TOPLEFT", p.detailTitle, "BOTTOMLEFT", 0, -6); p.detailHint:SetWidth(detailWidth)
  local editing = p.mode == "create" or p.mode == "replace"
  p.detailHint:SetShown(editing); p.detailHint:SetHeight(p.detailHint:GetStringHeight())
  local y = p.detailTitle:GetHeight() + (editing and 6 + p.detailHint:GetHeight() or 0) + 12
  local creating = p.mode == "create"
  p.profileName:SetShown(creating); p.profileName.caption:SetShown(creating)
  p.source:SetShown(creating); p.source.caption:SetShown(creating)
  if creating then
    y = y + 24 * scale
    p.profileName:ClearAllPoints(); p.profileName:SetPoint("TOPLEFT", p.detail, "TOPLEFT", 0, -y)
    p.profileName:SetWidth((detailWidth - 16) / 2); p.profileName:SetHeight(32)
    p.source:ClearAllPoints(); p.source:SetPoint("TOPLEFT", p.detail, "TOPLEFT", (detailWidth + 16) / 2, -y)
    p.source:SetWidth((detailWidth - 16) / 2); p.source:SetHeight(32)
    y = y + 32 + 12
  end
  Kit.Place(p.actions, "TOPLEFT", p.detail, "TOPLEFT", 0, -y)
  y = y + p.actions:Layout(detailWidth) + 16
  local details = p.profileButtons.Details
  details:ClearAllPoints(); details:SetPoint("TOPRIGHT", 0, -y); details:SetWidth(Kit.LabelWidth(details)); details:SetHeight(28 * scale)
  p.reviewTitle:ClearAllPoints(); p.reviewTitle:SetPoint("TOPLEFT", 0, -y - 4)
  p.reviewTitle:SetWidth(math.max(80, detailWidth - (details:IsShown() and details:GetWidth() + 12 or 0)))
  p.reviewTitle:SetHeight(math.max(28 * scale, p.reviewTitle:GetStringHeight()))
  y = y + math.max(28 * scale, p.reviewTitle:GetHeight()) + 10
  for _, area in ipairs({ p.profileScroll, p.defaultInfo }) do
    area:ClearAllPoints(); area:SetPoint("TOPLEFT", 0, -y); area:SetPoint("BOTTOMRIGHT")
  end
  p.profileList:SetText(T("saved_profiles"))
  p.profileButtons.New:SetEnabled(not creating)
  p.listView:SetItems(p.profileChoices); p.profileScroll:Refresh(); p.defaultInfo.body:Refresh()
  p.layingOut = nil
end

function p.RefreshProfiles(force)
  if not Core.db or p.refreshing or not (force or p:IsVisible()) then return end
  p.refreshing = true
  local baseline = P.EnsureDefault()
  local state = P.ActiveState and P.ActiveState() or {}
  p.activeState = state
  p.lastRevision, p.lastActive, p.lastPending = state.revision, Core.db.activeProfile, P.pending
  p.current:SetText((state.label or T("current")) .. " - " .. (state.status or T("automatic_save")))
  local before = p.selected
  p.selected = Core.db.profiles[p.selected] and p.selected or Core.db.activeProfile or "Default"
  if not Core.db.profiles[p.selected] then p.selected = "Default" end
  -- Removing or renaming the selection elsewhere (such as a command) cancels its pending delete.
  if p.selected ~= before then p.profileButtons.Delete:Disarm() end
  p.profileChoices = { { key = "Default", label = "Default" } }
  for name in P.SortedPairs(Core.db.profiles) do if name ~= "Default" then p.profileChoices[#p.profileChoices + 1] = { key = name, label = name } end end
  p.savedProfiles.choices = p.profileChoices
  p.assignments:Refresh()
  p.header.title:SetText(T("title"))
  p.profileName.caption:SetText(T("name")); p.source.caption:SetText(T("source"))
  for key, label in pairs({ New = "new", Update = "update", Import = "import", Export = "export", Chat = "share" }) do
    p.profileButtons[key]:SetText(T(label))
  end
  O.openHub:SetText(T("open"))
  local creating, replacing = p.mode == "create", p.mode == "replace"
  local readOnly = p.selected == "Default" and not creating and not p.example
  if readOnly then p.mode, replacing, p.showAll = "browse", false, false end
  local sources = { { key = "current", label = T("current") }, { key = "default", label = "Default" } }
  if p.copySource and Core.db.profiles[p.copySource] then sources[#sources + 1] = { key = "copy", label = p.copySource } end
  if ns.Setup then for _, key in ipairs({ "minimal", "damage", "healer", "carrier", "caller" }) do
    sources[#sources + 1] = { key = "preset:" .. key, label = T("preset", { name = ns.Setup.presets[key].label }) }
  end end
  p.source:SetChoices(sources)
  p.detailTitle:SetText(T(creating and "new_title" or replacing and "replace_title" or "profile_title", { name = p.selected }))
  p.detailHint:SetText(T(readOnly and "default_hint" or creating and "create_hint" or replacing and "replace_hint" or "browse_hint"))
  local candidate, problem
  if creating then candidate, problem = Candidate()
  elseif replacing then candidate = P.Snapshot()
  else candidate = Selected() end
  if p.example then candidate = p.example.after end
  p.reviewCandidate = (creating or replacing) and candidate or nil
  local changed
  if not readOnly and candidate then changed, problem = P.Review(candidate, baseline) end
  p.reviewRows = p.showAll and candidate and P.Review(candidate) or changed or {}
  p.reviewTitle:SetText(T(readOnly and "built_in" or p.showAll and "contents" or "changes", { count = #p.reviewRows }))
  p.profileScroll:SetShown(not readOnly); p.defaultInfo:SetShown(readOnly)
  p.profileScroll:SetRows(p.reviewRows, p.showAll, problem)
  p.defaultInfo.title:SetText(T("default_title")); p.defaultInfo.body:SetText(T("default_body"))
  p.profileButtons.Details:SetShown(not readOnly)
  p.profileButtons.Details:SetText(T(p.showAll and "differences" or "all"))
  p.profileButtons.Save:SetShown(creating or replacing); p.profileButtons.Save:SetText(T(creating and "create" or "replace"))
  p.profileButtons.Load:SetShown(not creating and not replacing); p.profileButtons.Load:SetText(T(readOnly and "restore" or "apply"))
  p.profileButtons.Update:SetShown(not readOnly and not creating and not replacing)
  p.profileButtons.Copy:SetText(T((creating or replacing) and "cancel" or "duplicate"))
  p.profileButtons.Save:SetEnabled(not problem and not p.example)
  p.profileButtons.Load:SetEnabled(not problem and not p.example)
  p.profileButtons.Update:SetEnabled(not problem and not p.example)
  p.profileButtons.Copy:SetEnabled(not p.example)
  p.profileButtons.Delete:SetShown(not readOnly and not creating and not replacing)
  p.profileButtons.Delete:SetEnabled(not p.example)
  p.profileButtons.Delete:SetLabels(T("delete"), T("confirm_delete"))
  if p.example then p.detailTitle:SetText(T("example")) end
  O.openHub:SetShown(not (ns.Hub and p:GetParent() == ns.Hub.content))
  p.LayoutProfiles(); p.refreshing = nil
  if P.RefreshContext then P.RefreshContext() end
end
function p.BeginReviewExample()
  p.SelectProfile(Core.db.activeProfile or "Default")
  -- Use an owned snapshot rather than modifying the immutable baseline.
  local after = P.ParseString(P.ExportString(P.EnsureDefault()))
  after.setup.features.sniper = not after.setup.features.sniper
  after.setup.alerts.mode = "objectives"
  after.setup.positions.point = { "TOPLEFT", "TOPLEFT", 44, -184 }
  p.example = { after = after }
  p.showAll = false; p.RefreshProfiles(); p.profileScroll:Scroll(0)
end
function p.EndReviewExample()
  if not p.example then return end
  p.example, p.showAll = nil, false; p.RefreshProfiles()
end
p:HookScript("OnSizeChanged", function() if Core.db and p:IsVisible() then p.LayoutProfiles() end end)
p:HookScript("OnShow", function() p.RefreshProfiles(true) end)
p:HookScript("OnHide", function() p.profileButtons.Delete:Disarm() end)
Core.OnFontScaleChange(function() if p:IsVisible() then p.LayoutProfiles() end end)
p.locale = { SetText = function() if p:IsVisible() then p.RefreshProfiles() end end }
ns.Localization.Bind(p.locale, "profiles.workspace.title")
local elapsed = 0
p:SetScript("OnUpdate", function(_, dt)
  if not p:IsVisible() or not P.ActiveState then return end
  elapsed = elapsed + dt
  if elapsed < 0.5 then return end
  elapsed = 0
  local state = P.ActiveState()
  if state.revision ~= p.lastRevision or Core.db.activeProfile ~= p.lastActive or P.pending ~= p.lastPending then p.RefreshProfiles() end
end)
