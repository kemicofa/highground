local test, new, check = ...
local function equal(a, b, why) return check(a, b, why or "values match") end
local function peer(client, name)
  return new(client, {}, function(sim, env)
    sim.units.player.name = name
    env.C_ChatInfo.SendAddonMessage = function(prefix, message, channel, target)
      sim.sent[#sim.sent + 1] = { prefix = prefix, message = message, channel = channel, target = target, at = sim.now }
    end
  end)
end
local function packets(sim)
  local out = {}
  for _, p in ipairs(sim.sent) do if p.prefix == "HighgroundP" then out[#out + 1] = p end end
  return out
end
local function receive(sim, packet, source)
  equal(packet.channel, "WHISPER", "profile data travels privately")
  equal(packet.target, sim.ns.Core.CanonUnit("player"), "data goes to the requesting character")
  assert(#packet.message <= 255, "fits an addon message")
  sim:event("CHAT_MSG_ADDON", packet.prefix, packet.message, packet.channel, source)
end
-- Imports kept for addon (default Battlegrounds), in list order.
local function imports(sim, addon)
  local out = {}
  for _, item in ipairs(sim.ns.CharacterSettings.Profiles(addon or "battlegrounds")) do
    if item.kind == "import" then out[#out + 1] = item end
  end
  return out
end
local function said(sim, text)
  for i = #sim.messages, 1, -1 do if sim.messages[i]:find(text, 1, true) then return true end end
  return false
end
local function offer(sender, receiver, addon)
  addon = addon or "battlegrounds"
  local label = sender.units.player.name .. " · " .. sender.ns.Options.Profiles.AddonLabel(addon)
  assert(sender.ns.Options.Profiles.Chat.ToChat(addon))
  local rendered = sender.chatDraft
  for _, filter in ipairs(receiver.chatFilters.CHAT_MSG_PARTY) do
    local _, text = filter(nil, "CHAT_MSG_PARTY", rendered, "Alice-Realm")
    rendered = text or rendered
  end
  assert(rendered:find("[Profile: " .. label .. "]", 1, true), "chat shows a readable profile link: " .. rendered)
  local link = assert(rendered:match("|H([^|]+)|h"))
  receiver.env.SetItemRef(link)
  return link
end
local function pair(client)
  local a, b = peer(client, "Alice"), peer(client, "Bob")
  a.ns.Core.db.sniper = false
  a.ns.Alerts.SetMode("quiet")
  return a, b
end
local function download(a, b)
  receive(a, packets(b)[1], "Bob-Realm")
  a:advance(70)
  for _, p in ipairs(packets(a)) do receive(b, p, "Alice-Realm") end
end

for _, client in ipairs({ "cata", "retail" }) do
test(client .. " profile links draft, transfer and keep a frozen copy under the sender's name without applying it", function()
  local a, b = pair(client)
  equal(a.ns.Options.Profiles.Chat.sending.state, "idle")
  equal(b.ns.Options.Profiles.Chat.receiving.state, "idle")
  offer(a, b)
  equal(b.ns.Options.Profiles.Chat.receiving.state, "pending")
  assert(said(b, "Receiving Alice · Battlegrounds"), "the receiver sees the transfer start")
  equal(#a.chat, 0, "does not send a chat message")
  equal(#packets(a), 0, "sharing a link does not broadcast settings")
  a.ns.Core.SetFeature("sniper", true)
  download(a, b)
  equal(a.ns.Options.Profiles.Chat.sending.state, "succeeded")
  equal(b.ns.Options.Profiles.Chat.receiving.state, "succeeded")
  local kept = imports(b)
  equal(#kept, 1, "the shared settings join Profiles")
  equal(kept[1].name, "Alice", "named after the sender's character, without the realm")
  equal(#imports(b, "nearby"), 0, "a Battlegrounds link offers only Battlegrounds")
  assert(said(b, "Alice added to Profiles"), "receipt is reported")
  equal(b.ns.Hub.current, "profiles", "Profiles opens on receipt")
  equal(b.ns.Options.panel.addon, "battlegrounds", "on the shared addon")
  equal(b.ns.Core.db.sniper, true, "receiving never applies settings")
  assert(b.ns.CharacterSettings.Copy(kept[1].source, "battlegrounds"))
  equal(b.ns.Core.db.sniper, false, "changing settings after sharing cannot change the shared copy")
  local shared = 0
  for _, def in ipairs(b.ns.Alerts.categories) do
    if def.module == "battlegrounds" then
      shared = shared + 1
      local function channel(sim) return sim.ns.Codec.Pack({ sim.ns.Alerts.Settings().channels[def.key] }) end
      equal(channel(b), channel(a), "the shared Battlegrounds alert choices come along: " .. def.key)
    end
  end
  assert(shared > 0, "Battlegrounds owns alerts")
  local data = packets(a)
  for i = 2, #data do assert(data[i].at - data[i - 1].at >= 0.39, "transfer is paced") end
  a:assertHealthy(); b:assertHealthy()
end)
end

test("links share the chosen addon and the Profiles page drafts them", function()
  local a, b = pair("cata")
  a.ns.Core.SetTuning("option", "nearbyRows", 7)
  a.ns.Options.ShowProfiles("nearby")
  local p = a.ns.Options.panel
  p.chat:Click()
  assert(p.status:GetText():find("Press Enter to share", 1, true), "the page reports the draft")
  local payload = assert(a.chatDraft:match("%[HGP:([^%]]+)%]"), "the page drafts a link")
  equal(a.ns.Options.Profiles.Chat.Decode(payload).label, "Alice · Nearby", "the link names the character and addon")
  a.env.ChatFrame_OpenChat("")
  offer(a, b, "nearby")
  download(a, b)
  equal(#imports(b, "nearby"), 1, "a Nearby link offers Nearby")
  equal(#imports(b, "battlegrounds"), 0, "and nothing else")
  equal(b.ns.Options.panel.addon, "nearby", "Profiles opens on Nearby")
  assert(b.ns.CharacterSettings.Copy(imports(b, "nearby")[1].source, "nearby"))
  equal(b.ns.Core.O("nearbyRows"), 7, "copying applies the shared Nearby settings")
  a:assertHealthy(); b:assertHealthy()
end)

for _, client in ipairs({ "cata", "retail" }) do
test(client .. " profiles with the kill-target card hidden can be shared and restored", function()
  local a, b = pair(client)
  b.ns.Core.SetElement("hero", true)
  local C = a.ns.Core
  -- This is the value written by Appearance > Kill-target card.
  C.SetElement("hero", false)
  C.SetElement("rank", false)
  offer(a, b)
  C.SetElement("hero", true) -- the link keeps the visibility it was shared with
  download(a, b)
  local CS = b.ns.CharacterSettings
  equal(b.ns.Core.ShowsElement("hero"), true, "receiving does not apply settings")
  assert(CS.Copy(imports(b)[1].source, "battlegrounds"))
  equal(b.ns.Core.ShowsElement("hero"), false, "a chat profile restores the hidden card")
  equal(b.ns.Core.ShowsElement("rank"), false, "other hidden elements survive too")
  local code = CS.Export("battlegrounds")
  b.ns.Core.SetElement("hero", true)
  local ok, _, index = CS.Import(code, "Saved")
  assert(ok and CS.Copy({ import = index }, "battlegrounds"))
  equal(b.ns.Core.ShowsElement("hero"), false, "clipboard imports use the same validation")
  a:assertHealthy(); b:assertHealthy()
end)
end

test("visibility validation still rejects unknown elements and non-boolean values", function()
  local sim = peer("cata", "Alice")
  local P, C, CS = sim.ns.Options.Profiles, sim.ns.Core, sim.ns.CharacterSettings
  local before = P.ExportString(P.Snapshot())
  for _, entry in ipairs({ { "hero", "false" }, { "rank", 1 }, { "unknownElement", true } }) do
    local snap = P.Snapshot()
    snap.setup.style.hide[entry[1]] = entry[2]
    equal(CS.Import(P.ExportString(snap)), false, "invalid visibility is rejected")
    equal(#imports(sim), 0, "rejected imports are not kept")
    equal(P.ExportString(P.Snapshot()), before, "rejected imports do not change active settings")
  end
  equal(C.ShowsElement("hero"), false)
  sim:assertHealthy()
end)

test("chat sharing preserves a draft and rejects overflow or unknown addons", function()
  local sim = peer("retail", "Alice")
  sim.env.ChatFrame_OpenChat("Try this")
  sim:command("profile share")
  assert(sim.chatDraft:find("Try this [HGP:", 1, true))
  equal(#sim.chat, 0)
  sim.env.ChatFrame_OpenChat(string.rep("a", 250))
  local ok = sim.ns.Options.Profiles.Chat.ToChat("battlegrounds")
  equal(ok, false); equal(sim.chatDraft, string.rep("a", 250), "does not replace the draft")
  equal(sim.ns.Options.Profiles.Chat.ToChat("missing"), false, "an unknown addon has nothing to share")
end)

test("own links open locally and repeated imports never overwrite a kept profile", function()
  local sim = peer("cata", "Alice")
  local link = offer(sim, sim)
  equal(#packets(sim), 0, "own links need no network request")
  equal(imports(sim)[1].name, "Alice")
  sim.env.SetItemRef(link)
  local kept = imports(sim)
  equal(#kept, 2, "opening the link again adds another copy")
  equal(kept[2].name, "Alice (2)", "names stay unique")
  sim:advance(1801)
  sim.env.SetItemRef(link)
  assert(said(sim, "This link has expired"), "an expired own link explains itself")
  equal(#imports(sim), 2, "and adds nothing")
end)

test("unavailable chat transport fails without opening a draft", function()
  local sim = peer("retail", "Alice")
  local P = sim.ns.Options.Profiles
  sim.env.C_ChatInfo.SendAddonMessage = nil
  local ok, problem = P.Chat.ToChat("battlegrounds")
  equal(ok, false)
  assert(problem:find("Use Export", 1, true), "the error offers Export instead")
  assert(not sim.chatDraft, "failed shares never replace chat")
  sim:assertHealthy()
end)

test("wrong senders, other channels and unsolicited profile data are ignored", function()
  local a, b = pair("cata")
  offer(a, b)
  receive(a, packets(b)[1], "Bob-Realm"); a:advance(70)
  local data, share = packets(a), b.ns.Options.Profiles.Chat
  for _, p in ipairs(data) do b:event("CHAT_MSG_ADDON", p.prefix, p.message, "WHISPER", "Stranger-Realm") end
  for _, p in ipairs(data) do b:event("CHAT_MSG_ADDON", p.prefix, p.message, "PARTY", "Alice-Realm") end
  equal(#imports(b), 0, "nothing arrived from the wrong sender or channel")
  equal(share.receiving.state, "pending")
  share.Cancel()
  equal(share.receiving.state, "cancelled")
  for _, p in ipairs(data) do receive(b, p, "Alice-Realm") end
  equal(#imports(b), 0, "a cancelled request stays cancelled")
  equal(b.ns.Core.db.sniper, true)
end)

test("replacement profile requests own their timeout and retain their outcome", function()
  local a, b = pair("retail")
  local link = offer(a, b)
  local op = b.ns.Options.Profiles.Chat.receiving
  local first = op.current
  b:advance(45)
  b.env.SetItemRef(link)
  local retry = op.current
  equal(first.state, "cancelled", "reopening retires the old request")
  b:advance(46)
  assert(op:IsCurrent(retry), "old deadline cannot fail the replacement")
  receive(a, packets(b)[2], "Bob-Realm")
  a:advance(70)
  for _, packet in ipairs(packets(a)) do receive(b, packet, "Alice-Realm") end
  equal(retry.state, "succeeded")
  local lines = #b.messages
  b:advance(45)
  equal(op.state, "succeeded", "completed request keeps its outcome after its deadline")
  equal(#b.messages, lines, "a late deadline reports nothing")
  b.ns.Options.Profiles.Chat.Cancel()
  equal(op.state, "succeeded", "cancelling after completion keeps the transfer's outcome")
  equal(#imports(b), 1, "and its import")
  a:assertHealthy(); b:assertHealthy()
end)

test("failed profile requests and exhausted uploads can start a fresh transfer", function()
  local a, b = pair("retail")
  local sendRequest = b.env.C_ChatInfo.SendAddonMessage
  b.env.C_ChatInfo.SendAddonMessage = function() return true, false end
  local link = offer(a, b)
  local incoming = b.ns.Options.Profiles.Chat.receiving
  equal(incoming.state, "failed", "request rejection is terminal")
  equal(incoming.current, nil)
  b.env.C_ChatInfo.SendAddonMessage = sendRequest
  b.env.SetItemRef(link)
  local sendChunk = a.env.C_ChatInfo.SendAddonMessage
  a.env.C_ChatInfo.SendAddonMessage = function() return true, false end
  receive(a, packets(b)[1], "Bob-Realm")
  local outgoing = a.ns.Options.Profiles.Chat.sending
  local failed = outgoing.current
  a:advance(2)
  equal(outgoing.state, "failed", "three rejected chunks release the sender")
  equal(failed.state, "failed")
  equal(outgoing.current, nil)
  a.env.C_ChatInfo.SendAddonMessage = sendChunk
  b.env.SetItemRef(link)
  receive(a, packets(b)[2], "Bob-Realm")
  a:advance(70)
  for _, packet in ipairs(packets(a)) do receive(b, packet, "Alice-Realm") end
  equal(outgoing.state, "succeeded")
  equal(incoming.state, "succeeded")
  equal(#imports(b), 1, "the retry reaches Profiles")
  a:assertHealthy(); b:assertHealthy()
end)

test("out-of-order and duplicate chunks complete exactly once", function()
  local a, b = pair("retail")
  offer(a, b)
  receive(a, packets(b)[1], "Bob-Realm"); a:advance(70)
  local data = packets(a)
  assert(#data > 1, "the profile needs several chunks")
  for i = #data, 1, -1 do receive(b, data[i], "Alice-Realm"); receive(b, data[i], "Alice-Realm") end
  equal(#imports(b), 1, "one import")
  for _, p in ipairs(data) do receive(b, p, "Alice-Realm") end
  equal(#imports(b), 1, "late chunks do not import again")
end)

test("a rejected profile chunk retries the same part before completing the transfer", function()
  local a, b = pair("retail")
  offer(a, b)
  local send, attempts = a.env.C_ChatInfo.SendAddonMessage, 0
  a.env.C_ChatInfo.SendAddonMessage = function(prefix, ...)
    if prefix == "HighgroundP" then
      attempts = attempts + 1
      if attempts == 1 then return true, false end
    end
    return send(prefix, ...)
  end
  receive(a, packets(b)[1], "Bob-Realm")
  a:advance(70)
  local data = packets(a)
  assert(#data > 0 and data[1].message:match("^1:D:[^:]+:1:"), "first successful send is still part 1")
  equal(attempts, #data + 1, "one rejected attempt was retried")
  for _, packet in ipairs(data) do receive(b, packet, "Alice-Realm") end
  equal(#imports(b), 1, "all parts arrive and the profile is kept")
  equal(b.ns.Core.db.sniper, true, "receiving still does not apply settings")
  a:assertHealthy(); b:assertHealthy()
end)

test("oversized, inconsistent and invalid profile payloads cannot be imported", function()
  for _, kind in ipairs({ "count", "conflict", "invalid" }) do
    local a, b = pair("cata")
    offer(a, b)
    local id = packets(b)[1].message:match("^1:R:(.+)$")
    local text
    if kind == "count" then text = "1:D:" .. id .. ":1:999:AAAA"
    elseif kind == "invalid" then text = "1:D:" .. id .. ":1:1:" .. b.ns.Codec.Encode64("WB1;o.noSuchOption=true;x=AAAA")
    else
      b:event("CHAT_MSG_ADDON", "HighgroundP", "1:D:" .. id .. ":1:2:" .. string.rep("A", 200), "WHISPER", "Alice-Realm")
      text = "1:D:" .. id .. ":1:2:" .. string.rep("B", 200)
    end
    b:event("CHAT_MSG_ADDON", "HighgroundP", text, "WHISPER", "Alice-Realm")
    equal(#imports(b), 0, kind .. " payloads are not kept")
    assert(not said(b, "added to Profiles"), kind .. " payloads report no import")
    equal(b.ns.Core.db.sniper, true)
    b:assertHealthy()
  end
end)

test("offline, expired and busy links explain how to try again", function()
  local a, b = pair("retail")
  local link = offer(a, b)
  b:advance(91)
  assert(said(b, "must be online"), "an unanswered request explains why")
  b.env.SetItemRef(link)
  receive(a, packets(b)[2], "Bob-Realm")
  a:advance(1.1)
  local c = peer("retail", "Carol")
  c.env.SetItemRef(link); receive(a, packets(c)[1], "Carol-Realm")
  local data = packets(a)
  receive(c, data[#data], "Alice-Realm")
  assert(said(c, "sharing another profile"), "a busy sender explains why")
  a:advance(1801)
  b.env.SetItemRef(link); receive(a, packets(b)[3], "Bob-Realm")
  data = packets(a); receive(b, data[#data], "Alice-Realm")
  assert(said(b, "This link has expired"), "an expired link explains why")
end)

test("malformed chat tokens stay plain text and other addon links remain untouched", function()
  local sim = peer("cata", "Alice")
  for _, text in ipairs({ "[HGP:2:bad:bad:bad]", "[HGP:1:QQ==:1-2:QQ==]", "[HGP:" .. string.rep("a", 256) .. "]" }) do
    local _, result = sim.ns.Options.Profiles.Chat.Filter(nil, nil, text)
    equal(result, text)
  end
  local lines = #sim.messages
  sim.env.SetItemRef("addon:AnotherAddon:abc")
  equal(sim.ns.Options.Profiles.Chat.receiving.state, "idle", "another addon's link starts no transfer")
  equal(#sim.messages, lines, "and reports nothing")
end)

test("a profile received in combat is kept and copies once combat ends", function()
  local a, b = pair("cata")
  offer(a, b)
  b:setCombat(true)
  download(a, b)
  local item = imports(b)[1]
  assert(item, "receipt in combat keeps the profile")
  local ok, problem = b.ns.CharacterSettings.Copy(item.source, "battlegrounds")
  equal(ok, false, "copying waits for combat to end")
  equal(problem, "Copy profiles after combat.")
  equal(b.ns.Core.db.sniper, true)
  b:setCombat(false)
  assert(b.ns.CharacterSettings.Copy(item.source, "battlegrounds"))
  equal(b.ns.Core.db.sniper, false)
  b:assertHealthy()
end)

test("a shared profile's export is released when its link expires", function()
  local sim = peer("retail", "Alice")
  local Share = sim.ns.Options.Profiles.Chat
  assert(Share.ToChat("battlegrounds"))
  local cache
  for i = 1, 50 do
    local name, value = debug.getupvalue(Share.ToChat, i)
    if name == "cache" then cache = value; break end
  end
  assert(next(cache), "the export is held for its link")
  sim:advance(1790)
  assert(next(cache), "until the link expires")
  sim:advance(15)
  equal(next(cache), nil, "then released without another share")
end)
