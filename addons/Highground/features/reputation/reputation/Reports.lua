local _, ns = ...
local W = ns.Reputation

function W.ValidReport(r)
  return type(r) == "table" and W.ID(r.id) and W.ID(r.account) and W.String(r.by, 200)
    and W.Actor(r.by) == r.by and W.ValidTarget(r.target) and W.Categories(r.categories) ~= nil
    and W.String(r.note, 280, true) and W.Int(r.revision, 1, 1000000000) and W.Int(r.at, 1, 4102444800)
end

function W.ReportWire(r)
  return { id = r.id, account = r.account, by = r.by, target = W.Copy(r.target), categories = W.Copy(r.categories),
    note = r.note, revision = r.revision, at = r.at }
end

function W.OwnReport(c, target)
  for _, r in pairs(c.reports) do
    if r.account == W.db.id and W.Same(r.target, target) then return r end
  end
end

-- Returns whether the report is stored, and why not: "invalid" (bad data,
-- sender or identity), "stale" (an older revision), "full" or "duplicate".
function W.MergeReport(c, r, sender, attested)
  if not W.Joined(c) or not ns.Organizations.IsMember(c.id, sender) or not W.ValidReport(r) or (attested and not W.CanModerate(c, sender)) or (not attested and sender ~= r.by) then return false, "invalid" end
  local old = c.reports[r.id]
  if old then
    if old.account ~= r.account or old.by ~= r.by or not W.Same(old.target, r.target) then return false, "invalid" end
    if r.revision <= old.revision then return r.revision == old.revision, "stale" end
  elseif W.Count(c.reports) >= W.MAX_REPORTS then return false, "full" end
  -- Changing characters or inventing another report ID never adds a second
  -- vote for this account and target. The account ID is not Blizzard-verified,
  -- so one character also has one vote per target and a bounded share.
  local mine = 0
  for id, other in pairs(c.reports) do
    if id ~= r.id and (other.account == r.account or other.by == r.by) and W.Same(other.target, r.target) then return false, "duplicate" end
    if other.by == r.by then mine = mine + 1 end
  end
  if not old and mine >= W.REPORTS_PER_MEMBER then return false, "full" end
  c.reports[r.id] = W.ReportWire(r)
  W.caseCache[c] = nil
  return true
end

function W.Submit(c, target, categories, note)
  if not W.Joined(c) then return nil, ns.Locale:Get("reputation.reports.choose_one_of_your_guilds_or_communities.487b18") end
  if not W.ValidTarget(target) then return nil, ns.Locale:Get("highground.coachrecords.select_an_exact_player_identity.d6a825") end
  categories = W.Categories(categories)
  if not categories then return nil, ns.Locale:Get("highground.coachrecords.choose_at_least_one_category.2d9bda") end
  if target.name == W.Me() then return nil, ns.Locale:Get("reputation.reports.you_cannot_report_yourself.6630da") end
  local old = W.OwnReport(c, target)
  if old and old.by ~= W.Me() then
    return nil, ns.Locale:Format("reputation.reports.already_reported_on_this_account_log_into.3e6c1d", { old_by = old.by })
  end
  local r = { id = old and old.id or W.NewID(), account = W.db.id, by = W.Me(), target = W.Copy(target),
    categories = categories, note = W.Text(note, 280), revision = old and old.revision + 1 or 1, at = W.Now() }
  if not W.MergeReport(c, r, W.Me()) then return nil, ns.Locale:Get("reputation.reports.the_report_could_not_be_stored_the.7b5a0a") end
  c.reports[r.id].delivery = W.CanModerate(c) and "received" or "queued"
  W.db.pending[r.id] = not W.CanModerate(c) and { community = c.id, report = W.ReportWire(r) } or nil
  W.Changed(c)
  if W.SendReports then W.SendReports(c) end
  return c.reports[r.id]
end

function W.ReportsFor(c, target)
  local out = {}
  for _, r in pairs(c.reports) do if W.Same(r.target, target) then out[#out + 1] = r end end
  table.sort(out, function(a, b) return a.at == b.at and a.id < b.id or a.at > b.at end)
  return out
end

-- Reviewed reports become history after REPORT_DAYS and are dropped, so the
-- store does not fill. Every client applies the same rule to the same
-- decisions, so moderators' report digests agree again after a sync.
function W.PruneReports(c)
  local cutoff, removed = W.Now() - W.REPORT_DAYS * 86400, false
  for _, row in pairs(W.Cases(c)) do
    for account, r in pairs(row.reports) do
      if r.at < cutoff and (row.reviewed[account] or 0) >= r.revision and c.reports[r.id] == r then
        c.reports[r.id], removed = nil, true
      end
    end
  end
  if removed then W.Changed(c) end
end
