local _, ns = ...
local Locale, Localization = ns.Macros.Host.Messages, ns.Macros.Host.Localization
local Macros = ns.Macros
local Theme, Kit = Macros.Host.Theme, Macros.Host.Kit
Macros.BuildPanel = { opts = { name = "", spell = "" } }
local Panel = Macros.BuildPanel

-- A scrollable recipe beside an independent editor. Optional groups keep
-- their values when folded; the live explanation always describes them.
Panel.CAPTIONS = Localization.Define({ cast = Locale:Get("macros.buildpanel.spell_name.18fc9e"), use = Locale:Get("macros.buildpanel.item_name_or_equipment_slot.fc4cc9"),
  castsequence = Locale:Get("macros.buildpanel.spells_in_order_comma_separated.ab51b7"), castrandom = Locale:Get("macros.buildpanel.spells_comma_separated.9b4414") }, { cast = "macros.buildpanel.spell_name.18fc9e", use = "macros.buildpanel.item_name_or_equipment_slot.fc4cc9", castsequence = "macros.buildpanel.spells_in_order_comma_separated.ab51b7", castrandom = "macros.buildpanel.spells_comma_separated.9b4414" })
-- The recipe's text fields (p[key]), cleared together and kept by navigation.
Panel.FIELDS = { "name", "spell", "rank", "unitName", "aura", "item", "resetSeconds", "scriptName", "scriptCount",
  "altSpell", "altRank", "sayText", "equip" }
-- Keep generous hit areas at small text sizes. At 150% the 40px controls
-- still fit the text; growing every gap further would crowd out review.
function Panel.Scale() return math.min(1.25, math.max(1, Macros.Host.FontScale())) end

