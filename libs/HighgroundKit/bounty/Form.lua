local _, ns = ...
local B, Kit, T = ns.Bounty, ns.Kit, ns.Theme
local P, Form = B.Public, {}
B.Form = Form
local MODES = {
  { key = "personal", label = "Only me", hint = "Start here for private alerts when you spot this player. No reward needed, and nothing is sent to anyone else." },
  { key = "guild", label = "Guild / community", hint = "Choose a guild or WoW community. Guild officers or community moderators approve submissions before members can hunt." },
  { key = "public", label = "Shared", hint = "Offer a reward to hunters on your realm and faction who use Highground. Other players can add their own rewards." },
}
local EXPIRIES = {
  { key = "2h", label = "2h", hint = "2 hours" },
  { key = "24h", label = "24h", hint = "24 hours" },
  { key = "3d", label = "3d", hint = "3 days" },
  { key = "7d", label = "7d", hint = "7 days" },
  { key = "custom", label = "Custom", hint = "Choose a duration from 5 minutes to 30 days" },
}

function Form.Expiry(w, match)
  if match then
    w.durationChoice = "custom"
    local seconds = P.Duration(w.duration:GetText())
    for _, option in ipairs(EXPIRIES) do
      if option.key ~= "custom" and seconds == P.Duration(option.key) then w.durationChoice = option.key end
    end
  end
  for key, button in pairs(w.expiryButtons) do button:SetSelected(key == w.durationChoice) end
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
  local text = w.name:GetText()
  if w.nameIdentity and ns.Caps.hideRealmNames and text == ns.Core.DisplayName(w.nameIdentity) then return w.nameIdentity end
  return text
end

function Form.Funding(w)
  if w.preview then return B.Preview.Funding(w) end
  local name, gold = Form.Name(w), B.Terms.Gold(w.gold:GetText()) or 0
  local count = math.max(1, tonumber(w.kills and w.kills:GetText()) or 1)
  if w.killBudget then w.killBudget:SetText(ns.Util.Gold(gold) .. " per approved kill\nUp to " .. ns.Util.Gold(gold * count) .. " total") end
  local own, guild = P.Own(name), B.GuildSource(name)
  local warning, available = P.FundingWarning(gold * count, own and own.id, guild)
  w.goldSummary:SetText((B.Gold.Enabled() and "Account gold" or "Character gold") .. " · " .. B.Scope.Label()
    .. "\nAvailable: " .. B.Gold.Format(available))
  w.goldWarning:SetText(warning and (warning .. (B.Gold.Required() and " Add gold or turn off Require enough gold."
    or " You can still create this bounty.")) or "")
end

function Form.Refresh(w)
  w = w or Form.win
  if not w then return end
  local shared, guild = w.formMode == "public", w.formMode == "guild"
  w.organization:SetShown(guild and not w.preview)
  w.organization:SetChoices(B.Organizations.Choices())
  w.organization:SetValue(w.organizationID, true)
  local joined = B.Organizations.Member(w.organizationID)
  w.action:SetText(shared and (P.Publishing() and "Publish shared bounty" or "Enable sharing & publish")
    or guild and "Submit bounty" or "Save private bounty")
  Form.Expiry(w)
  w.gold.caption:SetText(shared and "3. GOLD PER KILL" or "3. GOLD PER KILL (OPTIONAL)")
  w.action:SetEnabled(w.preview or not guild or joined)
  w.terms:SetText(shared and "Hunters' detected kills are reported automatically. Review the reward in Claims & payments, then pay through the game. Sharing on Discord is optional."
    or guild and ((w.preview or joined) and "Moderators approve the bounty first. Hunters' detected kills then appear in Claims & payments for reward review." or "Join a guild or WoW community, or choose Only me.")
    or "You get an alert when this player appears. Detected kills are saved automatically. A reward is optional.")
  if w.preview then w.action:SetText("Save sample bounty") end
  Form.Funding(w)
  if w.LayoutPage then w:LayoutPage() end
end

