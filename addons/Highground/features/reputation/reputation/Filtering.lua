local _, ns = ...
local W, U = ns.Reputation, ns.Util
W.CHAT_EVENTS = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_CHANNEL", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
  "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
  "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_WHISPER", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE" }
-- Automatic replies start with this marker, and a client never answers a
-- message that starts with one, so two players who blacklist each other
-- cannot reply forever. It is always sent in English and its catalog entry
-- stays untranslated: 3.0.0 sent it in the addon language, and two players
-- with different languages did not recognize each other's replies.
W.REPLY_PREFIX = ns.Locale:Source("reputation.filtering.highground_reputation.f7407b")
-- What 3.0.0 sent in each addon language (esES and esMX shared one).
local LEGACY = { "[Highground Bekanntmachung]", "[Reputación de Highground]", "[Highground Réputation]",
  "[Highground reputazione]", "[Highground 평판]", "[Reputação de Highground]", "[Highground Репутация]",
  "[Highground声誉]", "[Highground聲譽]" }
-- Chat addons and typing can change case or add leading spaces.
local function Fold(text) return (text:gsub("^%s+", ""):lower()) end
-- Recognized whatever language either client uses: every catalog's text for
-- the marker (English first; Locale:Variants reads catalogs that are not
-- loaded from the generated locale index) and the 3.0.0 markers.
local markers = {}
do
  local seen = {}
  local function Add(text)
    local marker = Fold(text)
    if marker ~= "" and not seen[marker] then seen[marker] = true; markers[#markers + 1] = marker end
  end
  for _, text in ipairs(ns.Locale:Variants("reputation.filtering.highground_reputation.f7407b")) do Add(text) end
  for _, text in ipairs(LEGACY) do Add(text) end
end

function W.IsReply(message)
  local text = Fold(message)
  for _, marker in ipairs(markers) do
    if text:sub(1, #marker) == marker then return true end
  end
  return false
end

ns.Localization.Define(W, { DEFAULT_REPLY = "reputation.filtering.your_whisper_was_hidden_because_organization_lists.ed91b6" })
W.REPLY_INTERVALS = { ns.Localization.Define({ key = 0, label = ns.Locale:Get("reputation.filtering.every_whisper.d96788") }, { label = "reputation.filtering.every_whisper.d96788" }), ns.Localization.Define({ key = 30, label = ns.Locale:Get("reputation.filtering.once_per_player_every_30_seconds.172557") }, { label = "reputation.filtering.once_per_player_every_30_seconds.172557" }),
  ns.Localization.Define({ key = 60, label = ns.Locale:Get("reputation.filtering.once_per_player_per_minute.25cb6c") }, { label = "reputation.filtering.once_per_player_per_minute.25cb6c" }), ns.Localization.Define({ key = 600, label = ns.Locale:Get("reputation.filtering.once_per_player_every_10_minutes.9369b6") }, { label = "reputation.filtering.once_per_player_every_10_minutes.9369b6" }) }

function W.ReplyInterval()
  for _, choice in ipairs(W.REPLY_INTERVALS) do
    if W.db.settings.replyInterval == choice.key then return choice.key end
  end
  return 0
end

function W.ReplyMessage(entry)
  local template = W.Text(W.db.settings.replyText, 200)
  if template == "" then template = W.DEFAULT_REPLY end
  local values = { organization = W.Name(entry.community), categories = W.CategoryText(entry.row.active.categories) }
  local body = template:gsub("{(%a+)}", function(key) return values[key] or ("{" .. key .. "}") end)
  return W.Text(W.REPLY_PREFIX .. " " .. body, 240)
end

-- Chat filters, tooltips and menus read this index for every message. It is
-- rebuilt after any change, including native roster events, so it reads no
-- roster: member counts only rank several listing communities (Match).
function W.BuildIndex()
  local index = { names = {}, guids = {}, counts = {}, empty = true }
  local function Add(bucket, key, entry)
    bucket[key] = bucket[key] or {}
    bucket[key][#bucket[key] + 1] = entry
    index.empty = false
  end
  for _, c in ipairs(W.List()) do
    if c.synced then
      for _, row in ipairs(W.Rows(c, "blacklist")) do
        local entry = { community = c, row = row }
        Add(index.names, row.target.key, entry)
        if row.target.guid ~= "" then Add(index.guids, row.target.guid, entry) end
      end
    end
  end
  W.index = index
  return index
end

local candidates, seen, counts, NONE = {}, {}, nil, {}
local function Members(entry)
  local id = entry.community.id
  if counts[id] == nil then counts[id] = W.MemberCount(entry.community) end
  return counts[id]
end
-- Most members first, then the stable organization ID.
local function Larger(a, b)
  local x, y = Members(a), Members(b)
  return x == y and a.community.id < b.community.id or x > y
end
local function Add(entry)
  if W.Joined(entry.community) and not seen[entry.community.id] then
    candidates[#candidates + 1] = entry; seen[entry.community.id] = true
  end
end

-- The best joined listing and how many joined organizations list the target.
function W.Match(target)
  if not W.ready or not target then return end
  local index = W.index or W.BuildIndex()
  if index.empty then return nil, 0 end
  wipe(candidates); wipe(seen)
  if target.guid ~= "" then
    for _, entry in ipairs(index.guids[target.guid] or NONE) do Add(entry) end
    for _, entry in ipairs(index.names[target.key] or NONE) do if entry.row.target.guid == "" then Add(entry) end end
  else
    local guid
    for _, entry in ipairs(index.names[target.key] or NONE) do
      local other = entry.row.target.guid
      if other ~= "" then
        if guid and guid ~= other then return end -- a reused/ambiguous name cannot identify a character
        guid = other
      end
      Add(entry)
    end
  end
  if #candidates > 1 then
    counts = index.counts
    table.sort(candidates, Larger)
  end
  return candidates[1], #candidates
end

-- Each chat window filters the same message, and senders repeat: the last
-- sender's answer is kept on the index, so any change (W.Changed) drops it.
local function Remember(index, name, guid, entry, count)
  index.chatName, index.chatGuid, index.chatEntry, index.chatCount = name, guid, entry, count
  return entry, count
end

function W.ChatMatch(...)
  if not W.ready or W.db.settings.filter == false then return end
  -- Most players have no blacklist: skip parsing every chat sender.
  local index = W.index or W.BuildIndex()
  if index.empty then return end
  local name, guid = U.value(select(2, ...)), U.value(select(12, ...))
  if name ~= nil and name == index.chatName and guid == index.chatGuid then return index.chatEntry, index.chatCount end
  if not W.String(name, 200) then return end
  local target = W.Target(name, nil, guid ~= "" and guid or nil, true)
  return Remember(index, name, guid, W.Match(target))
end

function W.ChatFilter(_, _, ...)
  return W.ChatMatch(...) ~= nil
end

function W.OnWhisper(_, ...)
  if not W.ready or W.db.settings.reply == false then return end
  local entry = W.ChatMatch(...)
  local message, sender = U.value(select(1, ...)), W.Actor(U.value(select(2, ...)))
  if not entry or not sender or sender == W.Me() or type(message) ~= "string"
    or W.IsReply(message) then return end
  if U.value(U.call(C_ChatInfo and C_ChatInfo.InChatMessagingLockdown)) then return end
  local now = W.Now()
  local replies = ns.Scope.Saved("replies", "character", W.db)
  local last, interval = replies[sender], W.ReplyInterval()
  if interval > 0 and type(last) == "number" and last <= now + 30 and now - last < interval then return end
  if not ns.Api.Fn("C_ChatInfo", "SendChatMessage") then return end
  local text = W.ReplyMessage(entry)
  -- Forever's internal realm suffix identifies records but is not a valid
  -- whisper address. Other clients still need their cross-realm suffixes.
  local recipient = ns.Core.DisplayName(sender, true)
  if ns.Api.SendChatMessage(text, "WHISPER", nil, recipient) then
    replies[sender] = now
    for name, at in pairs(replies) do if type(at) ~= "number" or now - at >= 600 or at > now + 30 then replies[name] = nil end end
  end
end

function W.Tooltip(tooltip, data)
  if not W.ready or W.db.settings.tooltip == false or not tooltip or not tooltip.AddLine then return end
  local _, unit = U.call(tooltip.GetUnit, tooltip)
  local target = unit and W.Unit(U.value(unit))
  if not target and type(data) == "table" then
    local guid = U.value(data.guid)
    if W.String(guid, 64) then target = { guid = guid, key = "" } end
  end
  local entry, count = W.Match(target)
  if not entry then return end
  local token = entry.community.id .. ":" .. entry.row.active.id
  if tooltip.hgrepEntry == token then return end
  tooltip.hgrepEntry = token
  tooltip:AddLine(ns.Locale:Get("reputation.filtering.highground_reputation_blacklisted.48d274"), ns.Theme.Color("danger"))
  local r, g, b = ns.Theme.Color("text")
  tooltip:AddLine(W.CategoryText(entry.row.active.categories) .. " - " .. W.Name(entry.community), r, g, b, true)
  if entry.row.active.note ~= "" then tooltip:AddLine(entry.row.active.note, r, g, b, true) end
  if count > 1 then tooltip:AddLine(ns.Locale:Format("reputation.filtering.also_listed_by_value2_other_joined_communities.6066a4", { value2 = (count - 1) }), ns.Theme.Color("textMuted")) end
end

function W.InstallFilters()
  if ns.STANDBY or W.filtersInstalled then return end
  local add = ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter
  if not add then return end
  for _, event in ipairs(W.CHAT_EVENTS) do add(event, W.ChatFilter) end
  W.filtersInstalled = true
end

function W.InstallTooltip()
  if ns.STANDBY or W.tooltipInstalled or not GameTooltip then return end
  local ok = pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipCleared", function(tip) tip.hgrepEntry = nil end)
  if not ok then return end
  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, W.Tooltip)
    W.tooltipInstalled = true
  else W.tooltipInstalled = pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetUnit", W.Tooltip) end
end
