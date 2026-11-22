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

local function Observe(info, id, aura)
  if info.specSource == "arena" then return end
  id = plain(id)
  if type(id) ~= "number" then return end
  local clue = A.specClues[info.class] and A.specClues[info.class][id]
  if not clue or (aura and not clue.aura) then return end
  info.specEvidence = info.specEvidence or {}
  local previous = info.specEvidence[clue.spec]
  if previous and previous.depth >= clue.depth then return end
  local name = plain(U.SpellName(id))
  info.specEvidence[clue.spec] = { spec = clue.spec, depth = clue.depth,
    reason = (type(name) == "string" and name or clue.name) .. (aura and ns.Locale:Get("arena.specs.buff.996575") or ns.Locale:Get("arena.specs.cast.56dee1")) }
  Choose(info)
end

function A.ScanSpecAuras(info, unit, force)
  if A.preview or not A.Enabled() or not (A.InArena() or A.duel) then return end
  if not A.specClues[info.class] or info.specSource == "arena" or not U.read(UnitExists, unit) then return end
  if not force and info.specScanUnit == unit and (info.specScanAt or 0) > GetTime() then return end
  info.specScanUnit, info.specScanAt = unit, GetTime() + 1
  for i = 1, 40 do
    local aura = plain(call(C_UnitAuras and C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL"))
    if type(aura) ~= "table" then break end
    local id, source = plain(aura.spellId), plain(aura.sourceUnit)
    -- Unknown or stolen/external buffs cannot identify their recipient.
    -- Inspect only readable fields, even before a duel when some fields may
    -- already be restricted. Never infer from a secret name or texture.
    if type(id) == "number" and type(source) == "string" and not U.secret(aura.isStealable)
      and not aura.isStealable and U.read(UnitIsUnit, source, unit) == true then Observe(info, id, true) end
  end
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

if not next(A.specClues) then return end
U.Events({
  UNIT_AURA = function(_, unit)
    local info, token = Opponent(unit)
    if not info then return end
    A.ScanSpecAuras(info, token, true)
    A.Update()
  end,
  UNIT_SPELLCAST_SUCCEEDED = function(_, unit, _, spellID)
    local info = Opponent(unit)
    if not info then return end
    Observe(info, spellID, false)
    A.Update()
  end,
}, "arena specs", "arena")
