local _, ns = ...
local B, P, Kit, T = ns.Bounty, ns.Bounty.Public, ns.Kit, ns.Theme
local Pref = {}
B.Preferences = Pref

function Pref.Build(preview)
  local field = preview and "previewWin" or "win"
  if Pref[field] then return Pref[field] end
  local w = Kit.Dialog((ns.FRAME_PREFIX or "Highground") .. "BountyPreferences" .. (preview and "Preview" or ""), {
    title = preview and ns.Locale:Get("shared.preferences.preview_shared_alerts.a01490") or ns.Locale:Get("shared.preferences.shared_alert_settings.73dcea"), width = 570, height = 450,
    header = 64, accent = "gold", alpha = 1, strata = "FULLSCREEN_DIALOG", child = preview })
  Pref[field] = w
  w.receive = ns.Localization.BindWidget(Kit.Toggle(w, ns.Locale:Get("shared.board.browse_shared_bounties.a74539"), { width = 510, onChange = function(_, on)
    if preview then B.Preview.state.receive = on; return end
    ns.Core.SetOption("bountyReceive", on); P.TransportTick(); B.Board.Refresh()
  end }), { label = "shared.board.browse_shared_bounties.a74539" })
  w.receive:SetPoint("TOPLEFT", 24, -90)
  Kit.Tooltip(w.receive, function() return { ns.Locale:Get("shared.board.join_the_shared_board.fd8f75"), ns.Locale:Get("shared.preferences.receive_contributions_from_participating_players_on_your.4b4445") } end)
  w.threshold = ns.Localization.BindWidget(Kit.Input(w, 230, ns.Locale:Get("shared.preferences.notify_me_from_gold.090c60")), { caption = "shared.preferences.notify_me_from_gold.090c60" }); w.threshold:SetPoint("TOPLEFT", 24, -170)
  local function Save(self)
    local value = tonumber(self:GetText())
    if P.Integer(value, 0, 999999999) then
      w.status:SetText("")
      if preview then B.Preview.state.minGold = value
      else ns.Core.SetOption("bountyMinGold", value); B.Board.Refresh() end
    else ns.Localization.Bind(w.status, "shared.preferences.enter_a_whole_gold_amount_from_0.8ef1e2") end
  end
  w.threshold:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  w.threshold:HookScript("OnEditFocusGained", function(self) self.editing = true end)
  w.threshold:HookScript("OnEditFocusLost", function(self) self.editing = nil; Save(self) end)
  Kit.Tooltip(w.threshold, function() return { ns.Locale:Get("shared.preferences.notification_minimum.7f0154"), ns.Locale:Get("shared.preferences.only_the_combined_reward_with_recent_available.6ad07d") } end)
  w.hint = T.Text(w, "body", "textMuted")
  w.hint:SetPoint("TOPLEFT", 24, -212); w.hint:SetPoint("RIGHT", -24, 0); w.hint:SetHeight(72)
  w.hint:SetJustifyH("LEFT"); w.hint:SetJustifyV("TOP")
  ns.Localization.Bind(w.hint, "shared.preferences.this_only_changes_notifications_smaller_rewards_remain.6e4dd3")
  w.publishOptIn = ns.Localization.BindWidget(Kit.Toggle(w, ns.Locale:Get("shared.preferences.advertise_my_shared_bounties.d92e87"), { width = 510, onChange = function(_, on)
    if preview then B.Preview.state.publish = on; return end
    ns.Core.SetOption("bountyPublish", on); P.TransportTick(); B.Form.Refresh(); B.Board.Refresh()
  end }), { label = "shared.preferences.advertise_my_shared_bounties.d92e87" })
  w.publishOptIn:SetPoint("TOPLEFT", 24, -300)
  Kit.Tooltip(w.publishOptIn, function() return { ns.Locale:Get("shared.preferences.advertise_your_contributions.563924"), ns.Locale:Get("shared.preferences.publishing_a_bounty_enables_this_automatically_with.d755ef") } end)
  w.status = T.Text(w, "body", "warning")
  w.status:SetPoint("BOTTOMLEFT", 24, 64); w.status:SetPoint("RIGHT", -24, 0); w.status:SetJustifyH("LEFT")
  w.done = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("shared.preferences.save_return.a31ac2"), 170, 32, { onClick = function() Save(w.threshold); if w.status:GetText() == "" then w:Hide() end end }), "shared.preferences.save_return.a31ac2")
  w.done:SetPoint("BOTTOMRIGHT", -24, 22)
  Kit.Tooltip(w.done, function() return { ns.Locale:Get("shared.preferences.save_alert_preferences.a07bcb"), ns.Locale:Get("shared.preferences.save_your_notification_minimum_and_return_to.4e71c7") } end)
  if preview then
    local function Layout()
      local scale = ns.Core.FontScale()
      w:SetSize(570 + (scale - 1) * 260, math.min(450 + (scale - 1) * 240, UIParent:GetHeight() - 40))
      w.hint:SetHeight(w.hint:GetStringHeight())
      w.publishOptIn:ClearAllPoints(); w.publishOptIn:SetPoint("TOPLEFT", w.hint, "BOTTOMLEFT", 0, -18)
      for _, button in ipairs({ w.receive, w.publishOptIn }) do button:SetSize(w:GetWidth() - 48, 32 * scale) end
      w.done:SetSize(w.done.label:GetStringWidth() + 24, 32 * scale)
    end
    Layout(); ns.Core.OnFontScaleChange(Layout)
  end
  return w
end

function Pref.Render(preview, state)
  local w, sample = Pref.Build(preview), preview and B.Preview.Ensure()
  w.receive:SetChecked(sample and sample.receive or not sample and P.Receiving(), true)
  w.publishOptIn:SetChecked(sample and sample.publish or not sample and P.Publishing(), true)
  w.threshold:SetText(tostring(sample and sample.minGold or ns.Core.O("bountyMinGold") or 0)); w.status:SetText("")
  if state then w.threshold:SetText(state.threshold) end
  if preview then B.Widgets.ShowWindow(w) else B.Navigation.Mount(w) end
  return w
end

function Pref.Open(preview)
  if preview then return Pref.Render(true) end
  return B.Navigation.Open("preferences")
end
