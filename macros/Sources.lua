local _, ns = ...
local Core, Macros = ns.Core, ns.Macros
local Suggest = Macros.Suggest
local Call, Plain = ns.Util.call, ns.Util.value

-- Suggestion sources besides spells (macros/Suggest.lua): items and slots,
-- and buffs worth removing before a cast.
-- Equipped items and items in your bags, plus equipment slot numbers.
function Suggest.Items()
  local set, list = {}, {}
  local function add(name) if type(name) == "string" and name ~= "" and not set[name] then set[name] = true; list[#list + 1] = name end end
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

-- Buffs worth removing before a cast because they block or waste it: your
-- class's, then ones other players put on you, then what you wear now.
-- Names may differ per game: G(cata, retail, forever) from macros/General.lua.
local G = Macros.G
local CLASS_BUFFS = {
  WARRIOR = { { "Bladestorm", "stops your other abilities" }, { G("Recklessness", "Recklessness", "Recklessness"), "drop it" } },
  PALADIN = { { "Divine Shield", "you can't attack under it" },
    { G("Hand of Protection", "Blessing of Protection", "Blessing of Protection"), "you can't attack under it" },
    { G(nil, "Blessing of Spellwarding"), "drop it" }, { G("Divine Plea"), "halves your healing" } },
  MAGE = { { "Ice Block", "blocks every action" }, { G(nil, "Alter Time"), "would snap you back" },
    { "Invisibility", "end it now" }, { G(nil, "Greater Invisibility"), "end it now" }, { G("Mage Ward", nil), "drop it" } },
  PRIEST = { { G("Dispersion", "Dispersion"), "blocks most spells" }, { G("Shadowform", "Shadowform", "Shadowform"), "lets you heal" },
    { G(nil, "Spirit of Redemption"), "end it" } },
  HUNTER = { { G("Deterrence", nil), "blocks attacking" }, { G(nil, "Aspect of the Turtle"), "blocks attacking" },
    { G(nil, "Camouflage"), "leave Camouflage" }, { G("Aspect of the Pack", nil, "Aspect of the Cheetah"), "dazed when hit" },
    { "Feign Death", "stand up" } },
  DEATHKNIGHT = { { "Lichborne", "turns heals into damage" }, { G(nil, "Death's Advance"), "drop it" } },
  DRUID = { { "Cat Form", "leave the form" }, { G("Bear Form", "Bear Form", "Dire Bear Form"), "leave the form" },
    { "Travel Form", "leave the form" }, { G("Moonkin Form", "Moonkin Form", "Moonkin Form"), "leave the form" },
    { G("Tree of Life", nil), "leave the form" }, { "Prowl", "leave stealth" } },
  SHAMAN = { { "Ghost Wolf", "leave the form" }, { G(nil, "Spirit Walk"), "drop it" } },
  ROGUE = { { "Stealth", "leave stealth" }, { G(nil, "Shadow Dance"), "leave it out of combat" }, { "Vanish", "leave stealth" } },
  WARLOCK = { { G("Soulburn", nil), "drop an unused Soulburn" }, { G(nil, "Burning Rush"), "it drains your health" },
    { G("Metamorphosis", nil), "leave the form" } },
  MONK = { { "Zen Meditation", "would cancel itself" }, { "Fortifying Brew", "drop it" } },
  DEMONHUNTER = { { "Netherwalk", "blocks attacking" }, { "Metamorphosis", "leave it" } },
  EVOKER = { { "Hover", "stop hovering" }, { "Obsidian Scales", "drop it" } },
}
local OTHERS_BUFFS = {
  { G("Hand of Protection", "Blessing of Protection", "Blessing of Protection"), "a paladin's: you can't attack" },
  { G(nil, "Blessing of Spellwarding"), "a paladin's: drop it" },
  { G(nil, nil, "Divine Intervention"), "a paladin's: you can't act" },
  { G("Hand of Salvation", nil, "Blessing of Salvation"), "a paladin's: no threat" },
  { G(nil, "Power Infusion"), "a priest's: drop it" },
  { "Shadowmeld", "racial: leave it" },
}
Suggest.CLASS_BUFFS, Suggest.OTHERS_BUFFS = CLASS_BUFFS, OTHERS_BUFFS

function Suggest.AuraProvider(before)
  local word = before:match("^%s*(.-)$")
  local list, set = {}, {}
  local function add(name, hint)
    name = Macros.SpellFor(name)
    if name and not set[name] then set[name] = true; list[#list + 1] = { text = name, hint = hint } end
  end
  local class = Core.me and Core.me.class or select(2, UnitClass("player"))
  for _, a in ipairs(CLASS_BUFFS[class] or {}) do add(a[1], a[2]) end
  for _, a in ipairs(OTHERS_BUFFS) do add(a[1], a[2]) end
  for i = 1, 40 do
    local data = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex and Call(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
    local name = data and Plain(data.name) or (not C_UnitAuras and Plain(Call(UnitBuff, "player", i)))
    if not name then break end
    add(name, "on you now")
  end
  -- Other classes' own buffs last, so typing finds any of them.
  for other, buffs in pairs(CLASS_BUFFS) do
    if other ~= class then for _, a in ipairs(buffs) do add(a[1], a[2]) end end
  end
  if word == "" then -- keep the order above: yours, others', current
    local out = {}
    for i = 1, math.min(Suggest.LIMIT, #list) do out[i] = list[i] end
    return word, out
  end
  return word, Suggest.Match(list, word)
end

