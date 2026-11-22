local _, ns = ...
local C, B, Kit = ns.Onboarding.Coach, ns.Bounty, ns.Kit
local D, S = B.Preview, {}
C.BountySample = S

function S.Visible(w) return w and w:IsVisible() and w end

function S.Fit(w)
  if not S.Visible(w) then return end
  if not w.coachScale then
    w.coachScale = w:GetScale()
    w.coachPoints = {}
    for i = 1, w:GetNumPoints() do w.coachPoints[i] = { w:GetPoint(i) } end
    if not w.coachScaleHook then
      w.coachScaleHook = true
      w:HookScript("OnHide", function()
        if w.coachScale then w:SetScale(w.coachScale); w.coachScale = nil end
        if w.coachPoints then
          w:ClearAllPoints()
          for _, point in ipairs(w.coachPoints) do w:SetPoint(unpack(point)) end
          w.coachPoints = nil
        end
      end)
    end
  end
  local room = math.max(320, UIParent:GetWidth() - (C.win and C.win:GetWidth() or 420) - 72)
  local scale = math.min(w.coachScale, (UIParent:GetHeight() - 48) / w:GetHeight(), room / w:GetWidth())
  if w:GetScale() ~= scale then w:SetScale(scale) end
  w:ClearAllPoints(); w:SetPoint("LEFT", UIParent, "LEFT", 24 / scale, 0)
  return w
end

function S.Poster(owner)
  return S.Fit(owner.previewWin)
end

function S.Remember()
  local w = B.Form.previewWin
  if not (D.state and D.scene and D.scene.key == "create" and w and w.coachSession == D.state) then return end
  D.state.coachDraft = { name = w.name:GetText(), identity = w.nameIdentity, mode = w.formMode,
    gold = w.gold:GetText(), kills = w.kills:GetText(), duration = w.duration:GetText(),
    choice = w.durationChoice, note = w.note:GetText(), methods = B.TermsEditor.Read(w).killMethods, customize = w.customize }
end

function S.Stop()
  local menu = Kit.Dropdown.Frame()
  local parent = menu and menu.anchor
  while parent do
    if parent == S.win then Kit.Dropdown.Hide(); break end
    parent = parent.GetParent and parent:GetParent()
  end
  if S.win then Kit.Windows.Close(S.win) end
  S.context = nil
end

function S.Select(key)
  S.Remember(); S.Stop(); D.SelectGuided(key)
end

function S.Bind(row, bounty)
  local state = D.state
  state.coachRow, state.coachBounty = row, bounty
  for _, key in ipairs({ "board", "nearby", "shared", "kill", "claims" }) do state.samples[key] = { row, bounty } end
  if state.coachRole == "post" then state.samples.create = { row, bounty } end
  D.row, D.bounty = row, bounty
end

function S.Ensure(role)
  local state = D.Ensure()
  if state.coachRole == role then return end
  state.coachRole, state.kills, state.approved, D.claims = role, 0, 0, {}
  local row, bounty = D.Sample(role == "hunt" and "shared" or "create")
  local name = (ns.Caps.hideRealmNames and ns.Locale:Get("highground.coachbountysamples.nightshade_vale.0d981c") or "Nightshade-") .. (ns.Core.myRealm or "Realm")
  row.name, bounty.name = name, name
  bounty.killsRequired, bounty.killMethods = 1, ""
  if role == "hunt" then
    local offer = bounty.contributions[1]
    offer.name = name
    offer.killsRequired, offer.killMethods = 1, ""
    bounty.contributions, bounty.gold, bounty.pledgedGold = { offer }, offer.gold, offer.gold
    row.gold, row.owner, row.status = offer.gold, ns.Locale:Format("highground.coachbountysamples.posted_by_value2.435384", { value2 = ns.Core.DisplayName(offer.by) }), B.Terms.Summary(bounty)
  end
  S.Bind(row, bounty)
end

