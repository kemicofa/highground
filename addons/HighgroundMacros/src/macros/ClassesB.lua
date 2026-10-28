local _, ns = ...
local Macros = ns.Macros
local G, Enemy, Ally, Self, Cursor, Raw = Macros.G, Macros.Enemy, Macros.Ally, Macros.Self, Macros.Cursor, Macros.Raw

-- Class macros, part two (see macros/ClassesA.lua).
local MO_HELP = "[@mouseover,help,nodead][@target,help,nodead][@player]"
local function Swift(heal) -- Nature's Swiftness, then an instant big heal
  return "#showtooltip Nature's Swiftness\n/cast Nature's Swiftness\n/cast " .. MO_HELP .. " " .. heal
end
local CURSOR_TOTEMS = { retail = true }
local DROP_TOTEMS = { cata = true, forever = true }

Macros.Add("SHAMAN", {
  Enemy("Interrupt", "Wind Shear / Earth Shock; stops casting first", G("Wind Shear", "Wind Shear", "Earth Shock"),
    { stopcast = true }),
  Enemy("Hex", "Hex", G("Hex", "Hex")),
  Enemy("Purge", "Remove a buff", "Purge"),
  Enemy("Frost Shock", "Slow", "Frost Shock"),
  Self("Grounding", "Grounding Totem; stops casting first", "Grounding Totem", { stopcast = true }),
  Self("Tremor", "Tremor Totem: break fear", "Tremor Totem", { stopcast = true }),
  Self("Earthbind", "Earthbind Totem at your feet", "Earthbind Totem", { games = DROP_TOTEMS }),
  Cursor("Earthbind", "Earthbind Totem at your cursor", "Earthbind Totem", { games = CURSOR_TOTEMS }),
  Cursor("Capacitor", "Capacitor Totem at your cursor", G(nil, "Capacitor Totem")),
  Cursor("Static Field", "Static Field Totem at your cursor", G(nil, "Static Field Totem")),
  Cursor("Spirit Link", "Spirit Link Totem at your cursor", G(nil, "Spirit Link Totem")),
  Self("Spirit Link", "Spirit Link Totem", G("Spirit Link Totem"), { games = { cata = true } }),
  Cursor("Projection", "Move your totems to your cursor", G(nil, "Totemic Projection")),
  Ally("Cleanse Spirit", "Dispel an ally", G("Cleanse Spirit", "Cleanse Spirit")),
  Ally("Purify Spirit", "Restoration: dispel an ally", G(nil, "Purify Spirit")),
  Ally("Cure Poison", "Remove a poison", G(nil, nil, "Cure Poison")),
  Ally("Earth Shield", "Earth Shield", G("Earth Shield", "Earth Shield", nil, "Earth Shield")),
  Ally("Quick Heal", "Healing Surge (not Restoration on Retail) / Lesser Healing Wave", G("Healing Surge", "Healing Surge", "Lesser Healing Wave")),
  Raw("NS Heal", "Nature's Swiftness, then an instant big heal",
    G(Swift("Greater Healing Wave"), Swift("Healing Wave"), Swift("Healing Wave")),
    { needs = { "Nature's Swiftness", G("Greater Healing Wave", "Healing Wave", "Healing Wave") } }),
  Self("Spiritwalker", "Spiritwalker's Grace: cast while moving", G("Spiritwalker's Grace", "Spiritwalker's Grace")),
  Self("Ghost Wolf", "Ghost Wolf without toggling it off", "Ghost Wolf", { force = true }),
  Self("Stormstrike", "Stormstrike, keep auto attacking", "Stormstrike", { startattack = true }),
})

