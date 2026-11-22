local _, ns = ...
local U, Core = ns.Util, ns.Core
local G = { ranks = {}, online = {} }
ns.Guild = G

function G.Info()
  local name, _, rank = U.call(GetGuildInfo, "player")
  name, rank = U.value(name), U.value(rank)
  if type(name) == "string" and name ~= "" then return name, rank end
end

function G.InGuild() return G.Info() ~= nil end

-- Preserve the existing bounty storage/wire key, including Forever scope.
function G.Key()
  local name = G.Info()
  return name and (name .. "@" .. (ns.Caps.rulesetRealms and ns.Scope.Key() or Core.myRealm or ""))
end

function G.Clear()
  wipe(G.ranks); wipe(G.online)
  G.rosterKey, G.rosterRead = G.Key(), nil
end

function G.ReadRoster()
  G.Clear()
  G.rosterRead = GetTime()
  if not G.InGuild() then return end
  for i = 1, U.read(GetNumGuildMembers) or 0 do
    local name, _, rank, _, _, _, _, _, online = U.call(GetGuildRosterInfo, i)
    name, rank = Core.Canon(U.value(name)), U.value(rank)
    if name and type(rank) == "number" then
      G.ranks[name], G.online[name] = rank, U.value(online) == true
    end
  end
end

function G.EnsureRoster()
  if G.rosterKey ~= G.Key() then G.Clear() end
  if GetTime() - (G.rosterRead or -math.huge) >= 5 then G.ReadRoster() end
end

function G.RequestRoster()
  U.call(C_GuildInfo and C_GuildInfo.GuildRoster or GuildRoster)
end

function G.Rank(who)
  if not G.InGuild() then return end
  who = Core.Canon(who or Core.CanonUnit("player"))
  if not who then return end
  if who == Core.CanonUnit("player") then return select(2, G.Info()) end
  G.EnsureRoster()
  return G.ranks[who]
end

local function Flags(rank)
  local flags = U.read(C_GuildInfo and C_GuildInfo.GuildControlGetRankFlags, rank + 1)
  return type(flags) == "table" and flags or nil
end

-- The native officer permission of a rank: true, false, or nil while rank
-- flags are unloaded. self: the player's own rank, which may use the
-- client's officer status.
function G.RankPermission(rank, self)
  if type(rank) ~= "number" then return nil end
  if rank == 0 then return true end
  local master = Flags(0)
  local flags
  if master and U.value(master[1]) == true then flags = Flags(rank) end
  local officer = flags and U.value(flags[22])
  if type(officer) == "boolean" then return officer end
  if self then
    officer = U.read(C_GuildInfo and C_GuildInfo.IsGuildOfficer)
    if type(officer) == "boolean" then return officer end
  end
end

-- Native rank permissions win. A feature may explicitly supply its legacy
-- fallback rank; missing data otherwise grants no officer privileges.
function G.RankIsOfficer(rank, self, fallbackRank)
  local officer = G.RankPermission(rank, self)
  if officer ~= nil then return officer end
  return type(rank) == "number" and type(fallbackRank) == "number" and rank <= fallbackRank
end

function G.IsOfficer(who, fallbackRank)
  local self = not who or Core.Canon(who) == Core.CanonUnit("player")
  return G.RankIsOfficer(G.Rank(who), self, fallbackRank)
end
