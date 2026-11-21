local test, new, equal = ...
local function Click(button) assert(button.scripts.OnClick)(button) end
local function Same(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end
  for k, v in pairs(a) do if not Same(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end

for _, case in ipairs({ { "cata", 40402 }, { "retail", 120100 }, { "retail", 16001 } }) do
  test(case[2] .. " bounty scenes show real presentations without publishing or changing bounties", function()
    local s = new(case[1], { bountyTellGroup = true }, function(sim)
      sim.env.GetBuildInfo = function() return "test", "1", "", case[2] end
    end)
    local B, P = s.ns.Bounty, s.ns.Bounty.Public
    local real = assert(B.Add("RealEnemy", 50, "Keep me"))
    B.Ledger.Record(real, B.Me())
    B.Board.Open(); B.Board.win.search:SetText("RealEnemy")
    s.ns.Comms.GroupChannel = function() return "PARTY" end
    local personal, guild, network, claims = P.Copy(B.Personal()), P.Copy(B.Guild()), P.Copy(P.db), P.Copy(B.Ledger.All())
    local sightings, encounters = P.Copy(s.ns.Nearby.seen), P.Copy(s.ns.NearbyHistory.All())
    local sent, chat, marks = #s.sent, #s.chat, #B.plateMarks
    s:command("bounty test")
    local demo, w = B.Preview, B.Preview.win
    assert(w:IsShown() and demo.scene.key == "nearby", "command opens nearby scene immediately")
    local poster = assert(B.Poster.previewWin)
    assert(poster:IsShown() and poster.status:GetText():find("PREVIEW", 1, true), "real wanted poster renderer")
    equal(poster.reward:GetText(), "500g", "sample reward on poster")
    assert(poster.portrait:IsShown() and not poster.fallback:IsShown(), "preview demonstrates an actual character portrait")
    equal(poster.portrait.texture, "portrait:Me-Realm", "unselected preview uses your character")
    equal(poster.likeness:GetText(), "YOUR CHARACTER · SAMPLE", "sample portrait clearly labelled")
    assert(w.examples.row.wbBounty:IsShown() and w.examples.marker:IsShown(), "real row mark and nameplate coin")
    equal(#B.plateMarks, marks, "no fake live nameplate")
    Click(w.details)
    assert(B.Details.preview and not w:IsShown(), "sample overview replaces the preview")
    assert(not poster:IsShown(), "sample poster does not cover the overview")
    for _, button in ipairs(B.Details.win.actions) do assert(not button:IsShown(), "sample cannot expose real mutations") end
    Click(B.Details.win.back)
    assert(w:IsShown() and not B.Details.win:IsShown(), "back returns directly")
    Click(w.scenes.guild)
    assert(s.messages[#s.messages]:find("[PREVIEW] guild bounty:", 1, true), "guild arrival uses real text")
    equal(w.row.approval.label:GetText(), "GUILD APPROVED", "guild approval badge shown")
    s:command("bounty test world")
    equal(demo.scene.key, "shared", "world alias")
    equal(w.row.gold:GetText(), "750g", "stacked contribution total")
    assert(s.messages[#s.messages]:find("Shared bounty:", 1, true), "shared arrival notification")
    Click(w.details)
    assert(B.Details.win.cards[2]:IsShown(), "sample overview shows each contribution")
    Click(B.Details.win.back)
    Click(w.scenes.kill)
    assert(s.messages[#s.messages]:find("Saved 2 reward report(s)", 1, true), "kill explains the saved report and review")
    Click(w.claims)
    local ledger = demo.claimsWin
    assert(ledger:IsShown() and not w:IsShown(), "sample claims replace preview")
    equal(#ledger.items, 6, "separate contributor reports plus review and payment examples")
    assert(not ledger.actions[1]:IsEnabled(), "hunter cannot approve their own reported kill")
    assert(ledger.detail:GetText():find("awaits the poster's review", 1, true), "hunter status explained")
    Click(ledger.rows[2])
    assert(not ledger.actions[1]:IsEnabled(), "second contributor also reviews their own reward")
    Click(ledger.rows[3]); Click(ledger.actions[1])
    equal(demo.claims[3].state, "approved", "sample approval works")
    Click(ledger.actions[2])
    equal(demo.claims[3].state, "paid", "sample payment recording works")
    assert(ledger.detail:GetText():find("Marked paid:", 1, true), "real claim detail formatter")
    Click(ledger.back); s:command("bounty test stop")
    assert(not w:IsShown() and not ledger:IsShown(), "stop closes sample windows")
    assert(not poster:IsShown(), "stop closes sample poster")
    equal(B.Details.preview, nil, "sample overview released")
    assert(Same(B.Personal(), personal) and Same(B.Guild(), guild), "real bounty lists unchanged")
    assert(Same(P.db, network) and Same(B.Ledger.All(), claims), "real offers, claims and contributor IDs unchanged")
    assert(Same(s.ns.Nearby.seen, sightings) and Same(s.ns.NearbyHistory.All(), encounters), "no fabricated sightings or history")
    equal(B.Board.win.search:GetText(), "RealEnemy", "real board search kept")
    equal(#s.sent, sent, "no addon packets sent")
    equal(#s.chat, chat, "no group or guild chat sent, even with sharing enabled")
    equal(P.Publishing(), false, "publishing preference unchanged")
    equal(P.Receiving(), false, "receiving preference unchanged")
    B.Announce(real, "Tarren Mill")
    equal(#s.chat, chat + 1, "normal group sighting sharing still works")
    s:assertHealthy()
  end)
end

test("bounty preview works in combat with live alerts off and respects sound settings", function()
  local s = new("cata", { bounty = false, sound = false, bountyAnnounce = false,
    alerts = { mode = "critical", channels = {} } })
  s:setCombat(true)
  s:command("bounty test nearby")
  assert(s.ns.Bounty.Preview.win:IsShown(), "preview uses no protected target buttons")
  assert(s.ns.Bounty.Poster.previewWin:IsShown(), "explicit visual preview is still visible")
  equal(#s.sounds, 0, "master mute respected")
  s.ns.Core.db.sound = true
  s:command("bounty test shared")
  equal(#s.sounds, 0, "critical-only sound filter respected")
  s:command("bounty test stop")
  equal(s.ns.Core.db.bounty, false, "live feature stays off")
  s:assertHealthy()
end)

test("bounty preview controls fit enlarged text and stay above the board", function()
  local s = new("cata", nil, function(sim) dofile("../../tools/wowsim/geometry.lua")(sim) end)
  s.ns.Hub.Open("bountyboard")
  for _, scale in ipairs({ 1, 1.5 }) do
    s.ns.Core.SetFontScale(scale)
    for _, scene in ipairs({ "nearby", "guild", "shared", "kill" }) do
      s:command("bounty test " .. scene)
      local w = s.ns.Bounty.Preview.win
      equal(w:GetFrameStrata(), "FULLSCREEN_DIALOG", "preview above embedded board")
      equal(w:GetAlpha(), 1, "opaque during entrance")
      local root, scroll, footer = s.bounds(w), s.bounds(w.scroll), s.bounds(w.progress)
      assert(root[2] >= 0 and root[2] + root[4] <= s.env.UIParent:GetHeight(), "tour fits on screen")
      assert(scroll[2] + scroll[4] + 10 <= footer[2], "scroll clears footer")
      for _, button in pairs(w.scenes) do
        assert(button.label:GetStringWidth() + 20 <= button:GetWidth(), "scene label fits")
      end
      for _, button in ipairs({ w.prev, w.next, w.details, w.done }) do
        assert(button.label:GetStringWidth() + 20 <= button:GetWidth(), "action label fits")
      end
    end
  end
  s:command("bounty test stop")
  s:assertHealthy()
end)
