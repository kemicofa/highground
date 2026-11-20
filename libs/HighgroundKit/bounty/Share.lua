local _, ns = ...
local Core, Bounty, Chat = ns.Core, ns.Bounty, ns.Chat
local Share = {}
Bounty.Share = Share

---------------------------------------------------------------------------
-- Chat carries a self-contained, versioned text token. Addon hyperlinks
-- are local-only, so receiving clients turn the token into a clickable
-- link. No guild membership, addon-message exchange or sender cache is
-- needed; the sender may be offline when the recipient clicks it.
-- Wire: [HGB:<payload>], with %XX escapes in names and notes. Version 1
-- carries target, gold, poster and note; version 2 adds audience and kill
-- terms; version 3 adds encoded origin intel. Encode writes version 2 or 3.
-- Organization membership and approval are never imported from chat.
---------------------------------------------------------------------------
local LINK = "addon:HighgroundB:"
local MAX_CHAT = 255
local INVALID = "invalid or unsupported bounty link"

local function Escape(text)
  return (text:gsub("[%%:%[%]]", function(c) return string.format("%%%02X", c:byte()) end))
end

local function Unescape(text)
  if text:gsub("%%%x%x", ""):find("%", 1, true) then return nil end
  return (text:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end))
end

-- Require the realm in the wire format: a recipient may be on another
-- realm. Keep full names (including Forever's spaces and UTF-8 bytes).
local function ValidName(name)
  if type(name) ~= "string" or name:find("[%c|,;:%[%]%%]") then return false end
  local short, realm = name:match("^([^-]+)%-(.+)$")
  return short and not short:find("%d") and not short:match("^%s") and not short:match("%s$")
    and not realm:find("%s") and Core.Canon(name) == name
end

function Share.Decode(payload)
  if type(payload) ~= "string" or Core.issecret(payload) or #payload + 6 > MAX_CHAT
    or payload:find("[%c|%[%]]") then return nil, INVALID end
  local audience, count, methods, origin
  local body = payload
  if body:sub(1, 2) == "3:" then
    local encoded
    body, encoded = body:match("^3:(.*):([%w+/=]+)$")
    local raw = encoded and ns.Codec.Decode64(encoded)
    local data = raw and ns.Codec.Unpack(raw)
    if type(data) ~= "table" then return nil, INVALID end
    origin = Bounty.Sightings.Validate({ by = data[1], at = data[2], zone = data[3], area = data[4],
      mapID = data[5], world = data[6], guid = data[7] })
    if not origin then return nil, INVALID end
    body = "2:" .. body
  end
  if body:sub(1, 2) == "2:" then
    audience, body, count, methods = body:match("^2:(%a+):(.*):(%d+):([^:]*)$")
    if audience ~= "private" and audience ~= "guild" and audience ~= "community" then return nil, INVALID end
    if not Bounty.Terms.Validate(count, methods) then return nil, INVALID end
    body = "1:" .. body
  end
  local name, gold, by, note = body:match("^1:([^:]+):(%d+):([^:]+):([^:]*)$")
  if not name then return nil, INVALID end
  name, by, note, gold = Unescape(name), Unescape(by), Unescape(note), tonumber(gold)
  if not ValidName(name) or not ValidName(by) or not gold or gold > Bounty.MAX_GOLD
    or not note or #note > Bounty.NOTE_MAX or note:find("%c") or note ~= Bounty.Clean(note) then
    return nil, INVALID
  end
  return { name = name, gold = gold, by = by, note = note ~= "" and note or nil,
    intel = origin and { origin = origin, latest = origin } or nil,
    importAudience = audience or "private", killsRequired = tonumber(count) or 1, killMethods = methods or "" }
end

function Share.Encode(b)
  if b and b.state == "public" then return nil, "Shared rewards have separate contributors. Use Shared board and View bounty to review them, or the bounty export command to copy a link." end
  if type(b) ~= "table" or not ValidName(b.name) or not ValidName(b.by)
    or type(b.gold) ~= "number" or b.gold ~= math.floor(b.gold) or b.gold < 0 or b.gold > Bounty.MAX_GOLD
    or (b.note ~= nil and type(b.note) ~= "string") then return nil, INVALID end
  local payload = table.concat({ "2", (b.state == "pending" or b.state == "approved") and (b.organization and "community" or "guild") or "private",
    Escape(b.name), tostring(b.gold), Escape(b.by), Escape(b.note or ""), Bounty.Terms.Count(b), b.killMethods or "" }, ":")
  local intel = Bounty.Sightings.Pack(b)
  local a = intel and intel.origin
  if a then
    local location = ns.Codec.Encode64(ns.Codec.Pack({ a.by, a.at, a.zone, a.area, a.mapID, a.world, a.guid }))
    payload = "3:" .. payload:sub(3) .. ":" .. location
  end
  if #payload + 6 > MAX_CHAT then return nil, "bounty details are too long for one chat message; use Export bounty to keep the location and note" end
  if not Share.Decode(payload) then return nil, INVALID end
  return payload
end

-- Prepare a draft in the player's chosen chat. Never send it for them or
-- overwrite an existing draft. Reject overflow instead of truncating data.
function Share.Draft(payload)
  local ok, problem = Chat.Draft("[HGB:" .. payload .. "]")
  if ok then return true end
  return nil, problem == "full" and "not enough room in the chat draft; send or clear it before sharing this bounty"
    or "chat is not available"
end

function Share.ToChat(name)
  local b = Bounty.Entry(name)
  if not b then return Bounty.Say("no bounty on " .. tostring(name)) end
  local payload, err = Share.Encode(b)
  if not payload then return Bounty.Say(err) end
  local ok
  ok, err = Share.Draft(payload)
  if not ok then Bounty.Say(err) end
  return ok
end

Share.Filter = Chat.LinkFilter("%[HGB:([^%[%]]+)%]", function(payload)
  local b = Share.Decode(payload)
  if not b then return nil end -- leave malformed or future versions as plain text
  local label = "[Bounty: " .. Core.DisplayName(b.name) .. " - " .. Bounty.GoldText(b) .. "]"
  return ns.Theme.TipHex("gold") .. "|H" .. LINK .. payload .. "|h" .. label .. "|h|r"
end)

function Share.OnLink(link)
  if type(link) ~= "string" or Core.issecret(link) or link:sub(1, #LINK) ~= LINK then return end
  if not Core.db then return end
  local payload = link:sub(#LINK + 1)
  local b, err = Share.Decode(payload)
  if not b then return Bounty.Say(err) end
  Share.ShowImport(payload)
end

function Share.Install()
  Chat.InstallLinks(Share.Filter, Share.OnLink, "bounty share")
end
