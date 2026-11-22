local _, ns = ...
local P, Hub, Kit, U = ns.Peers, ns.Hub, ns.Kit, ns.Util
local rows = {
  { "realm", "Your realm", "" },
  { "PARTY", "Party", "Not in a party" },
  { "RAID", "Raid", "Not in a raid" },
  { "INSTANCE_CHAT", "Instance group", "Not in an instance group" },
  { "GUILD", "Guild", "Not in a guild" },
  { "CHANNEL", "Realm/faction channel", "Not connected" },
}

function Hub.CopyUsersDiagnostics()
  if not Hub.usersDiagnostics then
    Hub.usersDiagnostics = Kit.CopyBox("HighgroundUserDiagnostics", { width = 700, height = 520 })
  end
  Hub.usersDiagnostics:Open("Addon user diagnostics", "Copy with Ctrl+C (Mac: Cmd+C). Run /hg users why again for a fresh report.",
    P.Diagnostics(), true)
end

function Hub.BuildUsers()
  if Hub.users then return Hub.users end
  local w = CreateFrame("Frame", "HighgroundAddonUsers", UIParent)
  w:Hide(); w:SetSize(700, 580)
  Hub.users = w
  local scroll = Kit.ScrollArea(w)
  w.scroll = scroll
  scroll:SetPoint("TOPLEFT", 16, -16); scroll:SetPoint("BOTTOMRIGHT", -8, 12)
  local body, parts = scroll.body, {}
  local function Text(text, role, color)
    local fs = Kit.Paragraph(body, role, color)
    fs:SetText(text)
    parts[#parts + 1] = { frame = fs, text = true }
    return fs
  end
  Text("ADDON USERS", "title", "titleText")
  Text("Counts include you, members of the latest complete discovery-channel list, and recent addon announcements. "
    .. "Announcements expire after 15 minutes; detections reset on reload. "
    .. "The same character can appear in several contexts; the total counts each character once.", "body", "textMuted")
  w.total = Text("", "heading", "accent")
  w.rows = {}
  for _, def in ipairs(rows) do
    local row = CreateFrame("Frame", nil, body)
    row.label = Kit.Paragraph(row, "body", "text")
    row.label:SetText(def[2]); row.label:SetPoint("TOPLEFT")
    row.value = Kit.Paragraph(row, "body", "textMuted")
    row.value:SetPoint("TOPRIGHT"); row.value:SetJustifyH("RIGHT")
    w.rows[def[1]] = row
    parts[#parts + 1] = { frame = row, row = true }
  end
  w.status = Text("", "body", "textMuted")
  w.connection = Text("", "body", "textMuted")
  w.roster = Text("", "body", "textMuted")
  w.refresh = Kit.Button(body, "Refresh members", 240, 32, { onClick = function()
    if w.sample then
      local sample = w.sample
      w.sampleRefresh = sample
      C_Timer.After(0.6, function()
        if w.sampleRefresh ~= sample then return end
        w.sampleRefresh = nil
        if w.sample == sample then Hub.UsersSample(sample.next) end
      end)
    else P.Roster.Request(true) end
    w:Refresh(true)
  end })
  Kit.BusyButton(w.refresh, function()
    return (w.sample and w.sampleRefresh ~= nil or not w.sample and P.Roster.pending ~= nil), "Refreshing…"
  end, function() w:Refresh() end)
  parts[#parts + 1] = { frame = w.refresh, button = true }
  w.diagnostics = Kit.Button(body, "Copy diagnostics", 240, 32, { onClick = Hub.CopyUsersDiagnostics })
  parts[#parts + 1] = { frame = w.diagnostics, button = true }
  w.limit = Text("", "body", "warning")
  Text("Versions", "heading", "text")
  w.version = Text("", "body", "text")
  w.versions = Text("", "body", "textMuted")
  Text("Preferences", "heading", "text")
  w.toggles = {}
  for _, def in ipairs({
    { "peerDiscovery", "Detect and announce Highground users" },
    { "peerRealmDiscovery", "Include realm/faction discovery" },
    { "peerVersionNotices", "Notify me when a newer release is detected" },
  }) do
    local key = def[1]
    local toggle = Kit.Toggle(body, def[2], { onChange = function(_, on)
      P.SetPreference(key, on); w:Refresh()
    end })
    w.toggles[key] = toggle
    parts[#parts + 1] = { frame = toggle, toggle = true }
  end
  Text("Channel membership does not confirm a responding addon or its version. Members without an announcement are labelled separately. "
    .. "Unavailable or incomplete member lists fall back to recent announcements. This is a sample, not a server census. "
    .. "Group and guild detection still needs compatible Highground announcements; standalone releases use their own discovery.", "body", "textMuted")

  function scroll:onLayout(width)
    local y = 0
    for _, part in ipairs(parts) do
      local f = part.frame
      if f:IsShown() then
        local partWidth = part.button and math.min(width, 240) or width
        f:SetWidth(partWidth)
        local height
        if part.row then
          f.label:SetWidth(width * 0.48); f.value:SetWidth(width * 0.5)
          height = math.max(f.label:GetStringHeight(), f.value:GetStringHeight(), 20)
        elseif part.toggle then height = math.max(f.label:GetStringHeight() + 8, 28)
        elseif part.button then height = 32
        else height = math.max(f:GetStringHeight(), 20) end
        if part.text then Kit.Place(f, "TOPLEFT", body, "TOPLEFT", 0, -y)
        else Kit.Place(f, "TOPLEFT", body, "TOPLEFT", 0, -y, partWidth, height) end
        y = y + height + (part.row and 8 or 16)
      end
    end
    body:SetHeight(math.max(1, y))
  end

  function w:Refresh(opening)
    if not opening and not self:IsVisible() then return end
    local sample = self.sample
    local data = sample and sample.data or P.Summary()
    local enabled = sample ~= nil or P.Enabled()
    self.total:SetText(U.Plural(data.total, "character") .. " detected")
    self.rows.realm.label:SetText(ns.Caps.rulesetRealms and "Your realmset" or "Your realm")
    for _, def in ipairs(rows) do
      local key = def[1]
      local count = key == "realm" and data.realm or data.contexts[key]
      self.rows[key].value:SetText((key == "realm" or data.active[key] and enabled)
        and (count .. (key == "CHANNEL" and data.roster and " members" or " detected"))
        or (enabled and def[3] or "Detection off"))
    end
    self.status:SetText(sample and "Guide sample. Refresh members cycles through a departure and an unavailable list." or P.Status())
    self.connection:SetText(sample and "Your live discovery and settings are unchanged." or P.ConnectionStatus())
    self.roster:SetText(sample and sample.text or P.Roster.Status())
    self.refresh:SetEnabled(sample ~= nil or P.RealmEnabled())
    self.refresh:RefreshBusy()
    self.diagnostics:SetEnabled(sample == nil)
    self.limit:SetShown(data.limited == true)
    self.limit:SetText("A discovery source reached its tracking limit of " .. P.LIMIT .. " other characters. Counts may be incomplete.")
    self.version:SetText("Installed: " .. P.Version() .. (not sample and P.latest
      and ("\nNewer release reported: " .. P.latest .. ". Check your addon manager for an update.")
      or "\nNo newer release detected. This is not an online release check."))
    local versions, lines, others = {}, {}, 0
    for version in pairs(data.versions) do versions[#versions + 1] = version end
    table.sort(versions, function(a, b) return b == "?" and a ~= "?" or P.Newer(a, b) end)
    for i, version in ipairs(versions) do
      if i <= 6 then lines[#lines + 1] = (version == "?" and "Development / unknown" or version) .. ": " .. data.versions[version]
      else others = others + data.versions[version] end
    end
    if others > 0 then lines[#lines + 1] = "Other versions: " .. others end
    if data.unconfirmed > 0 then lines[#lines + 1] = "Channel members without an announcement: " .. data.unconfirmed end
    self.versions:SetText(#lines > 0 and table.concat(lines, "\n") or "No users counted yet.")
    self.toggles.peerDiscovery:SetChecked(sample ~= nil or P.Enabled(), true)
    self.toggles.peerRealmDiscovery:SetChecked(sample ~= nil or ns.Core.db.peerRealmDiscovery ~= false, true)
    self.toggles.peerVersionNotices:SetChecked(P.NoticesEnabled(), true)
    self.toggles.peerDiscovery:SetEnabled(sample == nil)
    self.toggles.peerRealmDiscovery:SetEnabled(sample == nil and P.Enabled())
    self.toggles.peerVersionNotices:SetEnabled(sample == nil)
    scroll:Refresh()
  end
  local ticker = U.Every(5, function() w:Refresh() end, "addon users view")
  ticker.Stop()
  w:SetScript("OnShow", function()
    if not w.sample then P.Roster.Request(true) end
    w:Refresh(true); ticker.Start()
  end)
  w:SetScript("OnHide", function() ticker.Stop(); w.sample, w.sampleRefresh = nil, nil end)
  ns.Core.OnFontScaleChange(function() if w:IsVisible() then scroll:Refresh() end end)
  return w
end

-- Render-only examples for the Feature guide; never replace the live caches.
function Hub.UsersSample(mode)
  local w = Hub.BuildUsers()
  w.sampleRefresh = nil
  local full, fallback = mode == "members", mode == "fallback"
  local count = full and 4 or 3
  local version = P.VersionParts(P.Version()) and P.Version() or "?"
  local versions = { [version] = 2 }
  versions["?"] = (versions["?"] or 0) + 1
  local data = { total = count, realm = count, selfCount = 1, unconfirmed = full and 1 or 0,
    roster = not fallback, versions = versions,
    contexts = { PARTY = 0, RAID = 0, INSTANCE_CHAT = 0, GUILD = 2, CHANNEL = count },
    active = { GUILD = true, CHANNEL = true } }
  w.sample = { data = data, next = full and "departure" or fallback and "members" or "fallback",
    text = fallback and "Channel member list is unavailable; using recent announcements."
      or (count .. " channel members in the last complete list. Versions appear as announcements arrive.") }
  w:Refresh(true)
end

function Hub.StopUsersSample()
  local w = Hub.users
  if w and w.sample then w.sample, w.sampleRefresh = nil, nil; w:Refresh() end
end
