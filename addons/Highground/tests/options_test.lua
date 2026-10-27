-- Build the real options and profile handlers against a frame fixture.
-- Validate canonical controls, inherited values and client visibility.
-- Run from addons/Highground: luajit tests/options_test.lua
local t = dofile("../../tools/harness.lua")()
local o = dofile("tests/options/fixture.lua")
o.equal = t.equal
local cata = assert(loadfile("tests/options/controls.lua"))(o)
assert(loadfile("tests/options/profiles.lua"))(o)
assert(loadfile("tests/options/tracking.lua"))(o)
assert(loadfile("tests/options/features.lua"))(o, cata)
t.finish("Options: " .. t.checks .. " checks passed")
