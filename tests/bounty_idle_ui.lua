-- Open bounty windows left idle, with the game's deferred resize events
-- (tools/wowsim/resize.lua). On Forever the guild's club ID may never resolve,
-- so organizations stay loading; without a guild or communities they are
-- unavailable. Neither may make the board or a mounted Create Bounty form
-- list organizations or allocate on every frame.
return function(addon)
local t = dofile("../../tools/harness.lua")(addon .. " idle bounty windows")
local fixture = dofile("../../tests/bounty_idle_fixture.lua")
local STATES = {
  loading = function(s, e) e.C_Club.GetGuildClubId = function() end; s.native = {} end,
  unavailable = function(s, e)
    s.clubsDisabled = true
    e.GetGuildInfo = function() end; e.IsInGuild = function() return false end
  end,
}
local function new(state)
  local s = fixture(addon, "retail", 16001, function(s, e)
    dofile("../../tools/wowsim/resize.lua")(s)
    e.GetMoney = function() return 1234567 end -- a known balance, as in the game
    STATES[state](s, e)
  end)
  s:advance(30)
  t.equal(select(2, s.ns.Organizations.List()), state, "organizations are " .. state)
  return s
end

-- One idle minute: organization lists, resize/reflow events, Board.Refresh
-- calls and the KiB allocated outside them (simulator measurements excluded).
local function Idle(s)
  local O, Board = s.ns.Organizations, s.ns.Bounty.Board
  local lists, refreshes, refreshKB = 0, 0, 0
  local list, refresh = O.List, Board.Refresh
  O.List = function(...) lists = lists + 1; return list(...) end
  Board.Refresh = function(...)
    local before = collectgarbage("count")
    refresh(...)
    refreshes, refreshKB = refreshes + 1, refreshKB + collectgarbage("count") - before
  end
  local events, overhead = s.resizes, s.resizeKB
  collectgarbage("collect")
  local memory = collectgarbage("count")
  collectgarbage("stop")
  local ok, err = pcall(s.advance, s, 60)
  local allocated = collectgarbage("count") - memory
  collectgarbage("restart")
  O.List, Board.Refresh = list, refresh
  assert(ok, err)
  return { lists = lists, events = s.resizes - events, refreshes = refreshes,
    kb = allocated - (s.resizeKB - overhead) - refreshKB }
end

local function Settle(s) s:advance(5); s:assertHealthy() end
-- Typing lays the form out again while it is shown, as the player does.
local function Type(s, w, name)
  Settle(s)
  w.name:SetText(name or "Enemy")
  Settle(s)
end

for _, state in ipairs({ "loading", "unavailable" }) do
  t.test("Forever " .. state .. ": an idle board polls every five seconds without resize events", function()
    local s = new(state)
    s.ns.Bounty.Board.Open(); Settle(s)
    local idle = Idle(s)
    t.equal(idle.events, 0, "no resize or text reflow events")
    assert(idle.refreshes <= 13, "only the five-second age poll refreshes: " .. idle.refreshes)
    assert(idle.lists <= 13, "at most one organization list per poll: " .. idle.lists)
    assert(idle.kb < 32, "nothing else allocates: " .. idle.kb .. " KiB")
    s:assertHealthy()
  end)

  t.test("Forever " .. state .. ": a mounted Create Bounty form stays idle", function()
    local s = new(state)
    local B = s.ns.Bounty
    B.Board.Open(); s:advance(1); B.Form.Open(); Type(s, B.Form.win)
    assert(B.Form.win:IsVisible() and B.Board.win.page == B.Form.win, "the form covers the board")
    local idle = Idle(s)
    t.equal(idle.events, 0, "no resize or text reflow events")
    assert(idle.lists <= 6, "organizations are not listed every frame: " .. idle.lists)
    assert(idle.kb < 32, "the idle form allocates almost nothing: " .. idle.kb .. " KiB")
    for step = 2, 3 do
      B.Form.win.name:SetText("Enemy-Realm"); B.Form.win.gold:SetText("5")
      B.Form.Step(B.Form.win, step); Settle(s)
      idle = Idle(s)
      t.equal(idle.events, 0, "step " .. step .. " has no resize or text reflow events")
      assert(idle.lists <= 6 and idle.kb < 32, "step " .. step .. " stays idle: " .. idle.lists .. " lists, " .. idle.kb .. " KiB")
    end
    s:assertHealthy()
  end)
end

if addon == "Highground" then
  t.test("Forever loading: the board and form opened from the Bounties hub page stay idle", function()
    local s = new("loading")
    local B = s.ns.Bounty
    s.ns.Hub.Open("module-bounties"); s:advance(1)
    B.Board.Open(); s:advance(1); B.Form.Open(); Type(s, B.Form.win)
    assert(B.Form.win:IsVisible(), "the form is shown")
    local idle = Idle(s)
    t.equal(idle.events, 0, "no resize or text reflow events")
    assert(idle.lists <= 6 and idle.kb < 32, "idle: " .. idle.lists .. " lists, " .. idle.kb .. " KiB")
    s:assertHealthy()
  end)
end

t.test("Forever loading: the sample Create Bounty form stays idle", function()
  local s = new("loading")
  local B = s.ns.Bounty
  B.Form.Open(nil, "personal", nil, true); Type(s, B.Form.previewWin)
  assert(B.Form.previewWin:IsVisible(), "the sample form is shown")
  local idle = Idle(s)
  t.equal(idle.events, 0, "no resize or text reflow events")
  assert(idle.kb < 32, "the sample form allocates almost nothing: " .. idle.kb .. " KiB")
  s:assertHealthy()
end)

t.test("a reflowed name field neither recomputes funding nor clears a validation error", function()
  local s = new("loading")
  local B = s.ns.Bounty
  B.Board.Open(); s:advance(1); B.Form.Open(); Settle(s)
  local w = B.Form.win
  local widths, setWidth = 0, w.name.SetWidth
  w.name.SetWidth = function(self, value)
    if math.abs(self:GetWidth() - value) > 0.001 then widths = widths + 1 end
    return setWidth(self, value)
  end
  B.Form.Layout(w)
  t.equal(widths, 0, "an unchanged layout does not resize the name field")
  B.Form.Advance(w)
  local message = w.error:GetText()
  assert(message ~= "", "an empty target is rejected")
  local fundings, funding = 0, B.Form.Funding
  B.Form.Funding = function(...) fundings = fundings + 1; return funding(...) end
  for _, script in ipairs({ w.name.scripts.OnTextChanged, unpack(w.name.hooks.OnTextChanged) }) do script(w.name, false) end
  s:advance(1)
  t.equal(w.error:GetText(), message, "the validation error stays")
  t.equal(fundings, 0, "an unchanged name does not recompute funding")
  w.name:SetText("Enemy")
  t.equal(w.error:GetText(), "", "an edit clears the error")
  t.equal(fundings, 1, "an edit recomputes funding once")
  B.Form.Funding, w.name.SetWidth = funding, nil
  s:assertHealthy()
end)

t.finish("Idle bounty windows: " .. t.tests .. " scenarios, " .. t.failures .. " failures")
end
