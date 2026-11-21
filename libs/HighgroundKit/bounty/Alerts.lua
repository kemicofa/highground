local ADDON, ns = ... -- ADDON: this addon's folder name
local Core, Bounty = ns.Core, ns.Bounty

---------------------------------------------------------------------------
-- Bounty alerts: sightings from nameplates (bounty/Marks.lua), target,
-- focus, mouseover, battleground and arena rosters. A target seen again after
-- `bountyRealert` seconds out of sight alerts again: sound, wanted poster,
-- optionally a line to your group. Sightings.lua shares observed locations
-- with the bounty's audience. Also reports guild bounty
-- messages (bounty/Sync.lua events) in chat.
---------------------------------------------------------------------------
-- This addon's src/sounds (ns.SOUNDS); Highground imports src/ as features/bounties.
Bounty.SOUND = (ns.SOUNDS or ("Interface\\AddOns\\" .. ADDON .. "\\features\\bounties\\sounds\\")) .. "bounty.ogg"
Bounty.ICON = "Interface\\Icons\\INV_Misc_Coin_01"
Bounty.ICON_CROP = { 0.08, 0.92, 0.08, 0.92 } -- trims the icon border
Bounty.SHARE_GAP = 60 -- seconds between shared sightings of one target

Bounty.seen = {} -- [key] = { last, shared }
local Util, M = ns.Util, Bounty.Messages
local Call, Plain = Util.call, Util.value
local Gold, Amount = M.Gold, M.Amount

function Bounty.Enabled()
  return Core.db ~= nil and Core.On("bounty")
end

function Bounty.Say(text)
  return Util.Say(text, "bounty")
end
local Say = Bounty.Say

function Bounty.Where()
  local inside, kind = Call(IsInInstance)
  if kind == "arena" then return "arena" end
  if kind == "pvp" then return "battleground" end
  return inside and "instance" or "world"
end

function Bounty.PlaySound()
  if not (Core.On("sound") and Core.O("bountySound")) then return end
  -- New files need a client restart before PlaySoundFile finds them.
  if ns.BOUNTY_SOUND_FALLBACK or not PlaySoundFile(Bounty.SOUND, "Master") then Util.AlertSound() end
end

-- Explicit previews show local visuals even when live alerts are filtered.
-- Sound still follows the user's alert settings; no group chat is sent.
function Bounty.PreviewSound()
  if not ns.Alerts or ns.Alerts.Allowed("bounty", "sound") then Bounty.PlaySound() end
end

function Bounty.Announce(b, where, preview, unit)
  local from = b.state == "personal" and "yours" or ("from " .. Core.DisplayName(b.by or "?"))
  if b.state == "public" then from = #b.contributions .. (b.imported and " contributors; imported offer, funds unverified" or " contributors; funds reported available") end
  local text = string.format("BOUNTY: %s (%s%s)", Core.DisplayName(b.name), b.gold > 0 and (Gold(b) .. ", ") or "", from)
  if preview then text = "[PREVIEW] " .. text end
  if not preview and ns.NearbyHistory and ns.NearbyHistory.Muted and ns.NearbyHistory.Muted(b.name) then return end
  local function Show()
  if preview or Core.O("bountyAnnounce") then
    Bounty.Poster.Show(b, where, unit, preview)
  end
  Say(text .. (where and (" in " .. where) or "") .. (b.note and (": " .. b.note) or ""))
  local chan = not preview and Core.O("bountyTellGroup") and ns.Comms.GroupChannel()
  if chan and SendChatMessage then
    pcall(SendChatMessage, "[" .. (ns.LABEL or "Highground") .. "] Bounty target spotted: "
      .. Core.DisplayName(b.name) .. " (" .. Gold(b) .. ")", chan)
  end
  end
  if preview then Show(); Bounty.PreviewSound()
  elseif Util.Notify then Util.Notify("bounty", b.name, text, Bounty.PlaySound, Show)
  else Bounty.PlaySound(); Show() end
end

function Bounty.AnnounceShared(b, preview)
  local text = (preview and "[PREVIEW] " or "") .. "Shared bounty: " .. Core.DisplayName(b.name) .. " — " .. Util.Gold(b.gold)
    .. " with funds reported available (" .. #b.contributions .. " contributions)."
  if preview then Say(text); Bounty.PreviewSound(); Bounty.Matches.Show(b, true)
  else Util.Notify("bounty", "public:" .. Bounty.Key(b.name), text, Bounty.PlaySound, function() Say(text) end) end
end

-- A sighting of a name (class token when known). Quiet: record it without
-- alerting (the target you just put a bounty on). Returns the bounty when
-- this one alerted.
function Bounty.Spot(name, class, quiet, unit)
  if not Bounty.Enabled() then return nil end
  if Bounty.Sightings then Bounty.Sightings.Observe(name, unit) end
  local b = Bounty.Find(name, true)
  if not b then return nil end
  local zone = Util.ZoneName()
  b.class = type(class) == "string" and class or b.class
  b.seenAt, b.seenZone, b.seenBy = time(), zone, Bounty.Me()
  local key, now = b.name:lower(), GetTime()
  local s = Bounty.seen[key]
  local fresh = not s or now - s.last > Core.O("bountyRealert")
  s = s or {}
  s.last = now
  s.unit = unit or s.unit
  Bounty.seen[key] = s
  if unit then Bounty.Portraits.Capture(b.name, unit) end
  local where = Bounty.Where()
  if quiet then return nil end
  Bounty.Poster.Observe(b, unit)
  if where == "world" and b.state == "approved" and Core.O("bountyShare") and now - (s.shared or -math.huge) > Bounty.SHARE_GAP then
    s.shared = now
    Bounty.Send("1:S," .. Util.Clean(b.name) .. "," .. Util.Clean(zone))
  end
  if fresh then
    Bounty.Announce(b, where == "world" and zone or where, false, unit)
    return b
  end
