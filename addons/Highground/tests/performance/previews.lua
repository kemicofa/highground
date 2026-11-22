local t, new = ...

for _, client in ipairs({ "cata", "retail" }) do
  t.test(client .. " repeated shared previews reuse widgets and stop their extra drivers without sending sample data", function()
    local s = new(client, {})
    local markerReads, targetPlate = 0, s.ns.Core.TargetPlateUnit
    s.ns.Core.TargetPlateUnit = function(...) markerReads = markerReads + 1; return targetPlate(...) end
    local scores, recompute = 0, s.ns.Core.Recompute
    s.ns.Core.Recompute = function(...) scores = scores + 1; return recompute(...) end
    s:advance(3)
    s:command("test all"); s:advance(2); s:command("test stop"); s:advance(2)
    local frames = #s.frames
    for _ = 1, 3 do
      local sent = #s.sent
      s:command("test all"); s:advance(0.5)
      t.equal(#s.sent, sent, "preview sends no sample messages")
      s:command("test stop"); assert(not s.ns.PreviewTests.AnyActive())
    end
    t.equal(#s.frames, frames, "reopening the sample set reuses its widgets")
    scores, markerReads = 0, 0; s:advance(2)
    t.equal(scores, 0, "preview scoring ticker is cancelled")
    t.equal(markerReads, 0, "preview marker driver is cancelled")
    s:assertHealthy()
  end)
end
