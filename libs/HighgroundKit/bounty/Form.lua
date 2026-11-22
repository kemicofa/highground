local _, ns = ...
local B, Kit, T = ns.Bounty, ns.Kit, ns.Theme
local P, Form = B.Public, {}
B.Form = Form
local MODES = {
  ns.Localization.Define({ key = "personal", label = ns.Locale:Get("shared.boardmodel.only_me.7631b1"), hint = ns.Locale:Get("shared.form.start_here_for_private_alerts_when_you.89617d") }, { label = "shared.boardmodel.only_me.7631b1", hint = "shared.form.start_here_for_private_alerts_when_you.89617d" }),
  ns.Localization.Define({ key = "guild", label = ns.Locale:Get("shared.form.guild_community.d3be0a"), hint = ns.Locale:Get("shared.form.choose_a_guild_or_wow_community_guild.184683") }, { label = "shared.form.guild_community.d3be0a", hint = "shared.form.choose_a_guild_or_wow_community_guild.184683" }),
  ns.Localization.Define({ key = "public", label = ns.Locale:Get("shared.form.shared.50d0d8"), hint = ns.Locale:Get("shared.form.offer_a_reward_to_hunters_on_your.58b97b") }, { label = "shared.form.shared.50d0d8", hint = "shared.form.offer_a_reward_to_hunters_on_your.58b97b" }),
}
local EXPIRIES = {
  ns.Localization.Define({ key = "2h", label = ns.Locale:Get("shared.form.2h.79e4ba"), hint = ns.Locale:Get("shared.form.2_hours.2046e4") }, { label = "shared.form.2h.79e4ba", hint = "shared.form.2_hours.2046e4" }),
  ns.Localization.Define({ key = "24h", label = ns.Locale:Get("shared.form.24h.027795"), hint = ns.Locale:Get("shared.form.24_hours.cb4780") }, { label = "shared.form.24h.027795", hint = "shared.form.24_hours.cb4780" }),
  ns.Localization.Define({ key = "3d", label = ns.Locale:Get("shared.form.3d.34f9ef"), hint = ns.Locale:Get("shared.form.3_days.09ad9d") }, { label = "shared.form.3d.34f9ef", hint = "shared.form.3_days.09ad9d" }),
  ns.Localization.Define({ key = "7d", label = ns.Locale:Get("shared.form.7d.fd4a4c"), hint = ns.Locale:Get("shared.form.7_days.0a8dd6") }, { label = "shared.form.7d.fd4a4c", hint = "shared.form.7_days.0a8dd6" }),
  ns.Localization.Define({ key = "custom", label = ns.Locale:Get("shared.form.custom.081ae3"), hint = ns.Locale:Get("shared.form.choose_a_duration_from_5_minutes_to.82d85d") }, { label = "shared.form.custom.081ae3", hint = "shared.form.choose_a_duration_from_5_minutes_to.82d85d" }),
}

function Form.Expiry(w, match)
  if match then
    w.durationChoice = "custom"
    local seconds = P.Duration(w.duration:GetText())
    for _, option in ipairs(EXPIRIES) do
      if option.key ~= "custom" and seconds == P.Duration(option.key) then w.durationChoice = option.key end
    end
  end
  if w.durationChoice then w.expirySelect:SetValue(w.durationChoice, true) end
  local shared = w.formMode == "public"
  w.expiry:SetShown(shared)
  w.duration:SetShown(shared and w.durationChoice == "custom")
  w.duration.caption:SetShown(shared and w.durationChoice == "custom")
end

function Form.SelectExpiry(w, key)
  w.durationChoice = key
  if key ~= "custom" then w.duration:SetText(key); w.duration:ClearFocus() end
  w.error:SetText("")
  Form.Expiry(w)
  if w.LayoutPage then w:LayoutPage() end
  if key == "custom" then w.duration:SetFocus() end
end

function Form.SetName(w, name)
  w.nameIdentity = name and ns.Core.Canon(name)
  w.name:SetText(ns.Caps.hideRealmNames and ns.Core.DisplayName(name) or name or "")
