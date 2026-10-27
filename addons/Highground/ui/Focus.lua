local _, ns = ...
local Theme = ns.Theme

-- Private defensive badges on allies targeted by observed enemies. Targeting
-- is attention, not proof of damage. We never infer unseen enemy targets,
-- change raid icons, or parent/change protected nameplate frames.
local config = ns.FocusConfig
local ranked, markers, previous = {}, {}, {}
ns.Test = ns.Test or {}
ns.Test.enemyFocus = ranked
local preview = false

local Plain, Read = ns.Util.plain, ns.Util.read

local function DB()
  return ns.GetDB and ns.GetDB()
end

local function Supported()
  return config and config.clients[ns.CLIENT] == true
end

local function Key(unit)
  local value = Read(ns.CanonUnit, unit)
  return type(value) == "string" and value ~= "" and value or nil
end

local function Alive(unit)
  return Read(UnitExists, unit) == true and Read(UnitIsDeadOrGhost, unit) == false
    and (not UnitIsConnected or Read(UnitIsConnected, unit) == true)
end

---------------------------------------------------------------------------
-- Ranking: allies by how many observed enemies target them
---------------------------------------------------------------------------
local function Allies()
  local allies = {}
  local function add(unit)
    if not Alive(unit) then return end
    local key = Key(unit)
    if key and not allies[key] then
      allies[key] = { key = key, unit = unit, name = key:match("^[^-]+"), count = 0 }
    end
  end
  add("player")
  local n = Read(GetNumGroupMembers) or 0
  local raid = Read(IsInRaid) == true
  for i = 1, math.min(40, raid and n or math.max(0, n - 1)) do
    add((raid and "raid" or "party") .. i)
  end
  return allies
end

local function Limit(db)
  return math.max(1, math.min(config.limit, math.floor(tonumber(db.pressureCount) or config.limit)))
end

