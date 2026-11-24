-- Counts and switches read as whole sentences in every language: plural
-- forms come from Locale:Plural (Russian one/few/many), lists from
-- Locale:List, and on/off or "after combat" variants are complete messages
-- instead of translated fragments. Run from addons/Highground.
local t = dofile("../../tools/harness.lua")("locale grammar")
local check = t.equal
t.equal = function(a, b, why) return check(a, b, why or "values match") end
local new = dofile("../../tools/wowsim/battleground/runtime.lua")

local function last(sim) return sim.messages[#sim.messages] or "" end
local function has(text, part, why) assert(text:find(part, 1, true), (why or "") .. ": " .. part .. " in " .. text) end

t.test("counts use each language's plural forms", function()
  local sim = new("cata")
  local U, Loc, L = sim.ns.Util, sim.ns.Localization, sim.ns.Locale
  local ru = { [1] = "1 ошибка", [2] = "2 ошибки", [5] = "5 ошибок", [11] = "11 ошибок", [21] = "21 ошибка",
    [22] = "22 ошибки", [25] = "25 ошибок" }
  assert(Loc.SetPreference("ruRU"))
  for n, text in pairs(ru) do t.equal(U.Plural(n, "error"), text, "ru " .. n) end
  t.equal(U.Plural(3, "macro"), "3 макроса")
  t.equal(U.Plural(5, "MACRO"), "5 МАКРОСОВ")
  t.equal((sim.ns.Macros.Verdict({ errors = 2, warnings = 0 })), "2 ОШИБКИ", "macro verdict")
  t.equal(sim.ns.NearbyHistory.Summary({ times = 22, killedMe = 0, killedThem = 0 }), "встречен 22 раза ранее")
  assert(Loc.SetPreference("deDE"))
  t.equal(U.Plural(1, "warning"), "1 Warnung")
  t.equal(U.Plural(4, "warning"), "4 Warnungen")
  t.equal(sim.ns.NearbyHistory.Summary({ times = 1, killedMe = 0, killedThem = 0 }), "1-mal zuvor gesehen")
  assert(Loc.SetPreference("zhCN"))
  t.equal(U.Plural(1, "button"), "1 个按钮")
  t.equal(U.Plural(7, "button"), "7 个按钮")
  t.equal(L:List({ U.Plural(2, "button"), U.Plural(1, "macro") }), "2 个按钮和1 个宏")
  Loc.SetPreference("enUS")
  t.equal(U.Plural(1, "error"), "1 error")
  t.equal(U.Plural(2, "ERROR"), "2 ERRORS")
  t.equal(sim.ns.NearbyHistory.Summary({ times = 3, killedMe = 0, killedThem = 0 }), "seen 3 times before")
  sim:assertHealthy()
end)

t.test("settings feedback and panel locks are whole sentences", function()
  local sim = new("cata")
  local Loc, L = sim.ns.Localization, sim.ns.Locale
  local cases = {
    { "deDE", "Kompaktes Layout: an", "UI-Skalierung: 120%", "Panels gesperrt.", "(aktiv)" },
    { "ruRU", "Компактная раскладка: вкл.", "Масштаб интерфейса: 120%", "Панели закреплены.", "(выбрана)" },
    { "zhCN", "紧凑布局：开启", "界面缩放：120%", "面板已锁定。", "（当前）" },
  }
  for _, case in ipairs(cases) do
    assert(Loc.SetPreference(case[1]))
    sim:command("compact on")
    has(last(sim), case[2], case[1] .. " compact")
    sim:command("compact off")
    sim:command("scale 1.2")
    has(last(sim), case[3], case[1] .. " scale")
    sim:command("theme")
    has(last(sim), case[5], case[1] .. " active theme")
    if not sim.ns.PanelControls.Locked() then sim.ns.PanelControls.Toggle() end
    sim.ns.PanelControls.Toggle()
    sim.ns.PanelControls.Toggle()
    has(last(sim), case[4], case[1] .. " panels")
    has(last(sim), sim.ns.PanelControls.Hint(), case[1] .. " hint follows")
  end
  sim:setCombat(true)
  assert(Loc.SetPreference("ruRU"))
  sim:command("scale 1.1")
  has(last(sim), "Масштаб интерфейса: 110% (применится после боя)", "pending scale")
  sim:setCombat(false)
  Loc.SetPreference("enUS")
  sim:command("compact on")
  has(last(sim), "compact layout: on", "English")
  sim:assertHealthy()
end)

t.test("Home names Nearby enemies and panel locks in one sentence", function()
  local sim = new("cata")
  local Loc, L = sim.ns.Localization, sim.ns.Locale
  sim:command("")
  local h = sim.ns.Hub.home
  for _, locale in ipairs({ "deDE", "ruRU", "zhCN" }) do
    assert(Loc.SetPreference(locale))
    sim.ns.Hub.Show("home")
    local on = sim.ns.Core.On("nearby")
    t.equal(h.state:GetText(), L:Get(on and "highground.home.panels_open_when_a_match_starts_nearby.75be9a"
      or "highground.home.panels_open_when_a_match_starts_nearby.0415ef"), locale .. " nearby state")
    has(h.help:GetText(), sim.ns.PanelControls.Hint(), locale .. " help")
  end
  t.equal(L:Get("highground.home.panels_open_when_a_match_starts_nearby.75be9a"),
    "面板会在对局开始时打开。“附近敌人”已开启。")
  Loc.SetPreference("enUS")
  sim:assertHealthy()
end)

t.finish("Locale grammar: " .. t.tests .. " tests")
