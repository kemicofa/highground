local test, new, equal = ...

-- Independent sRGB contrast calculation, including alpha compositing.
-- These checks cover the authored UI at default opacity, not a guarantee
-- about arbitrary game scenery behind player-customized translucent HUDs.
local function over(fg, bg, alpha)
  alpha = alpha or fg[4] or 1
  local result = {}
  for i = 1, 3 do result[i] = fg[i] * alpha + bg[i] * (1 - alpha) end
  return result
end
local function luminance(c)
  local channels = {}
  for i = 1, 3 do
    channels[i] = c[i] <= 0.04045 and c[i] / 12.92 or ((c[i] + 0.055) / 1.055) ^ 2.4
  end
  return channels[1] * 0.2126 + channels[2] * 0.7152 + channels[3] * 0.0722
end
local function contrast(fg, bg, minimum, why)
  local a, b = luminance(over(fg, bg)), luminance(bg)
  local ratio = (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05)
  assert(ratio >= minimum, why .. string.format(": %.2f:1, need %.1f:1", ratio, minimum))
end

local signals = { "accent", "gold", "success", "warning", "pending", "danger", "kill", "info",
  "scopeGeneral", "scopeCharacter", "factionA", "factionH", "error", "bounty" }
local chips = { "chipImmune", "chipDef", "chipCc", "chipStun", "chipCarrier", "chipSpent", "chipBurst", "chipPurge" }

for _, name in ipairs({ "highground", "ember", "parchment", "azeroth" }) do
test(name .. " text, states and boundaries meet contrast targets", function()
  local sim = new("retail")
  local T = sim.ns.Theme
  T.Use(name)
  local c, a = sim.ns.ThemeTokens.color, sim.ns.ThemeTokens.alpha
  for _, background in ipairs({ "bg", "surface", "surfaceRaised", "well" }) do
    local bg = c[background]
    for _, overlay in ipairs({ "overlaySubtle", "overlayHover", "overlaySelected" }) do
      local composed = over(c[overlay], bg)
      for _, ink in ipairs({ "text", "textMuted", "textDim", "titleText" }) do
        contrast(c[ink], composed, 4.5, name .. " " .. ink .. " on " .. background .. "/" .. overlay)
      end
      for _, ink in ipairs(signals) do
        contrast(c[ink], composed, 4.5, name .. " " .. ink .. " on " .. background .. "/" .. overlay)
      end
    end
    for _, ink in ipairs(chips) do
      local chip = sim.ns.Kit.Chip(sim.env.UIParent, "STATE", ink)
      local backing = over(chip.bg.colorTexture, bg)
      equal(chip.bg.colorTexture[4], 1, "chip isolates text from underlying colour")
      contrast(chip.label.textColor, backing, 4.5, name .. " " .. ink .. " chip on " .. background)
    end
    contrast(c.controlBorder, bg, 3, name .. " field boundary on " .. background)
    contrast(c.focus, bg, 3, name .. " focus on " .. background)
    contrast(c.accent, bg, 3, name .. " selection marker on " .. background)
  end
  -- Actual Kit buttons, including hover, use the correct foreground tone.
  for _, tone in ipairs({ "surface", "panel", "selected", "accent", "gold", "danger" }) do
    local button = sim.ns.Kit.Button(sim.env.UIParent, "Action", 100, 24, { tone = tone })
    local bg = over(button.bg.colorTexture, c.bg)
    contrast(button.label.textColor, bg, 4.5, name .. " " .. tone .. " button")
    button.scripts.OnEnter(button)
    contrast(button.label.textColor, over(button.hover.colorTexture, bg), 4.5, name .. " " .. tone .. " hover")
  end
  -- Saved scope marks and the selected target remain distinct and legible.
  local variant = sim.ns.Kit.Button(sim.env.UIParent, "F", 30, 20)
  for _, where in ipairs({ "general", "character", "both" }) do
    sim.ns.Macros.Window.PaintVariant(variant, where, true)
    local bg = over(variant.bg.colorTexture, c.bg)
    contrast(variant.label.textColor, bg, 4.5, name .. " saved macro/" .. where)
    contrast(variant.label.textColor, over(variant.hover.colorTexture, bg), 4.5, name .. " saved macro hover/" .. where)
    contrast(variant.ring[1].colorTexture, bg, 3, name .. " saved macro selection/" .. where)
  end
  -- A fully white/black class bar bounds all class colours. Include the
  -- zebra stripe and recommended-target tint. Status chips isolate their ink.
  for _, fill in ipairs({ "white", "black" }) do
    local bg = over(c[fill], c.bg, a.healthFill)
    bg = over(c.textMuted, bg, a.zebraOdd)
    bg = over(c.accent, bg, a.topTint)
    for _, ink in ipairs({ "text", "textMuted", "textDim", "danger", "accent", "kill" }) do
      contrast(c[ink], bg, 4.5, name .. " " .. ink .. " on health fill/" .. fill)
    end
    for _, ink in ipairs(chips) do
      contrast(c[ink], over(c.chipBg, bg), 4.5, name .. " " .. ink .. " on health fill/" .. fill)
    end
  end
  for _, ink in ipairs({ "hudText", "hudGold", "hudWarning", "hudDanger" }) do
    contrast(c[ink], c.hudBg, 4.5, name .. " world badge " .. ink)
  end
end)
end

