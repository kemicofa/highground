local test, new, equal = ...

for _, case in ipairs({ { "cata", 65 }, { "retail", 60 }, { "retail", 30, true } }) do
  test(case[1] .. (case[3] and " Blitz" or " standard") .. " node assault reaches timer window and map", function()
    local sim = new(case[1])
    sim.blitz = case[3]
    sim:join()
    sim:poi(36) -- neutral
    sim:poi(37) -- Alliance assault
    local node = sim.ns.Timers.nodes.Stables
    equal(node.capEnd - sim.now, case[2], "client-specific capture duration")
    sim:advance(0.5)
    assert(sim.env.HighgroundBasesFrame:IsShown(), "capture window visible")
    local pin
    for _, item in ipairs(sim.env.WorldMapFrame.pins) do
      if item.x == 0.2 and item.item.tooltip then
        local lines = {}
        item.item.tooltip({ AddLine = function(_, line) lines[#lines + 1] = line end })
        if table.concat(lines, " "):find("Stables", 1, true) then pin = item end
      end
    end
    assert(pin, "capture reaches actual map pin provider")
    sim:advance(case[2])
    sim:poi(38) -- Alliance owns the node
    equal(node.owner, "A", "ownership follows POI")
    equal(node.capEnd, nil, "capture clock clears")
    if case[3] then
      sim:advance(46)
      equal(node.owner, nil, "Blitz hold expires")
    end
  end)
end

test("flag chat drives carrier rows, macros, stack clock and match reset", function()
  local sim = new("cata")
  sim:enemy("Carrier")
  sim:join(1460, 489, "Warsong Gulch")
  sim:setCombat(true)
  sim:event("CHAT_MSG_BG_SYSTEM_HORDE", "The Alliance flag was picked up by Carrier!")
  sim:event("CHAT_MSG_BG_SYSTEM_ALLIANCE", "The Horde flag was picked up by Me!")
  sim:advance(0.5)
  equal(sim:entry("Carrier").carrier, true, "core identifies carrier")
  equal(sim.env.HighgroundFlagRow2.name.text, "Carrier", "flag window identifies carrier")
  assert(sim.env.HighgroundFlagRow2.attrs.macrotext1:find("@arena1,harm", 1, true), "combat-safe arena macro already exists")
  assert(not sim.env.HighgroundFlagRow2.attrs.macrotext1:find("targetexact Carrier", 1, true), "named fallback defers")
  equal(sim.ns.FlagStacks(), nil, "no premature stacks")
  sim:setCombat(false)
  assert(sim.env.HighgroundFlagRow2.attrs.macrotext1:find("targetexact Carrier", 1, true))
  sim:advance(181)
  equal(sim.ns.FlagStacks(), 1, "Cata first stack after three minutes")
  sim:event("CHAT_MSG_BG_SYSTEM_HORDE", "Carrier captured the Alliance flag!")
  sim:advance(0.5)
  equal(sim.ns.FlagStacks(), nil, "capture resets assault clock")
  equal(sim:entry("Carrier").carrier, false, "core clears carrier")
  equal(sim.env.HighgroundFlagRow2.name.text, "at base", "window clears carrier")
  sim:leave()
  sim:join(1460, 489, "Warsong Gulch")
  equal(sim.ns.FlagStacks(), nil, "same-map rematch starts clean")
end)
