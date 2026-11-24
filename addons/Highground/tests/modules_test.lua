local t = dofile("../../tools/harness.lua")("modules")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local F = dofile("tests/modules/fixture.lua")
local function click(button) button.scripts.OnClick(button) end

for _, client in ipairs({ "cata", "retail" }) do
  for _, legacy in ipairs({ false, true }) do
    t.test(client .. (legacy and " legacy" or " native") .. " switches preserve settings and apply on reload", function()
      local s = new(client, { bounty = false, highestRank = true }, F.configure(nil, legacy))
      local M = s.ns.Modules
      assert(M.SetEnabled("bounties", false))
      assert(M.Active("bounties") and M.Pending("bounties"), "running state stays stable until reload")
      t.equal(s.ns.Core.db.bounty, false, "panel preference is preserved")
      t.equal(#s.moduleWrites, 1, "one native change")
      t.equal(s.moduleWrites[1].name, "HighgroundModuleBounties", "exact module")
      assert(M.SetEnabled("bounties", true))
      assert(not M.Pending(), "reverting cancels pending reload")
      s:setCombat(true)
      assert(not M.SetEnabled("arena", false), "combat prevents native mutations")
      assert(not M.Reload(), "combat prevents reload")
      t.equal(#s.moduleWrites, 2, "combat did not change anything")
      s:setCombat(false)
      assert(M.SetEnabled("arena", false)); assert(M.Reload())
      t.equal(s.reloads, 1, "reload is explicit")
      local after = new(client, s.ns.Core.db, F.configure({ arena = true }, legacy))
      assert(not after.ns.Modules.Active("arena") and not after.ns.Modules.Pending())
      assert(not after.ns.Core.On("arena"))
      t.equal(after.ns.Core.db.bounty, false, "unrelated settings survive reload")
    end)
  end

  t.test(client .. " disabled modules run no feature callbacks or network initialization", function()
    local off = {}; for _, name in ipairs(F.names) do off[name:lower()] = true end
    local s = new(client, { capProbeOn = true }, F.configure(off))
    s:enemy("Enemy"); s:join(); s:advance(60)
    s:event("SPELLS_CHANGED"); s:event("PLAYER_TARGET_CHANGED"); s:event("UPDATE_MOUSEOVER_UNIT")
    s:event("PLAYER_GUILD_UPDATE", "player")
    assert(not s.ns.Core.active, "disabled battlegrounds never starts the match ticker")
    assert(not s.ns.Bounty.Public.ready, "disabled bounties never initializes networking or shared data")
    assert(not s.ns.Reputation.ready, "disabled reputation never initializes networking or filters")
    for stage in pairs(s.moduleWork) do
      local name = stage:lower()
      assert(not (name:find("bounty") or name:find("bounties") or name:find("reputation")
        or name:find("nearby") or name:find("arena") or name:find("macro")
        or name == "timers" or name == "intel events" or name == "pressure" or name == "capprobe"),
        "disabled callback ran: " .. stage)
    end
    for _, cmd in ipairs({ "bounty", "macros", "reputation", "nearby test", "arena test", "bg test" }) do
      s:command(cmd)
      assert(s.ns.Hub.current:match("^module%-"), "disabled command opens its module controls")
    end
    s.env.Highground_BountyBoard()
    assert(not s.ns.Bounty.Board.win, "key binding cannot build a disabled board")
    s:assertHealthy()
  end)

  t.test(client .. " feature sections are peers and addon controls refresh without polling", function()
    local s = new(client, nil, F.configure())
    s.ns.Hub.Open("addons")
    local page = s.ns.Hub.activeFrame
    for _, def in ipairs(s.ns.Modules.list) do assert(page.cards[def.key].addon, "every module has a switch") end
    for i, name in ipairs(F.names) do
      t.equal(s.ns.Hub.win.navGroups[i].groupTitle, name, "same navigation level")
    end
    local count = #s.frames
    for _ = 1, 5 do s.ns.Hub.Open("addons") end
    t.equal(#s.frames, count, "reopening reuses controls")
    click(page.cards.bounties.addon); assert(page.reload:IsShown())
    assert(page.cards.bounties.addonStatus:GetText():find("disables after reload", 1, true))
    click(page.cards.bounties.addon); assert(not page.reload:IsShown(), "revert removes reload prompt")
    s.moduleStates.HighgroundModuleMacros = false -- changed in Blizzard's list
    s.ns.Hub.win:Hide(); s.ns.Hub.Open("addons")
    assert(not page.cards.macros.addon:GetChecked() and page.reload:IsShown(), "native changes appear on reopen")
    s:setCombat(true); s.ns.Hub.Open("addons")
    assert(not page.cards.battlegrounds.addon:IsEnabled() and not page.reload:IsEnabled())
    s:setCombat(false); assert(page.cards.battlegrounds.addon:IsEnabled() and page.reload:IsEnabled())
    for _, scale in ipairs({ 1, 1.25, 1.5 }) do
      s.ns.Core.SetFontScale(scale)
      for _, def in ipairs(s.ns.Modules.list) do
        local card = page.cards[def.key]
        local toggle, status = s.bounds(card.addon), s.bounds(card.addonStatus)
        assert(toggle[2] + toggle[4] <= status[2], "switch and status never overlap at enlarged text sizes")
      end
    end
    s:assertHealthy()
  end)

  t.test(client .. " addon guide explains real controls without changing or reloading them", function()
    local s = new(client, nil, F.configure())
    local O = s.ns.Onboarding
    s.ns.Hub.Open("addons"); click(s.ns.Hub.activeFrame.guide)
    for _ = 1, 2 do
      t.equal(O.Coach.key, "addons", "module walkthrough starts from its page")
      for i = 1, #O.Coach.steps do
        O.Coach.Go(i)
        assert(O.Coach.target and O.Coach.target:IsVisible(), "real control is highlighted")
      end
      O.Return()
      t.equal(#s.moduleWrites, 0, "guide never changes native enable states")
      t.equal(s.reloads, nil, "guide never reloads automatically")
      O.Start("addons")
    end
    s:setCombat(true)
    assert(not O.Coach.running, "combat closes the walkthrough")
    s:setCombat(false); s:assertHealthy()
  end)

  t.test(client .. " installation advice detects only standalone copies and keeps module controls independent", function()
    local copies = { HighgroundArena = true, HighgroundMacros = false,
      HighgroundBountyData = true, HighgroundReputationData = true, HighgroundModuleNearby = true }
    local s = new(client, nil, F.configure(nil, true, nil, copies))
    local M = s.ns.Modules
    t.equal(#M.StandaloneAddons(), 2, "enabled and disabled standalone copies are both unnecessary")
    t.equal(M.StandaloneAddons()[1].standalone, "HighgroundArena", "exact standalone folder")
    t.equal(M.StandaloneAddons()[2].standalone, "HighgroundMacros", "never include module or data folders")
    s.ns.Hub.Open("addons")
    local page, reads, frames = s.ns.Hub.activeFrame, s.standaloneReads, #s.frames
    assert(page.notice and page.notice:IsVisible(), "show removal advice")
    for _ = 1, 5 do s.ns.Hub.Open("addons"); s.ns.Hub.RefreshHome() end
    t.equal(s.standaloneReads, reads, "installed copies are checked once, not on every refresh")
    t.equal(#s.frames, frames, "notice controls are reused")
    for _, scale in ipairs({ 1, 1.5 }) do
      s.ns.Core.SetFontScale(scale)
      local notice, row = s.bounds(page.notice), s.bounds(page.cards.battlegrounds.addon)
      assert(notice[2] + notice[4] <= row[2], "removal advice never overlaps switches")
    end
    click(page.cards.battlegrounds.addon)
    assert(M.Pending("battlegrounds"), "module switch still works below the notice")
    t.equal(#s.moduleWrites, 1, "advice never changes standalone or data enable states")
    s:assertHealthy()
  end)

  t.test(client .. " duplicate-installation guide shows removal advice and scrolls to the real switches", function()
    local copies = {}; for _, name in ipairs(F.names) do copies["Highground" .. name] = true end
    local s = new(client, nil, function(s, e)
      F.configure(nil, false, nil, copies)(s, e)
      e.C_AddOns.DoesAddOnExist = function(name)
        return s.moduleStates[name] ~= nil or copies[name] ~= nil
      end
    end)
    t.equal(#s.ns.Modules.StandaloneAddons(), 6, "modern existence API finds all six copies")
    s.ns.Core.SetFontScale(1.5)
    local O = s.ns.Onboarding
    for _ = 1, 2 do
      O.Start("addons")
      local page = O.Build()
      O.Coach.Go(1); t.equal(page.scroll.offset, 0, "show installation advice from its top")
      local target, tip = s.bounds(O.Coach.target), s.bounds(O.Coach.win)
      assert(target[1] + target[3] <= tip[1] or tip[1] + tip[3] <= target[1]
        or target[2] + target[4] <= tip[2] or tip[2] + tip[4] <= target[2], "guide never covers the highlighted installation heading")
      O.Coach.Go(2); assert(page.scroll.offset > 0, "scroll past removal instructions to reach switches")
      local row, viewport = s.bounds(page.cards.battlegrounds.addon), s.bounds(page.scroll)
      assert(row[2] >= viewport[2] and row[2] + row[4] <= viewport[2] + viewport[4], "highlighted switch is inside the viewport")
      O.Return()
    end
    t.equal(#s.moduleWrites, 0, "guide does not disable or remove anything")
    t.equal(s.reloads, nil, "guide does not reload automatically")
    s:assertHealthy()
  end)

  t.test(client .. " disabled guide chapters and previews lead to addon controls", function()
    local off = {}; for _, name in ipairs(F.names) do off[name:lower()] = true end
    local s = new(client, nil, F.configure(off))
    for _, key in ipairs({ "enemies", "battlegrounds", "arena", "macros", "bounties", "bounty_post", "nearby", "reputation", "map", "callouts" }) do
      s.ns.Onboarding.Start(key)
      assert(s.ns.Hub.current:match("^module%-"), "disabled chapter routes to its module")
      assert(not s.ns.Onboarding.Coach.running and not s.ns.Core.testMode and not s.ns.Setup.placement)
    end
    for _, command in ipairs({ "intel test", "sniper test", "go", "burst test", "pressure test", "bounty test" }) do
      s:command(command)
      assert(not s.ns.Core.testMode and not s.ns.Bounty.Preview.testing, "disabled command starts no preview")
    end
    assert(not s.ns.BattlegroundsPreview.Start(true), "direct placement preview also respects the switch")
    t.equal(#s.moduleWrites, 0, "guides and previews cannot implicitly enable a module")
    s:assertHealthy()
  end)

  t.test(client .. " Nearby guide works with Bounties disabled", function()
    local s = new(client, nil, F.configure({ bounties = true }))
    local O = s.ns.Onboarding
    O.Start("nearby")
    for i, step in ipairs(O.Coach.steps) do
      assert(not step.id:match("^bounty"), "unavailable bounty steps are left out")
      O.Coach.Go(i)
      assert(O.Coach.target and O.Coach.target:IsVisible())
    end
    local success = O.Coach.nearbySample.bounty(O.Coach.nearbySample.entries()[1])
    assert(success == false and not s.ns.Bounty.Form.previewWin, "sample journal explains the unavailable addon")
    O.Return(); assert(not s.ns.Nearby.preview and not s.ns.Setup.placement)
    s:assertHealthy()
  end)
end

t.test("all module combinations boot and preserve independent features on Forever", function()
  for mask = 0, 63 do
    local off = {}
    for i, name in ipairs(F.names) do off[name:lower()] = math.floor(mask / 2 ^ (i - 1)) % 2 == 1 end
    local s = new("retail", nil, function(s, e)
      e.GetBuildInfo = function() return "1.60.1", "", "", 16001 end
      F.configure(off)(s, e)
    end)
    for _, name in ipairs(F.names) do
      t.equal(s.ns.Modules.Active(name:lower()), name ~= "Arena" and not off[name:lower()], name)
    end
    t.equal(s.ns.Modules.byKey.arena, nil, "no arenas, no Arena module")
    t.equal(s.ns.Bounty.Public.ready == true, not off.bounties, "bounty service independence")
    t.equal(s.ns.Reputation.ready == true, not off.reputation, "reputation service independence")
    s:enemy("Enemy"); s:join()
    t.equal(s.ns.Core.active, not off.battlegrounds, "battleground independence")
    s:leave(); s:advance(5)
    for _, def in ipairs(s.ns.Modules.list) do s.ns.Hub.Open("module-" .. def.key) end
    s:assertHealthy()
  end
end)

t.test("partial bundles report missing modules without enabling them or changing other addons", function()
  local s = new("retail", nil, F.configure(nil, false, { HighgroundModuleBounties = true }))
  assert(not s.ns.Modules.Active("bounties"))
  assert(not s.ns.Modules.SetEnabled("bounties", true))
  t.equal(#s.moduleWrites, 0, "missing modules never change native state")
  s.ns.Hub.Open("module-bounties")
  assert(not s.ns.Hub.activeFrame.rows[1]:IsEnabled())
  assert(not s.ns.Hub.activeFrame.actions[1]:IsEnabled())
end)

t.finish()