test("class names keep readable ink across theme changes without tinting class strips", function()
  local sim = new("cata")
  local T, Core = sim.ns.Theme, sim.ns.Core
  local white, yellow, blue = { r = 1, g = 1, b = 1 }, { r = 1, g = 0.96, b = 0.41 }, { r = 0, g = 0.44, b = 0.87 }
  local samples = {}
  for _, color in ipairs({ white, yellow, blue }) do
    local text = T.Text(sim.env.UIParent, "rowName")
    local strip = sim.env.UIParent:CreateTexture()
    Core.ClassPaint(text, color)
    Core.ClassPaint(strip, color)
    samples[#samples + 1] = { text = text, strip = strip, color = color }
  end
  for _, name in ipairs(T.Names()) do
    T.Use(name)
    for _, sample in ipairs(samples) do
      for _, bg in ipairs({ "bg", "surface", "surfaceRaised" }) do
        contrast(sample.text.textColor, T.Rgb(bg), 4.5, name .. " class name on " .. bg)
      end
      equal(sample.strip.colorTexture[1], sample.color.r, "class strip red unchanged")
      equal(sample.strip.colorTexture[3], sample.color.b, "class strip blue unchanged")
    end
  end
  T.Paint(samples[1].text, "danger")
  T.Use("highground")
  equal(samples[1].text.wbClass, nil, "semantic paint detaches class ink")
  equal(samples[1].text.textColor[1], T.Rgb("danger")[1], "semantic colour survives repaint")
end)

test("focus and selection have persistent shape cues; disabled toggles have no hover", function()
  local sim = new("retail")
  local Kit, T = sim.ns.Kit, sim.ns.Theme
  local box = Kit.Input(sim.env.UIParent, 160, "Name")
  box:SetFocus()
  assert(box.focusLine:IsShown(), "focus adds an underline")
  equal(box.focusLine:GetHeight(), 2, "two-pixel underline")
  T.Use("parchment")
  equal(box.focusLine.colorTexture[1], T.Rgb("focus")[1], "focus follows theme")
  box:ClearFocus()
  assert(not box.focusLine:IsShown(), "underline leaves on blur")
  local toggle = Kit.Toggle(sim.env.UIParent, "Setting", { checked = false })
  assert(not toggle.mark:IsShown(), "unchecked is empty")
  toggle:SetChecked(true)
  assert(toggle.mark:IsShown(), "checked has a shape")
  toggle:SetEnabled(false)
  toggle.scripts.OnEnter(toggle)
  assert(not toggle.hover:IsShown() and not toggle.enabled, "disabled ignores hover and native clicks")
  local select = Kit.Select(sim.env.UIParent, { menu = true, value = "b",
    choices = { { key = "a", label = "Alpha" }, { key = "b", label = "Beta" } } })
  select.scripts.OnClick(select)
  local list = Kit.Dropdown.Frame()
  assert(not list.rows[1].marker:IsShown() and list.rows[2].marker:IsShown(), "selection has a side marker")
  T.Use("azeroth")
  equal(list.rows[2].bg.colorTexture[4], T.Rgb("overlaySelected")[4], "open menu alpha follows palette")
end)

test("reduced motion keeps cues steady, applies in combat and survives reload", function()
  local sim = new("cata")
  local Core = sim.ns.Core
  sim:enemy("Alpha")
  sim:join()
  local row = Core.rows[1]
  assert(not row.goFill.allPoints and not Core.hero.goFill.allPoints, "kill cues do not wash over text")
  equal(row.goFill:GetWidth(), sim.ns.Theme.Size("strip"), "kill cue is confined to an edge")
  Core.liveDotAnim:Play()
  row.goFillAnim:Play()
  row.goPop:Play()
  row.tileFlashAnim:Play()
  sim:setCombat(true)
  Core.SetReducedMotion(true)
  assert(not Core.liveDotAnim.group:IsPlaying(), "live pulse stopped")
  equal(Core.liveDot:GetAlpha(), 1, "live state remains visible")
  assert(not row.goFillAnim.group:IsPlaying(), "kill fill no longer pulses")
  equal(row.goFill:GetAlpha(), 0.03, "steady kill cue")
  assert(not row.goPop.group:IsPlaying(), "target zoom stopped")
  assert(not row.tileFlashAnim.group:IsPlaying(), "rank flash stopped")
  equal(row.tileFlash:GetAlpha(), 0, "rank remains readable")
  row.goPop:Play()
  assert(not row.goPop.group:IsPlaying(), "future zooms suppressed")
  local again = new("cata", sim.env.HighgroundDB)
  assert(again.ns.Core.ReducedMotion(), "preference restored")
  Core.SetReducedMotion(false)
  assert(Core.liveDotAnim.group:IsPlaying(), "ongoing cue resumes")
  assert(not row.goPop.group:IsPlaying(), "past zoom does not replay")
end)
