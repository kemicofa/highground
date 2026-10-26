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

-- Icon files by buff name: the game only finds icons by name for spells you
-- know, and these file names are the same in every game.
local ICONS = {
  ["Bladestorm"] = "Ability_Warrior_Bladestorm", ["Recklessness"] = "Ability_CriticalStrike",
  ["Divine Shield"] = "Spell_Holy_DivineIntervention", ["Hand of Protection"] = "Spell_Holy_SealOfProtection",
  ["Blessing of Protection"] = "Spell_Holy_SealOfProtection", ["Blessing of Spellwarding"] = "Spell_Holy_BlessingOfProtection",
  ["Divine Plea"] = "Spell_Holy_Aspiration", ["Divine Intervention"] = "Spell_Nature_TimeStop",
  ["Hand of Salvation"] = "Spell_Holy_SealOfSalvation", ["Blessing of Salvation"] = "Spell_Holy_SealOfSalvation",
  ["Ice Block"] = "Spell_Frost_Frost", ["Alter Time"] = "Spell_Mage_AlterTime", ["Invisibility"] = "Ability_Mage_Invisibility",
  ["Greater Invisibility"] = "Ability_Mage_GreaterInvisibility", ["Mage Ward"] = "Spell_Fire_TwilightFireward",
  ["Dispersion"] = "Spell_Shadow_Dispersion", ["Shadowform"] = "Spell_Shadow_Shadowform",
  ["Spirit of Redemption"] = "Inv_Enchant_EssenceEternalLarge", ["Power Infusion"] = "Spell_Holy_PowerInfusion",
  ["Deterrence"] = "Ability_Whirlwind", ["Aspect of the Turtle"] = "Ability_Hunter_Pet_Turtle",
  ["Camouflage"] = "Ability_Hunter_Camouflage", ["Aspect of the Pack"] = "Ability_Mount_WhiteTiger",
  ["Aspect of the Cheetah"] = "Ability_Mount_JungleTiger", ["Feign Death"] = "Ability_Rogue_FeignDeath",
  ["Lichborne"] = "Spell_Shadow_RaiseDead", ["Death's Advance"] = "Spell_Shadow_DemonicEmpathy",
  ["Cat Form"] = "Ability_Druid_CatForm", ["Bear Form"] = "Ability_Racial_BearForm",
  ["Dire Bear Form"] = "Ability_Racial_BearForm", ["Travel Form"] = "Ability_Druid_TravelForm",
  ["Moonkin Form"] = "Spell_Nature_ForceOfNature", ["Tree of Life"] = "Ability_Druid_TreeofLife",
  ["Prowl"] = "Ability_Ambush", ["Ghost Wolf"] = "Spell_Nature_SpiritWolf", ["Spirit Walk"] = "Ability_Tracking",
  ["Stealth"] = "Ability_Stealth", ["Shadow Dance"] = "Ability_Rogue_ShadowDance", ["Vanish"] = "Ability_Vanish",
  ["Soulburn"] = "Spell_Warlock_Soulburn", ["Burning Rush"] = "Ability_Deathwing_FierySpeed",
  ["Metamorphosis"] = "Spell_Shadow_DemonForm", ["Zen Meditation"] = "Ability_Monk_ZenMeditation",
  ["Fortifying Brew"] = "Ability_Monk_FortifyingAle_New", ["Netherwalk"] = "Spell_Warlock_DemonSoul",
  ["Hover"] = "Ability_Evoker_Hover", ["Obsidian Scales"] = "Inv_Artifact_DragonScales",
  ["Shadowmeld"] = "Ability_Ambush",
}
Suggest.BUFF_ICONS = ICONS

function Suggest.AuraProvider(before)
  local word = before:match("^%s*(.-)$")
  local list, set = {}, {}
  local function add(name, hint, icon)
    name = Macros.SpellFor(name)
    if name and not set[name] then
      set[name] = true
      list[#list + 1] = { text = name, hint = hint, icon = icon,
        spellIcon = icon == nil, fallbackIcon = ICONS[name] and ("Interface\\Icons\\" .. ICONS[name]) }
    end
  end
  local class = Core.me and Core.me.class or select(2, UnitClass("player"))
  for _, a in ipairs(CLASS_BUFFS[class] or {}) do add(a[1], a[2]) end
  for _, a in ipairs(OTHERS_BUFFS) do add(a[1], a[2]) end
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

