local _, ns = ...
local W, O = ns.Reputation, ns.Organizations
W.candidates = {}
local LIMIT, REFRESH, GAP = 32, 300, 5

-- Only identity hints survive a scan. Every returned row is read live, so
-- demotion, departure, ID reuse and Forever ruleset changes still deny access.
function W.Moderators(id)
  local now, cache = GetTime(), W.candidates[id]
  if not cache then
    if W.Count(W.candidates) >= LIMIT then
      local oldest
      for key, entry in pairs(W.candidates) do
        if not oldest or entry.at < W.candidates[oldest].at then oldest = key end
      end
      W.candidates[oldest] = nil
    end
    cache = { names = {}, at = -math.huge, state = "loading" }
    W.candidates[id] = cache
  end
  local org = O.Get(id)
  if not org then W.candidates[id] = nil; return {}, "unavailable" end
  cache.kind = org.kind
  if now - cache.at >= (cache.dirty and GAP or REFRESH) then
    local members, state = O.Moderators(id)
    cache.at, cache.state, cache.dirty = now, state, state ~= "ready"
    if state == "ready" then
      wipe(cache.names)
      for i, member in ipairs(members) do
        if i > W.MAX_MEMBERS then break end
        cache.names[member.name] = org.kind == "guild" and true or member.memberId
      end
    end
  elseif cache.dirty then
    W.nextDiscovery = math.min(W.nextDiscovery or math.huge, cache.at + GAP)
  end
  if org.kind ~= "guild" and C_Club.AreMembersReady and ns.Util.read(C_Club.AreMembersReady, org.clubId) ~= true then
    return {}, "loading"
  end
  local members = {}
  for name, memberId in pairs(cache.names) do
    local member
    if org.kind == "guild" then member = O.Member(id, name) else member = O.MemberByID(id, memberId) end
    if member and member.name == name and O.ModeratorRole(member.role) then members[#members + 1] = member end
  end
  -- Stable rotation between eligible authorities without sorting the full roster.
  table.sort(members, function(a, b) return a.name < b.name end)
  return members, cache.state
end

function W.NoteModerator(id, member)
  local cache = W.candidates[id]
  if not cache or not member then return end
  if O.ModeratorRole(member.role) then
    if cache.names[member.name] or W.Count(cache.names) < W.MAX_MEMBERS then
      cache.names[member.name] = member.memberId or true
    end
  else cache.names[member.name] = nil end
end

function W.InvalidateCandidates(event, clubId)
  if O.IsGuildEvent(event) then
    for _, cache in pairs(W.candidates) do if cache.kind == "guild" then cache.dirty = true end end
  elseif clubId and type(clubId) == "number" then
    if event == "CLUB_REMOVED" then W.candidates["club:" .. clubId] = nil; return end
    local cache = W.candidates["club:" .. clubId]
    if cache then cache.dirty = true end
  else
    for _, cache in pairs(W.candidates) do cache.dirty = true end
  end
end

function W.PruneCandidates()
  for id in pairs(W.candidates) do if not O.Get(id) then W.candidates[id] = nil end end
end
