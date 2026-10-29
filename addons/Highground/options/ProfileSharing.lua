local _, ns = ...
local Core, P, Codec = ns.Core, ns.Options.Profiles, ns.Codec
local Share = { PREFIX = "HighgroundP" }
P.Chat = Share

-- A short chat token identifies an immutable snapshot held by the sender.
-- Clicking requests that snapshot by whisper; only the requested sender/id
-- can complete it. Receipt opens a review, never applies settings.
local LINK, MAX, CHUNK, TTL = "addon:HighgroundP:", 32768, 200, 1800
local cache, serial, incoming, outgoing, nextReply = {}, 0, nil, nil, 0

local function Name(name)
  if type(name) ~= "string" or Core.issecret(name) or #name > 96 or name:find("[%c|:%[%]%%]") then return end
  local short, realm = name:match("^([^-]+)%-(.+)$")
  if short and not short:find("%d") and not short:match("^%s") and not short:match("%s$")
    and not realm:find("%s") and Core.Canon(name) == name then return name end
end

function Share.Decode(payload)
  if type(payload) ~= "string" or Core.issecret(payload) or #payload > 249 then return end
  local source, id, label = payload:match("^1:([%w+/=]+):(%x+%-%x+):([%w+/=]+)$")
  if not source or #id > 32 then return end
  source, label = Codec.Decode64(source), Codec.Decode64(label)
  if not Name(source) or not label or #label > 40 or label:find("[%c|]") or not P.CleanName(label) then return end
  return { source = source, id = id, label = label }
end

local function Prune()
  for id, item in pairs(cache) do if GetTime() - item.at >= TTL then cache[id] = nil end end
end

-- Keep an existing draft and let the player choose the channel and press Enter.
local function Draft(token)
  local active = ChatFrameUtil and ChatFrameUtil.GetActiveWindow or ChatEdit_GetActiveWindow
  local edit = active and active()
  if edit then
    local text = edit:GetText()
    local insert = (text ~= "" and " " or "") .. token
    if #text + #insert > 255 then return false, "Not enough room in chat. Send or clear your draft first." end
    edit:Insert(insert)
  else
    local open = ChatFrameUtil and ChatFrameUtil.OpenChat or ChatFrame_OpenChat
    if not open then return false, "Chat is not available." end
    open(token)
  end
  return true
end

function Share.ToChat(name)
  local snap = name and Core.db.profiles and Core.db.profiles[name]
  if name and not snap then return false, "Choose a saved profile first." end
  if not ns.Comms.CanSend() then return false, "Chat sharing is unavailable. Use Export to copy this profile." end
  local source = Name(Core.CanonUnit("player"))
  if not source then return false, "Your character name is not available yet." end
  snap = snap or P.Snapshot()
  local prepared, err = P.Prepare(snap)
  if not prepared then return false, err end
  local label = P.CleanName(name or "Current setup")
  if not label or label:find("%c") then return false, "Give the profile a name without line breaks before sharing." end
  local encoded, text = pcall(P.ExportString, snap, label)
  if not encoded then return false, "This saved profile could not be shared. Save your current setup as a new profile." end
  if #text > MAX then return false, "This profile is too large for chat sharing. Use Export to copy it." end
  Prune()
  local count, existing = 0, nil
  for id, item in pairs(cache) do
    count = count + 1
    if item.text == text then existing = id end
  end
  if count >= 8 and not existing then return false, "Eight profiles are already shared. Wait for a link to expire, or use Export." end
  serial = serial + 1
  local id = existing or string.format("%x-%x", time(), math.floor(GetTime() * 1000) + serial)
  local payload = table.concat({ "1", Codec.Encode64(source), id, Codec.Encode64(label) }, ":")
  if not Share.Decode(payload) then return false, "These profile details are too long for chat. Use Export instead." end
  local ok, problem = Draft("[HGP:" .. payload .. "]")
  if not ok then return false, problem end
  cache[id] = { text = text, at = GetTime() }
  return true, "Link added to chat. Press Enter to share. Stay online; links expire after 30 minutes or a reload."
end

local function Send(text, target)
  if not ns.Comms.CanSend() then return false end
  local ok, first, second = pcall(C_ChatInfo.SendAddonMessage, Share.PREFIX, text, "WHISPER", target)
  local result = second ~= nil and second or first
  return ok and (result == nil or result == true or result == 0)
end

function Share.Cancel() incoming = nil end

local function Fail(message)
  incoming = nil
  Share.Progress(message, true)
end

