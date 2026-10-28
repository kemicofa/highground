local _, ns = ...
local Macros = ns.Macros
local Host = Macros.Host

---------------------------------------------------------------------------
-- Macro builder: one factory for the catalog and for macros players build
-- themselves. Options (all but spell optional):
--   spell      spell name, or { cata = , retail = , forever = , tbc = } per game
--              (Classic Era and a missing tbc use forever: Macros.ForGame)
--   target     nil (no conditions) | "target" | "focus" | "mouseover" | "cursor" | "player" |
--              "arena1".."arena5" | "party1".."party4" | a unit's target such as
--              "focustarget" | "name" (a group member: unitName) (default "target")
--   unitName   target = "name": the group member's name, as spelled in game
--   of         their target: the target of the chosen unit or name (never yours changes)
--   kind       nil | "harm" | "help" | "any": adds harm/help,nodead to unit targets
--   fallback   also cast on your target when the first target is missing
--   self       last resort: cast on yourself (help spells)
--   stopcast   /stopcasting first (interrupts and instant CC while casting)
--   startattack  /startattack first (melee: keep auto attack going)
--   stopattack   /stopattack first (crowd control that damage breaks)
--   cancel     aura names to /cancelaura first (e.g. Bladestorm)
--   toggle     second press removes the aura (Ice Block, Divine Shield)
--   stance     { index, "Stance Name" }, or one per game: swap stance first if needed
--   force      "!" prefix: never toggle off a form (powershifting)
--   pet        pet ability: not in your spellbook
--   rank       pin a spell rank (downranking); nil casts your highest rank
--   verb       "cast" (default), "use" (spell is an item name or slot),
--              "castsequence" or "castrandom" (spell is "A, B, C")
--   reset      castsequence: "3/target/combat/shift" (seconds, target, combat, modifiers)
--   uses       items or slots to /use first, e.g. { "13", "Healthstone" }
--   lines      full body instead of the generated one
-- WoW limits: name 16 characters, body 255.
---------------------------------------------------------------------------
Macros.NAME_MAX, Macros.BODY_MAX = 16, 255
Macros.TARGETS = { "target", "focus", "mouseover", "cursor", "player", "party1", "party2", "party3", "party4",
  "arena1", "arena2", "arena3", "arena4", "arena5" }
local UNITS = Macros.Config.UNITS
-- Button labels of the targets (config/Macros.lua UNITS).
Macros.TARGET_LABEL = {}
for _, t in ipairs(Macros.TARGETS) do Macros.TARGET_LABEL[t] = UNITS[t].label end
Macros.KINDS = { "harm", "help", "any" }

-- Games without their own column in per-game tables use another game's:
-- Classic Era and The Burning Crusade (Anniversary) take WoW Forever's
-- vanilla spells unless an entry names them itself.
Macros.CONTENT_OF = { classic = "forever", tbc = "forever" }

-- t[game], falling back to the game whose content it shares.
function Macros.ForGame(t, game)
  game = game or Host.Game()
  local v = t[game]
  if v == nil and Macros.CONTENT_OF[game] then v = t[Macros.CONTENT_OF[game]] end
  return v
end

-- { index, name } stance for this game, if any.
function Macros.StanceFor(stance, game)
  if type(stance) ~= "table" then return nil end
  if stance[1] then return stance end
  return Macros.ForGame(stance, game)
end

-- The spell name for this game, or nil when the game lacks it.
function Macros.SpellFor(spell, game)
  if type(spell) == "table" then return Macros.ForGame(spell, game) end
  return spell
end

local function Unit(target, kind)
  if target == "cursor" or target == "player" then return "@" .. target end
  local cond = (kind == "harm" and ",harm,nodead") or (kind == "help" and ",help,nodead") or ""
  if target == "mouseover" then return "@mouseover" .. (cond ~= "" and cond or ",exists,nodead") end
  if target == "target" then return cond ~= "" and cond:sub(2) or nil end -- "[harm,nodead]"
  return "@" .. target .. cond
end

-- The unit token the options aim at: "focus", "party1target", "Bob",
-- "Bob-target" (names chain with hyphens), or nil for none.
function Macros.UnitOf(o)
  local t = o.target
  if t == "name" then
    t = Host.Trim(o.unitName)
    if t == "" then return nil end
    return o.of and (t .. "-target") or t
  end
  if o.of and t and t ~= "cursor" and t ~= "player" then return t .. "target" end
  return t
end

-- Whether fallback / self can change anything for these options.
function Macros.CanFallback(o)
  local t = Macros.UnitOf(o)
  return t ~= nil and t ~= "target" and t ~= "cursor" and t ~= "player"
end
function Macros.CanSelf(o)
  local t = o.target
  return t ~= "player" and t ~= "cursor" and (t ~= nil or o.kind ~= nil)
