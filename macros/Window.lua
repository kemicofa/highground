local _, ns = ...
local Core, Macros = ns.Core, ns.Macros
local W = ns.Widgets
local C = Core.THEME.colors
Macros.Window = {}
local Win = Macros.Window

---------------------------------------------------------------------------
-- PvP macros window: general macros, your class (ready ones first), every
-- class, and a builder. Each macro copies into WoW's General or Character
-- macro tab. Opens with /wb macros or the Test and commands page.
---------------------------------------------------------------------------
Win.CARDS, Win.CARD_H, Win.W = 5, 82, 660
Win.tab, Win.offset = "class", 0
Win.variant = {} -- [entry] = chosen target for arena-capable macros
local GAME_LABEL = { cata = "CATACLYSM", retail = "RETAIL", forever = "WOW FOREVER" }
-- Target variants a card offers: enemy (arena) or ally (party) macros.
local VARIANTS = {
  arena = { { "focus", "F" }, { "arena1", "A1" }, { "arena2", "A2" }, { "arena3", "A3" } },
  party = { { "mouseover", "MO" }, { "party1", "P1" }, { "party2", "P2" }, { "player", "ME" } },
}
local function Variants(entry)
  if entry.arena then return Macros.ARENA_GAMES[ns.GAME] and VARIANTS.arena or nil end
  return entry.party and VARIANTS.party or nil
end

local function Say(text) print("|cffff5533Warboard|r " .. text) end

function Macros.InGame(entry, game)
  game = game or ns.GAME
  if entry.games and not entry.games[game] then return false end
  return Macros.Build(entry, game) ~= nil
end

-- The entry as it will be copied: the chosen arena/focus variant applied.
function Win.Resolve(entry)
  if not Variants(entry) then return entry end
  -- Always the suffixed name ("Kick F"), so a variant matches its button.
  return Macros.WithTarget(entry, Win.variant[entry] or entry.target)
end

function Win.Copy(entry, perCharacter)
  local o = Win.Resolve(entry)
  local body, err = Macros.Build(o)
  local ok, msg
  if body then ok, msg = Macros.Save(o.name, body, perCharacter) else ok, msg = false, err end
  Say(msg)
  Win.Refresh()
  return ok
end

-- Where your macros are, by name, read once per refresh:
-- saved[name] = { general = true?, character = true? }.
Win.saved = {}
Win.SCOPE_COLOR = { general = { 0.13, 0.55, 0.52 }, character = { 0.5, 0.36, 0.85 } }

function Win.ReadSaved()
  wipe(Win.saved)
  for _, m in ipairs(Macros.Existing()) do
    local s = Win.saved[m.name] or {}
    s[m.perCharacter and "character" or "general"] = true
    Win.saved[m.name] = s
  end
end

-- "general", "character", "both" or nil for a macro name.
function Win.SavedIn(name)
  local s = Win.saved[name]
  if not s then return nil end
  return (s.general and s.character and "both") or (s.general and "general") or "character"
end

local function Status(entry)
  local o = Win.Resolve(entry)
  local where = Win.SavedIn(o.name)
  if where then return where == "both" and "IN GENERAL + CHARACTER" or ("IN " .. where:upper()), C.accent end
  if entry.pet then return "PET", C.muted end
  local missing = Macros.Missing(o)
  if #missing > 0 then return "NEEDS " .. table.concat(missing, ", "):upper(), C.warning end
  return "READY", { 0.4, 0.9, 0.55 }
end

