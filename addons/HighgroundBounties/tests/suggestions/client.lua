local t, addon = ...
local H = dofile("../HighgroundBounties/tests/suggestions/fixture.lua")
local equal = t.equal
local function make(build, saved, network, epoch)
  return H.new("Alice", { addon = addon, build = build, client = build == 40402 and "cata" or "retail",
    saved = saved, network = network, epoch = epoch })
end

for _, build in ipairs({ 120100, 16001, 40402 }) do
  t.test(addon .. " " .. build .. ": optional suggestions review and save through the existing form", function()
    local s = make(build, { nearby = false, nearbyHistory = false })
    local B, Core = s.ns.Bounty, s.ns.Core
    H.death(s, "Enemy-Other")
    equal(#B.Suggestions.Rows(), 0, "off by default")
    equal(#H.packets(s), 0, "sharing is off by default")
    Core.SetOption("bountySuggestions", true)
    for _ = 1, 2 do H.death(s, "Enemy-Other") end
    equal(#B.Suggestions.Rows(), 0, "two deaths do not suggest")
    H.death(s, "Enemy-Other")
    local r = B.Suggestions.Rows()[1]
    equal(r.personal, 3, "one record per death, independent of nearby history and panel")
    equal(#H.packets(s), 0, "suggestions do not enable sharing")
    assert(B.Suggestions.View.toast:IsShown(), "postcombat suggestion")
    equal(next(B.Personal()), nil, "no bounty before player confirmation")
    equal(next(B.Public.Data().offers), nil, "no reward pledged")
    local slash = addon == "Highground" and "HIGHGROUND" or addon:upper()
    local command = addon == "HighgroundBounties" and "suggestions" or "bounty suggestions"
    s:slash(slash, command)
    local board = B.Board.win
    equal(B.Board.tab, "suggestions", "addon command opens Suggestions")
    equal(board.tabs.suggestions.count:GetText(), "1", "target grouped once")
    equal(board.rows[1].primary:GetText(), "Review bounty", "review action")
    board.rows[1].details.scripts.OnClick(board.rows[1].details)
    assert(B.Suggestions.View.details.text:GetText():find("Alice%-Realm: 3"), "victim breakdown")
    B.Suggestions.View.details.review.scripts.OnClick(B.Suggestions.View.details.review)
    local form = B.Form.win
    equal(form.name:GetText(), "Enemy-Other", "exact target copied")
    equal(form.gold:GetText(), "", "reward starts blank")
    equal(form.formMode, "personal", "personal trigger defaults to Only me")
    assert(form.note:GetText():find("Reported: 3 deaths", 1, true), "reason copied")
    equal(next(B.Personal()), nil, "opening draft does not save")
    form.action.scripts.OnClick(form.action)
    equal(B.Personal()["enemy-other"].gold, 0, "explicit save supports no reward")
    B.Suggestions.View.Review("Enemy-Other")
    assert(not form:IsShown(), "existing bounty opens without another draft")
    equal(B.Board.tab, "mine", "existing listing opened")
    s:assertHealthy()
  end)
end

t.test(addon .. ": combat defers suggestions; ignore, dismiss, expiry and reload keep their meaning", function()
  local saved = { bountySuggestions = true, bountySuggestionWindow = 5 }
  local s = make(120100, saved)
  local B, S = s.ns.Bounty, s.ns.Bounty.Suggestions
  s:setCombat(true)
  for _ = 1, 3 do H.death(s, "Enemy-Realm") end
  assert(not S.View.toast or not S.View.toast:IsShown(), "no popup during combat")
  s:setCombat(false); s:advance(1)
  assert(S.View.toast:IsShown(), "queued until combat ends")
  S.Change("Enemy-Realm", "ignore")
  equal(#S.Rows(), 0, "ignore hides candidate")
  assert(not S.View.toast:IsShown(), "ignore closes prompt")
  s.epoch = s.epoch + 301; s:advance(1)
  equal(#S.Data().events, 0, "old reports expire")
  equal(#S.Rows("", true), 1, "ignored target remains manageable after expiry")
  B.Board.SetTab("suggestions"); B.Board.Open()
  B.Board.win.review:SetChecked(true)
  equal(B.Board.win.rows[1].primary:GetText(), "Allow again", "ignored row offers undo")
  B.Board.win.rows[1].primary.scripts.OnClick(B.Board.win.rows[1].primary)
  equal(#S.Rows("", true), 0, "allow removes the ignore record")
  for _ = 1, 3 do H.death(s, "Enemy-Realm") end
  S.Change("Enemy-Realm", "dismiss")
  H.death(s, "Enemy-Realm")
  equal(#S.Rows(), 0, "new deaths cannot defeat a 24h dismissal")
  local reloaded = make(120100, saved, B.Public.Copy(B.Public.db), s.epoch + math.floor(s.now))
  equal(#reloaded.ns.Bounty.Suggestions.Rows(), 0, "dismissal survives reload")
  reloaded.epoch = reloaded.epoch + 86401
  for _ = 1, 3 do H.death(reloaded, "Enemy-Realm") end
  equal(#reloaded.ns.Bounty.Suggestions.Rows(), 1, "dismissal ends after a day")
  reloaded:assertHealthy(); s:assertHealthy()
end)

t.test(addon .. ": settings disable immediately queued sends and stale prompts", function()
  local s = make(120100, { bountySuggestions = true, bountyDeathShare = true })
  local S = s.ns.Bounty.Suggestions
  for _ = 1, 3 do H.death(s, "Enemy-Realm") end
  assert(S.View.toast:IsShown())
  s.ns.Core.SetOption("bountySuggestions", false)
  s.ns.Core.SetOption("bountyDeathShare", false)
  local count = #H.packets(s)
  H.death(s, "Enemy-Realm")
  equal(#H.packets(s), count, "disabled reporting stays silent")
  equal(#S.Data().events, 0, "disabled feature clears recent reports")
  assert(not S.View.toast:IsShown(), "disabled suggestions close prompt")
  s:assertHealthy()
end)
