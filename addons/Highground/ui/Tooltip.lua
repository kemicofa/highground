local _, ns = ...
local Core = ns.Core
local Theme = ns.Theme

-- r, g, b of a token on a tooltip line (no alpha).
local function RGB(name)
  local r, g, b = Theme.TipColor(name)
  return r, g, b
end

-- Rows are secure buttons: left-click targets, right-click focuses. Blizzard
-- forbids changing their macro, position or visibility in combat, so each row
-- stays bound to one enemy until combat ends; only its visuals and rank number
-- update live. Visuals sit on a plain child frame so alpha changes stay legal.
Core.rows = {}
Core.layoutPending = false

-- What the rows can't show: who the enemy is, where, what they're casting
-- and the big cooldowns they've used (icons with time left). Health, mana
-- and priority are already on the row; scores stay internal (Target
-- behavior > Refresh comparison). Rebuilt every tick while shown, so
-- cooldown timers count down live.
function Core.ShowTooltip(self)
  local e = self.entry
  if not e then
    return
  end
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  local c = ns.Util.ClassColor(e.class)
  if c then
    GameTooltip:AddLine(e.display, c.r, c.g, c.b)
  else
    GameTooltip:AddLine(e.display, RGB("text"))
  end
  local dim = Theme.TipHex("textDim")
  local si = e.specID and Core.specInfo[e.specID]
  local cls = ns.Util.ClassName(e.class)
  if si then
    GameTooltip:AddLine(ns.SpecLabel(e, si.name) .. " " .. cls .. (e.specSrc == "hist" and "  " .. dim .. "(from history)|r" or ""),
      RGB("textMuted"))
    if e.specReason then
      local r, g, b = RGB("warning")
      GameTooltip:AddLine((e.specSrc == "cast" and "Identified from " or "Estimated from ") .. e.specReason, r, g, b, true)
    end
  else
    GameTooltip:AddLine(cls .. "  " .. dim .. "(specialization unknown)|r", RGB("textMuted"))
  end
  local where = ns.MapWhere and ns.MapWhere(e.key)
  if where then
    GameTooltip:AddLine("Location: " .. where, RGB("info"))
  end
  if e.cast then
    GameTooltip:AddLine(string.format("Casting %s%s", e.cast.name, e.cast.kickable and "" or " (cannot be interrupted)"),
      RGB("gold"))
  end
  -- Cooldowns seen used: active first, then down. Ready or never seen
  -- used ones are left out.
  local active, downs = {}, {}
  for _, entry in ipairs(Core.KitFor(e)) do
    local left = Core.CdLeft(e, entry)
    if e.activeCooldowns and e.activeCooldowns[entry[1]] then
      active[#active + 1] = { entry, left }
    elseif left then
      downs[#downs + 1] = { entry, left }
    end
  end
  table.sort(downs, function(a, b) return a[2] < b[2] end)
  if #active + #downs > 0 then
    GameTooltip:AddLine(" ")
    local ar, ag, ab = RGB("warning")
    for _, d in ipairs(active) do
      GameTooltip:AddDoubleLine(Core.IconText(d[1], Theme.Size("icon")) .. " " .. d[1][4], "ACTIVE", ar, ag, ab, ar, ag, ab)
    end
    local dr, dg, db = RGB("success")
    for _, d in ipairs(downs) do
      GameTooltip:AddDoubleLine(Core.IconText(d[1], Theme.Size("icon")) .. " " .. d[1][4], Core.Clock(d[2]), dr, dg, db, dr, dg, db)
    end
  end
  local key = Theme.TipHex("success")
  GameTooltip:AddLine(key .. "Left|r target   " .. key .. "Right|r focus   " .. key .. "Shift|r call in chat", RGB("textMuted"))
  Theme.TipLine(GameTooltip, "Focus keeps a second target selected for abilities and tracking.", "textMuted", true)
  if self == Core.heroBtn and InCombatLockdown() then
    Theme.TipLine(GameTooltip, "This click stays on the displayed name until combat ends. A changed suggestion appears below; click its enemy row to switch.", "info", true)
  end
  GameTooltip:Show()
end

-- Keep an open tooltip current (called each render).
function Core.RefreshTooltip()
  local owner = GameTooltip:IsShown() and GameTooltip:GetOwner()
  if owner and owner.entry and (owner == Core.heroBtn or owner.wbRow) then
    Core.ShowTooltip(owner)
  end
end
