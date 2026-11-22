return function(t, new, client)
  t.test(client .. " Profiles reuses its review and bounded list while idle", function()
    local sim = new(client, {})
    local P, C, panel = sim.ns.Options.Profiles, sim.ns.Core, sim.ns.Options.panel
    P.EnsureDefault()
    local saved = P.Snapshot()
    for i = 1, 80 do C.db.profiles["Setup " .. i] = saved end
    sim.ns.Hub.Open("profiles"); sim:advance(2)
    local reviews, snapshots, review, snapshot = 0, 0, P.Review, P.Snapshot
    P.Review = function(...) reviews = reviews + 1; return review(...) end
    P.Snapshot = function(...) snapshots = snapshots + 1; return snapshot(...) end
    collectgarbage("collect")
    local baseline = collectgarbage("count")
    collectgarbage("stop")
    for _ = 1, 120 do panel.scripts.OnUpdate(panel, 0.5) end
    local allocated = collectgarbage("count") - baseline
    collectgarbage("restart")
    t.equal(reviews, 0, "unchanged visible contents are not rebuilt")
    t.equal(snapshots, 0, "a workspace without an active named profile does not copy settings every poll")
    assert(allocated < 256, "one minute of workspace polling stays below 256 KiB")
    local frames = #sim.frames
    for _ = 1, 10 do
      panel.listScroll:Scroll(panel.listScroll.range)
      panel.listScroll:Scroll(0)
    end
    t.equal(#sim.frames, frames, "scrolling many saved profiles reuses its button pool")
    assert(#panel.profileRows <= 24, "saved-list frame count is bounded")
    local style = C.StyleDB()
    style.scales = style.scales or {}; style.scales.main = 1.2
    sim:advance(0.6)
    assert(reviews > 0, "a nested edit rebuilds the visible review")
    sim.ns.Hub.win:Hide()
    reviews, snapshots = 0, 0
    sim:advance(2)
    t.equal(reviews, 0, "closed workspace does no review work")
    t.equal(snapshots, 0, "closed workspace does not snapshot settings")
    sim:assertHealthy()
  end)
end