end

function Form.Name(w)
  local text = w.name:GetText():match("^%s*(.-)%s*$")
  if w.nameIdentity and ns.Caps.hideRealmNames and text == ns.Core.DisplayName(w.nameIdentity) then return w.nameIdentity end
  return text
end

function Form.Funding(w)
  if w.preview then return B.Preview.Funding(w) end
  local name, gold = Form.Name(w), B.Terms.Gold(w.gold:GetText()) or 0
  local count = math.max(1, tonumber(w.kills and w.kills:GetText()) or 1)
  if w.killBudget then w.killBudget:SetText(ns.Locale:Format("shared.form.value1_per_approved_kill_up_to_value3.2411d3", { value1 = ns.Util.Gold(gold), value3 = ns.Util.Gold(gold * count) })) end
  local own, guild = P.Own(name), B.GuildSource(name)
  local warning, available = P.FundingWarning(gold * count, own and own.id, guild)
  w.goldSummary:SetText(ns.Locale:Format("shared.form.value1_value3_available_value5.16f996", { value1 = (B.Gold.Enabled() and ns.Locale:Get("shared.form.account_gold.d091f7") or ns.Locale:Get("shared.form.character_gold.929e3b")), value3 = B.Scope.Label(), value5 = B.Gold.Format(available) }))
  w.goldWarning:SetText(warning and (warning .. (B.Gold.Required() and ns.Locale:Get("shared.form.add_gold_or_turn_off_require_enough.093433")
    or ns.Locale:Get("shared.form.you_can_still_create_this_bounty.734203"))) or "")
end

function Form.Refresh(w)
  if not w then
    -- Gold and sharing notifications only matter to a visible draft; every
    -- route into the form renders it again.
    w = Form.win
    if not (w and w:IsVisible()) then return end
  end
  local shared, guild = w.formMode == "public", w.formMode == "guild"
  w.organization:SetShown(guild and not w.preview)
  w.organization:SetChoices(B.Organizations.Choices())
  w.organization:SetValue(w.organizationID, true)
  local joined = B.Organizations.Member(w.organizationID)
  w.action:SetText(shared and (P.Publishing() and ns.Locale:Get("shared.form.publish_shared_bounty.a15d1f") or ns.Locale:Get("shared.form.enable_sharing_publish.721213"))
    or guild and ns.Locale:Get("shared.form.submit_bounty.46a60b") or ns.Locale:Get("shared.form.save_private_bounty.e34eeb"))
  Form.Expiry(w)
  w.gold.caption:SetText(shared and ns.Locale:Get("shared.form.gold_per_kill.ae5040") or ns.Locale:Get("shared.form.gold_per_kill_optional.76bd5e"))
  w.action:SetEnabled(true)
  w.terms:SetText(shared and ns.Locale:Get("shared.form.hunters_detected_kills_are_reported_automatically_review.cc60b1")
    or guild and ((w.preview or joined) and ns.Locale:Get("shared.form.moderators_approve_the_bounty_first_hunters_detected.08c1ff") or ns.Locale:Get("shared.form.join_a_guild_or_wow_community_or.9e2012"))
    or ns.Locale:Get("shared.form.you_get_an_alert_when_this_player.785530"))
  if w.preview then ns.Localization.Bind(w.action, "shared.form.save_sample_bounty.03e305") end
  if (w.step or 1) < 3 then w.action:SetText(w.step == 2 and ns.Locale:Get("shared.boardactions.review_bounty.1d4814") or ns.Locale:Get("shared.form.next_reward.c4b2e0")) end
  Form.Funding(w)
  if w.LayoutPage then w:LayoutPage() end
end

function Form.SetMode(w, key)
  w.formMode = key
  w.modeSelect:SetValue(key, true)
  for _, mode in ipairs(MODES) do
    if mode.key == key then ns.Localization.BindField(w.audienceHint, mode, "hint") end
  end
  w.error:SetText("")
  Form.Refresh(w)
