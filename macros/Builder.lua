local _, ns = ...
ns.Macros = ns.Macros or {}
local Macros = ns.Macros

---------------------------------------------------------------------------
-- Macro builder: one factory for the catalog and for macros players build
-- themselves. Options (all but spell optional):
--   spell      spell name, or { cata = , retail = , forever = } per game
--   target     nil (no conditions) | "target" | "focus" | "mouseover" | "cursor" | "player" |
--              "arena1".."arena3" | "party1" | "party2" (default "target")
--   kind       nil | "harm" | "help" | "any": adds harm/help,nodead to unit targets
--   fallback   also cast on your target when the first target is missing
--   self       last resort: cast on yourself (help spells)
--   stopcast   /stopcasting first (interrupts and instant CC while casting)
--   startattack  /startattack first (melee: keep auto attack going)
--   cancel     aura names to /cancelaura first (e.g. Bladestorm)
--   toggle     second press removes the aura (Ice Block, Divine Shield)
--   stance     { index, "Stance Name" }, or one per game: swap stance first if needed
--   force      "!" prefix: never toggle off a form (powershifting)
--   pet        pet ability: not in your spellbook
--   verb       "cast" (default) or "use": spell is then an item name or slot
--   uses       items or slots to /use first, e.g. { "13", "Healthstone" }
--   lines      full body instead of the generated one
-- WoW limits: name 16 characters, body 255.
---------------------------------------------------------------------------
Macros.NAME_MAX, Macros.BODY_MAX = 16, 255
Macros.TARGETS = { "target", "focus", "mouseover", "cursor", "player", "arena1", "arena2", "arena3",
  "party1", "party2" }
Macros.TARGET_LABEL = { target = "Target", focus = "Focus", mouseover = "Mouseover", cursor = "Cursor",
  player = "Self", arena1 = "Arena 1", arena2 = "Arena 2", arena3 = "Arena 3", party1 = "Party 1", party2 = "Party 2" }
Macros.KINDS = { "harm", "help", "any" }

-- { index, name } stance for this game, if any.
function Macros.StanceFor(stance, game)
  if type(stance) ~= "table" then return nil end
  if stance[1] then return stance end
  return stance[game or ns.GAME]
end

-- The spell name for this game, or nil when the game lacks it.
function Macros.SpellFor(spell, game)
  if type(spell) == "table" then return spell[game or ns.GAME] end
  return spell
end

local function Unit(target, kind)
  if target == "cursor" or target == "player" then return "@" .. target end
  local cond = (kind == "harm" and ",harm,nodead") or (kind == "help" and ",help,nodead") or ""
  if target == "mouseover" then return "@mouseover" .. (cond ~= "" and cond or ",exists,nodead") end
  if target == "target" then return cond ~= "" and cond:sub(2) or nil end -- "[harm,nodead]"
  return "@" .. target .. cond
end

-- Whether fallback / self can change anything for these options.
function Macros.CanFallback(o)
  local t = o.target
  return t ~= nil and t ~= "target" and t ~= "cursor" and t ~= "player"
end
function Macros.CanSelf(o)
  local t = o.target
  return t ~= "player" and t ~= "cursor" and (t ~= nil or o.kind ~= nil)
end

-- The conditional chain for the cast: "[@focus,harm,nodead][]".
function Macros.Conditions(o)
  local target = o.target or "target"
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
    if type(body) == "table" then body = body[game or ns.GAME] end
    if not body then return nil, "not in this game" end
    return body
  end
  local spell = Macros.SpellFor(o.spell, game)
  if not spell or spell == "" then return nil, "not in this game" end
  local lines = { "#showtooltip" }
  local cancel = o.cancel
  if type(cancel) == "table" and cancel[1] == nil then cancel = cancel[game or ns.GAME] end
  for _, aura in ipairs(type(cancel) == "table" and cancel or { cancel }) do
    if aura and aura ~= "" then lines[#lines + 1] = "/cancelaura " .. aura end
  end
  if o.toggle then lines[#lines + 1] = "/cancelaura " .. spell end
  if o.stopcast then lines[#lines + 1] = "/stopcasting" end
  if o.startattack then lines[#lines + 1] = "/startattack" end
  for _, item in ipairs(o.uses or {}) do
    if item and item ~= "" then lines[#lines + 1] = "/use " .. item end
  end
  local cast = Macros.Conditions(o)
  local name = (o.force and "!" or "") .. spell
  local verb = o.verb == "use" and "/use " or "/cast "
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
  if spell then list[#list + 1] = spell end
  for _, extra in ipairs(o.needs or {}) do
    local name = Macros.SpellFor(extra, game)
    if name then list[#list + 1] = name end
  end
  local stance = Macros.StanceFor(o.stance, game)
  if stance then list[#list + 1] = stance[2] end
  return list
end

-- A short name for a target variant: "Kick" -> "Kick Arena 2" within 16 characters.
function Macros.VariantName(name, target)
  local suffix = ({ focus = " F", arena1 = " A1", arena2 = " A2", arena3 = " A3", mouseover = " MO",
    party1 = " P1", party2 = " P2", player = " Me" })[target] or ""
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
