local _, ns = ...
local B, Kit, T = ns.Bounty, ns.Kit, ns.Theme
local P, G, View = B.Public, B.Gold, {}
B.GoldView = View

local Text = Kit.Paragraph

function View.Layout(w)
  local scale = ns.Core.FontScale()
  w:SetSize(570 + 180 * (scale - 1), 610 + 220 * (scale - 1))
  if w.preview then w:SetHeight(math.min(w:GetHeight(), UIParent:GetHeight() - 40)) end
  local width = w:GetWidth() - 48
  w.summary:SetWidth(width); w.summary:SetHeight(w.summary:GetStringHeight())
  w.tracking:ClearAllPoints(); w.tracking:SetPoint("TOPLEFT", w.summary, "BOTTOMLEFT", 0, -18)
  w.tracking:SetSize(width, 32 * scale)
  w.requireGold:SetSize(width, 32 * scale)
  w.hint:SetWidth(width); w.hint:SetHeight(w.hint:GetStringHeight())
  w.list.body:SetWidth(width - 24)
  local y = 0
  for _, row in ipairs(w.rows) do
    if row:IsShown() then
      row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -y); row:SetWidth(width - 24)
      row:SetHeight(row:GetStringHeight()); y = y + row:GetHeight() + 18
    end
  end
  w.list.body:SetHeight(math.max(1, y)); w.list:Refresh()
  w.done:SetSize(130 * scale, 32 * scale)
end

function View.Refresh(w)
  w = w or View.win
  if not w then return end
  local sample = w.preview and B.Preview.Wallet()
  local total, available = sample and sample.total or G.Total(), sample and sample.available or P.Available()
  local enabled, required = G.Enabled(), G.Required()
  if sample then enabled, required = sample.enabled, sample.required end
  w.summary:SetText(ns.Locale:Format("shared.goldview.value1_value3_total_value5_available_for_bounties.b2380f", { value1 = B.Scope.Label(), value3 = (enabled and ns.Locale:Get("shared.form.account_gold.d091f7") or ns.Locale:Get("shared.goldview.current_character_only.b1d89a")), value5 = G.Format(total), value7 = G.Format(available), value9 = G.Format(sample and sample.reserved or P.Reserved()) }))
  w.tracking:SetChecked(enabled, true); w.requireGold:SetChecked(required, true)
  w.hint:SetText(ns.Locale:Format("shared.goldview.log_into_each_character_to_record_its.dc0577", { value2 = (required and ns.Locale:Get("shared.goldview.creating_a_bounty_requires_enough_available_gold.e7e2bc") or ns.Locale:Get("shared.goldview.low_gold_shows_a_warning_and_still.0abc64")), value3 = (sample and ns.Locale:Get("shared.goldview.sample_balances_and_switches_your_settings_are.020e80") or "") }))
  local rows = sample and sample.rows or G.Rows()
  for i, data in ipairs(rows) do
    local row = w.rows[i] or Text(w.list.body, "body")
    w.rows[i] = row
    row:SetText(ns.Core.DisplayName(data.name) .. (data.current and ns.Locale:Get("shared.goldview.current_character.647a43") or "")
      .. "\n" .. G.Format(not sample and data.current and G.Current() or data.balance)
      .. (data.current and ns.Locale:Get("shared.goldview.live_balance.a2c8ee") or ns.Locale:Format("shared.goldview.last_recorded_value2.a604e0", { value2 = date("%Y-%m-%d %H:%M", data.seenAt) })))
    row:Show()
  end
  for i = #rows + 1, #w.rows do w.rows[i]:Hide() end
  View.Layout(w)
end

function View.Open(preview)
  local field = preview and "previewWin" or "win"
  local w = View[field]
  if not w then
    w = Kit.Dialog((ns.FRAME_PREFIX or "Highground") .. "BountyGold" .. (preview and "Preview" or ""), {
      title = preview and ns.Locale:Get("shared.goldview.preview_account_gold.526ab9") or ns.Locale:Get("shared.goldview.account_gold.4a40d4"), width = 570, height = 610, header = 64, accent = "gold", alpha = 1,
      strata = "FULLSCREEN_DIALOG", child = true })
    View[field], w.rows, w.preview = w, {}, preview
    w.summary = Text(w, "body"); w.summary:SetPoint("TOPLEFT", 24, -86)
    w.tracking = ns.Localization.BindWidget(Kit.Toggle(w, ns.Locale:Get("shared.goldview.track_gold_across_my_characters.ea24c7"), { width = 510, onChange = function(_, on)
      if preview then B.Preview.state.accountGold = on; View.Refresh(w); return end
      ns.Core.SetOption("bountyAccountGold", on); G.Refresh()
    end }), { label = "shared.goldview.track_gold_across_my_characters.ea24c7" })
    w.requireGold = ns.Localization.BindWidget(Kit.Toggle(w, ns.Locale:Get("shared.goldview.require_enough_gold_before_creating_a_bounty.c66298"), { width = 510, onChange = function(_, on)
      if preview then B.Preview.state.requireGold = on; View.Refresh(w); return end
      ns.Core.SetOption("bountyRequireGold", on); G.Refresh()
    end }), { label = "shared.goldview.require_enough_gold_before_creating_a_bounty.c66298" })
    w.requireGold:SetPoint("TOPLEFT", w.tracking, "BOTTOMLEFT", 0, -8)
    Kit.Tooltip(w.tracking, function() return { ns.Locale:Get("shared.form.account_gold.d091f7"), ns.Locale:Get("shared.goldview.on_by_default_count_the_last_recorded.4551c5") } end)
    Kit.Tooltip(w.requireGold, function() return { ns.Locale:Get("shared.goldview.require_enough_gold.ab1748"), ns.Locale:Get("shared.goldview.off_by_default_when_off_insufficient_or.bb5e51") } end)
    w.hint = Text(w, "bodySmall", "textMuted"); w.hint:SetPoint("TOPLEFT", w.requireGold, "BOTTOMLEFT", 0, -14)
    w.list = Kit.ScrollArea(w); w.list:SetPoint("TOPLEFT", w.hint, "BOTTOMLEFT", 0, -20)
    w.list:SetPoint("BOTTOMRIGHT", -24, 76)
    w.done = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("shared.form.return.24f096"), 130, 32, { onClick = function() w:Hide() end }), "shared.form.return.24f096")
    w.done:SetPoint("BOTTOMRIGHT", -24, 22)
    ns.Core.OnFontScaleChange(function() View.Refresh(w) end)
    T.OnChange(function() View.Refresh(w) end)
  end
  View.Refresh(w); B.Widgets.ShowWindow(w); return w
end