end

function Form.Save(w)
  if w.preview then return B.Preview.SaveDraft(w) end
  local name, gold, note = Form.Name(w), w.gold:GetText(), w.note:GetText()
  w.error:SetText("")
  local terms, err = B.Terms.Validate(tonumber(w.kills:GetText()) or 0, B.TermsEditor.Read(w).killMethods)
  if not terms then w.customize = true; Form.Layout(w); w.error:SetText(err); return end
  local b
  if w.suggestionTarget and B.Key(name) == B.Key(w.suggestionTarget) and B.Suggestions.Existing(name) then
    ns.Localization.Bind(w.error, "shared.form.a_bounty_for_this_target_already_exists.d6d5cb")
    return
  end
  if w.formMode == "public" then
    b, err = P.Post(name, gold, w.duration:GetText(), note, true, terms)
  elseif w.formMode == "guild" then
    if not B.Organizations.Member(w.organizationID) then
      err = B.Organizations.ID(w.organizationID) and ns.Locale:Get("shared.form.join_the_selected_community_before_submitting.d09f38") or ns.Locale:Get("shared.form.join_a_guild_before_submitting.a77c99")
    else
      local old = B.Guild(w.organizationID)[B.Key(name)]
      local shared = P.Own(name)
      if shared and (B.Terms.Gold(gold) ~= shared.gold or not B.Terms.Same(terms, shared) or B.Clean(note) ~= shared.note) then
        w.error:SetText(ns.Locale:Format("shared.form.organization_visibility_uses_your_existing_shared_gold.95ee8a", { shared_gold = shared.gold }))
        return
      end
      if old and old.state ~= "removed" and not old.publicClosed then err = ns.Locale:Get("shared.form.this_target_already_has_a_listing_in.e3bfc6")
      else
        local saved = B.Personal()[B.Key(name)]
        if shared then b = shared else b, err = B.Add(name, gold, note, terms) end
        if b then
          b, err = B.Submit(b.name, shared, w.organizationID)
          if not b then B.Personal()[B.Key(name)] = saved end
        end
      end
    end
  elseif P.Own(name) or B.GuildSource(name) then
    err = ns.Locale:Get("shared.form.this_bounty_is_already_published_open_the.e80e64")
  else b, err = B.Add(name, gold, note, terms) end
  if not b then w.error:SetText(err or ns.Locale:Get("shared.form.could_not_save_this_bounty.bb730d")); return end
  local mode = w.formMode
  w:Hide(); B.Board.SetTab("mine")
  B.Board.messageTone = "success"
  B.Board.message = mode == "public" and ns.Locale:Get("shared.form.reward_published_open_view_bounty_to_share.c5f1a2")
    or mode == "guild" and (b.state == "approved" and ns.Locale:Get("shared.form.bounty_approved_and_shared_with_your_organization.713a65") or ns.Locale:Get("shared.form.submitted_for_review_by_your_organization_moderators.fff1db"))
    or ns.Locale:Get("shared.form.private_bounty_saved_open_view_bounty_to.82eef7")
  B.Emit("updated")
end

