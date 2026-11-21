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
  scroll:SetPoint("TOPLEFT", 16, -16); scroll:SetPoint("BOTTOMRIGHT", -8, 12)
  local body, parts = scroll.body, {}
  local function Text(text, role, color)
    local fs = Kit.Paragraph(body, role, color)
    fs:SetText(text)
    parts[#parts + 1] = { frame = fs, text = true }
    return fs
  end
  Text("ADDON USERS", "title", "titleText")
  Text("Other characters detected in the last 15 minutes. Counts exclude you and reset on reload. "
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
  Text("Detection is a sample, not a server census or an exact online count. Only compatible Highground releases "
    .. "announce themselves; older releases and standalone addons are not counted. Realm discovery reaches participants "
    .. "in your faction's channel. Group counts exclude departed members when their roster is available.", "body", "textMuted")

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
    local data = P.Summary()
    self.total:SetText(U.Plural(data.total, "character") .. " detected")
    self.rows.realm.label:SetText(ns.Caps.rulesetRealms and "Your realmset" or "Your realm")
    for _, def in ipairs(rows) do
      local key = def[1]
      local count = key == "realm" and data.realm or data.contexts[key]
      self.rows[key].value:SetText((key == "realm" or data.active[key] and P.Enabled())
        and (count .. " detected") or (P.Enabled() and def[3] or "Detection off"))
    end
    self.status:SetText(P.Status())
    self.connection:SetText(P.ConnectionStatus())
    self.limit:SetShown(data.limited == true)
    self.limit:SetText("The " .. P.LIMIT .. "-character tracking limit was reached. Counts may be lower than the actual number detected.")
    self.version:SetText("Installed: " .. P.Version() .. (P.latest
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
    self.versions:SetText(#lines > 0 and table.concat(lines, "\n") or "No other users detected yet.")
    self.toggles.peerDiscovery:SetChecked(P.Enabled(), true)
    self.toggles.peerRealmDiscovery:SetChecked(ns.Core.db.peerRealmDiscovery ~= false, true)
    self.toggles.peerVersionNotices:SetChecked(P.NoticesEnabled(), true)
    self.toggles.peerRealmDiscovery:SetEnabled(P.Enabled())
    scroll:Refresh()
  end
  local ticker = U.Every(5, function() w:Refresh() end, "addon users view")
  ticker.Stop()
  w:SetScript("OnShow", function() w:Refresh(true); ticker.Start() end)
  w:SetScript("OnHide", ticker.Stop)
  ns.Core.OnFontScaleChange(function() if w:IsVisible() then scroll:Refresh() end end)
  return w
end
