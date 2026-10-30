local _, ns = ...
local Macros = ns.Macros
local Host, Win = Macros.Host, Macros.Window
local Theme, Kit = Host.Theme, Host.Kit

-- A preset has one primary action. Target names are written out; editing,
-- account-wide copies and sharing live in its secondary menu.
function Win.CardOptions(r)
  local e = r.entry
  if not e then return end
  local items
  if e.existing then
    items = {
      { text = e.perCharacter and "Copy to all characters" or "Copy to this character", run = function()
        Win.Save(e.name, e.body, not e.perCharacter)
      end },
      { text = "Export macro", run = function() Macros.Share.ShowExport({ e }) end },
    }
  else
    items = {
      { text = "Customize macro", run = function() Win.CopyEdit(e) end },
      { text = "Save for all characters", run = function() Win.Copy(e, false) end },
    }
    if Macros.Find(Win.Resolve(e).name, true) then
      items[#items + 1] = { text = "Replace saved macro with this preset", run = function() Win.Copy(e, true) end }
    end
  end
  Kit.Dropdown.Open(r.more, items, function(item) item.run() end,
    { width = 300 * math.max(1, Host.FontScale()) })
end

function Win.NewCard(parent)
  local r = Kit.Card(parent, Win.CARD_H, { strip = "gold", titleRole = "cardName" })
  Kit.Tooltip(r, Win.Explain, { anchor = "ANCHOR_RIGHT" })
  r.name = r.title
  r.sub:Hide()
  r.desc = Theme.Text(r, "body", "textMuted")
  r.desc:SetJustifyH("LEFT"); r.desc:SetJustifyV("TOP"); r.desc:SetWordWrap(true)
  r.status = Theme.Text(r, "caption", "textMuted")
  r.status:SetJustifyH("RIGHT"); r.status:SetWordWrap(false)
  r.use = Kit.Button(r, "Use macro", 132, 28, { tone = "accent", onClick = function()
    local e = r.entry
    if not e then return end
    local saved = e.existing and e or Macros.Find(Win.Resolve(e).name, true)
    if saved then Win.Edit(saved) else Win.Copy(e, true) end
  end })
  Kit.Tooltip(r.use, function()
    return { r.use:GetText(), r.entry and r.entry.existing and "Edit this saved macro."
      or "Save for this character. Then open WoW macros and drag its icon to an action bar. A saved macro opens for editing instead of being replaced." }
  end)
  r.more = Kit.Button(r, "More", 72, 28, { onClick = function() Win.CardOptions(r) end })
  Kit.Tooltip(r.more, { "More options", "Customize, save for all characters, or export a saved macro." })
  r.target = Kit.Select(r, { width = 220, menu = true, choices = {}, onChange = function(_, key)
    if r.entry then Win.variant[r.entry] = key; Win.Refresh() end
  end })
  Kit.Tooltip(r.target, function()
    local t = Win.TARGET_TIPS[r.target:GetValue()]
    return t and { "Target: " .. t[1], t[2], "Changing this choice previews a version; it does not change a saved macro." }
  end)
  r:Hide()
  return r
end

function Win.LayoutCard(r, scale)
  r:SetHeight(Win.CARD_H * scale)
  local pad, h = 12, 28 * scale
  r.name:ClearAllPoints(); r.name:SetPoint("TOPLEFT", pad, -8 * scale)
  r.name:SetPoint("RIGHT", -220 * scale, 0); r.name:SetWordWrap(false)
  r.status:ClearAllPoints(); r.status:SetPoint("TOPRIGHT", -pad, -12 * scale)
  r.status:SetWidth(210 * scale)
  r.desc:ClearAllPoints(); r.desc:SetPoint("TOPLEFT", pad, -34 * scale)
  r.desc:SetPoint("RIGHT", -pad, 0); r.desc:SetHeight(34 * scale)
  r.use:ClearAllPoints(); r.use:SetPoint("BOTTOMRIGHT", -pad, 8 * scale)
  r.use:SetSize(132 * scale, h)
  r.more:ClearAllPoints(); r.more:SetPoint("RIGHT", r.use, "LEFT", -8, 0)
  r.more:SetSize(72 * scale, h)
  r.target:ClearAllPoints(); r.target:SetPoint("BOTTOMLEFT", pad, 8 * scale)
  r.target:SetPoint("RIGHT", r.more, "LEFT", -12, 0)
  r.target:SetHeight(h)
end

-- Full explanations remain on hover and in the editor, rather than showing
-- source code on every card before the player has chosen a macro.
function Win.Explain(r)
  if not r.entry then return nil end
  local o = r.entry.existing and r.entry or Win.Resolve(r.entry)
  local body = r.entry.existing and r.entry.body or Macros.Build(o)
  if not body then return nil end
  local result = Macros.Analyze(body, { pet = o.pet })
  local lines = { { o.name, "gold" } }
  for _, line in ipairs(Macros.Explain(result)) do lines[#lines + 1] = { line, "text", true } end
  for _, pr in ipairs(result.problems) do
    lines[#lines + 1] = { (pr.level == "error" and "Error: " or "Note: ") .. pr.text, "warning", true }
  end
  return lines
end

function Win.Fill(r, entry)
  r.entry = entry
  local o = entry.existing and entry or Win.Resolve(entry)
  r.name:SetText(entry.name)
  Theme.Paint(r.name, "text")
  local cc = entry.class and Host.ClassColor(entry.class)
  r:SetStrip(cc and { cc.r, cc.g, cc.b } or "accent")
  local text, color
  if entry.existing then
    local result = Macros.Analyze(entry.body)
    local explain = Macros.Explain(result)
    r.desc:SetText(explain[#explain] or "Open this macro to review its actions.")
    text, color = entry.perCharacter and "This character" or "All characters", "textMuted"
    if result.errors > 0 then text, color = "Needs editing", "warning" end
  else
    local target = Win.TARGET_TIPS[o.target or ""]
    local class = Win.tab == "all" and entry.class and Host.ClassName(entry.class)
    r.desc:SetText((class and (class .. " · ") or "") .. (entry.desc or "Hover for an explanation.")
      .. (target and ("\n" .. target[2]) or ""))
    text, color = Win.Status(entry)
  end
  r.status:SetText(text); Theme.Paint(r.status, color)
  local saved = entry.existing or (Win.saved[o.name] and Win.saved[o.name].character)
  r.use:SetText(saved and "Edit macro" or "Use macro")
  r.use:SetEnabled(not not saved or not InCombatLockdown())
  if InCombatLockdown() and not saved then r.status:SetText("Save after combat"); Theme.Paint(r.status, "warning") end
  local choices, variants = {}, not entry.existing and Win.Variants(entry)
  for _, list in ipairs({ variants or {}, not entry.existing and Win.MoreVariants(entry) or {} }) do
    for _, variant in ipairs(list) do
      local tip = Win.TARGET_TIPS[variant[1]]
      choices[#choices + 1] = { key = variant[1], label = tip and tip[1] or variant[1] }
    end
  end
  r.target:SetChoices(choices)
  r.target:SetValue(not entry.existing and (Win.variant[entry] or entry.target) or nil, true)
  r.target:SetShown(#choices > 0)
  r:Show()
end
Theme.OnChange(Win.Refresh)
Host.Events({ PLAYER_REGEN_DISABLED = Win.Refresh, PLAYER_REGEN_ENABLED = Win.Refresh }, "macro cards")
