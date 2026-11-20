local _, ns = ...
local B, T, Kit = ns.Bounty, ns.Theme, ns.Kit
local Row = {}
B.BoardRow = Row

function Row.Build(parent)
  local r = B.Wanted.Build(parent)
  r.thumbnail, r.gold, r.audience = true, r.reward, r.owner
  T.SetRole(r.title, "cardTitle"); T.SetRole(r.reward, "readoutSmall")
  T.SetRole(r.name, "cardTitle"); T.SetRole(r.owner, "bodySmall"); T.SetRole(r.detail, "bodySmall")
  r.strip = T.Fill(r, "ARTWORK", "posterEdge"); r.strip:SetPoint("TOPLEFT", 12, -12)
  r.strip:SetPoint("TOPRIGHT", -12, -12); r.strip:SetHeight(1)
  r.approval = Kit.Chip(r, "", "pending"); r.approval:Hide()
  r:EnableMouse(true)
  r:SetScript("OnMouseUp", function(_, button)
    if button == "LeftButton" and r.entry then B.BoardActions.Details(r.entry) end
  end)
  r.primary = Kit.Button(r, "", 120, 28, { tone = "gold", onClick = function(self)
    if r.entry then B.BoardActions.Run(self, r.entry) end
  end })
  r.details = Kit.Button(r, "View bounty", 120, 26, { onClick = function()
    if r.entry then B.BoardActions.Details(r.entry) end
  end })
  Kit.Tooltip(r.details, { "View wanted poster", "Open the full portrait, reward, progress and contribution details." })
  Kit.Tooltip(r.primary, function() return r.entry and { B.BoardActions.Primary(r.entry), B.BoardActions.Help(r.entry) } end)
  Kit.Tooltip(r, function()
    local b = r.entry
    return b and { ns.Core.DisplayName(b.name), ns.Util.Gold(b.gold) .. " reward", b.owner .. " · " .. b.visibility,
      { b.status, "textMuted" }, "Click to open the full wanted poster." }
  end, { anchor = "ANCHOR_RIGHT" })
  return r
end

function Row.Layout(r, width)
  local scale = math.max(1, ns.Core.FontScale())
  width = width or r:GetWidth()
  if width < 100 then width = 280 end
  r:SetWidth(width)
  local y, inner = 18, width - 36
  local function Place(fs, gap, lines)
    fs:ClearAllPoints(); fs:SetPoint("TOP", 0, -y); fs:SetWidth(inner); fs:SetWordWrap(true); fs:SetJustifyH("CENTER")
    fs:SetHeight(0)
    local height = math.ceil(fs:GetStringHeight()) + 2
    fs:SetHeight(height); fs:SetShown(fs:GetText() ~= ""); y = y + height + gap
  end
  Place(r.name, 8); Place(r.trackingLabel, 8); Place(r.rewardLabel, 3); Place(r.reward, 9)
  Place(r.status, 9)
  r.portraitWell:ClearAllPoints(); r.portraitWell:SetPoint("TOP", 0, -y)
  local portrait = 72 * math.min(scale, 1.3)
  r.portraitWell:SetSize(portrait, portrait); y = y + portrait + 9
  Place(r.owner, 6); r.detail:Hide()
  if r.location:GetText() ~= "" then Place(r.location, 10, 3) else r.location:Hide() end
  for _, fs in ipairs({ r.title, r.class, r.note, r.likeness, r.killProgress }) do fs:Hide() end
  r.rule:Hide()
  r.details:ClearAllPoints(); r.details:SetPoint("TOPLEFT", 18, -y)
  r.details:SetSize(inner, 30 * scale)
  y = y + 26 * scale + 8
  r.primary:ClearAllPoints(); r.primary:SetPoint("TOPLEFT", 18, -y); r.primary:SetSize(inner, 28 * scale)
  if r.primary:IsShown() then y = y + 28 * scale + 4 end
  r:SetHeight(y + 14)
end

function Row.Fill(r, b)
  r.entry = b
  local source = b.suggestion and b or b.shared or b.offer or b.guild or b.personal or b
  local display = B.Public.Copy(source)
  display.name, display.gold, display.class = b.name, b.gold, b.class or source.class
  display.pledgedGold = b.gold
  local primary = b.preview and (r.previewPrimary and r.previewPrimary(b) or "") or B.BoardActions.Primary(b)
  r.primary:SetText(primary)
  r.primary:SetShown(primary ~= "" and primary ~= "View bounty" and primary ~= "Edit" and primary ~= "Edit reward" and primary ~= "Add gold" and primary ~= "Share globally")
  Kit.Paint(r.details, r.primary:IsShown() and "surface" or "gold")
  r.details:SetText(b.suggestion and "View reports" or "View bounty")
  local approval = not b.suggestion and b.guild and b.guild.state
  local group = b.guild and b.guild.organization and "COMMUNITY" or "GUILD"
  r.approval:Set(approval == "pending" and "AWAITING APPROVAL" or (group .. " APPROVED"), approval == "pending" and "pending" or "success")
  r.approval:Hide()
  B.Wanted.Fill(r, display, { width = r:GetWidth(), compact = true, preview = b.preview == true,
    title = b.suggestion and "REPORTED" or "WANTED", status = approval == "approved" and (group .. " APPROVED")
      or approval == "pending" and ("AWAITING " .. group .. " APPROVAL") or b.visibility:upper(),
    owner = b.owner, detail = b.status, location = b.location, progress = "", tracking = not b.suggestion and B.Matches.Label(b) or "" })
  if b.suggestion then r.reward:SetText(b.total .. " reports") end
  T.Paint(r.strip, "posterEdge"); T.Paint(r.name, "posterInk"); T.Paint(r.gold, "posterStamp")
  r:Show()
end
