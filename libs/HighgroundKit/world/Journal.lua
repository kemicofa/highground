local _, ns = ...
local H, Kit, U = ns.NearbyHistory, ns.Kit, ns.Util
local Core, T = ns.Core, ns.Theme
local J = {}
ns.EnemyJournal = J

local function Class(h)
  return (h.level and h.level > 0 and ("Level " .. h.level .. " · ") or "")
    .. (h.class and U.ClassName(h.class) or "Unknown class")
end

local function Ago(at)
  if not at then return "Not recorded" end
  local seconds = math.max(0, time() - at)
  return seconds < 60 and "Just now" or H.Ago(seconds) .. " ago"
end

local function Text(parent, role, color)
  local fs = T.Text(parent, role, color)
  fs:SetJustifyH("LEFT"); fs:SetJustifyV("TOP"); fs:SetWordWrap(true)
  fs:SetNonSpaceWrap(true)
  return fs
end

-- Only constrain width. Let native text measure every line before sizing
-- its containing section, including when notes or text size grow.
local function Place(fs, text, x, y, width)
  fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", x, -y)
  fs:SetWidth(math.max(1, width)); fs:SetText(text)
  return fs:GetStringHeight()
end

local function Profile(w)
  local p = CreateFrame("Frame", nil, w.detailBody)
  p:SetPoint("TOPLEFT")
  p.hero = CreateFrame("Frame", nil, p)
  p.hero:SetPoint("TOPLEFT")
  T.Fill(p.hero, "BACKGROUND", "surface"):SetAllPoints()
  T.Gradient(p.hero, "BORDER", "accent", "headerLight", "HORIZONTAL", 1, 0):SetAllPoints()
  p.strip = T.Fill(p.hero, "ARTWORK", "accent")
  p.strip:SetPoint("TOPLEFT"); p.strip:SetPoint("TOPRIGHT"); p.strip:SetHeight(2)
  p.emblem = CreateFrame("Frame", nil, p.hero)
  T.Fill(p.emblem, "BACKGROUND", "well"):SetAllPoints()
  p.emblem.edge = Kit.Outline(p.emblem, "borderAccent")
  p.icon = p.emblem:CreateTexture(nil, "ARTWORK")
  p.icon:SetPoint("TOPLEFT", 5, -5); p.icon:SetPoint("BOTTOMRIGHT", -5, 5)
  p.unknown = T.Text(p.emblem, "number", "textMuted")
  p.unknown:SetPoint("CENTER"); p.unknown:SetText("?")
  p.state = Text(p.hero, "caption", "textMuted")
  p.name = Text(p.hero, "displayLarge", "text")
  p.class = Text(p.hero, "body", "text")
  p.guild = Text(p.hero, "note", "textMuted")
  p.stats = CreateFrame("Frame", nil, p)
  T.Fill(p.stats, "BACKGROUND", "well"):SetAllPoints()
  p.metrics = {}
  for i, spec in ipairs({ { "Encounters", "info" }, { "You killed", "success" }, { "Killed you", "danger" } }) do
    local cell = CreateFrame("Frame", nil, p.stats)
    cell.value = Text(cell, "readout", spec[2]); cell.value:SetJustifyH("CENTER")
    cell.label = Text(cell, "caption", "textMuted"); cell.label:SetJustifyH("CENTER")
    cell.label:SetText(spec[1])
    if i > 1 then
      cell.rule = T.Fill(cell, "ARTWORK", "border")
      cell.rule:SetPoint("TOPLEFT", 0, -12); cell.rule:SetPoint("BOTTOMLEFT", 0, 12); cell.rule:SetWidth(1)
    end
    p.metrics[i] = cell
  end
  p.locationLabel = Text(p, "caption", "textMuted")
  p.zone = Text(p, "bodyLarge", "text")
  p.lastSeen = Text(p, "body", "textMuted")
  p.firstSeen = Text(p, "note", "textMuted")
  p.notesRule = T.Fill(p, "ARTWORK", "border"); p.notesRule:SetHeight(1)
  p.notesLabel = Text(p, "caption", "accent")
  p.notes = Text(p, "body", "text")
  return p
