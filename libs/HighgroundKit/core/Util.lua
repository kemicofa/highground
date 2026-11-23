local _, ns = ...

-- Helpers shared by every subsystem. No load-time dependencies, so it loads
-- first; core/Events.lua follows it with guarded calls, event frames and
-- timers (Util.Guard, Util.Events, Util.Every). ns.Core and ns.Theme are
-- looked up per call. Secret values: Util.secret(v) tests, Util.plain(v)
-- is a boolean, Util.value(v) returns v or nil (modules alias it as Plain).
local Util = {}
ns.Util = Util

-- Midnight returns secret values for enemy data; they must not be compared
-- or used as table keys. Looked up per call: the global is client-only.
function Util.secret(v)
  return issecretvalue ~= nil and issecretvalue(v) or false
end

-- True for a readable, non-nil value.
function Util.plain(v)
  return not Util.secret(v) and v ~= nil
end

-- The value when readable, otherwise nil. Always one result, so
-- tostring(Util.value(v)) and format arguments get nil, not nothing.
function Util.value(v)
  if Util.plain(v) then return v end
  return nil
end

-- pcall that returns the results, or nothing when fn is missing or errors.
function Util.call(fn, ...)
  if type(fn) ~= "function" then return end
  local ok, a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p = pcall(fn, ...)
  if ok then return a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p end
end

-- First result of Util.call when readable.
function Util.read(fn, ...)
  return Util.value((Util.call(fn, ...)))
end

-- True in battlegrounds and arenas, and while the game restricts addons
-- (combat, encounters, keystones, PvP matches, restricted maps). Blizzard
-- menus built then can hold secret sizes; an addon entry taints the build
-- and the menu fails to lay out, so unit menus add nothing.
local RESTRICTIONS = { "Combat", "Encounter", "ChallengeMode", "PvPMatch", "Map" }
function Util.Restricted()
  local _, kind = Util.call(IsInInstance)
  if kind == "pvp" or kind == "arena" then return true end
  local api, types = C_RestrictedActions, Enum and Enum.AddOnRestrictionType
  if not (api and types) then return false end
  for _, name in ipairs(RESTRICTIONS) do
    if types[name] ~= nil and Util.read(api.IsAddOnRestrictionActive, types[name]) then return true end
  end
  return false
end

-- "A" or "H": the battleground faction (from core), else the character's.
function Util.MyTeam()
  local f = ns.GetAllyFaction and ns.GetAllyFaction()
  if f == 1 or f == 0 then return f == 1 and "A" or "H" end
  return UnitFactionGroup("player") == "Alliance" and "A" or "H"
end

-- Stronger stock class colours, keeping their familiar hues. In
-- particular, Rogue yellow should not look like Priest white. Cache by
-- source RGB so live changes are picked up without allocating per row.
local classColors = {}
function Util.ClassColor(class)
  local custom = CUSTOM_CLASS_COLORS and class and CUSTOM_CLASS_COLORS[class]
  if custom then return custom end
  local c = RAID_CLASS_COLORS and class and RAID_CLASS_COLORS[class]
  if not c then return end
  local cached = classColors[class]
  if cached and cached.r == c.r and cached.g == c.g and cached.b == c.b then return cached.color end
  local high, low = math.max(c.r, c.g, c.b), math.min(c.r, c.g, c.b)
  if high == low then return c end -- Priest white and neutral fallbacks
  local saturation = math.min(1.6, high / (high - low))
  local color = { r = math.max(0, high - (high - c.r) * saturation),
    g = math.max(0, high - (high - c.g) * saturation), b = math.max(0, high - (high - c.b) * saturation) }
  classColors[class] = { r = c.r, g = c.g, b = c.b, color = color }
  return color
end

-- A class token's name in the game's language ("WARRIOR" -> "Warrior").
function Util.ClassName(class)
  return class and (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class] or class)
end

-- Sort class tokens by their names in the game's language.
function Util.SortClasses(list)
  table.sort(list, function(a, b) return Util.ClassName(a) < Util.ClassName(b) end)
  return list
end

