-- Pure Lua tests: the router has no dependency on WoW or the UI simulator.
local t = dofile("../../tools/harness.lua")("router")
local ns = {}
assert(loadfile("libs/core/Router.lua"))("test", ns)
assert(loadfile("libs/core/RouterNavigation.lua"))("test", ns)
local function new(opts)
  local r = ns.Router.New(opts)
  for _, name in ipairs({ "home", "list", "detail", "settings" }) do r:Register(name) end
  return r
end
local function equal(a, b, why) t.equal(a, b, why) end
local function history(r, names, index)
  local entries, cursor = r:History()
  local actual = {}
  for i, entry in ipairs(entries) do actual[i] = entry.name end
  equal(table.concat(actual, ","), names, "history")
  equal(cursor, index, "cursor")
end
local function failure(ok, err, code)
  equal(ok, false, "navigation rejected")
  equal(err.code, code, "failure reason")
end

t.test("registration is explicit, isolated and lazy", function()
  local r, other = new(), new()
  local entered, meta = 0, { label = "Editor" }
  r:Register("editor", { meta = meta, enter = function() entered = entered + 1 end })
  meta.label = "changed"
  equal(r:Has("editor"), true, "registered")
  equal(other:Has("editor"), false, "instances do not share routes")
  equal(pcall(function() r:Register("editor") end), false, "duplicate rejected")
  local resolved = r:Resolve({ name = "editor", params = { id = 17 }, state = false })
  equal(resolved.meta.label, "Editor", "metadata copied on registration")
  equal(resolved.state, false, "false state retained")
  equal(entered, 0, "resolve does not activate UI")
  assert(r:Navigate(resolved))
  equal(entered, 1, "entered on demand")
  equal(other:Current(), nil, "other router still empty")
end)

