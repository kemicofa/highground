local _, ns = ...
local B, U = ns.Bounty, ns.Util
local P, G = B.Public, {}
B.Gold = G
local MAX_MONEY = 1000000000000

function G.Enabled() return ns.Core.O("bountyAccountGold") ~= false end
function G.Required() return ns.Core.O("bountyRequireGold") == true end

function G.Current()
  local n = U.value(U.call(GetMoney))
  return P.Integer(n, 0, MAX_MONEY) and n or nil
end

local function Characters()
  if not P.ready then return {} end
  P.db.gold = type(P.db.gold) == "table" and P.db.gold or {}
  P.db.gold.characters = type(P.db.gold.characters) == "table" and P.db.gold.characters or {}
  return P.db.gold.characters
end

function G.Identity()
  local guid = U.value(U.call(UnitGUID, "player"))
  local region = U.value(U.call(GetCurrentRegion)) or 0
  return (ns.GAME or ns.CLIENT) .. ":" .. tostring(region) .. ":" .. (type(guid) == "string" and guid or B.Me() or "unknown")
end

function G.Record()
  if not P.ready or not G.Enabled() then return end
  local money, name = G.Current(), B.Me()
  if money == nil or not name then return end
  local characters, key, scope = Characters(), G.Identity(), B.Scope.Key()
  -- A later readable GUID, rename or transfer must not count a character twice.
  for id, row in pairs(characters) do
    if type(row) == "table" and id ~= key and row.name == name and row.scope == scope then characters[id] = nil end
  end
  local _, class = U.call(UnitClass, "player")
  local row = { name = name, scope = scope, scopeLabel = B.Scope.Label(), balance = money,
    seenAt = P.Now(), class = U.value(class), faction = U.value(U.call(UnitFactionGroup, "player")),
    obligations = P.LegacyObligations and P.LegacyObligations() or {} }
  characters[key] = row
  return row
end

local function Valid(row)
  return type(row) == "table" and P.Name(row.name) and row.scope == B.Scope.Key()
    and P.Integer(row.balance, 0, MAX_MONEY) and P.Integer(row.seenAt, 1, P.Now() + 30)
end

function G.Rows()
  G.Record()
  local rows, current, found = {}, G.Identity(), false
  for id, row in pairs(Characters()) do
    if Valid(row) then
      local copy = P.Copy(row)
      copy.current = id == current
      if copy.current then copy.balance = G.Current(); found = true end
      rows[#rows + 1] = copy
    end
  end
  if B.Me() and not found then
    rows[#rows + 1] = { name = B.Me(), balance = G.Current(), seenAt = P.Now(), current = true }
  end
  table.sort(rows, function(a, b)
    if a.current ~= b.current then return a.current end
    return a.balance > b.balance or a.balance == b.balance and a.name < b.name
  end)
  return rows
end

function G.Total()
  local money = G.Current()
  if money == nil or not G.Enabled() then return money end
  G.Record()
  local current = G.Identity()
  for id, row in pairs(Characters()) do
    if id ~= current and Valid(row) then money = money + row.balance end
  end
  return money
end

function G.OtherHolds()
  if not G.Enabled() then return 0 end
  local total, current = 0, G.Identity()
  for id, row in pairs(Characters()) do
    if id ~= current and Valid(row) and type(row.obligations) == "table" then
      for _, hold in pairs(row.obligations) do
        if type(hold) == "table" and P.Integer(hold.copper, 0, MAX_MONEY)
          and P.Integer(hold.expiresAt, 0, 100000000000) and (hold.expiresAt == 0 or hold.expiresAt >= P.Now()) then
          total = total + hold.copper
        end
      end
    end
  end
  return total
end

-- Local obligations across factions share one wallet. Only the author may
-- advertise changes; account ownership does not grant wire authority.
function G.Offers()
  local out, seen = {}, {}
  local scope = B.Scope.Key()
  local prefix = ns.Caps.rulesetRealms and (scope .. ":")
    or ((ns.GAME or ns.CLIENT) .. ":" .. (ns.Core.myRealm or "") .. ":")
  local active = P.Data()
  for key, data in pairs(P.db and P.db.scopes or {}) do
    local matches = type(key) == "string" and key:sub(1, #prefix) == prefix
    if type(data) == "table" then
      for id, p in pairs(data.offers or {}) do
        if P.Mine(p) and not seen[id] and (G.Enabled() and (p.walletScope and p.walletScope == scope or not p.walletScope and matches)
          or not G.Enabled() and data == active and P.CanManage(p)) then
          seen[id] = true
          out[#out + 1] = { offer = p, data = data }
        end
      end
    end
  end
  return out
end

function G.Format(copper, tooltip)
  if copper == nil then return ns.Locale:Get("shared.gold.unavailable.2c9c1f") end
  local hex = tooltip and ns.Theme.TipHex or ns.Theme.Hex
  return ns.Locale:Format("shared.gold.value1_value2_g_r_value4_value5_s.250109", { value1 = hex("moneyGold"), value2 = math.floor(copper / 10000), value4 = hex("moneySilver"), value5 = math.floor(copper % 10000 / 100), value7 = hex("moneyCopper"), value8 = math.floor(copper % 100) })
end

function G.Refresh()
  G.Record()
  if P.ready then P.CheckFunds(false) end
  if B.Form and B.Form.win then B.Form.Refresh() end
  if B.GoldView and B.GoldView.win then B.GoldView.Refresh() end
  if not G.Enabled() and B.GoldTooltip and B.GoldTooltip.frame then B.GoldTooltip.frame:Hide() end
end

B.Listen("updated", G.Record)
B.Listen("publish", G.Record)