function Form.Build(preview)
  local field = preview and "previewWin" or "win"
  if Form[field] then return Form[field] end
  local w = ns.Localization.BindWidget(Kit.Dialog((ns.FRAME_PREFIX or "Highground") .. "BountyCreate" .. (preview and "Preview" or ""), {
    title = ns.Locale:Get("shared.form.create_bounty.5e6f80"), width = 570, height = 560, header = 64, accent = "gold", alpha = 1,
    strata = "FULLSCREEN_DIALOG", child = preview }), { title = "shared.form.create_bounty.5e6f80" })
  Form[field], w.preview = w, preview
  w.fields = Kit.ScrollArea(w)
  local body = w.fields.body
  w.audienceLabel = T.Text(body, "heading", "text")
  ns.Localization.Bind(w.audienceLabel, "shared.form.2_who_should_see_it.ec9b42")
  -- One audience per bounty: a segmented choice, not separate pages.
  local choices = {}
  -- Segments read the declared labels, so they follow a language change.
  for i, mode in ipairs(MODES) do choices[i] = { key = mode.key, label = function() return mode.label end } end
  w.modeSelect = Kit.Segmented(body, { choices = choices, onChange = function(_, key) Form.SetMode(w, key) end })
  w.modes = w.modeSelect.byKey
  for _, mode in ipairs(MODES) do
    Kit.Tooltip(w.modes[mode.key], function() return { mode.label, mode.hint } end)
  end
  w.organization = Kit.Select(body, { width = 500, menu = true, choices = {}, onChange = function(_, id)
    w.organizationID = id; w.error:SetText(""); Form.Refresh(w)
  end })
  Kit.Tooltip(w.organization, function() return { ns.Locale:Get("shared.form.guild_or_community.448929"), ns.Locale:Get("shared.form.only_members_of_the_selected_organization_receive.d32575") } end)
  w.audienceHint = T.Text(body, "body", "textMuted"); w.audienceHint:SetJustifyH("LEFT")
  w.audienceHint:SetJustifyV("TOP"); w.audienceHint:SetWordWrap(true)
  w.name = Kit.Input(body, 350, ns.Caps.hideRealmNames and ns.Locale:Get("shared.form.player_name.d51b8d") or ns.Locale:Get("shared.form.player_name_realm_optional.b684e5"))
  w.target = ns.Localization.Bind(Kit.Button(body, ns.Locale:Get("shared.form.use_target.69136c"), 108, 26, { onClick = function()
    local name, err = B.Board.TargetPlayer()
    if name then Form.SetName(w, name); w.error:SetText("") else w.error:SetText(err) end
  end }), "shared.form.use_target.69136c")
  w.gold = ns.Localization.BindWidget(Kit.Input(body, 180, ns.Locale:Get("shared.form.3_gold_per_kill.798c37")), { caption = "shared.form.3_gold_per_kill.798c37" })
  w.goldSummary = T.Text(body, "bodySmall", "textMuted"); w.goldSummary:SetJustifyH("LEFT"); w.goldSummary:SetJustifyV("TOP")
  w.goldSummary:SetWordWrap(true)
  w.goldWarning = T.Text(body, "bodySmall", "warning"); w.goldWarning:SetJustifyH("LEFT"); w.goldWarning:SetJustifyV("TOP")
  w.goldWarning:SetWordWrap(true); w.goldWarning:SetText("")
  w.goldDetails = ns.Localization.Bind(Kit.Button(body, ns.Locale:Get("shared.form.gold_settings.6b81f3"), 132, 28, { onClick = function() B.GoldView.Open(w.preview) end }), "shared.form.gold_settings.6b81f3")
  Kit.Tooltip(w.goldDetails, function() return { ns.Locale:Get("shared.form.gold_across_your_characters.36c0a4"), ns.Locale:Get("shared.form.view_the_breakdown_and_choose_whether_enough.97f399") } end)
  w.expiry = CreateFrame("Frame", nil, body)
  w.expiry.caption = T.Text(w.expiry, "caption", "textMuted")
  w.expiry.caption:SetPoint("BOTTOMLEFT", w.expiry, "TOPLEFT", 1, 5); ns.Localization.Bind(w.expiry.caption, "shared.form.expires_after.6a5808")
  w.expirySelect = Kit.Segmented(w.expiry, { choices = EXPIRIES, onChange = function(_, key) Form.SelectExpiry(w, key) end })
  w.expiryButtons = w.expirySelect.byKey
  for _, option in ipairs(EXPIRIES) do
    Kit.Tooltip(w.expiryButtons[option.key], function() return { option.hint, ns.Locale:Get("shared.form.other_posters_choose_their_own_expiry_editing.18a05e") } end)
  end
  w.duration = ns.Localization.BindWidget(Kit.Input(body, 180, ns.Locale:Get("shared.form.custom_duration_e_g_30m_or_14d.6f68de")), { caption = "shared.form.custom_duration_e_g_30m_or_14d.6f68de" })
  w.note = ns.Localization.BindWidget(Kit.Input(body, 500, ns.Locale:Get("shared.form.note_optional.f91717")), { caption = "shared.form.note_optional.f91717" })
  -- Notes travel with a byte limit; accented letters and symbols use more
  -- than one byte. The game's byte limit includes the terminator.
  if w.note.SetMaxBytes then w.note:SetMaxBytes(B.NOTE_MAX + 1) else w.note:SetMaxLetters(B.NOTE_MAX) end
  w.terms = T.Text(body, "body", "textMuted"); w.terms:SetJustifyH("LEFT"); w.terms:SetJustifyV("TOP"); w.terms:SetWordWrap(true)
  w.error = T.Text(w, "body", "warning")
  w.error:SetPoint("BOTTOMLEFT", 24, 64); w.error:SetPoint("RIGHT", -24, 0)
  w.error:SetJustifyH("LEFT"); w.error:SetJustifyV("BOTTOM"); w.error:SetWordWrap(true)
  B.TermsEditor.Build(w, body)
  for _, field in ipairs({ w.name, w.gold, w.duration, w.note, w.kills }) do
    -- A validation result belongs to the submitted draft, not later edits.
    Kit.OnTextChange(field, function() w.error:SetText("") end)
    field:HookScript("OnEditFocusGained", function()
      local y = w.fieldY and w.fieldY[field]
      if not y then return end
      local top, bottom = y - 28, y + field:GetHeight() + 8
      if top < w.fields.offset then w.fields:Scroll(top)
      elseif bottom > w.fields.offset + w.fields.view:GetHeight() then w.fields:Scroll(bottom - w.fields.view:GetHeight()) end
    end)
  end
  for _, field in ipairs({ w.name, w.gold }) do
    Kit.OnTextChange(field, function() Form.Funding(w); if w.LayoutPage then Form.Layout(w) end end)
  end
  Kit.OnTextChange(w.duration, function()
    Form.Expiry(w, w.durationChoice ~= "custom")
    if w.LayoutPage then w:LayoutPage() end
  end)
  w.cancel = Kit.Button(w, preview and ns.Locale:Get("shared.form.return.24f096") or ns.Locale:Get("shared.board.back_to_board.c4cc8d"), 140, 32, { onClick = function() w:Hide() end })
  w.cancel:SetPoint("BOTTOMLEFT", 24, 22)
  w.action = Kit.Button(w, "", 260, 32, { tone = "gold", onClick = function() Form.Advance(w) end })
  w.action:SetPoint("BOTTOMRIGHT", -24, 22)
  Kit.Tooltip(w.name, function() return { ns.Locale:Get("shared.form.player_to_hunt.58b472"), ns.Caps.hideRealmNames and ns.Locale:Get("shared.form.type_the_full_character_name_including_their.71ac94")
    or ns.Locale:Get("shared.form.type_an_exact_character_name_for_your.89ea10") } end)
  Kit.Tooltip(w.target, function() return { ns.Locale:Get("shared.form.use_your_target.b6c784"), ns.Locale:Get("shared.form.copy_the_selected_player_s_exact_name.9fd7b9") } end)
  Kit.Tooltip(w.gold, function() return { ns.Locale:Get("shared.form.your_reward.fa1b16"), ns.Locale:Get("shared.form.whole_gold_per_approved_kill_1_and.9b8724") } end)
  Kit.Tooltip(w.duration, function() return { ns.Locale:Get("shared.form.when_your_contribution_expires.1d0b32"), ns.Locale:Get("shared.form.use_30m_2h_or_7d_allowed_range.2981b0") } end)
  Kit.Tooltip(w.note, function() return { ns.Locale:Get("shared.form.optional_context.0177b1"), ns.Locale:Get("shared.form.a_short_note_shown_to_this_bounty.b79761") } end)
  Kit.Tooltip(w.action, function() return { w.action:GetText(), (w.step or 1) < 3 and ns.Locale:Get("shared.form.continue_to_the_next_step_nothing_is.79b6aa") or ns.Locale:Get("shared.form.save_to_the_selected_audience_enable_sharing.921b0c") } end)
  Kit.Tooltip(w.cancel, function() return { ns.Locale:Get("shared.form.discard_this_draft.4b0e90"), ns.Locale:Get("shared.form.close_without_saving_or_changing_sharing_preferences.2fdba5") } end)
  w.name:SetScript("OnEnterPressed", function(self) self:ClearFocus(); Form.Advance(w) end)
  w.gold:SetScript("OnEnterPressed", function(self) self:ClearFocus(); (w.duration:IsShown() and w.duration or w.customize and w.kills or w.note):SetFocus() end)
  w.duration:SetScript("OnEnterPressed", function(self) self:ClearFocus(); w.note:SetFocus() end)
  w.note:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  Form.BuildSteps(w)
  w.LayoutPage = Form.Layout
  Form.Layout(w); ns.Core.OnFontScaleChange(function() Form.Layout(w) end)
  T.OnChange(function() Form.Funding(w); Form.Layout(w) end)
  if preview then w:HookScript("OnShow", function() if B.Preview.state then Form.Refresh(w) end end) end
  return w
