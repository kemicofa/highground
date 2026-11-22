local _, ns = ...
local Locale, Localization = ns.Macros.Host.Messages, ns.Macros.Host.Localization
local Macros = ns.Macros

-- Script presets: /run and /click for vendors, quests and other chores.
-- Flagged script = true; the scriptMacros switch hides them all
-- (Macros.Allowed). Retail and WoW Forever use the current API; Cataclysm,
-- Classic Era and The Burning Crusade the older one. Classic falls back to
-- forever, so per-game bodies name it.

local Host = Macros.Host
local Scripts = {}
Macros.Scripts = Scripts
local GAMES = { "cata", "retail", "forever", "classic", "tbc" }

-- Retail and WoW Forever: the current merchant and gossip API.
local function New(game) return game == "retail" or game == "forever" end

-- One body per game from a builder: { cata = f("cata"), ... }.
local function PerGame(f)
  local t = {}
  for _, g in ipairs(GAMES) do t[g] = f(g) end
  return t
end

-- A name typed by the player, safe inside "...": no quotes, backslashes or
-- control characters. nil when nothing is left.
function Scripts.Clean(s)
  s = Host.Trim((tostring(s or ""):gsub('["\\%c]', "")))
  return s ~= "" and s or nil
end

-- A whole number from 1 to 9999 (default 1).
local function Count(n)
  n = math.floor(tonumber(n) or 1)
  return n >= 1 and math.min(n, 9999) or 1
end

-- Sell grey items: C_Container on newer classic clients, globals on older.
local SELL_OLD = "/run if not MerchantFrame:IsShown() then return end local C=C_Container or _G for b=0,4 do for s=1,C.GetContainerNumSlots(b) do local l=C.GetContainerItemLink(b,s) if l and select(3,GetItemInfo(l))==0 then C.UseContainerItem(b,s) end end end"
local SELL_NEW = "/run C_MerchantFrame.SellAllJunkItems()"
function Scripts.SellJunk(game) return New(game or Host.Game()) and SELL_NEW or SELL_OLD end

-- Gossip option n, in the order the gossip window lists them. Classic
-- clients: sorted when options have orderIndex; SelectOption takes an index
-- where options carry no ID.
function Scripts.Gossip(n, game)
  n = Count(n)
  if New(game or Host.Game()) then
    return string.format("/run local o=C_GossipInfo.GetOptions() table.sort(o,function(a,b) return "
      .. "a.orderIndex<b.orderIndex end) if o[%d] then C_GossipInfo.SelectOption(o[%d].gossipOptionID) end", n, n)
  end
  return string.format("/run local G=C_GossipInfo local o=G.GetOptions() "
    .. "if o[%d] and o[%d].orderIndex then table.sort(o,function(a,b) return a.orderIndex<b.orderIndex end) end "
    .. "if o[%d] then G.SelectOption(o[%d].gossipOptionID or %d) end", n, n, n, n, n)
end

-- Buy qty of the open vendor's item called name. Cataclysm and later buy
-- more than a stack in one call (since 4.1); Classic Era and The Burning
-- Crusade buy one stack at a time.
function Scripts.Buy(name, qty, game)
  name, qty, game = Scripts.Clean(name), Count(qty), game or Host.Game()
  if not name then return nil end
  if New(game) then
    return string.format("/run for i=1,GetMerchantNumItems() do local t=C_MerchantFrame.GetItemInfo(i) if t and t.name==\"%s\" then BuyMerchantItem(i,%d) end end", name, qty)
  end
  if game == "cata" or qty == 1 then
    return string.format("/run for i=1,GetMerchantNumItems() do if GetMerchantItemInfo(i)==\"%s\" then BuyMerchantItem(i,%d) end end", name, qty)
  end
  return string.format("/run for i=1,GetMerchantNumItems() do if GetMerchantItemInfo(i)==\"%s\" then local q,m=%d,math.max(GetMerchantItemMaxStack(i) or 1,1) while q>0 do BuyMerchantItem(i,math.min(q,m)) q=q-m end end end",
    name, qty)