function Share.OnLink(link)
  if type(link) ~= "string" or Core.issecret(link) or link:sub(1, #LINK) ~= LINK or not Core.db then return end
  local offer = Share.Decode(link:sub(#LINK + 1))
  if not offer then return end
  incoming = nil
  Share.Review(nil, offer.source, offer.label)
  Prune()
  if offer.source == Core.CanonUnit("player") then
    if cache[offer.id] then return Share.Review(cache[offer.id].text, offer.source, offer.label) end
    return Fail("This link has expired. Share the profile again.")
  end
  offer.parts, offer.received, offer.bytes = {}, 0, 0
  incoming = offer
  if not Send("1:R:" .. offer.id, offer.source) then return Fail("Could not request this profile. Try the link again.") end
  C_Timer.After(90, function()
    if incoming == offer then Fail("Profile unavailable. The sender must be online with Highground. Ask for a fresh link or an export.") end
  end)
end

local function Respond(id, sender)
  Prune()
  if GetTime() < nextReply then return end
  nextReply = GetTime() + 1
  if not cache[id] then Send("1:E:" .. id .. ":expired", sender); return end
  if outgoing then Send("1:E:" .. id .. ":busy", sender); return end
  local item = { text = cache[id].text, part = 1, failures = 0 }
  local count = math.ceil(#item.text / CHUNK)
  outgoing = item
  -- Below the normal addon-message budget; one transfer at a time.
  item.ticker = C_Timer.NewTicker(0.4, function()
    local chunk = item.text:sub((item.part - 1) * CHUNK + 1, item.part * CHUNK)
    if Send(table.concat({ "1:D", id, item.part, count, chunk }, ":"), sender) then
      item.part, item.failures = item.part + 1, 0
    else item.failures = item.failures + 1 end
    if item.part > count or item.failures >= 3 then item.ticker:Cancel(); outgoing = nil end
  end)
end

function Share.Receive(text, channel, sender)
  if channel ~= "WHISPER" or Core.issecret(text) or #text > 255 or not Name(Core.Canon(sender)) then return end
  sender = Core.Canon(sender)
  local request = text:match("^1:R:(%x+%-%x+)$")
  if request and #request <= 32 then return Respond(request, sender) end
  local item = incoming
  if not item or sender ~= item.source then return end
  local id, problem = text:match("^1:E:(%x+%-%x+):(%a+)$")
  if id == item.id then
    if problem == "expired" then Fail("This link has expired. Ask the sender to share it again.")
    elseif problem == "busy" then Fail("The sender is sharing another profile. Try this link again in a moment.") end
    return
  end
  local part, count, chunk
  id, part, count, chunk = text:match("^1:D:(%x+%-%x+):(%d+):(%d+):([%w+/=]+)$")
  if id ~= item.id then return end
  part, count = tonumber(part), tonumber(count)
  if not part or not count or count < 1 or count > math.ceil(MAX / CHUNK) or part < 1 or part > count
    or #chunk > CHUNK or (part < count and #chunk ~= CHUNK) or item.count and item.count ~= count then
    return Fail("The shared profile was incomplete. Ask for a fresh link.")
  end
  if item.parts[part] then
    if item.parts[part] ~= chunk then Fail("The shared profile changed during transfer. Ask for a fresh link.") end
    return
  end
  item.count, item.parts[part] = count, chunk
  item.received, item.bytes = item.received + 1, item.bytes + #chunk
  if item.bytes > MAX then return Fail("The shared profile is too large. Ask for an export instead.") end
  Share.Progress("Receiving profile… " .. math.floor(item.received / count * 100) .. "%")
  if item.received == count then
    incoming = nil
    Share.Review(table.concat(item.parts), item.source, item.label)
  end
end

function Share.Filter(_, _, message, ...)
  if type(message) ~= "string" or Core.issecret(message) then return end
  local text = message:gsub("%[HGP:([^%[%]]+)%]", function(payload)
    local offer = Share.Decode(payload)
    if not offer then return nil end
    return ns.Theme.TipHex("accent") .. "|H" .. LINK .. payload .. "|h[Profile: " .. offer.label .. "]|h|r"
  end)
  return false, text, ...
end

local installed
local function Install()
  if installed then return end
  local filter = ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter
  if not (filter and hooksecurefunc and SetItemRef) then return end
  installed = true
  for _, event in ipairs({ "SAY", "YELL", "WHISPER", "WHISPER_INFORM", "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER",
    "RAID_WARNING", "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER", "GUILD", "OFFICER", "CHANNEL",
    "BN_WHISPER", "BN_WHISPER_INFORM", "COMMUNITIES_CHANNEL" }) do filter("CHAT_MSG_" .. event, Share.Filter) end
  hooksecurefunc("SetItemRef", function(link) ns.Util.Guard("profile link", Share.OnLink, link) end)
end
ns.Comms.Listen(Share.PREFIX, Share.Receive, "profile sharing")
ns.Util.Events({ PLAYER_LOGIN = Install }, "profile links")
