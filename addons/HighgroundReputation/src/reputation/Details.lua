local _, ns = ...
local W, K = ns.Reputation, ns.Kit

function W.OpenDetails(c, row, source)
  local W = source or W
  local UI = W.UI
  if not W.Joined(c) then return end
  if not UI.details then
    local f = UI.Dialog("Details", ns.Locale:Get("reputation.details.player_history.1f4c17"), 640, 610)
    UI.details = f
    f.history = K.ScrollText(f.content, { bottomPadding = 24 })
    f.history:SetPoint("TOPLEFT", 0, -6); f.history:SetPoint("BOTTOMRIGHT", -10, 54)
    f.scroll, f.body, f.text = f.history.view, f.history.body, f.history.text
    f.approve = K.Button(f, ns.Locale:Get("reputation.details.review_blacklist.465b77"), 190, 30, { tone = "accent", onClick = function()
      W.OpenReport(f.row.target, f.community)
    end })
    f.approve:SetPoint("BOTTOMLEFT", 18, 18)
    f.revoke = K.Button(f, ns.Locale:Get("reputation.details.revoke.32862b"), 140, 30, { onClick = function() W.OpenReason(f.community, f.row.target, "revoke") end })
    f.revoke:SetPoint("LEFT", f.approve, "RIGHT", 10, 0)
    f.dismiss = K.Button(f, ns.Locale:Get("reputation.details.dismiss_proposals.f1900f"), 195, 30, { onClick = function() W.OpenReason(f.community, f.row.target, "dismiss") end })
    f.dismiss:SetPoint("LEFT", f.revoke, "RIGHT", 10, 0)
  end
  row = W.FindCase(c, row.target) or row
  local f, lines = UI.details, {}
  f.community, f.row = c, row
  f:SetTitle(row.target.name)
  f:SetSub(W.Name(c) .. " - " .. row.state)
  if row.active then
    lines[#lines + 1] = W.CategoryText(row.active.categories)
    lines[#lines + 1] = row.active.note ~= "" and row.active.note or ns.Locale:Get("reputation.details.no_public_explanation_added.1df262")
    lines[#lines + 1] = ns.Locale:Format("reputation.details.approved_by_row_active_by.d9c87e", { row_active_by = row.active.by })
  end
  if W.CanModerate(c) then
    lines[#lines + 1] = ns.Locale:Format("reputation.details.row_count_distinct_reporting_identities_row_pending.e3616d", { row_count = row.count, row_pending = row.pending })
    local reports = {}
    for _, report in pairs(row.reports) do reports[#reports + 1] = report end
    table.sort(reports, function(a, b) return a.by < b.by end)
    for _, report in ipairs(reports) do
      lines[#lines + 1] = "\n" .. report.by .. " - " .. W.CategoryText(report.categories)
      lines[#lines + 1] = report.note ~= "" and report.note or ns.Locale:Get("reputation.details.no_note.8cb0e7")
    end
  else
    local report = W.OwnReport(c, row.target)
    if report then lines[#lines + 1] = ns.Locale:Format("reputation.details.your_report_value2_report_note.2a4756", { value2 = W.DeliveryText(c, report), report_note = report.note }) end
  end
  lines[#lines + 1] = ns.Locale:Get("reputation.details.moderation_history.644733")
  local actions = {}
  for _, op in ipairs(row.actions) do actions[#actions + 1] = op end
  table.sort(actions, function(a, b) return a.clock == b.clock and a.id > b.id or a.clock > b.clock end)
  for _, op in ipairs(actions) do
    lines[#lines + 1] = "\n" .. op.kind:upper() .. " - " .. op.by .. " - " .. date("%Y-%m-%d %H:%M", op.at)
    lines[#lines + 1] = op.note ~= "" and op.note or W.CategoryText(op.categories)
  end
  f.history:SetText(table.concat(lines, "\n")); f.history:Scroll(0)
  local mod = W.CanModerate(c)
  f.moderator = mod
  f.approve:SetShown(mod); f.revoke:SetShown(mod); f.dismiss:SetShown(mod)
  f.revoke:SetEnabled(row.active ~= nil); f.dismiss:SetEnabled(row.pending > 0)
  f:Show()
end
