local t = ...
local H = dofile("tests/suggestions/fixture.lua")
local F, equal = H.F, t.equal

t.test("guild reports combine across Bounties and Nearby without double counting replayed packets", function()
  local a = H.new("Alice", { saved = { bountySuggestions = true } })
  local m = H.new("Mira", { addon = "HighgroundNearby" })
  local h = H.new("Thorn", { client = "cata" })
  for _ = 1, 2 do H.death(a, "Enemy-Other"); H.death(m, "Enemy-Other") end
  H.death(h, "Enemy-Other")
  a:advance(5)
  H.deliver(m, a); H.deliver(h, a); H.deliver(m, a); H.deliver(h, a)
  local B, S = a.ns.Bounty, a.ns.Bounty.Suggestions
  local rows = S.Rows()
  equal(#rows, 1, "one candidate for the target")
  equal(rows[1].personal, 2, "two deaths belong to this player")
  equal(rows[1].guildDeaths, 5, "five distinct death events")
  equal(rows[1].guildVictimCount, 3, "three characters")
  equal(rows[1].mode, "guild", "guild trigger chooses Guild")
  equal(#H.packets(a), 0, "receiving does not enable sharing")
  S.View.Review("Enemy-Other")
  equal(B.Form.win.formMode, "guild", "guild suggestion prefills audience")
  B.Form.Save(B.Form.win)
  equal(B.Guild()["enemy-other"].state, "pending", "member submission still needs officer approval")
  equal(B.Guild()["enemy-other"].gold, 0, "reward was optional")
  equal(#a.chat, 0, "reports do not write visible chat")
  a:assertHealthy(); m:assertHealthy(); h:assertHealthy()
end)

t.test("guild notifications reach victims and officers; uninvolved members see the board quietly", function()
  local o = H.new("Officer", { rank = 1 })
  local a = H.new("Alice")
  local m = H.new("Mira")
  local h = H.new("Thorn")
  for _ = 1, 3 do H.death(m, "Enemy-Realm") end
  for _ = 1, 2 do H.death(h, "Enemy-Realm") end
  H.death(a, "Enemy-Realm")
  o:advance(20)
  local other = H.new("Observer", { roster = { { "Observer-Realm", 5 }, { "Alice-Realm", 5 }, { "Mira-Realm", 5 }, { "Thorn-Realm", 5 } } })
  other:advance(20)
  for _, source in ipairs({ a, m, h }) do H.deliver(source, o); H.deliver(source, other) end
  o:advance(1); other:advance(1)
  assert(o.ns.Bounty.Suggestions.View.toast:IsShown(), "officer gets a prompt")
  assert(not other.ns.Bounty.Suggestions.View.toast, "uninvolved member gets no prompt")
  equal(#other.ns.Bounty.Suggestions.Rows(), 1, "uninvolved member can still review on board")
  o.ns.Bounty.Suggestions.View.Review("Enemy-Realm")
  o.ns.Bounty.Form.Save(o.ns.Bounty.Form.win)
  equal(o.ns.Bounty.Guild()["enemy-realm"].state, "approved", "officer action retains existing approval semantics")
end)

t.test("invalid, foreign, stale and future death reports cannot manufacture a candidate", function()
  local s = H.new()
  local now = s.ns.Bounty.Public.Now()
  local function packet(id, at, name, source, zone)
    return table.concat({ "1:D", id or "death.0001", at or now, name or "Enemy-Other", source or "recap", zone or "Hillsbrad" }, ",")
  end
  H.receive(s, packet(), "Outsider-Realm")
  H.receive(s, packet(), "Mira-Realm", "WHISPER")
  H.receive(s, packet(nil, now + 100))
  H.receive(s, packet(nil, now - 1801))
  H.receive(s, packet(nil, nil, "Enemy"))
  H.receive(s, packet(nil, nil, "Mira-Realm"))
  H.receive(s, packet(nil, nil, nil, "guessed"))
  H.receive(s, packet(nil, nil, nil, nil, "|cffff0000Fake"))
  H.receive(s, packet() .. ",Thorn-Realm")
  H.receive(s, string.rep("x", 256))
  equal(#s.ns.Bounty.Suggestions.Data().events, 0, "invalid reports ignored")
  H.receive(s, packet())
  H.receive(s, packet())
  H.receive(s, packet("different.id"))
  equal(#s.ns.Bounty.Suggestions.Data().events, 1, "same victim/time is one death even with a changed ID")
  equal(s.ns.Bounty.Suggestions.Data().events[1].victim, "Mira-Realm", "victim comes from the sender")
  s:assertHealthy()
end)

t.test("different realms stay separate and guild thresholds require different victims", function()
  local s = H.new()
  for i = 1, 6 do
    s.epoch = s.epoch + 3
    H.receive(s, "1:D,death.000" .. i .. "," .. s.ns.Bounty.Public.Now() .. ",Enemy-Other,recap,Hillsbrad")
  end
  equal(#s.ns.Bounty.Suggestions.Rows(), 0, "many reports from one victim are not a guild incident")
  for _ = 1, 2 do H.death(s, "Enemy-Realm") end
  equal(#s.ns.Bounty.Suggestions.Rows(), 0, "same short name from another realm does not combine")
  H.death(s, "Enemy-Realm")
  equal(#s.ns.Bounty.Suggestions.Rows(), 1, "personal threshold works independently")
  equal(s.ns.Bounty.Suggestions.Rows()[1].name, "Enemy-Realm", "correct realm")
end)

t.test("guild changes drop other guild reports and queued sends; recent personal deaths remain personal", function()
  local s = H.new()
  H.receive(s, "1:D,death.0001," .. s.ns.Bounty.Public.Now() .. ",Enemy-Realm,recap,Hillsbrad")
  local S = s.ns.Bounty.Suggestions
  S.LocalDeath({ name = "Enemy-Realm", at = s.ns.Bounty.Public.Now(), source = "recap", zone = "Hillsbrad" })
  s.guild = "New Guild"; s.roster = { { "Alice-Realm", 5 } }
  s:event("PLAYER_GUILD_UPDATE"); s:event("GUILD_ROSTER_UPDATE"); s:advance(2)
  equal(#S.Data().events, 1, "old guild's reports removed")
  equal(S.Data().events[1].guild, nil, "personal death does not become a new guild death")
  equal(#H.packets(s), 0, "old-guild packet never sent to new guild")
  s:assertHealthy()
end)

t.test("pending sends respect opt-out; report count is bounded under a flood", function()
  local s = H.new()
  local S, P = s.ns.Bounty.Suggestions, s.ns.Bounty.Public
  S.LocalDeath({ name = "Enemy-Realm", at = P.Now(), source = "recap", zone = "Hillsbrad" })
  s.ns.Core.SetOption("bountyDeathShare", false); s:advance(2)
  equal(#H.packets(s), 0, "queued message discarded on opt-out")
  for i = 1, 100 do
    s.epoch = s.epoch + 1
    H.receive(s, "1:D,death.000" .. i .. "," .. P.Now() .. ",Enemy-Realm,recap,Hillsbrad")
  end
  assert(#S.Data().events <= 61, "per-victim limit bounds report storage")
  equal(#S.Rows(), 0, "flood still lacks distinct guild victims")
end)

t.test("reload and switching addons preserve notification cooldown and exact event identities", function()
  local s = H.new()
  for _ = 1, 3 do H.death(s, "Enemy-Realm") end
  local P = s.ns.Bounty.Public
  local copy = P.Copy(P.db)
  local switched = H.new("Alice", { addon = "HighgroundNearby", network = copy, epoch = s.epoch + math.floor(s.now) })
  switched:advance(2)
  equal(#switched.ns.Bounty.Suggestions.Rows(), 1, "recent candidate survives client switch")
  equal(#switched.ns.Bounty.Suggestions.Data().events, 3, "no lifetime totals imported or duplicate events")
  assert(not switched.ns.Bounty.Suggestions.View.toast, "cooldown prevents a repeated prompt")
  equal(#H.packets(switched), 0, "saved reports are not rebroadcast")
  switched:assertHealthy()
end)

t.test("a bounty created while a suggestion draft is open cannot be overwritten by that draft", function()
  local s = H.new()
  local B = s.ns.Bounty
  for _ = 1, 3 do H.death(s, "Enemy-Realm") end
  B.Suggestions.View.Review("Enemy-Realm")
  B.Add("Enemy-Realm", 250, "Existing reward")
  B.Form.Save(B.Form.win)
  equal(B.Personal()["enemy-realm"].gold, 250, "existing reward preserved")
  assert(B.Form.win.error:GetText():find("already exists", 1, true), "reviewer receives actionable feedback")
  s:assertHealthy()
end)

t.test("saved guild reports wait for the roster after reload and exclude departed members once it loads", function()
  local a, m, h = H.new("Alice"), H.new("Mira"), H.new("Thorn")
  for _ = 1, 2 do H.death(a, "Enemy-Realm"); H.death(m, "Enemy-Realm") end
  H.death(h, "Enemy-Realm"); a:advance(5)
  H.deliver(m, a); H.deliver(h, a)
  equal(#a.ns.Bounty.Suggestions.Rows(), 1, "guild threshold before reload")
  local copy = a.ns.Bounty.Public.Copy(a.ns.Bounty.Public.db)
  local s = H.new("Alice", { network = copy, epoch = a.epoch + math.floor(a.now), roster = {} })
  s:advance(2)
  equal(#s.ns.Bounty.Suggestions.Data().events, 5, "reports retained while roster is unavailable")
  equal(#s.ns.Bounty.Suggestions.Rows(), 0, "unverified roster does not trigger suggestions")
  s.roster = H.roster; s:event("GUILD_ROSTER_UPDATE")
  equal(#s.ns.Bounty.Suggestions.Rows(), 1, "reports count when membership is known")
  s.roster = { { "Alice-Realm", 5 }, { "Mira-Realm", 5 } }; s:event("GUILD_ROSTER_UPDATE")
  equal(#s.ns.Bounty.Suggestions.Rows(), 0, "departed victim no longer establishes a guild incident")
  s:assertHealthy()
end)
