# UI routing

[Documentation](README.md) · [Development](development.md)

HighgroundKit provides `ns.Router`, a synchronous Lua 5.1 router for named UI destinations. Highground and all six standalone UI addons load it. The hub, feature pages, guides and ordinary dialog return paths use the same library.

The library loads from `libs/core/Router.lua`, then `libs/core/RouterNavigation.lua`, before its consumers in every UI TOC. It has no WoW API dependencies, creates no frames and installs no timers. Storage-only companion addons do not load UI services.

## Adoption across Highground

| Surface | Router and behavior |
| --- | --- |
| Main hub | `ns.Hub.GetRouter()`: sidebar, settings pages, shortcuts and custom components. Header Back/Forward first traverse the active feature's history, then the hub's history. |
| Settings groups | `ns.Options.general.frame.navigation`: the Panels and features menu uses named group routes. Hub Back/Forward restores the group, expanded controls and scroll position. |
| Bounties | `ns.Bounty.Navigation.GetRouter()`: My bounties, Guild & communities, Shared board, Suggestions, editor, claims, alert preferences and suggestion reports. Page buttons, review filters and help use this router; claim selections share its history. History captures each draft, query, page and scroll position. Sample boards use an independent router with the same behavior. |
| Macros | `ns.Macros.Window.GetRouter()`: catalog tabs, PvP/PvE/ranks modes and individual editors. Captures form options, manually edited code, destination, filters and scroll positions. The feature uses `Macros.Host.Router`. |
| Reputation | `ns.Reputation.UI.GetRouter()`: organizations, blacklist, proposals, members, history, settings and pagination. Restores organization/filter/page; disabled organizations redirect to Organizations. |
| Browsers | `frame.navigation`: journal entries, match history, macro backups and import reviews. Row and page buttons use guarded routes, restoring query, selection and detail scroll. Fresh import reviews and sample claims reset their history. |
| Guides and samples | `ns.Onboarding.GetRouter()`, `ns.Onboarding.Coach.router` and `ns.Bounty.Preview.GetRouter()`: chapters and sample steps; sample exit discards its history. |
| Ordinary dialogs | `ns.Kit.Windows.router`: one coordinator shared by all loaded addon copies. Editors, details, imports, reviews and settings dialogs return through registered window routes. |

`Kit.AttachNavigation(dialog, router)` adds Back/Forward to the shared header and exposes `dialog.navigation` to the hub. These controls are separate from header actions. Compact hosted macro editors use the hub controls.

`Kit.Browser` creates an independent router by default. A feature can pass `router` and `route` to join a registered page, as Claims & payments does. The route's `capture` calls `frame:CaptureNavigation()`; its `enter` mounts the browser and calls `frame:RestoreNavigation(to.state)`. Use `frame:Select(key)` or `frame:GoPage(delta)` for programmatic navigation, and `frame:ResetNavigation()` when replacing a review session. Search edits and scrolling remain local UI state captured when leaving a visit.

Opening a primary tool resets the window coordinator's history. Opening a `Kit.Dialog` with `child = true` pushes a return path; closing or Escape returns to its owner and removes the closed forward branch. Completing a review can call `Kit.Windows.Close(hiddenEditor)` to retire that editor. `Kit.Windows.Forget(frame)` discards stale return paths during a data-scope change. Legacy `Show`/`Hide` calls are observed by the coordinator, so existing commands and buttons use the router too.

Feature Back/Forward preserves drafts without saving or publishing them. Explicit **Back to board**, save and discard actions retire the editor history. Bounty scope changes clear feature history; history is never serialized to SavedVariables. Native Blizzard windows and gameplay HUD visibility retain their game-owned lifecycles.

## Register a hub component

Call this after addon initialization, when the hub's settings pages are available:

```lua
local Hub = ns.Hub
local detail
Hub.RegisterRoute("enemy.detail", {
  label = "Enemy details",
  frame = function(to)
    -- Build lazily; reuse the frame and restore selection on Back/Forward.
    detail = detail or BuildEnemyDetails()
    detail:SetEnemy(to.params.name)
    return detail
  end,
  beforeLeave = function(to, from)
    if detail and detail:HasUnsavedChanges() then
      return false, "Save or discard the note first."
    end
  end,
})

Hub.Navigate({ name = "enemy.detail", params = { name = "Rival-Realm" } })
Hub.Back()
Hub.Forward()
Hub.Redirect("journal") -- replace the current entry
```

`BuildEnemyDetails`, `SetEnemy` and `HasUnsavedChanges` represent your component's functions. The factory receives the location every time it is entered, including history traversal. It should return an unshown, ordinary UI frame and let the hub present it. Return `nil` if the component is unavailable; the previous page and history remain selected.

The hub handles parenting, anchors, close buttons, dragging, transitions and returning the frame to its original parent. Register only ordinary UI pages here; secure gameplay frames keep their existing combat rules. Registration makes a page addressable from any shortcut; permanent sidebar placement remains in `hub/Hub.lua`'s `LAYOUT` and `Hub.Sections`.

