-- Load one subsystem in real manifest order; useful for focused API fixtures.
return function(subsystem, env, ns)
  setfenv(assert(loadfile("libs/core/Util.lua")), env)("Highground", ns)
  setfenv(assert(loadfile("libs/core/Comms.lua")), env)("Highground", ns)
  -- Battleground subsystems live in the Battlegrounds addon (features/battlegrounds);
  -- the HUD windows timers use are the library's (libs/ui/Windows.lua).
  local BG = "features/battlegrounds/"
  local prefixes = subsystem == "timers" and { BG .. "timers/", "libs/ui/Windows.lua", BG .. "flags/" }
    or { BG .. subsystem .. "/" }
  for line in io.lines("Highground.toc") do
    for _, prefix in ipairs(prefixes) do
      if line:sub(1, #prefix) == prefix and line:match("%.lua$") and line ~= "libs/core/Comms.lua" then
        setfenv(assert(loadfile(line)), env)("Highground", ns)
      end
    end
  end
end
