local _, ns = ...
local P, Hub, Kit, U = ns.Peers, ns.Hub, ns.Kit, ns.Util
local rows = {
  ns.Localization.Define({ "realm", ns.Locale:Get("highground.users.your_realm.d70686"), "" }, { [2] = "highground.users.your_realm.d70686" }),
  ns.Localization.Define(ns.Localization.Define({ "PARTY", ns.Locale:Get("battlegrounds.commands.party.60b18f"), ns.Locale:Get("highground.users.not_in_a_party.473f40") }, { [2] = "battlegrounds.commands.party.60b18f" }), { [3] = "highground.users.not_in_a_party.473f40" }),
  ns.Localization.Define(ns.Localization.Define({ "RAID", ns.Locale:Get("battlegrounds.commands.raid.be6698"), ns.Locale:Get("highground.users.not_in_a_raid.449cd4") }, { [2] = "battlegrounds.commands.raid.be6698" }), { [3] = "highground.users.not_in_a_raid.449cd4" }),
  ns.Localization.Define({ "INSTANCE_CHAT", ns.Locale:Get("highground.users.instance_group.945b06"), ns.Locale:Get("highground.users.not_in_an_instance_group.380bad") }, { [2] = "highground.users.instance_group.945b06", [3] = "highground.users.not_in_an_instance_group.380bad" }),
  ns.Localization.Define(ns.Localization.Define({ "GUILD", ns.Locale:Get("reputation.window.guild.54241a"), ns.Locale:Get("highground.users.not_in_a_guild.02d7c1") }, { [2] = "reputation.window.guild.54241a" }), { [3] = "highground.users.not_in_a_guild.02d7c1" }),
  ns.Localization.Define({ "CHANNEL", ns.Locale:Get("highground.users.realm_faction_channel.23614f"), ns.Locale:Get("highground.users.not_connected.8b02f3") }, { [2] = "highground.users.realm_faction_channel.23614f", [3] = "highground.users.not_connected.8b02f3" }),
}

