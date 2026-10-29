local _, ns = ...
local Core, Bounty, Util = ns.Core, ns.Bounty, ns.Util
local Share = {}
Bounty.Share = Share

---------------------------------------------------------------------------
-- Chat carries a self-contained, versioned text token. Addon hyperlinks
-- are local-only, so receiving clients turn the token into a clickable
-- link. No guild membership, addon-message exchange or sender cache is
-- needed; the sender may be offline when the recipient clicks it.
-- Wire: [HGB:1:name-realm:gold:poster-realm:note], with %XX escapes.
-- Guild state and approval are never imported from chat.
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
  local name, gold, by, note = payload:match("^1:([^:]+):(%d+):([^:]+):([^:]*)$")
  if not name then return nil, INVALID end
  name, by, note, gold = Unescape(name), Unescape(by), Unescape(note), tonumber(gold)
  if not ValidName(name) or not ValidName(by) or not gold or gold > Bounty.MAX_GOLD
    or not note or #note > Bounty.NOTE_MAX or note:find("%c") or note ~= Bounty.Clean(note) then
    return nil, INVALID
  end
  return { name = name, gold = gold, by = by, note = note ~= "" and note or nil }
end

function Share.Encode(b)
  if b and b.state == "public" then return nil, "Shared rewards have separate contributors. Use the Shared tab and Contributions to review them." end
  if type(b) ~= "table" or not ValidName(b.name) or not ValidName(b.by)
    or type(b.gold) ~= "number" or b.gold ~= math.floor(b.gold) or b.gold < 0 or b.gold > Bounty.MAX_GOLD
    or (b.note ~= nil and type(b.note) ~= "string") then return nil, INVALID end
  local payload = table.concat({ "1", Escape(b.name), tostring(b.gold), Escape(b.by), Escape(b.note or "") }, ":")
  if #payload + 6 > MAX_CHAT then return nil, "bounty details are too long for one chat message; shorten the note" end
  if not Share.Decode(payload) then return nil, INVALID end
  return payload
end

-- Prepare a draft in the player's chosen chat. Never send it for them or
-- overwrite an existing draft. Reject overflow instead of truncating data.
function Share.Draft(payload)
  local token = "[HGB:" .. payload .. "]"
  local getActive = ChatFrameUtil and ChatFrameUtil.GetActiveWindow or ChatEdit_GetActiveWindow
  local edit = getActive and getActive()
  if edit then
    local text = edit:GetText()
    local insert = (text ~= "" and " " or "") .. token
    if #text + #insert > MAX_CHAT then
      return nil, "not enough room in the chat draft; send or clear it before sharing this bounty"
    end
    edit:Insert(insert)
  else
    local open = ChatFrameUtil and ChatFrameUtil.OpenChat or ChatFrame_OpenChat
    if not open then return nil, "chat is not available" end
    open(token)
  end
  return true
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

function Share.Filter(_, _, message, ...)
  if type(message) ~= "string" or Core.issecret(message) then return end
  local text = message:gsub("%[HGB:([^%[%]]+)%]", function(payload)
    local b = Share.Decode(payload)
    if not b then return nil end -- leave malformed or future versions as plain text
    local label = "[Bounty: " .. Core.DisplayName(b.name) .. " - " .. Bounty.GoldText(b) .. "]"
    return ns.Theme.TipHex("gold") .. "|H" .. LINK .. payload .. "|h" .. label .. "|h|r"
  end)
  return false, text, ...
end

function Share.OnLink(link)
  if type(link) ~= "string" or Core.issecret(link) or link:sub(1, #LINK) ~= LINK then return end
  if not Core.db then return end
  local payload = link:sub(#LINK + 1)
  local b, err = Share.Decode(payload)
  if not b then return Bounty.Say(err) end
  Share.ShowImport(payload)
end

local EVENTS = { "SAY", "YELL", "WHISPER", "WHISPER_INFORM", "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER",
  "RAID_WARNING", "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER", "GUILD", "OFFICER", "CHANNEL",
  "BN_WHISPER", "BN_WHISPER_INFORM", "COMMUNITIES_CHANNEL" }

local installed = false
function Share.Install()
  if installed or ns.STANDBY then return end
  local filter = ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter
  if not (filter and hooksecurefunc and SetItemRef) then return end
  installed = true
  for _, event in ipairs(EVENTS) do filter("CHAT_MSG_" .. event, Share.Filter) end
  -- Blizzard consumes the "addon" link type without opening ItemRefTooltip
  -- on Retail and Cata. Other addons' links keep their normal handling.
  hooksecurefunc("SetItemRef", function(link) Util.Guard("bounty share", Share.OnLink, link) end)
end
