local _, ns = ...
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
local SELL_OLD = "/run if not MerchantFrame:IsShown() then return end local C=C_Container or _G for b=0,4 do "
  .. "for s=1,C.GetContainerNumSlots(b) do local l=C.GetContainerItemLink(b,s) "
  .. "if l and select(3,GetItemInfo(l))==0 then C.UseContainerItem(b,s) end end end"
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
    return string.format("/run for i=1,GetMerchantNumItems() do local t=C_MerchantFrame.GetItemInfo(i) "
      .. "if t and t.name==\"%s\" then BuyMerchantItem(i,%d) end end", name, qty)
  end
  if game == "cata" or qty == 1 then
    return string.format("/run for i=1,GetMerchantNumItems() do if GetMerchantItemInfo(i)==\"%s\" then "
      .. "BuyMerchantItem(i,%d) end end", name, qty)
  end
  return string.format("/run for i=1,GetMerchantNumItems() do if GetMerchantItemInfo(i)==\"%s\" then "
    .. "local q,m=%d,math.max(GetMerchantItemMaxStack(i) or 1,1) while q>0 do BuyMerchantItem(i,math.min(q,m)) q=q-m end end end",
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
local TURN_IN = "/run if QuestFrameRewardPanel:IsShown() then local n=GetNumQuestChoices() "
  .. "if n<2 then GetQuestReward(n) end else CompleteQuest() end"
local NEXT_PAGE = "/click MerchantNextPageButton"

-- Build tab script actions (macros/BuildPanel.lua). name / count: the
-- fields it takes; line(name, count, game) -> text or nil.
Scripts.ACTIONS = {
  { key = "none", label = "Nothing" },
  { key = "buy", label = "Buy item", name = "ITEM NAME", count = "QTY",
    line = function(name, count, game) return Scripts.Buy(name, count, game) end },
  { key = "gossip", label = "Gossip option", count = "NO.",
    line = function(_, count, game) return Scripts.Gossip(count, game) end },
  { key = "equipset", label = "Equip set", name = "SET NAME",
    line = function(name, _, game) return Scripts.EquipSet(name, game) end,
    games = { classic = false, tbc = false } },
  { key = "repair", label = "Repair", line = function() return REPAIR end },
  { key = "selljunk", label = "Sell junk", line = function(_, _, game) return Scripts.SellJunk(game) end },
  { key = "nextpage", label = "Next page", line = function() return NEXT_PAGE end },
  { key = "accept", label = "Accept quest", line = function() return ACCEPT end },
  { key = "turnin", label = "Turn in quest", line = function() return TURN_IN end },
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
  { name = "Repair", desc = "Repair all your gear at a vendor that repairs",
    lines = REPAIR },
  -- No guild banks in vanilla content.
  { name = "Guild Repair", desc = "Repair all your gear with guild bank money",
    lines = "/run if CanMerchantRepair() and CanGuildBankRepair() then RepairAllItems(1) end",
    games = { cata = true, retail = true, tbc = true, forever = false } },
  { name = "Sell Junk", desc = "Sell every grey item in your bags to the open vendor",
    lines = PerGame(Scripts.SellJunk) },
  { name = "Next Page", desc = "Turn the vendor window to its next page",
    lines = NEXT_PAGE },
  { name = "Gossip 1", desc = "Pick the first option an NPC offers when you talk to them",
    lines = PerGame(function(g) return Scripts.Gossip(1, g) end) },
  { name = "Accept Quest", desc = "Accept the quest the quest window shows", lines = ACCEPT },
  { name = "Turn In Quest", desc = "Hand in the open quest, then take its reward when there is no choice",
    lines = TURN_IN },
  { name = "Random Mount", desc = "Summon a random favourite mount",
    lines = "/run C_MountJournal.SummonByID(0)",
    games = { retail = true, forever = true, classic = false, tbc = false } },
  { name = "Leave Battle", desc = "Leave the battleground or arena you are in", lines = "/run LeaveBattlefield()" },
  -- Template: put any cast after the /run line to hide its error sound and red
  -- text; sound effects go back to the player's setting next frame.
  { name = "Quiet Trinket 1", desc = "Top trinket without the error sound or red text; put any cast after the /run line",
    lines = "#showtooltip 13\n/run local v=GetCVar(\"Sound_EnableSFX\") SetCVar(\"Sound_EnableSFX\",0) "
      .. "C_Timer.After(0,function() UIErrorsFrame:Clear() SetCVar(\"Sound_EnableSFX\",v) end)\n/use 13" },
}
for _, entry in ipairs(SCRIPTS) do entry.script = true end
Macros.Add(nil, SCRIPTS, "both")
