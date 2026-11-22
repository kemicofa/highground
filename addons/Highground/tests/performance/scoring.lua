local t, new = ...

-- Scoring reuses its working tables; readable reasons only through Core.Explain.
for _, client in ipairs({ "cata", "retail" }) do
  t.test(client .. " scoring reuses bounded working data without keeping stale reasons", function()
    local sim = new(client, {})
    local C = sim.ns.Core
    sim:command("bg test"); sim:advance(3)
    local enemy, other = C.order[1], C.order[2]
    local reasons, components = enemy.reasons, enemy.comp
    assert(reasons ~= other.reasons and components ~= other.comp, "each enemy owns its explanation")
    enemy.burst, enemy.onMe = true, true; C.Explain(enemy)
    assert(enemy.comp.burst and table.concat(enemy.reasons, " "):find("targeting YOU", 1, true))
    enemy.burst, enemy.onMe = false, false; C.Explain(enemy)
    assert(not enemy.comp.burst and not table.concat(enemy.reasons, " "):find("targeting YOU", 1, true))
    t.equal(enemy.reasons, reasons, "reason array is reused")
    enemy.onMe = true; C.Score(enemy)
    t.equal(#enemy.reasons, 0, "ordinary scoring builds no readable reasons")
    local live = enemy.live
    assert(table.concat(C.Explain(enemy), " "):find("targeting YOU", 1, true), "explaining builds them on demand")
    t.equal(enemy.live, live, "explaining does not change the score")
    t.equal(enemy.comp, components, "component table is reused")
    for _ = 1, 10 do C.Recompute() end
    collectgarbage("collect"); collectgarbage("stop")
    local before = collectgarbage("count")
    local ok, err = pcall(function() for _ = 1, 200 do C.Recompute() end end)
    local allocated = collectgarbage("count") - before
    collectgarbage("restart")
    assert(ok, err)
    assert(allocated < 64, "steady scoring must not rebuild tables: " .. allocated .. " KiB / 200 ticks")
    sim:command("bg test")
    local calls, score = 0, C.Recompute
    C.Recompute = function(...) calls = calls + 1; return score(...) end
    sim:advance(3)
    t.equal(calls, 0, "stopping test cancels its scoring loop")
    sim:assertHealthy()
  end)
end
