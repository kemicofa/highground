local _, ns = ...
local Core, P, Codec = ns.Core, ns.Options.Profiles, ns.Codec
local Chat, Comms = ns.Chat, ns.Comms
local Share = { PREFIX = "HighgroundP", receiving = ns.Async.New(), sending = ns.Async.New() }
P.Chat = Share

-- A short chat token identifies an immutable export held by the sender.
-- Clicking requests it by whisper; only the requested sender/id can complete
-- it. Receipt adds it to the profile list under the sender's character name,
-- never applies settings.
local LINK, MAX, CHUNK, TTL = "addon:HighgroundP:", 32768, 200, 1800
local cache, serial, nextReply = {}, 0, 0

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

-- Put a link to this character's settings for addon in the chat box.
function Share.ToChat(addon)
  if not Comms.CanSend() then return false, ns.Locale:Get("highground.profilesharing.chat_sharing_is_unavailable_use_export_to.2cef83") end
  local source = Name(Core.CanonUnit("player"))
  if not source then return false, ns.Locale:Get("highground.profilesharing.your_character_name_is_not_available_yet.7536f7") end
  local text = ns.CharacterSettings.Export(addon or "battlegrounds")
  if not text then return false, ns.Locale:Get("highground.profilesharing.this_saved_profile_could_not_be_shared.7a864f") end
  local label = P.CleanName(ns.Locale:Format("profiles.share.link", { name = ns.CharacterSettings.Name(), addon = P.AddonLabel(addon or "battlegrounds") }))
  if not label or label:find("%c") then return false, ns.Locale:Get("highground.profilesharing.give_the_profile_a_name_without_line.1a98ba") end
  if #text > MAX then return false, ns.Locale:Get("highground.profilesharing.this_profile_is_too_large_for_chat.7bb31c") end
  Prune()
  local count, existing = 0, nil
  for id, item in pairs(cache) do
    count = count + 1
    if item.text == text then existing = id end
  end
  if count >= 8 and not existing then return false, ns.Locale:Get("highground.profilesharing.eight_profiles_are_already_shared_wait_for.27ac59") end
  serial = serial + 1
  local id = existing or string.format("%x-%x", time(), math.floor(GetTime() * 1000) + serial)
  local payload = table.concat({ "1", Codec.Encode64(source), id, Codec.Encode64(label) }, ":")
  if not Share.Decode(payload) then return false, ns.Locale:Get("highground.profilesharing.these_profile_details_are_too_long_for.8c88f6") end
  local ok, problem = Chat.Draft("[HGP:" .. payload .. "]")
  if not ok then
    return false, problem == "full" and ns.Locale:Get("highground.profilesharing.not_enough_room_in_chat_send_or.7f1b2d") or ns.Locale:Get("highground.profilesharing.chat_is_not_available.9a9d1b")
  end
  cache[id] = { text = text, at = GetTime() }
  -- Release the export just after its link expires, not at the next share.
  C_Timer.After(TTL + 1, Prune)
  return true, ns.Locale:Get("highground.profilesharing.link_added_to_chat_press_enter_to.b98ca4")
end

local function Send(text, target)
  Share.protocolProblem = nil
  if ns.Protocols then
    local compatible, problem = ns.Protocols.Allows("profiles", target, 1)
    if not compatible then Share.protocolProblem = problem; return false end
  end
  return Comms.Send(Share.PREFIX, text, "WHISPER", target)
end

function Share.Cancel() Share.receiving:Cancel() end

local function Fail(attempt, message)
  if Share.receiving:Finish(attempt, "failed", message) then Share.Progress(message, true) end
end