-- Fills `ranked` with up to `limit` allies, most targeted first; ties keep
-- the previous order so badges don't jump.
local function Collect(allies, limit)
  local counted = {}
  for key, enemy in pairs(ns.enemies or {}) do
    local unit = enemy.unit
    if unit and not enemy.dead and not counted[key] and Alive(unit)
      and Read(UnitIsPlayer, unit) == true and Key(unit) == key then
      counted[key] = true
      local target = unit .. "target"
      local allyKey = Alive(target) and Read(UnitIsPlayer, target) == true and Key(target)
      local ally = allyKey and allies[allyKey]
      if ally then ally.count = ally.count + 1 end
    end
  end
  wipe(ranked)
  for _, ally in pairs(allies) do
    if ally.count >= config.minimumEnemies then ranked[#ranked + 1] = ally end
  end
  table.sort(ranked, function(a, b)
    if a.count ~= b.count then return a.count > b.count end
    local pa, pb = previous[a.key] or math.huge, previous[b.key] or math.huge
    if pa ~= pb then return pa < pb end
    return a.key < b.key
  end)
  for i = #ranked, limit + 1, -1 do ranked[i] = nil end
  wipe(previous)
  for i, ally in ipairs(ranked) do previous[ally.key] = i end
end

---------------------------------------------------------------------------
-- Drawing: one badge per ranked ally, anchored to their nameplate
---------------------------------------------------------------------------
local FILL_ALPHA, EDGE_ALPHA, EDGE_ALPHA_SHOWN = 0.94, 0.65, 0.8

local function HideMarker(marker)
  marker:Hide()
  marker.anchor, marker.plateUnit = nil, nil
  marker:ClearAllPoints()
end

local function Clear()
  wipe(ranked)
  wipe(previous)
  for _, marker in pairs(markers) do HideMarker(marker) end
end

local function UsableFrame(frame)
  return frame and not (frame.IsForbidden and frame:IsForbidden())
    and frame.IsShown and frame:IsShown()
end

local function Plate(ally)
  local get = C_NamePlate and C_NamePlate.GetNamePlateForUnit
  if not get then return nil end
  -- Some nameplate addons/clients accept raid tokens; others require the
  -- actual nameplate token. Always verify the current identity before use.
  local plate = Read(get, ally.unit)
  if UsableFrame(plate) then
    local token = plate.namePlateUnitToken
    if Plain(token) and type(token) == "string" and Read(UnitIsPlayer, token) == true
      and Key(token) == ally.key then return plate, token end
  end
  for i = 1, 40 do
    local unit = "nameplate" .. i
    if Read(UnitExists, unit) == true and Read(UnitIsPlayer, unit) == true and Key(unit) == ally.key then
      plate = Read(get, unit)
      if UsableFrame(plate) then return plate, unit end
    end
  end
end

-- Backdrop colours (not Theme.Paint regions): set here and on theme change.
local function PaintBackdrop(marker)
  local edge = marker.color or config.color
  marker:SetBackdropColor(Theme.Color("hudBg", FILL_ALPHA))
  marker:SetBackdropBorderColor(edge[1], edge[2], edge[3], marker.color and EDGE_ALPHA_SHOWN or EDGE_ALPHA)
end
Theme.OnChange(function()
  for _, marker in pairs(markers) do PaintBackdrop(marker) end
end)

-- Outlined text with a black shadow: badges sit over the world.
local function Label(parent, role, color)
  return Theme.Shadow(Theme.Text(parent, role, color), "black")
end

local function MakeMarker(index)
  local marker = CreateFrame("Frame", "HighgroundPressure" .. index, UIParent, "BackdropTemplate")
  marker:SetSize(config.size, config.size)
  marker:SetFrameStrata("HIGH")
  marker:EnableMouse(false)
  marker:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
  PaintBackdrop(marker)
  marker.icon = marker:CreateTexture(nil, "ARTWORK")
  marker.icon:SetPoint("TOPLEFT", 3, -3)
  marker.icon:SetPoint("BOTTOMRIGHT", -3, 3)
  -- Blizzard's tank-role artwork is a shield and exists on the Cata client.
  -- Use the spell shield if a custom client lacks the role-texture helper.
  local ok, left, right, top, bottom = pcall(GetTexCoordsForRoleSmallCircle, "TANK")
  if ok and left and right and top and bottom then
    marker.icon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
    marker.icon:SetTexCoord(left, right, top, bottom)
  else
    marker.icon:SetTexture(config.fallbackTexture)
    marker.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
  marker.count = Label(marker, "badgeCount", "white")
  marker.count:SetPoint("CENTER")
  marker.label = Label(marker, "badgeLabel", config.color)
  marker.label:SetPoint("TOP", marker, "BOTTOM", 0, -2)
  marker:Hide()
  markers[index] = marker
  return marker
end

local function ShowMarker(index, ally, isPreview)
  local plate, unit = Plate(ally)
  local ownFrame = not plate and ally.unit == "player" and UsableFrame(PlayerFrame) and PlayerFrame
  local anchor = plate or ownFrame
  local marker = markers[index]
  if not anchor then
    if marker then HideMarker(marker) end
    return
  end
  marker = marker or MakeMarker(index)
  marker:ClearAllPoints()
  marker:SetClampedToScreen(ownFrame and true or false)
  local ok
  if ownFrame then
    ok = pcall(marker.SetPoint, marker, "RIGHT", anchor, "LEFT", -8, 0)
  else
    ok = pcall(marker.SetPoint, marker, "BOTTOM", anchor, "TOP", 0, config.offsetY)
  end
  if not ok then HideMarker(marker); return end
  marker.anchor, marker.plateUnit = anchor, unit
  marker.color = ally.count >= config.urgentCount and config.urgentColor or config.color
  PaintBackdrop(marker)
  Theme.Tint(marker.icon, marker.color)
  marker.count:SetText(ally.count)
  marker.label:SetText((isPreview and "TEST: " or "") .. ally.count .. " targeting")
  Theme.Paint(marker.label, marker.color)
  marker:Show()
end

---------------------------------------------------------------------------
-- Driver and command
---------------------------------------------------------------------------
local function Update()
  local db = DB()
  if not Supported() or not db or not ns.Core.On("pressure") then preview = false; Clear(); return end
  if not preview and not (ns.IsActive and ns.IsActive()) then Clear(); return end
  local allies = Allies()
  if preview then
    Clear()
    local ally = allies[Key("target") or ""] or allies[Key("player") or ""]
    if ally then ally.count = 4; ShowMarker(1, ally, true) end
    return
  end
  Collect(allies, Limit(db))
  for i, ally in ipairs(ranked) do ShowMarker(i, ally) end
  for i = #ranked + 1, config.limit do if markers[i] then HideMarker(markers[i]) end end
end

function ns.UpdatePressure()
  local ok, err = pcall(Update)
  if not ok then
    Clear()
    local db = DB()
    if db then db.pressureError = tostring(err) end
  end
end

function ns.PressureCommand(arg, say)
  if not Supported() then say("Enemy focus markers are available on Cata."); return end
  local db = DB()
  if not db then return end
  local sub, value = arg:match("^(%S*)%s*(.-)$")
  if sub == "on" or sub == "off" then
    db.pressure, preview = sub == "on", false
  elseif sub == "count" then
    local n = tonumber(value)
    if not n or n < 1 or n > config.limit or n ~= math.floor(n) then
      say("/hg pressure count 1-" .. config.limit); return
    end
    db.pressureCount = n
  elseif sub == "test" then
    db.pressure, preview = true, not preview
  elseif sub ~= "" and sub ~= "status" then
    say("/hg pressure [on|off|count 1-3|test]"); return
  end
  ns.UpdatePressure()
  if preview then
    say("Enemy focus preview: shield with 4 targeting. Target a teammate with a visible nameplate, or see your player frame.")
  else
    say("Enemy focus markers " .. (ns.Core.On("pressure") and "on" or "OFF") .. "; up to " .. Limit(db)
      .. " teammates. Counts use observed enemy targets. Friendly nameplates must be visible (Shift+V).")
    for _, ally in ipairs(ranked) do say(ally.name .. ": " .. ally.count .. " enemies targeting") end
  end
  if db.pressureError then say("Last marker error: " .. db.pressureError) end
end

local ticker = ns.Util.Every(config.updateSeconds, function() ns.UpdatePressure() end, "pressure")
local update = function() ns.UpdatePressure() end
ns.Util.Events({
  PLAYER_ENTERING_WORLD = function()
    preview, ticker.elapsed = false, 0
    Clear()
  end,
  NAME_PLATE_UNIT_REMOVED = function(_, unit)
    for _, marker in pairs(markers) do if marker.plateUnit == unit then HideMarker(marker) end end
  end,
  GROUP_ROSTER_UPDATE = update,
  UNIT_TARGET = update,
  NAME_PLATE_UNIT_ADDED = update,
}, "pressure")