end

function Bounty.IsOtherPlayer(unit)
  return Plain(Call(UnitIsPlayer, unit)) and not Plain(Call(UnitIsUnit, unit, "player"))
end

-- Players that alert: those you can attack, or any other player with
-- bountyAnyPlayer (unflagged on a normal realm, or same faction).
function Bounty.Watched(unit)
  return Bounty.IsOtherPlayer(unit)
    and (Core.O("bountyAnyPlayer") or Plain(Call(UnitCanAttack, "player", unit))) and true or false
end

-- Quiet sightings (your target when you add a bounty) skip the attack check.
function Bounty.SpotUnit(unit, quiet)
  if not (quiet and Bounty.IsOtherPlayer(unit) or Bounty.Watched(unit)) then return nil end
  local key = Core.CanonUnit(unit)
  local _, class = Call(UnitClass, unit)
  return key and Bounty.Spot(key, Plain(class), quiet, unit)
end

-- Your target is in sight when you add a bounty on it: record it, no alert.
Bounty.Listen("added", function(b)
  if UnitExists("target") and Core.CanonUnit("target") == b.name then Bounty.SpotUnit("target", true) end
end)

-- Rosters already gathered by other panels (battleground and arena).
function Bounty.ScanRosters()
  if not Bounty.Enabled() then return end
  for key, e in pairs(ns.IsActive() and ns.enemies or {}) do
    Bounty.Spot(key, e.class)
  end
  local Arena = ns.Arena
  if Arena and Arena.InArena and Arena.InArena() then
    for _, seen in pairs(Arena.seen or {}) do
      if seen.full or seen.name then Bounty.Spot(seen.full or seen.name, seen.class) end
    end
  end
end

-- Guild messages (bounty/Sync.lua events).
function Bounty.OnChanged(b, from, was, preview)
  if not preview and not Bounty.Enabled() then return end
  local function Tell(text) Say((preview and "[PREVIEW] " or "") .. text) end
  local who, target = Core.DisplayName(from), Core.DisplayName(b.name)
  if b.state == "removed" then
    if was and was ~= "removed" then
      Tell(who .. (was == "pending" and " rejected" or " removed") .. " the bounty on " .. target)
    end
  elseif not preview and Bounty.syncing then
    Bounty.synced = (Bounty.synced or 0) + 1
  elseif b.state == "pending" then
    Tell(Core.DisplayName(b.by or from) .. " submitted " .. Amount(b) .. " on " .. target
      .. ": approve or reject it on the bounty board (" .. Bounty.CMD .. ")")
  elseif was == "pending" then
    Tell(who .. " approved " .. Amount(b) .. " on " .. target)
  else
    Tell((b.organization and (Bounty.Organizations.Label(b) .. " bounty: ") or "guild bounty: ") .. Amount(b) .. " on " .. target .. " from " .. Core.DisplayName(b.by or "?")
      .. (b.note and (": " .. b.note) or ""))
  end
end

function Bounty.OnShared(b, from, zone)
  b.seenAt, b.seenZone, b.seenBy = time(), zone ~= "" and zone or nil, from
  if Bounty.Enabled() then
    Say(Core.DisplayName(from) .. " sees " .. Core.DisplayName(b.name) .. " (" .. Gold(b) .. ")"
      .. (zone ~= "" and (" in " .. zone) or ""))
  end
end

function Bounty.OnClaim(b, from)
  if not Bounty.Enabled() then return end
  local mine = b.by == Bounty.Me()
  Say(Core.DisplayName(from) .. " killed " .. Core.DisplayName(b.name) .. " (" .. Gold(b) .. ")"
    .. (mine and ": review the claim in Bounty board > Claims" or ""))
end

Bounty.Listen("changed", function(...) Bounty.OnChanged(...) end)
Bounty.Listen("shared", function(...) Bounty.OnShared(...) end)
Bounty.Listen("claimed", function(...) Bounty.OnClaim(...) end)

-- Sync replies arrive over a few seconds after joining: summarize them once.
function Bounty.SummarizeSync(now)
  if not (Bounty.syncing and now - Bounty.syncing > Bounty.REPLY_DELAY[2] + 4) then return end
  if (Bounty.synced or 0) > 0 and Bounty.Enabled() then
    Say(Bounty.synced .. " guild bounties received (" .. Bounty.CMD .. ")")
  end
  Bounty.syncing, Bounty.synced = nil, nil
end

-- Chat feedback for a reported kill. Kills.lua owns detection and claims.
function Bounty.OnKilled(b, message, preview)
  Say((preview and "[PREVIEW] " or "") .. "you killed " .. Core.DisplayName(b.name)
    .. (message and (": " .. message) or b.state == "personal" and "" or
      (": " .. Gold(b) .. " from " .. Core.DisplayName(b.by or "?"))))
end

function Bounty.OnCombatLog()
  Bounty.Kills.CombatLog()
end
