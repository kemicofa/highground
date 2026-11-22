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

function Bounty.Sound()
  -- New files need a client restart before PlaySoundFile finds them.
  if ns.BOUNTY_SOUND_FALLBACK or not PlaySoundFile(Bounty.SOUND, "Master") then Util.AlertSound() end
end

function Bounty.PlaySound()
  if Core.On("sound") and Core.O("bountySound") then Bounty.Sound() end
end

-- Explicit previews show local visuals even when live alerts are filtered.
-- Sound still follows the user's alert settings; no group chat is sent.
function Bounty.PreviewSound()
  if not ns.Alerts or ns.Alerts.Allowed("bounty", "sound") then Bounty.PlaySound() end
end

function Bounty.Announce(b, where, preview, unit)
  local from = b.state == "personal" and "yours" or (ns.Locale:Format("shared.alerts.from_value2.498fa1", { value2 = Core.DisplayName(b.by or "?") }))
  if b.state == "public" then
    from = Bounty.Contributions(#b.contributions, ns.Locale:Get(b.imported and "bounty.contribution.imported" or "bounty.contribution.funds"))
  end
  local text = ns.Locale:Format("shared.alerts.bounty_value1_value2_from.d1b19d", { value1 = string.format("%s", Core.DisplayName(b.name)), value2 = string.format("%s", b.gold > 0 and (Gold(b) .. ", ") or ""), from = string.format("%s", from) })
  if preview then text = ns.Locale:Format("shared.alerts.preview_text.e2eadc", { text = text }) end
  if not preview and ns.NearbyHistory and ns.NearbyHistory.Muted and ns.NearbyHistory.Muted(b.name) then return end
  local function Show()
  if preview or Core.O("bountyAnnounce") then
    Bounty.Poster.Show(b, where, unit, preview)
  end
  Say(text .. (where and (ns.Locale:Format("shared.alerts.in_where.7bb010", { where = where })) or "") .. (b.note and (": " .. b.note) or ""))
  local chan = not preview and Core.O("bountyTellGroup") and ns.Comms.GroupChannel()
  if chan and SendChatMessage then
    pcall(SendChatMessage, ns.Locale:Format("shared.alerts.value2_bounty_target_spotted_value4_value6.50e2e9", { value2 = (ns.LABEL or "Highground"), value4 = Core.DisplayName(b.name), value6 = Gold(b) }), chan)
  end
  end
  if preview then Show(); Bounty.PreviewSound()
  elseif Util.Notify then Util.Notify("bounty", b.name, text, Bounty.PlaySound, Show)
  else Bounty.PlaySound(); Show() end
end

function Bounty.AnnounceShared(b, preview)
  local text = ns.Locale:Format("bounty.shared.alert", { preview = preview and ns.Locale:Get("shared.alerts.preview.da0c76") or "",
    name = Core.DisplayName(b.name), gold = Util.Gold(b.gold), contributions = Bounty.Contributions(#b.contributions) })
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
local NONE = {}
function Bounty.ScanRosters()
  if not Bounty.Enabled() then return end
  for key, e in pairs(ns.IsActive() and ns.enemies or NONE) do
    Bounty.Spot(key, e.class)
  end
  local Arena = ns.Arena
  if Arena and Arena.InArena and Arena.InArena() then
    for _, seen in pairs(Arena.seen or NONE) do
      if seen.full or seen.name then Bounty.Spot(seen.full or seen.name, seen.class) end
    end
  end
end

-- Guild messages (bounty/Sync.lua events).
function Bounty.OnChanged(b, from, was, preview)
  if not preview and not Bounty.Enabled() then return end
  local function Tell(text) Say((preview and ns.Locale:Get("shared.alerts.preview.da0c76") or "") .. text) end
  local who, target = Core.DisplayName(from), Core.DisplayName(b.name)
  if b.state == "removed" then
    if was and was ~= "removed" then
      Tell(ns.Locale:Format("shared.alerts.who_value2_the_bounty_on_target.d842bd", { who = who, value2 = (was == "pending" and ns.Locale:Get("shared.alerts.rejected.4a5650") or ns.Locale:Get("shared.alerts.removed.136c16")), target = target }))
    end
  elseif not preview and Bounty.syncing then
    Bounty.synced = (Bounty.synced or 0) + 1
  elseif b.state == "pending" then
    Tell(ns.Locale:Format("shared.alerts.value1_submitted_value3_on_target_approve_or.36ca2b", { value1 = Core.DisplayName(b.by or from), value3 = Amount(b), target = target, Bounty_CMD = Bounty.CMD }))
  elseif was == "pending" then
    Tell(ns.Locale:Format("shared.alerts.who_approved_value3_on_target.7d4bf1", { who = who, value3 = Amount(b), target = target }))
  else
    Tell(ns.Locale:Format("shared.alerts.value1_value2_on_target_from_value6_value7.df530e", { value1 = (b.organization and (ns.Locale:Format("shared.alerts.value1_bounty.0c6b78", { value1 = Bounty.Organizations.Label(b) })) or ns.Locale:Get("shared.alerts.guild_bounty.885384")), value2 = Amount(b), target = target, value6 = Core.DisplayName(b.by or "?"), value7 = (b.note and (": " .. b.note) or "") }))
  end
end

function Bounty.OnShared(b, from, zone)
  b.seenAt, b.seenZone, b.seenBy = time(), zone ~= "" and zone or nil, from
  if Bounty.Enabled() then
    Say(ns.Locale:Format("shared.alerts.value1_sees_value3_value5_value7.063c8e", { value1 = Core.DisplayName(from), value3 = Core.DisplayName(b.name), value5 = Gold(b), value7 = (zone ~= "" and (ns.Locale:Format("shared.alerts.in_zone.55c718", { zone = zone })) or "") }))
  end
end

function Bounty.OnClaim(b, from)
  if not Bounty.Enabled() then return end
  local mine = b.by == Bounty.Me()
  Say(ns.Locale:Format("shared.alerts.value1_killed_value3_value5_value7.25c300", { value1 = Core.DisplayName(from), value3 = Core.DisplayName(b.name), value5 = Gold(b), value7 = (mine and ns.Locale:Get("shared.alerts.review_the_claim_in_bounty_board_claims.527ef3") or "") }))
end

Bounty.Listen("changed", function(...) Bounty.OnChanged(...) end)
Bounty.Listen("shared", function(...) Bounty.OnShared(...) end)
Bounty.Listen("claimed", function(...) Bounty.OnClaim(...) end)

-- Sync replies arrive over a few seconds after joining: summarize them once.
function Bounty.SummarizeSync(now)
  if not (Bounty.syncing and now - Bounty.syncing > Bounty.REPLY_DELAY[2] + 4) then return end
  if (Bounty.synced or 0) > 0 and Bounty.Enabled() then
    Say(ns.Locale:Format("shared.alerts.bounty_synced_guild_bounties_received_bounty_cmd.11afcd", { Bounty_synced = Bounty.synced, Bounty_CMD = Bounty.CMD }))
  end
  Bounty.syncing, Bounty.synced = nil, nil
end

-- Chat feedback for a reported kill. Kills.lua owns detection and claims.
function Bounty.OnKilled(b, message, preview)
  Say(ns.Locale:Format("shared.alerts.value1_you_killed_value3_value4.5bfd91", { value1 = (preview and ns.Locale:Get("shared.alerts.preview.da0c76") or ""), value3 = Core.DisplayName(b.name), value4 = (message and (": " .. message) or b.state == "personal" and "" or
      (ns.Locale:Format("shared.alerts.value2_from_value4.50ed0b", { value2 = Gold(b), value4 = Core.DisplayName(b.by or "?") }))) }))
end

function Bounty.OnCombatLog()
  Bounty.Kills.CombatLog()
end
