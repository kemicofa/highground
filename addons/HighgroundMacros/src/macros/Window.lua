local _, ns = ...
local Macros = ns.Macros
local Host = Macros.Host
local UNITS = Macros.Config.UNITS
Macros.Window = {}
local Win = Macros.Window

---------------------------------------------------------------------------
-- Macros window: PVP, PVE or (games with spell ranks) RANKS presets in
-- tabs (general, your class with ready ones first, every class), your own
-- macros and a builder. A card copies its macro into WoW's General or
-- Character tab, or opens it in the builder (Customize macro). Opens with
-- /hg macros, from the Highground window or the minimap; in Highground
-- Macros with /hgm.
-- This file: state, lists and refresh. Cards: macros/Card.lua; the frame:
-- macros/Frame.lua; the builder: macros/BuildPanel.lua (layout) and
-- macros/BuildLogic.lua (behaviour).
---------------------------------------------------------------------------
Win.CARDS, Win.CARD_H, Win.W = 5, 108, 820
Win.tab, Win.offset = "class", 0
Win.variant = {} -- [entry] = chosen target of a card with variants

-- Short names remain in saved macro names for WoW's 16-character limit.
local function Label(unit)
  return (Macros.ShortUnit(unit) or unit == "target" and "T" or ""):upper()
end
local function Variant(unit) return { unit, Label(unit) } end

-- Target variants a card offers: arena (focus, arena 1-3), enemy (focus,
-- mouseover, target), party (mouseover, party 1-2, you) or assist (someone
-- else's target; yours stays). MoreVariants supplies additional menu entries.
local VARIANTS = {}
for kind, units in pairs({
  arena = { "focus", "arena1", "arena2", "arena3" },
  enemy = { "focus", "mouseover", "target" },
  party = { "mouseover", "party1", "party2", "player" },
  assist = { "focustarget", "mouseovertarget", "party1target", "party2target" },
}) do
  VARIANTS[kind] = {}
  for i, unit in ipairs(units) do VARIANTS[kind][i] = Variant(unit) end
end

-- What each target button means, for its tooltip: { title, text }
-- (config/Macros.lua UNITS), and "X's target" for the assist ones.
Win.TARGET_TIPS = {}
for unit, u in pairs(UNITS) do
  if u.tip then Win.TARGET_TIPS[unit] = { u.tip, u.about } end
end
for _, base in ipairs({ "target", "focus", "mouseover", "party1", "party2", "party3", "party4" }) do
  Win.TARGET_TIPS[base .. "target"] = { UNITS[base].tip .. "'s target",
    "Whoever " .. UNITS[base].phrase .. " is targeting. Your own target does not change." }
end

-- Spells that can't target yourself (self = false): no ME button.
VARIANTS.partyOthers = { VARIANTS.party[1], VARIANTS.party[2], VARIANTS.party[3] }
function Win.Variants(entry)
  if entry.arena then return Host.GameInfo().arenaSize and VARIANTS.arena or nil end
  if entry.party then return entry.self == false and VARIANTS.partyOthers or VARIANTS.party end
  if entry.assist then return VARIANTS.assist end
  return entry.enemy and VARIANTS.enemy or nil
end

-- Additional targets in the same menu: party 3-4, arena 4-5 in 5v5 games.
function Win.MoreVariants(entry)
  local out, arenas = {}, Host.GameInfo().arenaSize
  if entry.arena and arenas then
    for i = 4, arenas do out[#out + 1] = Variant("arena" .. i) end
  elseif entry.party then
    for i = 3, 4 do out[#out + 1] = Variant("party" .. i) end
  elseif entry.assist then
    for i = 3, 4 do out[#out + 1] = Variant("party" .. i .. "target") end
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

-- The entry as it will be copied: the chosen arena/focus variant applied.
function Win.Resolve(entry)
  if not Win.Variants(entry) then return entry end
  -- Always the suffixed name ("Kick F"), so a variant matches its button.
  return Macros.WithTarget(entry, Win.variant[entry] or entry.target)
end

-- Save and report in chat. Returns ok.
function Win.Save(name, body, perCharacter)
  local ok, msg = Macros.Save(name, body, perCharacter)
  Win.notice = ok and ("Saved " .. name .. ". Open WoW macros, then drag its icon to an action bar.") or msg
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
  if where then return where == "both" and "Saved for both" or (where == "character" and "Saved for this character" or "Saved for all characters"), "accent" end
  if entry.pet then return "Pet ability", "textMuted" end
  local missing = Macros.Missing(o)
  if #missing > 0 then return "Spell not learned", "warning" end
  return "Ready to use", "success"
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
    if keep and Macros.InMode(e, mode) and Macros.Allowed(e) and Macros.InGame(e) and (query == "" or (e.name .. " " .. (e.desc or "") .. " " .. (e.class or "")):lower():find(query, 1, true)) then
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
  if Win.Layout then Win.Layout() end
  Win.ReadSaved()
  w.exportAll:SetShown(Win.tab == "mine")
  w.import:SetShown(Win.tab == "mine")
  if Macros.BuildPanel then Macros.BuildPanel.Show(w, building) end
  w.search:SetShown(not building)
  w.open:SetShown(not building)
  w.help:SetShown(not building)
  w.help:SetText(Win.notice or "Choose a macro, then drag it from WoW macros to an action bar.")
  if w.history then w.history:SetShown(not building) end
  local list = building and {} or Win.List()
  local visible = Win.visibleCards or Win.CARDS
  Win.offset = math.max(0, math.min(Win.offset, #list - visible))
  for i, r in ipairs(w.rows) do
    local e = i <= visible and list[i + Win.offset] or nil
    if e then Win.Fill(r, e) else r.entry = nil; r:Hide() end
  end
  w.empty:SetText(not building and #list == 0 and (w.search:GetText() ~= "" and "No matches. Clear the search to see all macros in this tab."
    or Win.tab == "mine" and "No saved macros yet. Choose For my class to find one, or Create to write your own."
    or Win.Mode() == "ranks" and "No spells with ranks in your spellbook."
    or "No macros here for this game.") or "")
  w.range:SetText(#list > visible and string.format("%d-%d OF %d  ·  SCROLL", Win.offset + 1,
    math.min(#list, Win.offset + visible), #list) or "")
  local general, character, maxGeneral, maxCharacter = Macros.Limits()
  w.slots:SetText(string.format("All characters %d/%d  ·  This character %d/%d", general, maxGeneral, character, maxCharacter))
  local class = Host.Class()
  w:SetSub((Host.ClassName(class) or ""):upper()
    .. "  ·  " .. (Host.GameInfo().label or "") .. (catalog and ("  ·  " .. Win.Mode():upper() .. " PRESETS") or ""))
end

function Win.SetTab(key)
  Win.tab, Win.offset = key, 0
  if Win.win then Win.win.search:SetText("") end
  Win.Refresh()
end

-- Customize macro: a preset (as resolved: chosen target) into the builder.
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
