local _, ns = ...
local Macros, Theme, Kit = ns.Macros, ns.Theme, ns.Kit
local Win = Macros.Window
local S, Z = Theme.Space, Theme.Size

---------------------------------------------------------------------------
-- Macro cards: name, class or scope, description, macro text, status,
-- General / Character buttons and target variant buttons. A card shows a
-- catalog entry or one of your existing macros (Win.Fill).
---------------------------------------------------------------------------
local TEXT_RIGHT = 170 -- room for the status and buttons

function Win.NewCard(parent)
  local r = Kit.Card(parent, Win.CARD_H, { strip = "gold", titleRole = "rowName",
    onEnter = function(self) Win.Explain(self) end, onLeave = function() GameTooltip_Hide() end })
  r.name = r.title
  r.sub:Hide()
  r.class = Theme.Text(r, "caption", "textMuted")
  r.class:SetPoint("LEFT", r.name, "RIGHT", S("sm") + S("xs"), 0)
  r.desc = Theme.Text(r, "body", "textMuted")
  r.desc:SetPoint("TOPLEFT", S("lg"), -24)
  r.desc:SetPoint("RIGHT", r, "RIGHT", -TEXT_RIGHT, 0)
  r.desc:SetJustifyH("LEFT")
  r.body = Theme.Text(r, "label")
  r.body:SetPoint("TOPLEFT", S("lg"), -40)
  r.body:SetPoint("RIGHT", r, "RIGHT", -TEXT_RIGHT, 0)
  r.body:SetJustifyH("LEFT")
  r.body:SetJustifyV("TOP")
  r.body:SetWordWrap(true)
  r.body:SetHeight(38)
  r.status = Theme.Text(r, "caption")
  r.status:SetPoint("TOPRIGHT", -S("md"), -S("md"))
  r.status:SetWidth(TEXT_RIGHT - 20)
  r.status:SetJustifyH("RIGHT")
  local h = Z("row")
  r.general = Kit.Button(r, "General", 74, h, { tone = "panel", onClick = function(self)
    local e = self.card.entry
    if e.existing then Win.Edit(e) else Win.Copy(e, false) end
  end })
  r.general:SetPoint("BOTTOMRIGHT", -84, S("md"))
  r.character = Kit.Button(r, "Character", 74, h, { tone = "panel", onClick = function(self)
    local e = self.card.entry
    if e.existing then Win.Save(e.name, e.body, not e.perCharacter) else Win.Copy(e, true) end
  end })
  r.character:SetPoint("BOTTOMRIGHT", -(S("sm") + S("xs")), S("md"))
  r.general.card, r.character.card = r, r
  r.variants = {}
  for i = 1, 4 do
    local b = Kit.Button(r, "", Win.VARIANT_W, Z("icon"), { tone = "panel", onClick = function(self)
      local e = self.card.entry
      if e.existing then return Macros.Share.ShowExport({ e }) end
      Win.variant[e] = self.target
      Win.Refresh()
    end })
    b:SetPoint("TOPRIGHT", r, "TOPRIGHT", -(S("sm") + S("xs")) - (4 - i) * (Win.VARIANT_W + 3), -28)
    b.card = r
    r.variants[i] = b
  end
  r:Hide()
  return r
end

-- A variant button: fill = where that variant is saved, gold outline and
-- label = the variant the card shows and copies.
function Win.PaintVariant(b, where, selected)
  if not b.ring then
    local edge = Z("underline")
    b.ring = {}
    for i, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" },
      { "TOPLEFT", "BOTTOMLEFT", true }, { "TOPRIGHT", "BOTTOMRIGHT", true } }) do
      local t = Theme.Fill(b, "OVERLAY", "gold")
      t:SetPoint(side[1])
      t:SetPoint(side[2])
      if side[3] then t:SetWidth(edge) else t:SetHeight(edge) end
      b.ring[i] = t
    end
    b.both = Theme.Fill(b, "ARTWORK", Win.SCOPE_TOKEN.character)
    b.both:SetPoint("BOTTOMLEFT", edge, edge)
    b.both:SetPoint("BOTTOMRIGHT", -edge, edge)
    b.both:SetHeight(Z("strip"))
  end
  local fill = (where == "general" or where == "both") and Win.SCOPE_TOKEN.general
    or where == "character" and Win.SCOPE_TOKEN.character or "panel"
  Kit.Paint(b, fill, selected and "gold" or "text")
  for _, t in ipairs(b.ring) do t:SetShown(selected) end
  b.both:SetShown(where == "both")
  b.where, b.selected = where, selected
