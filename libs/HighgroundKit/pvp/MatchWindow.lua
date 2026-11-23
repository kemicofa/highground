local _, ns = ...
local H, U, Kit, T = ns.MatchHistory, ns.Util, ns.Kit, ns.Theme

local RESULTS = ns.Localization.Define({}, {
  ["Win"] = "highground.coachrecords.win.4973f4",
  ["Loss"] = "shared.copy.loss.12e24a",
  ["Completed"] = "shared.copy.completed.1798b3",
  ["Left early"] = "highground.coachrecords.left_early.3e26fd",
})
local TONES = { Win = "success", Loss = "danger", ["Left early"] = "warning" }

-- Scoreboard stats as tiles: { field, label key, value tone }. Stats the
-- game did not report stay out; a rating change shows only when it moved.
local STATS = {
  { "killingBlows", "shared.matchwindow.killing_blows.a52d07", "success" },
  { "honorableKills", "shared.matchwindow.honorable_kills.028a89", "info" },
  { "deaths", "shared.matchwindow.deaths.41cd88", "danger" },
  { "honorGained", "shared.matchwindow.honor.01e896", "gold" },
  { "damageDone", "highground.setup.damage.7bf6d1", "text" },
  { "healingDone", "shared.matchwindow.healing.87272f", "text" },
  { "ratingChange", "shared.matchwindow.rating_change.60e13f" },
}
local COLUMNS, EVENTS = 3, 11

local function Result(match) return RESULTS[match.result] or match.result or "" end
local function Spec(match)
  local info = match.spec and ns.Core.specInfo and ns.Core.specInfo[match.spec]
  return info, match.specName or info and info.name
end
local function Number(n)
  return BreakUpLargeNumbers and BreakUpLargeNumbers(n) or tostring(n)
end

-- Only constrain width; native text measures every line (as in the journal).
local function Place(fs, text, x, y, width)
  fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", x, -y)
  fs:SetWidth(math.max(1, width)); fs:SetText(text)
  return fs:GetStringHeight()
end

function H.Entries(records)
  local entries, wins, losses = {}, 0, 0
  for _, match in ipairs(records or H.All()) do
    if match.result == "Win" then wins = wins + 1 elseif match.result == "Loss" then losses = losses + 1 end
    local result, _, specName = Result(match), Spec(match)
    entries[#entries + 1] = { key = match.id, title = match.name, match = match,
      summary = result .. " · " .. U.Clock(match.duration or 0),
      search = match.name .. " " .. result .. " " .. ns.Core.DisplayName(match.character, true) .. " "
        .. tostring(match.spec or "") .. " " .. (specName or "") }
  end
  local summary = ns.Locale:Format("shared.matchwindow.wins_wins_losses_losses_value3_win_rate.aad517", { wins = string.format("%d", wins), losses = string.format("%d", losses), value3 = string.format("%.0f", wins + losses > 0 and wins / (wins + losses) * 100 or 0) })
  if not records then H.summary = summary end
  return entries, summary
end

local function Profile(w)
  local p = CreateFrame("Frame", nil, w.detailBody)
  p:SetPoint("TOPLEFT")
  p.hero = Kit.Hero(p)
  p.hero:SetPoint("TOPLEFT")
  p.emblem = CreateFrame("Frame", nil, p.hero)
  T.Fill(p.emblem, "BACKGROUND", "well"):SetAllPoints()
  p.emblem.edge = Kit.Outline(p.emblem, "borderAccent")
  p.icon = p.emblem:CreateTexture(nil, "ARTWORK")
  p.icon:SetPoint("TOPLEFT", 5, -5); p.icon:SetPoint("BOTTOMRIGHT", -5, 5)
  p.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  p.state = Kit.Paragraph(p.hero, "caption", "textMuted", { nonSpaceWrap = true })
  p.name = Kit.Paragraph(p.hero, "displayLarge", "text", { nonSpaceWrap = true })
  p.player = Kit.Paragraph(p.hero, "body", "text", { nonSpaceWrap = true })
  p.when = Kit.Paragraph(p.hero, "note", "textMuted", { nonSpaceWrap = true })
  p.stats = CreateFrame("Frame", nil, p)
  T.Fill(p.stats, "BACKGROUND", "well"):SetAllPoints()
  p.metrics = {}
  for i = 1, #STATS do
    local cell = CreateFrame("Frame", nil, p.stats)
    cell.value = Kit.Paragraph(cell, "readout", "text"); cell.value:SetJustifyH("CENTER")
    cell.label = Kit.Paragraph(cell, "caption", "textMuted"); cell.label:SetJustifyH("CENTER")
    cell.rule = T.Fill(cell, "ARTWORK", "border")
    cell.rule:SetPoint("TOPLEFT", 0, -12); cell.rule:SetPoint("BOTTOMLEFT", 0, 12); cell.rule:SetWidth(1)
    p.metrics[i] = cell
  end
  p.eventsLabel = Kit.Paragraph(p, "caption", "textMuted")
  p.eventsNote = Kit.Paragraph(p, "note", "textMuted")
  p.events = {}
  for i = 1, EVENTS do
    p.events[i] = { at = T.Text(p, "code", "textMuted"), text = Kit.Paragraph(p, "body", "text", { nonSpaceWrap = true }) }
    p.events[i].at:SetJustifyH("LEFT"); p.events[i].at:SetJustifyV("TOP")
  end
  return p
