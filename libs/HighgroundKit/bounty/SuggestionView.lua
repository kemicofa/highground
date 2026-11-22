local _, ns = ...
local B, Kit, T = ns.Bounty, ns.Kit, ns.Theme
local S, P = B.Suggestions, B.Public
local V = {}
S.View = V
local PREFIX = ns.FRAME_PREFIX or "Highground"

function V.Hide(name)
  local w = V.toast
  if w and (not name or w.entry and B.Key(w.entry.name) == B.Key(name)) then w:Hide(); w.entry = nil end
end

function V.Review(name)
  V.Hide(name)
  local scope = S.Existing(name)
  if scope then
    B.Board.SetTab(scope); B.Board.Open()
    for _, row in ipairs(B.BoardModel.Rows(scope)) do
      if B.Key(row.name) == B.Key(name) then B.Details.Open(row); return end
    end
    return
  end
  for _, row in ipairs(S.Rows()) do
    if B.Key(row.name) == B.Key(name) then
      local w = B.Form.Open(row.name, row.mode)
      w:SetTitle(ns.Locale:Get("shared.suggestionview.review_bounty.f4228b"))
      w.gold:SetText(""); w.note:SetText(S.Reason(row))
      w.suggestionTarget = row.name
      return
    end
  end
  B.Say(ns.Locale:Get("shared.suggestionview.these_reports_have_expired_or_the_suggestion.04ecd9"))
end

