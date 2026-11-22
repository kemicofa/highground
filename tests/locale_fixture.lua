-- Isolated module fixtures load the same English catalog as a real host.
-- Full-manifest simulations already include localization and need no shim.
return function(ns, env)
  if ns.Locale then return end
  for _, name in ipairs({ "Library", "Locales", "enUS", "Highground" }) do
    local load = assert(loadfile("libs/locale/" .. name .. ".lua"))
    if env then setfenv(load, env) end
    load("Fixture", ns)
  end
end
