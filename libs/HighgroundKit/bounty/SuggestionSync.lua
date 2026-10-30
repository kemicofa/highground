local _, ns = ...
local B, P, U, C = ns.Bounty, ns.Bounty.Public, ns.Util, ns.Comms
local S = B.Suggestions
S.PREFIX = "HighgroundD"
local queue = {}

-- 1:D,id,serverTime,Name-Realm,source,zone
-- The victim is the transport sender. Reports are never relayed and never
-- assert that another character died. Older bounty clients ignore this prefix.
function S.ClearQueue() wipe(queue) end

function S.ShareDeath(e)
  if not S.Sharing() or not e.guild then return end
  local text = table.concat({ "1:D", e.id, e.at, e.name, e.source, e.zone }, ",")
  if #text <= 255 and #queue < 10 then queue[#queue + 1] = { text = text, guild = e.guild, at = e.at } end
end

function S.Receive(text, channel, sender)
  if not S.Enabled() or not P.ready or channel ~= "GUILD" or not B.InGuild() or #text > 255 then return end
  local from = P.Name(sender)
  if not from or from == B.Me() then return end
  S.ReadRoster()
  if B.ranks[from] == nil then return end
  local id, stamp, name, source, zone = text:match("^1:D,([^,]+),(%d+),([^,]+),([^,]+),([^,]*)$")
  if not id or not name:match("^[^-]+-.+$") or P.Name(name) ~= name
    or B.Key(name) == B.Key(from) or zone:find("[%c|]") then return end
  S.Record({ id = id, at = tonumber(stamp), name = name, victim = from, source = source,
    zone = zone, guild = B.GuildKey(), own = false })
end
C.Listen(S.PREFIX, S.Receive, "guild death reports")

U.Every(1, function()
  if not S.Sharing() or not B.InGuild() then S.ClearQueue(); return end
  local item = table.remove(queue, 1)
  if item and item.guild == B.GuildKey() and P.Now() - item.at < 10 then C.Send(S.PREFIX, item.text, "GUILD") end
end, "guild death reports")
