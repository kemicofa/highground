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

  Section(h, "PREVIEWS  ·  CLICK AGAIN TO STOP", -104)
  h.previews = {}
  local col, row = 0, 0
  for _, def in ipairs(ns.Options.PREVIEWS or {}) do
    if ns.OptionAvailable(def) and def.cmd ~= "macros" and def.cmd ~= "bounty" then
      local b = W.Button(h, def.label, 170, 26, C.surface, function() SlashCmdList.WARBOARD(def.cmd) end)
      b:SetPoint("TOPLEFT", col * 178, -120 - row * 32)
      b.cmd = def.cmd
      h.previews[#h.previews + 1] = b
      col = col + 1
      if col == 4 then col, row = 0, row + 1 end
    end
  end
  local y = -120 - (row + (col > 0 and 1 or 0)) * 32 - 18

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
  local on, total = 0, 0
  for _, f in ipairs(ns.OptionsConfig.features) do
    if f.key and ns.OptionAvailable(f) then
      total = total + 1
      if Core.On(f.key) then on = on + 1 end
    end
  end
  h.features:SetText(string.format("%d OF %d FEATURES ON", on, total))
end
