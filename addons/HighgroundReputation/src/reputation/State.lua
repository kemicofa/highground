local _, ns = ...
local W = { VERSION = 1, PREFIX = "HighgroundRep", MAX_OPS = 4000, MAX_REPORTS = 2000, MAX_MEMBERS = 1000,
  communities = {}, peers = {}, listeners = {}, ready = false }
ns.Reputation = W
W.caseCache = setmetatable({}, { __mode = "k" })
local U = ns.Util
W.CATEGORIES = { { "toxic", "Toxicity / harassment" }, { "cheating", "Cheating / hacking" },
  { "scamming", "Scamming" }, { "boosting", "Boosting" }, { "griefing", "Griefing" }, { "other", "Other" } }
W.categoryNames = {}
for _, category in ipairs(W.CATEGORIES) do W.categoryNames[category[1]] = category[2] end

function W.Count(t) local n = 0; for _ in pairs(t or {}) do n = n + 1 end; return n end
function W.Copy(v)
  if type(v) ~= "table" then return v end
  local out = {}; for key, value in pairs(v) do out[key] = W.Copy(value) end; return out
end
function W.Int(n, lo, hi)
  return type(n) == "number" and not U.secret(n) and n == n and n == math.floor(n) and n >= lo and n <= hi
end
function W.String(s, max, empty)
  return type(s) == "string" and not U.secret(s) and #s <= max and (empty or #s > 0) and not s:find("[%c|]")
end
function W.Text(s, max)
  if type(s) ~= "string" or U.secret(s) then return "" end
  s = s:gsub("[%c|]", " "):match("^%s*(.-)%s*$")
  if #s <= max then return s end
  local last = max
  while last > 0 and s:byte(last + 1) and s:byte(last + 1) >= 128 and s:byte(last + 1) < 192 do last = last - 1 end
  return s:sub(1, last)
end
function W.ID(s) return W.String(s, 80) and not s:find("[^%w%.%-]") end
function W.OrganizationID(s) return W.String(s, 512) and (s:match("^club:%d+$") or s:match("^guild:.+@.+$")) ~= nil end
function W.Now() return U.read(GetServerTime) or time() end
W.Scope = ns.Scope.Social
function W.NewID() W.db.sequence = W.db.sequence + 1; return W.db.id .. "." .. W.db.sequence end
function W.Say(text) return U.Say("Reputation: " .. tostring(text)) end
function W.Listen(fn) W.listeners[#W.listeners + 1] = fn end
function W.Changed(c)
  W.index = nil
  if c then W.caseCache[c] = nil end
  for _, fn in ipairs(W.listeners) do U.Guard("reputation changed", fn, c) end
end

function W.Joined(c)
  return c ~= nil and c.enabled == true and c.scope == W.Scope() and ns.Organizations.IsMember(c.id)
end
function W.Get(id) return W.ready and W.communities[id or W.db.selected] end
function W.Name(c) local org = c and ns.Organizations.Get(c.id); return org and org.name or "Unavailable organization" end
function W.Role(c, who) return W.Joined(c) and ns.Organizations.Role(c.id, who) or nil end
function W.CanModerate(c, who)
  return W.Joined(c) and (who and who ~= W.Me() or c.activated == true)
    and ns.Organizations.CanModerate(c.id, who) or false
end
function W.MemberCount(c) return c and #ns.Organizations.Members(c.id) or 0 end
function W.List()
  local list = {}
  for _, c in pairs(W.communities) do if W.Joined(c) then list[#list + 1] = c end end
  table.sort(list, function(a, b) return W.Name(a) == W.Name(b) and a.id < b.id or W.Name(a) < W.Name(b) end)
  return list
end
function W.Status(c)
  if W.loadError then return W.loadError end
  if c and c.enabled == false then return W.Availability(c.id).message end
  if not W.Joined(c) then return "Choose a guild or community, then enable participation in Overview to report a player." end
  if W.inbound[c.id] then return "Receiving moderation decisions..." end
  local state = W.Availability(c.id)
  if not W.CanSend() then return "Sharing paused by the game. Proposals stay queued and retry automatically." end
  if state.ready and W.transportError then return W.transportError end
  return state.message
end

function W.LoadScope()
  local scope = W.Scope()
  W.db.scopes[scope] = type(W.db.scopes[scope]) == "table" and W.db.scopes[scope] or {}
  W.communities, W.currentScope = W.db.scopes[scope], scope
  for id, c in pairs(W.communities) do
    if not W.OrganizationID(id) or type(c) ~= "table" or c.id ~= id or c.scope ~= scope then
      W.communities[id] = nil
    else
      c.operations = type(c.operations) == "table" and c.operations or {}
      c.reports = type(c.reports) == "table" and c.reports or {}
      c.sequences = type(c.sequences) == "table" and c.sequences or {}
      c.clock = W.Int(c.clock, 0, 1000000000) and c.clock or 0
      -- A completed legacy snapshot (or local moderator activation) already
      -- established enablement. A member's old opt-in alone did not.
      c.activated = c.activated == true or c.synced == true
      for key, op in pairs(c.operations) do if not W.ValidOperation(c, op) then c.operations[key] = nil end end
      for key, report in pairs(c.reports) do if not W.ValidReport(report) then c.reports[key] = nil end end
    end
  end
end

function W.Init()
  if ns.Modules and not ns.Modules.Active("reputation") then return false end
  if W.ready or ns.STANDBY then return W.ready end
  local db = _G.HighgroundReputationNetworkDB
  if type(db) == "table" and db.version ~= nil and db.version ~= W.VERSION then
    W.loadError = "Reputation data needs a newer addon version. Update before using it."; return false
  end
  db = type(db) == "table" and db or {}
  db.version = W.VERSION
  if not W.ID(db.id) then
    local hash, seed = 5381, U.read(UnitGUID, "player") or W.Me() or "reputation"
    for i = 1, #seed do hash = (hash * 33 + seed:byte(i)) % 2147483647 end
    db.id = string.format("%08x%08x%08x", W.Now(), hash, math.random(0, 2147483646))
  end
  db.sequence = W.Int(db.sequence, 0, 1000000000) and db.sequence or 0
  for _, field in ipairs({ "scopes", "settings", "replies", "pending" }) do
    db[field] = type(db[field]) == "table" and db[field] or {}
  end
  W.db, _G.HighgroundReputationNetworkDB, W.ready = db, db, true
  W.LoadScope()
  for id, pending in pairs(db.pending) do
    if not W.ID(id) or type(pending) ~= "table" or not W.OrganizationID(pending.community)
      or type(pending.report) ~= "table" or type(pending.report.target) ~= "table"
      or pending.report.target.scope == W.Scope() and not W.ValidReport(pending.report) then db.pending[id] = nil end
  end
  W.Changed()
  return true
end
