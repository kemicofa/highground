local _, ns = ...
local W, K = ns.Reputation, ns.Kit
local UI = W.UI

local function CheckStatus(f, source)
  local a = f.updateCheck.current
  if not a then return false end
  local c, now = a.value, GetTime()
  local O = source.organizations or ns.Organizations
  local outcome, message
  if source.Get() ~= c or not source.Joined(c) or not O.Get(c.id) then
    outcome, message = "cancelled", ns.Locale:Get("reputation.overview.update_check_cancelled.b0d6d4")
  elseif a.request and a.request.completed then
    outcome, message = "succeeded", ns.Locale:Get("reputation.overview.updates_received.869c53")
  elseif a.request and a.request.state == "failed" then
    outcome, message = "failed", ns.Locale:Get("reputation.overview.no_complete_update_received_try_again_when.1a2a6d")
  elseif source.transportError and source.transportError ~= a.error then
    outcome, message = "failed", source.transportError
  elseif now >= a.deadline then
    outcome, message = "failed", ns.Locale:Get("reputation.overview.no_complete_update_received_try_again_when.1a2a6d")
  elseif not a.request and not a.rechecked and now >= a.started + 2 then
    a.rechecked = true
    a.request = source.RequestSync(c, true)
    if not a.request then a.deadline = a.started + 6 end
  end
  if outcome then
    f.updateCheck:Finish(a, outcome, message)
    f.updateMessage = message
    return false
  end
  local incoming = source.inbound and source.inbound[c.id]
  local matching = incoming and a.request and incoming.request == a.request.id
  return true, matching and ns.Locale:Get("reputation.overview.receiving.682046") or ns.Locale:Get("reputation.overview.checking.820d60"),
    matching and incoming.count and incoming.count > 0 and incoming.received / incoming.count or nil
end

function UI.RefreshOverview(source, org, c)
  local W = source or W
  local f, O = W.UI.window, W.organizations or ns.Organizations
  local joined = W.Joined(c)
  local moderator = org and O.CanModerate(org.id)
  local paused = c and c.enabled == false
  local needsActivation = moderator and not (c and c.activated)
  f.participationTitle:SetText(joined and ns.Locale:Get("reputation.overview.reputation_is_on_for_your_account.afcb7f") or paused and ns.Locale:Get("reputation.overview.reputation_is_off_for_your_account.aad20d")
    or ns.Locale:Get("reputation.overview.start_using_reputation_here.9bf4aa"))
  f.participationHelp:SetText(joined and ns.Locale:Get("reputation.overview.share_reports_and_use_this_organization_s.3b0ad6")
    or paused and ns.Locale:Get("reputation.overview.your_reports_and_history_are_kept_enable.690bd3")
    or moderator and ns.Locale:Get("reputation.overview.enable_reputation_to_review_proposals_and_publish.9f0938")
    or ns.Locale:Get("reputation.overview.use_this_organization_to_report_players_and.e24d06"))
  f.disable:SetText(joined and ns.Locale:Get("reputation.overview.disable_on_this_account.32d240") or ns.Locale:Get("reputation.forms.enable_on_this_account.5a6ada"))
  K.Paint(f.disable, joined and "surface" or "accent")
  f.disable:SetEnabled(org ~= nil and (joined or O.Role(org.id) ~= nil))
  f.openReports:SetShown(joined); f.openReports:SetEnabled(joined)
  f.openReports:SetText(needsActivation and ns.Locale:Get("reputation.overview.enable_moderation.98735f") or moderator and ns.Locale:Get("reputation.overview.review_proposals.ec8964") or ns.Locale:Get("reputation.overview.view_proposals.15c299"))
  f.sync:SetEnabled(joined)
  f.sync:RefreshBusy()
  f.updateStatus:SetText(f.updateCheck.current and ns.Locale:Get("reputation.overview.waiting_for_an_online_moderator_s_response.3e8bbf") or f.updateMessage or "")
  local width = math.max(400, f.overview:GetWidth() - 16)
  if f.overviewWidth ~= width then
    f.overviewWidth = width
    f.overviewBody:SetWidth(width)
    f.participationTitle:SetWidth(width); f.participationHelp:SetWidth(width); f.organizationHelp:SetWidth(width)
    f.updateStatus:SetWidth(width)
  end
  local height = f.participationTitle:GetStringHeight() + f.participationHelp:GetStringHeight()
    + f.organizationHelp:GetStringHeight() + f.updateStatus:GetStringHeight() + 200
  if f.overviewBody:GetHeight() ~= height then f.overviewBody:SetHeight(height) end
