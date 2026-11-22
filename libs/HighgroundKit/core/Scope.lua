local _, ns = ...
local U, S = ns.Util, {}
ns.Scope = S

-- Shared game/region and economy boundaries. Features own their saved data.
function S.Region()
  return (ns.GAME or ns.CLIENT) .. ":" .. tostring(U.read(GetCurrentRegion) or 0)
end

function S.Ruleset()
  if not ns.Caps.rulesetRealms then return end
  local rules = Enum and Enum.GameRule
  local query = C_GameRules and C_GameRules.IsGameRuleActive
  if not (rules and query and rules.HardcoreRuleset and rules.RPRuleset and rules.PvPRuleset) then return end
  local hardcore, rp, pvp = U.read(query, rules.HardcoreRuleset), U.read(query, rules.RPRuleset), U.read(query, rules.PvPRuleset)
  if type(hardcore) ~= "boolean" or type(rp) ~= "boolean" or type(pvp) ~= "boolean" then return end
  return hardcore and "Hardcore" or rp and (pvp and "RP-PvP" or "RP") or pvp and "PvP" or "PvE"
end

-- Forever custom channels span rulesets. Never guess a channel while the
-- rules are unavailable, and use letters only for the RP-PvP suffix.
function S.Channel(base)
  if not ns.Caps.rulesetRealms then return base end
  local rule = S.Ruleset()
  return rule and base .. (rule == "RP-PvP" and "RPPvP" or rule) or nil
end

function S.Key()
  local rule = S.Ruleset()
  return S.Region() .. ":" .. (rule and "ruleset:" or "realm:") .. (rule or ns.Core.myRealm or "")
end

function S.Label()
  return S.Ruleset() or (ns.Caps.hideRealmNames and "Current realmset") or ns.Core.myRealm or "Current realm"
end

-- Native communities span realms. Forever still separates its rulesets.
function S.Social() return ns.Caps.rulesetRealms and S.Key() or S.Region() end

function S.Faction()
  return S.Key() .. ":" .. (U.read(UnitFactionGroup, "player") or "Unknown")
end

-- A GUID distinguishes a recreated character with the same name. Keep the
-- ruleset and native faction even when a character retains its GUID there.
function S.Character()
  local who = U.read(UnitGUID, "player") or ns.Core.CanonUnit("player")
  if type(who) == "string" and who ~= "" then return S.Faction() .. ":" .. who end
end

-- Learned mechanics can be reused by other characters and factions, but
-- not by another game or Forever ruleset. They do not depend on a realm.
function S.Rules()
  return ns.Caps.rulesetRealms and S.Key() or (ns.GAME or ns.CLIENT)
end

local keys = { character = S.Character, faction = S.Faction, realm = S.Key,
  social = S.Social, rules = S.Rules, account = S.Region }

-- Realm and ruleset keys are unknown until one of them can be read.
local function Located(kind)
  if kind == "account" or not ns.Caps.rulesetRealms and (kind == "social" or kind == "rules") then return true end
  return (ns.Core.myRealm or "") ~= "" or S.Ruleset() ~= nil
end

-- Writes made before the saved table or the scope key exists wait here,
-- per saved table (false: the default one) and kind. The first store that
-- resolves takes them over; newer pending values win, tables merge.
local pending = {}
local function Pending(db, kind)
  local slot = db or false
  pending[slot] = pending[slot] or {}
  pending[slot][kind] = pending[slot][kind] or {}
  return pending[slot][kind]
end
local function Merge(into, from)
  for key, value in pairs(from) do
    if type(value) == "table" and type(into[key]) == "table" then Merge(into[key], value) else into[key] = value end
  end
end
local function Adopt(slot, kind, store)
  local waiting = pending[slot] and pending[slot][kind]
  if not waiting then return end
  pending[slot][kind] = nil
  if next(pending[slot]) == nil then pending[slot] = nil end
  Merge(store, waiting)
end

local function Resolve(kind, db, key)
  local all = ns.Saved.Table(ns.Saved.Table(db, "scoped"), kind)
  -- A missing or damaged record adopts the pre-GUID record for this name.
  if kind == "character" and type(all[key]) ~= "table" then
    local name = ns.Core.CanonUnit("player")
    local fallback = name and S.Faction() .. ":" .. name
    if fallback and fallback ~= key and type(all[fallback]) == "table" then
      all[key], all[fallback] = all[fallback], nil
    end
  end
  return ns.Saved.Table(all, key)
end

function S.Store(kind, db)
  db = db or ns.Core.db
  local key = keys[kind]()
  if not db or not key or not Located(kind) then return Pending(db, kind) end
  local store = Resolve(kind, db, key)
  if next(pending) ~= nil then -- the default slot key is false
    Adopt(db, kind, store)
    if db == ns.Core.db then Adopt(false, kind, store) end
  end
  return store
end

-- Unattributed legacy fields are deliberately left intact. Reading a new
-- scope must never adopt another character's old account-wide records.
function S.Saved(name, kind, db)
  local store = S.Store(kind, db)
  store[name] = type(store[name]) == "table" and store[name] or {}
  return store[name]
end

local listeners = {}
function S.Listen(fn) listeners[#listeners + 1] = fn end
function S.Check()
  ns.Core.myRealm = U.read(GetNormalizedRealmName) or ns.Core.myRealm
  local key = S.Character()
  if key == S.current then return false end
  local previous = S.current
  S.current = key
  if not previous then return false end
  for _, fn in ipairs(listeners) do U.Guard("data scope", fn, previous, key) end
  return true
end

-- Retire dialogs and their return paths before another scope can use them.
function S.Close(window)
  if not window then return end
  window.undoAction, window.entry, window.selected = nil, nil, nil
  if ns.Kit and ns.Kit.Windows then
    ns.Kit.Windows.Forget(window)
    ns.Kit.Windows.Close(window)
  else window:Hide() end
end

U.Events({ PLAYER_LOGIN = S.Check, PLAYER_ENTERING_WORLD = S.Check,
  UNIT_FACTION = function(_, unit) if unit == "player" then S.Check() end end,
}, "data scope")
