local HERE = debug.getinfo(1, "S").source:match("^@(.*/)")
local new = dofile(HERE .. "installation_runtime.lua")
local root, build, reverse = arg[1], tonumber(arg[2]), arg[3] == "reverse"
local folders = {}; for i = 4, #arg do folders[#folders + 1] = arg[i] end
local disabled = {}
if arg[3] == "disabled" then
  disabled.Highground, disabled.HighgroundBounties = true, true
  for _, name in ipairs(folders) do if name:match("^HighgroundModule") then disabled[name] = true end end
end
local sim = new(root, build, folders, nil, reverse, nil, disabled)
local env, namespaces = sim.env, sim.namespaces
local bountyOwner, reputationOwner, windows
local aliases = {}
for key, alias in pairs(env) do
  if type(key) == "string" and key:match("^SLASH_") then
    assert(not aliases[alias], "duplicate slash alias: " .. alias)
    aliases[alias] = key
  end
end

for name, ns in pairs(namespaces) do
  if ns.Core then
    local standby = name ~= "Highground" and (namespaces.Highground ~= nil
      or name == "HighgroundNearby" and namespaces.HighgroundBounties ~= nil)
    assert(not not ns.STANDBY == not not standby, name .. ": correct active host")
    if standby then
      assert(ns.Core.db == nil, name .. ": standby leaves settings alone")
      assert(not (ns.Bounty and ns.Bounty.Public.ready), name .. ": standby cannot own bounty data")
      assert(not (ns.Reputation and ns.Reputation.ready), name .. ": standby cannot own reputation data")
    else
      assert(ns.Core.db == env[name .. "DB"], name .. ": independent settings")
      assert(not windows or windows == ns.Kit.Windows, "dialog coordinator is shared")
      windows = ns.Kit.Windows
      if ns.Bounty then
        assert(not bountyOwner, "only one active bounty engine")
        bountyOwner = name
        assert(ns.Bounty.Public.ready and ns.Bounty.Public.db == env.HighgroundBountyNetworkDB)
      end
      if ns.Reputation then
        assert(not reputationOwner, "only one active reputation engine")
        reputationOwner = name
        assert(ns.Reputation.ready and ns.Reputation.db == env.HighgroundReputationNetworkDB)
      end
    end
  end
end

-- Exercise every entry point after every copy of the shared libraries loads.
for _, name in ipairs(folders) do
  local ns = namespaces[name]
  if ns and ns.Standalone then
    local command = ns.Standalone.spec.command
    sim:slash(command, "help")
    sim:slash(command, "config")
    if not ns.STANDBY then
      local themes = {}
      for host, other in pairs(namespaces) do
        if other.Core and other.Core.db then themes[host] = { other.Core.db.theme } end
      end
      sim:slash(command, "theme ember")
      assert(ns.Core.db.theme == "ember", "theme applies to its host")
      for host, theme in pairs(themes) do
        if host ~= name then assert(namespaces[host].Core.db.theme == theme[1], "settings cannot leak to " .. host) end
      end
      if ns.Macros or ns.Reputation then sim:slash(command, "") end
      if ns.Arena or ns.Nearby or ns.BattlegroundsPreview then
        local preview = name == "HighgroundBounties" and "nearby test" or "test"
        sim:slash(command, preview); sim:advance(0.1); sim:slash(command, preview)
      end
      if ns.Bounty then
        local prefix = name == "HighgroundNearby" and "bounty " or ""
        sim:slash(command, prefix .. "test board")
        sim:slash(command, prefix .. "test stop")
        sim:slash(command, prefix .. "guide board")
        sim:slash(command, prefix .. "guide stop")
      end
    end
  end
end

sim:setCombat(true); sim:advance(0.2); sim:setCombat(false)
sim:join(); sim:advance(0.2); sim:leave()
sim:joinArena(); sim:advance(0.2); sim:leave()
sim:advance(2)
sim:assertHealthy()
