local _, ns = ...

---------------------------------------------------------------------------
-- Unit tokens built once. Battleground and arena scans run several times a
-- second; indexing these avoids building "nameplate" .. i on every pass.
---------------------------------------------------------------------------
local T = { nameplate = {}, arena = {}, raid = {}, party = {}, target = {} }
ns.UnitTokens = T
for i = 1, 40 do T.nameplate[i], T.raid[i] = "nameplate" .. i, "raid" .. i end
for i = 1, 5 do T.arena[i] = "arena" .. i end
for i = 1, 4 do T.party[i] = "party" .. i end
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
