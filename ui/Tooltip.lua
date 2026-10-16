local _, ns = ...
local Core = ns.Core

-- Rows are secure buttons: left-click targets, right-click focuses. Blizzard
-- forbids changing their macro, position or visibility in combat, so each row
-- stays bound to one enemy until combat ends; only its visuals and rank number
-- update live. Visuals sit on a plain child frame so alpha changes stay legal.
Core.MAX_ROWS = 40 -- every enemy in the largest battlegrounds
Core.rows = {}
Core.layoutPending = false

function Core.ShowTooltip(self)
  local e = self.entry
  if not e then
    return
  end
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  local c = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[e.class]
  GameTooltip:AddDoubleLine(e.display, string.format("%.0f  |cff888888live %.0f|r", e.base or 0, e.live or 0), c and c.r or 1, c and c.g or 1,
    c and c.b or 1, Core.ACCENT[1], Core.ACCENT[2], Core.ACCENT[3])
  local si = e.specID and Core.specInfo[e.specID]
  local cls = LOCALIZED_CLASS_NAMES_MALE[e.class] or e.class
  if si then
    GameTooltip:AddLine(ns.SpecLabel(e, si.name) .. " " .. cls .. (e.specSrc == "hist" and "  |cff888888(from history)|r" or ""),
      0.8, 0.8, 0.8)
    if e.specReason then
      GameTooltip:AddLine((e.specSrc == "cast" and "Identified from " or "Estimated from ") .. e.specReason
        .. "; scoreboard data takes priority.", 1, 0.75, 0.35, true)
    end
  else
    GameTooltip:AddLine(cls .. "  |cff888888(spec hidden: ranked by class)|r", 0.8, 0.8, 0.8)
  end
  if e.note then
    GameTooltip:AddLine(e.note, 0.6, 0.85, 1, true)
  end
  local where = ns.MapWhere and ns.MapWhere(e.key)
  if where then
    GameTooltip:AddLine("Location: " .. where, 0.55, 0.8, 1)
  end
  if e.cast then
    GameTooltip:AddLine(string.format("Casting %s%s", e.cast.name, e.cast.kickable and "" or " (can't be kicked)"),
      1, 0.82, 0.25)
  end
  -- Class breakdown: down (seen used) first, green = opportunity.
  local kit = Core.KitFor(e)
  if #kit > 0 then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Cooldowns (combat log)", 0.55, 0.56, 0.62)
    local active, downs, ready = {}, {}, {}
    for _, entry in ipairs(kit) do
      local left = Core.CdLeft(e, entry)
      if e.activeCooldowns and e.activeCooldowns[entry[1]] then
        active[#active + 1] = { entry, left }
      elseif left then
        downs[#downs + 1] = { entry, left }
      else
        ready[#ready + 1] = entry
      end
    end
    for _, d in ipairs(active) do
      GameTooltip:AddDoubleLine(d[1][4], "ACTIVE" .. (d[2] and (" · cooldown " .. Core.Clock(d[2])) or ""),
        1, 0.78, 0.3, 1, 0.78, 0.3)
    end
    for _, d in ipairs(downs) do
      GameTooltip:AddDoubleLine(d[1][4], "DOWN " .. Core.Clock(d[2]), 0.3, 0.9, 0.45, 0.3, 0.9, 0.45)
    end
    for _, entry in ipairs(ready) do
      local known = e.cds and e.cds[entry[1]]
      GameTooltip:AddDoubleLine(entry[4], known and "estimated ready" or "not observed", 0.75, 0.75, 0.78, 0.45, 0.45, 0.5)
    end
  end
  for _, reason in ipairs(e.reasons or {}) do
    GameTooltip:AddLine("• " .. reason, 0.85, 0.85, 0.85, true)
  end
  if e.comp then
    local parts = {}
    for _, w in ipairs(Core.WEIGHTS) do
      local v = e.comp[w.key]
      if v and math.abs(v) >= 0.5 then
        parts[#parts + 1] = string.format("%s %+.0f", w.key, v)
      end
    end
    GameTooltip:AddLine(table.concat(parts, "  "), 0.55, 0.55, 0.6, true)
  end
  if not e.unit then
    GameTooltip:AddLine("Out of sight: health and auras unknown", 0.5, 0.5, 0.5, true)
  end
  local cfg = (Core.me.range or ns.RangeBands[Core.me.class])
  local reach = cfg and (cfg.reachYards or cfg.attackYards) or 40
  if e == Core.killNow then
    GameTooltip:AddLine(string.format("KILL TARGET: eligible within %d yd; switch margin %g", reach, Core.O("switchMargin")), Core.ACCENT[1], Core.ACCENT[2],
      Core.ACCENT[3], true)
  elseif Core.TargetBlocked(e) then
    GameTooltip:AddLine("Not kill target: " .. Core.TargetBlocked(e), 0.6, 0.6, 0.6, true)
  elseif Core.killNow then
    GameTooltip:AddLine(string.format("Current target %s: live %.0f vs %.0f; switching needs a lead greater than %g",
      Core.killNow.display:match("^[^-]+"), Core.killNow.live or 0, e.live or 0, Core.O("switchMargin")), 0.6, 0.6, 0.6, true)
  end
  GameTooltip:AddLine("|cff66ff66Left|r target   |cff66ff66Right|r focus   |cff66ff66Shift|r call in chat", 0.7, 0.7, 0.7)
  GameTooltip:Show()
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