t.test("push, replace, back, forward and branching preserve browser history semantics", function()
  local r, actions = new(), {}
  r:On("change", function(e) actions[#actions + 1] = e.action end)
  assert(r:Navigate("home")); assert(r:Push("list")); assert(r:Navigate("detail"))
  history(r, "home,list,detail", 3)
  assert(r:Back()); assert(r:Replace("settings"))
  history(r, "home,settings,detail", 2)
  assert(r:Forward()); assert(r:Go(-2))
  assert(r:Navigate("list"))
  history(r, "home,list", 2)
  equal(r:CanGo(1), false, "new branch retires forward entries")
  equal(table.concat(actions, ","), "PUSH,PUSH,PUSH,POP,REPLACE,POP,POP,PUSH", "actions describe navigation")
  local ok, err = r:Forward(); failure(ok, err, "history_boundary")
  history(r, "home,list", 2)
end)

t.test("duplicate visits do not grow history; explicit refresh remounts", function()
  local r, visits, action = new(), 0
  r:Register("editor", { enter = function(_, _, how) visits = visits + 1; action = how end })
  assert(r:Navigate("editor")); assert(r:Navigate({ name = "editor", params = {} }))
  equal(visits, 1, "duplicate skipped")
  assert(r:Refresh())
  equal(visits, 2, "explicit refresh")
  equal(action, "REFRESH", "refresh action")
  assert(r:Navigate("editor", { refresh = true }))
  equal(visits, 3, "reopening can request a remount")
  history(r, "editor", 1)
  assert(r:Navigate({ name = "editor", params = { id = 0 }, state = { tab = "notes" } }))
  assert(r:Navigate({ name = "editor", params = { id = 0 }, state = { tab = "history" } }))
  history(r, "editor,editor,editor", 3)
  assert(r:Back())
  equal(r:Current().state.tab, "notes", "Back restores per-entry state")
end)

t.test("bounded history, reset and empty boundaries", function()
  local r = new({ limit = 2 })
  equal(r:CanGo(-1), false, "empty boundary")
  local ok, err = r:Refresh(); failure(ok, err, "history_boundary")
  assert(r:ClearHistory()); history(r, "", 0)
  assert(r:Replace("home")); assert(r:Navigate("list")); assert(r:Navigate("detail"))
  history(r, "list,detail", 2)
  assert(r:Back()); assert(r:ClearHistory())
  history(r, "list", 1)
  for _, delta in ipairs({ 0, -1, 1, 0.5, math.huge }) do
    ok, err = r:Go(delta); failure(ok, err, "history_boundary")
  end
end)

t.test("guards run in order before UI and change events", function()
  local r, order = new(), {}
  local function note(value) order[#order + 1] = value end
  r:Register("editor", { beforeLeave = function() note("leave") end })
  r:Register("preview", { beforeEnter = function() note("enter guard") end, enter = function() note("UI") end })
  assert(r:Navigate("editor"))
  r:On("before", function() note("before") end)
  r:BeforeEach(function() note("global") end)
  r:On("change", function(e) note("change"); equal(r:Current().name, e.to.name, "commit precedes event") end)
  r:On("history", function() note("history") end)
  assert(r:Navigate("preview"))
  equal(table.concat(order, ","), "before,leave,global,enter guard,UI,change,history", "lifecycle order")
end)

t.test("cancelled pushes and history traversals leave the cursor and UI untouched", function()
  local r, blocked, rendered = new(), false, 0
  r:Register("editor", { beforeLeave = function() if blocked then return false, "Unsaved draft" end end })
  r:Register("preview", { enter = function() rendered = rendered + 1 end })
  assert(r:Navigate("home")); assert(r:Navigate("editor")); assert(r:Navigate("list")); assert(r:Back())
  blocked = true
  local cancel
  r:On("cancel", function(e) cancel = e end)
  local ok, err = r:Navigate("preview"); failure(ok, err, "blocked")
  equal(err.message, "Unsaved draft", "guard reason retained")
  equal(rendered, 0, "UI unchanged")
  ok, err = r:Back(); failure(ok, err, "blocked")
  ok, err = r:Forward(); failure(ok, err, "blocked")
  equal(cancel.action, "POP", "cancel event carries attempted action")
  history(r, "home,editor,list", 2)
  blocked = false
  assert(r:Forward())
end)

t.test("route and guard redirects activate only the final destination", function()
  local r, redirects, guarded = new(), 0, 0
  r:Register("old", { redirect = function(to) return { name = "protected", params = to.params, state = to.state } end,
    beforeEnter = function() error("redirecting routes have no guard") end,
    enter = function() error("redirecting routes have no component") end })
  r:Register("protected", { beforeEnter = function(to)
    guarded = guarded + 1
    return { name = "detail", params = to.params, state = to.state }
  end })
  r:On("redirect", function(e) redirects = redirects + 1; assert(e.redirectedFrom) end)
  assert(r:Navigate("home"))
  assert(r:Navigate({ name = "old", params = { id = 42 }, state = false }))
  history(r, "home,detail", 2)
  equal(r:Current().params.id, 42, "explicit params survive redirects")
  equal(r:Current().state, false, "explicit state survives redirects")
  equal(redirects, 2, "one event per redirect")
  equal(guarded, 1, "destination guard")
  assert(r:Redirect("settings"))
  history(r, "home,settings", 2)
end)

t.test("redirects on Back replace the destination slot without adding history", function()
  local r, locked = new(), false
  r:Register("restricted", { beforeEnter = function() if locked then return "settings" end end })
  assert(r:Navigate("home")); assert(r:Navigate("restricted")); assert(r:Navigate("detail"))
  locked = true
  assert(r:Back())
  history(r, "home,settings,detail", 2)
  assert(r:Forward()); equal(r:Current().name, "detail", "forward branch preserved")
end)

t.test("redirect cycles and unbounded parameter changes fail without committing", function()
  local r = new({ maxRedirects = 3 })
  r:Register("a", { redirect = "b" }); r:Register("b", { redirect = "a" })
  r:Register("counter", { redirect = function(to) return { name = "counter", params = { n = (to.params.n or 0) + 1 } } end })
  assert(r:Navigate("home"))
  local ok, err = r:Navigate("a"); failure(ok, err, "redirect_loop")
  ok, err = r:Navigate("counter"); failure(ok, err, "redirect_limit")
  history(r, "home", 1)
  assert(r:Navigate("detail"))
end)

t.test("unknown routes and malformed data cannot enter history", function()
  local r = new()
  assert(r:Navigate("home"))
  local ok, err = r:Navigate("missing"); failure(ok, err, "unknown_route")
  local cycle = {}; cycle.self = cycle
  for _, target in ipairs({ false, {}, { name = "list", params = false }, { name = "list", state = cycle },
    { name = "list", state = function() end }, { name = "list", state = setmetatable({}, {}) },
    { name = "list", state = math.huge }, { name = "list", state = { [math.huge] = true } } }) do
    ok, err = r:Navigate(target); failure(ok, err, "invalid_target")
  end
  history(r, "home", 1)
  assert(r:Navigate("list"))
end)

t.test("deep valid locations remain readable inside history and event envelopes", function()
  local r, state, notifications = new(), {}, 0
  for _ = 1, 22 do state = { child = state } end
  r:On("change", function(e) assert(e.to.state); notifications = notifications + 1 end)
  assert(r:Navigate({ name = "detail", state = state }))
  history(r, "detail", 1)
  assert(r:Refresh())
  equal(notifications, 2, "event wrappers do not invalidate accepted data")
  local ok, err = r:Navigate({ name = "detail", state = { child = state } })
  failure(ok, err, "invalid_target")
  assert(r:Replace("home")); history(r, "home", 1)
end)

t.test("location snapshots resist mutation by callers, guards, renderers and listeners", function()
  local r, target = new(), { name = "editor", params = { id = 7 }, state = { filter = { text = "rogue" } } }
  r:Register("editor", { enter = function(to) to.params.id = 99 end })
  r:BeforeEach(function(to, from) to.state.filter.text = "guard"; if from then from.params.id = 99 end end)
  r:On("change", function(e) e.to.state.filter.text = "listener" end)
  r:On("change", function(e) equal(e.to.state.filter.text, "rogue", "listeners receive independent snapshots") end)
  local ok, location = r:Navigate(target); assert(ok)
  target.params.id, target.state.filter.text, location.params.id = 88, "caller", 100
  local entries = r:History(); entries[1].params.id = 101
  local current = r:Current(); current.state.filter.text = "reader"
  equal(r:Current().params.id, 7, "parameter is a snapshot")
  equal(r:Current().state.filter.text, "rogue", "nested state is a snapshot")
end)

t.test("guard and activation failures preserve history and allow recovery", function()
  local r, errors, cancels = new(), 0, 0
  r:On("error", function(e) errors = errors + 1; equal(e.failure.code, "callback_error", "error event") end)
  r:On("cancel", function() cancels = cancels + 1 end)
  r:Register("broken", { enter = function() error("cannot mount") end })
  r:Register("unavailable", { enter = function() return false, "missing feature" end })
  assert(r:Navigate("home"))
  local stop = r:BeforeEach(function() error("bad guard") end)
  local ok, err = r:Navigate("list"); failure(ok, err, "callback_error")
  stop(); stop()
  ok, err = r:Navigate("broken"); failure(ok, err, "callback_error")
  ok, err = r:Navigate("unavailable"); failure(ok, err, "blocked")
  history(r, "home", 1)
  equal(errors, 2, "both exceptions reported")
  equal(cancels, 3, "all failures cancel")
  assert(r:Navigate("list"))
end)

t.test("observer failures cannot undo committed navigation or suppress other listeners", function()
  local r, notifications, errors = new(), 0, 0
  r:On("change", function() error("bad observer") end)
  r:On("change", function() notifications = notifications + 1 end)
  r:On("error", function() errors = errors + 1; error("bad error observer") end)
  r:On("error", function(e) equal(e.stage, "change", "original failure retained") end)
  assert(r:Navigate("home")); assert(r:Navigate("list"))
  equal(notifications, 2, "later listeners still run")
  equal(errors, 2, "error reporting does not recurse")
  history(r, "home,list", 2)
end)

t.test("subscriptions can be removed during dispatch and additions wait", function()
  local r, seen, removeSecond, removeFirst = new(), {}
  removeFirst = r:On("change", function()
    seen[#seen + 1] = "first"; removeFirst(); removeSecond()
    r:On("change", function() seen[#seen + 1] = "new" end)
  end)
  removeSecond = r:On("change", function() seen[#seen + 1] = "removed" end)
  assert(r:Navigate("home")); equal(table.concat(seen, ","), "first", "snapshot dispatch")
  assert(r:Navigate("list")); equal(table.concat(seen, ","), "first,new", "next dispatch")
end)

t.test("nested navigation and registry mutations cannot interleave commits", function()
  local r = new()
  local stop = r:BeforeEach(function()
    local ok, err = r:Navigate("settings"); failure(ok, err, "busy")
    ok, err = r:ClearHistory(); failure(ok, err, "busy")
    ok, err = r:Unregister("settings"); failure(ok, err, "busy")
  end)
  r:On("change", function() local ok, err = r:Back(); failure(ok, err, "busy") end)
  assert(r:Navigate("home")); stop(); assert(r:Navigate("detail"))
  history(r, "home,detail", 2)
end)

t.test("unregister prunes retired entries on both sides of the cursor", function()
  local r = new()
  for _, name in ipairs({ "home", "list", "detail", "list", "settings" }) do assert(r:Navigate(name)) end
  assert(r:Go(-2))
  assert(r:Unregister("list"))
  history(r, "home,detail,settings", 2)
  local ok, err = r:Unregister("detail"); failure(ok, err, "active_route")
  assert(r:Back()); assert(r:Forward()); assert(r:Forward())
  r:Register("list")
  assert(r:Navigate("list"))
  history(r, "home,detail,settings,list", 4)
end)

t.test("capture restores independent drafts, including refreshing the active editor", function()
  local r, draft, rendered = new(), {}, 0
  r:Register("editor", {
    capture = function() return draft end,
    enter = function(to) draft = to.state or {}; rendered = rendered + 1 end,
  })
  assert(r:Navigate({ name = "editor", params = { id = 1 } }))
  draft.text = "first draft"
  assert(r:Navigate({ name = "editor", params = { id = 2 } }))
  draft.text = "second draft"
  assert(r:Back()); equal(draft.text, "first draft", "first visit restored")
  draft.text = "revised first"
  assert(r:Refresh()); equal(draft.text, "revised first", "refresh captures current edits")
  draft.text = "latest first"
  assert(r:Navigate(r:Current(), { refresh = true }))
  equal(draft.text, "latest first", "explicit remount keeps new edits")
  assert(r:Forward()); equal(draft.text, "second draft", "second visit restored independently")
  assert(r:Back()); equal(draft.text, "latest first", "latest snapshot retained")
  draft.text = "keep duplicate edits"
  assert(r:Navigate(r:Current()))
  equal(draft.text, "keep duplicate edits", "duplicate navigation never restores a stale snapshot")
  history(r, "editor,editor", 1)
  equal(rendered, 7, "all requested activations run")
end)

t.test("invalid or throwing capture leaves the route usable for recovery", function()
  local r, value = new(), { text = "valid" }
  r:Register("editor", { capture = function()
    if value == "throw" then error("cannot capture") end
    return value
  end })
  assert(r:Navigate("editor"))
  value = function() end
  local ok, err = r:Navigate("home"); failure(ok, err, "invalid_target")
  history(r, "editor", 1)
  value = "throw"
  ok, err = r:Back(); failure(ok, err, "history_boundary")
  ok, err = r:Navigate("home"); failure(ok, err, "callback_error")
  value = { text = "recovered" }
  assert(r:Navigate("home")); assert(r:Back())
  equal(r:Current().state.text, "recovered", "capture is retried after failure")
end)

t.test("reselecting a captured destination preserves its state and forward history", function()
  local r, draft, rendered = new(), {}, 0
  r:Register("editor", {
    capture = function() return draft end,
    enter = function(to) draft = to.state or {}; rendered = rendered + 1 end,
  })
  local target = { name = "editor", params = { id = 1 } }
  assert(r:Navigate(target)); draft.text = "first draft"
  assert(r:Navigate("list")); assert(r:Back())
  for _ = 1, 3 do
    draft.text = "latest draft"
    assert(r:Navigate(target))
    equal(draft.text, "latest draft", "selected tab keeps live edits")
    history(r, "editor,list", 1)
  end
  equal(rendered, 2, "reselection does not remount")
  assert(r:Navigate(target, { refresh = true }))
  equal(draft.text, "latest draft", "explicit remount captures edits")
  equal(rendered, 3, "refresh remounts once")
  assert(r:Replace(target)); history(r, "editor,list", 1)
  assert(r:Forward()); assert(r:Back())
  equal(draft.text, "latest draft", "forward and back retain the draft")
  assert(r:Navigate({ name = "editor", params = { id = 2 } }))
  equal(draft.text, nil, "different params start a new visit")
  history(r, "editor,editor", 2)
end)

t.test("redirects to the current captured destination do not erase state", function()
  local r, draft = new(), {}
  r:Register("editor", { capture = function() return draft end, enter = function(to) draft = to.state or {} end })
  r:Register("alias", { redirect = "editor" })
  assert(r:Navigate("editor")); draft.text = "keep"
  assert(r:Navigate("list")); assert(r:Back()); assert(r:Navigate("alias"))
  equal(draft.text, "keep", "alias preserves current edits")
  history(r, "editor,list", 1)
end)

t.test("explicit state and reset still replace captured state", function()
  local r, draft = new(), {}
  r:Register("editor", { capture = function() return draft end, enter = function(to) draft = to.state end })
  assert(r:Navigate({ name = "editor", state = { text = "first" } }))
  assert(r:Navigate({ name = "editor", state = {} }))
  equal(draft.text, nil, "explicit empty state clears edits")
  assert(r:Back()); equal(draft.text, "first", "explicit state creates a visit")
  assert(r:Navigate({ name = "editor", state = false }))
  equal(draft, false, "explicit false remains meaningful")
  assert(r:Back()); assert(r:Reset(r:Current()))
  history(r, "editor", 1)
  draft.text = "new edits"
  assert(r:Reset("editor"))
  equal(draft, nil, "reset does not inherit the departing state")
  draft = { text = "uncaptured edits" }
  assert(r:Reset("editor"))
  equal(draft, nil, "reset also clears edits before their first capture")
  history(r, "editor", 1)
  assert(r:Reset({ name = "editor", state = { text = "requested" } }))
  local target = r:Current()
  draft.text = "changed locally"
  assert(r:Navigate(target, { restoreState = true }))
  equal(draft.text, "requested", "explicit restoration honors the requested snapshot")
  history(r, "editor,editor", 2)
  assert(r:Back()); equal(draft.text, "changed locally", "restoration still captures the departure")
  assert(r:Forward()); equal(draft.text, "requested", "restored state remains in history")
end)

t.test("reset respects guards and retirement cannot revive closed dialogs", function()
  local r, blocked = new(), true
  r:Register("editor", { beforeLeave = function() return not blocked end })
  assert(r:Navigate("home")); assert(r:Navigate("editor"))
  local ok, err = r:Reset("settings"); failure(ok, err, "blocked")
  history(r, "home,editor", 2)
  blocked = false
  assert(r:Reset("settings")); history(r, "settings", 1)
  assert(r:Navigate("editor")); assert(r:Navigate("detail"))
  assert(r:Forget("editor")); equal(r:Has("editor"), true, "registration survives retirement")
  history(r, "settings,detail", 2)
  assert(r:Back()); assert(r:TrimForward()); history(r, "settings", 1)
  equal(r:CanGo(1), false, "closed branch is gone")
  assert(r:Navigate("editor")); history(r, "settings,editor", 2)
  assert(r:Reset("editor")); history(r, "editor", 1)
end)

t.finish("Router: " .. t.tests .. " tests, " .. t.checks .. " checks, " .. t.failures .. " failures")
