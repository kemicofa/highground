---------------------------------------------------------------------------
-- Line and function coverage for the Lua suites (LuaJIT, Lua 5.1 code).
-- scripts/lua_coverage.py merges the results; run it through the test runner:
--   bash tests/run.sh --addons-only --coverage --jobs 2
--
--   luajit tools/coverage.lua run <out> <script> [args...]
--     Runs a test script with line and call hooks, then writes its hits to
--     <out> ("L source line count" and "F source linedefined count" rows).
--     JIT compilation is off so every executed line reaches the hook. The
--     hook pauses while a test has stopped the collector, so allocation
--     budgets measure the code under test rather than the hook. Expect
--     suites to run 10-20 times slower.
--   luajit tools/coverage.lua lines <file>...
--     Prints each file's executable lines ("L file line") and functions
--     ("F file linedefined lastlinedefined") from its bytecode.
-- Only line coverage is exact: functions are keyed by their first line, so
-- functions defined on the same line share one call count.
---------------------------------------------------------------------------
local mode = arg[1]

local function lines(paths)
  local jutil, vmdef = require("jit.util"), require("jit.vmdef")
  local band = bit.band
  local funcinfo, funcbc, funck = jutil.funcinfo, jutil.funcbc, jutil.funck
  local function opcode(ins) local op = band(ins, 0xff) * 6; return vmdef.bcnames:sub(op + 1, op + 6) end
  local function walk(path, func, seen, main)
    local info = funcinfo(func)
    if not main then
      print(("F\t%s\t%d\t%d"):format(path, info.linedefined, info.lastlinedefined))
    end
    local last
    for pc = 1, math.huge do
      local ins = funcbc(func, pc)
      if not ins then break end
      last = pc
    end
    for pc = 1, last or 0 do
      -- The implicit return at a function's closing "end" is never reported
      -- after an explicit return, so it does not count as a line to cover.
      local implicit = pc == last and opcode(funcbc(func, pc)) == "RET0  "
      local line = funcinfo(func, pc).currentline
      if not implicit and line > 0 and not seen[line] then
        seen[line] = true
        print(("L\t%s\t%d"):format(path, line))
      end
    end
    for n = -1, -math.huge, -1 do
      local k = funck(func, n)
      if k == nil then break end
      if type(k) == "proto" then walk(path, k, seen) end
    end
  end
  for _, path in ipairs(paths) do
    local func, err = loadfile(path)
    if func then walk(path, func, {}, true) else io.stderr:write(err, "\n") end
  end
end

local function run(out, script, ...)
  local getinfo, sethook = debug.getinfo, debug.sethook
  local hits, calls = {}, {}
  -- Per-function records, so most hook calls need only the cheap "f" lookup.
  local records = setmetatable({}, { __mode = "k" })
  local function record(func)
    local info = getinfo(func, "S")
    local source = info.source
    hits[source] = hits[source] or {}
    calls[source] = calls[source] or {}
    local entry = { hits = hits[source], calls = calls[source], defined = info.linedefined }
    records[func] = entry
    return entry
  end
  local function hook(event, line)
    local func = getinfo(2, "f").func
    local entry = records[func] or record(func)
    if event == "line" then
      local counts = entry.hits
      counts[line] = (counts[line] or 0) + 1
    else
      local counts, defined = entry.calls, entry.defined
      counts[defined] = (counts[defined] or 0) + 1
    end
  end
  local written = false
  local function write()
    if written then return end
    written = true
    sethook()
    local file = assert(io.open(out, "w"))
    for kind, data in pairs({ L = hits, F = calls }) do
      for source, counts in pairs(data) do
        if source:sub(1, 1) == "@" then
          for line, count in pairs(counts) do
            file:write(kind, "\t", source:sub(2), "\t", line, "\t", count, "\n")
          end
        end
      end
    end
    file:close()
  end
  local collect, exit, stopped = collectgarbage, os.exit, false
  _G.collectgarbage = function(option, ...)
    if option == "stop" and not stopped then
      stopped = true; sethook()
    elseif option == "restart" and stopped then
      stopped = false; sethook(hook, "cl")
    end
    return collect(option, ...)
  end
  _G.os.exit = function(...) write(); return exit(...) end
  local chunk = assert(loadfile(script))
  _G.arg = { [0] = script, ... }
  if jit then jit.off() end
  -- Hook bookkeeping allocates on every line; collecting less often keeps
  -- large simulations from spending most of their time in the collector.
  collect("setpause", 400)
  local args = { n = select("#", ...), ... }
  sethook(hook, "cl")
  local ok, err = xpcall(function() return chunk(unpack(args, 1, args.n)) end, debug.traceback)
  write()
  if not ok then
    io.stderr:write("luajit: ", tostring(err), "\n")
    exit(1)
  end
end

if mode == "lines" then
  lines({ select(2, unpack(arg)) })
elseif mode == "run" and arg[2] and arg[3] then
  run(select(2, unpack(arg)))
else
  io.stderr:write("usage: luajit tools/coverage.lua run <out> <script> [args...] | lines <file>...\n")
  os.exit(2)
end
