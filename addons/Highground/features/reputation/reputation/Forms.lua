local _, ns = ...
local W, K, T = ns.Reputation, ns.Kit, ns.Theme
W.UI = { mode = "organizations", page = 1 }
local UI = W.UI
-- Report form choice that saves in every enabled organization.
local ALL = "*all"
W.ALL = ALL

-- A positioned Kit.Paragraph; callers that need one line turn wrapping off.
function UI.Label(parent, text, x, y, width, color)
  local label = K.Paragraph(parent, "body", color or "textMuted")
  label:SetPoint("TOPLEFT", x, y)
  label:SetWidth(width)
  label:SetText(text)
  return label
end

function UI.Dialog(key, title, width, height, preview)
  return K.Dialog((ns.FRAME_PREFIX or "Highground") .. "Reputation" .. key .. (preview and "Preview" or ""),
    { title = title, width = width, height = height, savedKey = not preview and "reputation" .. key or nil, child = key ~= "Window",
      stage = key == "Window" and K.STAGES.reputation or nil })
end

function UI.Result(frame, value, err, source)
  local UI = (source or W).UI
  if not value then frame.status:SetText(err or ns.Locale:Get("reputation.forms.the_action_could_not_be_completed.8b4f40")); return end
  frame:Hide()
  if UI.Refresh then UI.Refresh() end
end

