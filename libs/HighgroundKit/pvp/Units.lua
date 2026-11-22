local _, ns = ...

---------------------------------------------------------------------------
-- Unit tokens built once. Battleground and arena scans run several times a
-- second; indexing these avoids building "nameplate" .. i on every pass.
---------------------------------------------------------------------------
-- The lists are Util.UnitTokens' own tables, shared with every other scan.
local U = ns.Util
local T = { nameplate = U.UnitTokens("nameplate", 40), arena = U.UnitTokens("arena", 5),
  raid = U.UnitTokens("raid", 40), party = U.UnitTokens("party", 4), target = {} }
ns.UnitTokens = T
-- T.target[unit] is that unit's target token: "raid3" -> "raid3target".
for _, list in ipairs({ T.nameplate, T.arena, T.raid, T.party }) do
  for _, unit in ipairs(list) do T.target[unit] = unit .. "target" end
end
for _, unit in ipairs({ "player", "target", "focus", "mouseover", "softenemy" }) do T.target[unit] = unit .. "target" end

-- Your group's tokens and how many to read: raid1..N in a raid, otherwise
-- party1..N-1 (you are not a party token).
function T.Group()
  local n = GetNumGroupMembers and GetNumGroupMembers() or 0
  if IsInRaid and IsInRaid() then return T.raid, math.min(n, #T.raid) end
  return T.party, math.min(math.max(n - 1, 0), #T.party)
end
