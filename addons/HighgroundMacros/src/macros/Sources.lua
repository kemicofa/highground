local _, ns = ...
local Macros = ns.Macros
local Host = Macros.Host
local Suggest = Macros.Suggest
local Call, Plain = Host.call, Host.value

---------------------------------------------------------------------------
-- Suggestion sources besides spells (macros/Suggest.lua): items and slots,
-- and buffs worth removing before a cast.
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

