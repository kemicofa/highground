local t = dofile("../../tools/harness.lua")("reputation integration")
local F = dofile("tests/fixture.lua")
local bg = dofile("../../tools/wowsim/battleground/runtime.lua")
local test, equal = t.test, t.equal

for _, case in ipairs({ { "retail", 120100, "Owner" }, { "retail", 16001, "Owner Bright" }, { "cata", 40402, "Owner" } }) do
  test(case[1] .. " " .. case[2] .. " main addon embeds the same feature and storage", function()
    local standalone = F.new(case[3], { client = case[1], build = case[2], guild = case[1] == "cata" and "Test Guild" or nil })
    local w = F.W(standalone)
    local c = F.community(standalone)
    local name = case[2] == 16001 and "Enemy Bright" or "Enemy-Realm"
    w.Decide(c, F.target(standalone, name), "ban", { scamming = true }, "Shared decision")
    local main = F.new(case[3], { client = case[1], build = case[2], guild = case[1] == "cata" and "Test Guild" or nil, addon = "Highground", runtime = bg, database = w.Copy(w.db) })
    local embedded = F.W(main)
    equal(embedded.db.id, w.db.id, "same account identity")
    assert(embedded.Match(F.target(main, name)), "blacklist persists when switching packages")
    main:command("reputation")
    equal(main.ns.Hub.current, "reputation", "Reputation has a main hub section")
    equal(embedded.UI.window:GetParent(), main.ns.Hub.content, "workspace embedded in hub")
    main:command("reputation status")
    assert(main.messages[#main.messages]:find("shared", 1, true), "embedded commands dispatched")
    main:assertHealthy()
    local back = F.new(case[3], { client = case[1], build = case[2], guild = case[1] == "cata" and "Test Guild" or nil, database = embedded.Copy(embedded.db) })
    assert(F.W(back).Match(F.target(back, name)), "switching back retains entries")
  end)
end

test("workspace adapts its row count when borrowed by the smaller hub", function()
  local main = F.new("Owner", { addon = "Highground", runtime = bg, configure = function(s) dofile("../../tools/wowsim/geometry.lua")(s) end })
  local w = F.W(main)
  local c = F.community(main)
  for i = 1, 20 do w.Decide(c, F.target(main, "Enemy" .. string.char(64 + i) .. "-Realm"), "ban", { toxic = true }, "") end
  main:command("reputation")
  w.UI.Refresh()
  local f = w.UI.window
  local row = f.rows[w.UI.pageSize]
  local _, ry, _, rh = unpack(main.bounds(row))
  local _, fy, _, fh = unpack(main.bounds(f))
  assert(ry + rh < fy + fh - 44, "last row stays above footer")
  assert(w.UI.pageSize < 7, "embedded height reduces visible rows")
end)

for _, addon in ipairs({ "Highground", "HighgroundReputation" }) do
  test(addon .. ": reply settings save custom text and frequency and reset the message", function()
    local opts = { addon = addon, build = 16001, runtime = addon == "Highground" and bg or nil }
    local s = F.new("Owner Bright", opts)
    local W, c = F.W(s), F.community(s)
    if s.ns.Hub then s.ns.Hub.Open("reputation") else W.Open() end
    W.UI.SetMode("settings")
    local f = W.UI.window
    equal(f.replyInterval:GetValue(), 0, "every whisper selected on fresh installs")
    equal(f.replyText:GetText(), W.DEFAULT_REPLY, "default message is editable")
    f.replyText:SetText("Blocked by {organization} for {categories}.")
    f.replyInterval:SetValue(60)
    s:event("CLUB_MEMBER_PRESENCE_UPDATED", 42, 2)
    equal(f.replyText:GetText(), "Blocked by {organization} for {categories}.", "background updates preserve edits")
    assert(W.Decide(c, F.target(s, "Enemy Bright-Realm"), "ban", { scamming = true }, ""))
    s:event("CHAT_MSG_WHISPER", unpack(F.chat("Enemy Bright-Realm")))
    equal(s.chat[1].message, "[Highground Reputation] Blocked by Test community for Scamming.", "saved message is used")
    opts.database = W.Copy(W.db)
    local again = F.new("Owner Bright", opts)
    equal(F.W(again).ReplyInterval(), 60, "frequency persists through reload")
    equal(F.W(again).db.settings.replyText, W.db.settings.replyText, "message persists through reload")
    F.click(s, f.resetReply)
    equal(f.replyText:GetText(), W.DEFAULT_REPLY, "reset restores the default message")
    equal(W.db.settings.replyText, nil, "reset clears the override")
    f.replyInterval:SetValue(0)
    s:event("CHAT_MSG_WHISPER", unpack(F.chat("Enemy Bright-Realm")))
    equal(#s.chat, 2, "every whisper immediately overrides the previous cooldown")
    f.toggles.reply:SetChecked(false)
    s:event("CHAT_MSG_WHISPER", unpack(F.chat("Enemy Bright-Realm")))
    equal(#s.chat, 2, "reply switch disables automatic messages")
    s:assertHealthy(); again:assertHealthy()
  end)
end

t.finish("Reputation integration: " .. t.tests .. " scenarios")
