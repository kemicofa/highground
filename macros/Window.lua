local _, ns = ...
local Core, Macros, Theme = ns.Core, ns.Macros, ns.Theme
Macros.Window = {}
local Win = Macros.Window

---------------------------------------------------------------------------
-- PvP macros window: general macros, your class (ready ones first), every
-- class, and a builder. Each macro copies into WoW's General or Character
-- macro tab. Opens with /wb macros or the Test and commands page.
-- This file: state, lists and refresh. Cards: macros/Card.lua; the frame:
-- macros/Frame.lua.
---------------------------------------------------------------------------
Win.CARDS, Win.CARD_H, Win.W = 5, 82, 660
Win.VARIANT_W, Win.EXPORT_W = 30, 62
Win.tab, Win.offset = "class", 0
Win.variant = {} -- [entry] = chosen target for arena-capable macros
local GAME_LABEL = { cata = "CATACLYSM", retail = "RETAIL", forever = "WOW FOREVER" }
-- Target variants a card offers: enemy (arena) or ally (party) macros.
local VARIANTS = {
  arena = { { "focus", "F" }, { "arena1", "A1" }, { "arena2", "A2" }, { "arena3", "A3" } },
  party = { { "mouseover", "MO" }, { "party1", "P1" }, { "party2", "P2" }, { "player", "ME" } },
}
function Win.Variants(entry)
  if entry.arena then return Macros.ARENA_GAMES[ns.GAME] and VARIANTS.arena or nil end
  return entry.party and VARIANTS.party or nil
end

-- Where a macro is saved: colour token of each macro tab.
Win.SCOPE_TOKEN = { general = "scopeGeneral", character = "scopeCharacter" }

-- Tooltip line in a colour token.
function Win.TipLine(text, token, wrap)
  local r, g, b = Theme.Color(token)
  GameTooltip:AddLine(text, r, g, b, wrap)
end

function Macros.InGame(entry, game)
  game = game or ns.GAME
  if entry.games and not entry.games[game] then return false end
  return Macros.Build(entry, game) ~= nil
end

-- The entry as it will be copied: the chosen arena/focus variant applied.
function Win.Resolve(entry)
  if not Win.Variants(entry) then return entry end
  -- Always the suffixed name ("Kick F"), so a variant matches its button.
  return Macros.WithTarget(entry, Win.variant[entry] or entry.target)
end

-- Save and report in chat. Returns ok.
function Win.Save(name, body, perCharacter)
  local ok, msg = Macros.Save(name, body, perCharacter)
  ns.Util.Say(msg)
  Win.Refresh()
  return ok
end

function Win.Copy(entry, perCharacter)
  local o = Win.Resolve(entry)
  local body, err = Macros.Build(o)
  if body then return Win.Save(o.name, body, perCharacter) end
  ns.Util.Say(err)
  Win.Refresh()
  return false
end

-- Where your macros are, by name, read once per refresh:
-- saved[name] = { general = true?, character = true? }.
Win.saved = {}

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

-- Status text and colour token of a catalog card.
function Win.Status(entry)
  local o = Win.Resolve(entry)
  local where = Win.SavedIn(o.name)
  if where then return where == "both" and "IN GENERAL + CHARACTER" or ("IN " .. where:upper()), "accent" end
  if entry.pet then return "PET", "textMuted" end
  local missing = Macros.Missing(o)
  if #missing > 0 then return "NEEDS " .. table.concat(missing, ", "):upper(), "warning" end
  return "READY", "success"
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
    if e then Win.Fill(r, e) else r.entry = nil; r:Hide() end
  end
  w.empty:SetText(not building and #list == 0 and (Win.tab == "mine" and "You have no macros yet."
    or "No macros here for this game.") or "")
  w.range:SetText(#list > Win.CARDS and string.format("%d-%d OF %d  ·  SCROLL", Win.offset + 1,
    math.min(#list, Win.offset + Win.CARDS), #list) or "")
  local general, character, maxGeneral, maxCharacter = Macros.Limits()
  w.slots:SetText(string.format("GENERAL %d/%d  ·  CHARACTER %d/%d", general, maxGeneral, character, maxCharacter))
  local class = Core.me and Core.me.class
  w:SetSub(((class and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class or ""):upper()
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
