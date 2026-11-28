-- Wanted posters: who a reward is from, sighting rows and the contract's
-- label/value layout (bounty/Messages.lua, Sightings.lua, Wanted.lua).
local t = dofile("../../tools/harness.lua")("bounty posters")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local test, equal = t.test, t.equal

local NOW = 1795861680
local function start()
  local s = new("retail", nil, function(sim) dofile("../../tools/wowsim/geometry.lua")(sim) end)
  s.now = NOW
  return s, s.ns.Bounty
end

test("posters name who a reward is from", function()
  local _, B = start()
  local now = B.Public.Now()
  local function offer(by, gold, extra)
    local p = { id = by .. gold, by = by, gold = gold, state = "active", expiresAt = now + 3600, killsAwarded = 0 }
    for k, v in pairs(extra or {}) do p[k] = v end
    return p
  end
  equal(B.From({ contributions = { offer("Ally-Realm", 500) } }), "From Ally", "one shared offer")
  equal(B.From({ contributions = { offer("Small-Realm", 100), offer("Big-Realm", 900), offer("Mid-Realm", 300) } }),
    "From Big and 2 others", "the largest pledge is named")
  equal(B.From({ contributions = { offer("Ally-Realm", 500), offer("Other-Realm", 100) } }), "From Ally and 1 other", "singular")
  equal(B.From({ contributions = { offer("Old-Realm", 5000, { expiresAt = now - 1 }), offer("Ally-Realm", 50) } }),
    "From Ally", "expired offers are left out")
  equal(B.From({ contributions = { offer("Ally-Realm", 500, { imported = true }) } }), "From Ally · imported offer", "imported")
  equal(B.From({ contributions = { offer(B.Me(), 500) } }), "Your bounty", "own offer")
  equal(B.From({ name = "Enemy-Realm", by = "Officer-Realm", gold = 100, state = "approved" }), "From Officer · Guild", "guild bounty")
  equal(B.From({ name = "Enemy-Realm", by = B.Me(), gold = 0, state = "personal" }), "Your bounty", "private target")
end)

test("sighting rows drop a first report that is also the last", function()
  local _, B = start()
  local now = B.Public.Now()
  local seen = { by = "Scout-Realm", at = now - 300, zone = "Feralas", area = "The Twin Colossals", mapID = 69, world = true, guid = "" }
  local rows = B.Sightings.Facts({ name = "Enemy-Realm", intel = { origin = seen, latest = seen } }, {})
  equal(#rows, 1, "one sighting, one row")
  equal(rows[1][1], "Last seen", "label")
  equal(rows[1][2], "The Twin Colossals · Feralas\nScout · 5m ago", "place, then who and when")
  local first = { by = "Main-Realm", at = now - 3 * 86400, zone = "Feralas", area = "Feralas", mapID = 69, world = true, guid = "" }
  rows = B.Sightings.Facts({ name = "Enemy-Realm", intel = { origin = first, latest = seen } }, {})
  equal(#rows, 2, "an earlier first sighting")
  equal(rows[2][1], "First seen", "second row")
  equal(rows[2][2], "Feralas\nMain · 3d ago", "a zone without a separate area")
  equal(B.Sightings.Brief({ name = "Enemy-Realm", intel = { origin = first, latest = seen } }),
    "Last seen The Twin Colossals · Feralas · 5m ago", "one line for popups")
  equal(B.Sightings.Brief({ name = "Enemy-Realm" }), nil, "no sighting")
end)

test("the new-bounty popup names the sender and keeps tracking to its button", function()
  local s, B = start()
  local p = { id = "offer", by = "Ally-Realm", gold = 500, state = "active", expiresAt = B.Public.Now() + 3600, killsAwarded = 0 }
  B.Matches.Show({ name = "Enemy-Realm", gold = 500, state = "public", contributions = { p } }, true)
  local w = assert(B.Matches.previewWin)
  equal(w.from:GetText(), "From Ally", "sender")
  assert(w.from:IsShown() and not w.trackingLabel:IsShown(), "no tracking stamp beside Start tracking")
  local name, from, reward = s.bounds(w.name), s.bounds(w.from), s.bounds(w.reward)
  -- Simulator y grows downward.
  assert(name[2] + name[4] <= from[2] + 0.5 and from[2] + from[4] <= reward[2] + 0.5, "name, sender, then reward")
  equal(w.details.tone, "posterPrimary", "parchment primary")
  equal(w.ignore.tone, "posterSecondary", "parchment secondary")
end)

test("contract rows share a label column and wrap beside it", function()
  local s, B = start()
  local card = B.Wanted.Build(s.env.CreateFrame("Frame", nil, s.env.UIParent))
  card.fullPoster = true
  B.Wanted.Fill(card, { name = "Enemy-Realm", gold = 500 }, { width = 480, compact = true, status = "SHARED", progress = "",
    facts = { { "Progress", "0/1 kills approved" }, { "Posted by", "Main" }, { "Last seen", "The Twin Colossals · Feralas\nScout · 5m ago" } } })
  local rows = card.factRows
  equal(rows[1].label:GetText(), "PROGRESS", "labels in capitals")
  local first, second, third = s.bounds(rows[1].label), s.bounds(rows[2].label), s.bounds(rows[3].label)
  equal(first[1], second[1], "labels share a left edge")
  local widest = 0
  for i = 1, 3 do widest = math.max(widest, rows[i].label:GetStringWidth()) end
  for i = 1, 3 do
    local value = s.bounds(rows[i].value)
    assert(value[1] >= first[1] + widest, "value " .. i .. " starts after the widest label")
  end
  assert(s.bounds(rows[3].value)[4] > s.bounds(rows[1].value)[4], "a two-line value is taller")
  assert(second[2] > first[2] and third[2] > second[2], "rows run downward")
  assert(card.statusRules[1]:IsShown() and card.statusRules[2]:IsShown(), "rules frame the audience stamp")
end)

t.finish("Bounty posters: " .. t.tests .. " scenarios, " .. t.failures .. " failures")
