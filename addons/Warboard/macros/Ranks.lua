local _, ns = ...
local Macros = ns.Macros
local Host = Macros.Host
local Call, Plain = Host.call, Host.value
local Ranks = {}
Macros.Ranks = Ranks

---------------------------------------------------------------------------
-- Spell ranks, in games that have them (Host.Can("spellRanks"): WoW
-- Forever). A spell name without a rank casts your highest rank, but
-- action buttons and "Name(Rank N)" macro text keep the rank they were made
-- with. When you learn a new rank, buttons and macros on the rank it
-- replaces move up to it; lower ranks kept on purpose (downranking) stay.
-- /wb macros ranks moves every lower rank up.
-- Switches: highestRank (buttons), highestRankMacros (macro text).
---------------------------------------------------------------------------
Ranks.SLOTS = 180 -- action slots checked
Ranks.top = {} -- [spell name] = { id, rank }: highest rank seen
Ranks.pending = nil -- moves waiting for combat or the cursor: a moved table or "all"

function Ranks.Supported() return Host.Can("spellRanks") end

-- Rank number from a spell's subtext ("Rank 3", "Rang 3", ...), or nil.
local function Number(subtext)
  return tonumber((Plain(subtext) or ""):match("^%D*(%d+)%D*$"))
end

-- name, rank of a spell ID; rank nil for spells without ranks.
function Ranks.Of(id)
  local name
  if C_Spell and C_Spell.GetSpellName then name = Plain(Call(C_Spell.GetSpellName, id))
  else name = Plain((Call(GetSpellInfo, id))) end
  local subtext = (C_Spell and C_Spell.GetSpellSubtext) or GetSpellSubtext
  return name, Number(Call(subtext, id))
end

-- id, rank of the highest rank you know of a spell, by name (the game
-- resolves a bare name to it), or nil.
function Ranks.Highest(name)
  local id
  if C_Spell and C_Spell.GetSpellInfo then
    local info = Call(C_Spell.GetSpellInfo, name)
    id = type(info) == "table" and Plain(info.spellID)
  else
    id = Plain(select(7, Call(GetSpellInfo, name)))
  end
  if not id then return nil end
  local _, rank = Ranks.Of(id)
  return id, rank
end

-- "Frostbolt(Rank 3)": the game's own word for rank when it has one.
function Ranks.Pin(spell, rank)
  return string.format("%s(%s %d)", spell, RANK or "Rank", rank)
end

-- body with each "Name(Rank N)" replaced where to(name, n) returns a new
-- rank. Returns the new body and how many changed.
function Ranks.Rewrite(body, to)
  local count = 0
  local out = body:gsub("([^%]\n;,]+)%(([^%d%(%)]+)(%d+)%)", function(before, word, n)
    local name = before:gsub("^%s*[/#]%S+%s*", ""):gsub("^reset=%S+%s*", ""):gsub("^!", "")
    name = name:match("^%s*(.-)%s*$")
    local new = name ~= "" and to(name, tonumber(n))
    if not new or new == tonumber(n) then return nil end
    count = count + 1
    return before .. "(" .. word .. new .. ")"
  end)
  return out, count
end

-- Spell IDs on your action buttons: { [slot] = id }.
function Ranks.Buttons()
  local out = {}
  if not GetActionInfo then return out end
  for slot = 1, Ranks.SLOTS do
    local kind, id = Call(GetActionInfo, slot)
    if Plain(kind) == "spell" and Plain(id) then out[slot] = Plain(id) end
  end
  return out
end

-- Spell names with a rank on your buttons and in your macros.
local function Tracked()
  local names = {}
  for _, id in pairs(Ranks.Buttons()) do
    local name, rank = Ranks.Of(id)
    if name and rank then names[name] = true end
  end
  for _, m in ipairs(Macros.Existing()) do
    Ranks.Rewrite(m.body, function(name) names[name] = true end)
  end
  return names
end

-- Remember the highest rank of each tracked spell; returns the spells whose
-- highest rank went up: { [name] = { from, fromID, to, toID } }.
function Ranks.Update()
  local moved = {}
  for name in pairs(Tracked()) do
    local id, rank = Ranks.Highest(name)
    local seen = Ranks.top[name]
    if rank then
      if seen and rank > seen.rank then
        moved[name] = { from = seen.rank, fromID = seen.id, to = rank, toID = id }
      end
      Ranks.top[name] = { id = id, rank = rank }
    end
  end
  return moved
end

local function Place(slot, id)
  local pickup = (C_Spell and C_Spell.PickupSpell) or PickupSpell
  Call(pickup, id)
  Call(PlaceAction, slot)
  Call(ClearCursor)
end

-- Keep moves for later: after combat, or once the cursor is free.
local function Later(moved)
  local p = Ranks.pending
  if not moved or p == "all" then
    Ranks.pending = "all"
  else
    p = p or {}
    for name, m in pairs(moved) do
      local old = p[name]
      p[name] = old and { from = old.from, fromID = old.fromID, to = m.to, toID = m.toID } or m
    end
    Ranks.pending = p
  end
  if not InCombatLockdown() and C_Timer then C_Timer.After(1, function() Ranks.Flush() end) end
end

