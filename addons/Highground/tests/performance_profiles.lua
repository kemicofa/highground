return function(t, new, client)
  t.test(client .. " Profiles reuses its rows and does no work while idle", function()
    local sim = new(client, {})
    local P, CS, panel = sim.ns.Options.Profiles, sim.ns.CharacterSettings, sim.ns.Options.panel
    local code = CS.Export("battlegrounds")
    for i = 1, 80 do assert(CS.Import(code, "Friend " .. i)) end
    sim.ns.Hub.Open("profiles"); sim:advance(2)
    t.equal(#panel.items, 81, "this character and every import are listed")
    local lists, snapshots, list, snapshot = 0, 0, CS.Profiles, P.Snapshot
    CS.Profiles = function(...) lists = lists + 1; return list(...) end
    P.Snapshot = function(...) snapshots = snapshots + 1; return snapshot(...) end
    collectgarbage("collect")
    local baseline = collectgarbage("count")
    collectgarbage("stop")
    sim:advance(60)
    local allocated = collectgarbage("count") - baseline
    collectgarbage("restart")
    t.equal(lists, 0, "unchanged visible contents are not rebuilt")
    t.equal(snapshots, 0, "an open Profiles page does not copy settings")
    assert(allocated < 256, "one minute of an open Profiles page stays below 256 KiB")
    local function browse()
      panel.list:Scroll(panel.list.range)
      panel.list:Scroll(0)
      panel.addons.byKey.nearby:Click(); panel.addons.byKey.battlegrounds:Click()
    end
    browse() -- each choice builds its selected glow on first selection
    local frames = #sim.frames
    for _ = 1, 10 do browse() end
    t.equal(#sim.frames, frames, "scrolling and switching addons reuse the rows")
    assert(CS.Delete({ import = 1 }) and lists > 0, "a change refreshes the list")
    t.equal(#sim.frames, frames, "a shorter list hides rows instead of making new ones")
    sim.ns.Hub.win:Hide()
    lists, snapshots = 0, 0
    sim:advance(2)
    t.equal(lists, 0, "a closed Profiles page does no list work")
    t.equal(snapshots, 0, "a closed Profiles page does not snapshot settings")
    sim:assertHealthy()
  end)
end
