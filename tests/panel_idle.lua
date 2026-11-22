return function()
jit.off()
local t = dofile("../../tools/harness.lua")("idle panel controls")
for _, addon in ipairs({ "Highground", "HighgroundBattlegrounds", "HighgroundArena", "HighgroundNearby", "HighgroundBounties" }) do
  for _, variant in ipairs({ { "cata", 40402 }, { "retail", 120100 }, { "retail", 16001 } }) do
    t.test(addon .. " " .. variant[2] .. " settled cogs do no idle allocation or alpha writes", function()
      local new = dofile((addon == "Highground" or addon == "HighgroundBattlegrounds")
        and "../../tools/wowsim/battleground/runtime.lua" or "../../tools/wowsim/runtime.lua")
      local s = new(variant[1], { locked = true }, function(sim, e)
        sim.addon = addon
        local base, loader = "../" .. addon .. "/", sim.load
        sim.manifest = base .. addon .. (variant[1] == "cata" and "_Cata" or "") .. ".toc"
        sim.load = function(self, path) return loader(self, path:sub(1, 3) == "../" and path or base .. path) end
        e.GetBuildInfo = function() return "x", "1", "Nov 4 2026", variant[2] end
      end)
      local P, M, U = s.ns.PanelControls, s.ns.Motion, s.ns.Util
      if s.ns.BattlegroundsPreview then s.ns.BattlegroundsPreview.Start()
      elseif s.ns.ArenaPreview then s.ns.ArenaPreview()
      else s.ns.Nearby.Update() end
      s:advance(3)
      local rounded, writes = false, 0
      for _, w in ipairs(P.windows) do
        local set = w.gear.SetAlpha
        w.gear.SetAlpha = function(self, value)
          writes = writes + 1
          set(self, rounded and math.floor(value * 255 + 0.5) / 255 or value)
        end
      end
      for _, nativeRounding in ipairs({ false, true }) do
        rounded = nativeRounding
        for _, compact in ipairs(s.ns.SetCompact and { false, true } or { false }) do
          if s.ns.SetCompact then s.ns.SetCompact(compact) end
          -- Force an actual transition with the selected native readback model.
          for _, w in ipairs(P.windows) do w.gear:SetAlpha(1) end
          s:advance(3); writes = 0
          local objects, calls, kb, base = #s.frames, 0, 0, U.RunGuarded
          U.RunGuarded = function(stage, fn)
            if stage ~= "panel controls" then return base(stage, fn) end
            local before = collectgarbage("count")
            local ok = base(stage, fn)
            kb, calls = kb + collectgarbage("count") - before, calls + 1
            return ok
          end
          collectgarbage("collect"); collectgarbage("stop")
          local ok, err = pcall(function() s:advance(60) end)
          collectgarbage("restart"); U.RunGuarded = base
          assert(ok, err)
          assert(calls >= 590, "the real scheduled panel reconciliation keeps running")
          assert(kb < 2, "settled panels stay below 2 KiB/min: " .. kb)
          t.equal(writes, 0, "unchanged native endpoints require no alpha writes")
          t.equal(#s.frames, objects, "polling creates no UI objects")
          local visible
          for _, w in ipairs(P.windows) do
            assert(not M.IsPlaying(w.gear), "settled cogs have no animation")
            if w.gear:IsVisible() then visible = visible or w end
          end
          assert(visible, "the budget includes a visible locked cog")
          visible.gear:SetAlpha(0.6); P.RefreshGears()
          assert(M.IsPlaying(visible.gear), "an external alpha edit still gets reconciled")
          s:advance(0.3)
          assert(not M.IsPlaying(visible.gear), "the corrected endpoint settles")
          s.mouseOver = visible; P.RefreshGears(); s:advance(0.3)
          t.equal(visible.gear:GetAlpha(), 1, "hover still brightens the cog")
          s.mouseOver = nil; P.RefreshGears(); s:advance(0.3)
          local target = s.ns.Theme.Alpha("panelCog")
          t.equal(visible.gear:GetAlpha(), rounded and math.floor(target * 255 + 0.5) / 255 or target,
            "leaving returns to the client's settled endpoint")
        end
      end
      s:assertHealthy()
    end)
  end
end
t.finish("Idle panel controls: " .. t.tests .. " scenarios")
end
