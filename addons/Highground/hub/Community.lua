local _, ns = ...
local Core, Kit, Theme = ns.Core, ns.Kit, ns.Theme
local Community = {}
ns.Community = Community

local function OfferGuide()
  C_Timer.After(2, function() if ns.Onboarding then ns.Onboarding.TryOffer() end end)
end

function Community.Join()
  if not Community.copy then
    Community.copy = Kit.CopyBox("HighgroundCommunityLink", { width = 660, height = 360, header = 80, onClose = OfferGuide })
    Community.copy.status:SetHeight(72)
    Community.copy.status:SetJustifyV("TOP"); Community.copy.status:SetWordWrap(true)
    Community.copy.well:ClearAllPoints()
    Community.copy.well:SetPoint("TOPLEFT", Community.copy.hint, "BOTTOMLEFT", -Theme.Space("xs"), -Theme.Space("md"))
    Community.copy.well:SetPoint("BOTTOMRIGHT", -20, 164)
  end
  Community.copy:SetSub("Highground community")
  Community.copy:Open("Join Discord", "Copy the selected link with Ctrl+C (Mac: Cmd+C).", ns.Bounty.Exchange.INVITE, true)
  Community.copy:SetStatus("Paste the link into your browser or Discord's Join a Server dialog to join the Highground community.")
  if not Community.copy:IsVisible() then return false end
  Core.pos.highgroundCommunityOffered = true
  return true
end

function Community.Build()
  if Community.win then return Community.win end
  local w = Kit.Dialog("HighgroundCommunityInvite", { title = "HIGHGROUND DISCORD", crest = true,
    titleRole = "title", width = 620, height = 364, header = 80, child = true, onClose = OfferGuide })
  Community.win = w
  w.description = Theme.Text(w.content, "body", "text")
  w.description:SetPoint("TOPLEFT"); w.description:SetPoint("RIGHT")
  w.description:SetHeight(124); w.description:SetJustifyH("LEFT"); w.description:SetJustifyV("TOP")
  w.description:SetWordWrap(true)
  w.description:SetText("Join the Highground Discord community.\n\n"
    .. "Meet other players, get addon help and find bounty boards. You can join now, or find this invitation later on Home.")
  w.status = Theme.Text(w, "body", "textMuted")
  w.status:SetPoint("BOTTOMLEFT", 24, 72); w.status:SetPoint("RIGHT", -24, 0)
  w.status:SetHeight(48); w.status:SetJustifyH("LEFT"); w.status:SetWordWrap(true)
  w.later = Kit.Button(w, "Not now", 140, 32, { onClick = function() w:Hide() end })
  w.later:SetPoint("BOTTOMLEFT", 24, 24)
  w.join = Kit.Button(w, "Join Discord", 216, 32, { tone = "accent", onClick = Community.Join })
  w.join:SetPoint("BOTTOMRIGHT", -24, 24)
  return w
end

function Community.Open()
  local w = Community.Build()
  w:SetSub("Highground community")
  w.status:SetText("Join Discord shows a link to copy into your browser or Discord.")
  Kit.Windows.Show(w)
  if not w:IsVisible() then return false end
  -- Keep the old per-character dismissal so changing the destination does
  -- not prompt players again. Displaying it consumes the offer.
  Core.pos.highgroundCommunityOffered = true
  return true
end

local function Pending()
  -- Home works on every client; retain Forever's existing automatic offer.
  return ns.GAME == "forever" and Core.pos and not Core.pos.highgroundCommunityOffered
end

function Community.TryOffer()
  if not Pending() then return end
  if InCombatLockdown() or IsInInstance() then return end
  local active = Kit.Windows.Active()
  if active and active:IsVisible() then return end
  Community.Open()
end

local scheduled
local function ScheduleOffer()
  if scheduled or not Pending() then return end
  scheduled = true
  C_Timer.After(2, function() scheduled = nil; Community.TryOffer() end)
end

local function HideOffer()
  if Community.copy then Community.copy:Hide() end
  if Community.win then Community.win:Hide() end
end

-- Closing a busy tool retries a deferred offer without polling during play.
Kit.Windows.router:On("change", ScheduleOffer)
ns.Util.Events({
  PLAYER_LOGIN = ScheduleOffer,
  PLAYER_ENTERING_WORLD = function()
    if IsInInstance() then HideOffer() end
    ScheduleOffer()
  end,
  PLAYER_REGEN_ENABLED = ScheduleOffer,
  PLAYER_REGEN_DISABLED = HideOffer,
}, "Highground community invitation")