`Hub.GetRouter()` initializes and returns the hub router. `Hub.Navigate` uses exact route names. Existing `Hub.Open`, `Hub.Show` and `/hg config` also accept case-insensitive sidebar labels and settings page names, with Home as the fallback for a removed saved page. Reopening the hub remounts its current page without adding a duplicate history entry. `Hub.RegisterRoute(name, { redirect = target })` also supports aliases implemented as redirects.

## Use an independent router

```lua
local router = ns.Router.New({ limit = 50, maxRedirects = 16 })
router:Register("list", {
  enter = function(to, from, action)
    ShowList(to.state) -- your UI owns how components are mounted
  end,
})
router:Register("detail", {
  meta = { label = "Details" },
  beforeEnter = function(to)
    if not FindEntry(to.params.id) then return "list" end
  end,
  enter = function(to)
    ShowDetails(to.params.id, to.state)
  end,
  capture = function() return { note = detail.note:GetText() } end,
})
router:Register("old-list", { redirect = "list" })

router:Navigate("list")
router:Navigate({ name = "detail", params = { id = 42 }, state = { tab = "notes" } })
```

A location is `{ name, params, state, meta }`. `params` defaults to `{}`; `state` is optional per-visit data, such as a selected tab or filter. `meta` comes from the registered route. Store identifiers and ordinary data, rather than frames or live model references. Data may contain strings, finite numbers, booleans and plain tables with string/number keys; functions, userdata, metatables, cycles and nesting deeper than 24 tables are rejected. `false` and zero are preserved.

Inputs, callback arguments, returned locations and history reads are independent copies. Mutating them cannot rewrite history. Callbacks should return a redirect to change a destination instead of changing their `to` argument.

## API

Instance methods use `:`. Navigation methods return `true, location` on success or `false, failure` on refusal. A failure has `code` and `message` fields.

| Method | Behavior |
| --- | --- |
| `Router.New({ limit, maxRedirects })` | New empty router. Defaults: 50 entries, 16 redirects per navigation. Both limits must be positive integers. |
| `Register(name, definition)` | Register a unique, case-sensitive name; returns the router for chaining. Duplicate names and invalid definitions raise errors. |
| `Has(name)` | Whether the name is registered. |
| `Unregister(name)` | Remove an inactive route and its history entries, adjusting the cursor. Returns `false, failure` for an active/unknown route or during navigation. |
| `Forget(name)` | Remove an inactive route's visits while keeping its registration. Same failure cases as `Unregister`. |
| `Resolve(target)` | Validate and copy a name/location without running UI, redirects, guards or events. Returns `location` or `nil, failure`. |
| `Navigate(target, { replace, refresh, restoreState })` / `Push(...)` | Push a destination; optional `replace = true` overwrites the current slot. `refresh = true` remounts an identical destination. `restoreState = true` honors supplied state even when it matches the last snapshot of a visit whose UI has since changed. |
| `Replace(target)` / `Redirect(target)` | Replace the current slot; create the first entry if history is empty. |
| `Reset(target)` | Navigate through guards, then replace all history with the accepted destination. Failure preserves the existing history and cursor. |
| `Back()` / `Forward()` / `Go(delta)` | Move by a nonzero integer offset. Guards still run. Out-of-range offsets return `history_boundary`. |
| `CanGo(delta)` | Whether that offset exists. This does not run guards or promise they will accept it. |
| `Refresh()` | Enter the current location again without adding history. |
| `Current()` | Copy of the current location, or `nil`. |
| `History()` | Copies of the entries, plus the 1-based cursor (0 when empty). |
| `ClearHistory()` | Keep only the current location; an empty router stays empty. Does not remount UI. |
| `TrimForward()` | Retire every entry after the cursor, keeping current and earlier visits. |
| `BeforeEach(fn)` | Register a global navigation guard; returns an idempotent unsubscribe function. |
| `On(event, fn)` | Subscribe to an event; returns an idempotent unsubscribe function. |

Route definitions accept `enter`, `capture`, `beforeEnter`, `beforeLeave`, `redirect` and `meta`. Navigation callbacks receive `(to, from, action)`; `from` is `nil` on the first navigation. `enter` owns presentation and runs after all guards, before history commits. Return `false, reason` to refuse entry. Validate availability before changing visible UI: the router can retain its history after an exception, but cannot undo arbitrary side effects in your component code.

Optional `capture(from)` returns the current UI's plain state before navigation or refresh. The router validates and copies it into the current visit, even when a subsequent guard cancels leaving. Back/Forward restores the destination's saved state through `enter`. `Refresh()` captures the latest edits before remounting; `Navigate(router:Current(), { refresh = true })` does the same. A capture exception or invalid state cancels navigation. Capture should only read UI, without business actions or navigation.

List controls that supply an explicit selection or page use `Navigate(target, { restoreState = true })`. The departure is still captured, but cannot replace the requested state merely because it matches an older snapshot. This matters after search or data updates have changed the visible selection. Ordinary tab reselection retains the default behavior of resuming live UI state.

## Guards and redirects