function Form.SetMode(w, key)
  w.formMode = key
  for _, mode in ipairs(MODES) do
    w.modes[mode.key]:SetSelected(mode.key == key)
    if mode.key == key then w.audienceHint:SetText(mode.hint) end
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
    w.error:SetText("A bounty for this target already exists. Open it on the bounty board.")
    return
  end
  if w.formMode == "public" then
    b, err = P.Post(name, gold, w.duration:GetText(), note, true, terms)
  elseif w.formMode == "guild" then
    if not B.Organizations.Member(w.organizationID) then
      err = B.Organizations.ID(w.organizationID) and "Join the selected community before submitting." or "Join a guild before submitting."
    else
      local old = B.Guild(w.organizationID)[B.Key(name)]
      local shared = P.Own(name)
      if shared and (B.Terms.Gold(gold) ~= shared.gold or not B.Terms.Same(terms, shared) or B.Clean(note) ~= shared.note) then
        w.error:SetText("Organization visibility uses your existing " .. shared.gold .. "g contribution. Edit the shared contribution first to change its reward or note.")
        return
      end
      if old and old.state ~= "removed" and not old.publicClosed then err = "This target already has a listing in this organization. Open its board."
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
    err = "This bounty is already published. Use More to withdraw it; saving a private copy cannot make it private."
  else b, err = B.Add(name, gold, note, terms) end
  if not b then w.error:SetText(err or "Could not save this bounty."); return end
  local mode = w.formMode
  w:Hide(); B.Board.SetTab("mine")
  B.Board.message = mode == "public" and "Reward published. Review incoming kill reports in Claims & payments."
    or mode == "guild" and (b.state == "approved" and "Bounty approved and shared with your organization." or "Submitted for review by your organization moderators.")
    or "Private bounty saved. You will be alerted when you spot this player."
  B.Emit("updated")
end

