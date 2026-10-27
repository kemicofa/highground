local _, ns = ...
local Core, Theme, Kit = ns.Core, ns.Theme, ns.Kit
local S, Z = Theme.Space, Theme.Size
local Hub = ns.Hub

-- Home: where you are and what Warboard is doing, previews one click away,
-- and shortcuts to the other sections.

Hub.OFF_CHIPS = 5
local TILE_W, TILE_GAP, COLUMNS = 170, S("md"), 4
local CARD_H, SHORTCUT_H = 86, 44
local SHORTCUTS = {
  { "general", "Turn features on or off" },
  { "macros", "Macros for your class" },
  { "bountyboard", "Wanted players" },
  { "profiles", "Save, load and share settings" },
}

-- Feature switches this client has, in catalog order.
-- The client never changes in a session, so the list is built once.
local features
local function Features()
  if features then return features end
  features = {}
  for _, f in ipairs(ns.OptionsConfig.features) do
    if f.key and ns.OptionAvailable(f) then features[#features + 1] = f end
  end
  return features
end

-- Preview buttons, minus those that open a hub section.
local function Previews()
  local own, list = {}, {}
  for _, s in ipairs(Hub.sections or {}) do if s.cmd then own[s.cmd] = true end end
  for _, def in ipairs(ns.CommandCatalog.previews) do
    if ns.OptionAvailable(def) and not own[def.cmd] then list[#list + 1] = def end
  end
  return list
end

local function SectionLabel(key)
  for _, s in ipairs(Hub.sections or {}) do if s.key == key then return s.label end end
  return key
end

local function ChipTooltip(self)
  if not self.feature then return end
  GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
  local r, g, b = Theme.Color("gold")
  GameTooltip:AddLine(self.feature.label or "", r, g, b)
  if self.feature.desc then
    r, g, b = Theme.Color("text")
    GameTooltip:AddLine(self.feature.desc, r, g, b, true)
  end
  r, g, b = Theme.Color("accent")
  GameTooltip:AddLine(self.more and "Click to see them on Features." or "Off. Click to find its switch on Features.",
    r, g, b, true)
  GameTooltip:Show()
end

local function Tile(col, row, y)
  return col * (TILE_W + TILE_GAP), y - row * (Z("tab") + S("sm") + S("xs"))
end

function Hub.BuildHome(content)
  local h = CreateFrame("Frame", nil, content)
  h:SetAllPoints()
  Hub.home = h

  local card = Kit.Card(h, CARD_H, { titleRole = "number" })
  card:SetPoint("TOPLEFT", 0, 0)
  card:SetPoint("RIGHT", 0, 0)
  card:EnableMouse(false) -- status only: no hover, drags reach the window
  h.card, h.where, h.features = card, card.title, card.sub
  h.state = Theme.Text(card, "bodyLarge", "textMuted")
  h.state:SetPoint("TOPLEFT", S("lg"), -40)
  h.state:SetPoint("RIGHT", -S("xl"), 0)
  h.state:SetJustifyH("LEFT")

  -- Switched-off features by name: hover for what each does, click for its switch.
  local y = -CARD_H - S("md") - S("sm")
  h.offLabel = Kit.Chip(h, "", "warning")
  h.offLabel:SetPoint("LEFT", h, "TOPLEFT", S("xs"), y - Z("row") / 2)
  h.offChips = {}
  for i = 1, Hub.OFF_CHIPS do
    local chip = Kit.Button(h, "", 120, Z("row"), { onClick = function() Hub.Show("general") end })
    chip:SetScript("OnEnter", function(self) self.hover:Show(); ChipTooltip(self) end)
    chip:SetScript("OnLeave", function(self) self.hover:Hide(); GameTooltip_Hide() end)
    chip:Hide()
    h.offChips[i] = chip
  end
  h.chipY = y

  y = y - Z("row") - S("lg") - S("xs")
  h.previewTitle = Kit.Section(h, "Previews  ·  click again to stop")
  h.previewTitle:SetPoint("TOPLEFT", S("xs"), y)
  y = y - S("xl")
  h.previews = {}
  local col, row = 0, 0
  for _, def in ipairs(Previews()) do
    local b = Kit.Button(h, def.label, TILE_W, Z("tab"), { onClick = function() SlashCmdList.WARBOARD(def.cmd) end })
    b:SetPoint("TOPLEFT", Tile(col, row, y))
    b.cmd = def.cmd
    h.previews[#h.previews + 1] = b
    col = col + 1
    if col == COLUMNS then col, row = 0, row + 1 end
  end
  local _, below = Tile(0, row + (col > 0 and 1 or 0), y)
  y = below - S("xl") - S("xs")

  h.goTitle = Kit.Section(h, "Go to")
  h.goTitle:SetPoint("TOPLEFT", S("xs"), y)
  h.shortcuts = {}
  for i, s in ipairs(SHORTCUTS) do
    local key = s[1]
    local b = Kit.Button(h, SectionLabel(key), TILE_W, SHORTCUT_H, { onClick = function() Hub.Show(key) end })
    b:SetPoint("TOPLEFT", (i - 1) * (TILE_W + TILE_GAP), y - S("xl"))
    b.label:ClearAllPoints()
    b.label:SetPoint("TOPLEFT", S("md") + S("xs"), -S("md"))
    b.hint = Theme.Text(b, "body", "textMuted")
    b.hint:SetPoint("BOTTOMLEFT", S("md") + S("xs"), S("md"))
    b.hint:SetText(s[2])
    b.key = key
    h.shortcuts[i] = b
  end
  h.help = Theme.Text(h, "body", "textMuted")
  h.help:SetPoint("BOTTOMLEFT", S("sm"), S("sm"))
  h.help:SetText("Type /wb help for every command  ·  the Blizzard settings panel still has every page")
  h:Hide()
end

local function Where(h)
  local _, kind = IsInInstance()
  local bg = ns.GetBG and ns.GetBG()
  local active = ns.IsActive and ns.IsActive()
  if kind == "pvp" then
    h.where:SetText((bg and bg.name or "Battleground"):upper())
    h.state:SetText(active and "Warboard is on: enemy list, timers and intel are running."
      or "Warboard is off here: check Every battleground and the size switches on Features.")
  elseif kind == "arena" then
    h.where:SetText("ARENA")
    h.state:SetText(Core.On("arena") and "The arena enemy panel is on." or "The arena enemy panel is off.")
  else
    h.where:SetText("OPEN WORLD")
    h.state:SetText((Core.On("nearby") and "Nearby enemies are listed" or "Nearby enemies are off")
      .. (Core.On("bounty") and ", bounty targets alert." or "; bounty alerts are off."))
  end
  h.card:SetStrip(active and "accent" or "textMuted")
end

-- Chips until the row is full; the last one counts what didn't fit.
local function OffChips(h, off)
  local x, room = S("xs") + h.offLabel:GetWidth() + S("md"), (h:GetWidth() or 700) - S("sm")
  local shown = 0
  for _, chip in ipairs(h.offChips) do chip:Hide() end
  for i, f in ipairs(off) do
    local chip = h.offChips[shown + 1]
    if not chip then break end
    local width = math.min(180, 24 + #f.label * 6)
    local last = shown + 1 == Hub.OFF_CHIPS or x + width + 96 > room
    if last and i < #off then
      chip.feature, chip.more = { label = (#off - i + 1) .. " more switched off" }, true
      chip:SetText("+" .. (#off - i + 1) .. " MORE")
      width = 80
    else
      chip.feature, chip.more = f, false
      chip:SetText(f.label)
    end
    chip:SetWidth(width)
    chip:ClearAllPoints()
    chip:SetPoint("TOPLEFT", h, "TOPLEFT", x, h.chipY)
    chip:Show()
    x, shown = x + width + S("sm") + S("xs"), shown + 1
    if chip.more then break end
  end
end

function Hub.RefreshHome()
  local h = Hub.home
  if not h then return end
  Where(h)
  local features, off = Features(), {}
  for _, f in ipairs(features) do if not Core.On(f.key) then off[#off + 1] = f end end
  h.features:SetText(string.format("%d OF %d FEATURES ON", #features - #off, #features))
  local label = h.offLabel
  if #off == 0 then label:Set("EVERY FEATURE IS ON", "success") else label:Set("OFF", "warning") end
  local fs = label.label
  local textW = fs.GetStringWidth and fs:GetStringWidth() or 0
  if textW <= 0 then textW = #label.text * 6 end
  label:SetWidth(textW + S("md") * 2)
  OffChips(h, off)
end
