local ADDON, ns = ...
if ns.CLIENT ~= "cata" then return end

-- Cata's PaperDollFrame_SetRuneRegen formats GetRuneCooldown(1)'s duration
-- without checking for nil. Some clients temporarily provide no rune data.
-- Guard only that stat's dispatch entry; keep game APIs and global renderers
-- intact, and let Blizzard handle the normal display and non-player cases.
local function Install()
  local stat = PAPERDOLL_STATINFO and PAPERDOLL_STATINFO.RUNE_REGEN
  if not stat or type(stat.updateFunc) ~= "function" then return false end
  local original = stat.updateFunc
  stat.updateFunc = function(frame, unit, ...)
    if unit == "player" and select(2, UnitClass(unit)) == "DEATHKNIGHT" then
      local duration
      if type(GetRuneCooldown) == "function" then
        local ok, _, value = pcall(GetRuneCooldown, 1)
        if ok then duration = value end
      end
      if type(duration) ~= "number" or duration ~= duration or duration < 0 or duration == math.huge then
        frame.numericValue, frame.tooltip, frame.tooltip2 = nil, nil, nil
        frame:Hide()
        return
      end
    end
    return original(frame, unit, ...)
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
