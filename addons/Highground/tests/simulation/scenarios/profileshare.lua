local test, new, check = ...
local function equal(a, b, why) return check(a, b, why or "values match") end
local function click(b) b.scripts.OnClick(b) end
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
local function offer(sender, receiver)
  assert(sender.ns.Options.Profiles.Chat.ToChat("My healer"))
  local rendered = sender.chatDraft
  for _, filter in ipairs(receiver.chatFilters.CHAT_MSG_PARTY) do
    local _, text = filter(nil, "CHAT_MSG_PARTY", rendered, "Alice-Realm")
    rendered = text or rendered
  end
  assert(rendered:find("[Profile: My healer]", 1, true), "chat shows a readable profile link")
  local link = assert(rendered:match("|H([^|]+)|h"))
  receiver.env.SetItemRef(link)
  return link
end
local function pair(client)
  local a, b = peer(client, "Alice"), peer(client, "Bob")
  a.ns.Core.db.sniper = false
  a.ns.Alerts.SetMode("quiet")
  a.ns.Options.Profiles.SaveProfile("My healer")
  return a, b
end
local function download(a, b)
  receive(a, packets(b)[1], "Bob-Realm")
  a:advance(70)
  for _, p in ipairs(packets(a)) do receive(b, p, "Alice-Realm") end
end

