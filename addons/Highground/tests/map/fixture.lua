-- Run from the addon directory: luajit tests/map_test.lua
-- Loads the complete map module with client APIs stubbed at its boundary.
local root = arg[1] or "."
local key = "Enemy-Realm"
local checks = 0
local function check(condition, message)
  assert(condition, message)
  checks = checks + 1
end

local function client(options)
  options = options or {}
  local state = {
    now = 100, active = true, mapID = 1460, area = "Silverwing Hold", db = {},
    positions = { player = { x = 0.1, y = 0.1 } }, worldPositions = {}, pois = {}, flags = {}, frames = {}, messages = {},
  }
  local enemy = { key = key, display = "Enemy", class = "MAGE", unit = options.unit }
  local ns = {
    GetDB = function() return state.db end,
    IsActive = function() return state.active end,
    GetBG = function() return state.bg end,
    GetBGRules = function() return state.bg.rules end,
    enemies = { [key] = enemy },
    MapPins = { Add = function(fn) state.layer = fn end, stats = { draws = 0, pins = 0 }, Providers = function() return 0 end },
    Core = { On = function(option) return not (state.db and state.db[option] == false) end },
    CanonUnit = function(unit) return unit == "party1target" and key or nil end,
  }
  for _, path in ipairs({ "libs/config/Theme.lua", "libs/ui/Theme.lua", "features/battlegrounds/config/Shared.lua", "features/battlegrounds/config/cata/Classes.lua", "features/battlegrounds/config/Battlegrounds.lua",
    "features/battlegrounds/config/battlegrounds/WarsongGulch.lua", "features/battlegrounds/config/battlegrounds/TwinPeaks.lua",
    "features/battlegrounds/config/battlegrounds/ArathiBasin.lua", "features/battlegrounds/config/battlegrounds/BattleForGilneas.lua", "features/battlegrounds/rules/Combat.lua" }) do
    assert(loadfile(root .. "/" .. path))("Highground", ns)
  end
  state.bg = assert(ns.ResolveBattleground(1460, 489, "cata", "standard"))
  local env = setmetatable({}, { __index = _G })
  env._G = env
  env.RAID_CLASS_COLORS = { MAGE = { r = 0.3, g = 0.8, b = 1 }, PALADIN = { r = 1, g = 0.5, b = 0.7 } }
  env.LOCALIZED_CLASS_NAMES_MALE = { MAGE = "Mage", PALADIN = "Paladin" }
  env.wipe = function(t) for k in pairs(t) do t[k] = nil end end
  env.CreateFrame = function()
    local f = { scripts = {} }
    function f:SetScript(name, fn) self.scripts[name] = fn end
    function f:RegisterEvent() end
    state.frames[#state.frames + 1] = f
    return f
  end
  env.UnitName = function(unit)
    return unit == "player" and "Me" or unit == "party1" and "Ally" or "Enemy"
  end
  env.UnitFactionGroup = function() return "Alliance" end
  env.UnitIsDeadOrGhost = function(unit) return state.dead and state.dead[unit] or false end
  env.UnitInRange = function(unit)
    local near = state.inRange and state.inRange[unit]
    if near == nil then return false, false end
    return near, true
  end
  env.GetNumGroupMembers = function() return options.ally and 2 or 0 end
  env.IsInRaid = function() return false end
  env.IsInGroup = function() return state.group or false end
  env.LE_PARTY_CATEGORY_INSTANCE = 1
  env.GetTime = function() return state.now end
  env.GetSubZoneText = function() return state.area end
  env.GetInstanceInfo = function() return state.bg.name end
  env.date = function() return "test" end
  env.CreateVector2D = function(x, y)
    return { x = x, y = y, GetXY = function() return x, y end }
  end
  env.UnitPosition = function(unit)
    local pos = state.worldPositions[unit]
    if pos then return unpack(pos) end
  end
  env.C_Map = {
    GetBestMapForUnit = function() return state.mapID end,
    GetPlayerMapPosition = function(_, unit) return state.positions[unit] end,
    GetMapInfo = function() return { name = state.bg.name } end,
    GetWorldPosFromMapPos = function(_, pos)
      state.cornerCalls = (state.cornerCalls or 0) + 1
      if (state.cornerFailures or 0) > 0 then
        state.cornerFailures = state.cornerFailures - 1
        return nil
      end
      local p = state.projection
      if p then
        return p.instance, env.CreateVector2D(p.north + p.height * pos.y, p.west + p.width * pos.x)
      end
    end,
  }
  env.C_ChatInfo = { SendAddonMessage = function(prefix, message, channel)
    state.messages[#state.messages + 1] = { prefix = prefix, message = message, channel = channel }
  end }
  env.C_AreaPoiInfo = {
    GetAreaPOIForMap = function()
      local ids = {}; for i in ipairs(state.pois) do ids[#ids + 1] = i end; return ids
    end,
    GetAreaPOIInfo = function(_, id)
      if state.poiError then error("landmarks not ready") end
      return state.pois[id]
    end,
  }
  env.C_Timer = { After = function(_, callback) callback() end }
  env.C_UnitAuras = { GetAuraDataByIndex = function(unit, index)
    if unit == "player" and index == 1 and state.flagAura then return { spellId = state.flagAura } end
  end }
  env.C_DeathInfo = { GetDeathReleasePosition = function() return state.releasePosition end }
  env.GetNumBattlefieldFlagPositions = function() return #state.flags end
  env.GetBattlefieldFlagPosition = function(index) return unpack(state.flags[index]) end
  env.CombatLogGetCurrentEventInfo = function() return unpack(state.event) end
  dofile("tests/support/load_modules.lua")("map", env, ns)
  local ticker = ns.Intel.ticker.frame
  local driver = ns.Intel.events
  state.tick = function() ticker.scripts.OnUpdate(ticker, 1) end
  state.combat = function(event, spellID, source)
    state.event = { state.now, event, false, "Player-Source", source or "Me", 0, 0,
      "Player-Enemy", key, 0, 0, spellID or 589 }
    driver.scripts.OnEvent(driver, "COMBAT_LOG_EVENT_UNFILTERED")
  end
  state.enterWorld = function() driver.scripts.OnEvent(driver, "PLAYER_ENTERING_WORLD") end
  state.poiUpdated = function() driver.scripts.OnEvent(driver, "AREA_POIS_UPDATED") end
  state.items = function(width, height) return state.layer(state.mapID, width, height) end
  state.receive = function(message)
    ns.Comms.frame.scripts.OnEvent(ns.Comms.frame, "CHAT_MSG_ADDON", "HighgroundI", message, "PARTY", "Ally-Realm")
  end
  state.flagPickup = function(message)
    driver.scripts.OnEvent(driver, "CHAT_MSG_BG_SYSTEM_HORDE", message)
  end
  state.nodeChat = function(message, event)
    driver.scripts.OnEvent(driver, event or "CHAT_MSG_BG_SYSTEM_HORDE", message)
  end
  return state, ns, enemy
end

local function tooltip(item)
  local lines = {}
  item.tooltip({ AddLine = function(_, text) lines[#lines + 1] = text end })
  return table.concat(lines, " "):lower()
end

local function checkUnknown(s, ns, message)
  local sight = ns.Test.intel[key]
  check(sight and sight.t == s.now and sight.x == nil and sight.y == nil and sight.how == "unknown", message)
  local items = s.items()
  check(#items == 1 and items[1].x == 0.05, "an unknown position must remain visible in the side column")
  local wording = (items[1].label or ""):lower() .. " " .. tooltip(items[1])
  check(wording:find("position unknown", 1, true), "the column pin must explain that its position is unknown")
end

return {
  key = key,
  check = check,
  client = client,
  tooltip = tooltip,
  checkUnknown = checkUnknown,
  count = function() return checks end,
}
