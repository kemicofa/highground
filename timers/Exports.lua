local _, ns = ...
local Timers = ns.Timers

-- Test hooks for the simulator.
ns._timers = { gys = Timers.gys, nodes = Timers.nodes, NextWave = Timers.NextWave, Vote = Timers.Vote, StripText = Timers.StripText,
  GoodTimeToDie = Timers.GoodTimeToDie, MyGraveyard = Timers.MyGraveyard }
