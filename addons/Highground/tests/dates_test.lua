-- Dates in the selected language and the game's clock setting (core/Util.lua).
-- The simulator's date() is UTC, so these times are UTC.
local t = dofile("../../tools/harness.lua")("dates")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local test, equal = t.test, t.equal

local NOW = 1795861680 -- Sat 28 Nov 2026 10:28
local WED = 1796236812 -- Wed 2 Dec 2026 18:40:12

test("days read relative to today, then as a date with the year only when it differs", function()
  local U = new("retail").ns.Util
  equal(U.Day(NOW - 3600, NOW), "Today", "same day")
  equal(U.Day(1795770300, NOW), "Yesterday", "Fri 27 Nov")
  equal(U.Day(1795910400, NOW), "Tomorrow", "midnight starts tomorrow")
  equal(U.Day(WED, NOW), "Wed", "within six days")
  equal(U.Day(1795262400, NOW), "21 Nov", "a week ago")
  equal(U.Day(1767225540, NOW), "31 Dec 2025", "another year")
  equal(U.Day(1767227400, 1767225540), "Tomorrow", "across the year end")
  equal(U.Day(1798704000, NOW), "31 Dec", "later this year")
end)

test("times follow the 12/24-hour clock setting; evidence keeps seconds", function()
  local sim = new("retail")
  local U = sim.ns.Util
  equal(U.When(WED, NOW), "Wed, 18:40", "24-hour default")
  equal(U.Exact(WED), "2 Dec 2026, 18:40:12", "exact")
  sim.cvars.timeMgrUseMilitaryTime = "0"
  equal(U.When(WED, NOW), "Wed, 6:40 PM", "12-hour clock")
  equal(U.TimeOfDay(1795910400), "12:00 AM", "midnight")
  equal(U.Exact(WED), "2 Dec 2026, 6:40:12 PM", "exact on a 12-hour clock")
end)

test("ages count minutes, hours and days", function()
  local U = new("retail").ns.Util
  equal(U.TimeAgo(20), "just now", "under a minute")
  equal(U.TimeAgo(5 * 60), "5m ago", "minutes")
  equal(U.TimeAgo(3 * 3600 + 59), "3h ago", "hours")
  equal(U.TimeAgo(2 * 86400 + 7200), "2d ago", "days")
end)

test("month names, day order and day words come from the selected language", function()
  local sim = new("retail")
  local U = sim.ns.Util
  assert(sim.ns.Localization.SetPreference("deDE"))
  equal(U.Day(WED, NOW), "Mi", "German weekday")
  equal(U.Day(1767225540, NOW), "31. Dez 2025", "German day order and month")
  equal(U.When(NOW, NOW), "Heute, 10:28", "German day word")
  equal(U.TimeAgo(2 * 86400), "vor 2 T.", "German age")
  assert(sim.ns.Localization.SetPreference("zhCN"))
  equal(U.Day(1795262400, NOW), "11月21日", "Chinese month before day")
end)

t.finish("Dates: " .. t.tests .. " scenarios, " .. t.failures .. " failures")
