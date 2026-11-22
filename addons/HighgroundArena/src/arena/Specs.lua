local _, ns = ...
local A, U, Core = ns.Arena, ns.Util, ns.Core
local call, plain = U.call, U.value

function A.SpecIcon(info)
  if not info then return end
  if info.specIcon then return info.specIcon end
  local byName = info.class and Core.specByName[info.class]
  local spec = byName and Core.specInfo[byName[info.spec]]
  if spec then return spec.icon end
  for _, entry in pairs(A.specCatalog) do
    if entry.class == info.class and entry.name == info.spec then return entry.icon end
  end
end

-- Keep identification details in the tooltip, not a redundant text row.
function A.SpecLabel(info)
  if not info then return end
  if info.specSource == "observed" then
    return ns.Locale:Format("arena.specs.likely_info_spec_info_specreason.4dbb23", { info_spec = info.spec, info_specReason = info.specReason })
  end
  if info.specConflict then return ns.Locale:Get("arena.specs.spec_unclear_mixed_talent_clues.321fe6") end
  return info.spec
end

local function Choose(info)
  local best, tied
  for _, evidence in pairs(info.specEvidence) do
    if not best or evidence.depth > best.depth then best, tied = evidence, false
    elseif evidence.depth == best.depth then tied = true end
  end
  info.specConflict = tied or nil
  if tied then
    info.specID, info.spec, info.specIcon, info.specSource, info.specReason = nil, nil, nil, nil, nil
  elseif best then
    local spec = A.specCatalog[best.spec]
    info.specID, info.spec, info.specIcon = best.spec, spec.name, spec.icon
    info.specSource, info.specReason = "observed", best.reason
  end
end

-- Returns true when the evidence changed.
local function Observe(info, id, aura)
  if info.specSource == "arena" then return false end
  id = plain(id)
  if type(id) ~= "number" then return false end
  local clue = A.specClues[info.class] and A.specClues[info.class][id]
  if not clue or (aura and not clue.aura) then return false end
  info.specEvidence = info.specEvidence or {}
  local previous = info.specEvidence[clue.spec]
  if previous and previous.depth >= clue.depth then return false end
  local name = plain(U.SpellName(id))
  info.specEvidence[clue.spec] = { spec = clue.spec, depth = clue.depth,
    reason = (type(name) == "string" and name or clue.name) .. (aura and ns.Locale:Get("arena.specs.buff.996575") or ns.Locale:Get("arena.specs.cast.56dee1")) }
  Choose(info)
  return true
end

-- Returns true when a buff added evidence.
function A.ScanSpecAuras(info, unit, force)
  if A.preview or not A.Enabled() or not (A.InArena() or A.duel) then return false end
  if not A.specClues[info.class] or info.specSource == "arena" or not U.read(UnitExists, unit) then return false end
  if not force and info.specScanUnit == unit and (info.specScanAt or 0) > GetTime() then return false end
  info.specScanUnit, info.specScanAt = unit, GetTime() + 1
  local changed = false
  for i = 1, 40 do
    local aura = plain(call(C_UnitAuras and C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL"))
    if type(aura) ~= "table" then break end
    local id, source = plain(aura.spellId), plain(aura.sourceUnit)
    -- Unknown or stolen/external buffs cannot identify their recipient.
    -- Inspect only readable fields, even before a duel when some fields may
    -- already be restricted. Never infer from a secret name or texture.
    if type(id) == "number" and type(source) == "string" and not U.secret(aura.isStealable)
      and not aura.isStealable and U.read(UnitIsUnit, source, unit) == true and Observe(info, id, true) then
      changed = true
    end
  end
  return changed
end

function A.RememberSpec(info, index, unit)
  if A.InArena() then
    local id = U.read(GetArenaOpponentSpec, index)
    if type(id) == "number" and id > 0 then
      local _, name, _, icon, _, class = call(GetSpecializationInfoByID, id)
      name, icon, class = plain(name), plain(icon), plain(class)
      if type(name) == "string" and name ~= "" and (not info.class or not class or info.class == class) then
        info.specID, info.spec, info.specIcon, info.class = id, name, icon, info.class or class
        info.specSource, info.specReason, info.specConflict = "arena", nil, nil
      end
    end
  end
  A.ScanSpecAuras(info, unit)
end

local function Opponent(unit)
  unit = plain(unit)
  if type(unit) ~= "string" or A.preview or not A.Enabled() then return end
  local index
  if A.DuelMode() then
    if A.DuelMatches(unit) then index = 1 end
  elseif A.InArena() then
    for i = 1, A.MAX do
      if U.read(UnitIsUnit, unit, "arena" .. i) then index = i; break end
    end
  end
  if not index then return end
  local info = A.seen[index] or {}
  local _, class = call(UnitClass, unit)
  class = plain(class) or info.class
  if type(class) ~= "string" then return end
  info.class = class
  A.seen[index] = info
  return info, unit
end

-- Removals and refreshes cannot add evidence; a missing or unreadable
-- update description is treated as a full update.
local function MayAddAura(update)
  update = plain(update)
  if type(update) ~= "table" then return true end
  return plain(update.isFullUpdate) ~= false or type(update.addedAuras) ~= "nil"
end

if not next(A.specClues) then return end
-- Opponent unit traffic only during an observed arena or duel. Repaint
-- when evidence changes; the row refresh covers everything else.
ns.PvPEvents.Listen({
  UNIT_AURA = function(_, unit, update)
    if not MayAddAura(update) then return end
    local info, token = Opponent(unit)
    if info and A.ScanSpecAuras(info, token, true) then A.Update() end
  end,
  UNIT_SPELLCAST_SUCCEEDED = function(_, unit, _, spellID)
    local info = Opponent(unit)
    if info and Observe(info, spellID, false) then A.Update() end
  end,
}, "arena specs", function() return A.Enabled() and (A.InArena() or A.duel ~= nil) end, "arena")