end

-- Result card, scoreboard tiles, then the latest observed objectives with
-- times in their own column so wrapped lines keep a hanging indent.
local function RenderDetail(entry, w, width)
  w.profile = w.profile or Profile(w)
  local p = w.profile
  p:SetShown(entry ~= nil)
  if not entry then return end
  local match, pad = entry.match, 14
  local info, specName = Spec(match)
  local scale = math.max(1, ns.Core.FontScale())
  local icon = info and info.icon and 52 * math.min(scale, 1.25) or 0
  local x, y = pad + (icon > 0 and icon + 14 or 0), pad
  p:SetWidth(width); p.hero:SetWidth(width)
  p.hero:SetTone(TONES[match.result] or "accent")
  p.emblem:SetShown(icon > 0)
  if icon > 0 then
    p.emblem:SetPoint("TOPLEFT", pad, -pad); p.emblem:SetSize(icon, icon)
    p.icon:SetTexture(info.icon)
  end
  local inner = width - x - pad
  y = y + Place(p.state, ns.Text.Upper(Result(match)), x, y, inner) + 6
  T.Paint(p.state, TONES[match.result] or "textMuted")
  y = y + Place(p.name, match.name, x, y, inner) + 5
  local player = ns.Core.DisplayName(match.character, true)
  y = y + Place(p.player, specName and specName .. " · " .. player or player, x, y, inner) + 5
  y = y + Place(p.when, ns.Locale:Format("shared.matchwindow.joined_value2.4132f0", { value2 = date("%Y-%m-%d %H:%M", match.started) })
    .. " · " .. ns.Locale:Format("shared.matchwindow.duration_value2.58b84c", { value2 = U.Clock(match.duration or 0) }), x, y, inner)
  y = math.max(y, pad + icon) + pad
  p.hero:SetHeight(y)

  local shown, stats = 0, match.stats or {}
  for _, cell in ipairs(p.metrics) do cell:Hide() end
  for _, stat in ipairs(STATS) do
    local value = stats[stat[1]]
    if type(value) == "number" and (stat[1] ~= "ratingChange" or value ~= 0) then
      shown = shown + 1
      local cell = p.metrics[shown]
      cell.key = stat[1]
      cell.value:SetText((stat[1] == "ratingChange" and value > 0 and "+" or "") .. Number(value))
      T.Paint(cell.value, stat[3] or (value > 0 and "success" or "danger"))
      cell.label:SetText(ns.Locale:Get(stat[2]))
      cell:Show()
    end
  end
  p.stats:SetShown(shown > 0)
  if shown > 0 then
    local rows, cellWidth, top = math.ceil(shown / COLUMNS), width / COLUMNS, 0
    p.stats:SetPoint("TOPLEFT", 0, -y); p.stats:SetWidth(width)
    for row = 1, rows do
      local rowHeight = 0
      for column = 1, COLUMNS do
        local cell = p.metrics[(row - 1) * COLUMNS + column]
        if cell and cell:IsShown() then
          local height = 12 + Place(cell.value, cell.value:GetText(), 6, 12, cellWidth - 12) + 5
          rowHeight = math.max(rowHeight, height + Place(cell.label, cell.label:GetText(), 6, height, cellWidth - 12) + 12)
        end
      end
      for column = 1, COLUMNS do
        local cell = p.metrics[(row - 1) * COLUMNS + column]
        if cell and cell:IsShown() then
          cell:SetPoint("TOPLEFT", (column - 1) * cellWidth, -top); cell:SetSize(cellWidth, rowHeight)
          cell.rule:SetShown(column > 1)
        end
      end
      top = top + rowHeight
    end
    p.stats:SetHeight(top)
    y = y + top
  end
  y = y + 20

  local events = match.events or {}
  inner = width - pad * 2
  y = y + Place(p.eventsLabel, ns.Locale:Get("shared.matchwindow.observed_objectives.b5d775"), pad, y, inner) + 8
  local first = math.max(1, #events - EVENTS + 1)
  local note = #events == 0 and ns.Locale:Get("shared.matchwindow.no_objective_events_were_observed.bf34dd")
    or first > 1 and ns.Locale:Format("shared.matchwindow.latest_count_of_total_full_timeline_lists.87b132",
      { count = string.format("%d", EVENTS), total = string.format("%d", #events) })
  p.eventsNote:SetShown(note and true or false)
  if note then y = y + Place(p.eventsNote, note, pad, y, inner) + 8 end
  local column = 0
  for i, line in ipairs(p.events) do
    line.event = events[first + i - 1]
    line.at:SetShown(line.event ~= nil); line.text:SetShown(line.event ~= nil)
    if line.event then
      line.at:SetText(U.Clock(line.event.at))
      column = math.max(column, line.at:GetStringWidth())
    end
  end
  column = math.ceil(column) + 10
  for _, line in ipairs(p.events) do
    if line.event then
      line.at:ClearAllPoints(); line.at:SetPoint("TOPLEFT", pad, -y)
      y = y + math.max(line.at:GetStringHeight(), Place(line.text, line.event.text, pad + column, y, inner - column)) + 6
    end
  end
  y = y + pad
  p:SetHeight(y)
  return y
end

local function RenderRow(row, entry)
  if not row.icon then
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.when = Kit.Paragraph(row, "note", "textMuted"); row.when:SetWordWrap(false)
    T.SetRole(row.label, "rowName")
  end
  local match = entry.match
  local info = Spec(match)
  local scale = math.max(1, ns.Core.FontScale())
  local size = 28 * scale
  local x = info and info.icon and 12 + size + 10 or 12
  row.icon:SetShown(info and info.icon ~= nil)
  if info and info.icon then row.icon:SetTexture(info.icon); row.icon:SetSize(size, size); row.icon:SetPoint("LEFT", 12, 0) end
  row.label:ClearAllPoints(); row.label:SetPoint("TOPLEFT", x, -7 * scale)
  row.label:SetWidth(row:GetWidth() - x - 12)
  row.summary:ClearAllPoints(); row.summary:SetPoint("TOPLEFT", x, -25 * scale)
  row.summary:SetWidth(row:GetWidth() - x - 12); row.summary:SetWordWrap(false)
  T.Paint(row.summary, TONES[match.result] or "textMuted")
  T.Paint(row.classStrip, TONES[match.result] or "border", TONES[match.result] and 1 or 0)
  Place(row.when, date("%Y-%m-%d %H:%M", match.started), x, 40 * scale, row:GetWidth() - x - 12)
end

function H.Build(provider)
  local owner = provider or H
  if not owner.win then
    owner.win = Kit.Browser((ns.FRAME_PREFIX or "Highground") .. "MatchHistory" .. (provider and "Sample" or ""), {
      title = ns.Locale:Get("shared.matchwindow.match_history.c2b12f"), hint = ns.Locale:Get("shared.matchwindow.this_character_s_matches_on_the_current.2a625b"),
      width = 800, height = 640, listRatio = 0.38, rowHeight = 62, renderRow = RenderRow, renderDetail = RenderDetail,
      data = provider and provider.entries or function() return H.Entries() end,
      empty = ns.Locale:Get("shared.matchwindow.completed_matches_will_appear_here_only_observed.5ced7c"),
      selected = function(_, w) w:SetSub(owner.summary or "") end,
      actions = {
        { label = ns.Locale:Get("shared.matchwindow.full_timeline.a0c4d1"), tone = "accent", run = function(entry)
          if not owner.timeline then owner.timeline = Kit.CopyBox((ns.FRAME_PREFIX or "Highground") .. "MatchTimeline" .. (provider and "Sample" or ""), {
            title = ns.Locale:Get("shared.matchwindow.objective_timeline.f6ac0d"), width = 650, height = 500 }) end
          local lines = {}
          for _, e in ipairs(entry.match.events) do lines[#lines + 1] = U.Clock(e.at) .. "  " .. e.text end
          owner.timeline:Open(entry.match.name, ns.Locale:Get("shared.matchwindow.observed_events_since_joining.6ff0e9"), table.concat(lines, "\n"), true)
        end },
        { label = ns.Locale:Get("shared.matchwindow.delete_entry.ccaf75"), run = function(entry)
          local removed, index
          local records = provider and provider.records or H.All()
          for i, m in ipairs(records) do if m.id == entry.key then removed, index = table.remove(records, i), i; break end end
          return true, ns.Locale:Get("shared.matchwindow.match_removed_you_can_undo_this_below.5afa45"), function()
            if removed then table.insert(records, math.min(index, #records + 1), removed) end
          end
        end },
      },
    })
    T.OnChange(function() if owner.win:IsShown() then owner.win:Refresh() end end)
  end
  return owner.win
end

function H.Open(embedded)
  H.Build()
  if not embedded then H.win:Open() end
  return H.win
end