end

-- Equipment sets: a slash command, no script needed. nil where the game has
-- no equipment manager (ACTIONS). ";" and a leading "[" would read as
-- macro options, so they go.
function Scripts.EquipSet(name, game)
  if not Scripts.Has("equipset", game) then return nil end
  name = Scripts.Clean((tostring(name or ""):gsub(";", ""):gsub("^%s*%[+", "")))
  return name and ("/equipset " .. name)
end

local REPAIR = "/run if CanMerchantRepair() then RepairAllItems() end"
local ACCEPT = "/run AcceptQuest()"
-- Press once to hand in, again to take the reward (only when there is no choice to make).
local TURN_IN = "/run if QuestFrameRewardPanel:IsShown() then local n=GetNumQuestChoices() if n<2 then GetQuestReward(n) end else CompleteQuest() end"
local NEXT_PAGE = "/click MerchantNextPageButton"

-- Build tab script actions (macros/BuildPanel.lua). name / count: the
-- fields it takes; line(name, count, game) -> text or nil.
Scripts.ACTIONS = {
  Localization.Define({ key = "none", label = Locale:Get("macros.buildoptions.nothing.448194") }, { label = "macros.buildoptions.nothing.448194" }),
  Localization.Define({ key = "buy", label = Locale:Get("macros.scripts.buy_item.e93509"),
    line = function(name, count, game) return Scripts.Buy(name, count, game) end }, { label = "macros.scripts.buy_item.e93509", name = "shared.copy.item_name.18fcf2", count = "shared.copy.qty.ea99a8" }),
  Localization.Define({ key = "gossip", label = Locale:Get("macros.scripts.gossip_option.4631d0"),
    line = function(_, count, game) return Scripts.Gossip(count, game) end }, { label = "macros.scripts.gossip_option.4631d0", count = "shared.copy.no.f71bdc" }),
  Localization.Define({ key = "equipset", label = Locale:Get("macros.scripts.equip_set.26f831"),
    line = function(name, _, game) return Scripts.EquipSet(name, game) end,
    games = { classic = false, tbc = false } }, { label = "macros.scripts.equip_set.26f831", name = "shared.copy.set_name.3ebcc5" }),
  Localization.Define({ key = "repair", label = Locale:Get("macros.scripts.repair.5f60b1"), line = function() return REPAIR end }, { label = "macros.scripts.repair.5f60b1" }),
  Localization.Define({ key = "selljunk", label = Locale:Get("macros.scripts.sell_junk.06a779"), line = function(_, _, game) return Scripts.SellJunk(game) end }, { label = "macros.scripts.sell_junk.06a779" }),
  Localization.Define({ key = "nextpage", label = Locale:Get("macros.scripts.next_page.4bfc19"), line = function() return NEXT_PAGE end }, { label = "macros.scripts.next_page.4bfc19" }),
  Localization.Define({ key = "accept", label = Locale:Get("macros.scripts.accept_quest.3cc629"), line = function() return ACCEPT end }, { label = "macros.scripts.accept_quest.3cc629" }),
  Localization.Define({ key = "turnin", label = Locale:Get("macros.scripts.turn_in_quest.b0ca97"), line = function() return TURN_IN end }, { label = "macros.scripts.turn_in_quest.b0ca97" }),
}
local BY_KEY = {}
for _, a in ipairs(Scripts.ACTIONS) do BY_KEY[a.key] = a end
function Scripts.Action(key) return BY_KEY[key] end
-- Whether the game has the action.
function Scripts.Has(key, game)
  local a = BY_KEY[key]
  return a ~= nil and not (a.games and a.games[game or Host.Game()] == false)
end

