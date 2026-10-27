local _, ns = ...
local Core = ns.Core

-- Secure "target #1" button (bind under Key Bindings > AddOns > Highground).
-- Attributes can only change out of combat, so it is refreshed then.
---------------------------------------------------------------------------
local targetBtn = CreateFrame("Button", "HighgroundTargetButton", UIParent, "SecureActionButtonTemplate")
targetBtn:RegisterForClicks("AnyDown", "AnyUp")
targetBtn:SetAttribute("type", "macro")
-- /click from a macro sends an UP click; with ActionButtonUseKeyDown on, a
-- secure button would only act on DOWN and ignore it. Act on up instead:
-- works for /click, key bindings (down+up -> fires once on up) and mouse.
targetBtn:SetAttribute("useOnKeyDown", false)

-- Mark button: /click HighgroundMarkButton (macro or keybind). Targets the
-- kill target, puts your marker on it via /tm (secure slash command), then
-- returns to your previous target. Like all secure buttons it can only be
-- re-pointed out of combat. /tm toggles, so it's skipped when the enemy
-- already wears that marker.
Core.markBtn = CreateFrame("Button", "HighgroundMarkButton", UIParent, "SecureActionButtonTemplate")
Core.markBtn:RegisterForClicks("AnyDown", "AnyUp")
Core.markBtn:SetAttribute("type", "macro")
Core.markBtn:SetAttribute("useOnKeyDown", false) -- see targetBtn
-- Core.markBound caches the "key:icon:alreadyMarked" macro signature.

-- Focus button: /click HighgroundFocusButton or its keybind. Focuses the kill
-- target and returns to your previous target (/focus takes no name).
local focusBtn = CreateFrame("Button", "HighgroundFocusButton", UIParent, "SecureActionButtonTemplate")
focusBtn:RegisterForClicks("AnyDown", "AnyUp")
focusBtn:SetAttribute("type", "macro")
focusBtn:SetAttribute("useOnKeyDown", false) -- see targetBtn

-- Pre-rename names, so existing macros (/click KillOrderTargetButton...)
-- keep working: /click looks buttons up by global name.
Core.WrapRestore(focusBtn)
Core.WrapRestore(Core.markBtn)
_G.KillOrderTargetButton = targetBtn
_G.KillOrderMarkButton = Core.markBtn
_G.KillOrderFocusButton = focusBtn

function Core.UpdateTargetButton()
  if InCombatLockdown() then
    return
  end
  -- Pick fresh: Render (which also picks) runs after this in the tick, so
  -- reading killNow here would lag a tick or fall back to the list order.
  local on = Core.PriorityOn()
  local top = on and Core.PickHeroTarget() or nil
  local heroKey = top and top.key
  if not top and on then
    for _, e in ipairs(Core.order) do
      if not e.dead then
        top = e
        break
      end
    end
  end
  -- Hero card: only the live kill target (nothing when nobody is in reach).
  if heroKey ~= Core.heroBtn.boundKey then
    Core.heroBtn.boundKey = heroKey
    local name = heroKey and Core.DisplayName(heroKey)
    Core.heroBtn:SetAttribute("macrotext1", name and ("/targetexact " .. name) or "")
    Core.SetReturnMacro(Core.heroBtn, "macrotext2", name and ("/targetexact " .. name .. "\n/focus"))
  end
  local key = top and top.key
  if key ~= Core.boundKey then
    Core.boundKey = key
    targetBtn:SetAttribute("macrotext", key and ("/targetexact " .. Core.DisplayName(key)) or "")
    Core.SetReturnMacro(focusBtn, "macrotext", key and ("/targetexact " .. Core.DisplayName(key) .. "\n/focus"))
  end

  local icon = Core.db.markIcon or 8
  local ping = Core.db.markMode ~= "icon"
  local already = not ping and top and top.marker == icon
  local sig = tostring(key) .. ":" .. (ping and ("ping-" .. Core.db.pingType) or icon) .. ":" .. tostring(already)
  if sig ~= Core.markBound then
    Core.markBound = sig
    local text = ""
    if key and not already then
      local action = ping and ("/ping [@target] " .. (Core.db.pingType or "attack")) or ("/tm " .. icon)
      text = "/targetexact " .. Core.DisplayName(key) .. "\n" .. action
    end
    Core.SetReturnMacro(Core.markBtn, "macrotext", text ~= "" and text or nil)
  end
end