function Share.OnLink(link)
  if type(link) ~= "string" or Core.issecret(link) or link:sub(1, #LINK) ~= LINK or not Core.db then return end
  local offer = Share.Decode(link:sub(#LINK + 1))
  if not offer then return end
  Share.Cancel()
  Share.Review(nil, offer.source, offer.label)
  local attempt = Share.receiving:Start(offer)
  Prune()
  if offer.source == Core.CanonUnit("player") then
    if cache[offer.id] then
      Share.receiving:Finish(attempt, "succeeded")
      return Share.Review(cache[offer.id].text, offer.source, offer.label)
    end
    return Fail(attempt, ns.Locale:Get("highground.profilesharing.this_link_has_expired_share_the_profile.0ca2c5"))
  end
  offer.parts, offer.received, offer.bytes = {}, 0, 0
  if not Send("1:R:" .. offer.id, offer.source) then
    return Fail(attempt, Share.protocolProblem or ns.Locale:Get("highground.profilesharing.could_not_request_this_profile_try_the.a30b8c"))
  end
  C_Timer.After(90, function()
    Fail(attempt, ns.Locale:Get("highground.profilesharing.profile_unavailable_the_sender_must_be_online.5f237f"))
  end)
end

local function Respond(id, sender)
  Prune()
  if GetTime() < nextReply then return end
  nextReply = GetTime() + 1
  if not cache[id] then Send("1:E:" .. id .. ":expired", sender); return end
  if Share.sending.state == "pending" then Send("1:E:" .. id .. ":busy", sender); return end
  local item = { text = cache[id].text, part = 1, failures = 0 }
  local count = math.ceil(#item.text / CHUNK)
  local attempt = Share.sending:Start(item)
  -- Below the normal addon-message budget; one transfer at a time.
  item.ticker = C_Timer.NewTicker(0.4, function()
    if not Share.sending:IsCurrent(attempt) then item.ticker:Cancel(); return end
    local chunk = item.text:sub((item.part - 1) * CHUNK + 1, item.part * CHUNK)
    if Send(table.concat({ "1:D", id, item.part, count, chunk }, ":"), sender) then
      item.part, item.failures = item.part + 1, 0
    elseif Share.protocolProblem then item.failures = 3
    else item.failures = item.failures + 1 end
    if item.part > count or item.failures >= 3 then
      Share.sending:Finish(attempt, item.part > count and "succeeded" or "failed")
      item.ticker:Cancel()
    end
  end)
end

function Share.Receive(text, channel, sender)
  if channel ~= "WHISPER" or Core.issecret(text) or #text > 255 or not Name(Core.Canon(sender)) then return end
  sender = Core.Canon(sender)
  local request = text:match("^1:R:(%x+%-%x+)$")
  if request and #request <= 32 then return Respond(request, sender) end
  local attempt = Share.receiving.current
  if not attempt then return end
  local item = attempt.value
  if sender ~= item.source then return end
  local id, problem = text:match("^1:E:(%x+%-%x+):(%a+)$")
  if id == item.id then
    if problem == "expired" then Fail(attempt, ns.Locale:Get("highground.profilesharing.this_link_has_expired_ask_the_sender.b7e179"))
    elseif problem == "busy" then Fail(attempt, ns.Locale:Get("highground.profilesharing.the_sender_is_sharing_another_profile_try.c6db50")) end
    return
  end
  local part, count, chunk
  id, part, count, chunk = text:match("^1:D:(%x+%-%x+):(%d+):(%d+):([%w+/=]+)$")
  if id ~= item.id then return end
  part, count = tonumber(part), tonumber(count)
  if not part or not count or count < 1 or count > math.ceil(MAX / CHUNK) or part < 1 or part > count
    or #chunk > CHUNK or (part < count and #chunk ~= CHUNK) or item.count and item.count ~= count then
    return Fail(attempt, ns.Locale:Get("highground.profilesharing.the_shared_profile_was_incomplete_ask_for.6e6f5b"))
  end
  if item.parts[part] then
    if item.parts[part] ~= chunk then Fail(attempt, ns.Locale:Get("highground.profilesharing.the_shared_profile_changed_during_transfer_ask.e09f5d")) end
    return
  end
  item.count, item.parts[part] = count, chunk
  item.received, item.bytes = item.received + 1, item.bytes + #chunk
  if item.bytes > MAX then return Fail(attempt, ns.Locale:Get("highground.profilesharing.the_shared_profile_is_too_large_ask.c029e8")) end
  Share.Progress(ns.Locale:Format("highground.profilesharing.receiving_profile_value2.bbf037", { value2 = math.floor(item.received / count * 100) }))
  if item.received == count then
    Share.receiving:Finish(attempt, "succeeded")
    Share.Review(table.concat(item.parts), item.source, item.label)
  end
end

Share.Filter = Chat.LinkFilter("%[HGP:([^%[%]]+)%]", function(payload)
  local offer = Share.Decode(payload)
  if not offer then return nil end
  return ns.Theme.TipHex("accent") .. "|H" .. LINK .. payload .. "|h["
    .. ns.Locale:Format("profile.chat.label", { name = offer.label }) .. "]|h|r"
end)

local function Install()
  Chat.InstallLinks(Share.Filter, Share.OnLink, "profile link")
end
Comms.Listen(Share.PREFIX, Share.Receive, "profile sharing")
ns.Util.Events({ PLAYER_LOGIN = Install }, "profile links")

-- A received profile joins the list under the sender's character name;
-- nothing changes until it is copied. Without text the transfer has started.
function Share.Review(text, source, label)
  if not text then return Share.Progress(ns.Locale:Format("profiles.share.receiving", { name = label })) end
  local ok, message, _, addon = ns.CharacterSettings.Import(text, source and source:match("^([^-]+)") or label)
  Share.Progress(message, not ok)
  if ok and ns.Options.ShowProfiles then ns.Options.ShowProfiles(addon) end
end
function Share.Progress(message) ns.Util.Say(message) end