---------------------------------------------------------------------------
-- Text
---------------------------------------------------------------------------
function Util.Trim(s)
  return ((s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Split on one character (default ","); trim pieces and drop empty ones.
function Util.Split(s, sep)
  local p = (sep or ","):gsub("%p", "%%%0")
  local out = {}
  for piece in ((s or "") .. (sep or ",")):gmatch("([^" .. p .. "]*)" .. p) do
    piece = Util.Trim(piece)
    if piece ~= "" then out[#out + 1] = piece end
  end
  return out
end
-- "3 errors" in the selected language (Locale:Plural families).
local COUNT_MESSAGES = {
  ["error"] = "shared.labels.count_errors.f54d63", ["warning"] = "shared.labels.count_warnings.c294c0",
  ["button"] = "shared.labels.count_buttons.d5c07b", ["macro"] = "shared.labels.count_macros.6f76de",
  ["character"] = "shared.labels.count_characters.4d4b13", ["ERROR"] = "shared.labels.count_errors.398f7f",
  ["WARNING"] = "shared.labels.count_warnings.385555", ["MACRO"] = "shared.labels.count_macros.c9dfa7",
}
function Util.Plural(n, word)
  local base = COUNT_MESSAGES[word]
  if base then return ns.Locale:Plural(base, n) end
  if n == 1 then return n .. " " .. word end
  return n .. " " .. word .. (word:upper() == word and "S" or "s")
end

-- Seconds as "m:ss", rounded down: Util.Clock(75) -> "1:15".
-- opts.round: nearest second, never below 0, under a minute as "42s"
-- (Util.Clock(41.6, { round = true }) -> "42s").
function Util.Clock(seconds, opts)
  if opts and opts.round then
    seconds = math.max(0, math.floor(seconds + 0.5))
    if seconds < 60 then return seconds .. "s" end
  end
  return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
end

-- Strip the separators used by addon messages: , ; : |
function Util.Clean(s)
  return (tostring(s or ""):gsub("[,;:|]", ""))
end

-- Seconds since something: "now", "42s", "7m".
function Util.Ago(seconds)
  if seconds < 3 then return ns.Locale:Get("shared.util.now.c9bc84") end
  if seconds < 60 then return string.format("%ds", seconds) end
  return string.format("%dm", math.floor(seconds / 60))
end

---------------------------------------------------------------------------
-- Game data, the same on every client (C_Spell where it exists, else the
-- old globals). nil when the game doesn't answer or the value is secret.
---------------------------------------------------------------------------
local function Spell(name, global)
  local api = ns.Api -- config/Client.lua, loaded before this file's callers run
  return api and api.Fn("C_Spell", name, global)
end

function Util.SpellName(id) return Util.read(Spell("GetSpellName", "GetSpellInfo"), id) end
function Util.SpellTexture(spell) return Util.read(Spell("GetSpellTexture"), spell) end

-- Spell ID of a spell you know, by name (the highest rank where spells have ranks).
-- C_Spell.GetSpellInfo returns a table; the older global, its 7th value.
function Util.SpellID(name)
  local info, _, _, _, _, _, id = Util.call(Spell("GetSpellInfo"), name)
  if type(info) == "table" then return Util.value(info.spellID) end
  return Util.value(id)
end

-- Numbered unit tokens ("raid1".."raid40"), built once per prefix and count.
local unitTokens = {}
function Util.UnitTokens(prefix, count)
  local lists = unitTokens[prefix] or {}
  unitTokens[prefix] = lists
  if not lists[count] then
    lists[count] = {}
    for i = 1, count do lists[count][i] = prefix .. i end
  end
  return lists[count]
end

-- Health of a unit from 0 to 1, or nil (unknown, secret or no maximum).
function Util.HealthFraction(unit)
  local hp, max = Util.read(UnitHealth, unit), Util.read(UnitHealthMax, unit)
  if type(hp) ~= "number" or type(max) ~= "number" or max <= 0 then return nil end
  return hp / max
end

-- Subzone, else zone, else "".
function Util.ZoneName()
  local zone = Util.read(GetSubZoneText) or ""
  if zone == "" then zone = Util.read(GetZoneText) or "" end
  return zone
end

-- "1,234g" (digit grouping when the client provides BreakUpLargeNumbers).
function Util.Gold(n)
  n = tonumber(n) or 0
  return (BreakUpLargeNumbers and BreakUpLargeNumbers(n) or tostring(n)) .. "g"
end

-- Play the raid warning sound. Callers decide whether sound is enabled.
function Util.AlertSound()
  Util.call(PlaySound, SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master")
end

---------------------------------------------------------------------------
-- Chat output
---------------------------------------------------------------------------
-- Colours resolve through ns.Theme.TipHex(token) (chat is a dark frame) when
-- the theme is loaded (ui/ loads after core/, so it is looked up per call);
-- the literal is the fallback. hex is "rrggbb". The label is the addon's
-- name in chat (ns.LABEL, set by an addon that embeds this file).
local LABEL = ns.LABEL or "Highground"
Util.SAY_KINDS = {
  default = { label = LABEL, token = "brand", hex = "ff5533" },
  bounty = { label = LABEL .. " bounty", token = "bounty", hex = "ffd11a" },
  error = { label = LABEL, token = "brand", hex = "ff5533", text = "error", textHex = "ff5555" },
  warning = { label = LABEL, token = "brand", hex = "ff5533", text = "warning", textHex = "ffaa33" },
}

-- "|cffRRGGBB" for a theme token, else for the fallback hex. Accepts a theme
-- answer of "rrggbb", "aarrggbb", "#rrggbb" or a full "|caarrggbb".
function Util.ColorCode(token, fallback)
  local Theme = ns.Theme
  local fn = Theme and (Theme.TipHex or Theme.Hex)
  local hex = token and type(fn) == "function" and Util.call(fn, token)
  if type(hex) == "string" then
    if hex:match("^|c%x%x%x%x%x%x%x%x$") then return hex end
    hex = hex:gsub("^#", "")
    if hex:match("^%x%x%x%x%x%x%x%x$") then return "|c" .. hex end
    if hex:match("^%x%x%x%x%x%x$") then return "|cff" .. hex end
  end
  return "|cff" .. fallback
end

-- Coloured "Highground" label (no trailing space). kind as in Util.Say.
function Util.Prefix(kind)
  local k = Util.SAY_KINDS[kind or "default"] or Util.SAY_KINDS.default
  return Util.ColorCode(k.token, k.hex) .. k.label .. "|r"
end

-- Print and return one chat line: prefix, a space, then text. kind is nil,
-- "bounty", "error" or "warning"; error and warning colour the text too.
function Util.Say(text, kind)
  local k = Util.SAY_KINDS[kind or "default"] or Util.SAY_KINDS.default
  text = tostring(text)
  if k.text then text = Util.ColorCode(k.text, k.textHex) .. text .. "|r" end
  local line = Util.Prefix(kind) .. " " .. text
  print(line)
  return line
end