function V.Tooltip(r)
  local lines = { { ns.Core.DisplayName(r.name), "gold" }, { r.status, "text", true },
    { ns.Locale:Format("shared.suggestionview.your_deaths_r_personal_guild_r_guilddeaths.beb130", { r_personal = r.personal, r_guildDeaths = r.guildDeaths, r_guildVictimCount = r.guildVictimCount }), "text", true },
    { ns.Locale:Get("shared.suggestionview.reports_from_participating_players_not_server_verified.f5c3c3"), "textMuted", true } }
  if r.existing then lines[#lines + 1] = { ns.Locale:Get("shared.suggestionview.a_bounty_already_exists_review_opens_that.0fec65"), "gold", true } end
  return lines
end

local function Evidence(r)
  local lines = { ns.Core.DisplayName(r.name), "", ns.Locale:Format("shared.suggestionview.r_total_reported_deaths_in_the_last.5920af", { r_total = r.total, value3 = (S.Window() / 60) }),
    ns.Locale:Format("shared.suggestionview.you_r_personal_guild_r_guilddeaths_deaths.ecdb3a", { r_personal = r.personal, r_guildDeaths = r.guildDeaths, r_guildVictimCount = r.guildVictimCount }),
    ns.Locale:Get("shared.suggestionview.reports_from_participating_players_not_server_verified.5d7387"), "" }
  local victims = {}
  for name, count in pairs(r.victims) do victims[#victims + 1] = ns.Core.DisplayName(name) .. ": " .. count end
  table.sort(victims)
  for _, line in ipairs(victims) do lines[#lines + 1] = line end
  lines[#lines + 1] = ""
  table.sort(r.reports, function(a, b) return a.at > b.at end)
  for _, e in ipairs(r.reports) do
    lines[#lines + 1] = B.Widgets.Ago(P.Now() - e.at) .. " · " .. e.victim .. " · " .. e.zone
      .. " (" .. (e.source == "recap" and ns.Locale:Get("shared.suggestionview.death_recap.110a82") or ns.Locale:Get("shared.suggestionview.fatal_combat_damage.016923")) .. ")"
  end
  return table.concat(lines, "\n")
end

function V.Render(r, preview, state)
  local field = preview and "previewWin" or "details"
  if not V[field] then
    local w = Kit.Dialog(PREFIX .. "BountySuggestionReports" .. (preview and "Preview" or ""), {
      title = preview and ns.Locale:Get("shared.suggestionview.preview_death_reports.a25f12") or ns.Locale:Get("shared.suggestionview.death_reports.237a3d"), width = 640, height = 500,
      header = 60, accent = "gold", alpha = 1, strata = "FULLSCREEN_DIALOG", child = preview })
    V[field] = w
    w.reports = Kit.ScrollText(w)
    w.reports:SetPoint("TOPLEFT", 24, -78); w.reports:SetPoint("BOTTOMRIGHT", -26, 116)
    w.scroll, w.body, w.text = w.reports.view, w.reports.body, w.reports.text
    w.review = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("shared.boardactions.review_bounty.1d4814"), 176, 30, { onClick = function()
      if preview then return B.Preview.OpenCreate("personal", ns.Locale:Get("shared.suggestionview.suggested_after_5_sample_death_reports_near.c021dc")) end
      if w.entry then V.Review(w.entry.name) end
    end }), "shared.boardactions.review_bounty.1d4814")
    w.dismiss = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("shared.suggestionview.dismiss_24h.1295ba"), 130, 30, { onClick = function()
      if preview then B.Preview.Notice(ns.Locale:Get("shared.suggestionview.sample_suggestion_dismissed_for_24_hours_real.36c1bb")); w:Hide(); return end
      if w.entry then S.Change(w.entry.name, "dismiss"); w:Hide() end
    end }), "shared.suggestionview.dismiss_24h.1295ba")
    w.ignore = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("shared.suggestionview.ignore_enemy.851647"), 130, 30, { onClick = function()
      if preview then B.Preview.Notice(ns.Locale:Get("shared.suggestionview.sample_enemy_ignored_real_suggestions_are_unchanged.5236b7")); w:Hide(); return end
      if w.entry then S.Change(w.entry.name, w.entry.ignored and "allow" or "ignore"); w:Hide() end
    end }), "shared.suggestionview.ignore_enemy.851647")
    w.back = Kit.Button(w, preview and ns.Locale:Get("shared.form.return.24f096") or ns.Locale:Get("shared.board.back_to_board.c4cc8d"), 150, 28, { onClick = function() w:Hide() end })
    w.back:SetPoint("BOTTOMLEFT", 24, 18)
    Kit.Tooltip(w.back, function() return { ns.Locale:Get("shared.ledger.back_to_the_bounty_board.ea51fe"), ns.Locale:Get("shared.suggestionview.return_to_your_suggestions_without_dismissing_reports.57d2c3") } end)
    function w:Layout()
      local scale = math.max(1, ns.Core.FontScale())
      if not self.bountyPage then self:SetSize(640 * scale, 500 + (scale - 1) * 180) end
      self.back:SetWidth(150 * scale)
      Kit.LayoutGrid({ self.review, self.dismiss, self.ignore }, { width = self:GetWidth() - 48,
        columns = 3, height = 30 * scale, x = 24, y = 62, anchor = "BOTTOMLEFT" })
      self.reports:Refresh()
    end
    w.LayoutPage = w.Layout
    Kit.Tooltip(w.review, function() return { ns.Locale:Get("shared.boardactions.review_bounty.1d4814"), ns.Locale:Get("shared.suggestionview.open_the_existing_bounty_or_review_a.8484a8") } end)
    Kit.Tooltip(w.dismiss, function() return { ns.Locale:Get("shared.suggestionview.dismiss_for_24_hours.ecf378"), ns.Locale:Get("shared.suggestionview.hide_this_target_s_suggestions_for_one.5934a2") } end)
    Kit.Tooltip(w.ignore, function() return { ns.Locale:Get("shared.suggestionview.ignore_or_allow_this_enemy.17377d"), ns.Locale:Get("shared.suggestionview.ignored_enemies_stay_hidden_until_you_choose.e4e90e") } end)
    ns.Core.OnFontScaleChange(function() if w:IsShown() then w:Layout() end end)
  end
  local w = V[field]
  w.entry = r; w.reports:SetText(Evidence(r)); w:Layout(); w.reports:Scroll(0)
  w.review:SetEnabled(not r.ignored); w.dismiss:SetEnabled(not r.ignored)
  w.ignore:SetText(r.ignored and ns.Locale:Get("shared.boardactions.allow_again.a84070") or ns.Locale:Get("shared.suggestionview.ignore_enemy.851647"))
  if preview then B.Widgets.ShowWindow(w) else B.Navigation.Mount(w) end
  if state then w.reports:Scroll(state.scroll or 0) end
  return w