Macros.Add("MAGE", {
  Enemy("Counterspell", "Interrupt; stops casting first", "Counterspell", { stopcast = true }),
  Enemy("Polymorph", "Polymorph", "Polymorph"),
  Enemy("Spellsteal", "Steal a buff", G("Spellsteal", "Spellsteal", nil, "Spellsteal")),
  Enemy("Slow", "Slow", G("Slow", nil, nil, "Slow")),
  Enemy("Deep Freeze", "Stun", G("Deep Freeze")),
  Ally("Remove Curse", "Remove a curse", G("Remove Curse", "Remove Curse", "Remove Lesser Curse")),
  Self("Ice Block", "Ice Block; press again to cancel it", "Ice Block", { toggle = true, stopcast = true, mode = "both" }),
  Self("Alter Time", "Alter Time; press again to return", G(nil, "Alter Time"), { toggle = true }),
  Self("Blink", "Blink; stops casting first", "Blink", { stopcast = true }),
  Self("Frost Nova", "Frost Nova; stops casting first", "Frost Nova", { stopcast = true }),
  Self("Invisibility", "Invisibility; stops casting first", G("Invisibility", "Invisibility"), { stopcast = true, mode = "both" }),
  Self("Dragon's Breath", "Disorient in front of you", G("Dragon's Breath", "Dragon's Breath")),
  Cursor("Ring of Frost", "Ring of Frost at your cursor", G("Ring of Frost", "Ring of Frost")),
  Cursor("Freeze", "Water Elemental: root at your cursor", G("Freeze", "Freeze"), { pet = true }),
  Raw("PoM Poly", "Presence of Mind, then an instant Polymorph",
    G("#showtooltip Presence of Mind\n/cast Presence of Mind\n/cast [@focus,harm,nodead][] Polymorph", nil,
      "#showtooltip Presence of Mind\n/cast Presence of Mind\n/cast [@focus,harm,nodead][] Polymorph"),
    { needs = { "Presence of Mind", "Polymorph" } }),
})

Macros.Add("WARLOCK", {
  Enemy("Fear", "Fear", "Fear"),
  Enemy("Coil", "Death Coil / Mortal Coil", G("Death Coil", "Mortal Coil", "Death Coil")),
  Enemy("Spell Lock", "Felhunter interrupt (Command Demon on Retail)", G("Spell Lock", "Command Demon", "Spell Lock"),
    { pet = true }),
  Enemy("Seduction", "Succubus: Seduction", G("Seduction", nil, "Seduction"), { pet = true }),
  Enemy("Axe Toss", "Felguard stun", G("Axe Toss"), { pet = true }),
  Enemy("Banish", "Banish a demon or elemental", "Banish"),
  Enemy("Tongues", "Curse of Tongues", "Curse of Tongues"),
  Enemy("Exhaustion", "Curse of Exhaustion", "Curse of Exhaustion"),
  Enemy("Weakness", "Curse of Weakness", "Curse of Weakness"),
  -- Vanilla Devour Magic dispels friends too; from Cataclysm on it only purges enemies.
  Self("Devour Magic", "Felhunter: dispel an ally or purge an enemy under your mouse", G(nil, nil, "Devour Magic"),
    { target = "mouseover", kind = "any", fallback = true, pet = true }),
  Enemy("Devour Magic", "Felhunter: purge a buff from your focus or target", G("Devour Magic"), { pet = true }),
  Self("Howl", "Howl of Terror; stops casting first", "Howl of Terror", { stopcast = true }),
  Cursor("Shadowfury", "Shadowfury at your cursor", G("Shadowfury", "Shadowfury")),
  Self("Circle Port", "Demonic Circle: Teleport", G("Demonic Circle: Teleport", "Demonic Circle: Teleport"), { stopcast = true }),
  Raw("Soulburn Pet", "Soulburn, then an instant Felhunter", "#showtooltip Soulburn\n/cast Soulburn\n/cast Summon Felhunter",
    { games = { cata = true }, needs = { "Soulburn", "Summon Felhunter" } }),
})