end

local function RenderProfile(entry, w, width)
  w.profile = w.profile or Profile(w)
  local p = w.profile
  p:SetShown(entry ~= nil)
  if not entry then return end
  local h, pad = entry.record, 14
  local scale = math.max(1, Core.FontScale())
  local icon = 52 * math.min(scale, 1.25)
  local x, y = pad + icon + 14, pad
  p:SetWidth(width); p.hero:SetWidth(width)
  p.emblem:SetPoint("TOPLEFT", pad, -pad); p.emblem:SetSize(icon, icon)
  p.unknown:SetShown(not Kit.ClassIcon(p.icon, h.class))
  local cc = U.ClassColor(h.class)
  if cc then Core.ClassPaint(p.strip, cc); T.PaintClass(p.name, cc)
  else T.Paint(p.strip, "border"); T.Paint(p.name, "text") end
  y = y + Place(p.state, h.muted and "ALERTS MUTED" or "ENCOUNTER RECORD", x, y, width - x - pad) + 6
  T.Paint(p.state, h.muted and "warning" or "textMuted")
  y = y + Place(p.name, entry.title, x, y, width - x - pad) + 5
  y = y + Place(p.class, Class(h), x, y, width - x - pad)
  p.guild:SetShown(h.guild ~= nil and h.guild ~= "")
  if p.guild:IsShown() then y = y + 5 + Place(p.guild, "<" .. h.guild .. ">", x, y + 5, width - x - pad) end
  y = math.max(y, pad + icon) + pad
  p.hero:SetHeight(y)
  p.stats:SetPoint("TOPLEFT", 0, -y); p.stats:SetWidth(width)
  local values, cellWidth, statsHeight = { h.times or 0, h.killedThem or 0, h.killedMe or 0 }, width / 3, 0
  for i, cell in ipairs(p.metrics) do
    cell:SetPoint("TOPLEFT", (i - 1) * cellWidth, 0); cell:SetWidth(cellWidth)
    local height = 12 + Place(cell.value, tostring(values[i]), 6, 12, cellWidth - 12) + 5
    height = height + Place(cell.label, cell.label:GetText(), 6, height, cellWidth - 12) + 12
    statsHeight = math.max(statsHeight, height)
  end
  p.stats:SetHeight(statsHeight)
  for _, cell in ipairs(p.metrics) do cell:SetHeight(statsHeight) end
  y = y + statsHeight + 20
  local inner = width - pad * 2
  y = y + Place(p.locationLabel, "LAST ENCOUNTER", pad, y, inner) + 7
  y = y + Place(p.zone, h.zone or "Location not recorded", pad, y, inner) + 5
  y = y + Place(p.lastSeen, "Last seen · " .. Ago(h.last), pad, y, inner) + 5
  y = y + Place(p.firstSeen, "First met · " .. Ago(h.first), pad, y, inner) + 18
  p.notesRule:SetPoint("TOPLEFT", pad, -y); p.notesRule:SetWidth(inner)
  y = y + 16
  y = y + Place(p.notesLabel, "FIELD NOTES", pad, y, inner) + 8
  local hasNote = h.note and h.note ~= ""
  T.Paint(p.notes, hasNote and "text" or "textMuted")
  y = y + Place(p.notes, hasNote and h.note or "No notes yet. Add a reminder about this enemy with Edit note.", pad, y, inner) + pad
  p:SetHeight(y)
  return y
end

