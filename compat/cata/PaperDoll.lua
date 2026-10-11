local ADDON, ns = ...
if ns.CLIENT ~= "cata" then return end

-- Several Cata PaperDollFrame stat renderers do arithmetic or formatting on
-- game API results without checking for nil. Some clients temporarily provide
-- no data (rune cooldowns, hit modifiers). Guard only those stats' dispatch
-- entries; keep game APIs and global renderers intact, and let Blizzard handle
-- the normal display and non-player cases.
local function finite(value)
  return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function probe(name, ...)
  local api = _G[name]
  if type(api) ~= "function" then return nil end
  local ok, a, b = pcall(api, ...)
  if ok then return a, b end
end

local function hitModifierReady() return finite((probe("GetHitModifier"))) end

-- Returns false when the stat's Blizzard renderer would fail for this unit.
local GUARDS = {
  RUNE_REGEN = function(unit)
    if select(2, UnitClass(unit)) ~= "DEATHKNIGHT" then return true end
    local _, duration = probe("GetRuneCooldown", 1)
    return finite(duration) and duration >= 0
  end,
  HITCHANCE = hitModifierReady,
  RANGED_HITCHANCE = hitModifierReady,
  SPELL_HITCHANCE = function() return finite((probe("GetSpellHitModifier"))) end,
}

local wrapped = setmetatable({}, { __mode = "k" })

local function Install()
  local stats = PAPERDOLL_STATINFO
  if type(stats) ~= "table" then return false end
  for key, ready in pairs(GUARDS) do
    local stat = stats[key]
    if type(stat) == "table" and type(stat.updateFunc) == "function" and not wrapped[stat.updateFunc] then
      local original = stat.updateFunc
      stat.updateFunc = function(frame, unit, ...)
        if unit == "player" and not ready(unit) then
          frame.numericValue, frame.tooltip, frame.tooltip2 = nil, nil, nil
          frame:Hide()
          return
        end
        return original(frame, unit, ...)
      end
      wrapped[stat.updateFunc] = true
    end
  end
  return true
end

-- The character UI may be present already or arrive as a load-on-demand addon.
if not Install() then
  local loader = CreateFrame("Frame")
  loader:RegisterEvent("ADDON_LOADED")
  loader:SetScript("OnEvent", function(self, _, name)
    if (name == ADDON or name == "Blizzard_CharacterFrame") and Install() then
      self:UnregisterEvent("ADDON_LOADED")
    end
  end)
end