local BEAR = G({ 1, "Bear Form" }, nil, { 1, "Dire Bear Form" })
Macros.Add("DRUID", {
  Enemy("Cyclone", "Cyclone", G("Cyclone", "Cyclone", nil, "Cyclone")),
  Enemy("Roots", "Entangling Roots", "Entangling Roots"),
  Enemy("Hibernate", "Hibernate a druid or beast", "Hibernate"),
  Enemy("Bash", "Stun (Bear Form on Cata and Forever)", G("Bash", "Mighty Bash", "Bash"), { stance = BEAR }),
  Enemy("Skull Bash", "Interrupt", G("Skull Bash", "Skull Bash")),
  Enemy("Solar Beam", "Silence", G("Solar Beam", "Solar Beam")),
  -- Hits what your focus (or a party member) is attacking; your target stays.
  { name = "Starsurge", desc = "Starsurge whoever your focus or a party member is attacking, keeping your target",
    spell = G("Starsurge", "Starsurge"), target = "focustarget", kind = "harm", fallback = true, assist = true,
    mode = "both" },
  Enemy("Maim", "Stun, keep auto attacking", G("Maim", "Maim"), { startattack = true }),
  -- Retail Wild Charge changes target with the form (ally in caster form): not an enemy-only macro.
  Enemy("Charge", "Feral Charge (Bear or Cat Form)", G("Feral Charge", nil, "Feral Charge")),
  Enemy("Mass Entangle", "Root a group", G(nil, "Mass Entanglement")),
  Cursor("Ursol's Vortex", "Ursol's Vortex at your cursor", G(nil, "Ursol's Vortex")),
  Self("Faerie Fire", "Reveal stealth under your mouse", G("Faerie Fire", nil, "Faerie Fire"),
    { target = "mouseover", kind = "harm", fallback = true }),
  Self("Cat Form", "Powershift: Cat Form without toggling it off", "Cat Form", { force = true }),
  Self("Bear Form", "Bear Form without toggling it off", G("Bear Form", "Bear Form", "Dire Bear Form"), { force = true }),
  Self("Prowl", "Prowl without toggling it off", "Prowl", { force = true }),
  Self("Barkskin", "Barkskin", "Barkskin"),
  Ally("Innervate", "Innervate", "Innervate"),
  Ally("Decurse", "Remove Corruption / Remove Curse", G("Remove Corruption", "Remove Corruption", "Remove Curse")),
  Ally("Nature's Cure", "Restoration: dispel an ally", G(nil, "Nature's Cure")),
  Ally("Abolish Poison", "Remove poisons", G(nil, nil, "Abolish Poison")),
  Ally("Rejuvenation", "Rejuvenation", "Rejuvenation"),
  Raw("NS Heal", "Nature's Swiftness, then an instant big heal",
    G(Swift("Healing Touch"), Swift("Regrowth"), Swift("Healing Touch")),
    { needs = { "Nature's Swiftness", G("Healing Touch", "Regrowth", "Healing Touch") } }),
})

Macros.Add("MONK", {
  Enemy("Spear Hand", "Interrupt", "Spear Hand Strike"),
  Enemy("Paralysis", "Incapacitate", "Paralysis"),
  Self("Leg Sweep", "Stun around you", "Leg Sweep"),
  Ally("Tiger's Lust", "Remove roots and snares", "Tiger's Lust"),
  Ally("Detox", "Dispel an ally", "Detox"),
  Ally("Life Cocoon", "Absorb shield", "Life Cocoon"),
  Ally("Vivify", "Heal", "Vivify"),
  Cursor("Ring of Peace", "Ring of Peace at your cursor", "Ring of Peace"),
})

Macros.Add("DEMONHUNTER", {
  Enemy("Disrupt", "Interrupt", "Disrupt"),
  Enemy("Imprison", "Incapacitate", "Imprison"),
  Enemy("Consume Magic", "Remove a buff", "Consume Magic"),
  Cursor("Sigil Misery", "Sigil of Misery at your cursor", "Sigil of Misery"),
  Cursor("Sigil Silence", "Sigil of Silence at your cursor", "Sigil of Silence"),
  Cursor("Metamorphosis", "Havoc: Metamorphosis leap to your cursor", "Metamorphosis"),
})

Macros.Add("EVOKER", {
  Enemy("Quell", "Interrupt", "Quell"),
  Enemy("Sleep Walk", "Sleep", "Sleep Walk"),
  Ally("Rescue", "Fly an ally to safety", "Rescue", { self = false }),
  Ally("Naturalize", "Preservation: dispel an ally", "Naturalize"),
  Ally("Cauterizing", "Remove bleeds and poisons", "Cauterizing Flame"),
  Ally("Verdant Embrace", "Fly to an ally and heal, or heal yourself", "Verdant Embrace"),
  Self("Living Flame", "Heal an ally or hit an enemy under your mouse", "Living Flame",
    { target = "mouseover", kind = "any", fallback = true }),
})
