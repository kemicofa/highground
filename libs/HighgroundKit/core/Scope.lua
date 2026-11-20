local _, ns = ...
local U, S = ns.Util, {}
ns.Scope = S

-- Shared game/region and economy boundaries. Features own their saved data.
function S.Region()
  return (ns.GAME or ns.CLIENT) .. ":" .. tostring(U.read(GetCurrentRegion) or 0)
end

function S.Ruleset()
  if not ns.Caps.rulesetRealms then return end
  local rules = Enum and Enum.GameRule
  local query = C_GameRules and C_GameRules.IsGameRuleActive
  if not (rules and query and rules.HardcoreRuleset and rules.RPRuleset and rules.PvPRuleset) then return end
  local hardcore, rp, pvp = U.read(query, rules.HardcoreRuleset), U.read(query, rules.RPRuleset), U.read(query, rules.PvPRuleset)
  if type(hardcore) ~= "boolean" or type(rp) ~= "boolean" or type(pvp) ~= "boolean" then return end
  return hardcore and "Hardcore" or rp and (pvp and "RP-PvP" or "RP") or pvp and "PvP" or "PvE"
end

function S.Key()
  local rule = S.Ruleset()
  return S.Region() .. ":" .. (rule and "ruleset:" or "realm:") .. (rule or ns.Core.myRealm or "")
end

function S.Label()
  return S.Ruleset() or (ns.Caps.hideRealmNames and "Current realmset") or ns.Core.myRealm or "Current realm"
end

-- Native communities span realms. Forever still separates its rulesets.
function S.Social() return ns.Caps.rulesetRealms and S.Key() or S.Region() end