function UI.CommunityChoices(source, all)
  local W = source or W
  local O = W.organizations or ns.Organizations
  local choices, counts, ids = {}, {}, {}
  for _, c in ipairs(all and O.List() or W.List()) do
    local org = O.Get(c.id)
    if org then
      local label = (org.kind == "guild" and ns.Locale:Get("reputation.forms.guild.13426b") or ns.Locale:Get("reputation.forms.community.36e41c")) .. org.name
      choices[#choices + 1] = { key = c.id, label = label }
      counts[label], ids[c.id] = (counts[label] or 0) + 1, org.clubId or org.id
    end
  end
  -- Native IDs keep identically named communities distinguishable without
  -- changing the identity used to submit a report or select its audience.
  for _, choice in ipairs(choices) do
    if counts[choice.label] > 1 then choice.label = choice.label .. " (#" .. tostring(ids[choice.key]) .. ")" end
  end
  return choices
end

function W.OpenOrganizations()
  UI.SetMode("organizations")
  return W.Open()
end

function W.OpenNative(c)
  local ok, err = ns.Organizations.Open(c and c.id)
  if not ok then W.Say(err or ns.Locale:Get("reputation.forms.open_guild_communities_from_the_game_s.c9f37a")) end
end

-- Organization choices for the report form, plus "all" with two or more
-- enabled organizations (or when it is already selected).
local function ReportChoices(W, keepAll)
  local choices = W.UI.CommunityChoices(nil, true)
  if keepAll or #W.List() > 1 then
    choices[#choices + 1] = { key = ALL, label = ns.Locale:Get("reputation.forms.all_enabled_guilds_and_communities.e28b4b") }
  end
  return choices
end

local function FitReport(f)
  f:SetHeight(math.max(560, T.Size("header") + T.Space("md") + 310 + f.hint:GetStringHeight() + 152))
end

local function AllRole(f, W)
  local moderator, ready = false, false
  for _, c in ipairs(W.List()) do
    local mod = W.CanModerate(c)
    moderator = moderator or mod
    ready = ready or W.Role(c) ~= nil and (not mod or c.synced == true)
  end
  f:SetTitle(moderator and ns.Locale:Get("reputation.forms.blacklist_player.562890") or ns.Locale:Get("reputation.forms.report_player.af5122"))
  f.submit:SetText(ns.Locale:Get("reputation.forms.save_in_all.3d9d70"))
  f.submit:SetEnabled(ready)
  f.resume:Hide()
  f.hint:SetText(ns.Locale:Get("reputation.forms.blacklists_the_player_where_you_moderate_and.06998a"))
  T.Paint(f.hint, "textMuted")
  FitReport(f)
end

-- A decision where you moderate, a proposal elsewhere. Saves what it can and
-- names each organization that refused.
local function SaveAll(f, W, player, categories, note)
  local UI = W.UI
  if not ns.Reputation.Categories(categories) then return UI.Result(f, nil, ns.Locale:Get("highground.coachrecords.choose_at_least_one_category.2d9bda")) end
  local saved, failed = {}, {}
  for _, c in ipairs(W.List()) do
    local result, err
    if W.CanModerate(c) then result, err = W.Decide(c, player, "ban", categories, note)
    else result, err = W.Submit(c, player, categories, note) end
    if result then saved[#saved + 1] = W.Name(c)
    else failed[#failed + 1] = ns.Locale:Format("reputation.forms.not_saved_in_organization_error.325aa6", { organization = W.Name(c), error = tostring(err) }) end
  end
  if #saved == 0 then return UI.Result(f, nil, failed[1] and table.concat(failed, "\n")) end
  UI.Result(f, true)
  W.Say(ns.Locale:Format("reputation.forms.saved_in_organizations.f69e35", { organizations = ns.Locale:List(saved) }))
  for _, line in ipairs(failed) do W.Say(line) end
end

local function ReportRole(f, source)
  local W = source or W
  if f.community:GetValue() == ALL then return AllRole(f, W) end
  local c = W.Get(f.community:GetValue())
  local role, mod = W.Role(c), W.CanModerate(c)
  local state = c and W.Availability(c.id)
  f:SetTitle(mod and ns.Locale:Get("reputation.forms.blacklist_player.562890") or ns.Locale:Get("reputation.forms.report_player.af5122"))
  f.submit:SetText(mod and ns.Locale:Get("reputation.forms.save_blacklist_decision.decce9") or state and state.ready and ns.Locale:Get("reputation.forms.submit_proposal.0dde28") or ns.Locale:Get("reputation.forms.queue_proposal.87d747"))
  f.submit:SetEnabled(role ~= nil and (not mod or c.synced == true))
  local paused = c and c.enabled == false
  f.resume:SetShown(paused); f.resume:SetEnabled(paused and (W.organizations or ns.Organizations).Get(c.id) ~= nil)
  f.hint:SetText(paused and ns.Locale:Get("reputation.forms.reputation_is_off_on_this_account_use.12e4f1")
    or not W.Joined(c) and ns.Locale:Get("reputation.forms.this_organization_is_unavailable_your_draft_is.e4142d")
    or not role and ns.Locale:Get("reputation.forms.waiting_for_your_organization_role_your_draft.6e614a")
    or mod and not c.synced and ns.Locale:Get("reputation.forms.waiting_for_moderation_decisions_to_finish_syncing.628d43")
    or mod and ns.Locale:Get("reputation.forms.your_approved_categories_and_explanation_are_shared.1a20fb")
    or state and state.message or ns.Locale:Get("reputation.forms.choose_a_guild_or_community_for_this.67f55b"))
  T.Paint(f.hint, state and state.tone or "textMuted")
  FitReport(f)
end

-- Roster and presence events must not interrupt an editor. Refresh access
-- without changing its audience or discarding the entered name and notes.
function UI.RefreshDialogs(source)
  local W = source or W
  local UI = W.UI
  local f = UI.report
  if f and f:IsVisible() then
    local id, previous = f.community:GetValue()
    for _, choice in ipairs(f.community.choices) do if choice.key == id then previous = choice end end
    local choices, found = ReportChoices(W, id == ALL), false
    for _, choice in ipairs(choices) do if choice.key == id then found = true end end
    if previous and not found then table.insert(choices, 1, previous) end
    f.community:SetChoices(choices); f.community:SetValue(id, true)
    ReportRole(f, W)
  end
  f = UI.reason
  if f and f.community then
    local allowed = W.CanModerate(f.community)
    f.submit:SetEnabled(allowed)
    if not allowed then ns.Localization.Bind(f.status, "reputation.forms.moderator_access_is_unavailable_your_draft_is.65554f")
    elseif f.accessUnavailable then f.status:SetText("") end
    f.accessUnavailable = not allowed
  end
  f = UI.details
  if f and f.community and (not W.Joined(f.community) or f.moderator and not W.CanModerate(f.community)) then
    -- A suspended history window must not reveal private notes on return.
    f:Clear()
    K.Windows.Close(f)
  end
end

function UI.CloseDialogs(source)
  local UI = (source or W).UI
  for _, key in ipairs({ "details", "report", "reason" }) do
    local f = UI[key]
    if f then K.Windows.Forget(f); f:Hide() end
  end
end

W.Listen(function() UI.RefreshDialogs() end)

function W.OpenReport(target, community, source)
  local W = source or W
  local UI = W.UI
  if not W.ready then return W.Say(W.loadError or ns.Locale:Get("reputation.forms.reputation_is_loading.ebdd24")) end
  local choices = UI.CommunityChoices(nil, true)
  if #choices == 0 then W.Open(); return W.Say(ns.Locale:Get("reputation.forms.join_a_guild_or_wow_community_to.f7677f")) end
  if not UI.report then
    local f = UI.Dialog("Report", ns.Locale:Get("reputation.forms.report_player.af5122"), 560, 560)
    UI.report = f
    f.community = K.Select(f.content, { width = 508, label = ns.Locale:Get("reputation.forms.organization.519255"), menu = true,
      onChange = function(_, id)
        if id == ALL then
          for _, c in ipairs(W.List()) do W.Discover(c.id, true) end
        else
          local c = W.Get(id) or W.Follow(id)
          if c then W.db.selected = c.id end
          if W.Joined(c) then W.Discover(id, true) end
        end
        ReportRole(f, W)
      end })
    f.community:SetPoint("TOPLEFT", 0, -24)
    f.name = K.Input(f.content, 508, ns.Caps.hideRealmNames and ns.Locale:Get("reputation.forms.full_player_name_include_surname.2bd448") or ns.Locale:Get("reputation.forms.full_player_name_include_realm.fd807b"))
    f.name:SetPoint("TOPLEFT", 0, -90); f.name:SetMaxLetters(200)
    f.categories = {}
    for i, category in ipairs(W.CATEGORIES) do
      local toggle = K.Toggle(f.content, category[2], { width = 245 })
      toggle:SetPoint("TOPLEFT", ((i - 1) % 2) * 260, -140 - math.floor((i - 1) / 2) * 32)
      f.categories[category[1]] = toggle
    end
    f.note = K.Input(f.content, 508, ns.Locale:Get("reputation.forms.explanation_note_optional_280_characters.e32edb"))
    f.note:SetPoint("TOPLEFT", 0, -270); f.note:SetMaxLetters(280)
    f.hint = UI.Label(f.content, "", 0, -310, 508)
    f.hint:SetWordWrap(true)
    f.status = UI.Label(f.content, "", 0, -365, 508, "danger")
    f.status:SetWordWrap(true)
    f.status:ClearAllPoints(); f.status:SetPoint("TOPLEFT", f.hint, "BOTTOMLEFT", 0, -12)
    f.submit = K.Button(f, ns.Locale:Get("reputation.forms.submit_proposal.0dde28"), 235, 32, { tone = "accent", onClick = function()
      local id = f.community:GetValue()
      local c = W.Get(id)
      local name = W.Text(f.name:GetText(), 200)
      local player, err = f.target
      if not player or name ~= player.name and name ~= ns.Core.DisplayName(player.name, true) then player, err = W.Target(name) end
      if not player then return UI.Result(f, nil, err) end
      local categories = {}
      for key, toggle in pairs(f.categories) do if toggle:GetChecked() then categories[key] = true end end
      if id == ALL then return SaveAll(f, W, player, categories, f.note:GetText()) end
      local result
      if W.CanModerate(c) then result, err = W.Decide(c, player, "ban", categories, f.note:GetText())
      else result, err = W.Submit(c, player, categories, f.note:GetText()) end
      UI.Result(f, result, err)
      if result and result.delivery then
        UI.SetMode("proposals", c.id)
        W.Say(W.DeliveryText(c, result) .. ".")
      end
    end })
    f.submit:SetPoint("BOTTOMRIGHT", -18, 18)
    f.resume = K.Button(f, ns.Locale:Get("reputation.forms.enable_on_this_account.5a6ada"), 235, 32, { onClick = function()
      local id, c = f.community:GetValue(), W.Get(f.community:GetValue())
      local err
      if (W.organizations or ns.Organizations).CanModerate(id) and not (c and c.activated) then c, err = W.Enable(id)
      else c, err = W.Follow(id) end
      if not c then f.status:SetText(err); return end
      W.Discover(c.id, true); ReportRole(f, W)
    end })
    f.resume:SetPoint("BOTTOMLEFT", 18, 18)
    -- A suspended editor keeps its draft, but rechecks native access when
    -- it returns instead of rebuilding hidden controls on every event.
    f:HookScript("OnShow", function() UI.RefreshDialogs() end)
  end
  local f = UI.report
  local all, c, err = community == ALL, nil, nil
  if all then
    for _, joined in ipairs(W.List()) do W.Discover(joined.id, true) end
  else
    c = community or W.Get() or W.Get(choices[1].key)
    if not c then c, err = W.Follow(choices[1].key) end
    if not c then return W.Say(err) end
    W.db.selected = c.id
    if W.Joined(c) then W.Discover(c.id, true) end
  end
  f.target = target and W.Copy(target) or nil
  f.community:SetChoices(ReportChoices(W, all)); f.community:SetValue(all and ALL or c.id, true)
  f.name:SetText(ns.Core.DisplayName(target and target.name, true))
  -- "All" starts blank; one organization shows your report or its decision.
  local old = c and target and W.OwnReport(c, target)
  local row = c and target and W.FindCase(c, target)
  local source = c and W.CanModerate(c) and row and row.active or old
  for key, toggle in pairs(f.categories) do toggle:SetChecked(source and source.categories[key] or false, true) end
  f.note:SetText(source and source.note or "")
  f.status:SetText(""); ReportRole(f, W); f:Show()
  if not target then f.name:SetFocus() end
end

function W.OpenReason(c, target, kind, source)
  local W = source or W
  local UI = W.UI
  if not UI.reason then
    local f = UI.Dialog("Reason", ns.Locale:Get("reputation.forms.moderation_reason.5e7d5d"), 560, 290)
    UI.reason = f
    f.player = UI.Label(f.content, "", 0, 0, 508, "text")
    f.reason = K.Input(f.content, 508, ns.Locale:Get("reputation.forms.reason_required_shared_with_members.affeb0"))
    f.reason:SetPoint("TOPLEFT", 0, -70); f.reason:SetMaxLetters(280)
    f.status = UI.Label(f.content, "", 0, -112, 508, "danger")
    f.submit = K.Button(f, ns.Locale:Get("reputation.forms.save.efc007"), 180, 32, { tone = "danger", onClick = function()
      local op, err = W.Decide(f.community, f.target, f.kind, {}, f.reason:GetText())
      UI.Result(f, op, err)
      if op and UI.details then UI.details:Hide() end
    end })
    f.submit:SetPoint("BOTTOMRIGHT", -18, 18)
  end
  local f = UI.reason
  f.community, f.target, f.kind = c, W.Copy(target), kind
  f.player:SetText(ns.Core.DisplayName(target.name, true) .. " - " .. W.Name(c))
  f:SetTitle(kind == "revoke" and ns.Locale:Get("reputation.forms.revoke_blacklist_entry.27a25c") or ns.Locale:Get("reputation.forms.dismiss_proposals.3233cb"))
  f.submit:SetText(kind == "revoke" and ns.Locale:Get("reputation.forms.revoke_entry.52cd11") or ns.Locale:Get("reputation.forms.dismiss_proposals.7512a9"))
  f.status:SetText(""); f.reason:SetText(""); UI.RefreshDialogs(); f:Show(); f.reason:SetFocus()
end
