local test, newClient, equal = ...
-- Exercise the existing full-feature setup; fresh installs are covered by onboarding.
local function new(client, saved, configure) return newClient(client, saved or {}, configure) end
assert(loadfile("tests/bounties/sharing.lua"))(test, new, equal)

test("clicking a bounty link returns to the separate board after import", function()
  local sim = new("retail")
  sim.ns.Hub.Open("bounty"); sim.ns.Options.byKey.bounty.openTool:Click()
  sim.env.SetItemRef("addon:HighgroundB:1:Rival-Realm:500:Me-Realm:")
  local Bounty = sim.ns.Bounty
  assert(not sim.ns.Hub.win:IsShown(), "configuration stays hidden")
  assert(not Bounty.Board.win:IsShown() and Bounty.Board.win:GetParent() == sim.env.UIParent, "board waits behind import without drawing")
  assert(Bounty.Share.win:IsShown(), "import preview visible")
  Bounty.Share.win:Hide()
  assert(Bounty.Board.win:IsShown(), "closing import restores the board")
  sim:assertHealthy()
end)

test("Highground players exchange chat links in both directions", function()
  local full = new("retail")
  local peer = new("retail")
  local function transfer(sender, recipient)
    local text = sender.chatDraft
    for _, filter in ipairs(recipient.chatFilters.CHAT_MSG_WHISPER) do
      local hide, rendered = filter(nil, "CHAT_MSG_WHISPER", text, "Me-Realm")
      assert(not hide, "other chat features preserve bounty messages")
      text = rendered or text
    end
    recipient.env.SetItemRef(assert(text:match("|H([^|]+)|h")))
    local w = recipient.ns.Bounty.Share.win
    assert(w and w:IsShown(), "other player's link opens the preview")
    w.import.scripts.OnClick(w.import)
    recipient:assertHealthy()
  end
  full:command("bounty add 9999999 Rival; " .. string.rep("n", 60))
  full:command("bounty share Rival")
  full:advance(0.05)
  transfer(full, peer)
  equal(peer.ns.Bounty.Entry("Rival").gold, 9999999, "peer imports the maximum gold reward")
  equal(#peer.ns.Bounty.Entry("Rival").note, 60, "full-length note preserved")
  peer:slash("HIGHGROUND", "bounty add Friendly")
  peer:slash("HIGHGROUND", "bounty share Friendly")
  peer:advance(0.05)
  transfer(peer, full)
  equal(full.ns.Bounty.Entry("Friendly").gold, 0, "Highground imports a bounty without gold")
  equal(full.ns.Bounty.Entry("Friendly").note, nil, "empty note round trip")
end)
