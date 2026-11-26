local _, ns = ...
local Util = ns.Util
local Chat = {}
ns.Chat = Chat

-- Chat API compatibility and link plumbing. Features own their wire
-- formats, validation, labels and the action taken when a link is clicked.
local MAX_CHAT = 255
local EVENTS = { "SAY", "YELL", "WHISPER", "WHISPER_INFORM", "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER",
  "RAID_WARNING", "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER", "GUILD", "OFFICER", "CHANNEL",
  "BN_WHISPER", "BN_WHISPER_INFORM", "COMMUNITIES_CHANNEL" }

-- A delayed event can carry a channel number that has since been reused.
-- Prefer its name when supplied; only fall back to the current local ID.
function Chat.MatchesChannel(channel, joined, id, name)
  if not channel or not joined then return false end
  name = Util.value(name)
  if type(name) == "string" and name ~= "" then return name:lower() == channel:lower() end
  return tonumber(Util.value(id)) == joined
end

local suffixes = { "", "PvE", "PvP", "RP", "RPPvP", "Hardcore" }
function Chat.LeaveOtherChannels(base, keep)
  if not ns.Caps.rulesetRealms then return end
  -- Called only at startup or a channel/preference change. Also removes
  -- permanent membership restored by the game after an upgrade or reload.
  for _, suffix in ipairs(suffixes) do
    local name = base .. suffix
    if name ~= keep then
      local id = Util.read(GetChannelName, name)
      if type(id) == "number" and id > 0 then Util.call(LeaveChannelByName, name) end
    end
  end
end

-- Append to the player's draft or open one, on channel ("/i ") when given.
-- The player still chooses the channel and presses Enter. Failures return
-- nil and "full" / "unavailable".
function Chat.Draft(token, channel)
  if #token > MAX_CHAT then return nil, "full" end
  local active = ChatFrameUtil and ChatFrameUtil.GetActiveWindow or ChatEdit_GetActiveWindow
  local edit = active and active()
  if edit then
    local text = edit:GetText()
    if Util.secret(text) then return nil, "unavailable" end
    local insert = (text ~= "" and " " or "") .. token
    if #text + #insert > MAX_CHAT then return nil, "full" end
    edit:Insert(insert)
  else
    local open = ChatFrameUtil and ChatFrameUtil.OpenChat or ChatFrame_OpenChat
    if not open then return nil, "unavailable" end
    open((channel or "") .. token)
  end
  return true
end

-- format(payload) returns a hyperlink, or nil to leave an invalid or newer
-- token as plain text. Preserve every other chat argument, including nils.
function Chat.LinkFilter(pattern, format)
  return function(_, _, message, ...)
    if type(message) ~= "string" or Util.secret(message) then return end
    local text = message:gsub(pattern, format)
    return false, text, ...
  end
end

local installed = {}
function Chat.InstallLinks(filter, onLink, stage)
  if ns.STANDBY then return false end
  if installed[filter] then return true end
  local add = ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter
  if not (add and hooksecurefunc and SetItemRef) then return false end
  installed[filter] = true
  for _, event in ipairs(EVENTS) do add("CHAT_MSG_" .. event, filter) end
  -- Keep Blizzard's item-link handling and other addons' hooks intact.
  hooksecurefunc("SetItemRef", function(link) Util.Guard(stage, onLink, link) end)
  return true
end
