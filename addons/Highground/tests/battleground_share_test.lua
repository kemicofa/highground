-- Shift-click sharing (timers/Objectives.lua, Forecast.lua, flags/Window.lua,
-- core/Calling.lua): one chat line in the chat box on the callout channel.
-- Run from addons/Highground: luajit tests/battleground_share_test.lua
local t = dofile("../../tools/harness.lua")("battleground sharing")
local new = dofile("../../tools/wowsim/battleground/runtime.lua")
local equal = t.equal

local function chat(sim, side, text) sim:event("CHAT_MSG_BG_SYSTEM_" .. side, text) end

-- Score widgets for the forecast, reporting changes like the game.
local function widgets(sim, env)
  local store = {}
  sim.widgetText = setmetatable({}, { __index = store, __newindex = function(_, id, value)
    store[id] = value
    sim:event("UPDATE_UI_WIDGET", { widgetID = id })
  end })
  env.C_UIWidgetManager = {
    GetIconAndTextWidgetVisualizationInfo = function(id)
      local text = sim.widgetText[id]
      return text and { text = text }
    end,
    GetTopCenterWidgetSetID = function() return 1 end,
    GetAllWidgetsBySetID = function() return {} end,
  }
end

local function shiftUp(sim, frame, button)
  sim.shift = true
  frame:GetScript("OnMouseUp")(frame, button or "LeftButton")
  sim.shift = false
end

