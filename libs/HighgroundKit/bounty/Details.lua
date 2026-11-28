local _, ns = ...
local B, P, Kit, T = ns.Bounty, ns.Bounty.Public, ns.Kit, ns.Theme
local D = {}
B.Details = D
local SCOPES = ns.Localization.Define({ mine = ns.Locale:Get("shared.board.my_bounties.8513d0"),  public = ns.Locale:Get("shared.board.shared_board.4b49e6") }, { guild = "shared.board.guild_communities.a49fce", mine = "shared.board.my_bounties.8513d0", public = "shared.board.shared_board.4b49e6" })

local function Current()
  return D.preview or B.BoardModel.Find(D.scope, D.name, D.organization)
end

local FUNDS = { available = "bounty.funds.available", insufficient = "bounty.funds.insufficient", unknown = "bounty.funds.unknown" }

local function Fact(facts, key, value)
  if value and value ~= "" then facts[#facts + 1] = { ns.Locale:Get(key), value } end
end

-- "Wed, 18:40 · 4d 8h left"
local function Expiry(at)
  return ns.Locale:Format("bounty.fact.expires_value", { when = ns.Util.When(at), left = P.Remaining(at) })
end

-- One card per reward. facts: the contract's label/value rows; detail: an
-- explanation below them.
local function Entries(b)
  local out = {}
  local function Entry(source, audience, facts, detail)
    local rows = {}
    Fact(rows, "bounty.fact.progress", D.preview and B.Preview.Progress(source, true) or B.Terms.ProgressValue(source))
    Fact(rows, "bounty.fact.posted_by", ns.Core.DisplayName(source.by or "?", true))
    for _, fact in ipairs(facts or {}) do rows[#rows + 1] = fact end
    Fact(rows, "bounty.fact.finish", B.Terms.Methods(source))
    B.Sightings.Facts(source, rows)
    local last = not D.preview and B.Kills.Latest(source.name)
    if last then Fact(rows, "bounty.fact.last_kill", B.Kills.CauseText(last.cause) .. " · " .. ns.Util.When(last.killedAt)) end
    out[#out + 1] = {
      source = source,
      bounty = { name = b.name, class = b.class or source.class, gold = source.gold, note = source.note, killsRequired = B.Terms.Count(source), killMethods = source.killMethods },
      audience = audience, facts = rows, detail = detail or "",
    }
  end
  local function Offer(p)
    local guild = b.guild and b.guild.publicID == p.id and b.guild
    local audience = guild and (guild.state == "pending" and ns.Locale:Get("shared.details.shared_organization_approval_pending.0c5144") or (ns.Locale:Format("shared.details.value1_shared_approved.b4f3e1", { value1 = B.Organizations.Label(guild) })))
      or ({ private = ns.Locale:Get("shared.details.private.237dfa"), guild = "Guild", community = B.Organizations.Label(p), global = ns.Locale:Get("shared.form.shared.50d0d8") })[B.Pot.Audience(p)]
    local facts = {}
    Fact(facts, "bounty.fact.funds", ns.Locale:Get(FUNDS[P.Funds(p)]))
    Fact(facts, "bounty.fact.expires", Expiry(p.expiresAt))
    if p.contract then Fact(facts, "bounty.fact.reviewed_by", ns.Core.DisplayName(p.contract.by)) end
    Entry(p, audience, facts)
  end
  if b.pot and (#b.pot.contributions > 1 or b.personal and b.pot.contributions[1] ~= b.personal) then
    for _, p in ipairs(b.pot.contributions) do
      if p.id then Offer(p)
      else
        Entry(p, B.Pot.Audience(p) == "private" and ns.Locale:Get("shared.details.private.237dfa") or B.Organizations.Label(p),
          { { ns.Locale:Get("bounty.fact.expires"), Expiry(B.Pot.Expires(p)) } }, ns.Locale:Get("bounty.details.poster_decides"))
      end
    end
  elseif b.shared then for _, p in ipairs(b.shared.contributions) do Offer(p) end
  elseif b.offer then Offer(b.offer)
  else
    local source = b.guild or b.personal
    local detail = ns.Locale:Get("shared.details.private_target_for_your_own_alerts.686956")
    if b.guild then
      detail = (b.guild.state == "pending" and ns.Locale:Get("shared.details.awaiting_moderator_approval.ab7680") or ns.Locale:Get("shared.details.organization_approved.70f51b"))
        .. (b.guild.approver and (ns.Locale:Format("shared.details.by_value2.242709", { value2 = ns.Core.DisplayName(b.guild.approver, true) })) or "")
        .. "\n" .. (b.guild.publicID and ns.Locale:Get("shared.details.waiting_for_contribution_details_use_refresh_on.633b51") or ns.Locale:Get("shared.details.gold_payment_is_arranged_with_the_poster.f9d406"))
    end
    Entry(source, b.visibility, nil, detail)
  end
  return out
end

local function Report(b)
  return B.BoardActions.Report(b)
end

local function Actions(b)
  local actions, manage = {}, {}
  -- subject: the record a confirmed action changes, so an arm never
  -- carries over to a different record with the same label.
  local function Add(label, run, help, secondary, confirm, subject)
    local list = secondary and manage or actions
    list[#list + 1] = { label = label, run = run, help = help, secondary = secondary,
      confirm = confirm and ns.Locale:Get(confirm), subject = subject }
  end
  local report = B.Ledger.ForBounty(b)
  local own = B.Pot.Own(b.name)
  local source = own or b.offer or b.guild or b.personal
    or b.shared and b.shared.contributions[1]
  local canReport = false
  for _, reward in ipairs(b.pot and b.pot.contributions or {}) do
    if reward.by ~= B.Me() and (not reward.id or not P.Mine(reward)) and reward.state ~= "pending" then canReport = true end
  end
  if report then
    Add(B.BoardActions.Primary(b), function() return B.BoardActions.Run(nil, b) end, B.BoardActions.Help(b))
  elseif b.guild and b.guild.state == "pending" and B.IsOfficer(nil, b.guild) then
    Add(ns.Locale:Get("shared.details.approve_bounty.9c8d68"), function() return B.BoardActions.Run(nil, b) end, ns.Locale:Get("shared.details.approve_this_submission_for_your_organization.cdbe32"))
  elseif canReport then
    Add(ns.Locale:Get("highground.coachbountysamples.claim_reward.c3e030"), function() return Report(b) end, ns.Locale:Get("shared.details.report_a_kill_if_automatic_detection_missed.7c2522"))
  end
  if source then
    Add(ns.Locale:Get("highground.coachbounties.share_bounty.94e67c"), function() B.Exchange.Show(source, B.Pot.Audience(source)); return true end,
      ns.Locale:Get("shared.details.copy_a_bounty_link_to_send_to.a1ba03"))
  end
  if own and (not own.id or P.CanManage(own)) then
    Add(ns.Locale:Get("highground.coachbountysamples.edit_reward.0854ae"), function()
      if own.contract or own.state ~= "personal" and not own.id then B.Pot.Open(own)
      else B.Form.Open(b.name, own.id and "public" or "personal", own) end
      return true
    end, ns.Locale:Get("shared.details.change_your_reward_published_completion_terms_stay.427698"))
  end
  if not own then
    local tracking = B.Matches.Tracking(b)
    Add(tracking and ns.Locale:Get("highground.coachbountysamples.stop_tracking.888c9a") or ns.Locale:Get("highground.coachbountysamples.start_tracking.9d94fe"), function()
      B.Matches.Set(b.name, tracking and "ignored" or "tracking"); return true
    end, ns.Locale:Get("shared.details.sighting_alerts_cost_no_gold_detected_kills.861b6c"))
  end
  if not report and not canReport then
    Add(ns.Locale:Get("shared.board.claims_payments.f83748"), function() B.Ledger.Open(b.name); return true end, ns.Locale:Get("shared.details.review_hunters_claims_and_record_payments_after.590a52"))
  end
  if report and canReport then
    Add(ns.Locale:Get("shared.details.report_a_missed_kill.54d958"), function() return B.BoardActions.Report(b, true) end, ns.Locale:Get("shared.details.only_for_a_different_kill_that_was.d73419"), true)
  end
  if own then
    local tracking = B.Matches.Tracking(b)
    Add(tracking and ns.Locale:Get("highground.coachbountysamples.stop_tracking.888c9a") or ns.Locale:Get("highground.coachbountysamples.start_tracking.9d94fe"), function()
      B.Matches.Set(b.name, tracking and "ignored" or "tracking"); return true
    end, ns.Locale:Get("shared.details.turn_sighting_alerts_on_or_off_without.228ac6"), true)
    if not own.contract and (not own.id or P.CanManage(own)) then
      Add(ns.Locale:Get("shared.details.change_audience.c4df26"), function() B.Form.Open(b.name, "public", own); return true end,
        ns.Locale:Get("shared.details.review_publication_on_the_shared_board_or.c8dcf3"), true)
    end
  end
  if b.offer and P.CanManage(b.offer) then
    Add(ns.Locale:Get("shared.details.withdraw_reward.7ff437"), function() local p, err = P.Withdraw(b.offer); return p ~= nil, err end,
      ns.Locale:Get("shared.details.stop_future_hunts_existing_claims_and_payments.8aaee0"), true, "bounty.confirm.withdraw", "offer:" .. tostring(b.offer.id))
  elseif b.guild and (b.guild.by == B.Me() or B.IsOfficer(nil, b.guild)) then
    local pending = b.guild.state == "pending"
    Add(pending and ns.Locale:Get("shared.details.reject_withdraw.4f7350") or ns.Locale:Get("shared.details.remove_bounty.6427cd"), function()
      local removed, err = B.Remove(b.name, "guild", b.guild.organization); B.Emit("updated"); return removed ~= nil, err
    end, ns.Locale:Get("shared.details.remove_this_organization_listing_existing_claims_are.78a201"), true,
      pending and "bounty.confirm.reject" or "bounty.confirm.remove", "guild:" .. tostring(b.guild.organization or "guild"))
  elseif b.personal then
    Add(ns.Locale:Get("shared.details.remove_bounty.6427cd"), function() local removed, err = B.Remove(b.name, "personal"); B.Emit("updated"); return removed ~= nil, err end,
      ns.Locale:Get("shared.details.remove_this_private_target_existing_claims_are.c20326"), true, "bounty.confirm.remove", "personal")
  end
  for _, action in ipairs(manage) do actions[#actions + 1] = action end
  return actions
end

local function ConfirmKey(action) return tostring(D.name) .. "\n" .. (action.subject or action.label) end

-- Status feedback; a confirmation prompt is remembered so it can be cleared
-- once nothing is armed (another action, a changed record or hiding).
local function Status(w, text, tone, prompt)
  Kit.StatusText(w.status, text, tone)
  w.prompting = prompt or nil
end

local function Card(w, i)
  if w.cards[i] then return w.cards[i] end
  local r = B.Wanted.Build(w.body)
  r.fullPoster = true
  r.addGold = ns.Localization.Bind(Kit.Button(r, ns.Locale:Get("shared.details.add_gold.f9a980"), 180, 28, { tone = "posterSecondary", onClick = function()
    if not r.source then return end
    if D.preview then
      if D.previewActions and D.previewActions.addGold then D.previewActions.addGold(r.source) end
    else B.Pot.Open(r.source) end
  end }), "shared.details.add_gold.f9a980")
  w.cards[i] = r
  return r
end

function D.Layout(w)
  if w:IsShown() and not w.refreshing then return D.Refresh() end
  local extra = math.max(0, ns.Core.FontScale() - 1)
  local scale = 1 + extra
  if not w.bountyPage then w:SetSize(math.min(540 + extra * 180, UIParent:GetWidth() - 48), math.min(740, UIParent:GetHeight() - 48)) end
  local available = w:GetWidth() - 48
  w.back:SetSize(w.back.label:GetStringWidth() + 28, 32 * scale)
  local footer = 22 + w.back:GetHeight() + 14
  w.management:SetItems(w.manageActions)
  local managementHeight = w.management:Layout(available)
  Kit.Place(w.management, "BOTTOMLEFT", w, "BOTTOMLEFT", 24, footer)
  w.manageLabel:SetShown(managementHeight > 0)
  if managementHeight > 0 then
    footer = footer + managementHeight + 8
    Kit.Place(w.manageLabel, "BOTTOMLEFT", w, "BOTTOMLEFT", 24, footer, available, 0)
    w.manageLabel:SetHeight(math.ceil(w.manageLabel:GetStringHeight()) + 2)
    footer = footer + w.manageLabel:GetHeight() + 14
  end
  local feedback = w.status:GetText() ~= "" and (40 + extra * 20) or 0
  Kit.Place(w.status, "BOTTOMLEFT", w, "BOTTOMLEFT", 24, footer, available, feedback)
  w.status:SetShown(feedback > 0)
  footer = footer + feedback
  local top = 116 + extra * 18
  w.actionArea:SetItems(w.mainActions)
  local actionHeight = w.actionArea:Layout(available)
  Kit.Place(w.actionArea, "TOPLEFT", w, "TOPLEFT", 24, -top)
  top = top + (actionHeight > 0 and actionHeight + 16 or 0)
  Kit.Place(w.area, "TOPLEFT", w, "TOPLEFT", 24, -top, w:GetWidth() - 50, math.max(1, w:GetHeight() - top - footer))
  w.body:SetWidth(w:GetWidth() - 66)
end

function D.Build()
  if D.win then return D.win end
  local w = ns.Localization.BindWidget(Kit.Dialog((ns.FRAME_PREFIX or "Highground") .. "BountyOverview", {
    title = ns.Locale:Get("shared.details.bounty_details.8612fb"), width = 540, height = 740, header = 64, accent = "gold", alpha = 1, child = true,
    strata = "FULLSCREEN_DIALOG" }), { title = "shared.details.bounty_details.8612fb" })
  D.win = w
  w.reward = T.Text(w, "body", "gold"); w.reward:SetPoint("TOPRIGHT", -24, -84)
  w.context = T.Text(w, "body", "textMuted"); w.context:SetPoint("TOPLEFT", 24, -84)
  w.context:SetPoint("RIGHT", w.reward, "LEFT", -20, 0); w.context:SetJustifyH("LEFT")
  w.context:SetJustifyV("TOP")
  w.area = Kit.ScrollArea(w, { wheelStep = 45 })
  w.scroll, w.body = w.area.view, w.area.body
  w.target = B.Wanted.Build(w.body)
  w.target.fullPoster = true
  w.cards = {}
  w.terms = T.Text(w.body, "bodySmall", "textMuted"); w.terms:SetJustifyH("LEFT"); w.terms:SetJustifyV("TOP"); w.terms:SetWordWrap(true)
  w.status = T.Text(w, "body", "textMuted"); w.status:SetPoint("BOTTOMLEFT", 24, 66)
  w.status:SetPoint("RIGHT", -24, 0); w.status:SetJustifyH("LEFT"); w.status:SetJustifyV("BOTTOM")
  w.back = ns.Localization.Bind(Kit.Button(w, ns.Locale:Get("shared.board.back_to_board.c4cc8d"), 142, 32, { onClick = function()
    if D.preview then B.Preview.Resume() else w:Hide() end
  end }), "shared.board.back_to_board.c4cc8d"); w.back:SetPoint("BOTTOMLEFT", 24, 22)
  Kit.Tooltip(w.back, function() return { "Back", D.preview and ns.Locale:Get("shared.details.return_to_the_bounty_preview_sample_actions.b66d89")
    or ns.Locale:Get("shared.details.return_to_the_same_board_search_and.9032e3") } end)
  w.actions = {}
  -- Primary actions above the poster, management actions in the footer.
  w.actionArea = Kit.Toolbar(w, { height = 32, gap = 10 })
  w.management = Kit.Toolbar(w, { height = 30, gap = 10 })
  w.manageLabel = Kit.Paragraph(w, "heading", "textMuted")
  ns.Localization.Bind(w.manageLabel, "shared.details.manage_bounty.584c7a")
  w.nextStep = Kit.Paragraph(w.body, "body", "text")
  w.confirm = Kit.Confirmation(w)
  for i = 1, 10 do
    local button = Kit.Button(w.actionArea, "", 140, 32, { tone = i == 1 and "gold" or nil, onClick = function(self)
      local action = self.action
      if not action then return end
      if not action.confirm then
        if w.confirm:Reset() or w.prompting then Status(w, "") end
      elseif not w.confirm:Request(ConfirmKey(action)) then
        Status(w, ns.Locale:Format("bounty.confirm.prompt",
          { action = action.label, help = action.help or "", confirm = action.confirm }), "warning", true)
        return D.Refresh()
      end
      local ok, message = action.run()
      if message then Status(w, message, ok == false and "warning" or "text") end
      D.Refresh()
    end })
    Kit.Tooltip(button, function(self) return self.action and { self.action.label, self.action.help } end)
    w.actions[i] = button
  end
  w.LayoutPage = D.Layout
  D.Layout(w)
  ns.Core.OnFontScaleChange(function() D.Layout(w) end)
  -- Changes made in an editor or share window that replaced these details
  -- arrive while they are hidden; show the current bounty on return.
  w:HookScript("OnShow", function() if D.name and not D.opening then D.Refresh() end end)
  return w
end

function D.Refresh()
  local w = D.win
  if not (w and w:IsShown()) or w.refreshing then return end
  w.refreshing = true
  local offset = w.area.offset
  local b = Current()
  local items, y = b and Entries(b) or {}, 0
  w.reward:SetText(#items > 1 and (ns.Locale:Format("shared.details.total_pledged_value2.d80af6", { value2 = ns.Util.Gold(b.gold) })) or "")
  w.reward:SetShown(#items > 1)
  w.context:ClearAllPoints(); w.context:SetPoint("TOPLEFT", 24, -84)
  if #items > 1 then w.context:SetPoint("RIGHT", w.reward, "LEFT", -20, 0)
  else w.context:SetPoint("RIGHT", -24, 0) end
  w.context:SetText((D.preview and ns.Locale:Get("shared.details.preview.726b1b") or "") .. (SCOPES[D.scope] or ns.Locale:Get("shared.details.bounty.4b7a83"))
    .. (not b and ns.Locale:Get("shared.details.no_active_bounty.3b3140") or #items > 1 and (ns.Locale:Format("shared.details.value2_rewards.66c087", { value2 = #items })) or ""))
  local actions
  if D.preview then actions = D.previewActions and D.previewActions.actions and D.previewActions.actions(b) or {}
  else actions = b and Actions(b) or { { label = ns.Locale:Get("shared.board.claims_payments.f83748"), run = function() B.Ledger.Open() end } } end
  w.availableActions = actions
  local main, management, armed = {}, {}, false
  for i, button in ipairs(w.actions) do
    local action = actions[i]
    button.action = action; button:SetShown(action ~= nil)
    if action then
      local confirming = action.confirm ~= nil and w.confirm:Armed(ConfirmKey(action))
      armed = armed or confirming
      if confirming then button:SetText(action.confirm) else ns.Localization.BindField(button, action, "label") end
      button:SetParent(action.secondary and w.management or w.actionArea)
      local list = action.secondary and management or main
      list[#list + 1] = button
    end
  end
  -- An armed action that is no longer offered cannot be confirmed later.
  if not armed and (w.confirm:Reset() or w.prompting) then Status(w, "") end
  w.mainActions, w.manageActions = main, management
  D.Layout(w)
  local available, gap = w.body:GetWidth(), 12
  local width = available
  local owner = b and (D.preview and B.Preview.state.coachRole == "post" or not D.preview and B.Pot.Own(b.name))
  local report = b and not D.preview and B.Ledger.ForBounty(b) or nil
  w.nextStep:SetText(not b and ns.Locale:Get("shared.details.this_bounty_is_closed_your_reports_and.08afcf")
    or report and (report.claimant == B.Me() and ns.Locale:Get("shared.details.your_claim_is_saved_view_report_shows.1228bd")
      or report.state == "approved" and ns.Locale:Get("shared.details.claim_approved_pay_the_hunter_in_game.b1f404")
      or report.state == "paid" and ns.Locale:Get("shared.details.payment_recorded_the_report_keeps_the_evidence.c46d36")
      or ns.Locale:Get("shared.details.a_hunter_reported_a_kill_review_report.7d058c"))
    or owner and ns.Locale:Get("shared.details.your_reward_share_it_with_hunters_then.95abb9")
    or ns.Locale:Get("shared.details.defeat_this_target_detected_kills_create_a.2c6830"))
  w.nextStep:ClearAllPoints(); w.nextStep:SetPoint("TOPLEFT"); w.nextStep:SetWidth(available)
  w.nextStep:SetHeight(0); w.nextStep:SetHeight(w.nextStep:GetStringHeight() + 2)
  w.nextStep:SetShown(#actions > 0 and (report ~= nil or not b))
  y = w.nextStep:IsShown() and w.nextStep:GetHeight() + 14 or 0
  w.target:SetShown(#items > 1)
  if #items > 1 then
    w.target:ClearAllPoints(); w.target:SetPoint("TOPLEFT", 0, -y)
    B.Wanted.Fill(w.target, { name = b.name, class = b.class, gold = b.gold }, {
      width = width, compact = true, status = ns.Locale:Get("shared.details.target.f76210"), tracking = B.Matches.Label(b), progress = "", detail = "",
      preview = D.preview ~= nil, portraitLabel = D.preview and b.previewPortraitLabel })
    y = y + w.target:GetHeight() + gap
  end
  for i, entry in ipairs(items) do
    local r = Card(w, i)
    r.source, r.contribution = entry.source, #items > 1
    r.minPosterHeight = #items == 1 and math.min(440, w.scroll:GetHeight() - y - gap) or 0
    r.addGold:SetShown(entry.source ~= nil and entry.source.state ~= "pending"
      and (D.preview and D.previewActions and D.previewActions.addGold ~= nil and entry.source.by ~= B.Me()
        or not D.preview and not B.Pot.Own(b.name) and entry.source.by ~= B.Me()
          and (not entry.source.id or not P.Mine(entry.source)) and B.Pot.Live(entry.source)))
    r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y)
    B.Wanted.Fill(r, entry.bounty, { width = width, compact = true, status = ns.Text.Upper(entry.audience),
      facts = entry.facts, detail = entry.detail, progress = "",
      preview = D.preview ~= nil, portraitLabel = D.preview and b.previewPortraitLabel, tracking = "" })
    r:Show(); y = y + r:GetHeight() + gap
  end
  for i = #items + 1, #w.cards do w.cards[i]:Hide() end
  local terms = not b and ns.Locale:Get("shared.details.this_bounty_is_no_longer_active_earlier.8ca6f2")
    or b.personal and not b.offer and not b.guild and ns.Locale:Get("shared.details.only_you_see_this_target_share_bounty.23b46d")
    or ns.Locale:Format("shared.details.value1_reward_approval_and_payment_follow_in.9cc270", { value1 = B.Kills.Hint() })
  w.terms:ClearAllPoints(); w.terms:SetPoint("TOPLEFT", 0, -y); w.terms:SetWidth(w.body:GetWidth()); w.terms:SetText(terms)
  w.terms:SetHeight(0)
  local height = not b and math.ceil(w.terms:GetStringHeight()) + 2 or 0
  w.terms:SetHeight(math.max(1, height)); w.terms:SetShown(height > 0)
  -- Commit the full content height once. Native resize callbacks may refresh
  -- the scroll range while laying out; they must not discard the reader's offset.
  w.body:SetHeight(y + height + 12)
  w.area:Refresh()
  w.area:Scroll(offset)
  w.refreshing = nil
end

function D.Open(row, preview, actions)
  if preview then B.Poster.StopPreview() end
  local w = D.Build()
  D.preview = preview and row or nil
  D.previewActions = preview and actions or nil
  D.name, D.scope = row.name, row.scope
  D.organization = row.organization or row.guild and (row.guild.organization or "guild") or row.offer and row.offer.organization
  w.confirm:Reset(); Status(w, ""); w.area:Scroll(0)
  w.back:SetText(preview and not B.Preview.testing and ns.Locale:Get("shared.details.back_to_preview.0df1a4") or ns.Locale:Get("shared.board.back_to_board.c4cc8d"))
  -- Fill after the window switch: the board it replaces may still hold a
  -- captured portrait until then.
  D.opening = true
  local ok, err = pcall(B.Widgets.ShowWindow, w)
  D.opening = nil
  if not ok then error(err, 0) end
  D.Refresh()
  return w
end

B.Listen("updated", D.Refresh)
B.Listen("changed", D.Refresh)
