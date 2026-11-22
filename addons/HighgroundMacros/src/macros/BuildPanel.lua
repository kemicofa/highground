local _, ns = ...
local Macros = ns.Macros
local Theme, Kit = Macros.Host.Theme, Macros.Host.Kit
Macros.BuildPanel = { opts = { name = "", spell = "" } }
local Panel = Macros.BuildPanel

-- A scrollable recipe beside an independent editor. Optional groups keep
-- their values when folded; the live explanation always describes them.
Panel.CAPTIONS = { cast = "Spell name", use = "Item name or equipment slot",
  castsequence = "Spells in order, comma separated", castrandom = "Spells, comma separated" }
-- The recipe's text fields (p[key]), cleared together and kept by navigation.
Panel.FIELDS = { "name", "spell", "rank", "unitName", "aura", "item", "resetSeconds", "scriptName", "scriptCount",
  "altSpell", "altRank", "sayText", "equip" }
-- Keep generous hit areas at small text sizes. At 150% the 40px controls
-- still fit the text; growing every gap further would crowd out review.
function Panel.Scale() return math.min(1.25, math.max(1, Macros.Host.FontScale())) end

-- A recipe group on a Kit.SectionCard: a titled card for the required
-- steps, a fold button (+/-, with its active count) for optional ones.
-- g.body holds the controls (Panel.At coordinates); folded, it hides.
function Panel.Group(p, title, optional, open)
  local g = CreateFrame("Frame", nil, p.form.body)
  g.optional, g.open, g.label = optional, open ~= false, title
  g.card = Kit.SectionCard(g, { title = not optional and title or nil })
  g.card:SetPoint("TOPLEFT")
  local inner = g.card.body
  if optional then
    g.header = Kit.Button(inner, title, 200, 32, { tone = "panel", onClick = function()
      g.open = not g.open
      Kit.Dropdown.Hide()
      Panel.Layout()
    end })
    g.header:SetPoint("TOPLEFT"); g.header:SetPoint("RIGHT")
    g.header.label:ClearAllPoints()
    g.header.label:SetPoint("LEFT", 12, 0)
    g.header.label:SetPoint("RIGHT", -8, 0)
    g.header.label:SetJustifyH("LEFT")
  end
  g.body = CreateFrame("Frame", nil, inner)
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
  local g = Panel.Group(p, "1. Choose an action")
  p.actionGroup, p.verbs = g, {}
  for i, v in ipairs({ { "cast", "Cast spell" }, { "use", "Use item" },
    { "castsequence", "Sequence" }, { "castrandom", "Random" } }) do
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
  Kit.Tooltip(spell, { "Spell or item", "Use its exact name. Click for suggestions; Tab inserts the selected match. "
    .. "You can also write or paste a macro directly in the editor." })
  local rank = Panel.Field(p, g.body, "rank", "Rank", 100, 44)
  p.placements[#p.placements][3] = "rank"
  rank:SetMaxLetters(2)
  rank:SetShown(Macros.Ranks.Supported())
  rank.caption:SetShown(Macros.Ranks.Supported())
  Kit.Tooltip(rank, { "Spell rank (optional)", "Leave empty for the highest rank. Set a number for a lower-rank spell." })
  g.contentHeight = 132
end

local function Target(p)
  local g = Panel.Group(p, "2. Choose a target")
  p.targetGroup = g
  local choices = { { key = "auto", label = "Normal spell targeting" } }
  for _, key in ipairs({ "target", "focus", "mouseover", "player", "cursor" }) do
    choices[#choices + 1] = { key = key, label = Macros.Config.UNITS[key].tip }
  end
  for i = 1, 4 do choices[#choices + 1] = { key = "party" .. i, label = "Party member " .. i } end
  for i = 1, Macros.ARENA_SIZE[Macros.Host.Game()] or 0 do
    choices[#choices + 1] = { key = "arena" .. i, label = "Arena enemy " .. i }
  end
  choices[#choices + 1] = { key = "name", label = "A named group member" }
  p.target = Kit.Select(g.body, { width = 260, menu = true, choices = choices, value = "auto",
    onChange = function(_, key)
      Panel.opts.target = key ~= "auto" and key or nil
      Panel.Update()
    end })
  Panel.At(p, p.target, g.body, 0, 0, "full", 32)
  p.of = Kit.Choice(g.body, "Cast on their target", 260, "check", function(self)
    if self.disabled then return end
    Panel.opts.of = not Panel.opts.of
    Panel.Update()
  end)
  Panel.At(p, p.of, g.body, 0, 40, "full", 32)
  Kit.Tooltip(p.of, function()
    local o = Panel.opts
    local name = o.target == "name" and Macros.Host.Trim(o.unitName) or o.target
    local token = name and name ~= "" and (name .. (o.target == "name" and "-target" or "target"))
    return { "Cast on the selected unit's target", "Works with focus, mouseover, party and arena units, or a named group member. "
      .. "Your current target stays selected.", token and ("Macro target: @" .. token) or "Enter the group member's name first." }
  end)
  p.targetHint = Theme.Text(g.body, "body", "textMuted")
  p.targetHint:SetJustifyH("LEFT"); p.targetHint:SetJustifyV("TOP"); p.targetHint:SetWordWrap(true)
  Panel.At(p, p.targetHint, g.body, 0, 40, "full", 36)
  p.unitName = Panel.Field(p, g.body, "unitName", "Player name (in your party or raid)", 104)
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
  local left = math.min(330 * scale, width * 0.45)
  p.form:SetWidth(left)
  p.right:ClearAllPoints()
  p.right:SetPoint("TOPLEFT", left + 24, 0)
  p.right:SetPoint("BOTTOMRIGHT")
  local card = math.max(180, left - 16)
  p.form.body:SetWidth(card)
  -- Controls fill a section card's inner width (Kit.SectionCard padding).
  local content = card - Theme.Space("lg") * 2
  local half = (content - 8) / 2
  for _, a in ipairs(p.placements) do
    local f, parent, x, y, w, h = unpack(a)
    local fx = x == "half" and half + 8 or x == "rank" and content - 44 * scale or x * scale
    local fw = w == "full" and content or w == "half" and half or w == "spell" and content - 52 * scale or w * scale
    -- The panel owns these controls: write only what changed since its last
    -- layout, without reading native geometry (typing rarely moves them).
    if a.left ~= fx or a.top ~= y * scale then
      a.left, a.top = fx, y * scale
      f:ClearAllPoints(); f:SetPoint("TOPLEFT", parent, "TOPLEFT", fx, -y * scale)
    end
    if a.width ~= fw then a.width = fw; f:SetWidth(fw) end
    if h and a.height ~= h * scale then a.height = h * scale; f:SetHeight(h * scale) end
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
      local top = g.optional and 40 * scale or 0 -- below the fold button
      g.body:SetShown(g.open)
      local inner = g.open and top + g.contentHeight * scale or 32 * scale
      -- Typing relayouts the recipe; an unchanged card keeps its geometry
      -- and measured height without native reads or writes.
      local key = card .. "|" .. inner .. "|" .. g.contentHeight * scale
      if g.cardKey ~= key then
        g.cardKey = key
        if g.header then g.header:SetHeight(32 * scale) end
        Kit.Place(g.body, "TOPLEFT", g.card.body, "TOPLEFT", 0, -top, content, g.contentHeight * scale)
        g.cardHeight = g.card:Layout(card, inner)
      end
      local h = g.cardHeight
      if g.placedAt ~= y or g.placedHeight ~= h or g.placedWidth ~= card then
        g.placedAt, g.placedHeight, g.placedWidth = y, h, card
        Kit.Place(g, "TOPLEFT", p.form.body, "TOPLEFT", 0, -y, card, h)
      end
      if g.optional then
        g.header:SetText((g.open and "-  " or "+  ") .. g.label .. (g.active > 0 and (" (" .. g.active .. ")") or ""))
      end
      y = y + h + 8 * scale
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
  -- Theme and text size change card fonts: measure every card again.
  local function Remeasure()
    for _, g in ipairs(p.groups) do g.cardKey, g.placedAt = nil, nil end
    Panel.Layout()
  end
  Theme.OnChange(Remeasure)
  Macros.Host.OnFontScaleChange(Remeasure)
  Panel.Layout()
  p:Hide()
end
