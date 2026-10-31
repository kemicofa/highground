local _, ns = ...
local B, T, Kit = ns.Bounty, ns.Theme, ns.Kit
local Row = {}
B.BoardRow = Row

function Row.Build(parent)
  local r = CreateFrame("Frame", nil, parent)
  r.bg = T.Fill(r, "BACKGROUND", "surface"); r.bg:SetAllPoints()
  r.rule = T.Fill(r, "BORDER", "border")
  r.rule:SetPoint("BOTTOMLEFT"); r.rule:SetPoint("BOTTOMRIGHT"); r.rule:SetHeight(1)
  r.strip = T.Fill(r, "ARTWORK", "gold"); r.strip:SetPoint("TOPLEFT", 0, -1); r.strip:SetPoint("BOTTOMLEFT", 0, 1); r.strip:SetWidth(3)
  r.name = T.Text(r, "cardTitle", "text"); r.name:SetPoint("TOPLEFT", 14, -10)
  r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
  r.gold = T.Text(r, "number", "gold"); r.gold:SetPoint("TOPRIGHT", -14, -10)
  r.name:SetPoint("RIGHT", r.gold, "LEFT", -20, 0)
  r.approval = Kit.Chip(r, "", "pending")
  r.approval:SetPoint("TOPRIGHT", r.gold, "TOPLEFT", -14, 2)
  r.approval:EnableMouse(true)
  Kit.Tooltip(r.approval, function()
    local b = r.entry
    if not (b and b.guild) then return nil end
    local pending = b.guild.state == "pending"
    return { pending and "Awaiting guild approval" or "Guild approved",
      pending and "A guild officer must approve this submission before it becomes visible to all guild members."
        or "A guild officer has approved this listing. Guild members can see it.",
      (b.offer or b.shared) and "This status applies only to the guild listing. Its shared contribution is already published." or nil }
  end)
  r.approval:Hide()
  r.audience = T.Text(r, "bodySmall", "gold"); r.audience:SetJustifyH("LEFT"); r.audience:SetWordWrap(false)
  r.status = T.Text(r, "bodySmall", "textMuted"); r.status:SetJustifyH("LEFT"); r.status:SetWordWrap(false)
  r.primary = Kit.Button(r, "", 110, 26, { onClick = function(self) if r.entry then B.BoardActions.Run(self, r.entry) end end })
  r.details = Kit.Button(r, "View bounty", 110, 26, { onClick = function() if r.entry then B.BoardActions.Details(r.entry) end end })
  r.more = Kit.Button(r, "More", 66, 26, { onClick = function(self) if r.entry then B.BoardActions.Menu(self, r.entry) end end })
  r.more:SetPoint("BOTTOMRIGHT", -12, 10)
  r.primary:SetPoint("RIGHT", r.details, "LEFT", -8, 0)
  Kit.Tooltip(r.details, function()
    if r.entry and r.entry.suggestion then return { "Death reports", "Review victims, locations, report times and attribution sources before deciding on a bounty." } end
    return { "View this bounty", "Review who offers the reward, who can see it, funding, expiry and notes. All contributions in this view are shown together." }
  end)
  Kit.Tooltip(r.more, function()
    if r.entry and r.entry.suggestion then return { "Suggestion actions", "Dismiss for 24 hours, ignore this enemy, or allow an ignored enemy again." } end
    return { "More bounty actions", "Publish to another audience, withdraw a contribution, remove a listing or reject a guild submission. These actions are available directly in this menu." }
  end)
  Kit.Tooltip(r.primary, function()
    return r.entry and { B.BoardActions.Primary(r.entry), B.BoardActions.Help(r.entry) }
  end, { anchor = "ANCHOR_RIGHT" })
  Kit.Tooltip(r, function()
    local b = r.entry
    if not b then return nil end
    if b.suggestion then return B.Suggestions.View.Tooltip(b) end
    local lines = { { b.name, "gold" }, { ns.Util.Gold(b.gold) .. " reward", "text" },
      { b.owner .. " · " .. b.visibility, "text", true }, { b.status, "textMuted", true } }
    if b.shared then for _, line in ipairs(B.Public.Tooltip(b.shared)) do lines[#lines + 1] = line end
    elseif b.note and b.note ~= "" then lines[#lines + 1] = { b.note, "text", true } end
    return lines
  end, { anchor = "ANCHOR_RIGHT" })
  return r
end

function Row.Layout(r)
  local scale = math.max(1, ns.Core.FontScale())
  r:SetHeight(114 + (scale - 1) * 42)
  r.primary:SetSize(120 * scale, 26 + (scale - 1) * 14)
  r.details:SetSize(110 * scale, 26 + (scale - 1) * 14)
  r.more:SetSize(66 * scale, 26 + (scale - 1) * 14)
  r.approval:SetHeight(20 + (scale - 1) * 16)
  r.audience:ClearAllPoints(); r.audience:SetPoint("TOPLEFT", 14, -35 - (scale - 1) * 14)
  r.audience:SetPoint("RIGHT", -14, 0)
  r.status:ClearAllPoints(); r.status:SetPoint("TOPLEFT", 14, -57 - (scale - 1) * 20)
  r.status:SetPoint("RIGHT", -14, 0)
end

function Row.Fill(r, b)
  r.entry = b
  r.name:SetText(b.name)
  r.gold:SetText(b.suggestion and (b.total .. " reports") or b.gold > 0 and ns.Util.Gold(b.gold) or "No reward")
  r.audience:SetText(b.owner .. " · " .. b.visibility)
  r.status:SetText(b.status)
  r.primary:SetText(B.BoardActions.Primary(b))
  r.primary:SetShown(b.suggestion or B.BoardActions.Primary(b) ~= "View bounty")
  r.details:SetText(b.suggestion and "Reports" or "View bounty")
  local more = #B.BoardActions.Items(b) > 0
  r.more:SetShown(more)
  r.details:ClearAllPoints()
  if more then r.details:SetPoint("RIGHT", r.more, "LEFT", -8, 0)
  else r.details:SetPoint("BOTTOMRIGHT", -12, 10) end
  local approval = b.guild and b.guild.state
  local showApproval = approval == "pending" or approval == "approved"
  r.approval:SetShown(showApproval)
  r.name:ClearAllPoints(); r.name:SetPoint("TOPLEFT", 14, -10)
  r.name:SetPoint("RIGHT", showApproval and r.approval or r.gold, "LEFT", -14, 0)
  if showApproval then
    local tint = approval == "pending" and "pending" or "success"
    r.approval:Set(approval == "pending" and "AWAITING APPROVAL" or "GUILD APPROVED", tint)
    T.Paint(r.approval.bg, tint); T.Paint(r.approval.label, "onAccent")
    r.approval:SetWidth(math.ceil(r.approval.label:GetStringWidth()) + 20)
  end
  local token = b.muted and "textMuted" or "gold"
  T.Paint(r.name, b.muted and "textMuted" or "text")
  T.Paint(r.gold, token); T.Paint(r.audience, b.muted and "textMuted" or "text")
  T.Paint(r.strip, approval == "pending" and "pending" or token)
  r:Show()
end
