local _, ns = ...
local M = ns.Macros
local Panel, Kit, Theme = M.BuildPanel, M.Host.Kit, M.Host.Theme

local function Check(p, group, key, label, y, x, width)
  local b = Kit.Choice(group.body, label, 260, "check", function(self)
    if self.disabled then return end
    Panel.opts[key] = not Panel.opts[key]
    Panel.Update()
  end)
  b.value = key
  Panel.At(p, b, group.body, x or 0, y, width or "full", 32)
  return b
end

local function Conditions(p)
  local g = Panel.Group(p, "Target conditions", true, false)
  p.conditionsGroup = g
  p.kind = Kit.Select(g.body, { label = "Only cast if the recipient is", menu = true, width = 260, value = "any",
    choices = { { key = "any", label = "Any valid target" }, { key = "harm", label = "A living enemy" },
      { key = "help", label = "A living ally" } }, onChange = function(_, key)
      Panel.opts.kind = key ~= "any" and key or nil; Panel.Update()
    end })
  Panel.At(p, p.kind, g.body, 0, 20, "full", 32)
  local fallback = Check(p, g, "fallback", "Otherwise use my target", 68)
  local self = Check(p, g, "self", "Otherwise cast on myself", 106)
  p.toggles = { fallback, self }
  Kit.Tooltip(fallback, { "Fallback to your target", "If the recipient fails the macro's conditions, use normal spell targeting. "
    .. "Being out of range or on cooldown does not trigger a fallback." })
  Kit.Tooltip(self, { "Fallback to yourself", "If the earlier targets fail the macro's conditions, try yourself. "
    .. "Being out of range or on cooldown does not trigger a fallback." })
  g.contentHeight = 138
end

local function Before(p)
  local g = Panel.Group(p, "Casting options", true, false)
  p.beforeGroup = g
  for i, def in ipairs({ { "stopcast", "Stop my current cast first" },
    { "toggle", "Second press cancels spell" }, { "force", "Keep spell active (!)" } }) do
    local b = Check(p, g, def[1], def[2], (i - 1) * 38)
    p.toggles[#p.toggles + 1] = b
  end
  p.attack = Kit.Select(g.body, { label = "Auto attack", menu = true, width = 260, value = "unchanged",
    choices = { { key = "unchanged", label = "Leave unchanged" }, { key = "start", label = "Start attacking" },
      { key = "stop", label = "Stop attacking" } }, onChange = function(_, key)
      Panel.opts.startattack, Panel.opts.stopattack = key == "start", key == "stop"
      Panel.Update()
    end })
  Panel.At(p, p.attack, g.body, 0, 140, "full", 32)
  p.aura = Panel.Field(p, g.body, "aura", "Remove buffs first (optional)", 206)
  Kit.Tooltip(p.aura, { "Remove buffs first", "Adds /cancelaura before the spell. Bladestorm stops Pummel; "
    .. "Ice Block and Divine Shield block other abilities. Separate several buffs with commas." })
  M.Suggest.Attach(p.aura, M.Suggest.LastItem(M.Suggest.AuraProvider))
  g.contentHeight = 238
end

local function Items(p)
  local g = Panel.Group(p, "Use items first", true, false)
  p.itemsGroup, p.trinkets = g, {}
  for i, def in ipairs({ { "trinket1", "Top trinket" }, { "trinket2", "Bottom trinket" } }) do
    p.trinkets[i] = Check(p, g, def[1], def[2], (i - 1) * 38)
  end
  p.item = Panel.Field(p, g.body, "item", "Other items or slots (comma separated)", 104)
  Kit.Tooltip(p.item, { "Items or equipment slots", "Use items before the spell. Enter names such as Healthstone, "
    .. "or slot numbers: 10 for gloves, 13 for the top trinket, 14 for the bottom trinket." })
  M.Suggest.Attach(p.item, M.Suggest.LastItem(M.Suggest.ItemProvider))
  g.contentHeight = 136
end

local function Resets(p)
  local g = Panel.Group(p, "Sequence reset", true, true)
  p.resetGroup, p.resets = g, {}
  p.resetSeconds = Panel.Field(p, g.body, "resetSeconds", "Seconds without a press (optional)", 20, 64)
  p.resetSeconds:SetMaxLetters(3)
  p.resetUnit = Theme.Text(g.body, "body", "textMuted")
  p.resetUnit:SetPoint("LEFT", p.resetSeconds, "RIGHT", 8, 0); p.resetUnit:SetText("SEC")
  Kit.Tooltip(p.resetSeconds, { "Reset after inactivity", "Each press restarts this count. Leave empty for no time limit." })
  for i, r in ipairs(M.Config.RESETS) do
    p.resets[i] = Check(p, g, "reset_" .. r.key, r.button, 68 + (i - 1) * 38)
  end
  g.contentHeight = 252
end

local function Utility(p)
  local g = Panel.Group(p, "Utility action", true, false)
  p.scriptGroup = g
  p.scriptAction = Kit.Select(g.body, { width = 260, menu = true, choices = M.Scripts.Choices(), value = "none",
    onChange = function(_, key)
      Panel.opts.scriptAction = key ~= "none" and key or nil
      p.scriptName:SetText(""); p.scriptCount:SetText("")
      Panel.Update()
    end })
  Panel.At(p, p.scriptAction, g.body, 0, 0, "full", 32)
  p.scriptName = Panel.Field(p, g.body, "scriptName", "Name", 64)
  p.scriptCount = Panel.Field(p, g.body, "scriptCount", "Quantity / option number", 128)
  p.scriptCount:SetMaxLetters(4)
  Kit.Tooltip(p.scriptAction, { "Utility action", "Run after the spell, or on its own: buy an item, choose a gossip "
    .. "option, equip a set, repair, sell junk, or accept a quest." })
  g.contentHeight = 32
end

function Panel.Options(p)
  Resets(p)
  Conditions(p)
  Before(p)
  Items(p)
  Utility(p)
end
