local _, ns = ...
local Core = ns.Core

-- Rows are secure buttons: left-click targets, right-click focuses. Blizzard
-- forbids changing their macro, position or visibility in combat, so each row
-- stays bound to one enemy until combat ends; only its visuals and rank number
-- update live. Visuals sit on a plain child frame so alpha changes stay legal.
Core.MAX_ROWS = 40 -- every enemy in the largest battlegrounds
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
  GameTooltip:AddLine(e.display, c and c.r or 1, c and c.g or 1, c and c.b or 1)
  local si = e.specID and Core.specInfo[e.specID]
  local cls = LOCALIZED_CLASS_NAMES_MALE[e.class] or e.class
  if si then
    GameTooltip:AddLine(ns.SpecLabel(e, si.name) .. " " .. cls .. (e.specSrc == "hist" and "  |cff888888(from history)|r" or ""),
      0.8, 0.8, 0.8)
    if e.specReason then
      GameTooltip:AddLine((e.specSrc == "cast" and "Identified from " or "Estimated from ") .. e.specReason, 1, 0.75, 0.35, true)
    end
  else
    GameTooltip:AddLine(cls .. "  |cff888888(spec unknown)|r", 0.8, 0.8, 0.8)
  end
  local where = ns.MapWhere and ns.MapWhere(e.key)
  if where then
    GameTooltip:AddLine("Location: " .. where, 0.55, 0.8, 1)
  end
  if e.cast then
    GameTooltip:AddLine(string.format("Casting %s%s", e.cast.name, e.cast.kickable and "" or " (can't be kicked)"),
      1, 0.82, 0.25)
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
    for _, d in ipairs(active) do
      GameTooltip:AddDoubleLine(Core.IconText(d[1], 16) .. " " .. d[1][4], "ACTIVE", 1, 0.78, 0.3, 1, 0.78, 0.3)
    end
    for _, d in ipairs(downs) do
      GameTooltip:AddDoubleLine(Core.IconText(d[1], 16) .. " " .. d[1][4], Core.Clock(d[2]), 0.3, 0.9, 0.45, 0.3, 0.9, 0.45)
    end
  end
  GameTooltip:AddLine("|cff66ff66Left|r target   |cff66ff66Right|r focus   |cff66ff66Shift|r call in chat", 0.7, 0.7, 0.7)
  GameTooltip:Show()
end

-- Keep an open tooltip current (called each render).
function Core.RefreshTooltip()
  local owner = GameTooltip:IsShown() and GameTooltip:GetOwner()
  if owner and owner.entry and (owner == Core.heroBtn or owner.wbRow) then
    Core.ShowTooltip(owner)
  end
end

-- "Target X, focus/mark it, then go back to your target": with NO target
-- before the click, /targetlasttarget has nothing to return to and leaves
-- you on the enemy. A secure snippet (allowed in combat) checks at click
-- time and ends the macro with /targetlasttarget or /cleartarget.
-- Buttons store the macro without its last line in "wb-<attribute>".
local restoreHeader = CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
local RESTORE_SNIPPET = [[
  local attr = (button == "RightButton") and "macrotext2" or "macrotext"
  local body = self:GetAttribute("wb-" .. attr)
  if body and body ~= "" then
    if UnitExists("target") then
      self:SetAttribute(attr, body .. "\n/targetlasttarget")
    else
      self:SetAttribute(attr, body .. "\n/cleartarget")
    end
  end
]]
function Core.WrapRestore(btn)
  if restoreHeader.WrapScript then
    pcall(restoreHeader.WrapScript, restoreHeader, btn, "OnClick", RESTORE_SNIPPET)
  end
end

-- Set a target-then-return macro: the fallback text (if the snippet can't
-- run) plus the body the snippet completes.
function Core.SetReturnMacro(btn, attr, body)
  btn:SetAttribute("wb-" .. attr, body or "")
  btn:SetAttribute(attr, body and (body .. "\n/targetlasttarget") or "")
end
