local _, ns = ...
local Macros = ns.Macros
local Host = Macros.Host
local Theme = Host.Theme
Macros.Window = {}
local Win = Macros.Window

---------------------------------------------------------------------------
-- Macros window: PvP or PvE presets (general, your class with ready ones
-- first, every class), your own macros and a builder. Each macro copies
-- into WoW's General or Character macro tab. Opens with /hg macros or the
-- Test and commands page.
-- This file: state, lists and refresh. Cards: macros/Card.lua; the frame:
-- macros/Frame.lua.
---------------------------------------------------------------------------
Win.CARDS, Win.CARD_H, Win.W = 5, 82, 660
Win.VARIANT_W, Win.EXPORT_W = 30, 62
Win.tab, Win.offset = "class", 0
Win.variant = {} -- [entry] = chosen target for arena-capable macros
local GAME_LABEL = { cata = "CATACLYSM", retail = "RETAIL", forever = "WOW FOREVER", classic = "CLASSIC ERA",
  tbc = "BURNING CRUSADE" }
-- Target variants a card offers: enemy (arena, or focus and mouseover in
-- PvE) or ally (party) macros.
local VARIANTS = {
  arena = { { "focus", "F" }, { "arena1", "A1" }, { "arena2", "A2" }, { "arena3", "A3" } },
  enemy = { { "focus", "F" }, { "mouseover", "MO" }, { "target", "T" } },
  party = { { "mouseover", "MO" }, { "party1", "P1" }, { "party2", "P2" }, { "player", "ME" } },
  -- Someone else's target: yours stays.
  assist = { { "focustarget", "FT" }, { "mouseovertarget", "MOT" }, { "party1target", "P1T" }, { "party2target", "P2T" } },
}
-- What each target button means, for its tooltip.
Win.TARGET_TIPS = {
  target = { "Target", "Your current target" },
  focus = { "Focus", "Your focus target" },
  mouseover = { "Mouseover", "The unit under your mouse, on a nameplate, frame or in the world" },
  cursor = { "Cursor", "The ground at your cursor, no targeting circle" },
  player = { "Me", "Yourself" },
}
for i = 1, 5 do
  Win.TARGET_TIPS["arena" .. i] = { "Arena " .. i, "Arena enemy " .. i
    .. (i == 1 and " (the first enemy on the arena frames)" or i > 3 and " (5v5 only)" or "") }
end
for i = 1, 4 do
  Win.TARGET_TIPS["party" .. i] = { "Party " .. i, "Party member " .. i
    .. (i == 1 and " (the first under you on the party frames)" or "") }
end
-- Their target: "focustarget" and the like.
local WHO = { focus = "your focus", mouseover = "the unit under your mouse", target = "your target",
  party1 = "party member 1", party2 = "party member 2", party3 = "party member 3", party4 = "party member 4" }
for base, who in pairs(WHO) do
  Win.TARGET_TIPS[base .. "target"] = { Win.TARGET_TIPS[base][1] .. "'s target",
    "Whoever " .. who .. " is targeting. Your own target does not change." }
end

-- Hover tooltip of a target button: b.value (builder) or b.target (card).
-- note: an extra line, e.g. where that variant is saved.
function Win.TargetTip(b, note)
  b:HookScript("OnEnter", function(self)
    local t = Win.TARGET_TIPS[self.value or self.target]
    if not t then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    Win.TipLine(t[1], "gold")
    Win.TipLine(t[2], "text", true)
    local extra = type(note) == "function" and note(self) or note
    if extra then Win.TipLine(extra, "textMuted", true) end
    GameTooltip:Show()
  end)
  b:HookScript("OnLeave", GameTooltip_Hide)
end

-- Spells that can't target yourself (self = false): no ME button.
VARIANTS.partyOthers = { VARIANTS.party[1], VARIANTS.party[2], VARIANTS.party[3] }
function Win.Variants(entry)
  if entry.arena then return Macros.ARENA_GAMES[Host.Game()] and VARIANTS.arena or nil end
  if entry.party then return entry.self == false and VARIANTS.partyOthers or VARIANTS.party end
  if entry.assist then return VARIANTS.assist end
  return entry.enemy and VARIANTS.enemy or nil
end

