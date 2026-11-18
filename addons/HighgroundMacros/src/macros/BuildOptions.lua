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

-- A menu that writes its key into Panel.opts[key] (nil for the first choice).
local function Menu(p, parent, key, label, choices, y)
  local s = Kit.Select(parent, { label = label, menu = true, width = 260, choices = choices, value = choices[1].key,
    onChange = function(_, value)
      Panel.opts[key] = value ~= choices[1].key and value or nil
      Panel.Update()
    end })
  Panel.At(p, s, parent, 0, y, "full", 32)
  p[key .. "Menu"] = s
  return s
end

local function Before(p)
  local g = Panel.Group(p, "Casting options", true, false)
  p.beforeGroup = g
  for i, def in ipairs({ { "stopcast", "Stop my current cast first" },
    { "toggle", "Second press cancels spell" }, { "force", "Keep spell active (!)" },
    { "noclip", "Never cut my channel" } }) do
    local b = Check(p, g, def[1], def[2], (i - 1) * 38)
    p.toggles[#p.toggles + 1] = b
  end
  Kit.Tooltip(p.toggles[#p.toggles], { "Never cut my channel", "Adds /stopmacro [channeling]: pressing it while "
    .. "you channel Arcane Missiles, Drain Life or Mind Flay does nothing." })
  p.attack = Kit.Select(g.body, { label = "Auto attack", menu = true, width = 260, value = "unchanged",
    choices = { { key = "unchanged", label = "Leave unchanged" }, { key = "start", label = "Start attacking" },
      { key = "stop", label = "Stop attacking" } }, onChange = function(_, key)
      Panel.opts.startattack, Panel.opts.stopattack = key == "start", key == "stop"
      Panel.Update()
    end })
  Panel.At(p, p.attack, g.body, 0, 178, "full", 32)
  p.pet = Menu(p, g.body, "petDo", "Your pet", { { key = "unchanged", label = "Leave unchanged" },
    { key = "attack", label = "Attacks the same enemy" }, { key = "follow", label = "Follows me" } }, 244)
  Kit.Tooltip(p.pet, { "Your pet", "Adds /petattack (at the spell's enemy) or /petfollow before the spell." })
  p.aura = Panel.Field(p, g.body, "aura", "Remove buffs first (optional)", 310)
  Kit.Tooltip(p.aura, { "Remove buffs first", "Adds /cancelaura before the spell. Bladestorm stops Pummel; "
    .. "Ice Block and Divine Shield block other abilities. Separate several buffs with commas." })
  M.Suggest.Attach(p.aura, M.Suggest.LastItem(M.Suggest.AuraProvider))
  g.contentHeight = 342
end

-- Your stances and forms, in bar order: { { index, name } }.
function Panel.Forms()
  local out = {}
  local count = M.Host.call(GetNumShapeshiftForms) or 0
  for i = 1, count do
    local id = select(4, M.Host.call(GetShapeshiftFormInfo, i))
    local name = id and M.Host.SpellName(id)
    if name then out[#out + 1] = { i, name } end
  end
  return out
end

local function Stance(p)
  local g = Panel.Group(p, "Stance or form", true, false)
  p.stanceGroup = g
  p.stance = Kit.Select(g.body, { label = "Cast it in", menu = true, width = 260, choices = {},
    onChange = function(_, key)
      local info = p.stance.forms[key]
      Panel.opts.stance = info and { info[1], info[2] } or nil
      Panel.Update()
    end })
  Panel.At(p, p.stance, g.body, 0, 20, "full", 32)
  Kit.Tooltip(p.stance, { "Stance or form", "In another stance or form, a press switches first; "
    .. "press again to cast. Battle Stance for Overpower, Berserker Stance for Pummel." })
  g.contentHeight = 52
end

-- Stance choices: any, your forms, and one a loaded preset names.
function Panel.StanceChoices(p, current)
  local choices, forms = { { key = "any", label = "Any stance or form" } }, { }
  for _, f in ipairs(Panel.Forms()) do forms[tostring(f[1])] = f end
  if current then forms[tostring(current[1])] = forms[tostring(current[1])] or current end
  for key, f in pairs(forms) do choices[#choices + 1] = { key = key, label = f[2], index = f[1] } end
  table.sort(choices, function(a, b) return (a.index or 0) < (b.index or 0) end)
  p.stance.forms = forms
  p.stance:SetChoices(choices)
  p.stance:SetValue(current and tostring(current[1]) or "any", true)
  return #choices > 1
end

local function Alternative(p)
  local g = Panel.Group(p, "Alternative action", true, false)
  p.altGroup = g
  local when = { { key = "none", label = "Never" } }
  for _, key in ipairs(M.Config.ALT_ORDER) do when[#when + 1] = { key = key, label = M.Config.ALT_WHEN[key].label } end
  Menu(p, g.body, "alt", "When", when, 20)
  Kit.Tooltip(p.altMenu, { "Alternative action", "One button, two jobs: hold a modifier, right-click or "
    .. "press it out of combat to do something else." })
  local does = {}
  for _, d in ipairs(M.Config.ALT_DO) do
    if not d.ranks or M.Ranks.Supported() then does[#does + 1] = { key = d.key, label = d.label } end
  end
  p.altDoMenu = Kit.Select(g.body, { label = "Instead", menu = true, width = 260, choices = does, value = "self",
    onChange = function(_, key) Panel.opts.altDo = key; Panel.Update() end })
  Panel.At(p, p.altDoMenu, g.body, 0, 84, "full", 32)
  p.altSpell = Panel.Field(p, g.body, "altSpell", "Other spell", 148)
  M.Suggest.Attach(p.altSpell, M.Suggest.SpellProvider)
  p.altRank = Panel.Field(p, g.body, "altRank", "Rank", 148, 64)
  p.altRank:SetMaxLetters(2)
  Kit.Tooltip(p.altRank, { "Lower rank", "Hold the key for a cheaper rank, e.g. a small heal to save mana." })
  g.contentHeight = 116
end

local function Announce(p)
  local g = Panel.Group(p, "Announce", true, false)
  p.sayGroup = g
  local choices = { { key = "none", label = "Nothing" } }
  for _, key in ipairs(M.Config.CHAT_ORDER) do choices[#choices + 1] = { key = key, label = M.Config.CHAT[key].label } end
  Menu(p, g.body, "say", "Tell", choices, 20)
  Kit.Tooltip(p.sayMenu, { "Announce", "Sent with every press, even when the spell fails. During boss "
    .. "encounters only party, raid and instance chat work." })
  p.sayText = Panel.Field(p, g.body, "sayText", "Message (%t: your target, %f: your focus)", 84)
  g.contentHeight = 116
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
  p.equip = Panel.Field(p, g.body, "equip", "Equip first (weapon, shield)", 168)
  Kit.Tooltip(p.equip, { "Equip first", "Swap gear before the spell, e.g. a shield for Shield Bash. "
    .. "Name a one-handed weapon before the shield. Weapons swap in combat; armour does not." })
  M.Suggest.Attach(p.equip, M.Suggest.LastItem(M.Suggest.ItemProvider))
  g.contentHeight = 200
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
  Stance(p)
  Before(p)
  Alternative(p)
  Items(p)
  Announce(p)
  Utility(p)
end
