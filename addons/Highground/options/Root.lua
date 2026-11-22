local _, ns = ...
local Core, O, Theme, Kit = ns.Core, ns.Options, ns.Theme, ns.Kit
local P, p = O.Profiles, O.panel
local PAD = Theme.Space("xl")
p.mode, p.profileRows, p.profileButtons = "browse", {}, {}
p.header = Kit.Header(p, ns.Localization.Define({ title = ns.Locale:Get("highground.root.profiles.0aa762"), titleRole = "title", padding = PAD }, { title = "highground.root.profiles.0aa762" }))
p.header:SetPoint("TOPLEFT"); p.header:SetPoint("TOPRIGHT")
local function Text(parent, role, color)
  local t = Theme.Text(parent, role or "body", color or "text")
  t:SetJustifyH("LEFT"); t:SetJustifyV("TOP"); t:SetWordWrap(true)
  return t
end
p.hint = Text(p, "body", "textMuted")
ns.Localization.Bind(p.hint, "highground.root.settings_save_automatically_update_a_profile_to.7af66a")
p.current = Text(p, "body", "text")
p.assignments = P.CreateAssignments(p)
p.profileList = Text(p, "heading"); ns.Localization.Bind(p.profileList, "highground.root.saved_profiles.a41ba6")
p.listScroll = Kit.ScrollArea(p)
p.detail = CreateFrame("Frame", nil, p)
p.detailTitle = Text(p.detail, "heading")
p.detailTitle:SetPoint("TOPLEFT"); p.detailTitle:SetPoint("TOPRIGHT")
p.profileName = ns.Localization.BindWidget(Kit.Input(p, 220, ns.Locale:Get("highground.root.profile_name.775747")), { caption = "highground.root.profile_name.775747" })
p.profileName:SetMaxLetters(40)
p.source = Kit.Select(p, ns.Localization.Define({ label = ns.Locale:Get("highground.root.start_from.62a53f"), width = 180, menu = true, choices = {}, onChange = function()
  p.receipt = nil; p.RefreshProfiles(); p.profileScroll:Scroll(0)
end }, { label = "highground.root.start_from.62a53f" }))
p.reviewTitle = Text(p.detail, "body", "accent")
p.profileScroll = Kit.ScrollText(p.detail, { role = "body", color = "text", bottomPadding = 12 })
p.profileStatus = Text(p, "body", "textMuted")
p.footer = CreateFrame("Frame", nil, p)
p.actions = CreateFrame("Frame", nil, p.detail)
local function Status(text, failed)
  p.statusText = text or ""; p.profileStatus:SetText(p.statusText)
  Theme.Paint(p.profileStatus, failed and "danger" or "textMuted")
end
local function Button(key, label, parent, fn, tone)
  local b = ns.Localization.Bind(Kit.Button(parent, ns.Locale:Get(label), 140, 32, { tone = tone, onClick = fn }), label)
  p.profileButtons[key] = b
  return b
end
local function Selected() return Core.db.profiles and Core.db.profiles[p.selected] end
function p.SelectProfile(name)
  if not (Core.db.profiles and Core.db.profiles[name]) then return end
  p.example = nil
  p.selected, p.mode, p.receipt, p.showAll, p.deleteArmed = name, "browse", nil, nil, nil
  p.profileName:SetText(name)
  Status(""); p.RefreshProfiles(); p.profileScroll:Scroll(0)
end
-- Compatibility for context navigation and command-driven callers. The
-- player-facing picker is the visible, scrolling list below.
p.savedProfiles = { GetValue = function() return p.selected end,
  SetValue = function(_, name, silent)
    if silent then p.selected = name else p.SelectProfile(name) end
  end }