t.test("shift-click puts the forecast and timer rows in the chat box on the callout channel", function()
  local sim = new("cata", {}, widgets)
  sim:enemy("Foe")
  sim:join(93, 529, "Arathi Basin")
  local T, env = sim.ns.Timers, sim.env
  sim.widgetText[1893], sim.widgetText[1894] = "Bases: 3  Resources: 900/1500", "Bases: 2  Resources: 1000/1500"
  sim:advance(0.5)
  local b = T.foreWin.block
  b:GetScript("OnMouseUp")(b, "LeftButton")
  shiftUp(sim, b, "RightButton")
  equal(sim.chatDraft, nil, "a plain click or a right shift-click shares nothing")
  shiftUp(sim, b)
  equal(sim.chatDraft, "/s Forecast: Alliance wins in 6:00 (Alliance 900 - Horde 1000, 1500 to win) · Horde needs 3 bases",
    "the forecast and the bases needed, on the default callout channel")
  T.ShowForecast({ winner = "A", left = 300, frac = 0.6, A = 900, H = 1000, max = 1500, heldWinner = "H", heldLeft = 400 })
  shiftUp(sim, b)
  equal(sim.chatDraft, "/s Forecast: Alliance wins in 6:00 (Alliance 900 - Horde 1000, 1500 to win) · Horde needs 3 bases"
    .. " Forecast: Alliance wins in 5:00 (Alliance 900 - Horde 1000, 1500 to win) · If defended: Horde wins in 6:40",
    "an open draft keeps its text and channel; If defended joins the line")
  b:GetScript("OnEnter")(b)
  assert(table.concat(env.GameTooltip.lines, "\n"):find("Shift-click to share in chat", 1, true), "the tooltip says how")

  sim.chatEditing, sim.chatDraft = false, nil
  sim:command("call i")
  local res, obj = T.Windows()
  T.ShowRows(res, {
    T.Tag({ color = "accent", team = "A", place = "Stables", text = "Stables", left = 12, total = 30 }, "YOU"),
    T.Tag({ color = "accent", team = "H", text = "spot unknown", left = 23, total = 30, est = true }, "THEIRS"),
    T.Tag({ color = "accent", team = "A", text = "Farm", total = 30 }, "OURS"),
    T.Tag({ color = "accent", team = "A", text = "Waiting for a graveyard timer" }, "RES"),
  })
  local function share(w, i)
    sim.chatEditing, sim.chatDraft = false, nil
    shiftUp(sim, w.rows[i])
    return sim.chatDraft
  end
  equal(share(res, 1), "/i Alliance res at Stables in 12s", "your wave with team names, on the chosen channel")
  equal(share(res, 2), "/i Horde res in ~23s", "an unplaced, estimated wave")
  equal(share(res, 3), nil, "a graveyard without a timer")
  equal(share(res, 4), nil, "the waiting placeholder")
  res.rows[4].ShowTip(res.rows[4])
  assert(not table.concat(env.GameTooltip.lines, "\n"):find("Shift-click", 1, true), "no hint where nothing is shared")
  T.ShowRows(obj, {
    T.Tag({ color = "accent", team = "H", text = "Lumber Mill from Alliance", place = "Lumber Mill", left = 38, total = 60 }, "CAP"),
    T.Tag({ color = "accent", text = "Respawn", left = 8, total = 11 }, "FLAG"),
    T.Tag({ color = "accent", team = "H", text = "Vexa  Gold Mine", who = "Vexa", place = "Gold Mine", left = 3.2, time = "~3.2s" }, "CAPPING"),
    T.Tag({ color = "accent", team = "H", text = "Stables · 2 seen 4s ago", place = "Stables", time = "" }, "THEIRS"),
    T.Tag({ color = "accent", text = "Blacksmith", place = "Blacksmith", time = "" }, "NEUTRAL"),
    T.Tag({ color = "accent", text = "Reinforcements", detail = "Reinforcements (300/600)", time = "50%", frac = 0.5 }, "STATUS"),
    T.Tag({ color = "accent", place = "Farm", text = "Farm", left = 45, total = 60, est = true }, "RESET"),
  })
  equal(share(obj, 1), "/i Horde takes Lumber Mill in 38s", "a capture")
  equal(share(obj, 2), "/i Flag respawns in 8s", "the flag respawn")
  equal(share(obj, 3), "/i Vexa (Horde) is capping Gold Mine: ~3.2s", "an enemy clicking a banner")
  equal(share(obj, 4), "/i Horde: Stables · 2 seen 4s ago", "a base and its sightings")
  equal(share(obj, 5), "/i NEUTRAL: Blacksmith", "a neutral base")
  equal(share(obj, 6), "/i Reinforcements (300/600)", "game status text as the game gives it")
  equal(share(obj, 7), "/i Farm resets in ~45s", "a reset")
  sim.chatEditing = false
  env.ChatFrame_OpenChat(string.rep("x", 240))
  shiftUp(sim, obj.rows[1])
  equal(sim.chatDraft, string.rep("x", 240), "a full draft is left alone")
  assert(sim.messages[#sim.messages]:find("Not enough room", 1, true), "and the player is told")
end)

t.test("the battleground preview prints a shared sample instead of opening chat", function()
  local sim = new("cata", {})
  local T = sim.ns.Timers
  sim:command("bg test")
  assert(T.previewing and T.foreWin:IsShown(), "preview shows the forecast")
  shiftUp(sim, T.foreWin.block)
  shiftUp(sim, T.resWin.rows[1])
  equal(sim.chatDraft, nil, "nothing reaches the chat box")
  assert(sim.messages[#sim.messages]:find("Sample, not sent: Alliance res at Stables in 12s", 1, true),
    "the sample line is printed: " .. tostring(sim.messages[#sim.messages]))
  assert(T.sampleShared, "the guide can see it")
  sim:command("bg test stop")
end)

t.test("shift-clicking a flag carrier shares the carrier or the drop", function()
  local sim = new("cata", {})
  local Flags = sim.ns.Flags
  sim:enemy("Carrier")
  sim:join(1460, 489, "Warsong Gulch")
  chat(sim, "HORDE", "The Alliance flag was picked up by Carrier!")
  sim:advance(1)
  local theirs = Flags.frows[2]
  equal(theirs.side, "theirs", "second row: the enemy carrier")
  -- The left-click macro still targets (unchanged attributes); PostClick shares.
  local function click(r, shift, down)
    sim.shift = shift
    r:GetScript("PostClick")(r, "LeftButton", down)
    sim.shift = false
  end
  click(theirs, false, false)
  click(theirs, true, true)
  equal(sim.chatDraft, nil, "a plain click, or the press of a shift-click, shares nothing")
  click(theirs, true, false)
  equal(sim.chatDraft, "/s Horde flag carrier: Carrier", "the release shares the carrier")
  sim.chatEditing, sim.chatDraft = false, nil
  click(Flags.frows[1], true, false)
  equal(sim.chatDraft, nil, "no carrier seen: nothing to share")
  chat(sim, "HORDE", "The Alliance flag was dropped by Carrier!")
  sim:advance(1)
  click(theirs, true, false)
  equal(sim.chatDraft, "/s Horde dropped the flag", "a recent drop")
end)

t.finish("Battleground sharing: " .. t.tests .. " tests")
