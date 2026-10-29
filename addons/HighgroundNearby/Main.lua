local _, ns = ...
local Core, Util, Nearby = ns.Core, ns.Util, ns.Nearby

---------------------------------------------------------------------------
-- /hgn and the settings page (start-up: libs/standalone/Main.lua). The
-- list itself shows on its own in the open world (world/Nearby.lua).
---------------------------------------------------------------------------
-- Nearby.List drops the forgotten ones first.
local function Remembered() return #Nearby.List(GetTime()) end

local function Switch(on)
  Core.SetFeature("nearby", on)
  Util.Guard("nearby", Nearby.Update)
  Util.Say("nearby enemies " .. (on and "on" or "OFF"))
end

local function Preview()
  local on = ns.NearbyPreview()
  if on == nil then return Util.Say("leave combat first") end
  Util.Say("preview " .. (on and "ON: drag the list into place, /hgn test again to hide" or "off"))
end

local function Clear()
  ns.NearbyClear()
  Util.Say("nearby enemies cleared")
end

local function Forget()
  ns.NearbyHistory.Clear()
  Util.Say("enemy history forgotten")
end

ns.Standalone.Start({
  command = "HIGHGROUNDNEARBY",
  slash = { "/hgn", "/hgnearby" },
  help = {
    "/hgn: whether the list is on and how many enemies it remembers",
    "/hgn on, /hgn off: show or hide the list",
    "/hgn test: a preview to drag into place",
    "/hgn journal: searchable encounters, notes and muted enemies",
    "/hgn bounty: bounty board, contributions and claims",
    "/hgn bounty shared: opt-in realm/faction bounties",
    "/hgn clear: forget every enemy",
    "/hgn forget: forget the history of enemies you met",
    "/hgn lock: lock or unlock the list in place",
    "/hgn reset: put the list back where it started",
  },
  commands = {
    bounty = function(rest) ns.Commands.bounty(nil, "bounty " .. (rest or ""), ns.Bounty.Say) end,
    journal = function() ns.EnemyJournal.Open() end,
    on = function() Switch(true) end,
    off = function() Switch(false) end,
    test = Preview,
    clear = Clear,
    forget = Forget,
    lock = function()
      Core.db.locked = not Core.db.locked
      Util.Say("list " .. (Core.db.locked and "locked" or "unlocked"))
    end,
    reset = function()
      ns.TimersWindowReset()
      Util.Say("list position reset")
    end,
  },
  default = function()
    Util.Say("nearby enemies " .. (Core.On("nearby") and "on" or "OFF") .. " (" .. Remembered() .. " remembered)"
      .. " | /hgn on | off | test | clear | forget | help")
  end,
  settings = {
    hint = "Hostile players you have seen in the open world, most recent first. Left-click a row to target, right-click to focus.",
    keys = { "nearby", "nearbyRows", "nearbyFade", "nearbyForget", "nearbySound", "nearbyStealth", "nearbyHistory",
      "bounty", "bountyReceive", "bountyPublish", "bountyMinGold", "bountyDurationHours", "bountySound", "bountyAnnounce" },
    buttons = { { "Bounty board", function() ns.Bounty.Board.Open() end }, { "Journal", function() ns.EnemyJournal.Open() end },
      { "Preview", Preview }, { "Clear list", Clear }, { "Forget history", Forget } },
  },
})
