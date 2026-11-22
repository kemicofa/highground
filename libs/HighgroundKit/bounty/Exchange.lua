local _, ns = ...
local B, Kit = ns.Bounty, ns.Kit
local E = B.Exchange

local function LayoutShare(w)
  local scale = math.max(1, ns.Core.FontScale())
  w:SetSize(math.min(720 + (scale - 1) * 240, UIParent:GetWidth() - 40), math.min(560 + (scale - 1) * 160, UIParent:GetHeight() - 40))
  w.hint:SetHeight(0); w.hint:SetHeight(math.ceil(w.hint:GetStringHeight()) + 2)
  w.copyLabel:ClearAllPoints(); w.copyLabel:SetPoint("TOPLEFT", w.hint, "BOTTOMLEFT", 8, -22)
  w.copyLabel:SetWidth(w:GetWidth() - 40); w.copyLabel:SetHeight(0); w.copyLabel:SetHeight(w.copyLabel:GetStringHeight() + 2)
  w.instructions:ClearAllPoints(); w.instructions:SetPoint("BOTTOMLEFT", 20, 104 * scale)
  w.instructions:SetWidth(w:GetWidth() - 40); w.instructions:SetHeight(0); w.instructions:SetHeight(w.instructions:GetStringHeight() + 2)
  w.destination:ClearAllPoints(); w.destination:SetPoint("BOTTOMLEFT", w.instructions, "TOPLEFT", 0, 10)
  w.destination:SetWidth(w:GetWidth() - 40); w.destination:SetHeight(0); w.destination:SetHeight(w.destination:GetStringHeight() + 2)
  w.well:ClearAllPoints(); w.well:SetPoint("TOPLEFT", w.copyLabel, "BOTTOMLEFT", -2, -12)
  w.well:SetPoint("BOTTOMRIGHT", -18, 104 * scale + w.instructions:GetHeight() + w.destination:GetHeight() + 34)
  -- Done and the audience's sharing action on the left, the primary copy
  -- action on the right; rows wrap at large text sizes.
  local link = Kit.LabelWidth(w.actions.link, nil, 15)
  local height = w.toolbar:Layout(w:GetWidth() - 52 - link)
  Kit.Place(w.actions.link, "BOTTOMRIGHT", w, "BOTTOMRIGHT", -20, 18, link, math.ceil(Kit.Scale(30)))
  w.status:ClearAllPoints(); w.status:SetPoint("BOTTOMLEFT", 20, 18 + height + 12 + 2 * scale)
  w.status:SetPoint("RIGHT", -20, 0); w.status:SetHeight(44 * scale)
  w.box:SetWidth(w:GetWidth() - 84)
end

