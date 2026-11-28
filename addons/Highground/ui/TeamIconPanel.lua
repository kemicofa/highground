local _, ns = ...
local Core, Kit, Theme = ns.Core, ns.Kit, ns.Theme

---------------------------------------------------------------------------
-- Team icons quick panel: when you lead a newly formed group, a small panel
-- offers automatic icons for everyone: Class icons, Role icons, or Remove
-- all (core/TeamIcons.lua). X closes it, and so does entering a
-- battleground or arena. It appears once per group (Core.TeamIconOffered);
-- /hg icons panel and the Team icons window's Quick panel button bring it
-- back. The "Quick panel when you lead a group" switch stops it appearing.
---------------------------------------------------------------------------
local Panel = {}
ns.TeamIconPanel = Panel
local WIDTH, KEY = 320, "teamIconPanel"
local f

local function Apply(fn, ...)
  local ok, why = fn(...)
  if not ok then ns.Util.Say(ns.TeamIcons.WhyText(why)) end
end

local function Button(key, onClick)
  local b = Kit.Button(f, ns.Locale:Get(key), 1, nil, { onClick = onClick })
  ns.Localization.Bind(b, key)
  return b
end

local function Build()
  if f then return f end
  f = CreateFrame("Frame", "HighgroundTeamIconPanel", UIParent, "BackdropTemplate")
  Panel.frame = f
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); Kit.SavePoint(KEY, self) end)
  Theme.Backdrop(f)
  f:Hide()
  local md, gap = Theme.Space("md"), Theme.Space("xs")
  f.close = Kit.Button(f, "X", Theme.Size("close"), Theme.Size("close"), { onClick = function() Panel.Hide() end })
  f.close:SetPoint("TOPRIGHT", -gap, -gap)
  Kit.Tooltip(f.close, function() return { ns.Locale:Get("highground.profilereview.close.bbfa77") } end)
  f.title = Theme.Text(f, "label", "text")
  f.title:SetPoint("TOPLEFT", md, -md); f.title:SetPoint("RIGHT", f.close, "LEFT", -gap, 0); f.title:SetJustifyH("LEFT")
  ns.Localization.Bind(f.title, "highground.teamicons.team_icons.c632c4")
  f.text = Theme.Text(f, "body", "textMuted")
  f.text:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -gap); f.text:SetPoint("RIGHT", -md, 0)
  f.text:SetJustifyH("LEFT"); f.text:SetWordWrap(true)
  ns.Localization.Bind(f.text, "highground.teamicons.give_everyone_in_your_group_an_icon.6a3a62")
  local third = (WIDTH - md * 2 - gap * 2) / 3
  f.class = Button("highground.teamicons.class_icons.cbf1ae", function() Apply(Core.SetTeamIconRule, "class") end)
  f.role = Button("highground.teamicons.role_icons.3a8deb", function() Apply(Core.SetTeamIconRule, "role") end)
  f.remove = Button("highground.teamicons.remove_all.4100ef", function() Apply(Core.ClearTeamIcons) end)
  for i, b in ipairs({ f.class, f.role, f.remove }) do
    b:SetWidth(third)
    b:SetPoint("TOPLEFT", f.text, "BOTTOMLEFT", (i - 1) * (third + gap), -md)
  end
  f.status = Theme.Text(f, "body", "textMuted")
  f.status:SetPoint("TOPLEFT", f.class, "BOTTOMLEFT", 0, -gap); f.status:SetPoint("RIGHT", -md, 0)
  f.status:SetJustifyH("LEFT"); f.status:SetWordWrap(true)
  f:SetWidth(WIDTH)
  Kit.PlaceWindow(f, KEY, { "TOP", "TOP", 0, -140 })
  return f
end

-- Buttons follow who may change icons; the line under them says what is on.
function Panel.Refresh()
  if not (f and f:IsShown()) then return end
  local lock, rule = Core.TeamIconLock(), Core.TeamIconRule()
  f.class:SetEnabled(not lock); f.role:SetEnabled(not lock)
  f.remove:SetEnabled(not lock and (rule ~= nil or next(Core.TeamIconMarks()) ~= nil))
  Kit.Paint(f.class, rule == "class" and "selected" or "surface")
  Kit.Paint(f.role, rule == "role" and "selected" or "surface")
  if lock then
    f.status:SetText(Core.TeamIconLockText(lock))
  elseif rule then
    f.status:SetText(ns.Locale:Format("highground.display.automatic_team_icons_rule.2fa1da", { rule = Core.TeamIconRuleName(rule) }))
  else
    f.status:SetText(ns.Locale:Get("highground.display.automatic_team_icons_off.547723"))
  end
  f:SetHeight(math.ceil(Theme.Space("md") * 2 + f.title:GetStringHeight() + f.text:GetStringHeight()
    + f.class:GetHeight() + f.status:GetStringHeight() + Theme.Space("xs") * 2 + Theme.Space("md")))
end

function Panel.Show()
  Build():Show()
  Panel.Refresh()
end
function Panel.Hide() if f then f:Hide() end end
function Panel.Shown() return f ~= nil and f:IsShown() end
function Panel.Toggle()
  if Panel.Shown() then Panel.Hide() else Panel.Show() end
  return Panel.Shown()
end

local function InMatch()
  local _, kind = ns.Util.call(IsInInstance)
  return kind == "pvp" or kind == "arena"
end

-- Once per group, when you lead it with someone else in it.
local function Offer()
  if not (Core.db and Core.On("teamIcons") and Core.On("teamIconPanel")) or Core.TeamIconOffered() then return end
  if Core.TeamIconLock() or (ns.Util.read(GetNumGroupMembers, LE_PARTY_CATEGORY_HOME) or 0) < 2 then return end
  Core.SetTeamIconOffered()
  Panel.Show()
end

local refreshWindow = Core.RefreshTeamIcons
Core.RefreshTeamIcons = function()
  if refreshWindow then refreshWindow() end
  Panel.Refresh()
end

ns.Util.Events({
  GROUP_ROSTER_UPDATE = Offer,
  PARTY_LEADER_CHANGED = Offer,
  GROUP_LEFT = function() Panel.Hide() end,
  PLAYER_ENTERING_WORLD = function() if InMatch() then Panel.Hide() end end,
}, "team icon panel", "battlegrounds")
