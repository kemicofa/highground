local _, ns = ...
local B, T, Kit = ns.Bounty, ns.Theme, ns.Kit
local Row = {}
B.BoardRow = Row

function Row.Build(parent)
  local r = B.Wanted.Build(parent)
  r.thumbnail, r.gold, r.audience = true, r.reward, r.owner
  T.SetRole(r.title, "title"); T.SetRole(r.reward, "displayLarge")
  T.SetRole(r.name, "cardTitle"); T.SetRole(r.owner, "bodySmall"); T.SetRole(r.detail, "bodySmall")
  T.SetRole(r.trackingLabel, "headingSmall"); T.SetRole(r.location, "bodySmall")
  r.strip = T.Fill(r, "ARTWORK", "posterEdge"); r.strip:SetPoint("TOPLEFT", 12, -12)
  r.strip:SetPoint("TOPRIGHT", -12, -12); r.strip:SetHeight(1)
  r.approval = Kit.Chip(r, "", "pending"); r.approval:Hide()
  r:EnableMouse(true)
  r:SetScript("OnMouseUp", function(_, button)
    if button == "LeftButton" and r.entry then B.BoardActions.Details(r.entry) end
  end)
  r.primary = Kit.Button(r, "", 120, 28, { tone = "gold", onClick = function(self)
    if r.entry then B.BoardActions.Activate(self, r.entry) end
  end })
  r.details = ns.Localization.Bind(Kit.Button(r, ns.Locale:Get("shared.boardactions.view_bounty.be066d"), 120, 26, { onClick = function()
    if r.entry then B.BoardActions.Details(r.entry) end
  end }), "shared.boardactions.view_bounty.be066d")
  -- Keep native button feedback, with ink and brass that belong to the paper.
  local finish = r.details.RefreshFinish
  function r.details:RefreshFinish(immediate)
    finish(self, immediate)
    self.edge:SetColor("posterEdge")
    self.glow:SetColor("posterEdge")
  end
  Kit.Paint(r.details, "posterInk", "posterPaper")
  Kit.Tooltip(r.details, function() return { ns.Locale:Get("shared.boardrow.view_wanted_poster.9a40a3"), ns.Locale:Get("shared.boardrow.open_the_full_portrait_reward_progress_and.1153d7") } end)
  Kit.Tooltip(r.primary, function() return r.entry and { B.BoardActions.Primary(r.entry), B.BoardActions.Help(r.entry) } end)
  Kit.Tooltip(r, function()
    local b = r.entry
    -- Suggestions are death reports, not rewards: match the card's count.
    return b and { ns.Core.DisplayName(b.name), b.suggestion and ns.Locale:Format("shared.boardrow.b_total_reports.550c8a", { b_total = b.total })
      or ns.Locale:Format("shared.boardrow.value1_reward.56d8af", { value1 = ns.Util.Gold(b.gold) }), b.owner .. " · " .. b.visibility,
      { b.status, "textMuted" }, b.suggestion and ns.Locale:Get("bounty.card.reports_hint") or ns.Locale:Get("shared.boardrow.click_to_open_the_full_wanted_poster.cbf3b4") }
  end, { anchor = "ANCHOR_RIGHT" })
  return r
end

function Row.Layout(r, width, slots)
  local scale = math.max(1, ns.Core.FontScale())
  width = width or r:GetWidth()
  if width < 100 then width = 280 end
  r:SetWidth(width)
  local y, inner, measured = 20, width - 36, {}
  local function Place(key, gap)
    local fs = r[key]
    fs:ClearAllPoints(); fs:SetPoint("TOP", 0, -y); fs:SetWidth(inner); fs:SetWordWrap(true); fs:SetJustifyH("CENTER")
    fs:SetHeight(0)
    local height = fs:GetText() ~= "" and math.ceil(fs:GetStringHeight()) + 2 or 0
    measured[key] = height
    fs:SetHeight(math.max(1, height)); fs:SetShown(height > 0)
    local slot = slots and slots[key] or height
    if slot > 0 then y = y + slot + gap end
  end
  Place("title", 6); Place("status", 10)
  r.portraitWell:ClearAllPoints(); r.portraitWell:SetPoint("TOP", 0, -y)
  local portrait = 96 * math.min(scale, 1.3)
  r.portraitWell:SetSize(portrait, portrait); r.portraitWell:Show(); y = y + portrait + 10
  Place("name", 8); Place("rewardLabel", 2); Place("reward", 10)
  Place("trackingLabel", 6); Place("location", 8)
  for _, fs in ipairs({ r.owner, r.detail, r.class, r.note, r.likeness, r.killProgress }) do fs:Hide() end
  local buttonHeight = math.max(32 * scale, r.details.label:GetStringHeight() + 12)
  measured.action = r.primary:IsShown() and math.max(28 * scale, r.primary.label:GetStringHeight() + 10) + 8 or 0
  local action = slots and slots.action or measured.action
  r.details:ClearAllPoints(); r.details:SetPoint("BOTTOMLEFT", 18, 18); r.details:SetSize(inner, buttonHeight)
  r.primary:ClearAllPoints(); r.primary:SetPoint("BOTTOMLEFT", 18, 18 + buttonHeight + 8)
  r.primary:SetSize(inner, math.max(28 * scale, measured.action - 8))
  r.rule:ClearAllPoints(); r.rule:SetPoint("BOTTOMLEFT", 18, 18 + buttonHeight + action + 10)
  r.rule:SetWidth(inner); r.rule:Show()
  r.slots = measured
  r:SetHeight(y + 18 + buttonHeight + action + 18)
