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
    -- Moderator actions share one toolbar; hidden actions leave no gap.
    f.actions = K.Toolbar(f, { height = 30 })
    f.actions:SetPoint("BOTTOMLEFT", 18, 18)
    f.approve = f.actions:Add(K.Button(f.actions, "Review / blacklist...", 190, 30, { tone = "accent", onClick = function()
      W.OpenReport(f.row.target, f.community)
    end }))
    f.revoke = f.actions:Add(K.Button(f.actions, "Revoke...", 140, 30, { onClick = function() W.OpenReason(f.community, f.row.target, "revoke") end }))
    f.dismiss = f.actions:Add(K.Button(f.actions, "Dismiss proposals...", 195, 30, { onClick = function() W.OpenReason(f.community, f.row.target, "dismiss") end }))
    -- Resizing the dialog or changing text size reflows the actions.
    local function Reflow() if f:IsShown() then f.actions:Layout(math.max(1, f:GetWidth() - 36)) end end
    f:HookScript("OnSizeChanged", Reflow)
    ns.Core.OnFontScaleChange(Reflow)
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
    if report then lines[#lines + 1] = "\nYour report: " .. W.DeliveryText(c, report) .. "\n" .. report.note end
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
  f.actions:SetShown(mod)
  f:Show()
  f.actions:Layout(math.max(1, f:GetWidth() - 36))
end
