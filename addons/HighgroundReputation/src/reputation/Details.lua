local _, ns = ...
local W, K = ns.Reputation, ns.Kit
local UI = W.UI

function W.OpenDetails(c, row, source)
  local W = source or W
  local UI = W.UI
  if not W.Joined(c) then return end
  if not UI.details then
    local f = UI.Dialog("Details", "PLAYER HISTORY", 640, 610)
    UI.details = f
    f.history = K.ScrollText(f.content, { bottomPadding = 24 })
    f.history:SetPoint("TOPLEFT", 0, -6); f.history:SetPoint("BOTTOMRIGHT", -10, 54)
    f.scroll, f.body, f.text = f.history.view, f.history.body, f.history.text
    f.approve = K.Button(f, "Review / blacklist...", 190, 30, { tone = "accent", onClick = function()
      W.OpenReport(f.row.target, f.community)
    end })
    f.approve:SetPoint("BOTTOMLEFT", 18, 18)
    f.revoke = K.Button(f, "Revoke...", 140, 30, { onClick = function() W.OpenReason(f.community, f.row.target, "revoke") end })
    f.revoke:SetPoint("LEFT", f.approve, "RIGHT", 10, 0)
    f.dismiss = K.Button(f, "Dismiss proposals...", 195, 30, { onClick = function() W.OpenReason(f.community, f.row.target, "dismiss") end })
    f.dismiss:SetPoint("LEFT", f.revoke, "RIGHT", 10, 0)
  end
  row = W.FindCase(c, row.target) or row
  local f, lines = UI.details, {}
  f.community, f.row = c, row
  f:SetTitle(row.target.name)
  f:SetSub(W.Name(c) .. " - " .. row.state)
  if row.active then
    lines[#lines + 1] = W.CategoryText(row.active.categories)
    lines[#lines + 1] = row.active.note ~= "" and row.active.note or "No public explanation added."
    lines[#lines + 1] = "Approved by " .. row.active.by
  end
  if W.CanModerate(c) then
    lines[#lines + 1] = "\n" .. row.count .. " distinct reporting identities; " .. row.pending .. " awaiting review."
    local reports = {}
    for _, report in pairs(row.reports) do reports[#reports + 1] = report end
    table.sort(reports, function(a, b) return a.by < b.by end)
    for _, report in ipairs(reports) do
      lines[#lines + 1] = "\n" .. report.by .. " - " .. W.CategoryText(report.categories)
      lines[#lines + 1] = report.note ~= "" and report.note or "No note."
    end
  else
    local report = W.OwnReport(c, row.target)
    if report then lines[#lines + 1] = "\nYour report: " .. (report.delivery or "received") .. "\n" .. report.note end
  end
  lines[#lines + 1] = "\nMODERATION HISTORY"
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
