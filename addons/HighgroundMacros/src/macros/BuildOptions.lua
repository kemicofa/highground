local _, ns = ...
local Locale, Localization = ns.Macros.Host.Messages, ns.Macros.Host.Localization
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
  local g = Panel.Group(p, Locale:Get("macros.buildoptions.target_conditions.c08be4"), true, false)
  p.conditionsGroup = g
  p.kind = Kit.Select(g.body, { label = Locale:Get("macros.buildoptions.only_cast_if_the_recipient_is.8a414f"), menu = true, width = 260, value = "any",
    choices = { { key = "any", label = Locale:Get("macros.buildoptions.any_valid_target.fbacc8") }, { key = "harm", label = Locale:Get("macros.buildoptions.a_living_enemy.2a9d06") },
      { key = "help", label = Locale:Get("macros.buildoptions.a_living_ally.8297c1") } }, onChange = function(_, key)
      Panel.opts.kind = key ~= "any" and key or nil; Panel.Update()
    end })
  Panel.At(p, p.kind, g.body, 0, 20, "full", 32)
  local fallback = Check(p, g, "fallback", Locale:Get("macros.buildoptions.otherwise_use_my_target.97f199"), 68)
  local self = Check(p, g, "self", Locale:Get("macros.buildoptions.otherwise_cast_on_myself.891042"), 106)
  p.toggles = { fallback, self }
  Kit.Tooltip(fallback, function() return { Locale:Get("macros.buildoptions.fallback_to_your_target.4c1106"), Locale:Get("macros.buildoptions.if_the_recipient_fails_the_macro_s.49a23a") } end)
  Kit.Tooltip(self, function() return { Locale:Get("macros.buildoptions.fallback_to_yourself.57ecd2"), Locale:Get("macros.buildoptions.if_the_earlier_targets_fail_the_macro.612911") } end)
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
  local g = Panel.Group(p, Locale:Get("macros.buildoptions.casting_options.9671a4"), true, false)
  p.beforeGroup = g
  for i, def in ipairs({ { "stopcast", Locale:Get("macros.buildoptions.stop_my_current_cast_first.6a0b68") },
    { "stopafter", Locale:Get("macros.buildoptions.stop_casting_after_spell.b27228") },
    { "toggle", Locale:Get("macros.buildoptions.second_press_cancels_spell.98aea1") }, { "force", Locale:Get("macros.buildoptions.keep_spell_active.0da14c") },
    { "noclip", Locale:Get("macros.buildoptions.never_cut_my_channel.9b71e9") } }) do
    local b = Check(p, g, def[1], def[2], (i - 1) * 38)
    p.toggles[#p.toggles + 1] = b
    if def[1] == "stopafter" then
      Kit.Tooltip(b, function() return { Locale:Get("macros.buildoptions.stop_casting_after_spell.b27228"), Locale:Get("macros.buildoptions.adds_stopcasting_at_the_end_for_cast.e9b42b") } end)
    end
  end
  Kit.Tooltip(p.toggles[#p.toggles], function() return { Locale:Get("macros.buildoptions.never_cut_my_channel.9b71e9"), Locale:Get("macros.buildoptions.adds_stopmacro_channeling_pressing_it_while_you.c9c07a") } end)
  p.attack = Kit.Select(g.body, { label = Locale:Get("macros.buildoptions.auto_attack.d3fbb8"), menu = true, width = 260, value = "unchanged",
    choices = { { key = "unchanged", label = Locale:Get("macros.buildoptions.leave_unchanged.ff924f") }, { key = "start", label = Locale:Get("macros.buildoptions.start_attacking.ebd36c") },
      { key = "stop", label = Locale:Get("macros.buildoptions.stop_attacking.476809") } }, onChange = function(_, key)
      Panel.opts.startattack, Panel.opts.stopattack = key == "start", key == "stop"
      Panel.Update()
    end })
  Panel.At(p, p.attack, g.body, 0, 216, "full", 32)
  p.pet = Menu(p, g.body, "petDo", Locale:Get("macros.buildoptions.your_pet.8c803f"), { { key = "unchanged", label = Locale:Get("macros.buildoptions.leave_unchanged.ff924f") },
    { key = "attack", label = Locale:Get("macros.buildoptions.attacks_the_same_enemy.f65ab5") }, { key = "follow", label = Locale:Get("macros.buildoptions.follows_me.6438db") } }, 282)
  Kit.Tooltip(p.pet, function() return { Locale:Get("macros.buildoptions.your_pet.8c803f"), Locale:Get("macros.buildoptions.adds_petattack_at_the_spell_s_enemy.e78171") } end)
  p.aura = Panel.Field(p, g.body, "aura", Locale:Get("macros.buildoptions.remove_buffs_first_optional.7ce866"), 348)
  Kit.Tooltip(p.aura, function() return { Locale:Get("macros.buildoptions.remove_buffs_first.8ee578"), Locale:Get("macros.buildoptions.adds_cancelaura_before_the_spell_bladestorm_stops.542ed2") } end)
  M.Suggest.Attach(p.aura, M.Suggest.LastItem(M.Suggest.AuraProvider))
  g.contentHeight = 380
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
  local g = Panel.Group(p, Locale:Get("macros.buildoptions.stance_or_form.63e3f0"), true, false)
  p.stanceGroup = g
  p.stance = Kit.Select(g.body, { label = Locale:Get("macros.buildoptions.cast_it_in.430dce"), menu = true, width = 260, choices = {},
    onChange = function(_, key)
      local info = p.stance.forms[key]
      Panel.opts.stance = info and { info[1], info[2] } or nil
      Panel.Update()
    end })
  Panel.At(p, p.stance, g.body, 0, 20, "full", 32)
  Kit.Tooltip(p.stance, function() return { Locale:Get("macros.buildoptions.stance_or_form.63e3f0"), Locale:Get("macros.buildoptions.in_another_stance_or_form_a_press.5d717c") } end)
  g.contentHeight = 52
end

-- Stance choices: any, your forms, and one a loaded preset names.
function Panel.StanceChoices(p, current)
  local choices, forms = { { key = "any", label = Locale:Get("macros.buildoptions.any_stance_or_form.c12a87") } }, { }
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
  local g = Panel.Group(p, Locale:Get("macros.buildoptions.alternative_action.cc6161"), true, false)
  p.altGroup = g
  local when = { { key = "none", label = Locale:Get("macros.buildoptions.never.80c305") } }
  for _, key in ipairs(M.Config.ALT_ORDER) do when[#when + 1] = { key = key, label = M.Config.ALT_WHEN[key].label } end
  Menu(p, g.body, "alt", Locale:Get("macros.buildoptions.when.769bb1"), when, 20)
  Kit.Tooltip(p.altMenu, function() return { Locale:Get("macros.buildoptions.alternative_action.cc6161"), Locale:Get("macros.buildoptions.one_button_two_jobs_hold_a_modifier.ae6b71") } end)
  local does = {}
  for _, d in ipairs(M.Config.ALT_DO) do
    if not d.ranks or M.Ranks.Supported() then does[#does + 1] = { key = d.key, label = d.label } end
  end
  p.altDoMenu = Kit.Select(g.body, { label = Locale:Get("macros.buildoptions.instead.62cb55"), menu = true, width = 260, choices = does, value = "self",
    onChange = function(_, key) Panel.opts.altDo = key; Panel.Update() end })
  Panel.At(p, p.altDoMenu, g.body, 0, 84, "full", 32)
  p.altSpell = Panel.Field(p, g.body, "altSpell", Locale:Get("macros.buildoptions.other_spell.4bc303"), 148)
  M.Suggest.Attach(p.altSpell, M.Suggest.SpellProvider)
  p.altRank = Panel.Field(p, g.body, "altRank", Locale:Get("macros.buildoptions.rank.dd48a1"), 148, 64)
  p.altRank:SetMaxLetters(2)
  Kit.Tooltip(p.altRank, function() return { Locale:Get("macros.buildoptions.lower_rank.a8c207"), Locale:Get("macros.buildoptions.hold_the_key_for_a_cheaper_rank.f69bf5") } end)
  g.contentHeight = 116
end

local function Announce(p)
  local g = Panel.Group(p, Locale:Get("macros.buildoptions.announce.b6e441"), true, false)
  p.sayGroup = g
  local choices = { { key = "none", label = Locale:Get("macros.buildoptions.nothing.448194") } }
  for _, key in ipairs(M.Config.CHAT_ORDER) do choices[#choices + 1] = { key = key, label = M.Config.CHAT[key].label } end
  Menu(p, g.body, "say", Locale:Get("macros.buildoptions.tell.bceeda"), choices, 20)
  Kit.Tooltip(p.sayMenu, function() return { Locale:Get("macros.buildoptions.announce.b6e441"), Locale:Get("macros.buildoptions.sent_with_every_press_even_when_the.6d0f27") } end)
  p.sayText = Panel.Field(p, g.body, "sayText", Locale:Get("macros.buildoptions.message_t_your_target_f_your_focus.11a911"), 84)
  g.contentHeight = 116
end

local function Items(p)
  local g = Panel.Group(p, Locale:Get("macros.buildoptions.use_items_first.bf2319"), true, false)
  p.itemsGroup, p.trinkets = g, {}
  for i, def in ipairs({ { "trinket1", Locale:Get("macros.buildoptions.top_trinket.8c409d") }, { "trinket2", Locale:Get("macros.buildoptions.bottom_trinket.e55af5") } }) do
    p.trinkets[i] = Check(p, g, def[1], def[2], (i - 1) * 38)
  end
  p.item = Panel.Field(p, g.body, "item", Locale:Get("macros.buildoptions.other_items_or_slots_comma_separated.c57d19"), 104)
  Kit.Tooltip(p.item, function() return { Locale:Get("macros.buildoptions.items_or_equipment_slots.be2482"), Locale:Get("macros.buildoptions.use_items_before_the_spell_enter_names.853c6c") } end)
  M.Suggest.Attach(p.item, M.Suggest.LastItem(M.Suggest.ItemProvider))
  p.equip = Panel.Field(p, g.body, "equip", Locale:Get("macros.buildoptions.equip_first_weapon_shield.f8e266"), 168)
  Kit.Tooltip(p.equip, function() return { Locale:Get("macros.buildoptions.equip_first.7e2ae2"), Locale:Get("macros.buildoptions.swap_gear_before_the_spell_e_g.fdbd7e") } end)
  M.Suggest.Attach(p.equip, M.Suggest.LastItem(M.Suggest.ItemProvider))
  g.contentHeight = 200
end

local function Resets(p)
  local g = Panel.Group(p, Locale:Get("macros.buildoptions.sequence_reset.cc00d2"), true, true)
  p.resetGroup, p.resets = g, {}
  p.resetSeconds = Panel.Field(p, g.body, "resetSeconds", Locale:Get("macros.buildoptions.seconds_without_a_press_optional.3be761"), 20, 64)
  p.resetSeconds:SetMaxLetters(3)
  p.resetUnit = Theme.Text(g.body, "body", "textMuted")
  p.resetUnit:SetPoint("LEFT", p.resetSeconds, "RIGHT", 8, 0); Localization.Bind(p.resetUnit, "macros.buildoptions.sec.669fee")
  Kit.Tooltip(p.resetSeconds, function() return { Locale:Get("macros.buildoptions.reset_after_inactivity.4a2c90"), Locale:Get("macros.buildoptions.each_press_restarts_this_count_leave_empty.bdea73") } end)
  for i, r in ipairs(M.Config.RESETS) do
    p.resets[i] = Check(p, g, "reset_" .. r.key, r.button, 68 + (i - 1) * 38)
  end
  g.contentHeight = 252
end

local function Utility(p)
  local g = Panel.Group(p, Locale:Get("macros.buildoptions.utility_action.b7f6ea"), true, false)
  p.scriptGroup = g
  p.scriptAction = Kit.Select(g.body, { width = 260, menu = true, choices = M.Scripts.Choices(), value = "none",
    onChange = function(_, key)
      Panel.opts.scriptAction = key ~= "none" and key or nil
      p.scriptName:SetText(""); p.scriptCount:SetText("")
      Panel.Update()
    end })
  Panel.At(p, p.scriptAction, g.body, 0, 0, "full", 32)
  p.scriptName = Panel.Field(p, g.body, "scriptName", Locale:Get("highground.profiles.name.709a23"), 64)
  p.scriptCount = Panel.Field(p, g.body, "scriptCount", Locale:Get("macros.buildoptions.quantity_option_number.41c7b4"), 128)
  p.scriptCount:SetMaxLetters(4)
  Kit.Tooltip(p.scriptAction, function() return { Locale:Get("macros.buildoptions.utility_action.b7f6ea"), Locale:Get("macros.buildoptions.run_after_the_spell_or_on_its.8561cb") } end)
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