end

-- The conditional chain for the cast: "[@focus,harm,nodead][]".
function Macros.Conditions(o)
  local target = Macros.UnitOf(o) or "target"
  local parts = {}
  local unit = Unit(target, o.kind)
  if unit then parts[#parts + 1] = "[" .. unit .. "]" end
  if o.fallback and unit and Macros.CanFallback(o) then
    parts[#parts + 1] = o.kind == "help" and "[@target,help,nodead]" or "[]"
  end
  if o.self and unit and Macros.CanSelf(o) then parts[#parts + 1] = "[@player]" end
  return table.concat(parts)
end

-- Body text for a game, or nil and a reason.
function Macros.Build(o, game)
  if o.lines then
    local body = o.lines
    if type(body) == "table" then body = Macros.ForGame(body, game) end
    if not body then return nil, "not in this game" end
    return body
  end
  local spell = Macros.SpellFor(o.spell, game)
  if not spell or spell == "" then return nil, "not in this game" end
  local lines = { "#showtooltip" }
  local cancel = o.cancel
  if type(cancel) == "table" and cancel[1] == nil then cancel = Macros.ForGame(cancel, game) end
  for _, aura in ipairs(type(cancel) == "table" and cancel or { cancel }) do
    if aura and aura ~= "" then lines[#lines + 1] = "/cancelaura " .. aura end
  end
  if o.toggle then lines[#lines + 1] = "/cancelaura " .. spell end
  if o.stopcast then lines[#lines + 1] = "/stopcasting" end
  if o.stopattack then lines[#lines + 1] = "/stopattack"
  elseif o.startattack then lines[#lines + 1] = "/startattack" end
  for _, item in ipairs(o.uses or {}) do
    if item and item ~= "" then lines[#lines + 1] = "/use " .. item end
  end
  local cast = Macros.Conditions(o)
  local rank = tonumber(o.rank)
  if rank and o.verb ~= "use" and o.verb ~= "castsequence" and o.verb ~= "castrandom" then
    spell = Macros.Ranks.Pin(spell, rank)
  end
  local name = (o.force and "!" or "") .. spell
  local verb = "/" .. (o.verb or "cast") .. " "
  if o.verb == "castsequence" and o.reset and o.reset ~= "" then name = "reset=" .. o.reset .. " " .. name end
  if (o.verb == "castsequence" or o.verb == "castrandom") and o.force then name = spell end -- ! only on single casts
  local castLine = verb .. (cast ~= "" and (cast .. " ") or "") .. name
  local stance = Macros.StanceFor(o.stance, game)
  if stance then
    lines[1] = "#showtooltip " .. spell
    castLine = string.format("/cast [nostance:%s] %s; %s%s", stance[1], stance[2],
      cast ~= "" and (cast .. " ") or "", name)
  end
  lines[#lines + 1] = castLine
  local body = table.concat(lines, "\n")
  if #body > Macros.BODY_MAX then return nil, "longer than " .. Macros.BODY_MAX .. " characters" end
  return body
end

-- Spells the macro needs in your spellbook (pet abilities excluded).
function Macros.Needs(o, game)
  local list = {}
  if o.pet then return list end
  local spell = o.verb ~= "use" and Macros.SpellFor(o.spell, game)
  if spell and (o.verb == "castsequence" or o.verb == "castrandom") then
    for _, step in ipairs(Host.Split(spell)) do list[#list + 1] = step end
  elseif spell then
    list[#list + 1] = spell
  end
  for _, extra in ipairs(o.needs or {}) do
    local name = Macros.SpellFor(extra, game)
    if name then list[#list + 1] = name end
  end
  local stance = Macros.StanceFor(o.stance, game)
  if stance then list[#list + 1] = stance[2] end
  return list
end

-- Button label and name suffix of a unit (config/Macros.lua UNITS short):
-- "F", "MO", "A2", "P3", "Me"; someone's target adds T: "FT", "P1T", "TT".
-- nil for units without one (your target, cursor).
function Macros.ShortUnit(unit)
  if not unit then return nil end
  local base = unit ~= "target" and unit:match("^(.+)target$")
  if base then return (base == "target" and "T" or Macros.ShortUnit(base) or "") .. "T" end
  return UNITS[unit] and UNITS[unit].short
end

-- A short name for a target variant: "Kick" -> "Kick A2" within 16 characters.
function Macros.VariantName(name, target)
  local short = Macros.ShortUnit(target)
  local suffix = short and (" " .. short) or ""
  return name:sub(1, Macros.NAME_MAX - #suffix) .. suffix
end

-- A copy of o aimed at another target.
function Macros.WithTarget(o, target)
  local copy = {}
  for k, v in pairs(o) do copy[k] = v end
  copy.target = target
  copy.name = Macros.VariantName(o.name or "", target)
  return copy
end