function S.Posted()
  if D.state.coachSaved then return end
  -- A resumed later step reconstructs the one sample the player is learning.
  local row, bounty = D.state.coachRow, D.state.coachBounty
  local offer = B.Public.Copy(bounty)
  offer.id, offer.contributor, offer.state = "preview-draft", "preview-account", "active"
  offer.createdAt, offer.checkedAt, offer.funds, offer.expiresAt = B.Public.Now(), B.Public.Now(), "available", B.Public.Now() + 7200
  bounty.state, bounty.contributions, bounty.expiresAt = "public", { offer }, offer.expiresAt
  row.personal, row.shared, row.scope, row.visibility, row.state = nil, bounty, "public", ns.Locale:Get("shared.form.shared.50d0d8"), "public"
  D.state.coachSaved, D.state.draftMode, D.state.draft = true, "public", B.Public.Copy(bounty)
  S.Bind(row, bounty)
end

function S.Rows(tab, query)
  local state = D.state
  if not state or not state.coachRow then return {} end
  local row = state.coachRow
  local listed = tab == "public" and row.shared or tab == "guild" and row.guild
    or tab == "mine" and (state.coachRole == "post" and state.coachSaved or state.interest == "tracking")
  if not listed or query and query ~= "" and not (row.name .. " " .. row.owner):lower():find(query:lower(), 1, true) then return {} end
  return { row }
end

function S.Claim()
  return D.claims and D.claims[1]
end

function S.MakeClaim(manage)
  if S.Claim() then return S.Claim() end
  local b, now = D.state.coachBounty, B.Public.Now()
  local offer = b.contributions and b.contributions[1] or b
  local proof = D.state.coachKill or { at = now, evidence = ns.Caps.combatLog and "observed killing blow" or "honor credit",
    cause = ns.Caps.combatLog and { event = "SPELL_DAMAGE", spellID = 5308, spellName = "Execute" } or nil }
  local claim = B.Terms.Copy({ id = "preview-guide-" .. D.state.coachRole, pledge = offer.id,
    name = b.name, gold = offer.gold, by = offer.by, claimant = manage and ("HunterPreview-" .. (ns.Core.myRealm or "Realm")) or B.Me(),
    public = true, previewManage = manage, received = true, state = "claimed", claimedAt = now, killedAt = proof.at,
    evidence = proof.evidence, cause = B.Public.Copy(proof.cause) }, offer)
  D.claims, D.state.kills = { claim }, 1
  return claim
end

function S.Incoming()
  S.Posted()
  if D.state.draftMode ~= "public" then return end
  local row, b = D.state.coachRow, D.state.coachBounty
  if row.guild and b.state == "pending" then b.state, row.state, b.approver = "approved", "approved", "OfficerPreview" end
  S.MakeClaim(true)
end

function S.SyncProgress()
  local c, state = S.Claim(), D.state
  if not state or not state.coachRow then return end
  state.approved = c and (c.state == "approved" or c.state == "paid") and 1 or 0
  state.coachPending = c and c.state == "claimed" and 1 or 0
  state.coachRow.status = B.Terms.Summary(state.coachBounty)
    .. (c and (" · " .. (state.approved > 0 and ns.Locale:Get("highground.coachbountysamples.1_approved.56c853") or c.state == "rejected" and ns.Locale:Get("highground.coachbountysamples.report_declined.d051d9") or ns.Locale:Get("highground.coachbountysamples.1_awaiting_review.3b8407"))) or "")
  state.coachRow.tracking = state.interest == "tracking"
end

function S.ReportKill()
  if not D.state.coachKill then return false, ns.Locale:Get("highground.coachbountysamples.no_sample_kill_yet_continue_the_hunt.35271c") end
  if S.Claim() then return false, ns.Locale:Get("highground.coachbountysamples.this_sample_kill_is_already_submitted_view.e01249") end
  S.MakeClaim(false); S.SyncProgress()
  return true, ns.Locale:Get("highground.coachbountysamples.sample_kill_submitted_awaiting_the_poster_s.5a1179")
