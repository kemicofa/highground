---------------------------------------------------------------------------
-- Prints "file:line: name" for every global write (GSET) in the given Lua
-- files, from LuaJIT's bytecode. lint.py filters the allowed names.
-- Usage: luajit tools/lint/globals.lua <file>...
---------------------------------------------------------------------------
local jutil, vmdef = require("jit.util"), require("jit.vmdef")
local band, rshift = bit.band, bit.rshift
local funcinfo, funcbc, funck = jutil.funcinfo, jutil.funcbc, jutil.funck

local function scan(path, func)
  for pc = 1, math.huge do
    local ins = funcbc(func, pc)
    if not ins then break end
    local op = band(ins, 0xff) * 6
    if vmdef.bcnames:sub(op + 1, op + 6) == "GSET  " then
      local name = funck(func, -rshift(ins, 16) - 1)
      print(("%s:%d: %s"):format(path, funcinfo(func, pc).currentline, name))
    end
  end
  for n = -1, -math.huge, -1 do
    local k = funck(func, n)
    if k == nil then break end
    if type(k) == "proto" then scan(path, k) end
  end
end

for _, path in ipairs(arg) do
  scan(path, assert(loadfile(path)))
end
