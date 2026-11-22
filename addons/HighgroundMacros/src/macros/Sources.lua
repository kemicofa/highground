local _, ns = ...
local Locale, Localization = ns.Macros.Host.Messages, ns.Macros.Host.Localization
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
  local nameOf = ns.Api.ItemName
  for slot = 1, 19 do
    local id = Plain(Call(GetInventoryItemID, "player", slot))
    if id then add(Plain(Call(nameOf, id))) end
  end
  local slots = ns.Api.Fn("C_Container", "GetContainerNumSlots")
  local itemID = ns.Api.Fn("C_Container", "GetContainerItemID")
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
  for _, name in ipairs(list) do out[#out + 1] = { text = name, hint = Locale:Get("macros.sources.item.3a7d97") } end
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
    add(name, Locale:Get("macros.sources.on_you_now.f0efde"), icon)
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
  Localization.Define({ "BuyMerchantItem", ALL, Locale:Get("macros.sources.buy_from_the_open_vendor_index_count.1f99d0") }, { [3] = "macros.sources.buy_from_the_open_vendor_index_count.1f99d0" }),
  Localization.Define({ "GetMerchantNumItems", ALL, Locale:Get("macros.sources.number_of_items_the_vendor_sells.53d03b") }, { [3] = "macros.sources.number_of_items_the_vendor_sells.53d03b" }),
  Localization.Define({ "RepairAllItems", ALL, Locale:Get("macros.sources.repair_everything_at_the_vendor.cb2d7e") }, { [3] = "macros.sources.repair_everything_at_the_vendor.cb2d7e" }),
  Localization.Define({ "CanMerchantRepair", ALL, Locale:Get("macros.sources.the_vendor_can_repair.7560dd") }, { [3] = "macros.sources.the_vendor_can_repair.7560dd" }),
  Localization.Define({ "AcceptQuest", ALL, Locale:Get("macros.sources.accept_the_open_quest.8a2472") }, { [3] = "macros.sources.accept_the_open_quest.8a2472" }),
  Localization.Define({ "CompleteQuest", ALL, Locale:Get("macros.sources.turn_in_the_open_quest.5dc82f") }, { [3] = "macros.sources.turn_in_the_open_quest.5dc82f" }),
  Localization.Define({ "GetQuestReward", ALL, Locale:Get("macros.sources.take_quest_reward_choice_index.e22b8c") }, { [3] = "macros.sources.take_quest_reward_choice_index.e22b8c" }),
  Localization.Define({ "LeaveBattlefield", ALL, Locale:Get("macros.sources.leave_the_battleground_or_arena.ff55ee") }, { [3] = "macros.sources.leave_the_battleground_or_arena.ff55ee" }),
  Localization.Define({ "SetCVar", ALL, Locale:Get("macros.sources.change_a_game_setting.05920a") }, { [3] = "macros.sources.change_a_game_setting.05920a" }),
  Localization.Define({ "UIErrorsFrame:Clear", ALL, Locale:Get("macros.sources.clear_red_error_text.752992") }, { [3] = "macros.sources.clear_red_error_text.752992" }),
  Localization.Define({ "C_GossipInfo.SelectOptionByIndex", ALL, Locale:Get("macros.sources.pick_a_talk_option_by_position.d8f32e") }, { [3] = "macros.sources.pick_a_talk_option_by_position.d8f32e" }),
  Localization.Define({ "C_GossipInfo.SelectOption", ALL, Locale:Get("macros.sources.pick_a_talk_option_by_id.a2b351") }, { [3] = "macros.sources.pick_a_talk_option_by_id.a2b351" }),
  Localization.Define({ "C_GossipInfo.GetOptions", ALL, Locale:Get("macros.sources.the_talk_options_shown.99ee5a") }, { [3] = "macros.sources.the_talk_options_shown.99ee5a" }),
  Localization.Define({ "C_Container.UseContainerItem", ALL, Locale:Get("macros.sources.use_an_item_bag_slot.7c67e2") }, { [3] = "macros.sources.use_an_item_bag_slot.7c67e2" }),
  Localization.Define({ "C_Container.GetContainerNumSlots", ALL, Locale:Get("macros.sources.slots_in_a_bag.43667f") }, { [3] = "macros.sources.slots_in_a_bag.43667f" }),
  Localization.Define({ "C_Container.GetContainerItemLink", ALL, Locale:Get("macros.sources.item_link_bag_slot.3334b7") }, { [3] = "macros.sources.item_link_bag_slot.3334b7" }),
  Localization.Define({ "C_EquipmentSet.UseEquipmentSet", WITH_SETS, Locale:Get("macros.sources.wear_a_saved_set_set_id.0db8bd") }, { [3] = "macros.sources.wear_a_saved_set_set_id.0db8bd" }),
  Localization.Define({ "C_EquipmentSet.GetEquipmentSetID", WITH_SETS, Locale:Get("macros.sources.a_saved_set_s_id_name.69f9b4") }, { [3] = "macros.sources.a_saved_set_s_id_name.69f9b4" }),
  Localization.Define({ "C_MountJournal.SummonByID", RETAIL, Locale:Get("macros.sources.summon_a_mount_id_0_for_random.31716d") }, { [3] = "macros.sources.summon_a_mount_id_0_for_random.31716d" }),
  Localization.Define({ "C_MerchantFrame.GetItemInfo", RETAIL, Locale:Get("macros.sources.a_vendor_item_s_name_price_stock.7f3e8a") }, { [3] = "macros.sources.a_vendor_item_s_name_price_stock.7f3e8a" }),
  Localization.Define({ "C_MerchantFrame.SellAllJunkItems", RETAIL, Locale:Get("macros.sources.sell_all_gray_items.093614") }, { [3] = "macros.sources.sell_all_gray_items.093614" }),
  Localization.Define({ "C_ChatInfo.SendChatMessage", RETAIL, Locale:Get("macros.sources.send_chat_text_channel.471186") }, { [3] = "macros.sources.send_chat_text_channel.471186" }),
  Localization.Define({ "GetMerchantItemInfo", NOT_RETAIL, Locale:Get("macros.sources.a_vendor_item_s_name_price_stock.7f3e8a") }, { [3] = "macros.sources.a_vendor_item_s_name_price_stock.7f3e8a" }),
  Localization.Define({ "SendChatMessage", NOT_RETAIL, Locale:Get("macros.sources.send_chat_text_channel.471186") }, { [3] = "macros.sources.send_chat_text_channel.471186" }),
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