for _, client in ipairs({ "cata", "retail" }) do
test(client .. " profile links draft, transfer and review a frozen setup before saving or applying", function()
  local a, b = pair(client)
  local expected = a.ns.Options.Profiles.ExportString(a.ns.Core.db.profiles["My healer"], "My healer")
  offer(a, b)
  equal(#a.chat, 0, "does not send a chat message")
  equal(#packets(a), 0, "sharing a link does not broadcast settings")
  a.ns.Core.db.sniper = true
  a.ns.Options.Profiles.SaveProfile("My healer")
  download(a, b)
  local w = b.ns.Options.Profiles.Chat.win
  equal(w.text, expected, "renaming or updating the saved profile cannot change the shared snapshot")
  equal(b.ns.Core.db.sniper, true, "receiving never applies settings")
  assert(w:IsVisible() and w.save:IsEnabled() and w.apply:IsEnabled())
  click(w.save)
  equal(b.ns.Core.db.profiles["My healer"].setup.features.sniper, false)
  equal(b.ns.Core.db.sniper, true, "save a copy preserves the active setup")
  click(w.apply)
  equal(b.ns.Core.db.sniper, false)
  equal(b.ns.Alerts.Settings().mode, "quiet")
  equal(w.apply:IsEnabled(), false, "successful import cannot be applied twice accidentally")
  local data = packets(a)
  for i = 2, #data do assert(data[i].at - data[i - 1].at >= 0.39, "transfer is paced") end
  a:assertHealthy(); b:assertHealthy()
end)
end

for _, client in ipairs({ "cata", "retail" }) do
test(client .. " profiles with the kill-target card hidden can be shared and restored", function()
  local a, b = pair(client)
  local C, P = a.ns.Core, a.ns.Options.Profiles
  -- This is the value written by Appearance > Kill-target card.
  C.SetElement("hero", false)
  C.SetElement("rank", false)
  P.SaveProfile("My healer")
  local ok, problem = P.Chat.ToChat()
  assert(ok, "current setup can be shared: " .. tostring(problem))
  a.env.ChatFrame_OpenChat("")
  C.SetElement("hero", true)
  offer(a, b) -- an existing named copy keeps its original visibility choice
  download(a, b)
  local w, receiver = b.ns.Options.Profiles.Chat.win, b.ns.Options.Profiles
  equal(b.ns.Core.ShowsElement("hero"), true, "review does not apply settings")
  click(w.save)
  equal(b.ns.Core.db.profiles["My healer"].setup.style.hide.hero, true, "saved copy keeps the hidden card")
  click(w.apply)
  equal(b.ns.Core.ShowsElement("hero"), false, "chat import restores the hidden card")
  equal(b.ns.Core.ShowsElement("rank"), false, "other hidden elements survive too")
  b.ns.Core.SetElement("hero", true)
  assert(receiver.LoadProfile("My healer"))
  equal(b.ns.Core.ShowsElement("hero"), false, "named profiles also load")
  b.ns.Core.SetElement("hero", true)
  assert(receiver.ImportText(receiver.ExportString(b.ns.Core.db.profiles["My healer"])))
  equal(b.ns.Core.ShowsElement("hero"), false, "clipboard imports use the same validation")
  a:assertHealthy(); b:assertHealthy()
end)
end

test("visibility validation still rejects unknown elements and non-boolean values", function()
  local sim = peer("cata", "Alice")
  local P, C = sim.ns.Options.Profiles, sim.ns.Core
  local before = P.ExportString(P.Snapshot())
  for _, entry in ipairs({ { "hero", "false" }, { "rank", 1 }, { "unknownElement", true } }) do
    local snap = P.Snapshot()
    snap.setup.style.hide[entry[1]] = entry[2]
    equal(P.ImportText(P.ExportString(snap)), false, "invalid visibility is rejected")
    equal(P.ExportString(P.Snapshot()), before, "rejected imports do not change active settings")
  end
  equal(C.ShowsElement("hero"), true)
  sim:assertHealthy()
end)

test("chat sharing preserves a draft and rejects overflow or missing profiles", function()
  local sim = peer("retail", "Alice")
  sim.env.ChatFrame_OpenChat("Try this")
  sim:command("profile share")
  assert(sim.chatDraft:find("Try this [HGP:", 1, true))
  equal(#sim.chat, 0)
  sim.env.ChatFrame_OpenChat(string.rep("a", 250))
  local ok = sim.ns.Options.Profiles.Chat.ToChat()
  equal(ok, false); equal(sim.chatDraft, string.rep("a", 250), "does not replace the draft")
  equal(sim.ns.Options.Profiles.Chat.ToChat("Missing"), false)
end)

test("own links open locally and imported copies do not overwrite an existing profile", function()
  local sim = peer("cata", "Alice")
  sim.ns.Options.Profiles.SaveProfile("My healer")
  local link = offer(sim, sim)
  local w = sim.ns.Options.Profiles.Chat.win
  equal(#packets(sim), 0, "own links need no network request")
  equal(w.name:GetText(), "My healer (2)")
  w.name:SetText("My healer"); click(w.save)
  assert(w.status.text:find("already saved", 1, true))
  click(w.cancel)
  sim:advance(1801)
  sim.env.SetItemRef(link)
  assert(w.status.text:find("expired", 1, true)); assert(not w.apply:IsEnabled())
end)

test("damaged saved profiles and unavailable chat transport fail without opening a draft", function()
  local sim = peer("retail", "Alice")
  local P = sim.ns.Options.Profiles
  P.SaveProfile("||||")
  equal(P.Chat.ToChat("||||"), false)
  sim.ns.Core.db.profiles.Old = { points = {}, weights = {}, specs = {}, options = {} }
  equal(P.Chat.ToChat("Old"), false, "an old snapshot with no export metadata gives an actionable error")
  sim.env.C_ChatInfo.SendAddonMessage = nil
  equal(P.Chat.ToChat(), false)
  assert(not sim.chatDraft, "failed shares never replace chat")
  sim:assertHealthy()
end)

test("wrong senders, other channels and unsolicited profile data are ignored", function()
  local a, b = pair("cata")
  offer(a, b)
  receive(a, packets(b)[1], "Bob-Realm"); a:advance(70)
  local data, w = packets(a), b.ns.Options.Profiles.Chat.win
  for _, p in ipairs(data) do b:event("CHAT_MSG_ADDON", p.prefix, p.message, "WHISPER", "Stranger-Realm") end
  for _, p in ipairs(data) do b:event("CHAT_MSG_ADDON", p.prefix, p.message, "PARTY", "Alice-Realm") end
  assert(not w.text and not w.apply:IsEnabled())
  click(w.cancel)
  for _, p in ipairs(data) do receive(b, p, "Alice-Realm") end
  assert(not w:IsShown() and not w.text, "a cancelled request stays cancelled")
  equal(b.ns.Core.db.sniper, true)
end)

test("out-of-order and duplicate chunks complete exactly once", function()
  local a, b = pair("retail")
  offer(a, b)
  receive(a, packets(b)[1], "Bob-Realm"); a:advance(70)
  local data = packets(a)
  for i = #data, 1, -1 do receive(b, data[i], "Alice-Realm"); receive(b, data[i], "Alice-Realm") end
  local w = b.ns.Options.Profiles.Chat.win
  assert(w.text and w.apply:IsEnabled())
  w.name:SetText("My copy")
  for _, p in ipairs(data) do receive(b, p, "Alice-Realm") end
  equal(w.name:GetText(), "My copy", "late chunks do not reopen or reset the review")
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
    local w = b.ns.Options.Profiles.Chat.win
    assert(not w.text and not w.save:IsEnabled() and not w.apply:IsEnabled(), kind)
    equal(b.ns.Core.db.sniper, true)
    b:assertHealthy()
  end
end)

test("offline, expired and busy links explain how to try again", function()
  local a, b = pair("retail")
  local link = offer(a, b)
  b:advance(91)
  assert(b.ns.Options.Profiles.Chat.win.status.text:find("must be online", 1, true))
  b.env.SetItemRef(link)
  receive(a, packets(b)[2], "Bob-Realm")
  a:advance(1.1)
  local c = peer("retail", "Carol")
  c.env.SetItemRef(link); receive(a, packets(c)[1], "Carol-Realm")
  local data = packets(a)
  receive(c, data[#data], "Alice-Realm")
  assert(c.ns.Options.Profiles.Chat.win.status.text:find("another profile", 1, true))
  a:advance(1801)
  b.env.SetItemRef(link); receive(a, packets(b)[3], "Bob-Realm")
  data = packets(a); receive(b, data[#data], "Alice-Realm")
  assert(b.ns.Options.Profiles.Chat.win.status.text:find("expired", 1, true))
end)

test("malformed chat tokens stay plain text and other addon links remain untouched", function()
  local sim = peer("cata", "Alice")
  for _, text in ipairs({ "[HGP:2:bad:bad:bad]", "[HGP:1:QQ==:1-2:QQ==]", "[HGP:" .. string.rep("a", 256) .. "]" }) do
    local _, result = sim.ns.Options.Profiles.Chat.Filter(nil, nil, text)
    equal(result, text)
  end
  sim.env.SetItemRef("addon:AnotherAddon:abc")
  assert(not sim.ns.Options.Profiles.Chat.win)
end)

test("chat imports still defer applying a full setup until combat ends", function()
  local a, b = pair("cata")
  offer(a, b); download(a, b)
  b:setCombat(true); click(b.ns.Options.Profiles.Chat.win.apply)
  equal(b.ns.Core.db.sniper, true)
  assert(b.ns.Options.Profiles.pending)
  b:setCombat(false)
  equal(b.ns.Core.db.sniper, false)
  b:assertHealthy()
end)