end

function V.Details(r, preview)
  if preview then return V.Render(r, true) end
  return B.Navigation.Open("suggestion", { name = r.name })
end

local function Toast()
  if V.toast then return V.toast end
  local w = ns.Localization.BindWidget(Kit.Dialog(PREFIX .. "BountySuggestion", { title = ns.Locale:Get("shared.suggestionview.bounty_suggestion.570bc5"), width = 560, height = 248,
    header = 54, accent = "gold", savedKey = "bountySuggestion", point = { "TOPRIGHT", "TOPRIGHT", -36, -180 } }), { title = "shared.suggestionview.bounty_suggestion.570bc5" })
  V.toast = w
  w.body = T.Text(w, "body", "text"); w.body:SetJustifyH("LEFT"); w.body:SetJustifyV("TOP"); w.body:SetWordWrap(true)
  w.body:SetPoint("TOPLEFT", 22, -70); w.body:SetPoint("RIGHT", -22, 0)
  w.review = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("shared.boardactions.review_bounty.1d4814"), 160, 30, { onClick = function() if w.entry then V.Review(w.entry.name) end end }), "shared.boardactions.review_bounty.1d4814")
  w.dismiss = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("shared.suggestionview.dismiss_24h.1295ba"), 140, 30, { onClick = function() if w.entry then S.Change(w.entry.name, "dismiss") end end }), "shared.suggestionview.dismiss_24h.1295ba")
  w.ignore = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("shared.suggestionview.ignore_enemy.851647"), 140, 30, { onClick = function() if w.entry then S.Change(w.entry.name, "ignore") end end }), "shared.suggestionview.ignore_enemy.851647")
  Kit.Tooltip(w.review, function() return { ns.Locale:Get("shared.boardactions.review_bounty.1d4814"), ns.Locale:Get("shared.suggestionview.review_a_prefilled_draft_with_an_optional.fe2200") } end)
  Kit.Tooltip(w.dismiss, function() return { ns.Locale:Get("shared.suggestionview.dismiss_for_24_hours.ecf378"), ns.Locale:Get("shared.suggestionview.hide_suggestions_for_this_enemy_for_one.144726") } end)
  Kit.Tooltip(w.ignore, function() return { ns.Locale:Get("shared.suggestionview.ignore_this_enemy.55a120"), ns.Locale:Get("shared.suggestionview.stop_suggestions_for_this_enemy_use_show.4c226c") } end)
  function w:Layout()
    local scale = math.max(1, ns.Core.FontScale())
    self:SetSize(560 * scale, 248 + (scale - 1) * 170); self.body:SetHeight(122 * scale)
    Kit.LayoutGrid({ self.review, self.dismiss, self.ignore }, { width = self:GetWidth() - 44,
      columns = 3, height = 30 * scale, x = 22, y = 20, anchor = "BOTTOMLEFT" })
  end
  w:Layout(); ns.Core.OnFontScaleChange(function() w:Layout() end)
  return w
end

local function Fill(w, r)
  w.entry = r
  w.body:SetText(ns.Locale:Format("shared.suggestionview.value1_r_total_reported_deaths_in_value5.c1b3b7", { value1 = ns.Core.DisplayName(r.name), r_total = r.total, value5 = (S.Window() / 60), r_personal = r.personal, r_guildDeaths = r.guildDeaths, r_guildVictimCount = r.guildVictimCount, value13 = (r.zone or ns.Locale:Get("shared.sightings.unknown_location.4f20e4")) }))
end

function V.Notify(r)
  if V.toast and V.toast:IsShown() or B.Widgets.HasOpenWindow() then return false end
  local w = Toast()
  Fill(w, r); w.untilTime = GetTime() + 20; w:Show()
  return true
end

function V.Update(rows)
  local w = V.toast
  if not w or not w:IsShown() then return end
  if ns.Util.read(InCombatLockdown) or not ns.Nearby.InWorld() or GetTime() >= w.untilTime then V.Hide(); return end
  for _, r in ipairs(rows) do
    if w.entry and B.Key(r.name) == B.Key(w.entry.name) and not r.existing then Fill(w, r); return end
  end
  V.Hide()
end