end

function S.DetailActions()
  local actions = {}
  if D.state.coachRole == "hunt" and not S.Claim() then actions[1] = { label = ns.Locale:Get("highground.coachbountysamples.claim_reward.c3e030"), run = S.ReportKill,
    help = ns.Locale:Get("highground.coachbountysamples.fallback_for_a_missed_detection_detected_kills.2d8911") } end
  actions[#actions + 1] = { label = S.Claim() and S.Primary() or ns.Locale:Get("shared.board.claims_payments.f83748"), run = function() S.Claims(); return true end,
    help = ns.Locale:Get("highground.coachbountysamples.see_this_bounty_s_sample_reports_and.edc6d8") }
  actions[#actions + 1] = { label = ns.Locale:Get("highground.coachbounties.share_bounty.94e67c"), run = function() S.Share(); return true end }
  if D.state.coachRole == "hunt" then
    actions[#actions + 1] = { label = D.state.interest == "tracking" and ns.Locale:Get("highground.coachbountysamples.stop_tracking.888c9a") or ns.Locale:Get("highground.coachbountysamples.ignore_bounty_alerts.a53db4"), run = function()
      D.Interest("ignored"); D.state.coachInterestVersion = (D.state.coachInterestVersion or 0) + 1
      B.Details.win:Hide(); S.Board(); return true
    end, secondary = true }
  end
  return actions
end

function S.DetailButton(label)
  local w = B.Details.preview and S.Visible(B.Details.win)
  if w then for _, button in ipairs(w.actions) do if button.action and button.action.label == label then return button end end end
end

function S.ReturnOn(button, window)
  if button.coachReturn then return end
  button.coachReturn = true
  button:HookScript("OnClick", function()
    if D.guided and D.state and D.state.coachRole and not window:IsShown() then S.Board() end
  end)
end

function S.Tools(anchor)
  Kit.Dropdown.Open(anchor, {
    { text = ns.Locale:Get("highground.coachbountysamples.account_gold_funding.731d2e"), run = function() S.Fit(B.GoldView.Open(true)) end },
    { text = ns.Locale:Get("highground.coachbountysamples.shared_alert_settings.cefbc7"), run = function() S.Fit(B.Preferences.Open(true)) end },
    { text = ns.Locale:Get("highground.coachbountysamples.import_bounty.00e6b6"), run = S.Import },
  }, function(item) item.run() end)
end

function S.RefreshBoard()
  S.SyncProgress()
  if S.win then B.Board.preview.Refresh(); S.Fit(S.win) end
end

function S.Primary()
  local c = S.Claim()
  if c then return D.state.coachRole == "hunt" and ns.Locale:Get("highground.coachbountysamples.view_report.7398c9")
    or c.state == "claimed" and ns.Locale:Get("highground.coachbountysamples.review_report.29a1c5") or c.state == "approved" and ns.Locale:Get("highground.coachbountysamples.record_payment.86e563") or ns.Locale:Get("highground.coachbountysamples.view_report.7398c9") end
  return D.state.coachRole == "post" and ns.Locale:Get("highground.coachbountysamples.edit_reward.0854ae") or D.state.interest ~= "tracking" and ns.Locale:Get("highground.coachbountysamples.start_tracking.9d94fe") or ns.Locale:Get("highground.coachbountysamples.stop_tracking.888c9a")
end

function S.Board(tab)
  S.Remember()
  S.win = B.Board.Build({ rows = S.Rows, create = function() S.Form("name", "public") end,
    import = function() S.Import() end, claims = function() S.Claims() end,
    primary = S.Primary,
    runPrimary = function()
      if S.Claim() then return S.Claims() end
      if D.state.coachRole == "post" then return S.Form("gold", "public") end
      D.Interest(D.state.interest == "tracking" and "ignored" or "tracking")
      D.state.coachInterestVersion = (D.state.coachInterestVersion or 0) + 1; S.RefreshBoard()
    end,
    tools = S.Tools, details = function(row) S.Details(row) end })
  B.Widgets.ShowWindow(S.win)
  if tab then B.Board.preview.SetTab(tab) end
  S.RefreshBoard()
  return S.win
end

function S.PrimaryButton()
  local w = S.Visible(S.win)
  if not w then return end
  w.list:Scroll(math.max(0, w.rows[1]:GetHeight() - w.list.view:GetHeight()))
  return w.rows[1].primary
end

-- The board tab, or its page menu when enlarged text compacts the strip.
function S.Tab(key)
  local w = S.Visible(S.win)
  return w and w.tabGroup:Target(key)
end

function S.CardButton(tab)
  local w = S.Visible(S.win)
  if not w then return end
  tab = tab or "mine"
  if B.Board.preview.tab ~= tab then return S.Tab(tab) end
  local row = w.rows[1]
  w.list:Scroll(math.max(0, row:GetHeight() - w.list.view:GetHeight()))
  return row.details
end

function S.Details(row)
  row = row or S.Rows("public")[1]
  local key = D.state.coachRole == "post" and "create" or "shared"
  S.Remember(); D.SelectGuided(key)
  D.row, D.bounty = row, row.shared or row.guild or row.personal
  S.SyncProgress()
  local w = B.Details.Open(row, true, { addGold = row.shared and S.OpenPot or nil, actions = S.DetailActions })
  S.ReturnOn(w.back, w); S.Fit(w)
  return w
end

function S.AddButton()
  local w = B.Details.preview and S.Visible(B.Details.win)
  if not w or not D.bounty.contributions then return end
  local card = w.cards[1]
  local button = card.addGold
  w.area:Scroll(math.max(0, card:GetHeight() - w.scroll:GetHeight()))
  return button
end

function S.Form(field, mode)
  if not D.scene or D.scene.key ~= "create" then S.Remember(); D.SelectGuided("create") end
  local gold = S.Visible(B.GoldView.previewWin)
  if gold then gold:Hide() end
  local w = S.Visible(B.Form.previewWin)
  if not w then
    S.Remember(); D.SelectGuided("create"); w = D.OpenCreate(mode)
    local draft = D.state.coachDraft
    if draft then
      B.Form.SetName(w, draft.identity); ns.Localization.BindField(w.name, draft, "name")
      B.TermsEditor.Set(w, { killMethods = draft.methods }); w.kills:SetText(draft.kills)
      w.gold:SetText(draft.gold); w.note:SetText(draft.note); w.duration:SetText(draft.duration)
      w.durationChoice, w.customize = draft.choice, draft.customize; B.Form.SetMode(w, draft.mode)
    elseif not D.state.draft and D.state.coachBounty then
      local bounty = D.state.coachBounty
      B.Form.SetName(w, bounty.name); w.gold:SetText(tostring(bounty.gold)); w.note:SetText(bounty.note)
      B.TermsEditor.Set(w, bounty); w.kills:SetText(tostring(B.Terms.Count(bounty)))
    end
    w.coachSession = D.state
    if not w.coachSaveHook then
      w.coachSaveHook = true
      w.action:HookScript("OnClick", function()
        if D.guided and D.state and D.state.coachRole and w.coachSession == D.state
          and D.scene.key == "create" and not w:IsShown() and D.state.draft then
          D.state.coachSaved = true
          D.state.coachSaveVersion = (D.state.coachSaveVersion or 0) + 1
          if D.state.coachRole == "post" then
            D.claims, D.state.approved, D.state.coachPending, D.state.kills = {}, 0, 0, 0
            S.Bind(unpack(D.state.samples.create))
          end
          S.Board()
        end
      end)
    end
  end
  B.Form.Step(w, field == "name" and 1 or field == "review" and 3 or 2)
  if field == "kills" then w.customize = true; B.Form.Layout(w) end
  for _, input in ipairs({ w.name, w.gold, w.duration, w.kills, w.note }) do input:ClearFocus() end
  local y = field and w.fieldY[field == "huntSummary" and w.kills or w[field]] or 0
  w.fields:Scroll(math.max(0, (y or 0) - 28))
  S.Fit(w)
  return w
end

function S.Arrival()
  S.Select("shared")
  B.Matches.Show(D.bounty, true); D.Dock(B.Matches.previewWin)
  local w = B.Matches.previewWin
  if not w.coachInterestHook then
    w.coachInterestHook = true
    for _, button in ipairs({ w.details, w.ignore }) do button:HookScript("OnClick", function()
      if D.guided and D.state and D.state.coachRole then D.state.coachInterestVersion = (D.state.coachInterestVersion or 0) + 1 end
    end) end
  end
  S.ReturnOn(w.details, w); S.ReturnOn(w.ignore, w)
end

function S.OpenPot(source)
  D.state.coachPotOpened = true
  local w = B.Pot.Open(source or D.bounty.contributions[1], true)
  if not w.coachRefresh then
    w.coachRefresh = true
    w.add:HookScript("OnClick", function()
      if D.guided and D.state and D.state.coachRole and not w:IsShown() and B.Details.preview then B.Details.Refresh() end
    end)
  end
  w.gold:SetText("100"); S.Fit(w)
  return w
end

function S.Pot()
  if not (B.Details.preview and S.Visible(B.Details.win)) then S.Board(); S.Details() end
  D.state.coachPotOpened, D.state.coachPotGold = nil, D.bounty.gold
  return S.AddButton()
end

function S.Import()
  S.Remember(); D.SelectGuided("exchange"); D.state.messages.exchange = nil
  local w = B.Exchange.OpenImport(D.CODE, true)
  S.ReturnOn(w.done, w); S.ReturnOn(w.actions.review, w)
  return S.Fit(w)
end

function S.Share()
  local w = S.Visible(B.Exchange.previewShareWin)
  if not w then local _, b = D.Sample("exchange"); w = B.Exchange.PreviewShare(D.state.draft or b, "global") end
  S.ReturnOn(w.done, w)
  return S.Fit(w)
end

function S.Claims()
  S.Remember(); D.SelectGuided("claims")
  local w = D.OpenClaims()
  if S.Claim() then w:Select(S.Claim().id) end
  S.ReturnOn(w.back, w)
  return S.Fit(w)
end

function S.Proof(state)
  S.Select("kill"); D.state.kills = 1; D.Capture(state)
  D.state.coachKill = B.Public.Copy(B.Proof.previewWin.item)
  S.MakeClaim(false); S.SyncProgress()
  local w = B.Proof.previewWin
  if not w.coachProofHook then
    w.coachProofHook = true
    w.proof:HookScript("OnClick", function()
      if D.guided and D.state and D.state.coachRole and S.Visible(B.Exchange.previewProofWin) then
        w:Hide(); S.ReturnOn(B.Exchange.previewProofWin.done, B.Exchange.previewProofWin)
      end
    end)
    w.details:HookScript("OnClick", function()
      if D.guided and D.state and D.state.coachRole == "hunt" then w:Hide(); S.Claims() end
    end)
  end
end

function S.Context()
  S.SyncProgress()
  for _, owner in ipairs({ B.GoldView, B.Pot, B.Exchange, B.Form }) do
    local w = S.Visible(owner.previewWin)
    if w then return S.Fit(w) end
  end
  for _, w in pairs({ B.Exchange.previewImportWin, B.Exchange.previewShareWin, B.Exchange.previewProofWin,
    B.Details.preview and B.Details.win, D.claimsWin, S.win,
    B.Proof.previewWin, B.Poster.previewWin, B.Matches.previewWin }) do
    if S.Visible(w) then return S.Fit(w) end
  end
end