end

function Form.Render(name, mode, source, preview, state, organization)
  local w = Form.Build(preview)
  w.suggestionTarget, w.step = nil, 1
  w.organizationID = organization or source and source.organization or B.Organizations.Selected()
  name = name or B.Board.TargetPlayer()
  mode = mode or "personal"
  local own = not preview and name and P.Own(name)
  local draft = source
  if not preview then draft = own or source or name and (B.GuildSource(name) or B.Personal()[B.Key(name)]) end
  B.TermsEditor.Set(w, draft)
  Form.SetName(w, name); w.gold:SetText(draft and tostring(draft.gold) or "")
  w.note:SetText(draft and draft.note or "")
  w.durationChoice = nil
  w.duration:SetText(own and (math.max(5, math.ceil((own.expiresAt - P.Now()) / 60)) .. "m")
    or ((ns.Core.O("bountyDurationHours") or 24) .. "h"))
  Form.Expiry(w, true)
  w:SetTitle(preview and ns.Locale:Get("shared.form.preview_create_bounty.090cfa") or draft and ns.Locale:Get("shared.form.edit_bounty.035bc9") or ns.Locale:Get("shared.form.create_bounty.5e6f80"))
  Form.SetMode(w, mode)
  if state then
    Form.SetName(w, state.identity)
    for _, key in ipairs({ "name", "gold", "note", "duration", "kills" }) do w[key]:SetText(state[key]) end
    w.selectedMethods, w.durationChoice, w.suggestionTarget = state.methods, state.expiry, state.suggestionTarget
    for id, button in pairs(w.methodButtons) do button:SetSelected(w.selectedMethods[id] == true) end
    w.organizationID = state.organization
    w.customize = state.customize == true
    w.step = state.step or 1
    Form.SetMode(w, state.mode)
  end
  if preview then B.Widgets.ShowWindow(w) else B.Navigation.Mount(w) end
  if not state then w.name:SetFocus() end
  w.fields:Scroll(state and state.scroll or 0)
  return w
end

function Form.Capture()
  local w = Form.win
  local state = { identity = w.nameIdentity, methods = w.selectedMethods, expiry = w.durationChoice,
    suggestionTarget = w.suggestionTarget, mode = w.formMode, scroll = w.fields.offset, organization = w.organizationID, customize = w.customize, step = w.step }
  for _, key in ipairs({ "name", "gold", "note", "duration", "kills" }) do state[key] = w[key]:GetText() end
  return state
end

function Form.Open(name, mode, source, preview, organization)
  if ns.Modules and not ns.Modules.Require("bounties") then return end
  if preview then return Form.Render(name, mode, source, true) end
  return B.Navigation.Open("form", { name = name or B.Board.TargetPlayer(), mode = mode or "personal", source = source, organization = organization })
end