-- Move buttons and macros up. moved = Ranks.Update() result, or nil for
-- every lower rank. Returns buttons, macros changed; nil (kept for later)
-- in combat or while you hold something on the cursor.
function Ranks.Apply(moved)
  if InCombatLockdown() or (GetCursorInfo and GetCursorInfo()) then
    Later(moved)
    return nil
  end
  local buttons, macros = 0, 0
  if not moved or Host.On("highestRank") then
    for slot, id in pairs(Ranks.Buttons()) do
      local name, rank = Ranks.Of(id)
      local to
      if moved then
        local m = name and moved[name]
        to = m and m.fromID == id and m.toID
      elseif name and rank then
        local top, topRank = Ranks.Highest(name)
        to = topRank and topRank > rank and top
      end
      if to then Place(slot, to); buttons = buttons + 1 end
    end
  end
  if not moved or (Host.On("highestRank") and Host.On("highestRankMacros")) then
    for _, m in ipairs(Macros.Existing()) do
      local body, n = Ranks.Rewrite(m.body, function(name, rank)
        if moved then
          local up = moved[name]
          return up and up.from == rank and up.to
        end
        local _, top = Ranks.Highest(name)
        return top and top > rank and top
      end)
      if n > 0 and Macros.Rewrite(m, body) then macros = macros + 1 end
    end
  end
  return buttons, macros
end

local function Report(buttons, macros)
  if buttons + macros == 0 then return end
  Host.Say(string.format("moved %d button%s and %d macro%s up to your new spell rank", buttons,
    buttons == 1 and "" or "s", macros, macros == 1 and "" or "s"))
end

-- /wb macros ranks: every button and macro on a lower rank moves up.
function Ranks.Command()
  if not Ranks.Supported() then return Host.Say("this game has no spell ranks") end
  local buttons, macros = Ranks.Apply(nil)
  if not buttons then return Host.Say("after combat: moving your buttons and macros up to your highest ranks") end
  Host.Say(buttons + macros == 0 and "every button and macro already casts your highest rank"
    or string.format("moved %d button%s and %d macro%s up to your highest ranks", buttons,
      buttons == 1 and "" or "s", macros, macros == 1 and "" or "s"))
end

-- Presets for every ranked spell in your spellbook (the RANKS mode of the
-- macros window): a bare name always casts the highest rank. Targeting
-- comes from the game: a spell without a range (yourself only, or around
-- you, like Desperate Prayer) is a plain /cast; a helpful spell with a range
-- chains mouseover, target, yourself; the rest cast on your target, with
-- focus and mouseover variants. Kept until SPELLS_CHANGED; entries are
-- reused by name so a card's chosen variant survives.
local presets, byName = nil, {}
local function Helpful(name)
  local fn = (C_Spell and C_Spell.IsSpellHelpful) or IsHelpfulSpell
  return Plain(Call(fn, name)) and true or false
end

-- Whether a spell is cast on a unit at a distance (melee range counts).
function Ranks.HasRange(name)
  local fn = (C_Spell and C_Spell.SpellHasRange) or SpellHasRange
  if fn then return Plain(Call(fn, name)) and true or false end
  local info = C_Spell and C_Spell.GetSpellInfo and Call(C_Spell.GetSpellInfo, name)
  local max = type(info) == "table" and Plain(info.maxRange) or Plain(select(6, Call(GetSpellInfo, name)))
  return (tonumber(max) or 0) > 0
end

function Ranks.Presets()
  if presets then return presets end
  presets = {}
  if not Ranks.Supported() then return presets end
  local class = Host.Class()
  for _, name in ipairs(Macros.Suggest.Spells()) do
    local rank
    if Macros.Suggest.inBook[name] then rank = select(2, Ranks.Highest(name)) end
    if rank then
      local e = byName[name]
      if not e then
        e = { name = name:sub(1, Macros.NAME_MAX), spell = name, class = class, mode = "ranks", ranked = true }
        if not Ranks.HasRange(name) then
          e.self = nil -- a plain /cast
        elseif Helpful(name) then
          e.target, e.kind, e.fallback, e.self, e.party = "mouseover", "help", true, true, true
        else
          e.target, e.enemy, e.fallback = "target", true, true
        end
        byName[name] = e
      end
      e.desc = "Always your highest rank (now rank " .. rank .. ")"
      presets[#presets + 1] = e
    end
  end
  table.sort(presets, function(a, b) return a.spell < b.spell end)
  return presets
end

-- Apply moves kept for later.
function Ranks.Flush()
  local pending = Ranks.pending
  if not pending then return end
  Ranks.pending = nil
  local buttons, macros = Ranks.Apply(pending ~= "all" and pending or nil)
  if buttons then Report(buttons, macros) end
end

local function SpellsChanged()
  if not (Ranks.Supported() and Host.On("highestRank")) then return end
  local moved = Ranks.Update()
  if next(moved) then
    local buttons, macros = Ranks.Apply(moved)
    if buttons then Report(buttons, macros) end
  end
end

Host.Events({ SPELLS_CHANGED = function() presets = nil; SpellsChanged() end,
  PLAYER_REGEN_ENABLED = function() Ranks.Flush() end },
  "macro ranks")