local function EmptyMessage(sample)
  if sample then return "This sample has no encounters to display." end
  local nearby, history = ns.Nearby.Enabled(), H.Enabled()
  if nearby and history then
    return "Recording is on.\n\nEnemies you meet in the open world will appear here for this character."
  end
  local messages = {}
  if not nearby then
    messages[#messages + 1] = "Nearby enemies is off. Turn it on in "
      .. (ns.StandaloneSettings and "the addon settings." or "General settings.")
  end
  if not history then
    messages[#messages + 1] = "Encounter history is off. Enable it in "
      .. (ns.StandaloneSettings and "the addon settings under More settings." or "Nearby enemies settings.")
  end
  return table.concat(messages, "\n\n")
end

local function RenderDetail(entry, w, width, sample)
  local height = RenderProfile(entry, w, width)
  local empty = w.viewState and w.viewState.kind == "empty"
  if empty and not w.emptyTitle then
    w.emptyTitle = Text(w.detailBody, "cardTitle", "text")
    w.emptyGuide = Text(w.detailBody, "body", "textMuted")
  end
  if w.emptyTitle then w.emptyTitle:SetShown(empty); w.emptyGuide:SetShown(empty) end
  if not empty then return height end
  local pad, inner = 14, width - 28
  local y = pad + Place(w.emptyTitle, "No enemies recorded", pad, pad, inner) + 12
  return y + Place(w.emptyGuide, EmptyMessage(sample), pad, y, inner) + pad
end

local function RenderRow(row, entry)
  if not row.icon then
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.identity = Text(row, "note", "textMuted"); row.identity:SetWordWrap(false)
    T.SetRole(row.label, "rowName")
    Kit.Tooltip(row, function()
      local e = row.entry
      if not e then return {} end
      local lines = { e.title, Class(e.record), e.record.zone or "Location not recorded",
        "Last seen: " .. Ago(e.record.last), e.record.muted and "Alerts muted" or "Select to view encounters and notes." }
      local b = ns.Bounty and ns.Bounty.Enabled() and ns.Bounty.Find(e.key)
      if b then lines[#lines + 1] = { "Bounty: " .. ns.Bounty.GoldText(b), "gold" } end
      return lines
    end)
  end
  local scale = math.max(1, Core.FontScale())
  local icon, x = 28 * scale, 12 + 28 * scale + 10
  row.icon:SetSize(icon, icon); row.icon:SetPoint("LEFT", 12, 0)
  Kit.ClassIcon(row.icon, entry.class)
  row.label:ClearAllPoints(); row.label:SetPoint("TOPLEFT", x, -7 * scale)
  row.label:SetWidth(row:GetWidth() - x - 12)
  Place(row.identity, entry.record.zone or "Location not recorded", x, 25 * scale, row:GetWidth() - x - 12)
  row.summary:ClearAllPoints(); row.summary:SetPoint("TOPLEFT", x, -40 * scale)
  row.summary:SetWidth(row:GetWidth() - x - 12); row.summary:SetWordWrap(false)
  row.summary:SetText(Ago(entry.record.last) .. (entry.record.muted and " · muted" or ""))
  if ns.Bounty then ns.Bounty.MarkRow(row, entry.key) end
end

local function RefreshJournal()
  if not (J.win and J.win:IsVisible()) then return end
  if J.win.emptyGuide and J.win.emptyGuide:IsShown() and J.win.emptyGuide:GetText() ~= EmptyMessage() then
    J.win:Refresh()
  end
  if not ns.Bounty then return end
  for _, row in ipairs(J.win.rows) do
    if row:IsShown() then ns.Bounty.MarkRow(row, row.entry and row.entry.key) end
  end
end

function J.Entries()
  local out = {}
  for name, h in pairs(H.All()) do
    local class = h.class and U.ClassName(h.class) or "Unknown class"
    out[#out + 1] = { key = name, record = h, title = ns.Core.DisplayName(name, true), class = h.class,
      summary = class .. "  ·  " .. (h.zone or "Unknown zone") .. (h.muted and "  ·  muted" or ""),
      detail = ns.Core.DisplayName(name, true) .. "\n" .. class .. "\n" .. (h.guild or "") .. "\n\n" .. H.Summary(h)
        .. "\nFirst met " .. H.Ago(time() - (h.first or time())) .. " ago"
        .. "\nLast zone: " .. (h.zone or "unknown") .. "\n\nNotes:\n" .. (h.note or "No notes") }
  end
  table.sort(out, function(a, b) return (a.record.last or 0) > (b.record.last or 0)
    or ((a.record.last or 0) == (b.record.last or 0) and a.key < b.key) end)
  return out
end

local function Note(entry, owner)
  owner = owner or J
  if not owner.noteWindow then
    owner.noteWindow = Kit.CopyBox((ns.FRAME_PREFIX or "Highground") .. "EnemyNote" .. (owner ~= J and "Sample" or ""), {
      title = "ENEMY NOTE", width = 480, height = 300,
      buttons = { { key = "save", label = "Save note", onClick = function()
        local box = owner.noteWindow
        if box.entry and (owner ~= J or box.scope == ns.Scope.Character()) then
          box.entry.record.note = box:GetText():gsub("|", ""):sub(1, 500)
        end
        box:Hide(); owner.win:Refresh()
      end } } })
  end
  owner.noteWindow.entry = entry
  owner.noteWindow.scope = ns.Scope.Character()
  owner.noteWindow:Open("NOTE: " .. ns.Core.DisplayName(entry.key, true),
    owner ~= J and "Sample note · your journal stays unchanged." or "Saved locally. Up to 500 bytes of text.", entry.record.note or "")
end

function J.Build(provider)
  local owner = provider or J
  if not owner.win then
    owner.win = Kit.Browser((ns.FRAME_PREFIX or "Highground") .. "EnemyJournal" .. (provider and "Sample" or ""), {
      title = "ENEMY JOURNAL", hint = "This character's encounters on the current realm or ruleset. Search by name, class, guild, zone, or note.",
      width = 800, height = 640, listRatio = 0.38, rowHeight = 62, renderRow = RenderRow,
      renderDetail = function(entry, w, width) return RenderDetail(entry, w, width, provider) end,
      data = provider and provider.entries or J.Entries, empty = "No enemies recorded",
      actions = {
        { label = "Edit note", tone = "accent", run = function(e) Note(e, owner) end },
        { label = "Mute alerts", text = function(e) return e and e.record.muted and "Unmute alerts" or "Mute alerts" end,
          run = function(e) e.record.muted = not e.record.muted; return true, "Sighting and stealth alerts updated." end },
        { label = "Add bounty", enabled = function() return ns.Bounty ~= nil end, run = function(e)
          if provider then return provider.bounty(e) end
          local b = ns.Bounty
          b.Board.Open(e.key)
          return true, "Set a reward on the bounty board."
        end },
        { label = "Delete entry", run = function(e)
          local records = provider and provider.records or H.All()
          local record, scope = records[e.key], ns.Scope.Character(); records[e.key] = nil
          return true, "Entry removed. You can undo this below.", function()
            if (provider or scope == ns.Scope.Character()) and not records[e.key] then records[e.key] = record end
          end
        end },
      },
    })
    T.OnChange(function() if owner.win:IsShown() then owner.win:Refresh() end end)
    if not provider then
      -- Bounties load after the journal; subscribe when the window is built.
      if ns.Bounty then
        for _, event in ipairs({ "added", "updated", "changed" }) do ns.Bounty.Listen(event, RefreshJournal) end
      end
      -- Recording settings, bounty expiry and markers can change while open.
      local refresh = U.Every(1, RefreshJournal, "enemy journal")
      refresh.Stop()
      J.win:HookScript("OnShow", refresh.Start)
      J.win:HookScript("OnHide", refresh.Stop)
    end
  end
  return owner.win
end

function J.Open(embedded)
  J.Build()
  if not embedded then J.win:Open() end
  return J.win
end
