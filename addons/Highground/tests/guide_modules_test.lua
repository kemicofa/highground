local t = dofile("../../tools/harness.lua")("guide modules")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local F = dofile("tests/modules/fixture.lua")
local function click(button) button.scripts.OnClick(button) end
local function snapshot(s)
  local P = s.ns.Options.Profiles
  return P.ExportString(P.Snapshot())
end
local function inside(s, child, parent)
  local b, p = s.bounds(child), s.bounds(parent)
  assert(b[1] >= p[1] - 1 and b[2] >= p[2] - 1
    and b[1] + b[3] <= p[1] + p[3] + 1 and b[2] + b[4] <= p[2] + p[4] + 1, "control fits its container")
end

for _, client in ipairs({ "cata", "retail", "forever" }) do
  local function make(off, missing, saved)
    return new(client == "cata" and "cata" or "retail", saved, function(s, env)
      if client == "forever" then env.GetBuildInfo = function() return "1.60.1", "", "", 16001 end end
      F.configure(off, client == "cata", missing)(s, env)
    end)
  end

  t.test(client .. " every subaddon card changes the native module switch and preserves preferences", function()
    local s = make(nil, nil, { nearby = false, arena = true, bounty = false, highestRank = true })
    local O, M = s.ns.Onboarding, s.ns.Modules
    s:command("guide")
    local before = snapshot(s)
    for _, def in ipairs(M.list) do
      local card = O.win.cards[def.key]
      assert(card.addon:IsVisible() and card.addon:IsEnabled() and card.addon:GetChecked())
      click(card.addon)
      assert(not card.addon:GetChecked() and M.Active(def.key) and M.Pending(def.key))
      assert(card.addonStatus:GetText():find("disables after reload", 1, true))
      assert(O.win.reload:IsShown())
      t.equal(s.moduleWrites[#s.moduleWrites].name, def.addon, "only the selected addon is changed")
      t.equal(snapshot(s), before, "module changes preserve panel and profile preferences")
    end
    t.equal(#s.moduleWrites, 6, "one native write per addon")
    t.equal(s.reloads, nil, "changing switches never reloads automatically")
    s.ns.Hub.Open("addons")
    for _, row in ipairs(s.ns.Hub.activeFrame.rows) do assert(not row:GetChecked()) end
    click(s.ns.Hub.activeFrame.rows[1])
    s.ns.Hub.Open("checklist")
    assert(O.win.cards.battlegrounds.addon:GetChecked(), "guide reflects changes made on Addons")
    for _, def in ipairs(M.list) do
      if def.key ~= "battlegrounds" then click(O.win.cards[def.key].addon) end
    end
    assert(not M.Pending() and not O.win.reload:IsShown(), "reverting all switches cancels reload")
    click(O.win.cards.nearby.enable)
    assert(s.ns.Core.On("nearby") and not M.Pending(), "Show panel is independent of the addon switch")
    local count = #s.frames
    for _ = 1, 3 do O.Dismiss(); s:command("checklist") end
    t.equal(#s.frames, count, "reopening reuses guide controls")
    O.Dismiss()
    local reads = 0
    local api, method = s.env.C_AddOns, "GetAddOnEnableState"
    if client == "cata" then api = s.env end
    local get = api[method]
    api[method] = function(...) reads = reads + 1; return get(...) end
    s:advance(10)
    t.equal(reads, 0, "closed guide does not poll native addon state")
    s:assertHealthy()
  end)

  t.test(client .. " disabled addons can be selected from their cards but previews wait for reload", function()
    local off = {}; for _, name in ipairs(F.names) do off[name:lower()] = true end
    local s = make(off)
    local O, M = s.ns.Onboarding, s.ns.Modules
    for _, def in ipairs(M.list) do
      s:command("guide"); O.Go("enemies")
      local card = O.win.cards[def.key]
      assert(card.addon:IsEnabled() and not card.addon:GetChecked())
      click(card.addon)
      assert(card.addon:GetChecked() and not M.Active(def.key) and M.Pending(def.key))
      assert(card.addonStatus:GetText():find("enables after reload", 1, true))
      if card.enable then assert(not card.enable:IsEnabled(), "panel controls wait for the module") end
      click(card.start)
      t.equal(s.ns.Hub.current, "module-" .. def.key, "disabled guide still leads to addon settings")
      assert(not O.Coach.running and not s.ns.Core.testMode and not s.ns.Setup.placement)
    end
    s:command("bg test"); assert(not s.ns.Core.testMode)
    s:command("bounty test"); assert(not s.ns.Bounty.Preview.testing)
    s:command("guide"); O.Go("enemies")
    assert(O.win.reload:IsVisible())
    click(O.win.reload); t.equal(s.reloads, 1, "only the reload button reloads")
    local after = make(nil, nil, s.ns.Core.db)
    after:command("guide")
    assert(not after.ns.Onboarding.win.reload:IsShown())
    for _, def in ipairs(after.ns.Modules.list) do
      assert(after.ns.Modules.Active(def.key) and after.ns.Onboarding.win.cards[def.key].addon:GetChecked())
    end
    s:assertHealthy(); after:assertHealthy()
  end)

  t.test(client .. " guide switches handle combat missing modules and native failures", function()
    local s = make(nil, { HighgroundModuleBounties = true })
    local O, M = s.ns.Onboarding, s.ns.Modules
    s:command("guide")
    local missing = O.win.cards.bounties
    assert(not missing.addon:IsEnabled() and missing.addonStatus:GetText():find("Install the full bundle", 1, true))
    click(missing.addon); t.equal(#s.moduleWrites, 0, "missing addons cannot be switched")
    click(O.win.cards.macros.addon)
    s:setCombat(true)
    assert(not O.win:IsVisible(), "combat dismisses the guide")
    s:command("guide")
    assert(not O.win.cards.arena.addon:IsEnabled() and not O.win.reload:IsEnabled())
    click(O.win.cards.arena.addon); click(O.win.reload)
    t.equal(#s.moduleWrites, 1, "combat makes no native writes")
    t.equal(s.reloads, nil, "combat forbids reload")
    s:setCombat(false)
    assert(O.win.cards.arena.addon:IsEnabled() and O.win.reload:IsEnabled(), "controls recover when combat ends")
    click(O.win.cards.macros.addon); assert(not M.Pending())
    local api = client == "cata" and s.env or s.env.C_AddOns
    api.DisableAddOn = function() end
    click(O.win.cards.arena.addon)
    assert(O.win.cards.arena.addon:GetChecked() and not M.Pending(), "failed writes restore native selection")
    assert(O.win.status:GetText():find("could not change", 1, true), "native failure is visible")
    s:assertHealthy()
  end)

  t.test(client .. " module controls and pending reload fit both guide hosts at large text sizes", function()
    local s = make()
    local O = s.ns.Onboarding
    s.env.UIParent:SetSize(1280, 720)
    for _, scale in ipairs({ 1, 1.5 }) do
      s.ns.Core.SetFontScale(scale)
      for _, embedded in ipairs({ false, true }) do
        if embedded then s.ns.Hub.Open("checklist") else O.Open() end
        O.Go("enemies")
        click(O.win.cards.bounties.addon)
        for _, def in ipairs(s.ns.Modules.list) do
          local card = O.win.cards[def.key]
          inside(s, card.addon, card); inside(s, card.addonStatus, card)
          if card.enable then inside(s, card.enable, card) end
          local a, b = s.bounds(card.addon), s.bounds(card.addonStatus)
          assert(a[2] + a[4] <= b[2], "switch and status do not overlap")
        end
        inside(s, O.win.reload, O.win); inside(s, O.win.later, O.win); inside(s, O.win.status, O.win)
        local reload, later, status, view = s.bounds(O.win.reload), s.bounds(O.win.later), s.bounds(O.win.status), s.bounds(O.win.scroll.view)
        assert(reload[1] + reload[3] < later[1], "footer actions do not overlap")
        assert(view[2] + view[4] < status[2] and status[2] + status[4] <= reload[2], "status fits between the cards and actions")
        O.Go("bounties")
        assert(O.win.reload:IsVisible(), "pending changes remain reachable in the bounty path picker")
        inside(s, O.win.reload, O.win)
        O.Go("enemies"); click(O.win.cards.bounties.addon)
      end
    end
    s:assertHealthy()
  end)
end

t.finish()
