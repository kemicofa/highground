local test, newClient, equal = ...
-- Exercise the existing full-feature setup; fresh installs are covered by onboarding.
local function new(client, saved, configure) return newClient(client, saved or {}, configure) end
assert(loadfile("../HighgroundBounties/tests/sharing.lua"))(test, new, equal)

test("clicking a bounty link opens a board borrowed by the Highground hub", function()
  local sim = new("retail")
  sim.ns.Hub.Open("bountyboard")
  sim.env.SetItemRef("addon:HighgroundB:1:Rival-Realm:500:Me-Realm:")
  local Bounty = sim.ns.Bounty
  assert(not sim.ns.Hub.win:IsShown(), "hub releases the board")
  assert(Bounty.Board.win:IsShown() and Bounty.Board.win:GetParent() == sim.env.UIParent, "board visible on its own")
  assert(Bounty.Share.win:IsShown(), "import preview visible")
  sim:assertHealthy()
end)

test("Highground and standalone Bounties exchange chat links in both directions", function()
  local full = new("retail")
  local standalone = new("retail", nil, function(sim)
    sim.addon = "HighgroundBounties"
    sim.manifest = "../HighgroundBounties/HighgroundBounties.toc"
    local load = sim.load
    function sim:load(path)
      if path:sub(1, 3) ~= "../" then path = "../HighgroundBounties/" .. path end
      return load(self, path)
    end
  end)
  local function transfer(sender, recipient)
    local text = sender.chatDraft
    for _, filter in ipairs(recipient.chatFilters.CHAT_MSG_WHISPER) do
      local hide, rendered = filter(nil, "CHAT_MSG_WHISPER", text, "Me-Realm")
      assert(not hide, "other chat features preserve bounty messages")
      text = rendered or text
    end
    recipient.env.SetItemRef(assert(text:match("|H([^|]+)|h")))
    local w = recipient.ns.Bounty.Share.win
    assert(w and w:IsShown(), "other addon's link opens the preview")
    w.import.scripts.OnClick(w.import)
    recipient:assertHealthy()
  end
  full:command("bounty add 9999999 Rival; " .. string.rep("n", 60))
  full:command("bounty share Rival")
  full:advance(0.05)
  transfer(full, standalone)
  equal(standalone.ns.Bounty.Entry("Rival").gold, 9999999, "standalone imports the maximum gold reward")
  equal(#standalone.ns.Bounty.Entry("Rival").note, 60, "full-length note preserved")
  standalone:slash("HIGHGROUNDBOUNTIES", "add Friendly")
  standalone:slash("HIGHGROUNDBOUNTIES", "share Friendly")
  standalone:advance(0.05)
  transfer(standalone, full)
  equal(full.ns.Bounty.Entry("Friendly").gold, 0, "Highground imports a bounty without gold")
  equal(full.ns.Bounty.Entry("Friendly").note, nil, "empty note round trip")
end)
