return function(addon)
local t = dofile("../../tools/harness.lua")("idle bounties")
local new = dofile("../../tests/bounty_idle_fixture.lua")
for _, variant in ipairs({ { "cata", 40402 }, { "retail", 120100 }, { "retail", 16001 } }) do
  t.test(addon .. " " .. variant[2] .. " empty notifications and retries do no native organization work", function()
    local s = new(addon, variant[1], variant[2])
    s:advance(30)
    local B, O = s.ns.Bounty, s.ns.Organizations
    local lists, guilds, list, guild = 0, 0, O.List, O.Guild
    O.List = function(...) lists = lists + 1; return list(...) end
    O.Guild = function(...) guilds = guilds + 1; return guild(...) end
    collectgarbage("collect")
    local memory = collectgarbage("count")
    collectgarbage("stop")
    local ok, err = pcall(function()
      for tick = 1, 240 do
        s.now = s.now + 0.25
        B.Tick(s.now)
        if tick % 4 == 0 then B.Matches.Scan() end
      end
    end)
    local allocated = collectgarbage("count") - memory
    collectgarbage("restart")
    assert(ok, err)
    t.equal(lists, 0, "empty records need no native organization lists")
    t.equal(guilds, 0, "empty retries need no native guild descriptors")
    assert(allocated < 64, "empty bounty callbacks stay below 64 KiB/min: " .. allocated)
    t.equal(#B.queue, 0, "no guild messages produced")
    t.equal(#B.Public.outbox, 0, "no public messages produced")
    s:assertHealthy()
  end)
end
t.finish("Idle bounties: " .. t.tests .. " scenarios, " .. t.failures .. " failures")
end
