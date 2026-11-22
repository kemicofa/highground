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

-- Gold and theme changes reach a hidden window too; Open refreshes it.
function View.Refresh(w, force)
  w = w or View.win
  if not w or not force and not w:IsShown() then return end
  local sample = w.preview and B.Preview.Wallet()
  local total, available = sample and sample.total or G.Total(), sample and sample.available or P.Available()
  local enabled, required = G.Enabled(), G.Required()
  if sample then enabled, required = sample.enabled, sample.required end
  w.summary:SetText(B.Scope.Label() .. " · " .. (enabled and "Account gold" or "Current character only")
    .. "\nTotal: " .. G.Format(total) .. "\nAvailable for bounties: " .. G.Format(available)
    .. "\nCommitted: " .. G.Format(sample and sample.reserved or P.Reserved()))
  w.tracking:SetChecked(enabled, true); w.requireGold:SetChecked(required, true)
  w.hint:SetText("Log into each character to record its gold. Alts show their last recorded balance. Gold stays on each character; transfer it before paying a hunter."
    .. (required and "\nCreating a bounty requires enough available gold." or "\nLow gold shows a warning and still allows creation.")
    .. (sample and "\nSample balances and switches; your settings are unchanged." or ""))
  local rows = sample and sample.rows or G.Rows()
  for i, data in ipairs(rows) do
    local row = w.rows[i] or Text(w.list.body, "body")
    w.rows[i] = row
    row:SetText(ns.Core.DisplayName(data.name) .. (data.current and " · Current character" or "")
      .. "\n" .. G.Format(not sample and data.current and G.Current() or data.balance)
      .. (data.current and " · Live balance" or " · Last recorded " .. date("%Y-%m-%d %H:%M", data.seenAt)))
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
      title = preview and "PREVIEW · ACCOUNT GOLD" or "ACCOUNT GOLD", width = 570, height = 610, header = 64, accent = "gold", alpha = 1,
      strata = "FULLSCREEN_DIALOG", child = true })
    View[field], w.rows, w.preview = w, {}, preview
    w.summary = Text(w, "body"); w.summary:SetPoint("TOPLEFT", 24, -86)
    w.tracking = Kit.Toggle(w, "Track gold across my characters", { width = 510, onChange = function(_, on)
      if preview then B.Preview.state.accountGold = on; View.Refresh(w); return end
      ns.Core.SetOption("bountyAccountGold", on); G.Refresh()
    end })
    w.requireGold = Kit.Toggle(w, "Require enough gold before creating a bounty", { width = 510, onChange = function(_, on)
      if preview then B.Preview.state.requireGold = on; View.Refresh(w); return end
      ns.Core.SetOption("bountyRequireGold", on); G.Refresh()
    end })
    w.requireGold:SetPoint("TOPLEFT", w.tracking, "BOTTOMLEFT", 0, -8)
    Kit.Tooltip(w.tracking, { "Account gold", "On by default. Count the last recorded gold on characters in this realm or Forever realmset. Turning this off uses only your current character's gold." })
    Kit.Tooltip(w.requireGold, { "Require enough gold", "Off by default. When off, insufficient or unreadable gold warns but does not block creation. When on, the available total must cover the reward after existing commitments." })
    w.hint = Text(w, "bodySmall", "textMuted"); w.hint:SetPoint("TOPLEFT", w.requireGold, "BOTTOMLEFT", 0, -14)
    w.list = Kit.ScrollArea(w); w.list:SetPoint("TOPLEFT", w.hint, "BOTTOMLEFT", 0, -20)
    w.list:SetPoint("BOTTOMRIGHT", -24, 76)
    w.done = Kit.Button(w, "Return", 130, 32, { onClick = function() w:Hide() end })
    w.done:SetPoint("BOTTOMRIGHT", -24, 22)
    ns.Core.OnFontScaleChange(function() View.Refresh(w) end)
    T.OnChange(function() View.Refresh(w) end)
  end
  View.Refresh(w, true); B.Widgets.ShowWindow(w); return w
end
