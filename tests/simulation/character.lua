-- Reproduce the Cata character pane's unchecked rune-duration formatting at
-- the Blizzard UI boundary. This fixture is not included in the addon.
-- Source behavior: Blizzard_CharacterFrame/Cata/PaperDollFrame.lua,
-- PaperDollFrame_SetRuneRegen and PaperDollFrame_UpdateStatCategory.
return function(sim)
  local env = sim.env
  sim.runeDuration, sim.runeReads, sim.runeUpdates, sim.otherStatUpdates = 8.627399, 0, 0, 0
  env.GetRuneCooldown = function(index)
    assert(index == 1)
    sim.runeReads = sim.runeReads + 1
    return sim.now, sim.runeDuration, true
  end
  function sim:loadCharacterFrame()
    local pane = env.CreateFrame("Frame", "CharacterStatsPane", env.UIParent)
    pane.unit = "player"
    pane:Hide()
    local row = env.CreateFrame("Frame", "CharacterStatsPaneRuneRegen", pane)
    row.Value = row:CreateFontString()
    local function updateRune(widget, unit)
      self.runeUpdates = self.runeUpdates + 1
      if unit ~= "player" or select(2, env.UnitClass(unit)) ~= "DEATHKNIGHT" then
        widget:Hide()
        return
      end
      local duration = select(2, env.GetRuneCooldown(1))
      widget.Value:SetText(string.format("%.2f sec", duration))
      widget.numericValue, widget.tooltip, widget.tooltip2 = duration, "Rune regeneration", "Rune cooldown"
      widget:Show()
    end
    self.originalRuneUpdater = updateRune
    env.PaperDollFrame_SetRuneRegen = updateRune
    env.PAPERDOLL_STATINFO = {
      RUNE_REGEN = { updateFunc = function(widget, unit) return env.PaperDollFrame_SetRuneRegen(widget, unit) end },
    }
    self.originalStatUpdater = env.PAPERDOLL_STATINFO.RUNE_REGEN.updateFunc
    local function updateStats()
      env.PAPERDOLL_STATINFO.RUNE_REGEN.updateFunc(row, pane.unit)
      self.otherStatUpdates = self.otherStatUpdates + 1
    end
    pane:SetScript("OnShow", updateStats)
    pane:RegisterEvent("UNIT_STATS")
    pane:SetScript("OnEvent", function()
      if pane:IsShown() then updateStats() end
    end)
    self.characterPane, self.runeRow = pane, row
    self:event("ADDON_LOADED", "Blizzard_CharacterFrame")
  end
end