end

function UI.BuildOverview(f, source)
  local W = source or W
  local UI, O = W.UI, W.organizations or ns.Organizations
  f.overview = CreateFrame("ScrollFrame", nil, f.workspaceBody, "UIPanelScrollFrameTemplate")
  f.overview:SetPoint("TOPLEFT", f.pageTabs, "BOTTOMLEFT", 0, -22); f.overview:SetPoint("BOTTOMRIGHT", -26, 100)
  f.overviewBody = CreateFrame("Frame", nil, f.overview)
  f.overviewBody:SetSize(660, 350); f.overview:SetScrollChild(f.overviewBody)
  f.participationTitle = UI.Label(f.overviewBody, "", 0, 0, 650, "text")
  ns.Theme.SetRole(f.participationTitle, "title")
  f.participationHelp = UI.Label(f.overviewBody, "", 0, -34, 650)
  f.participationHelp:SetWordWrap(true)
  f.disable = K.Button(f.overviewBody, "", 235, 32, { onClick = function()
    local id, c = W.db.selected, W.Get()
    if not id or not O.Get(id) then return UI.Refresh() end
    if W.Joined(c) then W.Disable(c)
    else
      local value, err
      if O.CanModerate(id) and not (c and c.activated) then value, err = W.Enable(id)
      else value, err = W.Follow(id) end
      if not value then W.Say(err) end
    end
    UI.Refresh()
  end })
  f.openReports = K.Button(f.overviewBody, ns.Locale:Get("reputation.overview.view_proposals.15c299"), 190, 32, { tone = "accent", onClick = function()
    local c = W.Get()
    if O.CanModerate(W.db.selected) and not (c and c.activated) then
      local enabled, err = W.Enable(W.db.selected)
      if not enabled then return W.Say(err) end
    end
    UI.SetMode("proposals", W.db.selected)
  end })
  f.organizationHelp = UI.Label(f.overviewBody,
    ns.Locale:Get("reputation.overview.updates_arrive_automatically_while_eligible_moderators_are.9839e5"), 0, -190, 650)
  f.organizationHelp:SetWordWrap(true)
  f.updateCheck = ns.Async.New()
  f.sync = K.Button(f.overviewBody, ns.Locale:Get("reputation.overview.check_for_updates.736b90"), 190, 30, { onClick = function()
    local c = W.Get()
    if not W.Joined(c) or f.updateCheck.current then return end
    local a = f.updateCheck:Start(c)
    a.started, a.deadline, a.error = GetTime(), GetTime() + 30, W.transportError
    f.updateMessage = nil
    W.Discover(c.id, true)
    a.request = W.RequestSync(c, true)
    W.SendReports(c); UI.Refresh()
  end })
  K.BusyButton(f.sync, function() return CheckStatus(f, W) end, function() UI.Refresh() end)
  f.updateStatus = UI.Label(f.overviewBody, "", 0, 0, 650)
  f.updateStatus:ClearAllPoints(); f.updateStatus:SetPoint("TOPLEFT", f.sync, "BOTTOMLEFT", 0, -10)
  f.updateStatus:SetWordWrap(true)
  f.native = K.Button(f.overviewBody, ns.Locale:Get("reputation.overview.open_in_wow.e2fe00"), 190, 30, { onClick = function()
    W.OpenNative(W.db.selected and { id = W.db.selected })
  end })
  f.disable:SetPoint("TOPLEFT", f.participationHelp, "BOTTOMLEFT", 0, -18)
  f.openReports:SetPoint("LEFT", f.disable, "RIGHT", 12, 0)
  f.organizationHelp:ClearAllPoints(); f.organizationHelp:SetPoint("TOPLEFT", f.disable, "BOTTOMLEFT", 0, -32)
  f.sync:SetPoint("TOPLEFT", f.organizationHelp, "BOTTOMLEFT", 0, -18)
  f.native:SetPoint("LEFT", f.sync, "RIGHT", 12, 0)
end
