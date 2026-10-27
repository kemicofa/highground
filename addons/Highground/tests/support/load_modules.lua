-- Load one subsystem in real manifest order; useful for focused API fixtures.
return function(subsystem, env, ns)
  setfenv(assert(loadfile("core/Util.lua")), env)("Highground", ns)
  local prefixes = subsystem == "timers" and { "timers/", "flags/" } or { subsystem .. "/" }
  for line in io.lines("Highground.toc") do
    for _, prefix in ipairs(prefixes) do
      if line:sub(1, #prefix) == prefix and line:match("%.lua$") then
        setfenv(assert(loadfile(line)), env)("Highground", ns)
      end
    end
  end
end