function Win.NewCard(parent)
  local r = CreateFrame("Frame", nil, parent)
  r:SetHeight(Win.CARD_H)
  local bg = Core.Fill(r, "BACKGROUND", C.surface[1], C.surface[2], C.surface[3], 0.85)
  bg:SetAllPoints()
  r.strip = Core.Fill(r, "ARTWORK", 1, 1, 1, 1)
  r.strip:SetPoint("TOPLEFT")
  r.strip:SetPoint("BOTTOMLEFT")
  r.strip:SetWidth(3)
  r.name = Core.Text(r, "bold", 15)
  r.name:SetPoint("TOPLEFT", 12, -6)
  r.class = Core.Text(r, "mono", 8)
  r.class:SetPoint("LEFT", r.name, "RIGHT", 6, 0)
  r.class:SetTextColor(unpack(C.muted))
  r.desc = Core.Text(r, "medium", 11)
  r.desc:SetPoint("TOPLEFT", 12, -24)
  r.desc:SetPoint("RIGHT", r, "RIGHT", -170, 0)
  r.desc:SetJustifyH("LEFT")
  r.desc:SetTextColor(unpack(C.muted))
  r.body = Core.Text(r, "mono", 9)
  r.body:SetPoint("TOPLEFT", 12, -40)
  r.body:SetPoint("RIGHT", r, "RIGHT", -170, 0)
  r.body:SetJustifyH("LEFT")
  r.body:SetJustifyV("TOP")
  r.body:SetWordWrap(true)
  r.body:SetHeight(38)
  r.status = Core.Text(r, "mono", 8)
  r.status:SetPoint("TOPRIGHT", -8, -8)
  r.status:SetWidth(150)
  r.status:SetJustifyH("RIGHT")
  r.general = W.Button(r, "General", 74, 20, C.panel, function(self)
    local e = self.card.entry
    if e.existing then Win.Edit(e) else Win.Copy(e, false) end
  end)
  r.general:SetPoint("BOTTOMRIGHT", -84, 8)
  r.character = W.Button(r, "Character", 74, 20, C.panel, function(self)
    local e = self.card.entry
    if e.existing then
      local ok, msg = Macros.Save(e.name, e.body, not e.perCharacter)
      Say(msg)
      Win.Refresh()
    else
      Win.Copy(e, true)
    end
  end)
  r.character:SetPoint("BOTTOMRIGHT", -6, 8)
  r.general.card, r.character.card = r, r
  r.variants = {}
  for i = 1, 4 do
    local b = W.Button(r, "", 30, 16, C.panel, function(self)
      local e = self.card.entry
      if e.existing then return Macros.Share.ShowExport({ e }) end
      Win.variant[e] = self.target
      Win.Refresh()
    end)
    b:SetPoint("TOPRIGHT", r, "TOPRIGHT", -6 - (4 - i) * 33, -28)
    b.card = r
    r.variants[i] = b
  end
  r:EnableMouse(true)
  r:SetScript("OnEnter", function(self) Win.Explain(self) end)
  r:SetScript("OnLeave", GameTooltip_Hide)
  r:Hide()
  return r
end

-- A variant button: fill = where that variant is saved, gold outline and
-- label = the variant the card shows and copies.
function Win.PaintVariant(b, where, selected)
  if not b.ring then
    b.ring = {}
    for i, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
      { "TOPLEFT", "BOTTOMLEFT", true }, { "TOPRIGHT", "BOTTOMRIGHT", true } }) do
      local t = b:CreateTexture(nil, "OVERLAY")
      t:SetColorTexture(W.GOLD[1], W.GOLD[2], W.GOLD[3], 1)
      t:SetPoint(side[1])
      t:SetPoint(side[2])
      if side[3] then t:SetWidth(2) else t:SetHeight(2) end
      b.ring[i] = t
    end
    b.both = b:CreateTexture(nil, "ARTWORK")
    b.both:SetPoint("BOTTOMLEFT", 2, 2)
    b.both:SetPoint("BOTTOMRIGHT", -2, 2)
    b.both:SetHeight(3)
    local v = Win.SCOPE_COLOR.character
    b.both:SetColorTexture(v[1], v[2], v[3], 1)
  end
  local fill = (where == "general" or where == "both") and Win.SCOPE_COLOR.general
    or where == "character" and Win.SCOPE_COLOR.character or C.panel
  W.Paint(b, fill, selected and W.GOLD or C.text)
  for _, t in ipairs(b.ring) do t:SetShown(selected) end
  b.both:SetShown(where == "both")
  b.where, b.selected = where, selected
end

-- Hover: what the macro does, compiled from its text.
function Win.Explain(r)
  if not r.entry then return end
  local o = r.entry.existing and r.entry or Win.Resolve(r.entry)
  local body = r.entry.existing and r.entry.body or Macros.Build(o)
  if not body then return end
  local result = Macros.Analyze(body, { pet = o.pet })
  GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
  GameTooltip:AddLine(o.name, 1, 0.82, 0)
  for _, line in ipairs(Macros.Explain(result)) do GameTooltip:AddLine(line, 0.9, 0.9, 0.9, true) end
  for _, pr in ipairs(result.problems) do
    GameTooltip:AddLine((pr.level == "error" and "Error: " or "Note: ") .. pr.text, 1, 0.7, 0.3, true)
  end
  GameTooltip:Show()
end

