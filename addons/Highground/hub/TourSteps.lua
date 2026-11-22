local _, ns = ...
local O = ns.Onboarding
local function page(label, key, group, review)
  return { label = label, page = key, group = group, review = review }
end
local function native(key) return { label = "Open guide", native = key } end
local function loaded(key) return function() return ns[key] ~= nil end end

-- Independent entry points, not a course that must be completed in order.
-- Highground bundles these modules; standalone folder names are not required.
O.aliases = { targeting = "enemies" }
O.steps = {
  { key = "enemies", module = "battlegrounds", label = "Highground", logo = "Highground", summary = "Enemy rows, target markers and status labels.", feature = "killorder",
    actions = { native("enemies"), page("Enemy appearance", "battlegrounds-appearance") } },
  { key = "macros", module = "macros", label = "Macros", logo = "Macros", summary = "Try a macro, then put it on an action bar.", available = loaded("Macros"),
    actions = { native("macros"), page("Open macros", "macros") } },
  { key = "bounties", module = "bounties", label = "Bounties", logo = "Bounties", summary = "Post a reward or hunt a target. Choose your path.", available = loaded("Bounty"),
    paths = { "bounty_post", "bounty_hunt" },
    actions = { { label = "Choose a path", paths = true }, page("Open bounty board", "bountyboard") } },
  { key = "bounty_post", module = "bounties", parent = "bounties", label = "Post a bounty", caption = "Bounties · Post",
    summary = "Create a reward, review claims and record payment.", available = loaded("Bounty"),
    actions = { { label = "Start posting guide", bounties = "post" } } },
  { key = "bounty_hunt", module = "bounties", parent = "bounties", label = "Hunt a bounty", caption = "Bounties · Hunt",
    summary = "Track a target and follow its automatic kill report.", available = loaded("Bounty"),
    actions = { { label = "Start hunting guide", bounties = "hunt" } } },
  { key = "battlegrounds", module = "battlegrounds", label = "Battlegrounds", logo = "Battlegrounds", summary = "Resurrection waves, captures and flag carriers.", available = loaded("Timers"),
    actions = { { label = "Try it", preview = "objectives" }, page("Battleground previews", "battlegrounds-previews"), page("Battleground settings", "battlegrounds-settings", "Battleground", "features") } },
  { key = "nearby", module = "nearby", label = "Nearby", logo = "Nearby", summary = "Fresh sightings, faded sightings and enemy history.", available = loaded("Nearby"), feature = "nearby",
    actions = { native("nearby"), page("Open enemy history", "journal") } },
  { key = "arena", module = "arena", label = "Arena & duels", logo = "Arena", summary = "Target, focus and keep track of your opponent.", available = loaded("Arena"), feature = "arena",
    actions = { { label = "Try it", preview = "arena" } } },
  { key = "reputation", module = "reputation", label = "Reputation", logo = "Reputation", summary = "Report a player and review a guild decision.", available = loaded("Reputation"),
    actions = { native("reputation"), page("Open player reputation", "reputation") } },
  { key = "map", module = "battlegrounds", label = "Enemy map", summary = "Try enemy sightings on Warsong Gulch.", extra = true, available = loaded("Intel"),
    actions = { { label = "Try Warsong Gulch", map = true }, page("Map settings", "battlegrounds-settings", "Map and sharing", "features") } },
  { key = "callouts", module = "battlegrounds", label = "Quick callouts", summary = "Try the buttons used during battlegrounds.", extra = true, feature = "quickCalls",
    actions = { { label = "Try it", quickCalls = true }, page("Battleground settings", "battlegrounds-settings", "Battleground", "features") } },
  { key = "records", label = "History & notes", summary = "Find an encounter and leave yourself a note.", extra = true,
    actions = { native("records"), page("Open match history", "history"), page("Open enemy journal", "journal") } },
  { key = "features", label = "Appearance", summary = "Preview real panels while adjusting their appearance.", extra = true,
    actions = { native("features"), page("Choose panels", "battlegrounds-settings", nil, "features"), page("Shared appearance", "appearance") } },
  { key = "alerts", label = "Alerts & sounds", summary = "Hear sample sounds and choose your warnings.", extra = true,
    actions = { native("alerts"), page("Choose alerts", "alerts", nil, "alerts") } },
  { key = "profile", label = "Saved setups", summary = "Review settings, save a setup and choose when it loads.", extra = true,
    actions = { native("profile"), page("Open profiles", "profiles", nil, "profile") } },
  { key = "panels", module = "battlegrounds", label = "Move panels", summary = "Drag sample panels into position.", extra = true,
    actions = { { label = "Move panels", preview = "bg" }, page("Playstyle presets", "setup", nil, "panels") } },
  { key = "addons", label = "Addon controls", summary = "Choose which addons run, find their commands and learn when to reload.", extra = true,
    actions = { native("addons"), page("All commands and controls", "tools") } },
  { key = "users", label = "Addon users", summary = "Read channel membership, version reports and discovery status.", extra = true,
    actions = { native("users"), page("Open addon users", "users") } },
}

function O.Available(step) return not step.available or step.available() end
function O.Guides(extra)
  local result = {}
  for _, step in ipairs(O.steps) do
    if not step.parent and not not step.extra == not not extra and O.Available(step) then result[#result + 1] = step end
  end
  return result
end

function O.PathGroup()
  local step = O.Current()
  return step.paths and step or step.parent and O.Find(step.parent)
end

function O.Paths(group)
  local result = {}
  for _, key in ipairs(group.paths) do
    local step = O.Find(key)
    if step and O.Available(step) then result[#result + 1] = step end
  end
  return result
end
