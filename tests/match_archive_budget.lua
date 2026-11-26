-- Match history budgets (MatchArchive.lua): a login with a full, archived
-- history leaves the archive and its SavedVariables unloaded, and the
-- check after each loading screen allocates nothing per saved match (100
-- matches: one small table each would be hundreds of KiB per 100 checks).
return function()
local t = dofile("../../tools/harness.lua")("match archive budget")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
for _, variant in ipairs({ { "cata", 40402 }, { "retail", 120100 }, { "retail", 16001 } }) do
  t.test(variant[2] .. " a full archived history stays unloaded and loading screens allocate nothing per match", function()
    local function configure(_, env) env.GetBuildInfo = function() return "x", "1", "Nov 22 2026", variant[2] end end
    local first = new(variant[1], {}, configure)
    local list, key = first.ns.MatchHistory.All(), first.ns.Scope.Character()
    for i = 1, 100 do
      local waiting = i <= 19 and { { at = 1, text = "Waiting " .. i } } or nil
      list[i] = { id = "m" .. i, name = "Arathi Basin", map = 529, result = "Win", character = "Me", game = first.ns.GAME,
        scope = key, started = 1000 + i, updated = 2000 + i, duration = 900, events = waiting, archived = not waiting and 200 or nil }
    end
    local s = new(variant[1], first.env.HighgroundDB, configure)
    s:event("PLAYER_ENTERING_WORLD"); s:advance(1)
    assert(not s.addons.HighgroundMatchData and s.env.HighgroundMatchArchiveDB == nil, "19 waiting timelines: not loaded")
    local check = s.ns.MatchArchive.Check
    check()
    collectgarbage("collect"); collectgarbage("stop")
    local before = collectgarbage("count")
    for _ = 1, 100 do check() end
    local used = collectgarbage("count") - before
    collectgarbage("restart")
    assert(used < 4, string.format("100 checks allocated %.1f KiB", used))
    s:assertHealthy()
  end)
end
t.finish("Match archive budget: " .. t.tests .. " scenarios")
end
