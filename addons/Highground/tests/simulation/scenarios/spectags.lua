local test, new, check = ...
local function equal(a, b, why) check(a, b, why or "value") end

-- Spec tags (core/SpecTags.lua, ui/SpecPicker.lua): picking an enemy's spec
-- by hand when the game hides it, sharing it with the team, and yielding to
-- specs the game identifies.

local function forever(s)
  s.env.GetBuildInfo = function() return "1.60.1", "70532", "Oct 22 2026", 16001 end
  s.env.loadstring_untainted = nil
  s.secureSnippets = false
end

local function sentOn(sim, prefix)
  local out = {}
  for _, m in ipairs(sim.sent) do
    if m.prefix == prefix then out[#out + 1] = m end
  end
  return out
end

-- Tag messages only, not the R request sent on arrival.
local function tagsSent(sim)
  local out = {}
  for _, m in ipairs(sentOn(sim, "HighgroundS")) do
    if m.message ~= "R" then out[#out + 1] = m end
  end
  return out
end

-- The pointer enters a row: its OnEnter and hooks run, as in the game.
local function hover(sim, frame)
  sim.mouseOver = frame
  if frame.scripts.OnEnter then frame.scripts.OnEnter(frame) end
  for _, hook in ipairs(frame.hooks.OnEnter or {}) do hook(frame) end
end

local function shownButtons(picker)
  local n = 0
  for _, b in ipairs(picker.buttons) do
    if b:IsShown() then n = n + 1 end
  end
  return n
end

-- One Forever match against a mage the scoreboard only names by class.
local function foreverMatch()
  local sim = new("retail", nil, forever)
  sim:enemy("Classonly")
  sim.scores[#sim.scores].talentSpec = "Mage"
  sim:join()
  sim:advance(1.5)
  local C = sim.ns.Core
  return sim, C, C.rows[1], C.rows[1].entry
end

-- A Retail match, where match messages are sent, against a mage the
-- scoreboard gives no spec.
local function retailMatch()
  local sim = new("retail")
  sim:enemy("Classonly")
  sim.scores[#sim.scores].talentSpec = ""
  sim:join()
  sim:advance(1.5)
  local C = sim.ns.Core
  return sim, C, C.rows[1].entry
end

test("WoW Forever: hovering an unidentified enemy offers its trees; a click tags the spec, kept, not sent", function()
  local sim, C, r, e = foreverMatch()
  assert(e and not e.specID, "the class name is not a spec")
  local picker = C.specPicker
  assert(not picker:IsShown(), "hidden until the row is hovered")
  hover(sim, r)
  local tip = sim.env.GameTooltip.lines
  equal(table.concat(tip, "|"), "Classonly|" .. sim.ns.Util.ClassName("MAGE") .. "|Location: at Stables (approx.)|Shift-click: call in chat",
    "the tooltip names the class without explaining the missing spec or the clicks")
  sim.ns.Test.intel[e.key] = { t = sim.env.GetTime(), how = "unknown", by = "Buddy" }
  hover(sim, r)
  equal(#sim.env.GameTooltip.lines, 3, "an enemy seen without a position gets no location line")
  assert(picker:IsShown(), "hovering the row shows the picker")
  equal(shownButtons(picker), 3, "one icon per classic talent tree")

  picker.buttons[3]:Click()
  equal(e.specSrc, "tag")
  equal(e.specID, C.classSpecs.MAGE[3], "the third tree is tagged")
  local icon = C.specInfo[e.specID].icon
  assert(icon and r.icon.texture == icon, "the row's icon shows the tagged spec")
  assert(picker.buttons[3].ring:IsShown() and not picker.buttons[1].ring:IsShown(), "the tagged icon stands out")
  equal(#sentOn(sim, "HighgroundS"), 0, "WoW Forever blocks match messages: nothing is sent")
  equal(sim.ns.Scope.Saved("specTags", "social")[e.key].tree, 3, "kept for later matches")

  picker.buttons[3]:Click()
  equal(e.specID, nil, "a second click removes the tag")
  equal(sim.ns.Scope.Saved("specTags", "social")[e.key], nil)
  equal(#sentOn(sim, "HighgroundS"), 0, "nor the removal")

  sim.mouseOver = nil
  sim:advance(0.2)
  assert(not picker:IsShown(), "leaving the row hides the picker")
  sim:assertHealthy()
end)

test("a tag outranks history and yields to a spec the game identifies", function()
  local sim = new("retail")
  sim:enemy("Frosty", { classID = 8 })
  local score = sim.scores[#sim.scores]
  score.talentSpec = "" -- not reported yet
  local C = sim.ns.Core
  local key = C.Canon("Frosty-Realm")
  sim.ns.Scope.Saved("history", "social")[key] = { class = "MAGE", spec = C.specInfo[C.classSpecs.MAGE[2]].name, t = os.time() }
  sim:join()
  sim:advance(1.5)
  local e = C.enemies[key]
  equal(e.specSrc, "hist", "history fills the gap first")
  C.SetSpecTag(e, 1)
  equal(e.specSrc, "tag", "the tag replaces older history")
  equal(e.specID, C.classSpecs.MAGE[1])
  sim:advance(2.5)
  equal(e.specSrc, "tag", "a roster refresh keeps the tag")

  score.talentSpec = C.specInfo[C.classSpecs.MAGE[3]].name
  sim:event("UPDATE_BATTLEFIELD_SCORE")
  sim:advance(2.5)
  equal(e.specSrc, "live", "the scoreboard outranks the tag")
  equal(e.specID, C.classSpecs.MAGE[3])
  hover(sim, C.rows[1])
  assert(not C.specPicker:IsShown(), "no picker once the game knows the spec")
  sim:assertHealthy()
end)

test("a spec the game draws but addons can't read keeps the picker away and the tag off", function()
  local sim = new("retail")
  sim:enemy("Frosty", { classID = 8 })
  local score = sim.scores[#sim.scores]
  score.talentSpec = ""
  sim:join()
  sim:advance(1.5)
  local C = sim.ns.Core
  local e = C.rows[1].entry
  C.SetSpecTag(e, 2)
  equal(e.specSrc, "tag", "tagged while nothing is shown")
  -- Mid-match Retail hands the row a spec it can draw but not read.
  local unreadable = setmetatable({}, { __tostring = function() return "Frost" end })
  C.plain = (function(plain) return function(v) if v == unreadable then return false end return plain(v) end end)(C.plain)
  e.specLive = unreadable
  C.ApplySpecTag(e)
  equal(e.specSrc, nil, "the tag steps aside for the game's own text")
  assert(not C.SpecTaggable(e), "no picker over a spec the game shows")
end)

test("teammates' tags apply with their name; malformed or foreign ones are ignored", function()
  local sim, C, r, e = foreverMatch()
  local function say(text, sender)
    sim:event("CHAT_MSG_ADDON", "HighgroundS", text, "INSTANCE_CHAT", sender or "Buddy-Realm")
  end
  say("1:" .. e.key .. ",PRIEST,2") -- wrong class
  say("1:" .. e.key .. ",MAGE,9") -- no such tree
  say("1:Nobody-Realm,MAGE,1") -- not in this match
  say("2:" .. e.key .. ",MAGE,1") -- unknown version
  equal(e.specID, nil, "nothing applied")
  say("1:" .. e.key .. ",MAGE,2")
  equal(e.specSrc, "tag")
  equal(e.specID, C.classSpecs.MAGE[2])
  equal(e.specBy, "Buddy", "the tagger is named")
  hover(sim, r)
  local text = table.concat(sim.env.GameTooltip.lines, "\n")
  assert(text:find("Spec tagged by Buddy", 1, true), "the tooltip names the teammate")
  say("1:" .. e.key .. ",MAGE,0")
  equal(e.specID, nil, "a teammate's removal applies too")
  sim:assertHealthy()
end)

test("a teammate's tag for an enemy the scoreboard hasn't listed applies once it does", function()
  local sim, C = foreverMatch()
  local function say(text) sim:event("CHAT_MSG_ADDON", "HighgroundS", text, "INSTANCE_CHAT", "Buddy-Realm") end
  say("1:Late-Realm,MAGE,3")
  say("1:Gone-Realm,MAGE,1")
  say("1:Gone-Realm,MAGE,0") -- removed again before the roster lists it
  say("1:Wrong-Realm,PRIEST,2")
  equal(next(sim.ns.Scope.Saved("specTags", "social")), nil, "nothing saved for enemies not in this match")
  sim:enemy("Late")
  sim:enemy("Gone")
  sim:enemy("Wrong", { classID = 8 }) -- a mage, not the priest the tag named
  sim:event("UPDATE_BATTLEFIELD_SCORE")
  sim:advance(2.5)
  local late, gone, wrong = C.enemies["Late-Realm"], C.enemies["Gone-Realm"], C.enemies["Wrong-Realm"]
  assert(late and gone and wrong, "the roster lists all three")
  equal(late.specSrc, "tag", "the early tag applies")
  equal(late.specID, C.classSpecs.MAGE[3])
  equal(late.specBy, "Buddy", "with the tagger's name")
  equal(gone.specSrc, nil, "the later removal wins")
  equal(wrong.specSrc, nil, "a tag for another class is dropped")
  sim:assertHealthy()
end)

test("early tags stay in this match and are capped", function()
  local sim, C = foreverMatch()
  local function say(text) sim:event("CHAT_MSG_ADDON", "HighgroundS", text, "INSTANCE_CHAT", "Buddy-Realm") end
  say("1:Next-Realm,MAGE,2")
  sim:leave()
  sim:join()
  for i = 1, C.EARLY_SPEC_TAGS_MAX + 5 do say("1:Many" .. i .. "-Realm,MAGE,1") end
  sim:enemy("Next")
  sim:enemy("Many1")
  sim:enemy("Many" .. (C.EARLY_SPEC_TAGS_MAX + 3))
  sim:event("UPDATE_BATTLEFIELD_SCORE")
  sim:advance(2.5)
  equal(C.enemies["Next-Realm"].specSrc, nil, "an earlier match's tag does not carry over")
  equal(C.enemies["Many1-Realm"].specSrc, "tag", "tags within the cap apply")
  equal(C.enemies["Many" .. (C.EARLY_SPEC_TAGS_MAX + 3) .. "-Realm"].specSrc, nil, "tags past the cap are not kept")
  sim:assertHealthy()
end)

test("Retail: arriving asks the group for tags; each player resends only their own", function()
  local sim, C, e = retailMatch()
  local requests = 0
  for _, m in ipairs(sentOn(sim, "HighgroundS")) do
    if m.message == "R" then requests = requests + 1 end
  end
  equal(requests, 1, "one request on arrival")
  sim:enemy("Other")
  sim.scores[#sim.scores].talentSpec = ""
  sim:event("UPDATE_BATTLEFIELD_SCORE")
  sim:advance(2.5)
  local other = C.enemies["Other-Realm"]
  C.SetSpecTag(e, 2) -- yours
  sim:event("CHAT_MSG_ADDON", "HighgroundS", "1:" .. other.key .. ",MAGE,1", "INSTANCE_CHAT", "Buddy-Realm")
  equal(other.specBy, "Buddy", "a teammate's tag")
  local before = #tagsSent(sim)
  sim:advance(11)
  sim:event("CHAT_MSG_ADDON", "HighgroundS", "R", "INSTANCE_CHAT", "Newcomer-Realm")
  local msgs = tagsSent(sim)
  equal(#msgs, before + 1, "one answer")
  equal(msgs[#msgs].message, "1:" .. e.key .. ",MAGE,2", "your tag only")
  sim:event("CHAT_MSG_ADDON", "HighgroundS", "R", "INSTANCE_CHAT", "Another-Realm")
  equal(#tagsSent(sim), before + 1, "a second request waits")
  sim:advance(11)
  equal(#tagsSent(sim), before + 2, "and is answered once at the end of the wait")
  sim:assertHealthy()
end)

test("Retail: a tag refused by chat lockdown goes out once sending is allowed", function()
  local sim, C, e = retailMatch()
  sim.chatLockdown = true
  C.SetSpecTag(e, 2)
  equal(#tagsSent(sim), 0, "held during lockdown")
  sim:advance(4)
  equal(#tagsSent(sim), 0, "still held")
  sim.chatLockdown = nil
  sim:advance(3)
  local msgs = tagsSent(sim)
  equal(#msgs, 1, "sent once")
  equal(msgs[1].message, "1:" .. e.key .. ",MAGE,2")
  sim:advance(6)
  equal(#tagsSent(sim), 1, "no repeats after delivery")
end)

test("/hg bg test tags stay in the preview: nothing saved or sent", function()
  local sim = new("retail")
  sim:command("bg test")
  local C = sim.ns.Core
  local row
  for _, r in ipairs(C.rows) do
    if r:IsShown() and r.entry and C.SpecTaggable(r.entry) then row = row or r end
  end
  assert(row, "the preview has an enemy whose spec can be tagged")
  hover(sim, row)
  assert(C.specPicker:IsShown(), "the preview offers the picker")
  C.specPicker.buttons[1]:Click()
  equal(row.entry.specSrc, "tag")
  equal(#sentOn(sim, "HighgroundS"), 0, "sample tags are never shared")
  equal(next(sim.ns.Scope.Saved("specTags", "social")), nil, "nor saved")
  sim:command("bg test")
  assert(not C.testMode, "preview stopped")
  sim:command("bg test")
  local tagged = false
  for _, r in ipairs(C.rows) do
    if r.entry and r.entry.specSrc == "tag" then tagged = true end
  end
  assert(not tagged, "a new preview starts without the old sample tags")
  sim:assertHealthy()
end)

test("WoW Forever's class-name scoreboard specs are neither saved nor kept as history", function()
  local sim, C, _, e = foreverMatch()
  local history = sim.ns.Scope.Saved("history", "social")
  history["Old-Realm"] = { class = "HUNTER", spec = "Hunter", t = os.time() }
  history["Real-Realm"] = { class = "MAGE", spec = C.specInfo[C.classSpecs.MAGE[1]].name, t = os.time() }
  C.HarvestHistory()
  equal(history[e.key], nil, "the class name is not saved as a spec")
  C.PruneHistory(history, os.time())
  equal(history["Old-Realm"], nil, "an old class-name entry is removed")
  assert(history["Real-Realm"], "a real spec stays")
end)

test("the enemy guide holds the picker open on a sample with a hidden spec", function()
  local sim = new("retail", nil, forever)
  local steps = sim.ns.Onboarding.Coach.EnemySteps()
  local step
  for _, s in ipairs(steps) do
    if s.id == "spectag" then step = s end
  end
  assert(step, "the enemy chapter has a spec tag step")
  step.enter({})
  local C = sim.ns.Core
  assert(C.specPicker:IsShown(), "the picker is open on Lunara")
  equal(step.target(), C.specPicker, "the step points at the picker")
  sim:advance(0.5)
  assert(C.specPicker:IsShown(), "it stays open without a hover")
  C.specPicker.buttons[1]:Click()
  equal(C.rows[1].entry.specSrc, "tag", "the sample can be tagged")
  equal(#sentOn(sim, "HighgroundS"), 0, "guide tags are never shared")
  equal(next(sim.ns.Scope.Saved("specTags", "social")), nil, "nor saved")
end)
