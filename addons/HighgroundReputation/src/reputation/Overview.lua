local _, ns = ...
local W, K = ns.Reputation, ns.Kit
local UI = W.UI

function UI.RefreshOverview(source, org, c)
  local W = source or W
  local f, O = W.UI.window, W.organizations or ns.Organizations
  local joined = W.Joined(c)
  local moderator = org and O.CanModerate(org.id)
  local paused = c and c.enabled == false
  local needsActivation = moderator and not (c and c.activated)
  f.participationTitle:SetText(joined and "Reputation is on for your account" or paused and "Reputation is off for your account"
    or "Start using Reputation here")
  f.participationHelp:SetText(joined and "Share reports and use this organization's blacklist. Disable stops sharing and filtering on your account. Your records are kept; other members keep their settings."
    or paused and "Your reports and history are kept. Enable explicitly to share reports and use this organization's blacklist again."
    or moderator and "Enable Reputation to review proposals and publish blacklist decisions as a guild officer or community moderator."
    or "Use this organization to report players and receive its approved blacklist. Proposals wait until an eligible moderator has Reputation enabled.")
  f.disable:SetText(joined and "Disable on this account" or "Enable on this account")
  K.Paint(f.disable, joined and "surface" or "accent")
  f.disable:SetEnabled(org ~= nil and (joined or O.Role(org.id) ~= nil))
  f.openReports:SetShown(joined); f.openReports:SetEnabled(joined)
  f.openReports:SetText(needsActivation and "Enable moderation" or moderator and "Review proposals" or "View proposals")
  f.sync:SetEnabled(joined)
  local width = math.max(400, f.overview:GetWidth() - 16)
  if f.overviewWidth ~= width then
    f.overviewWidth = width
    f.overviewBody:SetWidth(width)
    f.participationTitle:SetWidth(width); f.participationHelp:SetWidth(width); f.organizationHelp:SetWidth(width)
  end
  local height = f.participationTitle:GetStringHeight() + f.participationHelp:GetStringHeight()
    + f.organizationHelp:GetStringHeight() + 180
  if f.overviewBody:GetHeight() ~= height then f.overviewBody:SetHeight(height) end
end

function UI.BuildOverview(f, source)
  local W = source or W
  local UI, O = W.UI, W.organizations or ns.Organizations
  f.overview = CreateFrame("ScrollFrame", nil, f.content, "UIPanelScrollFrameTemplate")
  f.overview:SetPoint("TOPLEFT", 0, -128); f.overview:SetPoint("BOTTOMRIGHT", -26, 100)
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
  f.openReports = K.Button(f.overviewBody, "View proposals", 190, 32, { tone = "accent", onClick = function()
    local c = W.Get()
    if O.CanModerate(W.db.selected) and not (c and c.activated) then
      local enabled, err = W.Enable(W.db.selected)
      if not enabled then return W.Say(err) end
    end
    UI.SetMode("proposals", W.db.selected)
  end })
  f.organizationHelp = UI.Label(f.overviewBody,
    "Updates arrive automatically while eligible moderators are online. Manage membership, invitations and roles in WoW.", 0, -190, 650)
  f.organizationHelp:SetWordWrap(true)
  f.sync = K.Button(f.overviewBody, "Check for updates", 190, 30, { onClick = function()
    local c = W.Get()
    if W.Joined(c) then W.Discover(c.id, true); W.RequestSync(c, true); W.SendReports(c); UI.Refresh() end
  end })
  f.native = K.Button(f.overviewBody, "Open in WoW", 190, 30, { onClick = function()
    W.OpenNative(W.db.selected and { id = W.db.selected })
  end })
  f.disable:SetPoint("TOPLEFT", f.participationHelp, "BOTTOMLEFT", 0, -18)
  f.openReports:SetPoint("LEFT", f.disable, "RIGHT", 12, 0)
  f.organizationHelp:ClearAllPoints(); f.organizationHelp:SetPoint("TOPLEFT", f.disable, "BOTTOMLEFT", 0, -32)
  f.sync:SetPoint("TOPLEFT", f.organizationHelp, "BOTTOMLEFT", 0, -18)
  f.native:SetPoint("LEFT", f.sync, "RIGHT", 12, 0)
end
