local _, ns = ...
local O, Core = ns.Onboarding, ns.Core
local C = O.Coach

local function Visible(frame) return frame and frame:IsVisible() and frame end
local function Panel()
  return Visible(Core.frame) or Visible(ns.Flags.flagWin) or Visible(ns.Timers.resWin)
    or Visible(ns.QuickCalls and ns.QuickCalls.win)
end
local function Gear()
  for _, w in ipairs(ns.PanelControls.windows) do if Visible(w.gear) then return w.gear end end
  return Panel()
end

local function Placement()
  return {
    { id = "panel", title = "Make room for the fight", target = Panel,
      text = "These are your actual panels with sample data. Put them somewhere you can glance at without hiding the center of the fight. The arrow follows the panel as it moves." },
    { id = "place", title = "Try moving a panel", target = function() return Visible(Core.frame) and Core.head.bg or Panel() end,
      observe = Panel, event = "OnDragStop",
      text = "Drag the highlighted header to reposition its panel. Your chosen position is kept. Other panels can be moved by their headers too." },
    { id = "controls", title = "Find the panel controls", target = Gear, event = "OnEnter",
      text = "Hover the cogwheel to read its shortcuts. In play, click it for lock/unlock, quick controls and the relevant settings. These are real controls: changes you make here are kept." },
    { id = "finish", title = "Return to your normal layout", target = Panel,
      text = "Done removes the samples and restores your previous lock setting. Your chosen panel positions are kept." },
  }
end

local function Objectives()
  return {
    { id = "resurrection", title = "Your next resurrection", target = function() return ns.Timers.resWin.rows[1] end, event = "OnEnter",
      feature = "timers", settingLabel = "Enable battleground timers in game",
      text = "YOU marks your graveyard: Stables here. The clock shows the next resurrection wave. Hover for its source." },
    { id = "estimate", title = "~ means an estimate", target = function() return ns.Timers.resWin.rows[3] end,
      text = "THEIRS is the enemy wave; OURS is another friendly graveyard. -- means the timer is unknown." },
    { id = "capture", title = "A base is changing hands", target = function() return ns.Timers.objWin.rows[2] end, event = "OnEnter",
      feature = "objectives", settingLabel = "Enable objective timers in game",
      text = "CAP is the countdown after a base is assaulted. CAPPING marks an observed attempt to capture it." },
    { id = "score", title = "Plan around the score", target = function() return ns.Timers.objWin.rows[1] end,
      text = "WIN estimates the result from the current score and base ownership. It changes as bases change hands." },
    { id = "carrier", title = "Find the enemy flag carrier", target = function() return ns.Flags.frows[2] end, event = "OnEnter",
      feature = "flags", settingLabel = "Enable flag carrier panel in game",
      text = "ENEMY marks Vexa, the opposing carrier. ALLY is your carrier. In play, left-click targets a known carrier; right-click focuses." },
  }
end

local function Arena()
  local function Duel() return ns.Arena.DuelMode() end
  return {
    { id = "opponents", title = "Meet your opponents", target = function() return ns.Arena.win end,
      feature = "arena", settingLabel = "Enable Arena & duels in game",
      text = function() return Duel() and "This sample shows a duel opponent. The panel appears at a challenge or countdown, then clears when the duel ends."
        or "These sample arena opponents show the panel used in a match. Slot labels identify each opponent. Duels use the same panel with one opponent." end },
    { id = "row", title = "Target now, keep a focus for later", target = function() return ns.Arena.rows[1] end, event = "OnEnter",
      text = "Left-click targets this opponent; right-click focuses them. A focus lets you keep watching one enemy while selecting another. Combat clicks remain bound to the same opponent." },
    { id = "health", title = "Read the available information", target = function() return ns.Arena.rows[1].bar end,
      text = "The health bar and row details show what your client provides. Casts and crowd control appear when available. Missing information stays unknown; it is never treated as zero health." },
    { id = "status", title = function() return Duel() and "Follow the duel" or "Watch the escape trinket" end,
      target = function() return Duel() and ns.Arena.rows[1] or ns.Arena.rows[1].trinket end,
      text = function() return Duel() and "The status follows the challenge, countdown and fight. Changing your current target keeps the same opponent in the duel panel."
        or "The trinket icon uses client-reported escape information. A question mark means timing is unavailable, not that the trinket is ready. Available cooldowns show on the icon." end },
    { id = "finish", title = "Keep your attention on the fight", target = function() return ns.Arena.win end,
      text = "The panel follows the activity and clears when the duel or arena ends. Done clears these example opponents. Move the header while unlocked if you need a better position." },
  }
end

function C.PanelSteps(context, chapter)
  if context == "world" then return C.NearbySteps() end
  if context == "arena" then return Arena() end
  if chapter == "objectives" then return Objectives() end
  return Placement()
end

