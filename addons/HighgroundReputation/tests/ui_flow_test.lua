local t = dofile("../../tools/harness.lua")("reputation UI flow")
local F = dofile("tests/fixture.lua")
local runtime = dofile("../../tools/wowsim/battleground/runtime.lua")

for _, addon in ipairs({ "Highground", "HighgroundReputation" }) do
  for _, build in ipairs({ 120100, 16001, 40402 }) do
    t.test(addon .. " " .. build .. ": browsing a paused organization never resumes it", function()
      local s = F.new("Owner", { addon = addon, build = build, client = build == 40402 and "cata" or "retail",
        guild = build == 40402 and "Test Guild" or nil, runtime = addon == "Highground" and runtime or nil })
      local W = F.W(s)
      local c = F.community(s)
      W.Disable(c)
      W.OpenOrganizations()
      local w = W.UI.window
      assert(w.rows[1]:IsVisible(), "paused organization remains available to inspect")
      F.click(s, w.rows[1].action)
      t.equal(c.enabled, false, "opening an organization must not change participation")
      assert(not W.CanModerate(c), "browsing must not resume moderation")
      s:assertHealthy()
    end)
  end
end

t.finish("Reputation UI flow: " .. t.tests .. " scenarios")
