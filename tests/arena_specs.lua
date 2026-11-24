return function(addon)
  local t = dofile("../../tools/harness.lua")(addon .. " arena specs")
  local new = dofile("../../tools/wowsim/battleground/runtime.lua")
  local function equal(a, b, why) t.equal(a, b, why or "spec state") end
  local function setup(build, configure)
    return new(build == 40402 and "cata" or "retail", {}, function(s, env)
      s.addon, s.manifest = addon, addon .. (build == 40402 and "_Cata" or "") .. ".toc"
      env.GetBuildInfo = function() return "x", "1", "Nov 19 2026", build end
      if configure then configure(s, env) end
    end)
  end

  t.test("native arena preparation supplies the spec and its icon", function()
    local sim = setup(120100, function(_, env)
      env.GetArenaOpponentSpec = function(i) return i == 1 and 64 or 0 end
      env.GetSpecializationInfoByID = function(id) return id, "Client Frost", nil, 99999, "DAMAGER", "MAGE" end
    end)
    sim.units.arena1 = { name = "Frostbite", classID = 8, guid = "Player-Frostbite" }
    sim:joinArena()
    local A = sim.ns.Arena
    equal(A.seen[1].specID, 64)
    equal(A.rows[1].icon.texture, 99999)
    equal(A.SpecLabel(A.seen[1]), "Client Frost")
    assert(A.rows[1].spec == nil, "no redundant class or spec text row")
  end)

  for _, build in ipairs({ 120100, 40402 }) do
    t.test(build .. ": spec previews work without the battleground spec catalog", function()
      local sim = setup(build)
      local A = sim.ns.Arena
      sim.ns.Core.specByName = {}
      sim.ns.ArenaPreview()
      equal(A.rows[1].icon.texture, A.specCatalog[261].icon, "Subtlety preview uses its spec icon")
      equal(A.rows[1].spec, nil)
    end)
  end
  t.finish("Arena specs: " .. t.tests .. " scenarios")
end