-- History is the same browser used outside the tour, with isolated records.
function C.NearbySteps()
  local N, Nearby, B = C.Native, ns.Nearby, ns.Bounty
  local data = C.nearbySample or {}; C.nearbySample = data
  data.records = {
    ["Sneakypete-Sample"] = { class = "ROGUE", level = 60, zone = "Tarren Mill", guild = "Night Watch",
      times = 3, killedThem = 1, killedMe = 2, first = time() - 86400, last = time() - 1 },
    ["Holyhands-Sample"] = { class = "PRIEST", zone = "Hillsbrad Foothills", times = 1,
      killedThem = 0, killedMe = 0, first = time() - 3600, last = time() - 300 },
  }
  data.entries = function()
    local entries = {}
    for key, record in pairs(data.records) do
      entries[#entries + 1] = { key = key, title = Core.DisplayName(key, true), class = record.class,
        record = record, summary = record.zone, search = key .. " " .. record.zone .. " " .. (record.note or "") }
    end
    table.sort(entries, function(a, b) return a.record.last > b.record.last end)
    return entries
  end
  data.bounty = function(entry)
    if ns.Modules and not ns.Modules.Active("bounties") then
      return false, "Enable Bounties on the Addons page, then reload, to use this part of the guide."
    end
    B.Preview.StartGuided(nil, "create"); N.bountyOwned = true
    local w = B.Form.Open(entry.key, "personal", nil, true)
    N.Track(w); C.BountySample.Fit(w)
    return true, "Sample bounty opened; your real records stay unchanged."
  end
  local function History()
    local w = ns.EnemyJournal.Build(data)
    w:Open(); N.Track(w); N.Fit(w)
    return w
  end
  local function Panel()
    if data.win then ns.Kit.Windows.Close(data.win) end
    if not ns.Setup.placement then ns.Setup.BeginPlacement(true) end
    Nearby.guide = { history = History }
    ns.Setup.PreviewContext("world")
    Nearby.preview = true; Nearby.Update()
  end
  local function Context() return data.win end
  local function Form()
    local w = B.Form.previewWin
    if not (N.bountyOwned and w and w:IsVisible()) then data.bounty(data.entries()[1]); w = B.Form.previewWin end
    return w
  end
  local steps = {
    { id = "nearby", title = "A fresh sighting", text = "Sneakypete was just observed. In play, left-click targets and right-click focuses this enemy.",
      enter = Panel, target = function() return Nearby.rows[1] end, context = function() return Nearby.win end,
      feature = "nearby", settingLabel = "Enable Nearby panel in game" },
    { id = "memory", title = "Faded means last seen earlier", text = "Holyhands is an older sighting. Being on this list does not prove the enemy is still nearby.",
      enter = Panel, target = function() return Nearby.rows[3] end, context = function() return Nearby.win end },
    { id = "sound", title = "Choose whether Nearby makes a sound", text = "This button toggles sighting and stealth sounds. Your global alert settings still apply.",
      enter = Panel, target = function() return Nearby.win.sound end, context = function() return Nearby.win end,
      hint = "This is your real sound preference." },
    { id = "history", title = "Open the encounter history", text = "History keeps enemies after they leave the nearby list. Click History below the sightings.",
      enter = Panel, target = function() return Nearby.win.history end, context = function() return Nearby.win end,
      advance = function() return data.win and data.win:IsVisible() end, requireAction = true, hint = "Click History." },
    { id = "record", title = "Read the selected enemy's history", text = "The record shows encounters, kills, deaths and last known location. Search finds names, locations and notes.",
      enter = History, target = function() return data.win.profile and data.win.profile.stats end, context = Context },
    { id = "note", title = "Keep a private reminder", text = "Edit note adds your own reminder. Mute alerts quiets this player's alerts without deleting the record.",
      enter = History, target = function() return data.win.actions[1] end, context = Context,
      hint = "These are sample records; trying the actions leaves your real journal unchanged." },
    { id = "bounty", title = "Add a bounty from this enemy record", text = "Select the enemy, then click Add bounty. Their name carries into the bounty form.",
      enter = History, target = function() return data.win.actions[3] end, context = Context,
      requireAction = true, advance = function() return N.bountyOwned and B.Form.previewWin:IsVisible() end, hint = "Click Add bounty." },
    { id = "bounty_name", title = "The selected name is already filled in", text = "Check the name, choose who should see the bounty and enter the reward. This is the real bounty form with sample data.",
      enter = function() Form().fields:Scroll(0) end, target = function() return B.Form.previewWin.name end,
      context = function() return B.Form.previewWin end, hint = "The Bounties guide covers posting, tracking and claims." },
  }
  if ns.Modules and not ns.Modules.Active("bounties") then
    for i = #steps, 1, -1 do
      if steps[i].id:match("^bounty") then table.remove(steps, i) end
    end
    steps[#steps].hint = "Bounties is disabled. Enable it on Addons and reload to try adding a bounty."
  end
  return steps
end
