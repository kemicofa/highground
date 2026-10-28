local _, ns = ...
local Macros = ns.Macros
local Host = Macros.Host
local Suggest = Macros.Suggest
local Call, Plain = Host.call, Host.value

---------------------------------------------------------------------------
-- Suggestion sources besides spells (macros/Suggest.lua): items and slots,
-- buffs worth removing before a cast, and game functions for /run.
---------------------------------------------------------------------------
-- Equipped items and items in your bags, plus equipment slot numbers.
function Suggest.Items()
  local list, _, add = Suggest.Unique()
  local nameOf = (C_Item and C_Item.GetItemNameByID) or function(id) return (GetItemInfo(id)) end
  for slot = 1, 19 do
    local id = Plain(Call(GetInventoryItemID, "player", slot))
    if id then add(Plain(Call(nameOf, id))) end
  end
  local bags = C_Container or {}
  local slots = bags.GetContainerNumSlots or GetContainerNumSlots
  local itemID = bags.GetContainerItemID or GetContainerItemID
  for bag = 0, 4 do
    for i = 1, (slots and Plain(Call(slots, bag))) or 0 do
      local id = itemID and Plain(Call(itemID, bag, i))
      if id then add(Plain(Call(nameOf, id))) end
    end
  end
  table.sort(list)
  local out = {}
  for _, slot in ipairs({ "13", "14", "10", "6", "15", "16", "17" }) do
    out[#out + 1] = { text = slot, hint = Macros.SLOT_NAMES and Macros.SLOT_NAMES[slot] }
  end
  for _, name in ipairs(list) do out[#out + 1] = { text = name, hint = "item" } end
  return out
end

function Suggest.ItemProvider(before)
  local word = before:match("^%s*(.-)$")
  return word, Suggest.Match(Suggest.Items(), word)
end

-- Buffs worth removing before a cast because they block or waste it
-- (config/Macros.lua), and only ones you can have: your class's that are
-- in your spellbook, ones other players can put on you in this game, then
-- what you wear now.
local Config = Macros.Config
local CLASS_BUFFS, OTHERS_BUFFS, ICONS = Config.CLASS_BUFFS, Config.OTHERS_BUFFS, Config.BUFF_ICONS
Suggest.CLASS_BUFFS, Suggest.OTHERS_BUFFS, Suggest.BUFF_ICONS = CLASS_BUFFS, OTHERS_BUFFS, ICONS

function Suggest.AuraProvider(before)
  local word = before:match("^%s*(.-)$")
  local list, _, unique = Suggest.Unique()
  local function add(name, hint, icon)
    unique(name, { text = name, hint = hint, icon = icon or Suggest.SpellIcon,
      fallbackIcon = ICONS[name] and ("Interface\\Icons\\" .. ICONS[name]) })
  end
  local class = Host.Class()
  for _, a in ipairs(CLASS_BUFFS[class] or {}) do
    local name = Macros.SpellFor(a[1])
    if name and Macros.Known(name) then add(name, a[2]) end
  end
  for _, a in ipairs(OTHERS_BUFFS) do
    local name = Macros.SpellFor(a[1])
    if name and (not a.known or Macros.Known(name)) then add(name, a[2]) end
  end
  for i = 1, 40 do
    local data = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex and Call(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
    local name, icon
    if data then
      name, icon = Plain(data.name), Plain(data.icon)
    elseif not C_UnitAuras then
      local n, _, tex = Call(UnitBuff, "player", i)
      name, icon = Plain(n), Plain(tex)
    end
    if not name then break end
    add(name, "on you now", icon)
  end
  if word == "" then -- keep the order above: yours, others', current
    local out = {}
    for i = 1, math.min(Suggest.LIMIT, #list) do out[i] = list[i] end
    return word, out
  end
  return word, Suggest.Match(list, word)
end

-- Game functions worth calling from /run and /script, by the clients that
-- have them (Host.Client(): "retail" is also WoW Forever's; "classic" is
-- Classic Era's and The Burning Crusade's). Today's Classic clients use
-- C_GossipInfo and C_Container too; the old globals (SelectGossipOption,
-- GetContainerNumSlots, UseEquipmentSet) are on none of them. Protected
-- functions (targeting, raid markers on Retail, joining battlegrounds,
-- toys) are left out: a script cannot call them.
local ALL = { retail = true, cata = true, classic = true }
local RETAIL = { retail = true }
local NOT_RETAIL = { cata = true, classic = true }
local WITH_SETS = { retail = true, cata = true } -- equipment manager
local SCRIPT_API = {
  { "BuyMerchantItem", ALL, "buy from the open vendor: index, count" },
  { "GetMerchantNumItems", ALL, "number of items the vendor sells" },
  { "RepairAllItems", ALL, "repair everything at the vendor" },
  { "CanMerchantRepair", ALL, "the vendor can repair" },
  { "AcceptQuest", ALL, "accept the open quest" },
  { "CompleteQuest", ALL, "turn in the open quest" },
  { "GetQuestReward", ALL, "take quest reward: choice index" },
  { "LeaveBattlefield", ALL, "leave the battleground or arena" },
  { "SetCVar", ALL, "change a game setting" },
  { "UIErrorsFrame:Clear", ALL, "clear red error text" },
  { "C_GossipInfo.SelectOptionByIndex", ALL, "pick a talk option by position" },
  { "C_GossipInfo.SelectOption", ALL, "pick a talk option by ID" },
  { "C_GossipInfo.GetOptions", ALL, "the talk options shown" },
  { "C_Container.UseContainerItem", ALL, "use an item: bag, slot" },
  { "C_Container.GetContainerNumSlots", ALL, "slots in a bag" },
  { "C_Container.GetContainerItemLink", ALL, "item link: bag, slot" },
  { "C_EquipmentSet.UseEquipmentSet", WITH_SETS, "wear a saved set: set ID" },
  { "C_EquipmentSet.GetEquipmentSetID", WITH_SETS, "a saved set's ID: name" },
  { "C_MountJournal.SummonByID", RETAIL, "summon a mount: ID, 0 for random favorite" },
  { "C_MerchantFrame.GetItemInfo", RETAIL, "a vendor item's name, price, stock" },
  { "C_MerchantFrame.SellAllJunkItems", RETAIL, "sell all gray items" },
  { "C_ChatInfo.SendChatMessage", RETAIL, "send chat: text, channel" },
  { "GetMerchantItemInfo", NOT_RETAIL, "a vendor item's name, price, stock" },
  { "SendChatMessage", NOT_RETAIL, "send chat: text, channel" },
}

-- The script functions a client has, in the order above.
local scriptCache = {}
function Suggest.ScriptFunctions(client)
  client = client or Host.Client()
  if scriptCache[client] then return scriptCache[client] end
  local out = {}
  for _, f in ipairs(SCRIPT_API) do
    if f[2][client] then out[#out + 1] = { text = f[1], hint = f[3] } end
  end
  scriptCache[client] = out
  return out
end

-- Whether code ends inside a string or a comment.
local function InStringOrComment(code)
  local i = 1
  while i <= #code do
    local c = code:sub(i, i)
    local long = code:match("^%-?%-?%[(=*)%[", i) -- [[...]], --[[...]]
    if code:sub(i, i + 1) == "--" and not long then return true end
    if long then
      local open = code:find("[", i, true)
      local close = code:find("]" .. long .. "]", open + #long + 2, true)
      if not close then return true end
      i = close + #long + 2
    elseif c == '"' or c == "'" then
      local j = i + 1
      while j <= #code and code:sub(j, j) ~= c do
        if code:sub(j, j) == "\\" then j = j + 1 end
        j = j + 1
      end
      if j > #code then return true end
      i = j + 1
    else
      i = i + 1
    end
  end
  return false
end

-- Lua after /run or /script: completes the name being typed. Nothing typed
-- yet lists every function; nothing inside strings, comments or numbers.
function Suggest.ScriptProvider(code)
  if InStringOrComment(code) then return "", {} end
  local start, word = code:match("()([%a_][%w_%.:]*)$")
  if not word then
    if code:match("^%s*$") then return "", Suggest.Match(Suggest.ScriptFunctions(), "") end
    return "", {}
  end
  if start > 1 and code:sub(start - 1, start - 1):match("[%w_]") then return "", {} end -- 0xC, 1e5
  return word, Suggest.Match(Suggest.ScriptFunctions(), word)
end