function Hub.CopyUsersDiagnostics()
  if not Hub.usersDiagnostics then
    Hub.usersDiagnostics = Kit.CopyBox("HighgroundUserDiagnostics", { width = 700, height = 520 })
  end
  Hub.usersDiagnostics:Open(ns.Locale:Get("highground.users.addon_user_diagnostics.033260"), ns.Locale:Get("highground.users.copy_with_ctrl_c_mac_cmd_c.4cbac1"),
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
  Text(ns.Locale:Get("highground.users.addon_users.dc08ad"), "title", "titleText")
  Text(ns.Locale:Get("highground.users.counts_include_you_members_of_the_latest.c57c11"), "body", "textMuted")
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
  w.refresh = ns.Localization.Bind(Kit.Button(body, ns.Locale:Get("highground.users.refresh_members.1b7daa"), 240, 32, { onClick = function()
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
  end }), "highground.users.refresh_members.1b7daa")
  Kit.BusyButton(w.refresh, function()
    return (w.sample and w.sampleRefresh ~= nil or not w.sample and P.Roster.pending ~= nil), ns.Locale:Get("highground.users.refreshing.961411")
  end, function() w:Refresh() end)
  parts[#parts + 1] = { frame = w.refresh, button = true }
  w.diagnostics = ns.Localization.Bind(Kit.Button(body, ns.Locale:Get("highground.users.copy_diagnostics.973495"), 240, 32, { onClick = Hub.CopyUsersDiagnostics }), "highground.users.copy_diagnostics.973495")
  parts[#parts + 1] = { frame = w.diagnostics, button = true }
  w.limit = Text("", "body", "warning")
  Text(ns.Locale:Get("highground.users.versions.a23910"), "heading", "text")
  w.version = Text("", "body", "text")
  w.versions = Text("", "body", "textMuted")
  Text(ns.Locale:Get("reputation.window.preferences.9dfd34"), "heading", "text")
  w.toggles = {}
  for _, def in ipairs({
    { "peerDiscovery", ns.Locale:Get("highground.users.detect_and_announce_highground_users.2c9966") },
    { "peerRealmDiscovery", ns.Locale:Get("highground.users.include_realm_faction_discovery.53025e") },
    { "peerVersionNotices", ns.Locale:Get("highground.users.notify_me_when_a_newer_release_is.98c128") },
  }) do
    local key = def[1]
    local toggle = Kit.Toggle(body, def[2], { onChange = function(_, on)
      P.SetPreference(key, on); w:Refresh()
    end })
    w.toggles[key] = toggle
    parts[#parts + 1] = { frame = toggle, toggle = true }
  end
  Text(ns.Locale:Get("highground.users.channel_membership_does_not_confirm_a_responding.ee5706"), "body", "textMuted")

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
    self.total:SetText(ns.Locale:Format("highground.users.value1_detected.80d136", { value1 = U.Plural(data.total, "character") }))
    self.rows.realm.label:SetText(ns.Caps.rulesetRealms and ns.Locale:Get("highground.users.your_realmset.9ad79b") or ns.Locale:Get("highground.users.your_realm.d70686"))
    for _, def in ipairs(rows) do
      local key = def[1]
      local count = key == "realm" and data.realm or data.contexts[key]
      self.rows[key].value:SetText((key == "realm" or data.active[key] and enabled)
        and (count .. (key == "CHANNEL" and data.roster and ns.Locale:Get("highground.users.members.19f5a8") or ns.Locale:Get("highground.users.detected.958e03")))
        or (enabled and def[3] or ns.Locale:Get("highground.users.detection_off.53776f")))
    end
    self.status:SetText(sample and ns.Locale:Get("highground.users.guide_sample_refresh_members_cycles_through_a.884cfc") or P.Status())
    self.connection:SetText(sample and ns.Locale:Get("highground.users.your_live_discovery_and_settings_are_unchanged.0d55c6") or P.ConnectionStatus())
    self.roster:SetText(sample and sample.text or P.Roster.Status())
    self.refresh:SetEnabled(sample ~= nil or P.RealmEnabled())
    self.refresh:RefreshBusy()
    self.diagnostics:SetEnabled(sample == nil)
    self.limit:SetShown(data.limited == true)
    self.limit:SetText(ns.Locale:Format("highground.users.a_discovery_source_reached_its_tracking_limit.18a3e0", { P_LIMIT = P.LIMIT }))
    self.version:SetText(ns.Locale:Format("highground.users.installed_value2_value3.500c4d", { value2 = P.Version(), value3 = (not sample and P.latest
      and (ns.Locale:Format("highground.users.newer_release_reported_p_latest_check_your.baaa78", { P_latest = P.latest }))
      or ns.Locale:Get("highground.users.no_newer_release_detected_this_is_not.b2b917")) }))
    local versions, lines, others = {}, {}, 0
    for version in pairs(data.versions) do versions[#versions + 1] = version end
    table.sort(versions, function(a, b) return b == "?" and a ~= "?" or P.Newer(a, b) end)
    for i, version in ipairs(versions) do
      if i <= 6 then lines[#lines + 1] = (version == "?" and ns.Locale:Get("highground.users.development_unknown.ac62a0") or version) .. ": " .. data.versions[version]
      else others = others + data.versions[version] end
    end
    if others > 0 then lines[#lines + 1] = ns.Locale:Format("highground.users.other_versions_others.270225", { others = others }) end
    if data.unconfirmed > 0 then lines[#lines + 1] = ns.Locale:Format("highground.users.channel_members_without_an_announcement_data_unconfirmed.e5905e", { data_unconfirmed = data.unconfirmed }) end
    self.versions:SetText(#lines > 0 and table.concat(lines, "\n") or ns.Locale:Get("highground.users.no_users_counted_yet.1cccdb"))
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
    text = fallback and ns.Locale:Get("highground.users.channel_member_list_is_unavailable_using_recent.28cb94")
      or (ns.Locale:Format("highground.users.count_channel_members_in_the_last_complete.f17160", { count = count })) }
  w:Refresh(true)
end

function Hub.StopUsersSample()
  local w = Hub.users
  if w and w.sample then w.sample, w.sampleRefresh = nil, nil; w:Refresh() end
end
