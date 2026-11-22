local _, ns = ...
local Locale, Localization = ns.Macros.Host.Messages, ns.Macros.Host.Localization
local Macros = ns.Macros
local Host = Macros.Host
local Kit = Host.Kit
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
Win.CARDS, Win.CARD_H, Win.W = 6, 86, 820
Win.tab, Win.offset = "class", 0
Win.variant = {} -- [entry] = chosen target of a card with variants

function Win.ShowCode()
  return Win.tab ~= "mine" and Win.tab ~= "build" and Host.Get("macroShowCode") == true
end

function Win.CardHeight()
  return Win.ShowCode() and 170 or Win.CARD_H
end

-- Scroll by whole cards; the visible cards redraw, nothing else changes.
function Win.Scroll(delta)
  local w = Win.win
  if not (w and w.rowHeight) then return end
  Win.offset = math.max(0, math.min(Win.offset - delta, (Win.count or 0) - (Win.visibleCards or Win.CARDS)))
  w.list:Scroll(Win.offset * w.rowHeight)
end

-- "1-6 OF 40 · SCROLL" when the list is longer than the window.
function Win.ShowRange()
  local w, count, visible = Win.win, Win.count or 0, Win.visibleCards or Win.CARDS
  if not w then return end
  w.range:SetText(count > visible and Locale:Format("macros.window.value1_value2_of_value3_scroll.5d7b44", { value1 = string.format("%d", Win.offset + 1),
    value2 = string.format("%d", math.min(count, Win.offset + visible)), value3 = string.format("%d", count) }) or "")
end

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
  Win.TARGET_TIPS[base .. "target"] = { Locale:Format("macros.explain.value1_s_target.443aff", { value1 = UNITS[base].tip }),
    Locale:Format("macros.window.whoever_value2_is_targeting_your_own_target.99504a", { value2 = UNITS[base].phrase }) }
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
  mode = Win.MODES[mode] and mode or "pvp"
  if mode == "ranks" and not Macros.Ranks.Supported() then mode = "pvp" end
  if mode == Win.Mode() then return Win.SetTab(Win.tab) end
  return Win.Navigate(Win.tab, mode, { search = Win.win and Win.win.search:GetText() or "" })
end

-- The entry as it will be copied: the chosen arena/focus variant applied.
function Win.Resolve(entry)
  if not Win.Variants(entry) then return entry end
  -- Always the suffixed name ("Kick F"), so a variant matches its button.
  return Macros.WithTarget(entry, Win.variant[entry] or entry.target)
end

-- Save and report in chat. Returns ok, message.
function Win.Save(name, body, perCharacter)
  local ok, msg = Macros.Save(name, body, perCharacter)
  Win.notice = ok and (Locale:Format("macros.window.saved_name_open_wow_macros_then_drag.f06c59", { name = name })) or msg
  Host.Say(msg)
  Win.Refresh()
  return ok, msg
end

function Win.Copy(entry, perCharacter)
  local o = Win.Resolve(entry)
  local body, err = Macros.Build(o)
  if body then return Win.Save(o.name, body, perCharacter) end
  Host.Say(err)
  Win.Refresh()
  return false
end

-- Where your macros are, by name, read once per refresh: saved[name] =
-- 1 (General), 2 (Character) or 3 (both); savedBody[name] is the text Use
-- macro would open (Character first).
Win.saved, Win.savedBody = {}, {}
local WHERE = { "general", "character", "both" }

local function Note(_, name, body, _, perCharacter)
  local saved = Win.saved
  local bit = perCharacter and 2 or 1
  local now = saved[name] or 0
  if now ~= bit and now ~= 3 then saved[name] = now + bit end
  if perCharacter or not Win.savedBody[name] then Win.savedBody[name] = body end
end
function Win.ReadSaved()
  wipe(Win.saved); wipe(Win.savedBody)
  Macros.Each(Note)
end

-- "general", "character", "both" or nil for a macro name.
function Win.SavedIn(name)
  return WHERE[Win.saved[name] or 0]
end

-- A catalog card's state: "saved" (this text under its name), "differs"
-- (another text under its name, e.g. the PvP preset when this is PvE),
-- "pet", "missing" (spells not learned) or "ready". Returns state, where.
function Win.CardState(entry)
  local o = Win.Resolve(entry)
  local where = Win.SavedIn(o.name)
  if where then return Win.savedBody[o.name] == Macros.Build(o) and "saved" or "differs", where end
  if entry.pet then return "pet" end
  return #Macros.Missing(o) > 0 and "missing" or "ready"
end

local SAVED_IN = { both = "macros.window.saved_for_both.802c29", character = "macros.window.saved_for_this_character.6d998e",
  general = "macros.window.saved_for_all_characters.e08b1e" }
-- Status text and colour token of a catalog card.
function Win.Status(entry)
  local state, where = Win.CardState(entry)
  if state == "saved" then return Locale:Get(SAVED_IN[where]), "accent" end
  if state == "differs" then return Locale:Get("macros.card.differs"), "warning" end
  if state == "pet" then return Locale:Get("macros.window.pet_ability.f3d1e9"), "textMuted" end
  if state == "missing" then return Locale:Get("macros.window.spell_not_learned.952e97"), "warning" end
  return Locale:Get("macros.window.ready_to_use.448773"), "success"
