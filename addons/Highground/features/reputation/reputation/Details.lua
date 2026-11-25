local _, ns = ...
local W, K, T, U = ns.Reputation, ns.Kit, ns.Theme, ns.Util

-- Moderation history names an operation (ban, revoke, dismiss) for players.
local function OperationLabel(kind)
  return kind == "ban" and ns.Locale:Get("reputation.history.ban")
    or kind == "revoke" and ns.Locale:Get("reputation.history.revoke")
    or kind == "dismiss" and ns.Locale:Get("reputation.history.dismiss") or tostring(kind)
end

-- A case's state (Moderation.lua W.Cases) as players read it.
local STATES = { blacklisted = "reputation.history.ban", revoked = "reputation.history.revoke",
  dismissed = "reputation.history.dismiss", proposed = "reputation.details.state.proposed" }
function W.StateText(state)
  return STATES[state] and ns.Locale:Get(STATES[state]) or tostring(state)
end

local STATE_TONES = { blacklisted = "danger", proposed = "warning", revoked = "success", dismissed = "textMuted" }
local OPERATION_TONES = { ban = "danger", revoke = "success", dismiss = "textMuted" }
local PAD = 14

-- This character's own encounters with the player (Nearby history), if any.
function W.Encounter(target)
  local H = ns.NearbyHistory
  if not (H and H.Get) or ns.Modules and not ns.Modules.Active("nearby") then return nil end
  return H.Get(target.name)
end

local function Text(parent, role, color)
  local fs = T.Text(parent, role, color)
  fs:SetJustifyH("LEFT"); fs:SetJustifyV("TOP"); fs:SetWordWrap(true)
  fs:SetNonSpaceWrap(true)
  return fs
end

-- Only constrain width; native text measures its own wrapped height.
local function Place(fs, text, x, y, width)
  fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", x, -y)
  fs:SetWidth(math.max(1, width)); fs:SetText(text or ""); fs:Show()
  return fs:GetStringHeight()
end

local function When(at) return at and date("%Y-%m-%d %H:%M", at) or ns.Locale:Get("shared.journal.not_recorded.305cc3") end

local function Ago(at)
  local seconds = math.max(0, time() - at)
  return seconds < 60 and ns.Locale:Get("shared.journal.just_now.a69f48")
    or ns.Locale:Format("shared.journal.value1_ago.353086", { value1 = ns.NearbyHistory.Ago(seconds) })
end