-- An existing macro: compiled to show whether it is sound.
local function FillExisting(r, e)
  r.entry = e
  r.strip:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
  r.name:SetText(e.name)
  r.name:SetTextColor(unpack(C.text))
  r.class:SetText(e.perCharacter and "CHARACTER" or "GENERAL")
  local result = Macros.Analyze(e.body)
  local explain = Macros.Explain(result)
  r.desc:SetText(explain[#explain] or "")
  r.body:SetText(e.body)
  local text, color = "OK", { 0.4, 0.9, 0.55 }
  if result.errors > 0 then
    text, color = result.errors .. " ERROR" .. (result.errors > 1 and "S" or ""), { 1, 0.35, 0.35 }
  elseif result.warnings > 0 then
    text, color = result.warnings .. " WARNING" .. (result.warnings > 1 and "S" or ""), C.warning
  end
  r.status:SetText(text)
  r.status:SetTextColor(color[1], color[2], color[3])
  r.general:SetText("Edit")
  r.character:SetText(e.perCharacter and "To General" or "To Character")
  for i, b in ipairs(r.variants) do b:SetShown(i == 1) end
  local share = r.variants[1]
  share.target = nil
  share:SetText("EXPORT")
  W.Paint(share, C.panel, C.text)
  r:Show()
end

local function Fill(r, entry)
  if entry.existing then return FillExisting(r, entry) end
  r.general:SetText("General")
  r.character:SetText("Character")
  r.entry = entry
  local o = Win.Resolve(entry)
  local cc = entry.class and ns.Util.ClassColor(entry.class)
  r.strip:SetColorTexture(cc and cc.r or W.GOLD[1], cc and cc.g or W.GOLD[2], cc and cc.b or W.GOLD[3], 1)
  r.name:SetText(o.name)
  if cc then r.name:SetTextColor(cc.r, cc.g, cc.b) else r.name:SetTextColor(unpack(C.text)) end
  r.class:SetText(entry.class and (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[entry.class] or entry.class):upper()
    or "GENERAL")
  r.desc:SetText(entry.desc or "")
  r.body:SetText(Macros.Build(o) or "")
  local text, color = Status(entry)
  r.status:SetText(text)
  r.status:SetTextColor(color[1], color[2], color[3])
  local chosen = Win.variant[entry] or entry.target
  local list = Variants(entry)
  for i, b in ipairs(r.variants) do
    local v = list and list[i]
    b.target = v and v[1]
    b:SetText(v and v[2] or "")
    b:SetShown(v ~= nil)
    if v then Win.PaintVariant(b, Win.SavedIn(Macros.VariantName(entry.name, v[1])), v[1] == chosen) end
  end
  r:Show()
end

-- Entries for the current tab and search.
function Win.List()
  local list, me = {}, Core.me and Core.me.class
  local query = Win.win and Win.win.search:GetText():lower() or ""
  if Win.tab == "mine" then
    for _, e in ipairs(Macros.Existing()) do
      if query == "" or (e.name .. " " .. e.body):lower():find(query, 1, true) then list[#list + 1] = e end
    end
    return list
  end
  for _, e in ipairs(Macros.catalog) do
    local tab = Win.tab
    local keep = (tab == "general" and not e.class) or (tab == "class" and e.class == me) or (tab == "all" and e.class)
    if keep and Macros.InGame(e) and (query == "" or (e.name .. " " .. (e.desc or "") .. " " .. (e.class or "")):lower():find(query, 1, true)) then
      list[#list + 1] = e
    end
  end
  if Win.tab == "class" then
    -- Ready first (your spec's spells), then the rest of your class.
    local ready = {}
    for _, e in ipairs(list) do ready[e] = e.pet or #Macros.Missing(e) == 0 end
    table.sort(list, function(a, b)
      if ready[a] ~= ready[b] then return ready[a] end
      return a.name < b.name
    end)
  end
  return list
end

function Win.Refresh()
  local w = Win.win
  if not (w and w:IsShown()) then return end
  for key, t in pairs(w.tabs) do t:Select(key == Win.tab) end
  local building = Win.tab == "build"
  Win.ReadSaved()
  w.exportAll:SetShown(Win.tab == "mine")
  w.import:SetShown(Win.tab == "mine")
  if Macros.BuildPanel then Macros.BuildPanel.Show(w, building) end
  w.search:SetShown(not building)
  local list = building and {} or Win.List()
  Win.offset = math.max(0, math.min(Win.offset, #list - Win.CARDS))
  for i, r in ipairs(w.rows) do
    local e = list[i + Win.offset]
    if e then Fill(r, e) else r.entry = nil; r:Hide() end
  end
  w.empty:SetText(not building and #list == 0 and (Win.tab == "mine" and "You have no macros yet."
    or "No macros here for this game.") or "")
  w.range:SetText(#list > Win.CARDS and string.format("%d-%d OF %d  ·  SCROLL", Win.offset + 1,
    math.min(#list, Win.offset + Win.CARDS), #list) or "")
  local general, character, maxGeneral, maxCharacter = Macros.Limits()
  w.slots:SetText(string.format("GENERAL %d/%d  ·  CHARACTER %d/%d", general, maxGeneral, character, maxCharacter))
  local class = Core.me and Core.me.class
  w.sub:SetText(((class and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class or ""):upper()
    .. "  ·  " .. (GAME_LABEL[ns.GAME] or ""))
end

function Win.SetTab(key)
  Win.tab, Win.offset = key, 0
  Win.Refresh()
end

-- Open an existing macro in the builder; saving to its tab updates it.
function Win.Edit(e)
  Win.SetTab("build")
  if Macros.BuildPanel.Load then Macros.BuildPanel.Load(e) end
end
