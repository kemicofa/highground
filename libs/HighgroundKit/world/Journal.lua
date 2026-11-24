local _, ns = ...
local H, Kit, U = ns.NearbyHistory, ns.Kit, ns.Util
local Core, T = ns.Core, ns.Theme
local J = {}
ns.EnemyJournal = J

local function Class(h)
  return (h.level and h.level > 0 and (ns.Locale:Format("shared.journal.level_h_level.bafbe1", { h_level = h.level })) or "")
    .. (h.class and U.ClassName(h.class) or ns.Locale:Get("shared.journal.unknown_class.b6275c"))
end

local function Ago(at)
  if not at then return ns.Locale:Get("shared.journal.not_recorded.305cc3") end
  local seconds = math.max(0, time() - at)
  return seconds < 60 and ns.Locale:Get("shared.journal.just_now.a69f48") or ns.Locale:Format("shared.journal.value1_ago.353086", { value1 = H.Ago(seconds) })
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
  for i, spec in ipairs({ { ns.Locale:Get("shared.journal.encounters.188175"), "info" }, { ns.Locale:Get("shared.journal.you_killed.4dfe40"), "success" }, { ns.Locale:Get("shared.journal.killed_you.a1087b"), "danger" } }) do
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
  p.report = Text(p, "body", "danger")
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
  local state = h.muted and ns.Locale:Get("shared.journal.alerts_muted.fef5de") or ns.Locale:Get("shared.journal.encounter_record.4b2427")
  if h.tracked then state = ns.Locale:Get("tracking.row") .. " · " .. state end
  y = y + Place(p.state, state, x, y, width - x - pad) + 6
  T.Paint(p.state, h.tracked and "danger" or h.muted and "warning" or "textMuted")
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
  y = y + Place(p.locationLabel, ns.Locale:Get("shared.journal.last_encounter.ec3811"), pad, y, inner) + 7
  y = y + Place(p.zone, h.zone or ns.Locale:Get("shared.journal.location_not_recorded.5c185c"), pad, y, inner) + 5
  y = y + Place(p.lastSeen, ns.Locale:Format("shared.previewsamples.last_seen_value2.b31bec", { value2 = Ago(h.last) }), pad, y, inner) + 5
  -- A tracked enemy's latest report, yours or someone else's (world/Tracking.lua).
  local report = h.tracked and type(h.report) == "table" and ns.Tracking and h.report
  p.report:SetShown(report and true or false)
  if report then
    y = y + Place(p.report, ns.Locale:Format("tracking.journal.report", { where = ns.Tracking.Where(report),
      who = report.by and Core.DisplayName(report.by) or ns.Locale:Get("tracking.journal.you"), ago = Ago(report.at) }), pad, y, inner) + 5
  end
  y = y + Place(p.firstSeen, ns.Locale:Format("shared.journal.first_met_value2.d34939", { value2 = Ago(h.first) }), pad, y, inner) + 18
  p.notesRule:SetPoint("TOPLEFT", pad, -y); p.notesRule:SetWidth(inner)
  y = y + 16
  y = y + Place(p.notesLabel, ns.Locale:Get("shared.journal.field_notes.5cb337"), pad, y, inner) + 8
  local hasNote = h.note and h.note ~= ""
  T.Paint(p.notes, hasNote and "text" or "textMuted")
  y = y + Place(p.notes, hasNote and h.note or ns.Locale:Get("shared.journal.no_notes_yet_add_a_reminder_about.419990"), pad, y, inner) + pad
  p:SetHeight(y)
  return y
end

