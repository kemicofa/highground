local _, ns = ...
local B = ns.Bounty
local S = {}
B.Scope = S

-- Bounty storage and wire envelopes remain feature-owned; all addons use
-- the same game, region, realm and Forever ruleset boundaries.
S.Ruleset, S.Key, S.Label = ns.Scope.Ruleset, ns.Scope.Key, ns.Scope.Label

function S.Wrap(text)
  if not ns.Caps.rulesetRealms then return text end
  return "3:" .. (S.Ruleset() or S.Key()) .. ";" .. text
end

function S.Unwrap(text)
  if not ns.Caps.rulesetRealms then return text end
  local scope, payload = text:match("^3:([^;]+);(.*)$")
  if scope == (S.Ruleset() or S.Key()) then return payload end
end

function S.Saved(name)
  local db = ns.Core.db
  if not db then return {} end
  if ns.Caps.rulesetRealms then
    db.bountyRulesets = type(db.bountyRulesets) == "table" and db.bountyRulesets or {}
    local key = S.Key()
    db.bountyRulesets[key] = db.bountyRulesets[key] or {}
    db = db.bountyRulesets[key]
    -- Older unscoped lists remain intact in the original saved fields.
    -- Their ruleset cannot be inferred safely from an enemy's realm ID.
  end
  db[name] = type(db[name]) == "table" and db[name] or {}
  return db[name]
end

function S.Check()
  local key = S.Key()
  if key == S.current then return false end
  local previous = S.current
  S.current = key
  if not previous then return false end
  local P = B.Public
  for _, field in ipairs({ "outbox", "incoming", "rates", "peers", "replies" }) do wipe(P[field] or {}) end
  P.cache, P.nextHello, P.nextHeartbeat, P.nextPrune = nil, 0, 0, 0
  P.quietUntil = GetTime() + 12
  wipe(B.seen or {})
  if B.Poster then
    wipe(B.Poster.pending)
    if B.Poster.win then B.Poster.win:Hide() end
    B.Poster.StopPreview()
  end
  -- Discard return paths and drafts referencing the previous realmset.
  for _, name in ipairs({ "GoldView", "Form", "Details", "Ledger", "Import", "Preview" }) do
    local w = B[name] and B[name].win
    if w then
      ns.Kit.Windows.Forget(w)
      ns.Kit.Windows.Close(w)
    end
  end
  B.Emit("scope", previous, key)
  B.Emit("updated")
  return true
end