local function Categories(W, set)
  local out = {}
  for _, category in ipairs(W.CATEGORIES) do if set[category[1]] then out[#out + 1] = category[2] end end
  return out
end

-- What the dialog shows, read once per OpenDetails. Rendering only lays it
-- out, so resizing and text size changes need no model access.
local function Model(c, row, W)
  local mod, tags = W.CanModerate(c), {}
  local m = { state = row.state, tone = STATE_TONES[row.state] or "textMuted", name = ns.Core.DisplayName(row.target.name),
    encounter = W.Encounter and W.Encounter(row.target), moderator = mod, reports = {}, history = {} }
  if row.active then
    m.approved = ns.Locale:Format("reputation.details.approved_by_row_active_by.d9c87e", { row_active_by = ns.Core.DisplayName(row.active.by) })
      .. " · " .. When(row.active.at)
    m.explanation = row.active.note
  end
  local reports = {}
  if mod then
    for _, report in pairs(row.reports) do reports[#reports + 1] = report end
    m.counts = { row.count, row.pending, #row.actions }
  else
    reports[1] = W.OwnReport(c, row.target)
  end
  local function Pending(r) return ((row.reviewed or {})[r.account] or 0) < (r.revision or 1) end
  table.sort(reports, function(a, b)
    local pa, pb = Pending(a), Pending(b)
    if pa ~= pb then return pa end
    return a.by < b.by
  end)
  for _, report in ipairs(reports) do
    for key in pairs(report.categories) do tags[key] = true end
    local pending = Pending(report)
    local status = mod and (pending and W.StateText("proposed") or ns.Locale:Get("reputation.availability.reviewed.31ef85"))
      or W.DeliveryText(c, report)
    m.reports[#m.reports + 1] = { title = ns.Core.DisplayName(report.by), tone = pending and "warning" or "success",
      meta = status .. (report.at and (" · " .. When(report.at)) or ""),
      tags = table.concat(Categories(W, report.categories), " · "), note = report.note, empty = ns.Locale:Get("reputation.details.no_note.8cb0e7") }
  end
  m.badges = Categories(W, row.active and row.active.categories or tags)
  local actions = {}
  for _, op in ipairs(row.actions) do actions[#actions + 1] = op end
  table.sort(actions, function(a, b) return a.clock == b.clock and a.id > b.id or a.clock > b.clock end)
  for _, op in ipairs(actions) do
    m.history[#m.history + 1] = { title = OperationLabel(op.kind), tone = OPERATION_TONES[op.kind] or "border",
      meta = ns.Core.DisplayName(op.by) .. " · " .. When(op.at), tags = table.concat(Categories(W, op.categories or {}), " · "),
      note = op.note, empty = ns.Locale:Get("reputation.details.no_public_explanation_added.1df262") }
  end
  return m
end

-- One report or decision: a tone strip beside its heading, status line,
-- categories and note.
local function Entry(parent)
  local e = CreateFrame("Frame", nil, parent)
  T.Fill(e, "BACKGROUND", "well"):SetAllPoints()
  e.strip = T.Fill(e, "ARTWORK", "border")
  e.strip:SetPoint("TOPLEFT"); e.strip:SetPoint("BOTTOMLEFT"); e.strip:SetWidth(3)
  e.title = Text(e, "detail", "text")
  e.meta = Text(e, "note", "textMuted")
  e.tags = Text(e, "note", "accent")
  e.body = Text(e, "body", "text")
  return e
end

local function RenderEntry(e, spec, y, width)
  e:ClearAllPoints(); e:SetPoint("TOPLEFT", PAD, -y); e:SetWidth(width); e:Show()
  T.Paint(e.strip, spec.tone)
  local x, inner = 14, width - 26
  local h = 10 + Place(e.title, spec.title, x, 10, inner) + 3
  h = h + Place(e.meta, spec.meta, x, h, inner)
  e.tags:SetShown(spec.tags ~= "")
  if spec.tags ~= "" then h = h + 6 + Place(e.tags, spec.tags, x, h + 6, inner) end
  local note = spec.note ~= nil and spec.note ~= ""
  T.Paint(e.body, note and "text" or "textMuted")
  h = h + 8 + Place(e.body, note and spec.note or spec.empty, x, h + 8, inner) + 12
  e:SetHeight(h)
  return h
end

local function Build(f)
  local v = f.history.body
  f.view = v
  v.hero = K.Hero(v, "accent")
  v.hero:SetPoint("TOPLEFT")
  v.emblem = CreateFrame("Frame", nil, v.hero)
  T.Fill(v.emblem, "BACKGROUND", "well"):SetAllPoints()
  K.Outline(v.emblem, "borderAccent")
  v.icon = v.emblem:CreateTexture(nil, "ARTWORK")
  v.icon:SetPoint("TOPLEFT", 5, -5); v.icon:SetPoint("BOTTOMRIGHT", -5, 5)
  v.unknown = T.Text(v.emblem, "number", "textMuted")
  v.unknown:SetPoint("CENTER"); v.unknown:SetText("?")
  v.state = Text(v.hero, "caption", "textMuted")
  v.name = Text(v.hero, "displayLarge", "text")
  v.class = Text(v.hero, "body", "text")
  v.approved = Text(v.hero, "note", "textMuted")
  v.badges = {}
  v.stats = CreateFrame("Frame", nil, v)
  T.Fill(v.stats, "BACKGROUND", "well"):SetAllPoints()
  v.metrics = {}
  for i, spec in ipairs({ { "reputation.details.reporters", "info" }, { "reputation.details.state.proposed", "warning" }, { "reputation.details.decisions", "accent" } }) do
    local cell = CreateFrame("Frame", nil, v.stats)
    cell.value = Text(cell, "readout", spec[2]); cell.value:SetJustifyH("CENTER")
    cell.label = Text(cell, "caption", "textMuted"); cell.label:SetJustifyH("CENTER")
    cell.key = spec[1]
    if i > 1 then
      local rule = T.Fill(cell, "ARTWORK", "border")
      rule:SetPoint("TOPLEFT", 0, -12); rule:SetPoint("BOTTOMLEFT", 0, 12); rule:SetWidth(1)
    end
    v.metrics[i] = cell
  end
  v.sections, v.reports, v.entries = {}, {}, {}
  for _, key in ipairs({ "explanation", "reports", "encounters", "history" }) do
    local s = { rule = T.Fill(v, "ARTWORK", "border"), label = Text(v, "caption", "accent") }
    s.rule:SetHeight(1)
    v.sections[key] = s
  end
  v.explanation = Text(v, "bodyLarge", "text")
  v.met = Text(v, "body", "text")
  v.lastSeen = Text(v, "note", "textMuted")
  v.noReports = Text(v, "body", "textMuted")
  v.noHistory = Text(v, "body", "textMuted")
end

local function Section(v, key, text, y, width)
  local s = v.sections[key]
  s.rule:ClearAllPoints(); s.rule:SetPoint("TOPLEFT", PAD, -y); s.rule:SetWidth(width - PAD * 2); s.rule:Show()
  return y + 16 + Place(s.label, ns.Text.Upper(text), PAD, y + 16, width - PAD * 2) + 10
end

local function Hero(v, m, width)
  local scale = math.max(1, ns.Core.FontScale())
  local icon = 52 * math.min(scale, 1.25)
  local h = m.encounter
  local x, y, inner = PAD + icon + 14, PAD, width - PAD * 2 - icon - 14
  v.hero:SetWidth(width)
  T.Paint(v.hero.strip, m.tone)
  v.emblem:SetPoint("TOPLEFT", PAD, -PAD); v.emblem:SetSize(icon, icon)
  v.unknown:SetShown(not K.ClassIcon(v.icon, h and h.class))
  local cc = h and U.ClassColor(h.class)
  if cc then T.PaintClass(v.name, cc) else T.Paint(v.name, "text") end
  T.Paint(v.state, m.tone)
  y = y + Place(v.state, ns.Text.Upper(W.StateText(m.state)), x, y, inner) + 6
  y = y + Place(v.name, m.name, x, y, inner) + 5
  local class = h and ((h.level and h.level > 0 and ns.Locale:Format("shared.journal.level_h_level.bafbe1", { h_level = h.level }) or "")
    .. (h.class and U.ClassName(h.class) or ns.Locale:Get("shared.journal.unknown_class.b6275c"))
    .. (h.guild and h.guild ~= "" and ("  <" .. h.guild .. ">") or ""))
  v.class:SetShown(class ~= nil)
  if class then y = y + Place(v.class, class, x, y, inner) + 4 end
  v.approved:SetShown(m.approved ~= nil)
  if m.approved then y = y + Place(v.approved, m.approved, x, y, inner) + 4 end
  -- Category badges wrap onto further lines when a translation is long.
  local bx, rowHeight = x, 0
  for i, label in ipairs(m.badges) do
    local b = v.badges[i] or K.Badge(v.hero, label, m.tone)
    v.badges[i] = b
    b:Set(label, m.tone); b:Show()
    local bw = b:Layout()
    if bx > x and bx + bw > x + inner then bx, y = x, y + rowHeight + 6 end
    b:ClearAllPoints(); b:SetPoint("TOPLEFT", bx, -(y + 4))
    bx, rowHeight = bx + bw + 6, b:GetHeight()
  end
  for i = #m.badges + 1, #v.badges do v.badges[i]:Hide() end
  if #m.badges > 0 then y = y + 4 + rowHeight end
  y = math.max(y, PAD + icon) + PAD
  v.hero:SetHeight(y)
  return y
end

local function Stats(v, m, y, width)
  v.stats:SetShown(m.counts ~= nil)
  if not m.counts then return y end
  v.stats:ClearAllPoints(); v.stats:SetPoint("TOPLEFT", 0, -y); v.stats:SetWidth(width)
  local cellWidth, height = width / 3, 0
  for i, cell in ipairs(v.metrics) do
    cell:ClearAllPoints(); cell:SetPoint("TOPLEFT", (i - 1) * cellWidth, 0); cell:SetWidth(cellWidth)
    local h = 12 + Place(cell.value, tostring(m.counts[i]), 6, 12, cellWidth - 12) + 5
    height = math.max(height, h + Place(cell.label, ns.Locale:Get(cell.key), 6, h, cellWidth - 12) + 12)
  end
  v.stats:SetHeight(height)
  for _, cell in ipairs(v.metrics) do cell:SetHeight(height) end
  return y + height
end

local function Entries(v, pool, specs, y, width)
  for i, spec in ipairs(specs) do
    pool[i] = pool[i] or Entry(v)
    y = y + RenderEntry(pool[i], spec, y, width - PAD * 2) + 8
  end
  for i = #specs + 1, #pool do pool[i]:Hide() end
  return y
end

local function Render(f, width)
  local v, m = f.view, f.model
  if not m then return 1 end
  for _, s in pairs(v.sections) do s.rule:Hide(); s.label:Hide() end
  for _, fs in ipairs({ v.explanation, v.met, v.lastSeen, v.noReports, v.noHistory }) do fs:Hide() end
  local inner = width - PAD * 2
  local y = Stats(v, m, Hero(v, m, width), width) + 10
  if m.approved then
    y = Section(v, "explanation", ns.Locale:Get("reputation.details.explanation"), y, width)
    local note = m.explanation ~= ""
    T.Paint(v.explanation, note and "text" or "textMuted")
    y = y + Place(v.explanation, note and m.explanation or ns.Locale:Get("reputation.details.no_public_explanation_added.1df262"), PAD, y, inner) + 18
  end
  if m.moderator or #m.reports > 0 then
    local title = m.moderator and ns.Locale:Format("reputation.details.reports", { count = #m.reports }) or ns.Locale:Get("reputation.details.your_report")
    y = Section(v, "reports", title, y, width)
    if #m.reports == 0 then y = y + Place(v.noReports, ns.Locale:Get("reputation.details.no_reports"), PAD, y, inner) + 18 end
  end
  y = Entries(v, v.reports, m.reports, y, width) + (#m.reports > 0 and 10 or 0)
  local h = m.encounter
  if h then
    y = Section(v, "encounters", ns.Locale:Get("reputation.details.encounters"), y, width)
    y = y + Place(v.met, ns.Locale:Format("reputation.details.encounter_counts", { times = h.times or 0, killed = h.killedThem or 0, deaths = h.killedMe or 0 }), PAD, y, inner) + 5
    local seen = h.last and (h.zone and ns.Locale:Format("reputation.details.last_seen_in", { zone = h.zone, ago = Ago(h.last) })
      or ns.Locale:Format("shared.previewsamples.last_seen_value2.b31bec", { value2 = Ago(h.last) }))
    v.lastSeen:SetShown(seen ~= nil)
    if seen then y = y + Place(v.lastSeen, seen, PAD, y, inner) + 5 end
    y = y + 18
  end
  y = Section(v, "history", ns.Locale:Get("reputation.details.history"), y, width)
  if #m.history == 0 then
    y = y + Place(v.noHistory, ns.Locale:Get("reputation.details.no_decisions"), PAD, y, inner) + 10
  end
  return Entries(v, v.entries, m.history, y, width) + PAD
end

-- A suspended window must not keep private notes after access ends.
local function Clear(f)
  f.model, f.row = nil, nil
  for _, pool in ipairs({ f.view.reports, f.view.entries }) do
    for _, e in ipairs(pool) do
      for _, fs in ipairs({ e.title, e.meta, e.tags, e.body }) do fs:SetText("") end
      e:Hide()
    end
  end
end

function W.OpenDetails(c, row, source)
  local W = source or W
  local UI = W.UI
  if not W.Joined(c) then return end
  if not UI.details then
    local f = UI.Dialog("Details", ns.Locale:Get("reputation.details.player_history.1f4c17"), 640, 610)
    UI.details = f
    f.history = K.ScrollArea(f.content)
    f.history:SetPoint("TOPLEFT", 0, -6); f.history:SetPoint("BOTTOMRIGHT", -10, 54)
    f.scroll = f.history.view
    Build(f)
    function f.history.onLayout(area, width)
      local height = math.max(1, Render(f, width))
      if math.abs(area.body:GetHeight() - height) > 0.001 then area.body:SetHeight(height) end
    end
    f.Clear = Clear
    -- Moderator actions share one toolbar; hidden actions leave no gap and
    -- longer translations wrap inside taller buttons.
    f.actions = K.Toolbar(f, { height = 30, fitHeight = true })
    f.actions:SetPoint("BOTTOMLEFT", 18, 18)
    f.approve = f.actions:Add(K.Button(f.actions, ns.Locale:Get("reputation.details.review_blacklist.465b77"), 190, 30, { tone = "accent", onClick = function()
      W.OpenReport(f.row.target, f.community)
    end }))
    f.revoke = f.actions:Add(K.Button(f.actions, ns.Locale:Get("reputation.details.revoke.32862b"), 140, 30, { onClick = function() W.OpenReason(f.community, f.row.target, "revoke") end }))
    f.dismiss = f.actions:Add(K.Button(f.actions, ns.Locale:Get("reputation.details.dismiss_proposals.f1900f"), 195, 30, { onClick = function() W.OpenReason(f.community, f.row.target, "dismiss") end }))
    -- Resizing the dialog or changing text size reflows the actions and
    -- the record; a theme change repaints it.
    local function Reflow() if f:IsShown() then f.actions:Layout(math.max(1, f:GetWidth() - 36)) end end
    f:HookScript("OnSizeChanged", Reflow)
    ns.Core.OnFontScaleChange(function() Reflow(); if f:IsShown() then f.history:Refresh() end end)
    T.OnChange(function() if f:IsShown() then f.history:Refresh() end end)
  end
  row = W.FindCase(c, row.target) or row
  local f = UI.details
  f.community, f.row = c, row
  f:SetTitle(ns.Locale:Get("reputation.details.player_history.1f4c17"))
  f:SetSub(W.Name(c))
  f.model = Model(c, row, W)
  local mod = f.model.moderator
  f.moderator = mod
  f.approve:SetShown(mod); f.revoke:SetShown(mod); f.dismiss:SetShown(mod)
  f.revoke:SetEnabled(row.active ~= nil); f.dismiss:SetEnabled(row.pending > 0)
  f.actions:SetShown(mod)
  f:Show()
  f.history:Refresh(); f.history:Scroll(0)
  f.actions:Layout(math.max(1, f:GetWidth() - 36))
end