function Panel.Group(p, title, optional, open)
  local g = CreateFrame("Frame", nil, p.form.body)
  g.optional, g.open, g.title = optional, open ~= false, title
  if optional then
    g.header = Kit.Button(g, title, 200, 32, { tone = "panel", onClick = function()
      g.open = not g.open
      Kit.Dropdown.Hide()
      Panel.Layout()
    end })
  else
    g.header = CreateFrame("Frame", nil, g)
    g.header:SetSize(200, 32)
    g.header.label = Theme.Text(g.header, "heading", "titleText")
    g.header.label:SetText(title)
  end
  g.header:SetPoint("TOPLEFT"); g.header:SetPoint("RIGHT")
  g.header.label:ClearAllPoints()
  g.header.label:SetPoint("LEFT", optional and 12 or 0, 0)
  g.header.label:SetPoint("RIGHT", -8, 0)
  g.header.label:SetJustifyH("LEFT")
  g.body = CreateFrame("Frame", nil, g)
  g.body:SetPoint("TOPLEFT", 0, -40)
  g.body:SetPoint("RIGHT")
  g.contentHeight, g.active = 0, 0
  p.groups[#p.groups + 1] = g
  return g
end

-- Coordinates in the recipe scale with the player's text size.
function Panel.At(p, control, parent, x, y, width, height)
  p.placements[#p.placements + 1] = { control, parent, x, y, width, height }
  return control
end
function Panel.Field(p, parent, key, label, y, width)
  local f = Kit.Input(parent, type(width) == "number" and width or 260, label)
  Panel.At(p, f, parent, 0, y, width or "full", 32)
  p[key] = f
  p.inputs[#p.inputs + 1] = f
  f:SetScript("OnTextChanged", function(self)
    Panel.opts[key] = self:GetText()
    Panel.Update()
  end)
  return f
end

local function Action(p)
  local g = Panel.Group(p, Locale:Get("macros.buildpanel.1_choose_an_action.f17152"))
  p.actionGroup, p.verbs = g, {}
  for i, v in ipairs({ { "cast", Locale:Get("macros.buildpanel.cast_spell.26627e") }, { "use", Locale:Get("macros.buildpanel.use_item.f76d18") },
    { "castsequence", Locale:Get("macros.buildpanel.sequence.5c8f4e") }, { "castrandom", Locale:Get("macros.buildpanel.random.58d888") } }) do
    local b = Kit.Choice(g.body, v[2], 130, "radio", function(self)
      Panel.opts.verb = self.value
      p.spell.caption:SetText(Panel.CAPTIONS[self.value])
      Panel.Update()
    end)
    b.value = v[1]
    Panel.At(p, b, g.body, (i - 1) % 2 == 0 and 0 or "half", math.floor((i - 1) / 2) * 38, "half", 32)
    p.verbs[i] = b
  end
  local spell = Panel.Field(p, g.body, "spell", Panel.CAPTIONS.cast, 100, Macros.Ranks.Supported() and "spell" or nil)
  spell:SetScript("OnTextChanged", function(self) Panel.opts.spell = self:GetText(); Panel.Update() end)
  Macros.Suggest.Attach(spell, function(text)
    local verb = Panel.opts.verb
    if verb == "use" then return Macros.Suggest.ItemProvider(text) end
    local provider = Macros.Suggest.SpellProvider
    if verb == "castsequence" or verb == "castrandom" then provider = Macros.Suggest.LastItem(provider) end
    return provider(text)
  end)
  Kit.Tooltip(spell, function() return { Locale:Get("macros.buildpanel.spell_or_item.6b8104"), Locale:Get("macros.buildpanel.use_its_exact_name_click_for_suggestions.ced43e") } end)
  local rank = Panel.Field(p, g.body, "rank", Locale:Get("macros.buildoptions.rank.dd48a1"), 100, 44)
  p.placements[#p.placements][3] = "rank"
  rank:SetMaxLetters(2)
  rank:SetShown(Macros.Ranks.Supported())
  rank.caption:SetShown(Macros.Ranks.Supported())
  Kit.Tooltip(rank, function() return { Locale:Get("macros.buildpanel.spell_rank_optional.50986b"), Locale:Get("macros.buildpanel.leave_empty_for_the_highest_rank_set.5c2b91") } end)
  g.contentHeight = 132
end

local function Target(p)
  local g = Panel.Group(p, Locale:Get("macros.buildpanel.2_choose_a_target.97e399"))
  p.targetGroup = g
  local choices = { { key = "auto", label = Locale:Get("macros.buildpanel.normal_spell_targeting.124553") } }
  for _, key in ipairs({ "target", "focus", "mouseover", "player", "cursor" }) do
    choices[#choices + 1] = { key = key, label = Macros.Config.UNITS[key].tip }
  end
  for i = 1, 4 do choices[#choices + 1] = { key = "party" .. i, label = Locale:Format("macros.buildpanel.party_member_i.1f1105", { i = i }) } end
  for i = 1, Macros.ARENA_SIZE[Macros.Host.Game()] or 0 do
    choices[#choices + 1] = { key = "arena" .. i, label = Locale:Format("macros.buildpanel.arena_enemy_i.42da6a", { i = i }) }
  end
  choices[#choices + 1] = { key = "name", label = Locale:Get("macros.buildpanel.a_named_group_member.614f32") }
  p.target = Kit.Select(g.body, { width = 260, menu = true, choices = choices, value = "auto",
    onChange = function(_, key)
      Panel.opts.target = key ~= "auto" and key or nil
      Panel.Update()
    end })
  Panel.At(p, p.target, g.body, 0, 0, "full", 32)
  p.of = Kit.Choice(g.body, Locale:Get("macros.buildpanel.cast_on_their_target.5742a9"), 260, "check", function(self)
    if self.disabled then return end
    Panel.opts.of = not Panel.opts.of
    Panel.Update()
  end)
  Panel.At(p, p.of, g.body, 0, 40, "full", 32)
  Kit.Tooltip(p.of, function()
    local o = Panel.opts
    local name = o.target == "name" and Macros.Host.Trim(o.unitName) or o.target
    local token = name and name ~= "" and (name .. (o.target == "name" and "-target" or "target"))
    return { Locale:Get("macros.buildpanel.cast_on_the_selected_unit_s_target.71d8fc"), Locale:Get("macros.buildpanel.works_with_focus_mouseover_party_and_arena.9555ba"), token and (Locale:Format("macros.buildpanel.macro_target_token.2c4b11", { token = token })) or Locale:Get("macros.buildpanel.enter_the_group_member_s_name_first.769274") }
  end)
  p.targetHint = Theme.Text(g.body, "body", "textMuted")
  p.targetHint:SetJustifyH("LEFT"); p.targetHint:SetJustifyV("TOP"); p.targetHint:SetWordWrap(true)
  Panel.At(p, p.targetHint, g.body, 0, 40, "full", 36)
  p.unitName = Panel.Field(p, g.body, "unitName", Locale:Get("macros.buildpanel.player_name_in_your_party_or_raid.84c973"), 104)
  p.unitName:SetScript("OnTextChanged", function(self)
    Panel.opts.unitName = self:GetText()
    if Panel.opts.unitName:match("%S") then Panel.opts.target = "name" end
    Panel.Update()
  end)
  g.contentHeight = 76
end

function Panel.Layout()
  local p = Panel.frame
  if not p or p.layingOut then return end
  p.layingOut = true
  local scale, width = Panel.Scale(), p:GetWidth()
  local left = math.min(306 * scale, width * 0.43)
  p.form:SetWidth(left)
  p.right:ClearAllPoints()
  p.right:SetPoint("TOPLEFT", left + 24, 0)
  p.right:SetPoint("BOTTOMRIGHT")
  local content = math.max(180, left - 16)
  p.form.body:SetWidth(content)
  for _, a in ipairs(p.placements) do
    local f, parent, x, y, w, h = unpack(a)
    f:ClearAllPoints()
    local half = (content - 8) / 2
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", x == "half" and half + 8 or x == "rank" and content - 44 * scale or x * scale, -y * scale)
    f:SetWidth(w == "full" and content or w == "half" and half or w == "spell" and content - 52 * scale or w * scale)
    if h then f:SetHeight(h * scale) end
    if f == p.targetHint then
      local height = math.max(36 * scale, f:GetStringHeight())
      f:SetHeight(height)
      p.targetGroup.contentHeight = y + height / scale
    end
  end
  local y = 0
  for _, g in ipairs(p.groups) do
    g:SetShown(not g.hidden)
    if not g.hidden then
      g:ClearAllPoints(); g:SetPoint("TOPLEFT", 0, -y)
      g:SetWidth(content)
      g.header:SetHeight(32 * scale)
      g.body:ClearAllPoints(); g.body:SetPoint("TOPLEFT", 0, -40 * scale); g.body:SetPoint("RIGHT")
      g.body:SetHeight(g.contentHeight * scale)
      g.body:SetShown(g.open)
      local h = (g.open and g.contentHeight + 40 or 32) * scale
      g:SetHeight(h)
      if g.optional then
        g.header:SetText((g.open and "-  " or "+  ") .. g.title .. (g.active > 0 and (" (" .. g.active .. ")") or ""))
      end
      y = y + h + 12 * scale
    end
  end
  p.form.body:SetHeight(math.max(1, y))
  p.form:Refresh()
  if Panel.LayoutEditor then Panel.LayoutEditor() end
  p.layingOut = nil
end

function Panel.Create(w, top)
  local p = CreateFrame("Frame", nil, w)
  p:SetPoint("TOPLEFT", 24, -top - 10)
  p:SetPoint("BOTTOMRIGHT", -24, 24)
  Panel.frame = p
  p.groups, p.placements, p.inputs = {}, {}, {}
  p.form = Kit.ScrollArea(p)
  p.form:SetPoint("TOPLEFT"); p.form:SetPoint("BOTTOMLEFT")
  p.right = CreateFrame("Frame", nil, p)
  p.right.bg = Theme.Fill(p.right, "BACKGROUND", "surface")
  p.right.bg:SetPoint("TOPLEFT", -12, 12); p.right.bg:SetPoint("BOTTOMRIGHT", 12, -12)
  p.right.edge = Kit.Outline(p.right, "border", -12)
  p.right.bevel = Kit.Bevel(p.right, -11)
  Action(p)
  Target(p)
  Panel.Options(p)
  Panel.Editor(p)
  p:SetScript("OnSizeChanged", Panel.Layout)
  p:HookScript("OnHide", function()
    Kit.Dropdown.Hide()
    for _, field in ipairs(p.inputs) do field:ClearFocus() end
  end)
  Theme.OnChange(Panel.Layout)
  Macros.Host.OnFontScaleChange(Panel.Layout)
  Panel.Layout()
  p:Hide()
end
