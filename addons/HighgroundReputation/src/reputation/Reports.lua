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

function W.MergeReport(c, r, sender, attested)
  if not W.Joined(c) or not ns.Organizations.IsMember(c.id, sender) or not W.ValidReport(r) or (attested and not W.CanModerate(c, sender)) or (not attested and sender ~= r.by) then return false end
  local old = c.reports[r.id]
  if old then
    if old.account ~= r.account or old.by ~= r.by or not W.Same(old.target, r.target) then return false end
    if r.revision <= old.revision then return r.revision == old.revision end
  elseif W.Count(c.reports) >= W.MAX_REPORTS then return false end
  -- Changing characters or inventing another report ID never adds a second
  -- vote for this account and target. This ID is not Blizzard-verified.
  for id, other in pairs(c.reports) do
    if id ~= r.id and other.account == r.account and W.Same(other.target, r.target) then return false end
  end
  c.reports[r.id] = W.ReportWire(r)
  W.caseCache[c] = nil
  return true
end

function W.Submit(c, target, categories, note)
  if not W.Joined(c) then return nil, "Choose one of your guilds or communities first." end
  if not W.ValidTarget(target) then return nil, "Select an exact player identity." end
  categories = W.Categories(categories)
  if not categories then return nil, "Choose at least one category." end
  if target.name == W.Me() then return nil, "You cannot report yourself." end
  local old = W.OwnReport(c, target)
  if old and old.by ~= W.Me() then
    return nil, "Already reported on this account. Log into " .. old.by .. " to amend its note."
  end
  local r = { id = old and old.id or W.NewID(), account = W.db.id, by = W.Me(), target = W.Copy(target),
    categories = categories, note = W.Text(note, 280), revision = old and old.revision + 1 or 1, at = W.Now() }
  if not W.MergeReport(c, r, W.Me()) then return nil, "The report could not be stored; the community may be full." end
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