local function EmptyMessage(sample)
  if sample then return ns.Locale:Get("shared.journal.this_sample_has_no_encounters_to_display.df51f9") end
  local nearby, history = ns.Nearby.Enabled(), H.Enabled()
  if nearby and history then
    return ns.Locale:Get("shared.journal.recording_is_on_enemies_you_meet_in.f518d2")
  end
  local messages = {}
  if not nearby then
    messages[#messages + 1] = ns.Locale:Format("shared.journal.nearby_enemies_is_off_turn_it_on.ee189f", { value2 = (ns.StandaloneSettings and ns.Locale:Get("shared.journal.the_addon_settings.1f919e") or ns.Locale:Get("shared.journal.general_settings.06ea87")) })
  end
  if not history then
    messages[#messages + 1] = ns.Locale:Format("shared.journal.encounter_history_is_off_enable_it_in.0b8ed4", { value2 = (ns.StandaloneSettings and ns.Locale:Get("shared.journal.the_addon_settings.1f919e") or ns.Locale:Get("shared.journal.nearby_enemies_settings.88d420")) })
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
  local y = pad + Place(w.emptyTitle, ns.Locale:Get("shared.journal.no_enemies_recorded.c9f1af"), pad, pad, inner) + 12
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
      local lines = { e.title, Class(e.record), e.record.zone or ns.Locale:Get("shared.journal.location_not_recorded.5c185c"),
        ns.Locale:Format("shared.journal.last_seen_value2.41fe35", { value2 = Ago(e.record.last) }), e.record.muted and ns.Locale:Get("shared.journal.alerts_muted.9bfd3b") or ns.Locale:Get("shared.journal.select_to_view_encounters_and_notes.1f8ca9") }
      local b = ns.Bounty and ns.Bounty.Enabled() and ns.Bounty.Find(e.key)
      if b then lines[#lines + 1] = { ns.Locale:Format("shared.journal.bounty_value2.b4abd7", { value2 = ns.Bounty.GoldText(b) }), "gold" } end
      return lines
    end)
  end
  local scale = math.max(1, Core.FontScale())
  local icon, x = 28 * scale, 12 + 28 * scale + 10
  row.icon:SetSize(icon, icon); row.icon:SetPoint("LEFT", 12, 0)
  Kit.ClassIcon(row.icon, entry.class)
  row.label:ClearAllPoints(); row.label:SetPoint("TOPLEFT", x, -7 * scale)
  row.label:SetWidth(row:GetWidth() - x - 12)
  Place(row.identity, entry.record.zone or ns.Locale:Get("shared.journal.location_not_recorded.5c185c"), x, 25 * scale, row:GetWidth() - x - 12)
  row.summary:ClearAllPoints(); row.summary:SetPoint("TOPLEFT", x, -40 * scale)
  row.summary:SetWidth(row:GetWidth() - x - 12); row.summary:SetWordWrap(false)
  row.summary:SetText(Ago(entry.record.last) .. (entry.record.muted and ns.Locale:Get("shared.journal.muted.b6a778") or "")
    .. (entry.record.tracked and (" · " .. ns.Locale:Get("tracking.row")) or ""))
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
    -- A record too damaged to read is left out rather than closing the journal.
    h = type(name) == "string" and H.Record(h)
    if h then
      local class = h.class and U.ClassName(h.class) or ns.Locale:Get("shared.journal.unknown_class.b6275c")
      out[#out + 1] = { key = name, record = h, title = ns.Core.DisplayName(name, true), class = h.class,
        summary = class .. "  ·  " .. (h.zone or ns.Locale:Get("shared.journal.unknown_zone.36ecb6")) .. (h.muted and ns.Locale:Get("shared.journal.muted.edbf09") or "")
          .. (h.tracked and ("  ·  " .. ns.Locale:Get("tracking.row")) or ""),
        detail = ns.Locale:Format("shared.journal.value1_class_value5_value7_first_met_value9.f9d26c", { value1 = ns.Core.DisplayName(name, true), class = class, value5 = (h.guild or ""), value7 = H.Summary(h), value9 = H.Ago(time() - (h.first or time())), value12 = (h.zone or "unknown"), value14 = (h.note or ns.Locale:Get("shared.journal.no_notes.f03eb1")) }) }
    end
  end
  table.sort(out, function(a, b) return (a.record.last or 0) > (b.record.last or 0)
    or ((a.record.last or 0) == (b.record.last or 0) and a.key < b.key) end)
  return out
end

local function Note(entry, owner)
  owner = owner or J
  if not owner.noteWindow then
    owner.noteWindow = Kit.CopyBox((ns.FRAME_PREFIX or "Highground") .. "EnemyNote" .. (owner ~= J and "Sample" or ""), {
      title = ns.Locale:Get("shared.journal.enemy_note.a7fe73"), width = 480, height = 300,
      buttons = { { key = "save", label = ns.Locale:Get("shared.journal.save_note.d69ca0"), onClick = function()
        local box = owner.noteWindow
        if box.entry and (owner ~= J or box.scope == ns.Scope.Character()) then
          box.entry.record.note = ns.Text.ClipBytes((box:GetText():gsub("|", "")), 500)
        end
        box:Hide(); owner.win:Refresh()
      end } } })
  end
  owner.noteWindow.entry = entry
  owner.noteWindow.scope = ns.Scope.Character()
  owner.noteWindow:Open(ns.Locale:Format("shared.journal.note_value2.e03243", { value2 = ns.Core.DisplayName(entry.key, true) }),
    owner ~= J and ns.Locale:Get("shared.journal.sample_note_your_journal_stays_unchanged.3119f6") or ns.Locale:Get("shared.journal.saved_locally_up_to_500_bytes_of.a5b0f1"), entry.record.note or "")
end

function J.Build(provider)
  local owner = provider or J
  if not owner.win then
    owner.win = Kit.Browser((ns.FRAME_PREFIX or "Highground") .. "EnemyJournal" .. (provider and "Sample" or ""), {
      title = ns.Locale:Get("shared.journal.enemy_journal.49d951"), hint = ns.Locale:Get("shared.journal.this_character_s_encounters_on_the_current.f9ab1f"),
      width = 800, height = 640, listRatio = 0.38, rowHeight = 62, renderRow = RenderRow,
      renderDetail = function(entry, w, width) return RenderDetail(entry, w, width, provider) end,
      data = provider and provider.entries or J.Entries, empty = ns.Locale:Get("shared.journal.no_enemies_recorded.c9f1af"),
      actions = {
        { label = ns.Locale:Get("shared.journal.edit_note.9751b2"), tone = "accent", run = function(e) Note(e, owner) end },
        { label = ns.Locale:Get("shared.journal.mute_alerts.d2c70d"), text = function(e) return e and e.record.muted and ns.Locale:Get("shared.journal.unmute_alerts.3292ea") or ns.Locale:Get("shared.journal.mute_alerts.d2c70d") end,
          run = function(e) H.SetMuted(e.record, not e.record.muted); return true, ns.Locale:Get("shared.journal.sighting_and_stealth_alerts_updated.15b4f9") end },
        { label = ns.Locale:Get("shared.journal.add_bounty.321741"), enabled = function() return ns.Bounty ~= nil end, run = function(e)
          if provider then return provider.bounty(e) end
          local b = ns.Bounty
          b.Board.Open(e.key)
          return true, ns.Locale:Get("shared.journal.set_a_reward_on_the_bounty_board.ad8f1d")
        end },
        { label = ns.Locale:Get("shared.matchwindow.delete_entry.ccaf75"), run = function(e)
          local records = provider and provider.records or H.All()
          local record, scope = records[e.key], ns.Scope.Character(); records[e.key] = nil
          if not provider and ns.Tracking then ns.Tracking.Changed() end
          return true, ns.Locale:Get("shared.journal.entry_removed_you_can_undo_this_below.fe9d52"), function()
            if (provider or scope == ns.Scope.Character()) and not records[e.key] then records[e.key] = record end
            if not provider and ns.Tracking then ns.Tracking.Changed() end
          end
        end },
        -- Samples toggle only the sample record; real ones go through Tracking.
        { label = ns.Locale:Get("tracking.action.track"), enabled = function() return provider ~= nil or ns.Tracking ~= nil end,
          text = function(e) return e and e.record.tracked and ns.Locale:Get("tracking.action.untrack") or ns.Locale:Get("tracking.action.track") end,
          run = function(e)
            local on, name = not e.record.tracked, Core.DisplayName(e.key)
            if provider then e.record.tracked = on or nil
            else
              local ok, why = ns.Tracking.Set(e.key, on)
              if not ok then return false, why end
            end
            return true, ns.Locale:Format(on and "tracking.action.on" or "tracking.action.off", { name = name })
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
      local refresh = U.Every(1, RefreshJournal, "enemy journal", "nearby")
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
