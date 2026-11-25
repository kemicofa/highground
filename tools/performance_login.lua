-- Run from addons/Highground:
--   luajit ../../tools/performance_login.lua [cata|retail|forever] [client locale] [saved language]
-- Retained Lua heap after login: the real manifest loads, saved variables
-- apply and the selected language is ready. The simulator's compiled-chunk
-- cache is dropped first (the game keeps no file source). Includes simulated
-- widgets: compare before and after a change, not with WoW's memory meter.
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local client, locale, language = arg[1] or "retail", arg[2] or "enUS", arg[3]
assert(client == "cata" or client == "retail" or client == "forever", "expected cata, retail or forever")

collectgarbage("collect")
local initial = collectgarbage("count")
local sim = new(client == "cata" and "cata" or "retail", { locale = language }, function(_, env)
  env.GetLocale = function() return locale end
  if client == "forever" then env.GetBuildInfo = function() return "x", "1", "Nov 18 2026", 16001 end end
end)
local chunks = package.loaded["wowsim.chunks"]
for path in pairs(chunks) do chunks[path] = nil end
collectgarbage("collect"); collectgarbage("collect")
print(string.format("%s, %s client, language %s (%s): %.0f KiB retained Lua heap", client, locale,
  tostring(language or "default"), sim.ns.Locale:GetLocale(), collectgarbage("count") - initial))