end

-- Entries for the current tab and search. Preset lists are kept while only
-- the scroll position changes; spellbook changes rebuild them (Win.stamp).
Win.stamp = 0
local listKey, listCache
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
  -- The language is part of the key: searches match translated descriptions.
  local key = table.concat({ Win.tab, mode, query, tostring(me), tostring(Host.On("scriptMacros")), Win.stamp,
    Locale:GetLocale() }, "\0")
  if key == listKey then return listCache end
  listKey, listCache = key, list
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
  if not (w and w:IsShown()) or w.refreshing then return end
  w.refreshing = true
  w.tabGroup:SetSelected(Win.tab)
  local catalog = Win.tab ~= "mine" and Win.tab ~= "build"
  w.modeGroup:SetValue(Win.Mode(), true)
  w.modeGroup:SetShown(catalog)
  local building = Win.tab == "build"
  w.showCode:SetShown(catalog)
  w.showCode:SetText(Win.ShowCode() and Locale:Get("macros.window.hide_macro_code.f0672a") or Locale:Get("macros.frame.show_macro_code.2c34b1"))
  -- Geometry follows the tab, code previews, text size and window size; a
  -- scroll or search alone keeps it.
  local layout = table.concat({ Win.tab, tostring(Win.ShowCode()), Host.FontScale(), w:GetWidth(), w:GetHeight(),
    tostring(w:IsMovable()) }, "\0")
  if Win.Layout and layout ~= w.layoutKey then w.layoutKey = layout; Win.Layout() end
  Win.ReadSaved()
  local footer = Win.tab == "mine"
  if w.exportAll:IsShown() ~= footer then
    w.exportAll:SetShown(footer); w.import:SetShown(footer)
    w.footer:Layout(w.footer:GetWidth())
  end
  if Macros.BuildPanel then Macros.BuildPanel.Show(w, building) end
  w.search:SetShown(not building)
  w.open:SetShown(true) -- every tab, Create too: saved macros go to a bar from there
  w.help:SetShown(not building)
  w.help:SetText(Win.notice or Locale:Get("macros.window.choose_a_macro_then_drag_it_from.675489"))
  if w.history:IsShown() == building then
    w.history:SetShown(not building)
    w.footer:Layout(w.footer:GetWidth())
  end
  w.list:SetShown(not building)
  local list = building and {} or Win.List()
  local visible = Win.visibleCards or Win.CARDS
  Win.count = #list
  Win.offset = math.max(0, math.min(Win.offset, #list - visible))
  -- The cards render once, at the kept card offset (Kit.VirtualList).
  w.list.offset = Win.offset * w.rowHeight
  w.cards:SetItems(list)
  local empty = not building and #list == 0
  w.empty:SetShown(empty)
  if empty then
    -- A search uses the kit's localized "no matches" guidance.
    w.empty:SetState(Kit.ResolveState({ count = 0, filtered = w.search:GetText() ~= "",
      empty = Win.tab == "mine" and Locale:Get("macros.window.no_saved_macros_yet_choose_for_my.d7b6ab")
        or Win.Mode() == "ranks" and Locale:Get("macros.window.no_spells_with_ranks_in_your_spellbook.d68fe0")
        or Locale:Get("macros.window.no_macros_here_for_this_game.420400") }))
    w.empty:Layout(w.empty:GetWidth())
  end
  Win.ShowRange()
  local general, character, maxGeneral, maxCharacter = Macros.Limits()
  w.slots:SetText(Locale:Format("macros.window.all_characters_general_maxgeneral_this_character_character.b77c04", { general = string.format("%d", general), maxGeneral = string.format("%d", maxGeneral), character = string.format("%d", character), maxCharacter = string.format("%d", maxCharacter) }))
  local class = Host.Class()
  w:SetSub((Host.ClassName(class) or ""):upper()
    .. "  ·  " .. (Host.GameInfo().label or "") .. (catalog and (Locale:Format("macros.window.value2_presets.ec3bd8", { value2 = Win.Mode():upper() })) or ""))
  w.refreshing = nil
end

function Win.SetTab(key)
  local router = Win.GetRouter()
  local current = router:Current()
  -- Reselecting Create must also keep the identity of the open editor.
  if current and current.name == key then return router:Navigate(current) end
  return Win.Navigate(key)
end

-- Customize macro: a preset (as resolved: chosen target) into the builder.
function Win.CopyEdit(entry)
  return Win.OpenEditor(entry, true)
end

-- Open an existing macro in the builder; saving to its tab updates it.
function Win.Edit(e)
  return Win.OpenEditor(e)
end

-- Macros created, edited or deleted anywhere (also in Blizzard's macro
-- window): redraw the cards' saved state and slot counts at once. New
-- spells change which presets are ready: the next refresh rebuilds lists.
Host.Events({ UPDATE_MACROS = function() Win.Refresh() end,
  SPELLS_CHANGED = function() Win.stamp = Win.stamp + 1 end }, "macros window")