The router captures the departing visit first, when configured. The order for a destination is then: `before` event, current route's `beforeLeave`, global `BeforeEach` guards in registration order, destination's `beforeEnter`, `enter`, history commit, `change` event, `history` event. `beforeLeave` runs when the name, params or state change, including updates to the same component. `beforeEnter` and global guards also run on refresh.

Guards return:

- `nil` or `true` to continue.
- `false, reason` to cancel, retaining the current destination and cursor (including its freshly captured state).
- A name or location to redirect. Guards are evaluated again for the destination.

A route's `redirect` may be a name, location or function receiving `(to, from, action)`. Redirecting routes do not run their own guards or `enter`; only the final route is entered. Return explicit params/state to preserve them across a redirect:

```lua
router:Register("old-detail", {
  redirect = function(to)
    return { name = "detail", params = to.params, state = to.state }
  end,
})
```

Redirects commit only the final destination. A redirect during Back/Forward replaces that destination's history slot and preserves the forward branch. Cycles and chains exceeding `maxRedirects` are cancelled. An identical name, params and state is a successful no-op, unless refreshing or traversing history. Navigating or redirecting to the current name and params with state omitted preserves its captured state and forward history. Supply explicit state (such as `{}` to clear it) to create a distinct visit. `Reset` always uses the supplied destination state, even when the name and params match the current route.

Callbacks are synchronous and cannot yield. Navigation or registry mutations from inside a callback cannot interleave the active transition: navigation returns `busy`; registering raises an error. Redirect from guards by returning a location. A confirmation UI can cancel immediately, then retry navigation after the player answers.

## Events

```lua
local stop = router:On("change", function(event)
  UpdateSelectedPage(event.to.name)
end)
local stopHistory = router:On("history", function()
  backButton:SetEnabled(router:CanGo(-1))
  forwardButton:SetEnabled(router:CanGo(1))
end)
-- On disposal:
stop()
stopHistory()
```

| Event | Payload and timing |
| --- | --- |
| `before` | `{ to, from, action }` before each resolved destination is evaluated. Observational; use a guard to cancel. |
| `redirect` | `{ to, from, redirectedFrom, action }` for each redirect step. |
| `change` | `{ to, from, action }` after successful entry and history commit, including refresh. |
| `history` | Same payload after a successful transition; also emitted after clearing, trimming or forgetting history, or unregistering a route. |
| `cancel` | `{ to, from, action, failure, stage }` when capturing, resolving, guarding or entering fails. `to` can be absent for invalid targets. |
| `error` | Same failure payload for a thrown callback error. Observer errors are reported without undoing committed navigation. |

Navigation actions are `PUSH`, `REPLACE`, `POP`, `REFRESH` and `RESET`. History maintenance adds `CLEAR`, `REMOVE` and `TRIM`. Duplicate no-ops, unavailable history offsets and reentrant `busy` calls emit no events. Common failure codes are `unknown_route`, `invalid_target`, `blocked`, `redirect_loop`, `redirect_limit`, `invalid_redirect`, `callback_error`, `busy`, `history_boundary` and `active_route`.

Listeners receive separate snapshots. Removing a listener during dispatch takes effect immediately; new listeners start with the next dispatch. One listener's exception does not prevent later listeners from running. Errors are also recorded through `Util.Guard` when that service is available; failures inside an `error` listener do not recursively emit more errors.

## Why this fits Highground

Highground already hosts many settings and feature windows. A shared router removes navigation's dependency on sidebar button lookup, restores previous destinations consistently and gives editors a place to guard unsaved changes. Features can add parameterized detail pages without building their own history stack.

The design borrows named locations, redirects and guards from [Vue Router's named routes](https://router.vuejs.org/guide/essentials/named-routes.html), [redirects](https://router.vuejs.org/guide/essentials/redirect-and-alias.html) and [navigation guards](https://router.vuejs.org/guide/advanced/navigation-guards.html). Its bounded in-memory history and push/replace/pop actions draw on [React Router's memory router](https://reactrouter.com/api/data-routers/createMemoryRouter) and [navigation types](https://reactrouter.com/api/hooks/useNavigationType). These are design references; no JavaScript runtime or dependency is bundled.

There is no browser URL, path-pattern matcher, nested outlet system or asynchronous data loader. History lasts for the UI session; the hub continues saving only its last section name across reloads. Components own their data and rendering, and secure combat rules still govern protected game actions.

## Validation

From `addons/Highground`:

```sh
luajit tests/router_test.lua
luajit tests/simulation_test.lua router
luajit tests/ui_navigation_test.lua
```

The pure tests cover history semantics, capture, retirement, guards, redirects, malformed locations, failures, listener cleanup and state isolation. Integration scenarios exercise the hub and standalone features on Retail, Cata and Forever: drafts, filters, mode changes, nested dialogs, organization redirects, scope cleanup, combat, custom routes and reopening. `ui_navigation_test.lua` also runs from HighgroundBounties, HighgroundNearby and HighgroundMacros; Reputation has `tests/navigation_test.lua`. Run `bash tests/run.sh` from the repository root for all addon and packaging checks.
