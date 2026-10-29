-- Feature switches and their parents, client visibility, the Appearance page.
local o, cata = ...
local client, set, equal = o.client, o.set, o.equal
for _, s in ipairs({ cata, client("retail") }) do
  local timers = s:feature("timers")
  set(timers, false)
  equal(s:feature("objectives").enabled, false, "objective display depends on timers")
  equal(s:feature("dieAlert").enabled, false, "resurrection alert depends on timers")
  equal(s:feature("flags").enabled, true, "carrier panel is independently configurable")
  assert(s:feature("sound") and s:feature("allBGs"), "sound and battleground scope have switches")
  equal(s.db.objectives, nil, "disabling a parent preserves the child preference")
  set(timers, true)
  equal(s:feature("objectives").enabled, true, "dependent controls recover when timers are enabled")
  local compact = s:feature("compact")
  set(compact, true)
  equal(s.compactApplied, true, "compact layout switch applies the layout")
  set(compact, false)
  equal(s.compactApplied, false, "compact layout switch turns back off")
  local targeting = s:feature("killorder")
  set(targeting, false)
  equal(s.killOrderApplied, true, "target recommendations switch applies to the panel")
  equal(s:feature("sniper").enabled, true, "world target marker stays available to follow your own target")
  s.db.scale = 0.65
  local reset = assert(s:find("Button", "Reset target tuning"))
  reset.scripts.OnClick(reset)
  equal(s.db.scale, 0.65, "reset tuning preserves UI scale")
  equal(s.db.killorder, false, "reset tuning preserves feature choices")
end
local retail = client("retail")
equal(retail:tracking(), nil, "Retail hides the unsupported per-spell tracking page")
equal(retail:feature("cooldowns"), nil, "Retail hides combat-log-only tracking")
equal(retail:find("FontString", "PvP trinket on cooldown"), nil, "Retail hides unavailable cooldown tuning")
equal(retail:find("FontString", "In breakable CC"), nil, "Retail hides the inactive breakable-CC setting")
equal(retail:find("FontString", "Per relative max-health step"), nil, "Retail hides unavailable enemy-health tuning")
assert(retail:row("Orb carrier"), "Retail keeps orb tuning")
for _, s in ipairs({ client("cata"), client("retail") }) do
  equal(s.ui.pages[1].name, "General", "General is the first settings subpage")
  for _, key in ipairs({ "timers", "arena", "killorder", "flags", "intel" }) do
    equal(s:feature(key):GetChecked(), true, key .. " starts on")
  end
  local arena = s:feature("arena")
  set(arena, false)
  equal(s.db.arena, false, "the arena panel can be switched off from General")
end
for _, s in ipairs({ client("cata"), client("retail") }) do
  equal(s.ui.pages[2].name, "Appearance", "Appearance follows General")
  local function check(text)
    local label
    for _, f in ipairs(s.frames) do
      if f.kind == "FontString" and f.text == text then label = f end
    end
    for _, f in ipairs(s.frames) do
      if label and f.kind == "Button" and f.label == label then return f end
    end
  end
  local frameless = assert(check("Frameless"), "frameless switch")
  equal(frameless:GetChecked(), false, "panels start framed")
  set(frameless, true)
  equal(s.db.style.frameless, true, "frameless is saved")
  equal(s.ns.Core.Frameless(), true, "frameless applies")
  local rank = assert(check("Rank number"), "rank element switch")
  set(rank, false)
  equal(s.ns.Core.ShowsElement("rank"), false, "row elements can be hidden")
  equal(check("PvP trinket") ~= nil, not s.ns.Core.IS_RETAIL, "trinket element only where tracked")
  local Core = s.ns.Core
  Core.SetMetric("row", 99, false)
  equal(Core.Metric("row", false), 48, "row height is clamped to its range")
  equal(Core.Metric("row", true), 20, "compact keeps its own row height")
  Core.SetPanelScale("arena", 1.3)
  equal(Core.PanelScale("arena"), 1.3, "panels scale separately")
  equal(Core.PanelScale("main"), 1, "other panels keep their scale")
  Core.SetStyleChoice("font", "nope")
  equal(Core.StyleChoice("font").key, "barlow", "unknown font falls back")
  Core.SetStyleChoice("barColor", "faction")
  equal(Core.StyleChoice("barColor").key, "faction", "faction bar colors can be chosen")
  s.db.style.border = "bad"
  equal(Core.BorderSize(), 1, "invalid border size falls back")
  assert(s:find("Button", "Reset appearance")).scripts.OnClick()
  equal(Core.Frameless(), false, "reset appearance restores frames")
  equal(Core.PanelScale("arena"), 1, "reset appearance restores panel scales")
end