end

-- Hover: what the macro does, compiled from its text.
function Win.Explain(r)
  if not r.entry then return end
  local o = r.entry.existing and r.entry or Win.Resolve(r.entry)
  local body = r.entry.existing and r.entry.body or Macros.Build(o)
  if not body then return end
  local result = Macros.Analyze(body, { pet = o.pet })
  GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
  Win.TipLine(o.name, "gold")
  for _, line in ipairs(Macros.Explain(result)) do Win.TipLine(line, "text", true) end
  for _, pr in ipairs(result.problems) do
    Win.TipLine((pr.level == "error" and "Error: " or "Note: ") .. pr.text, "warning", true)
  end
  GameTooltip:Show()
end

local function Plural(n, word) return n .. " " .. word .. (n > 1 and "S" or "") end

-- An existing macro: compiled to show whether it is sound.
local function FillExisting(r, e)
  r.entry = e
  r:SetStrip("accent")
  r.name:SetText(e.name)
  Theme.Paint(r.name, "text")
  r.class:SetText(e.perCharacter and "CHARACTER" or "GENERAL")
  local result = Macros.Analyze(e.body)
  local explain = Macros.Explain(result)
  r.desc:SetText(explain[#explain] or "")
  r.body:SetText(e.body)
  local text, color = "OK", "success"
  if result.errors > 0 then
    text, color = Plural(result.errors, "ERROR"), "danger"
  elseif result.warnings > 0 then
    text, color = Plural(result.warnings, "WARNING"), "warning"
  end
  r.status:SetText(text)
  Theme.Paint(r.status, color)
  r.general:SetText("Edit")
  r.character:SetText(e.perCharacter and "To General" or "To Character")
  for i, b in ipairs(r.variants) do b:SetShown(i == 1) end
  local share = r.variants[1]
  share.target = nil
  share:SetWidth(Win.EXPORT_W) -- the variant buttons are too narrow for the word
  share:SetText("EXPORT")
  Kit.Paint(share, "panel")
  if share.ring then
    for _, t in ipairs(share.ring) do t:Hide() end
    share.both:Hide()
  end
  r:Show()
end

-- Class colours are game data, not theme tokens.
local function ClassRgb(class)
  local cc = class and ns.Util.ClassColor(class)
  return cc and { cc.r, cc.g, cc.b }
end

function Win.Fill(r, entry)
  if entry.existing then return FillExisting(r, entry) end
  r.general:SetText("General")
  r.character:SetText("Character")
  r.entry = entry
  local o = Win.Resolve(entry)
  local cc = ClassRgb(entry.class)
  r:SetStrip(cc or "gold")
  r.name:SetText(o.name)
  Theme.Paint(r.name, cc or "text")
  r.class:SetText(entry.class and (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[entry.class] or entry.class):upper()
    or "GENERAL")
  r.desc:SetText(entry.desc or "")
  r.body:SetText(Macros.Build(o) or "")
  local text, color = Win.Status(entry)
  r.status:SetText(text)
  Theme.Paint(r.status, color)
  local chosen = Win.variant[entry] or entry.target
  local list = Win.Variants(entry)
  for i, b in ipairs(r.variants) do
    b:SetWidth(Win.VARIANT_W)
    local v = list and list[i]
    b.target = v and v[1]
    b:SetText(v and v[2] or "")
    b:SetShown(v ~= nil)
    if v then Win.PaintVariant(b, Win.SavedIn(Macros.VariantName(entry.name, v[1])), v[1] == chosen) end
  end
  r:Show()
end