-- Targets behind a card's + button: party 3-4, arena 4-5 in 5v5 games.
function Win.MoreVariants(entry)
  local out = {}
  if entry.arena and Macros.ARENA_GAMES[Host.Game()] then
    for i = 4, Macros.ARENA_SIZE[Host.Game()] or 3 do out[#out + 1] = { "arena" .. i, "A" .. i } end
  elseif entry.party then
    for i = 3, 4 do out[#out + 1] = { "party" .. i, "P" .. i } end
  elseif entry.assist then
    for i = 3, 4 do out[#out + 1] = { "party" .. i .. "target", "P" .. i .. "T" } end
  end
  return #out > 0 and out or nil
end

-- Which presets the catalog tabs show: "pvp", "pve" or, in games with
-- spell ranks, "ranks" (your ranked spells, macros/Ranks.lua). Saved.
Win.MODES = { pvp = true, pve = true, ranks = true }
function Win.Mode()
  local mode = Host.Get("macroMode")
  if mode == "ranks" and not Macros.Ranks.Supported() then return "pvp" end
  return Win.MODES[mode] and mode or "pvp"
end
function Win.SetMode(mode)
  Host.Set("macroMode", Win.MODES[mode] and mode or "pvp")
  Win.offset = 0
  Win.Refresh()
end

-- Where a macro is saved: colour token of each macro tab.
Win.SCOPE_TOKEN = { general = "scopeGeneral", character = "scopeCharacter" }

-- Tooltip line in a colour token.
function Win.TipLine(text, token, wrap)
  Theme.TipLine(GameTooltip, text, token, wrap)
end

-- Whether a catalog entry is a preset of mode ("pvp" or "pve").
function Macros.InMode(entry, mode)
  local m = entry.mode or "pvp"
  return m == "both" or m == mode
end

function Macros.InGame(entry, game)
  game = game or Host.Game()
  if entry.games and not Macros.ForGame(entry.games, game) then return false end
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
  Host.Say(msg)
  Win.Refresh()
  return ok
end

function Win.Copy(entry, perCharacter)
  local o = Win.Resolve(entry)
  local body, err = Macros.Build(o)
  if body then return Win.Save(o.name, body, perCharacter) end
  Host.Say(err)
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
  local list, me = {}, Host.Class()
  local query = Win.win and Win.win.search:GetText():lower() or ""
  if Win.tab == "mine" then
    for _, e in ipairs(Macros.Existing()) do
      if query == "" or (e.name .. " " .. e.body):lower():find(query, 1, true) then list[#list + 1] = e end
    end
    return list
  end
  local mode = Win.Mode()
  if mode == "ranks" then -- every tab: your own spellbook
    for _, e in ipairs(Macros.Ranks.Presets()) do
      if query == "" or e.spell:lower():find(query, 1, true) then list[#list + 1] = e end
    end
    return list
  end
  for _, e in ipairs(Macros.catalog) do
    local tab = Win.tab
    local keep = (tab == "general" and not e.class) or (tab == "class" and e.class == me) or (tab == "all" and e.class)
    if keep and Macros.InMode(e, mode) and Macros.InGame(e) and (query == "" or (e.name .. " " .. (e.desc or "") .. " " .. (e.class or "")):lower():find(query, 1, true)) then
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
  local catalog = Win.tab ~= "mine" and Win.tab ~= "build"
  for key, t in pairs(w.modes) do
    t:Select(key == Win.Mode())
    t:SetShown(catalog and (key ~= "ranks" or Macros.Ranks.Supported()))
  end
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
    or Win.Mode() == "ranks" and "No spells with ranks in your spellbook."
    or "No macros here for this game.") or "")
  w.range:SetText(#list > Win.CARDS and string.format("%d-%d OF %d  ·  SCROLL", Win.offset + 1,
    math.min(#list, Win.offset + Win.CARDS), #list) or "")
  local general, character, maxGeneral, maxCharacter = Macros.Limits()
  w.slots:SetText(string.format("GENERAL %d/%d  ·  CHARACTER %d/%d", general, maxGeneral, character, maxCharacter))
  local class = Host.Class()
  w:SetSub(((class and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class or ""):upper()
    .. "  ·  " .. (GAME_LABEL[Host.Game()] or "") .. (catalog and ("  ·  " .. Win.Mode():upper() .. " PRESETS") or ""))
end

function Win.SetTab(key)
  Win.tab, Win.offset = key, 0
  Win.Refresh()
end

-- Copy & Edit: a preset (as resolved: chosen target) into the builder.
function Win.CopyEdit(entry)
  Win.SetTab("build")
  Macros.BuildPanel.LoadPreset(entry, Win.Resolve(entry))
end

-- Open an existing macro in the builder; saving to its tab updates it.
function Win.Edit(e)
  Win.SetTab("build")
  if Macros.BuildPanel.Load then Macros.BuildPanel.Load(e) end
end

-- Macros created, edited or deleted anywhere (also in Blizzard's macro
-- window): redraw the cards' saved state and slot counts at once.
Host.Events({ UPDATE_MACROS = function() Win.Refresh() end }, "macros window")
