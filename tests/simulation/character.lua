-- Reproduce the Cata character pane's unchecked stat formatting at the
-- Blizzard UI boundary. This fixture is not included in the addon.
-- Source behavior: Blizzard_CharacterFrame/Cata/PaperDollFrame.lua,
-- PaperDollFrame_SetRuneRegen, PaperDollFrame_Set{Melee,Ranged,Spell}HitChance
-- and PaperDollFrame_UpdateStatCategory.
local HIT_STATS = {
  { key = "HITCHANCE", renderer = "PaperDollFrame_SetMeleeHitChance", api = "GetHitModifier" },
  { key = "RANGED_HITCHANCE", renderer = "PaperDollFrame_SetRangedHitChance", api = "GetHitModifier" },
  { key = "SPELL_HITCHANCE", renderer = "PaperDollFrame_SetSpellHitChance", api = "GetSpellHitModifier" },
}

return function(sim)
  local env = sim.env
  sim.runeDuration, sim.runeReads, sim.runeUpdates, sim.otherStatUpdates = 8.627399, 0, 0, 0
  sim.hitModifier, sim.spellHitModifier, sim.hitUpdates = 1, 2, 0
  env.GetRuneCooldown = function(index)
    assert(index == 1)
    sim.runeReads = sim.runeReads + 1
    return sim.now, sim.runeDuration, true
  end
  env.GetCombatRatingBonus = function() return 0 end
  env.GetHitModifier = function() return sim.hitModifier end
  env.GetSpellHitModifier = function() return sim.spellHitModifier end
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
    local rows = { { key = "RUNE_REGEN", row = row } }
    self.hitRows, self.originalHitRenderers = {}, {}
    for _, stat in ipairs(HIT_STATS) do
      local hitRow = env.CreateFrame("Frame", "CharacterStatsPane" .. stat.key, pane)
      hitRow.Value = hitRow:CreateFontString()
      local function render(widget, unit)
        self.hitUpdates = self.hitUpdates + 1
        if unit ~= "player" then
          widget:Hide()
          return
        end
        local chance = env.GetCombatRatingBonus() + env[stat.api]()
        widget.Value:SetText(string.format("+%.2F%%", chance))
        widget.tooltip = "Hit Chance " .. chance
        widget:Show()
      end
      env[stat.renderer], self.originalHitRenderers[stat.renderer] = render, render
      env.PAPERDOLL_STATINFO[stat.key] = {
        updateFunc = function(widget, unit) env[stat.renderer](widget, unit) end,
      }
      self.hitRows[stat.key] = hitRow
      rows[#rows + 1] = { key = stat.key, row = hitRow }
    end
    local function updateStats()
      for _, entry in ipairs(rows) do
        env.PAPERDOLL_STATINFO[entry.key].updateFunc(entry.row, pane.unit)
      end
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
