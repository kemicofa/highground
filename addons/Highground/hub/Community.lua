local _, ns = ...
local Core, Kit, Theme = ns.Core, ns.Kit, ns.Theme
local Community = {}
local INVITES = {
  Horde = { faction = "Horde",
    url = "https://www.worldofwarcraft.com/invite/BJbgaAEIn27?region=EU&faction=Horde" },
  Alliance = { faction = "Alliance",
    url = "https://www.worldofwarcraft.com/invite/nr7D3Plcndq?region=EU&faction=Alliance" },
}
ns.Community = Community

-- This invitation belongs to Forever, even though Retail shares its TOC.
function Community.Available() return ns.GAME == "forever" end

-- Each faction's community spans rulesets; only the character's faction
-- selects an invitation. An unknown faction must not use the other link.
function Community.Invite()
  if Community.Available() then return INVITES[ns.Util.read(UnitFactionGroup, "player")] end
end

function Community.NativeVisible()
  if not Community.Available() then return false end
  return CommunitiesFrame and CommunitiesFrame:IsShown()
    or CommunitiesAddDialog and ns.Util.read(CommunitiesAddDialog.GetAttribute, CommunitiesAddDialog, "shown") == true
end

local function OfferGuide()
  C_Timer.After(2, function() if ns.Onboarding then ns.Onboarding.TryOffer() end end)
end

function Community.CopyInvite()
  local invite = Community.Invite()
  if not invite then return false end
  if not Community.copy then
    Community.copy = Kit.CopyBox("HighgroundCommunityLink", { width = 660, height = 360, header = 80, onClose = OfferGuide,
      buttons = { { key = "open", label = "Open join window", width = 240, tone = "accent",
        onClick = function() Community.OpenJoinWindow() end } } })
    Community.copy.status:SetHeight(72)
    Community.copy.status:SetJustifyV("TOP"); Community.copy.status:SetWordWrap(true)
    Community.copy.well:ClearAllPoints()
    Community.copy.well:SetPoint("TOPLEFT", Community.copy.hint, "BOTTOMLEFT", -Theme.Space("xs"), -Theme.Space("md"))
    Community.copy.well:SetPoint("BOTTOMRIGHT", -20, 164)
  end
  Community.copy:SetSub("WoW Forever · EU · " .. invite.faction)
  Community.copy:Open("Highground community", "Copy the selected link with Ctrl+C (Mac: Cmd+C).", invite.url, true)
  Community.copy:SetStatus("Then click Open join window, paste the link into WoW's invite box, and click Join.")
  return true
end

function Community.Join()
  return Community.CopyInvite()
end

function Community.OpenJoinWindow()
  if not Community.Invite() then return false end
  if InCombatLockdown() then
    if Community.copy then Community.copy:SetStatus("Open the community window after combat.") end
    return false
  end
  -- Blizzard's invite field is forbidden to addons. Its supported attribute
  -- bridge only opens the dialog; the player must paste and click Join there.
  -- Never call the ticket hyperlink/request/redeem APIs or edit native fields.
  local opened = ns.Organizations.Open()
  if opened and CommunitiesAddDialog and type(CommunitiesAddDialog.SetAttribute) == "function" then
    if CommunitiesFrame and not Community.nativeHooked then
      CommunitiesFrame:HookScript("OnHide", OfferGuide)
      Community.nativeHooked = true
    end
    local ok, result = pcall(CommunitiesAddDialog.SetAttribute, CommunitiesAddDialog, "setshown", true)
    if ok and result ~= false
      and ns.Util.read(CommunitiesAddDialog.GetAttribute, CommunitiesAddDialog, "shown") == true then
      if Community.copy then Community.copy:Hide() end
      if Community.win then Community.win:Hide() end
      if ns.Hub.win then ns.Hub.win:Hide() end
      return true
    end
  end
  if Community.copy then
    Community.copy:SetStatus("Open Guild & Communities from WoW's menu, choose Join Community, then paste the link and click Join.")
    Community.copy.box:SetFocus(); Community.copy.box:HighlightText()
  end
  return false
end

function Community.Build()
  if Community.win then return Community.win end
  local w = Kit.Dialog("HighgroundCommunityInvite", { title = "HIGHGROUND COMMUNITY", crest = true,
    titleRole = "title", width = 620, height = 364, header = 80, child = true, onClose = OfferGuide })
  Community.win = w
  w.description = Theme.Text(w.content, "body", "text")
  w.description:SetPoint("TOPLEFT"); w.description:SetPoint("RIGHT")
  w.description:SetHeight(124); w.description:SetJustifyH("LEFT"); w.description:SetJustifyV("TOP")
  w.description:SetWordWrap(true)
  w.description:SetText("Would you like to join the Highground in-game community?\n\n"
    .. "Meet other Highground players. You can join now, or find this invitation later on Home.")
  w.status = Theme.Text(w, "body", "textMuted")
  w.status:SetPoint("BOTTOMLEFT", 24, 72); w.status:SetPoint("RIGHT", -24, 0)
  w.status:SetHeight(48); w.status:SetJustifyH("LEFT"); w.status:SetWordWrap(true)
  w.later = Kit.Button(w, "Not now", 140, 32, { onClick = function() w:Hide() end })
  w.later:SetPoint("BOTTOMLEFT", 24, 24)
  w.join = Kit.Button(w, "Join community", 216, 32, { tone = "accent", onClick = Community.Join })
  w.join:SetPoint("BOTTOMRIGHT", -24, 24)
  return w
end

function Community.Open()
  if not Community.Available() then return false end
  local invite = Community.Invite()
  if not invite then ns.Util.Say("Choose a faction before opening the Highground community invitation."); return false end
  local w = Community.Build()
  w:SetSub("WoW Forever · EU · " .. invite.faction)
  w.status:SetText("Join community shows your invite and the steps to join in WoW.")
  Kit.Windows.Show(w)
  if not w:IsVisible() then return false end
  -- Per character, outside profiles: upgrades and new installations get one
  -- offer. Displaying it (including closing with Escape) consumes the offer.
  Core.pos.highgroundCommunityOffered = true
  return true
end

function Community.TryOffer()
  if not Community.Invite() or not Core.pos or Core.pos.highgroundCommunityOffered then return end
  if InCombatLockdown() or IsInInstance() or Community.NativeVisible() then return end
  local active = Kit.Windows.Active()
  if active and active:IsVisible() then return end
  Community.Open()
end

local scheduled
local function ScheduleOffer()
  if scheduled or not Community.Invite() or not Core.pos or Core.pos.highgroundCommunityOffered then return end
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
  UNIT_FACTION = function(_, unit) if unit == "player" then ScheduleOffer() end end,
}, "Highground community invitation")