local function Copy(title, text, code, preview)
  local field = preview and "previewProofWin" or "proofWin"
  if not E[field] then E[field] = Kit.CopyBox((ns.FRAME_PREFIX or "Highground") .. "BountyExport" .. (preview and "Preview" or ""), {
    title = title, width = 700, height = 550, strata = "FULLSCREEN_DIALOG", alpha = 1,
    buttons = { { key = "code", label = ns.Locale:Get("shared.exchange.select_import_code.73da22"), width = 190, onClick = function(w)
      if w.code then w.box:SetFocus(); w.box:HighlightText(#w:GetText() - #w.code, #w:GetText()) end
    end } } }) end
  local w = E[field]
  if not preview then E.copyWin = w end
  w.code = code; w.actions.code:SetShown(code ~= nil)
  w:Open(title, ns.Locale:Get("shared.exchange.ctrl_a_ctrl_c_to_copy_paste.209126"), text, true)
  B.Widgets.ShowWindow(w)
  return w
end

local function Discord(w, invite)
  if not E.destinationWin then E.destinationWin = Kit.CopyBox((ns.FRAME_PREFIX or "Highground") .. "BountyDiscord", {
    title = ns.Locale:Get("shared.exchange.open_discord.ce0341"), width = 620, height = 280, strata = "FULLSCREEN_DIALOG", alpha = 1 }) end
  local d = E.destinationWin
  d.preview = w.preview
  ns.Localization.Bind(d.done, "shared.exchange.back_to_sharing.364bdc"); d.done:SetWidth(160)
  d:Open(invite and ns.Locale:Get("shared.exchange.join_the_discord.49631a") or ns.Locale:Get("shared.exchange.open_the_bounty_channel.86285e"),
    ns.Locale:Get("shared.exchange.press_ctrl_c_then_paste_this_web.9294d6"), invite and E.INVITE or w.channelURL, true)
  d:SetStatus(ns.Locale:Get("shared.exchange.return_to_sharing_to_copy_your_bounty.1834f3"))
  B.Widgets.ShowWindow(d)
end

local function Share(b, audience, code, preview)
  local field = preview and "previewShareWin" or "shareWin"
  local w = E[field]
  if not w then
    w = Kit.CopyBox((ns.FRAME_PREFIX or "Highground") .. "BountyShare" .. (preview and "Preview" or ""), {
      title = ns.Locale:Get("shared.exchange.share_bounty.e671ea"), width = 720, height = 560, header = 64, alpha = 1,
      buttons = {
        { key = "link", label = ns.Locale:Get("shared.exchange.select_link_to_copy.381d80"), tone = "gold", onClick = function(self) self:SelectPayload(self.payloadMode or "link") end },
        { key = "options", label = ns.Locale:Get("shared.exchange.discord_channel.119a51"), onClick = function(self) Discord(self) end },
        { key = "chat", label = ns.Locale:Get("highground.profiles.share_in_chat.1d5c1d"), onClick = function(self)
          if self.preview then self:SetStatus(ns.Locale:Get("shared.exchange.sample_chat_link_prepared_nothing_is_sent.2d3e25")); return end
          local ok, err = B.Share.Draft(self.chatPayload)
          self:SetStatus(ok and ns.Locale:Get("shared.exchange.chat_draft_ready_choose_your_chat_channel.463633") or err, ok and "text" or "warning")
        end },
      } })
    E[field], w.preview = w, preview
    w.LayoutShare, w.bountyLink = LayoutShare, w.actions.link
    w.toolbar = Kit.Toolbar(w, { items = { w.done, w.actions.options, w.actions.chat }, gap = 12, height = 30 })
    w.toolbar:SetPoint("BOTTOMLEFT", 20, 18)
    local T = ns.Theme
    w.copyLabel, w.destination = T.Text(w, "heading", "gold"), T.Text(w, "heading", "gold")
    w.instructions = T.Text(w, "body", "textMuted")
    for _, text in ipairs({ w.copyLabel, w.destination, w.instructions }) do text:SetJustifyH("LEFT"); text:SetJustifyV("TOP"); text:SetWordWrap(true) end
    w.status:SetJustifyV("TOP")
    function w:SelectPayload(mode)
      mode = mode == true and "code" or mode == false and "post" or mode or "link"
      self.payloadMode = mode
      self.box:SetText(mode == "code" and self.code or mode == "post" and self.post or self.bountyURL)
      self.copyLabel:SetText(mode == "code" and ns.Locale:Get("shared.exchange.1_copy_the_raw_code_advanced.7a2336") or mode == "post" and ns.Locale:Get("shared.exchange.1_copy_the_bounty_and_description.a1e6f6") or ns.Locale:Get("shared.exchange.1_copy_your_bounty_link.ba0c9e"))
      self.box:SetFocus(); self.box:HighlightText(); self.scroll:SetVerticalScroll(0)
      self:SetStatus(ns.Locale:Get("shared.exchange.text_selected_press_ctrl_c_then_send.fcc8ea"))
      if self.preview then self:SetStatus(ns.Locale:Get("shared.exchange.press_ctrl_c_to_practice_this_sample.e705a9")) end
      LayoutShare(self)
    end
    ns.Core.OnFontScaleChange(function() if w:IsShown() then LayoutShare(w) end end)
  end
  w.code, w.audience, w.channelURL = code, audience, E.URL("board") or E.INVITE
  w.chatPayload = audience ~= "global" and B.Share.Encode(b) or nil
  w.actions.chat:SetShown(audience ~= "global" and (preview or w.chatPayload ~= nil))
  w.actions.options:SetShown(audience == "global")
  w.bountyURL = (E.LINK or "highground://bounty/") .. code:gsub("%+", "-"):gsub("/", "_")
  w.post = ns.Locale:Format("shared.exchange.wanted_value2_value4_posted_by_value6_realmset.e24450", { value2 = ns.Core.DisplayName(b.name), value4 = B.Terms.Summary(b), value6 = ns.Core.DisplayName(b.by), value8 = B.Scope.Label(), value9 = (b.note and b.note ~= "" and (ns.Locale:Format("shared.exchange.note_b_note.c4cb9e", { b_note = b.note })) or ""), w_bountyURL = w.bountyURL })
  if preview then w.post = ns.Locale:Format("shared.exchange.sample_only_nothing_published_w_post.82f268", { w_post = w.post }) end
  ns.Localization.Bind(w.destination, "shared.exchange.2_send_it_the_recipient_imports_it.ce0fdd")
  w.instructions:SetText(preview and ns.Locale:Get("shared.exchange.nothing_is_sent_or_published_return_to.1e883a")
    or ns.Locale:Get("shared.exchange.send_it_in_a_message_or_discord.8cd810"))
  w.hint:SetWordWrap(true)
  w:Open(preview and ns.Locale:Get("shared.exchange.preview_share_bounty.05b14f") or ns.Locale:Get("shared.exchange.share_bounty.e671ea"), ns.Locale:Format("shared.exchange.value1_value3_per_approved_kill_value5.3623d1", { value1 = ns.Core.DisplayName(b.name), value3 = ns.Util.Gold(b.gold), value5 = (preview and ns.Locale:Get("shared.exchange.practice_sharing_this_sample_bounty.fca48a")
      or audience == "global" and ns.Locale:Get("shared.exchange.already_published_in_game_sending_a_link.7204fe")
      or audience == "community" and ns.Locale:Get("shared.exchange.share_with_your_community.e52c71") or audience == "guild" and ns.Locale:Get("shared.exchange.share_with_your_guild.d2bace") or ns.Locale:Get("shared.exchange.share_in_a_private_message.0ea33d")) }), w.bountyURL, true)
  w:SelectPayload("link")
  if not preview then E.copyWin = w end
  return w
end

function E.PreviewShare(b, audience)
  return Share(b, audience, B.Preview.CODE, true)
end

function E.Show(b, audience)
  local code, err = E.Encode(b, audience)
  if not code then B.Say(err); return end
  return Share(b, audience, code)
end

function E.Proof(item)
  local b = item.bounty
  local text = ns.Locale:Format("shared.exchange.target_value2_hunter_value4_ruleset_realm_value6.15651e", { value2 = ns.Core.DisplayName(b.name), value4 = ns.Core.DisplayName(B.Me()), value6 = (item.ruleset or B.Scope.Label()), value8 = date("%Y-%m-%d %H:%M:%S", item.at), value11 = (item.zone or ns.Locale:Get("shared.exchange.unknown.bc7819")), item_evidence = item.evidence, value15 = B.Kills.CauseText(item.cause), value17 = (item.preview and B.Preview.Progress(b) or B.Terms.Progress(b)), value19 = (item.preview and ns.Locale:Get("shared.exchange.simulated_only_no_file_created.534c98")
      or item.screenshot and ns.Locale:Get("shared.exchange.saved_successfully_in_wow_screenshots.dc50d0") or ns.Locale:Get("shared.exchange.not_confirmed_attach_a_screenshot_or_video.5829c6")) })
  if item.global then
    text = ns.Locale:Format("shared.exchange.join_discord_e_invite_post_proof_value4.b922ad", { E_INVITE = E.INVITE, value4 = (E.URL("proof", item.ruleset) or ns.Locale:Get("shared.exchange.choose_your_ruleset_s_proof_channel.1715ed")), text = text })
    for _, p in ipairs(b.contributions or {}) do
      text = ns.Locale:Format("shared.exchange.text_contribution_p_id_poster_value5_value7.fe7d09", { text = text, p_id = p.id, value5 = ns.Core.DisplayName(p.by), value7 = B.Terms.Summary(p) })
    end
  else text = ns.Locale:Format("shared.exchange.text_value3_keep_proof_within_this_bounty.4b8d82", { text = text, value3 = B.Terms.Summary(b) }) end
  if item.preview then text = ns.Locale:Format("shared.exchange.sample_proof_no_kill_recorded_or_screenshot.b761eb", { text = text }) end
  return Copy(item.preview and ns.Locale:Get("shared.exchange.preview_bounty_proof.b64f05") or item.global and ns.Locale:Get("shared.exchange.post_global_bounty_proof.0840b3") or ns.Locale:Get("shared.exchange.bounty_proof.50cee8"), text, nil, item.preview)
end

function E.OpenImport(text, preview)
  local field = preview and "previewImportWin" or "importWin"
  if not E[field] then
    E[field] = Kit.CopyBox((ns.FRAME_PREFIX or "Highground") .. "BountyCodeImport" .. (preview and "Preview" or ""), {
      title = ns.Locale:Get("shared.exchange.import_bounty.224c98"), width = 700, height = 550, strata = "FULLSCREEN_DIALOG", alpha = 1,
      onText = function(w)
        if w.renderingReview then return end
        w.reviewed, w.existing, w.reviewText = nil, nil, nil; w:SetStatus("")
        if w.actions.review then ns.Localization.Bind(w.actions.review, "shared.exchange.review_import.9b66fe") end
      end,
      buttons = { { key = "review", label = ns.Locale:Get("shared.exchange.review_import.9b66fe"), width = 200, onClick = function(w)
        local code = w.reviewed and w:GetText() == w.reviewText and w.reviewed or w:GetText()
        local value, err
        if preview then value, err = B.Preview.DecodeSample(code) else value, err = E.Decode(code) end
        if not value then w:SetStatus(err, "warning"); return end
        local existing = not preview and value.audience ~= "global" and B.Personal()[B.Key(value.bounty.name)] or nil
        if not w.reviewed or w.existing ~= existing then
          w.reviewed, w.existing = code, existing
          w.actions.review:SetText(existing and ns.Locale:Get("shared.exchange.replace_private_bounty.e323d1") or ns.Locale:Get("shared.exchange.confirm_import.4c63db"))
          local notice = value.audience == "global" and ns.Locale:Get("shared.exchange.enable_receiving_import_an_unverified_global_offer.7e835b")
            or (value.audience == "guild" or value.audience == "community") and ns.Locale:Get("shared.exchange.save_as_a_private_draft_organization_approval.38282c") or ns.Locale:Get("shared.exchange.save_for_private_alerts.46a223")
          local b = value.bounty
          local review = ns.Locale:Format("shared.exchange.value1_audience_value3_target_value5_poster_value7.7caeef", { value1 = (preview and ns.Locale:Get("shared.exchange.sample_import_nothing_will_be_saved_or.14523f") or ""), value3 = value.audience:upper(), value5 = ns.Core.DisplayName(b.name), value7 = ns.Core.DisplayName(b.by), value9 = B.Scope.Label(), value11 = B.Terms.Summary(b), value13 = (b.note ~= "" and b.note or ns.Locale:Get("macros.macros.none.6eef66")), value14 = (b.expiresAt and (ns.Locale:Format("shared.exchange.expires_value2_local_time.52cfc4", { value2 = date("%Y-%m-%d %H:%M", b.expiresAt) })) or ""), value15 = (existing and (ns.Locale:Format("shared.exchange.replaces_your_private_bounty_value2_note_value4.294570", { value2 = B.Terms.Summary(existing), value4 = (existing.note or ns.Locale:Get("macros.macros.none.6eef66")) })) or ""), notice = notice, code = code })
          if value.contributions then
            local total, details = 0, ""
            for _, p in ipairs(value.contributions) do
              total = total + p.gold
              details = details .. "\n\n" .. ns.Core.DisplayName(p.by) .. ": " .. B.Terms.Summary(p)
                .. (p.contract and (ns.Locale:Format("shared.exchange.completion_decided_by_value2.c06b7c", { value2 = ns.Core.DisplayName(p.contract.by) })) or "")
            end
            review = ns.Locale:Format("shared.exchange.mega_bounty_value2_per_approved_kill_value4.edd8f3", { value2 = ns.Util.Gold(total), value4 = #value.contributions, details = details, review = review })
          end
          w.renderingReview = true; w.box:SetText(review); w.renderingReview = nil
          w.reviewText = w:GetText(); w.box:ClearFocus(); w.scroll:SetVerticalScroll(0)
          w:SetStatus(ns.Locale:Get("shared.exchange.review_the_details_above_then_confirm_or.41e4bc"), "text")
          return
        end
        if preview then
          B.Preview.Notice(ns.Locale:Get("shared.exchange.sample_import_confirmed_no_real_bounty_or.547705"))
          w:Hide(); return
        end
        local b, message = E.Import(value, w.existing)
        if not b then w:SetStatus(message, "warning"); return end
        w:Hide(); B.Board.Open(); B.Board.SetTab(value.audience == "global" and "public" or "mine"); B.Say(message)
      end } },
    })
    E[field].box:SetMaxLetters((E.POT_MAX or E.MAX) + 8192)
    E[field].status:SetHeight(70); E[field].status:SetJustifyV("BOTTOM")
    E[field].well:ClearAllPoints(); E[field].well:SetPoint("TOPLEFT", 18, -90); E[field].well:SetPoint("BOTTOMRIGHT", -18, 140)
  end
  local w = E[field]
  w.reviewed = nil
  w:Open(preview and ns.Locale:Get("shared.exchange.preview_import_bounty.7dd988") or ns.Locale:Get("shared.exchange.import_bounty.224c98"), ns.Locale:Get("shared.exchange.paste_the_bounty_link_you_received_then.683319"), text or "", false)
  ns.Localization.Bind(w.actions.review, "shared.exchange.review_import.9b66fe"); B.Widgets.ShowWindow(w)
  return w
end

B.Listen("scope", function()
  if E.destinationWin then E.destinationWin:Hide() end
  if E.copyWin then E.copyWin:Hide() end
  if E.shareWin then E.shareWin:Hide() end
  if E.proofWin then E.proofWin:Hide() end
  if E.importWin then E.importWin.reviewed = nil; E.importWin:Hide() end
end)