function Form.Layout(w)
  if w.layingOut then return end
  w.layingOut = true
  local extra = math.max(0, ns.Core.FontScale() - 1)
  if not w.bountyPage then w:SetSize(570 + 140 * extra, 620 + 180 * extra) end
  if w.preview then w:SetHeight(math.min(w:GetHeight(), UIParent:GetHeight() - 40)) end
  local width = w:GetWidth() - 68
  w.fields.body:SetWidth(width)
  local y = 122 + extra * 36
  w.audienceLabel:ClearAllPoints(); w.audienceLabel:SetPoint("TOPLEFT", 0, -94 - extra * 32)
  for i, mode in ipairs(MODES) do
    local button = w.modes[mode.key]
    button:ClearAllPoints(); button:SetPoint("TOPLEFT", (i - 1) * (width + 8) / 3, -y)
    button:SetWidth((width - 16) / 3); button:SetHeight(30 + extra * 12)
  end
  w.audienceHint:ClearAllPoints(); w.audienceHint:SetPoint("TOPLEFT", 0, -y - 40 - extra * 12)
  w.audienceHint:SetWidth(width); w.audienceHint:SetHeight(w.audienceHint:GetStringHeight())
  local inputY = 32 + extra * 16
  w.name:ClearAllPoints(); w.name:SetPoint("TOPLEFT", 0, -inputY); w.name:SetPoint("RIGHT", w.target, "LEFT", -10, 0)
  w.target:ClearAllPoints(); w.target:SetPoint("TOPRIGHT", 0, -inputY); w.target:SetSize(108 + extra * 40, 28 + extra * 10)
  local rewardY = y + 80 + extra * 30 + w.audienceHint:GetHeight()
  w.organization:ClearAllPoints(); w.organization:SetPoint("TOPLEFT", 0, -rewardY + 24)
  w.organization:SetWidth(width)
  if w.formMode == "guild" and not w.preview then rewardY = rewardY + 44 + extra * 12 end
  w.gold:ClearAllPoints(); w.gold:SetPoint("TOPLEFT", 0, -rewardY); w.gold:SetWidth(width)
  local fundsY = rewardY + w.gold:GetHeight() + 12
  w.goldSummary:ClearAllPoints(); w.goldSummary:SetPoint("TOPLEFT", 0, -fundsY)
  w.goldDetails:ClearAllPoints(); w.goldDetails:SetPoint("TOPRIGHT", 0, -fundsY)
  w.goldDetails:SetSize(132 + extra * 60, 28 + extra * 12)
  w.goldSummary:SetWidth(width - w.goldDetails:GetWidth() - 12); w.goldSummary:SetHeight(w.goldSummary:GetStringHeight())
  w.goldWarning:ClearAllPoints(); w.goldWarning:SetPoint("TOPLEFT", 0, -fundsY - math.max(w.goldSummary:GetHeight(), w.goldDetails:GetHeight()) - 10)
  w.goldWarning:SetWidth(width); w.goldWarning:SetHeight(w.goldWarning:GetText() ~= "" and w.goldWarning:GetStringHeight() or 0)
  local noteY = fundsY + math.max(w.goldSummary:GetHeight(), w.goldDetails:GetHeight()) + w.goldWarning:GetHeight() + 42
  local durationY = noteY + 30 + extra * 12 + 28
  w.expiry:ClearAllPoints(); w.expiry:SetPoint("TOPLEFT", 0, -noteY); w.expiry:SetSize(width, 30 + extra * 12)
  for i, option in ipairs(EXPIRIES) do
    local button = w.expiryButtons[option.key]
    button:ClearAllPoints(); button:SetPoint("TOPLEFT", (i - 1) * (width + 8) / #EXPIRIES, 0)
    button:SetSize((width - (#EXPIRIES - 1) * 8) / #EXPIRIES, w.expiry:GetHeight())
  end
  w.duration:ClearAllPoints(); w.duration:SetPoint("TOPLEFT", 0, -durationY); w.duration:SetWidth(width)
  if w.formMode == "public" then
    noteY = w.durationChoice == "custom" and durationY + w.duration:GetHeight() + 32
      or noteY + w.expiry:GetHeight() + 32
  end
  local killsY = noteY
  noteY = B.TermsEditor.Layout(w, width, noteY, extra)
  w.note:ClearAllPoints(); w.note:SetPoint("TOPLEFT", 0, -noteY); w.note:SetPoint("RIGHT", 0, 0)
  w.terms:ClearAllPoints(); w.terms:SetPoint("TOPLEFT", w.note, "BOTTOMLEFT", 0, -14)
  w.terms:SetWidth(width); w.terms:SetHeight(w.terms:GetStringHeight())
  w.fields.body:SetHeight(noteY + w.note:GetHeight() + 14 + w.terms:GetHeight() + 10)
  w.fieldY = { [w.name] = inputY, [w.gold] = rewardY, [w.duration] = durationY, [w.note] = noteY, [w.kills] = killsY }
  w.error:SetHeight(48 + extra * 24)
  w.fields:ClearAllPoints(); w.fields:SetPoint("TOPLEFT", 24, -80 - extra * 18)
  w.fields:SetPoint("BOTTOMRIGHT", -24, 124 + extra * 24); w.fields:Refresh()
  w.action:SetWidth(260 + extra * 160); w.action:SetHeight(32 + extra * 12)
  w.cancel:SetSize(140 + extra * 50, 32 + extra * 12)
  w.layingOut = nil
end

function Form.Build(preview)
  local field = preview and "previewWin" or "win"
  if Form[field] then return Form[field] end
  local w = Kit.Dialog((ns.FRAME_PREFIX or "Highground") .. "BountyCreate" .. (preview and "Preview" or ""), {
    title = "CREATE BOUNTY", width = 570, height = 560, header = 64, accent = "gold", alpha = 1,
    strata = "FULLSCREEN_DIALOG", child = preview })
  Form[field], w.preview = w, preview
  w.fields = Kit.ScrollArea(w)
  local body = w.fields.body
  w.audienceLabel = T.Text(body, "heading", "text")
  w.audienceLabel:SetText("2. Who should see it?")
  w.modes = {}
  for _, mode in ipairs(MODES) do
    w.modes[mode.key] = Kit.Choice(body, mode.label, 160, "radio", function() Form.SetMode(w, mode.key) end)
    Kit.Tooltip(w.modes[mode.key], { mode.label, mode.hint })
  end
  w.organization = Kit.Select(body, { width = 500, menu = true, choices = {}, onChange = function(_, id)
    w.organizationID = id; w.error:SetText(""); Form.Refresh(w)
  end })
  Kit.Tooltip(w.organization, { "Guild or community", "Only members of the selected organization receive this bounty. Membership and moderator roles come from WoW." })
  w.audienceHint = T.Text(body, "body", "textMuted"); w.audienceHint:SetJustifyH("LEFT")
  w.audienceHint:SetJustifyV("TOP"); w.audienceHint:SetWordWrap(true)
  w.name = Kit.Input(body, 350, ns.Caps.hideRealmNames and "1. PLAYER NAME" or "1. PLAYER NAME (REALM OPTIONAL)")
  w.target = Kit.Button(body, "Use target", 108, 26, { onClick = function()
    local name, err = B.Board.TargetPlayer()
    if name then Form.SetName(w, name); w.error:SetText("") else w.error:SetText(err) end
  end })
  w.gold = Kit.Input(body, 180, "3. GOLD PER KILL")
  w.goldSummary = T.Text(body, "bodySmall", "textMuted"); w.goldSummary:SetJustifyH("LEFT"); w.goldSummary:SetJustifyV("TOP")
  w.goldSummary:SetWordWrap(true)
  w.goldWarning = T.Text(body, "bodySmall", "warning"); w.goldWarning:SetJustifyH("LEFT"); w.goldWarning:SetJustifyV("TOP")
  w.goldWarning:SetWordWrap(true); w.goldWarning:SetText("")
  w.goldDetails = Kit.Button(body, "Gold & settings", 132, 28, { onClick = function() B.GoldView.Open(w.preview) end })
  Kit.Tooltip(w.goldDetails, { "Gold across your characters", "View the breakdown and choose whether enough gold is required to create a bounty. Your draft is kept while this window is open." })
  w.expiry = CreateFrame("Frame", nil, body)
  w.expiry.caption = T.Text(w.expiry, "caption", "textMuted")
  w.expiry.caption:SetPoint("BOTTOMLEFT", w.expiry, "TOPLEFT", 1, 5); w.expiry.caption:SetText("EXPIRES AFTER")
  w.expiryButtons = {}
  for _, option in ipairs(EXPIRIES) do
    local button = Kit.Choice(w.expiry, option.label, 90, "radio", function() Form.SelectExpiry(w, option.key) end)
    w.expiryButtons[option.key] = button
    Kit.Tooltip(button, { option.hint, "Other posters choose their own expiry. Editing can extend an active contribution, but cannot shorten it." })
  end
  w.duration = Kit.Input(body, 180, "CUSTOM DURATION (e.g. 30m or 14d)")
  w.note = Kit.Input(body, 500, "NOTE (OPTIONAL)"); w.note:SetMaxLetters(B.NOTE_MAX)
  w.terms = T.Text(body, "body", "textMuted"); w.terms:SetJustifyH("LEFT"); w.terms:SetJustifyV("TOP"); w.terms:SetWordWrap(true)
  w.error = T.Text(w, "body", "warning")
  w.error:SetPoint("BOTTOMLEFT", 24, 64); w.error:SetPoint("RIGHT", -24, 0)
  w.error:SetJustifyH("LEFT"); w.error:SetJustifyV("BOTTOM"); w.error:SetWordWrap(true)
  B.TermsEditor.Build(w, body)
  for _, field in ipairs({ w.name, w.gold, w.duration, w.note, w.kills }) do
    -- A validation result belongs to the submitted draft, not later edits.
    field:HookScript("OnTextChanged", function() w.error:SetText("") end)
    field:HookScript("OnEditFocusGained", function()
      local y = w.fieldY and w.fieldY[field]
      if not y then return end
      local top, bottom = y - 28, y + field:GetHeight() + 8
      if top < w.fields.offset then w.fields:Scroll(top)
      elseif bottom > w.fields.offset + w.fields.view:GetHeight() then w.fields:Scroll(bottom - w.fields.view:GetHeight()) end
    end)
  end
  for _, field in ipairs({ w.name, w.gold }) do
    field:HookScript("OnTextChanged", function() Form.Funding(w); if w.LayoutPage then Form.Layout(w) end end)
  end
  w.duration:HookScript("OnTextChanged", function()
    Form.Expiry(w, w.durationChoice ~= "custom")
    if w.LayoutPage then w:LayoutPage() end
  end)
  w.cancel = Kit.Button(w, preview and "Return" or "Back to board", 140, 32, { onClick = function() w:Hide() end })
  w.cancel:SetPoint("BOTTOMLEFT", 24, 22)
  w.action = Kit.Button(w, "", 260, 32, { tone = "gold", onClick = function() Form.Save(w) end })
  w.action:SetPoint("BOTTOMRIGHT", -24, 22)
  Kit.Tooltip(w.name, { "Player to hunt", ns.Caps.hideRealmNames and "Use the full character name, including their surname. The internal realm suffix is kept automatically when using your target or editing a bounty."
    or "Use an exact character name. Include Name-Realm for another realm. Names from different realms are separate targets." })
  Kit.Tooltip(w.target, { "Use your target", "Copy the selected player's exact name and realm, including friendly or unflagged players. This only fills the name; it does not publish anything." })
  Kit.Tooltip(w.gold, { "Your reward", "Whole gold per approved kill; 1 and 1g both work. The total commitment includes every requested kill. Account gold tracking is on by default; Require enough gold is off by default. A low balance warns as you type and only blocks creation when that requirement is enabled. Existing commitments reduce the available total." })
  Kit.Tooltip(w.duration, { "When your contribution expires", "Use 30m, 2h or 7d. Allowed range: 5 minutes to 30 days. Other posters choose their own expiry. An edit can extend, but cannot shorten, an active pledge." })
  Kit.Tooltip(w.note, { "Optional context", "A short note shown to this bounty's audience. It is not an automatically verified kill condition." })
  Kit.Tooltip(w.action, function() return { w.action:GetText(), "Save to the selected audience. Enable sharing & publish also opts you into sending contributions and funding reports. It does not enable receiving other players' bounties." } end)
  Kit.Tooltip(w.cancel, { "Discard this draft", "Close without saving or changing sharing preferences." })
  w.name:SetScript("OnEnterPressed", function(self) self:ClearFocus(); w.gold:SetFocus() end)
  w.gold:SetScript("OnEnterPressed", function(self) self:ClearFocus(); (w.duration:IsShown() and w.duration or w.customize and w.kills or w.note):SetFocus() end)
  w.duration:SetScript("OnEnterPressed", function(self) self:ClearFocus(); w.note:SetFocus() end)
  w.note:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  w.LayoutPage = Form.Layout
  Form.Layout(w); ns.Core.OnFontScaleChange(function() Form.Layout(w) end)
  T.OnChange(function() Form.Funding(w); Form.Layout(w) end)
  if preview then w:HookScript("OnShow", function() if B.Preview.state then Form.Refresh(w) end end) end
  return w
end

function Form.Render(name, mode, source, preview, state, organization)
  local w = Form.Build(preview)
  w.suggestionTarget = nil
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
  w:SetTitle(preview and "PREVIEW · CREATE BOUNTY" or draft and "EDIT BOUNTY" or "CREATE BOUNTY")
  Form.SetMode(w, mode)
  if state then
    Form.SetName(w, state.identity)
    for _, key in ipairs({ "name", "gold", "note", "duration", "kills" }) do w[key]:SetText(state[key]) end
    w.selectedMethods, w.durationChoice, w.suggestionTarget = state.methods, state.expiry, state.suggestionTarget
    for id, button in pairs(w.methodButtons) do button:SetSelected(w.selectedMethods[id] == true) end
    w.organizationID = state.organization
    w.customize = state.customize == true
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
    suggestionTarget = w.suggestionTarget, mode = w.formMode, scroll = w.fields.offset, organization = w.organizationID, customize = w.customize }
  for _, key in ipairs({ "name", "gold", "note", "duration", "kills" }) do state[key] = w[key]:GetText() end
  return state
end

function Form.Open(name, mode, source, preview, organization)
  if preview then return Form.Render(name, mode, source, true) end
  return B.Navigation.Open("form", { name = name or B.Board.TargetPlayer(), mode = mode or "personal", source = source, organization = organization })
end