end

-- A missing location, wrapped name or extra action must not shift a neighbour.
function Row.Align(rows, first, last, width)
  local slots = {}
  for i = first, last do
    for key, height in pairs(rows[i].slots) do slots[key] = math.max(slots[key] or 0, height) end
  end
  for i = first, last do Row.Layout(rows[i], width, slots) end
  return rows[first]:GetHeight()
end

-- Cards only read their source, so a shallow copy is enough. Alternate two
-- tables: Wanted.Fill compares the previous poster to drop a stale face.
local function Display(r, source)
  r.displays = r.displays or { {}, {} }
  local display = r.displays[1] == r.posterBounty and r.displays[2] or r.displays[1]
  for key in pairs(display) do display[key] = nil end
  for key, value in pairs(source) do display[key] = value end
  return display
end

function Row.Fill(r, b)
  r.entry = b
  local source = b.suggestion and b or b.shared or b.offer or b.guild or b.personal or b
  local display = Display(r, source)
  display.name, display.gold, display.class = b.name, b.gold, b.class or source.class
  display.pledgedGold = b.gold
  local primary = b.preview and (r.previewPrimary and r.previewPrimary(b) or "") or B.BoardActions.Primary(b)
  r.primary:SetText(primary)
  r.primary:SetShown(primary ~= "" and primary ~= ns.Locale:Get("shared.boardactions.view_bounty.be066d") and primary ~= ns.Locale:Get("macros.backups.edit.530164") and primary ~= ns.Locale:Get("highground.coachbountysamples.edit_reward.0854ae") and primary ~= ns.Locale:Get("shared.details.add_gold.f9a980") and primary ~= ns.Locale:Get("shared.boardactions.share_globally.9b3fc4"))
  r.details:SetText(b.suggestion and ns.Locale:Get("shared.boardrow.view_reports.ceb5e2") or ns.Locale:Get("shared.boardactions.view_bounty.be066d"))
  local approval = not b.suggestion and b.guild and b.guild.state
  local group = b.guild and b.guild.organization and ns.Locale:Get("shared.messages.community.ec32f6") or ns.Locale:Get("shared.messages.guild.84825d")
  r.approval:Set(approval == "pending" and ns.Locale:Get("shared.boardrow.awaiting_approval.dc24e6") or (ns.Locale:Format("shared.boardrow.group_approved.7efdbe", { group = group })), approval == "pending" and "pending" or "success")
  r.approval:Hide()
  B.Wanted.Fill(r, display, { width = r:GetWidth(), compact = true, preview = b.preview == true,
    title = b.suggestion and ns.Locale:Get("shared.boardrow.reported.7c64c1") or ns.Locale:Get("shared.marks.wanted.a5eefe"), status = approval == "approved" and (ns.Locale:Format("shared.boardrow.group_approved.7efdbe", { group = group }))
      or approval == "pending" and (ns.Locale:Format("shared.boardrow.awaiting_group_approval.461b46", { group = group })) or b.visibility:upper(),
    owner = b.owner, detail = b.status, location = b.location, progress = "", tracking = not b.suggestion and B.Matches.Label(b) or "" })
  if b.suggestion then r.reward:SetText(ns.Locale:Format("shared.boardrow.b_total_reports.550c8a", { b_total = b.total })) end
  T.Paint(r.strip, "posterEdge"); T.Paint(r.name, "posterInk"); T.Paint(r.gold, "posterStamp")
  r:Show()
end
