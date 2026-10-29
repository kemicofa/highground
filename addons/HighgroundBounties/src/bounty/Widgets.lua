local _, ns = ...
local Bounty, Theme, Kit = ns.Bounty, ns.Theme, ns.Kit

---------------------------------------------------------------------------
-- Bounty board pieces on the UI kit (ui/kit/): state labels and colours,
-- the wanted card and relative times (Bounty.Widgets, also ns.Widgets).
---------------------------------------------------------------------------
local W = {}
Bounty.Widgets = W
ns.Widgets = W

-- Bounty states: { label, r, g, b, token = colour token }, rebuilt when
-- the theme changes.
local STATES = { personal = { "PERSONAL", "textMuted" }, pending = { "PENDING", "pending" },
  approved = { "GUILD", "gold" } }
W.STATE = {}
local function BuildStates()
  for key, def in pairs(STATES) do
    local s = W.STATE[key] or {}
    local r, g, b = Theme.Color(def[2])
    s[1], s[2], s[3], s[4], s.token = def[1], r, g, b, def[2]
    W.STATE[key] = s
  end
end
BuildStates()
Theme.OnChange(BuildStates)

-- Wanted card: state strip, portrait, name and realm, who placed it, note,
-- reward, status chip, last sighting, two action buttons and chat sharing.
-- lines(card): its hover lines for Kit.Tooltip (nil: no tooltip).
function W.Card(parent, height, lines)
  local r = Kit.Card(parent, height, { strip = "gold", icon = true, titleRole = "cardTitle" })
  if lines then Kit.Tooltip(r, lines, { anchor = "ANCHOR_RIGHT" }) end
  r.name = r.title
  r.realm = Theme.Text(r, "bodySmall", "textMuted")
  r.realm:SetPoint("BOTTOMLEFT", r.name, "BOTTOMRIGHT", 4, 1)
  r.sub:ClearAllPoints()
  r.sub:SetPoint("BOTTOMLEFT", 52, 7)
  r.sub:SetPoint("RIGHT", r, "RIGHT", -330, 0)

  r.chip = CreateFrame("Frame", nil, r)
  r.chip:SetSize(Theme.Size("chipWidth"), Theme.Size("chip"))
  r.chip:SetPoint("TOPRIGHT", r, "TOPRIGHT", -150, -8)
  r.chipBg = Theme.Fill(r.chip, "BACKGROUND", "overlayStrong")
  r.chipBg:SetAllPoints()
  r.tag = Theme.Text(r.chip, "caption")
  r.tag:SetPoint("CENTER", 0, 0)
  r.seen = Theme.Text(r, "caption")
  r.seen:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -150, 8)
  r.seen:SetJustifyH("RIGHT")

  r.gold = Theme.Text(r, "number", "gold")
  r.gold:SetPoint("RIGHT", r, "RIGHT", -170 - 62 - 6, 2)
  r.coin = r:CreateTexture(nil, "ARTWORK")
  r.coin:SetSize(14, 14)
  r.coin:SetPoint("LEFT", r.gold, "RIGHT", 3, 0)
  r.coin:SetTexture(Bounty.ICON)
  r.coin:SetTexCoord(unpack(Bounty.ICON_CROP))

  r.buttons = {}
  for j = 1, 2 do
    local b = Kit.Button(r, "", 66, 20, { tone = "panel", onClick = function(self) if self.run then self.run() end end })
    b:SetPoint("TOPRIGHT", r, "TOPRIGHT", -8 - (2 - j) * 70, -4)
    r.buttons[j] = b
  end
  r.share = Kit.Button(r, "Share in chat", 136, 20, {
    onClick = function(self) if self.run then self.run() end end,
  })
  r.share:SetPoint("BOTTOMRIGHT", -8, 4)
  Kit.Tooltip(r.share, { { "Share this bounty", "gold" },
    { "Prepare a chat message. Choose your channel and press Enter to send it.", "text", true } })
  r:Hide()
  return r
end

-- "NOW", "5M AGO", "3H AGO", "2D AGO". Coarser than Util.Ago (which counts
-- seconds and stops at minutes): sightings can be days old.
function W.Ago(seconds)
  seconds = math.max(0, math.floor(seconds))
  if seconds < 60 then return "NOW" end
  if seconds < 3600 then return math.floor(seconds / 60) .. "M AGO" end
  if seconds < 86400 then return math.floor(seconds / 3600) .. "H AGO" end
  return math.floor(seconds / 86400) .. "D AGO"
end
