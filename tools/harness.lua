---------------------------------------------------------------------------
-- The test harness every *_test.lua uses: named tests, assertions that
-- count checks, and a summary that exits with status 1 on any failure.
--
--   local t = dofile("../../tools/harness.lua")("label")
--   t.test("name", function() t.equal(actual, expected, "why") end)
--   t.finish("Label: " .. t.tests .. " tests")
--
-- A failing test prints its traceback and the run goes on; finish() then
-- exits unsuccessfully. "PASS label: name" lines go to stdout, failures to
-- stderr. The label is optional.
---------------------------------------------------------------------------
return function(label)
  local t = { tests = 0, checks = 0, failures = 0 }
  local prefix = label and (label .. ": ") or ""

  function t.test(name, run)
    t.tests = t.tests + 1
    local ok, err = xpcall(run, debug.traceback)
    if ok then
      print("PASS " .. prefix .. name)
    else
      t.failures = t.failures + 1
      io.stderr:write("FAIL " .. prefix .. name .. "\n" .. tostring(err) .. "\n")
    end
  end

  function t.equal(actual, expected, why)
    t.checks = t.checks + 1
    assert(actual == expected, why .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
  end

  -- equal, but numbers only need to be within epsilon (default 1e-6).
  function t.close(actual, expected, why, epsilon)
    if type(actual) == "number" and type(expected) == "number" then
      t.checks = t.checks + 1
      assert(math.abs(actual - expected) < (epsilon or 0.000001),
        why .. ": expected " .. expected .. ", got " .. actual)
    else
      t.equal(actual, expected, why)
    end
  end

  -- Prints the summary line; exits 1 after a failure (or if nothing ran).
  function t.finish(summary)
    if summary then print(summary) end
    if t.failures > 0 or t.tests + t.checks == 0 then os.exit(1) end
  end

  return t
end