function p.NewProfile(copy)
  p.example = nil
  p.mode, p.receipt, p.showAll, p.deleteArmed = "create", nil, nil, nil
  p.copySource = copy and p.selected ~= Core.db.activeProfile and p.selected or nil
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
Button("New", "highground.root.new_profile.ca36da", p, function() p.NewProfile() end)
Button("Save", "highground.profiles.update_profile.837b6d", p.actions, function()
  if p.mode == "create" then
    local name = P.CleanName(p.profileName:GetText())
    if not name then return Status(ns.Locale:Get("highground.profilereview.enter_a_name_for_this_profile.b95770"), true) end
    if Core.db.profiles[name] then return Status(ns.Locale:Get("highground.root.that_name_already_exists_choose_another_name.0a4bd4"), true) end
    local snapshot, problem = Candidate()
    if not snapshot then return Status(problem, true) end
    -- Validate and take an owned copy, including a Default/copied source.
    local text = P.ExportString(snapshot, name)
    local ok, err = P.SaveImported(text, name)
    if not ok then return Status(err, true) end
    p.selected, p.mode, p.showAll = name, "browse", true
    p.receipt = { title = ns.Locale:Get("highground.settings.created_everything_included.d7a8f1"), rows = P.Review(Core.db.profiles[name]) }
    P.LoadProfile(name)
    Status(ns.Locale:Format("highground.root.created_name_value4.fc643a", { name = name, value4 = (P.pending and ns.Locale:Get("highground.root.applies_after_combat.028bb0") or ns.Locale:Get("highground.root.this_profile_is_now_in_use.7e46cb")) }))
  else
    if not p.selected or (p.selected ~= Core.db.activeProfile and p.mode ~= "replace") then return Status(ns.Locale:Get("highground.root.choose_update_from_current_to_review_this.404a7a"), true) end
    local snapshot = P.Snapshot()
    local rows, problem = P.Review(snapshot, Selected())
    if not rows then return Status(problem, true) end
    P.SaveProfile(p.selected, snapshot)
    Core.db.activeProfile, Core.db.importedProfileName = p.selected, nil
    p.mode = "browse"
    p.receipt = { title = ns.Locale:Format("highground.settings.saved_value2_changes.503761", { value2 = #rows }), rows = rows }
    p.showAll = false
    Status(ns.Locale:Format("highground.root.updated_p_selected_the_changes_are_listed.11bcd0", { p_selected = p.selected }))
  end
  p.RefreshProfiles(); MarkGuide()
end, "accent")
local function UseSelected()
  local rows, problem = P.Review(Selected(), P.Snapshot())
  if not rows then return Status(problem, true) end
  local name = p.selected
  local ok, err = P.LoadProfile(name)
  if not ok then return Status(err or ns.Locale:Get("highground.settings.choose_a_saved_profile.5c404b"), true) end
  p.receipt = { title = ns.Locale:Format("highground.profilereview.value1_value3_changes.fbba38", { value1 = (P.pending and ns.Locale:Get("highground.profilecontext.after_combat.09bba6") or ns.Locale:Get("highground.profiles.applied.a3e4a5")), value3 = #rows }), rows = rows }
  p.showAll = false
  Status(P.pending and (ns.Locale:Format("highground.root.name_will_apply_after_combat.1aa438", { name = name })) or (ns.Locale:Format("highground.root.name_is_now_in_use.1ef599", { name = name })))
  p.RefreshProfiles()
end
Button("Load", "highground.root.use_profile.0643ee", p.actions, UseSelected, "accent")
Button("Copy", "highground.root.save_as_new.ae54c1", p.actions, function()
  if p.mode == "create" or p.mode == "replace" then p.SelectProfile(p.selected) else p.NewProfile(true) end
end)
Button("Update", "highground.root.update_from_current.7c1e8a", p, function()
  if p.selected == Core.db.activeProfile then return UseSelected() end
  p.mode, p.receipt, p.showAll = "replace", nil, false
  Status(ns.Locale:Format("highground.root.review_how_your_current_settings_will_replace.ca2803", { p_selected = p.selected }))
  p.RefreshProfiles(); p.profileScroll:Scroll(0)
end)
p.profileButtons.Update.label:SetWordWrap(true)
p.profileButtons.Update.label:SetPoint("LEFT", 8, 0); p.profileButtons.Update.label:SetPoint("RIGHT", -8, 0)
Button("Details", "highground.profilereview.all_settings.0f803e", p.detail, function() p.showAll = not p.showAll; p.RefreshProfiles(); p.profileScroll:Scroll(0) end)
Button("Import", "highground.root.import.d6fbc9", p.footer, function() P.ShowImport() end)
Button("Export", "highground.root.export.f3e4fa", p.footer, function() P.ShowExport(p.selected) end)
Button("Chat", "highground.profiles.share_in_chat.1d5c1d", p.footer, function()
  local ok, message = P.Chat.ToChat(p.selected); Status(message, not ok)
end)
Button("Delete", "highground.root.delete.f6fdbe", p.footer, function()
  if p.deleteArmed ~= p.selected then
    p.deleteArmed = p.selected
    Status(ns.Locale:Format("highground.root.delete_p_selected_click_confirm_delete_current.5dfa2d", { p_selected = p.selected }))
    ns.Localization.Bind(p.profileButtons.Delete, "highground.root.confirm_delete.c9f282"); p.LayoutProfiles(); return
  end
  local name = p.selected
  local ok, err = P.DeleteProfile(name)
  if not ok then return Status(err, true) end
  p.selected, p.deleteArmed, p.receipt = nil, nil, nil
  p.RefreshProfiles(); Status(ns.Locale:Format("highground.root.deleted_name_current_settings_are_kept.bb4142", { name = name }))
end)
O.openHub = ns.Localization.Bind(Kit.Button(p, ns.Locale:Get("highground.root.open_highground.1fa4b1"), 150, 28, { onClick = function()
  if HideUIPanel and SettingsPanel then pcall(HideUIPanel, SettingsPanel) end
  if ns.Hub then ns.Hub.Open() end
end }), "highground.root.open_highground.1fa4b1")
p.header:SetActions({ O.openHub })

local function ListRows()
  local scroll = p.listScroll
  local h = 38 * math.max(1, Core.FontScale())
  local start = math.floor(scroll.offset / h)
  local count = math.min(24, math.max(1, math.ceil(scroll:GetHeight() / h) + 1))
  for i = 1, count do
    local button = p.profileRows[i]
    if not button then
      button = Kit.Button(scroll.body, "", 150, h, { onClick = function(self) p.SelectProfile(self.profileName) end })
      button.label:ClearAllPoints(); button.label:SetPoint("LEFT", 10, 0); button.label:SetPoint("RIGHT", -10, 0)
      button.label:SetJustifyH("LEFT"); button.label:SetWordWrap(false)
      Kit.Tooltip(button, function(self) return { { self.profileName or "", "text", true },
        { self.profileName == Core.db.activeProfile and ns.Locale:Get("highground.root.in_use.20716e") or self.profileName == "Default" and ns.Locale:Get("highground.root.your_starting_setup.bfa851") or ns.Locale:Get("highground.root.select_to_review_this_saved_copy.faf740"), "textMuted", true } } end)
      p.profileRows[i] = button
    end
    local choice = p.profileChoices and p.profileChoices[start + i]
    button:SetShown(choice ~= nil)
    if choice then
      button.profileName = choice.key
      button:SetText(choice.key .. (choice.key == Core.db.activeProfile and ns.Locale:Get("highground.root.in_use.834f5b") or ""))
      button:ClearAllPoints(); button:SetPoint("TOPLEFT", 0, -(start + i - 1) * h); button:SetPoint("RIGHT", -2, 0)
      button:SetHeight(h - 4)
      Kit.Paint(button, p.selected == choice.key and p.mode ~= "create" and "selected" or "surface")
    end
  end
  for i = count + 1, #p.profileRows do p.profileRows[i]:Hide() end
end
p.listScroll.onScroll = ListRows

function p.LayoutProfiles()
  if p.layingOut then return end
  p.layingOut = true
  local scale = math.max(1, Core.FontScale())
  local width = math.max(520, p:GetWidth()) - PAD * 2
  local inset = p.profileContext and p.profileContext.inset or 0
  local actionBottom = 32 + 60 * scale
  p.current:ClearAllPoints(); p.current:SetPoint("TOPLEFT", PAD, -58); p.current:SetWidth(width)
  p.current:SetHeight(p.current:GetStringHeight())
  p.hint:ClearAllPoints(); p.hint:SetPoint("TOPLEFT", p.current, "BOTTOMLEFT", 0, -4); p.hint:SetWidth(width)
  p.hint:SetHeight(p.hint:GetStringHeight())
  p.assignments:ClearAllPoints(); p.assignments:SetPoint("TOPLEFT", p.hint, "BOTTOMLEFT", 0, -12)
  p.assignments:SetWidth(width); p.assignments:Layout(width)
  local top = 58 + p.current:GetHeight() + 4 + p.hint:GetHeight() + 12 + p.assignments:GetHeight() + 18
  local side = math.min(180, width * 0.26)
  p.profileList:ClearAllPoints(); p.profileList:SetPoint("TOPLEFT", PAD, -top); p.profileList:SetWidth(side)
  p.listScroll:ClearAllPoints(); p.listScroll:SetPoint("TOPLEFT", PAD, -top - 28 * scale)
  p.listScroll:SetPoint("BOTTOMLEFT", PAD, 176 + (p.profileButtons.Update:IsShown() and 52 * scale or 0) + inset); p.listScroll:SetWidth(side)
  p.profileButtons.New:ClearAllPoints(); p.profileButtons.New:SetPoint("TOPLEFT", p.listScroll, "BOTTOMLEFT", 0, -8)
  p.profileButtons.New:SetWidth(side); p.profileButtons.New:SetHeight(30 * scale)
  p.profileButtons.Update:ClearAllPoints(); p.profileButtons.Update:SetPoint("TOPLEFT", p.profileButtons.New, "BOTTOMLEFT", 0, -8)
  p.profileButtons.Update:SetWidth(side); p.profileButtons.Update:SetHeight(44 * scale)
  p.detail:ClearAllPoints(); p.detail:SetPoint("TOPLEFT", PAD + side + 16, -top)
  p.detail:SetPoint("BOTTOMRIGHT", -PAD, 0)
  local detailWidth = width - side - 16
  local y = math.max(22 * scale, p.detailTitle:GetStringHeight()) + 8
  local creating = p.mode == "create"
  p.listScroll:SetShown(not creating); p.profileButtons.New:SetShown(not creating)
  p.profileList:SetText(creating and ns.Locale:Get("highground.root.new_profile.ca36da") or ns.Locale:Get("highground.root.saved_profiles.a41ba6"))
  p.profileName:SetShown(creating); p.profileName.caption:SetShown(creating)
  p.source:SetShown(creating); p.source.caption:SetShown(creating)
  if creating then
    p.profileName:ClearAllPoints(); p.profileName:SetPoint("TOPLEFT", PAD, -top - 54 * scale)
    p.profileName:SetWidth(side); p.profileName:SetHeight(28 * scale)
    p.source:ClearAllPoints(); p.source:SetPoint("TOPLEFT", p.profileName, "BOTTOMLEFT", 0, -34 * scale)
    p.source:SetWidth(side); p.source:SetHeight(28 * scale)
  end
  local details = p.profileButtons.Details
  details:ClearAllPoints(); details:SetPoint("TOPRIGHT", 0, -y); details:SetWidth(details.label:GetStringWidth() + 16)
  details:SetHeight(28 * scale)
  p.reviewTitle:ClearAllPoints(); p.reviewTitle:SetPoint("TOPLEFT", 0, -y - 4)
  p.reviewTitle:SetPoint("RIGHT", details, "LEFT", -10, 0); p.reviewTitle:SetHeight(math.max(28, 22 * scale))
  p.profileScroll:ClearAllPoints(); p.profileScroll:SetPoint("TOPLEFT", 0, -y - math.max(28, 22 * scale) - 10)
  p.profileScroll:SetPoint("BOTTOMRIGHT", 0, actionBottom + 32 * scale + 10 + inset)
  p.actions:ClearAllPoints(); p.actions:SetPoint("BOTTOMLEFT", 0, actionBottom + inset)
  p.actions:SetPoint("BOTTOMRIGHT", 0, actionBottom + inset); p.actions:SetHeight(32 * scale)
  local primary = p.profileButtons.Save:IsShown() and p.profileButtons.Save or p.profileButtons.Load
  primary:ClearAllPoints(); primary:SetPoint("LEFT"); primary:SetHeight(32 * scale)
  primary:SetWidth(math.min(detailWidth * 0.6, primary.label:GetStringWidth() + 28))
  local copy = p.profileButtons.Copy
  copy:ClearAllPoints(); copy:SetPoint("LEFT", primary, "RIGHT", 10, 0); copy:SetHeight(32 * scale)
  copy:SetWidth(math.min(detailWidth - primary:GetWidth() - 10, copy.label:GetStringWidth() + 28))
  p.profileStatus:ClearAllPoints(); p.profileStatus:SetPoint("BOTTOMLEFT", PAD, 20 + 30 * scale + inset)
  p.profileStatus:SetWidth(width); p.profileStatus:SetHeight(30 * scale)
  p.footer:ClearAllPoints(); p.footer:SetPoint("BOTTOMLEFT", PAD, 12 + inset); p.footer:SetWidth(width); p.footer:SetHeight(30 * scale)
  local x = 0
  for _, key in ipairs({ "Import", "Export", "Chat", "Delete" }) do
    local b = p.profileButtons[key]
    b:ClearAllPoints(); b:SetPoint("LEFT", x, 0); b:SetWidth(b.label:GetStringWidth() + 24); b:SetHeight(30 * scale)
    x = x + b:GetWidth() + 8
  end
  p.listScroll.body:SetHeight(math.max(1, #(p.profileChoices or {}) * 38 * scale))
  p.listScroll:Refresh(); p.profileScroll:Refresh()
  p.layingOut = nil
end

function p.RefreshProfiles(force)
  if not Core.db or p.refreshing or not (force or p:IsVisible()) then return end
  p.refreshing = true
  P.EnsureDefault()
  local state = P.ActiveState and P.ActiveState() or {}
  p.lastRevision, p.lastActive, p.lastPending = state.revision, Core.db.activeProfile, P.pending
  p.current:SetText((state.label or ns.Locale:Get("highground.profilecontext.current_settings.fbbfb4")) .. " · " .. (state.status or ns.Locale:Get("highground.profilecontext.saved_automatically.5bee9c")))
  p.selected = Core.db.profiles[p.selected] and p.selected or Core.db.activeProfile or "Default"
  if not Core.db.profiles[p.selected] then p.selected = "Default" end
  p.profileChoices = {}
  for name in P.SortedPairs(Core.db.profiles) do p.profileChoices[#p.profileChoices + 1] = { key = name, label = name } end
  p.savedProfiles.choices = p.profileChoices
  p.assignments:Refresh()
  local creating, active = p.mode == "create", p.selected == Core.db.activeProfile or p.mode == "replace"
  local sources = { { key = "current", label = ns.Locale:Get("highground.profilecontext.current_settings.fbbfb4") }, { key = "default", label = ns.Locale:Get("highground.appearance.default.808d7d") } }
  if p.copySource and Core.db.profiles[p.copySource] then sources[#sources + 1] = { key = "copy", label = p.copySource } end
  if ns.Setup then for _, key in ipairs({ "minimal", "damage", "healer", "carrier", "caller" }) do
    sources[#sources + 1] = { key = "preset:" .. key, label = ns.Locale:Format("highground.root.value1_preset.9d02cc", { value1 = ns.Setup.presets[key].label }) }
  end end
  p.source:SetChoices(sources)
  p.detailTitle:SetText(creating and ns.Locale:Get("highground.root.new_profile.ca36da") or p.selected)
  local current = P.Snapshot()
  local full, changed, problem
  if creating then
    local candidate, err = Candidate()
    if candidate then full, problem = P.Review(candidate) else problem = err end
  else
    changed, problem = P.Review(active and current or Selected(), active and Selected() or current)
    if p.showAll or (changed and #changed == 0 and not p.receipt) then full, problem = P.Review(active and current or Selected()) end
  end
  p.reviewRows = full or (p.receipt and not p.showAll and p.receipt.rows) or changed or {}
  p.reviewTitle:SetText(problem and ns.Locale:Get("highground.root.cannot_review_profile.4e9b91") or (p.receipt and not p.showAll and p.receipt.title)
    or (full and (creating and ns.Locale:Get("highground.profilereview.everything_included.6adb07") or ns.Locale:Get("highground.profilereview.profile_contents.8fe675")))
    or (#p.reviewRows .. (active and ns.Locale:Get("highground.root.changes_to_save.d23b8a") or ns.Locale:Get("highground.root.changes_to_apply.a321f7"))))
  p.profileScroll:SetText(problem or P.ReviewText(p.reviewRows) .. (full and ("\n\n" .. O.PROFILE_EXCLUSIONS) or ""))
  p.profileButtons.Details:SetShown(not creating)
  p.profileButtons.Details:SetText(p.showAll and ns.Locale:Get("highground.root.show_changes.130b03") or ns.Locale:Get("highground.profilereview.all_settings.0f803e"))
  p.profileButtons.Save:SetShown(creating or active); p.profileButtons.Load:SetShown(not creating and not active)
  p.profileButtons.Save:SetText(creating and ns.Locale:Get("highground.root.create_and_use_profile.5bcf0b") or ns.Locale:Get("highground.profiles.update_profile.837b6d"))
  p.profileButtons.Save:SetEnabled(not problem and (creating or changed and #changed > 0))
  p.profileButtons.Load:SetEnabled(not problem)
  p.profileButtons.Copy:SetText((creating or p.mode == "replace") and ns.Locale:Get("highground.root.cancel.77dfd2") or active and ns.Locale:Get("highground.root.save_as_new.ae54c1") or ns.Locale:Get("highground.root.create_a_copy.86250f"))
  p.profileButtons.Update:SetShown(not creating and p.mode ~= "replace" and (not active or changed and #changed > 0))
  p.profileButtons.Update:SetText(active and ns.Locale:Get("highground.root.use_saved_copy.1b2407") or ns.Locale:Get("highground.root.update_from_current.7c1e8a"))
  p.profileButtons.Delete:SetEnabled(not creating and p.selected ~= "Default")
  p.profileButtons.Delete:SetText(p.deleteArmed == p.selected and ns.Locale:Get("highground.root.confirm_delete.c9f282") or ns.Locale:Get("highground.root.delete.f6fdbe"))
  if p.example then
    ns.Localization.Bind(p.detailTitle, "highground.root.example_profile.79fb41")
    p.reviewRows = p.showAll and P.Review(p.example.after) or p.example.rows
    p.reviewTitle:SetText(p.showAll and ns.Locale:Get("highground.root.example_contents.2db730") or (ns.Locale:Format("highground.root.example_value2_changes.33c8fc", { value2 = #p.example.rows })))
    p.profileScroll:SetText(P.ReviewText(p.reviewRows))
    for _, key in ipairs({ "Save", "Load", "Copy", "Update", "Delete" }) do p.profileButtons[key]:SetEnabled(false) end
  else p.profileButtons.Copy:SetEnabled(true); p.profileButtons.Update:SetEnabled(true) end
  O.openHub:SetShown(not (ns.Hub and p:GetParent() == ns.Hub.content))
  p.LayoutProfiles()
  p.refreshing = nil
  if P.RefreshContext then P.RefreshContext() end
end
function p.BeginReviewExample()
  p.SelectProfile(Core.db.activeProfile or "Default")
  local before, after = P.Snapshot(), P.Snapshot()
  after.setup.features.sniper = not after.setup.features.sniper
  after.setup.alerts.mode = after.setup.alerts.mode == "objectives" and "essential" or "objectives"
  after.setup.style.fontScale = after.setup.style.fontScale == 1.1 and 1 or 1.1
  p.example = { after = after, rows = P.Review(after, before) }
  p.showAll = false; p.RefreshProfiles(); p.profileScroll:Scroll(0)
end
function p.EndReviewExample()
  if not p.example then return end
  p.example, p.showAll = nil, false; p.RefreshProfiles()
end
p:HookScript("OnSizeChanged", function() if Core.db and p:IsVisible() then p.LayoutProfiles() end end)
p:HookScript("OnShow", function() p.RefreshProfiles(true) end)
Core.OnFontScaleChange(function() if p:IsVisible() then p.LayoutProfiles() end end)
local elapsed = 0
p:SetScript("OnUpdate", function(_, dt)
  if not p:IsVisible() or not P.ActiveState then return end
  elapsed = elapsed + dt
  if elapsed < 0.5 then return end
  elapsed = 0
  local state = P.ActiveState()
  if state.revision ~= p.lastRevision or Core.db.activeProfile ~= p.lastActive or P.pending ~= p.lastPending then
    if p.receipt then p.showAll = false end
    p.receipt = nil; p.RefreshProfiles()
  end
end)