-- { key, label } of the actions this game has, for Kit.Select.
function Scripts.Choices(game)
  game = game or Host.Game()
  local list = {}
  for _, a in ipairs(Scripts.ACTIONS) do
    if Scripts.Has(a.key, game) then list[#list + 1] = { key = a.key, label = a.label } end
  end
  return list
end

-- The script line of the form's scriptAction, scriptName and scriptCount,
-- or nil. Pure.
function Scripts.ForForm(form, game)
  local a = BY_KEY[form.scriptAction or "none"]
  if not (a and a.line and Scripts.Has(a.key, game)) then return nil end
  return a.line(form.scriptName, form.scriptCount, game or Host.Game())
end

local SCRIPTS = {
  Localization.Define({ name = "Repair", desc = Locale:Get("macros.scripts.repair_all_your_gear_at_a_vendor.522cb6"),
    lines = REPAIR }, { desc = "macros.scripts.repair_all_your_gear_at_a_vendor.522cb6" }),
  -- No guild banks in vanilla content.
  Localization.Define({ name = "Guild Repair", desc = Locale:Get("macros.scripts.repair_all_your_gear_with_guild_bank.e574e8"),
    lines = "/run if CanMerchantRepair() and CanGuildBankRepair() then RepairAllItems(1) end",
    games = { cata = true, retail = true, tbc = true, forever = false } }, { desc = "macros.scripts.repair_all_your_gear_with_guild_bank.e574e8" }),
  Localization.Define({ name = "Sell Junk", desc = Locale:Get("macros.scripts.sell_every_grey_item_in_your_bags.ef70e8"),
    lines = PerGame(Scripts.SellJunk) }, { desc = "macros.scripts.sell_every_grey_item_in_your_bags.ef70e8" }),
  Localization.Define({ name = "Next Page", desc = Locale:Get("macros.scripts.turn_the_vendor_window_to_its_next.c8fd82"),
    lines = NEXT_PAGE }, { desc = "macros.scripts.turn_the_vendor_window_to_its_next.c8fd82" }),
  Localization.Define({ name = "Gossip 1", desc = Locale:Get("macros.scripts.pick_the_first_dialogue_option_of_an.31c6c5"),
    lines = PerGame(function(g) return Scripts.Gossip(1, g) end) }, { desc = "macros.scripts.pick_the_first_dialogue_option_of_an.31c6c5" }),
  Localization.Define({ name = "Accept Quest", desc = Locale:Get("macros.scripts.accept_the_quest_the_quest_window_shows.6b15e9"), lines = ACCEPT }, { desc = "macros.scripts.accept_the_quest_the_quest_window_shows.6b15e9" }),
  Localization.Define({ name = "Turn In Quest", desc = Locale:Get("macros.scripts.hand_in_the_open_quest_take_a.615c0a"),
    lines = TURN_IN }, { desc = "macros.scripts.hand_in_the_open_quest_take_a.615c0a" }),
  Localization.Define({ name = "Random Mount", desc = Locale:Get("macros.scripts.summon_a_random_favourite_mount.eedc86"),
    lines = "/run C_MountJournal.SummonByID(0)",
    games = { retail = true, forever = true, classic = false, tbc = false } }, { desc = "macros.scripts.summon_a_random_favourite_mount.eedc86" }),
  Localization.Define({ name = "Leave Battle", desc = Locale:Get("macros.scripts.leave_the_battleground_or_arena_you_are.b41047"), lines = "/run LeaveBattlefield()" }, { desc = "macros.scripts.leave_the_battleground_or_arena_you_are.b41047" }),
  -- Template: put any cast after the /run line to hide its error sound and red
  -- text; sound effects go back to the player's setting next frame.
  Localization.Define({ name = "Quiet Trinket 1",
    lines = "#showtooltip 13\n/run local v=GetCVar(\"Sound_EnableSFX\") SetCVar(\"Sound_EnableSFX\",0) C_Timer.After(0,function() UIErrorsFrame:Clear() SetCVar(\"Sound_EnableSFX\",v) end)\n/use 13" }, { desc = "macros.scripts.quiet_trinket_description" }),
}
for _, entry in ipairs(SCRIPTS) do entry.script = true end
Macros.Add(nil, SCRIPTS, "both")
