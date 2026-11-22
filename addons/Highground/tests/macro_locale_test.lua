-- Macros in another language: own buffs keep their client names and icons,
-- marker hints and the window's fitted labels follow a language change.
local t = dofile("../../tools/harness.lua")("macro locale")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local test, equal = t.test, t.equal
local function german(_, env) env.GetLocale = function() return "deDE" end end

for _, game in ipairs({ "cata", "retail" }) do
  test(game .. ": every own buff to remove is offered under its client name", function()
    local sim = new(game, nil, german)
    local M = sim.ns.Macros
    local icons = M.Config.BUFF_ICONS
    M.Host.SpellName = function(id) return "DE " .. id end
    for class, list in pairs(M.Config.CLASS_BUFFS) do
      sim.ns.Core.me.class = class
      local want = {}
      for _, a in ipairs(list) do
        local english = type(a[1]) == "table" and M.ForGame(a[1], game) or a[1]
        if type(english) == "string" then
          local id = M.SpellIDs[english]
          if type(id) == "table" then id = M.ForGame(id, game) end
          want[#want + 1] = { name = "DE " .. tostring(id), english = english }
          sim.known["DE " .. tostring(id)] = true
        end
      end
      local _, items = M.Suggest.AuraProvider("")
      local got = {}
      for _, item in ipairs(items) do got[item.text] = item end
      for _, w in ipairs(want) do
        assert(got[w.name], class .. ": " .. w.english .. " offered as " .. w.name)
        if icons[w.english] then
          equal(got[w.name].fallbackIcon, "Interface\\Icons\\" .. icons[w.english], w.english .. " keeps its icon")
        end
      end
    end
  end)
end

test("raid marker hints follow a language change", function()
  local sim = new("cata")
  local M = sim.ns.Macros
  local function hint(number)
    local _, items = M.Suggest.CodeProvider("/tm ")
    for _, item in ipairs(items) do if item.text == number then return item.hint end end
  end
  local english = hint("8")
  equal(english, M.Config.MARKERS[8], "skull named")
  assert(sim.ns.Localization.SetPreference("deDE"))
  equal(hint("8"), M.Config.MARKERS[8], "relabelled marker")
  assert(hint("8") ~= english, "German hint: " .. tostring(hint("8")))
  equal(hint("0"), sim.ns.Locale:Get("macros.suggest.clear.168cbb"), "clear hint")
end)

test("an open Macros window refits its labels after a language change", function()
  local sim = new("cata")
  sim:command("macros")
  local Win = sim.ns.Macros.Window
  Win.SetTab("mine")
  local w = Win.win
  local width = w.open:GetWidth()
  assert(sim.ns.Localization.SetPreference("deDE"))
  equal(w.open:GetText(), sim.ns.Locale:Get("macros.frame.open_wow_macros.94c506"), "relabelled")
  assert(w.open:GetWidth() ~= width, "fitted to the German label: " .. width .. " -> " .. w.open:GetWidth())
  assert(w.layoutKey:find("deDE", 1, true), "layout keyed by language")
end)

t.finish("Macro locale: " .. t.tests .. " scenarios, " .. t.failures .. " failures")
