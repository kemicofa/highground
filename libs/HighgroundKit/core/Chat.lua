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

-- Append to the player's draft or open one. The player still chooses the
-- channel and presses Enter. Failures return nil and "full" / "unavailable".
function Chat.Draft(token)
  if #token > MAX_CHAT then return nil, "full" end
  local active = ChatFrameUtil and ChatFrameUtil.GetActiveWindow or ChatEdit_GetActiveWindow
  local edit = active and active()
  if edit then
    local text = edit:GetText()
    local insert = (text ~= "" and " " or "") .. token
    if #text + #insert > MAX_CHAT then return nil, "full" end
    edit:Insert(insert)
  else
    local open = ChatFrameUtil and ChatFrameUtil.OpenChat or ChatFrame_OpenChat
    if not open then return nil, "unavailable" end
    open(token)
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
