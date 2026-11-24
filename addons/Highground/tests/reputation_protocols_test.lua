local t = dofile("../../tools/harness.lua")("reputation protocols")
local F = dofile("tests/reputation/fixture.lua")

t.test("capabilities preserve organization permissions and reject unsupported snapshots", function()
  local s = F.new("Owner")
  local w = F.W(s)
  local org = F.community(s)
  s.env.wipe(w.outbox)
  local packet = { kind = "query", community = org.id, request = w.NewID() }
  local function Caps(name, version)
    s:event("CHAT_MSG_ADDON", "HighgroundN", "1|" .. s.ns.Scope.Social() .. "|reputation=" .. version,
      "WHISPER", name)
  end
  Caps("Stranger-Realm", "1")
  t.equal(w.Enqueue(packet, "Stranger-Realm"), false, "advertised support never grants membership")
  Caps("Moderator-Realm", "2")
  t.equal(w.Enqueue(packet, "Moderator-Realm"), false, "known unsupported snapshot rejected")
  assert(w.transportError:find("reputation sharing", 1, true))
  t.equal(#w.outbox, 0, "nothing incompatible queued")
  Caps("Moderator-Realm", "1")
  assert(w.Enqueue(packet, "Moderator-Realm"))
  Caps("Moderator-Realm", "2")
  local before = #s.sent
  w.Flush()
  t.equal(#s.sent, before, "queued transfers recheck the current peer")
  s.ns.Protocols.Clear()
  assert(w.Enqueue(packet, "Moderator-Realm"), "legacy peer still works")
  w.Flush()
  t.equal(s.sent[before + 1].prefix, w.PREFIX, "existing reputation frame goes first")
  t.equal(s.sent[before + 2].prefix, "HighgroundN", "automatic capability announcement uses the same whisper")
  s:assertHealthy()
end)

t.finish("Reputation protocols: " .. t.tests .. " tests, " .. t.checks .. " checks")
