local _, ns = ...
local Core = ns.Core
local C = Core.THEME.colors
local Hub = ns.Hub

-- Home: where you are and what Warboard is doing, previews one click away,
-- and shortcuts to the other sections.

local function Section(parent, text, y)
  local fs = Core.Text(parent, "mono", 9)
  fs:SetPoint("TOPLEFT", 4, y)
  fs:SetText(text)
  fs:SetTextColor(unpack(C.muted))
  return fs
end

function Hub.BuildHome(content)
  local W = ns.Widgets
  local h = CreateFrame("Frame", nil, content)
  h:SetAllPoints()
  Hub.home = h

  local card = CreateFrame("Frame", nil, h)
  card:SetPoint("TOPLEFT", 0, 0)
  card:SetPoint("RIGHT", 0, 0)
  card:SetHeight(86)
  local bg = Core.Fill(card, "BACKGROUND", C.surface[1], C.surface[2], C.surface[3], 0.85)
  bg:SetAllPoints()
  h.strip = Core.Fill(card, "ARTWORK", C.accent[1], C.accent[2], C.accent[3], 1)
  h.strip:SetPoint("TOPLEFT")
  h.strip:SetPoint("BOTTOMLEFT")
  h.strip:SetWidth(4)
  h.where = Core.Text(card, "bold", 22)
  h.where:SetPoint("TOPLEFT", 16, -12)
  h.state = Core.Text(card, "medium", 13)
  h.state:SetPoint("TOPLEFT", 16, -40)
  h.state:SetPoint("RIGHT", -16, 0)
  h.state:SetJustifyH("LEFT")
  h.state:SetTextColor(unpack(C.muted))
  h.features = Core.Text(card, "mono", 9)
  h.features:SetPoint("BOTTOMLEFT", 16, 10)
  h.features:SetTextColor(unpack(C.muted))

  -- Switched-off features by name: hover for what each does, click for its switch.
  h.offLabel = Core.Text(h, "mono", 9)
  h.offLabel:SetPoint("TOPLEFT", 4, -100)
  h.offLabel:SetTextColor(unpack(C.muted))
  h.offChips = {}
  for i = 1, Hub.OFF_CHIPS do
    local chip = W.Button(h, "", 120, 20, C.surface, function() Hub.Show("general") end)
    chip:SetScript("OnEnter", function(self)
      if not self.feature then return end
      GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
      GameTooltip:AddLine(self.feature.label or "", 1, 0.82, 0)
      if self.feature.desc then GameTooltip:AddLine(self.feature.desc, 0.9, 0.9, 0.9, true) end
      GameTooltip:AddLine(self.more and "Click to see them on Features." or "Off. Click to find its switch on Features.",
        0.6, 0.85, 0.8, true)
      GameTooltip:Show()
    end)
    chip:SetScript("OnLeave", GameTooltip_Hide)
    chip:Hide()
    h.offChips[i] = chip
  end

  Section(h, "PREVIEWS  ·  CLICK AGAIN TO STOP", -134)
  h.previews = {}
  local col, row = 0, 0
  for _, def in ipairs(ns.Options.PREVIEWS or {}) do
    if ns.OptionAvailable(def) and def.cmd ~= "macros" and def.cmd ~= "bounty" then
      local b = W.Button(h, def.label, 170, 26, C.surface, function() SlashCmdList.WARBOARD(def.cmd) end)
      b:SetPoint("TOPLEFT", col * 178, -150 - row * 32)
      b.cmd = def.cmd
      h.previews[#h.previews + 1] = b
      col = col + 1
      if col == 4 then col, row = 0, row + 1 end
    end
  end
  local y = -150 - (row + (col > 0 and 1 or 0)) * 32 - 18

  Section(h, "GO TO", y)
  h.shortcuts = {}
  for i, s in ipairs({ { "features", "general", "Turn features on or off" }, { "PvP macros", "macros", "Macros for your class" },
    { "Bounty board", "bountyboard", "Wanted players" }, { "Profiles", "profiles", "Save, load and share settings" } }) do
    local b = W.Button(h, s[1] == "features" and "Features" or s[1], 170, 44, C.surface, function() Hub.Show(s[2]) end)
    b:SetPoint("TOPLEFT", (i - 1) * 178, y - 16)
    b.label:ClearAllPoints()
    b.label:SetPoint("TOPLEFT", 10, -7)
    b.hint = Core.Text(b, "medium", 10)
    b.hint:SetPoint("BOTTOMLEFT", 10, 7)
    b.hint:SetText(s[3])
    b.hint:SetTextColor(unpack(C.muted))
    b.key = s[2]
    h.shortcuts[i] = b
  end
  h.help = Core.Text(h, "medium", 11)
  h.help:SetPoint("BOTTOMLEFT", 4, 4)
  h.help:SetTextColor(unpack(C.muted))
  h.help:SetText("Type /wb help for every command  ·  the Blizzard settings panel still has every page")
  h:Hide()
end

Hub.OFF_CHIPS = 5

function Hub.RefreshHome()
  local h = Hub.home
  if not h then return end
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
  local color = active and C.accent or C.muted
  h.strip:SetColorTexture(color[1], color[2], color[3], 1)
  local on, total, off = 0, 0, {}
  for _, f in ipairs(ns.OptionsConfig.features) do
    if f.key and ns.OptionAvailable(f) then
      total = total + 1
      if Core.On(f.key) then on = on + 1 else off[#off + 1] = f end
    end
  end
  h.features:SetText(string.format("%d OF %d FEATURES ON", on, total))
  h.offLabel:SetText(#off == 0 and "EVERY FEATURE IS ON" or "OFF:")
  -- Chips until the row is full; the last one counts what didn't fit.
  local x, room = 34, (h:GetWidth() or 700) - 4
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
    chip:SetPoint("TOPLEFT", h, "TOPLEFT", x, -96)
    chip:Show()
    x, shown = x + width + 6, shown + 1
    if chip.more then break end
  end
end
