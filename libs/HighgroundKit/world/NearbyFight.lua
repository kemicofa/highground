local _, ns = ...
local Nearby = ns.Nearby
local Core, Theme, Hud, Timers, Util = ns.Core, ns.Theme, ns.Hud, ns.Timers, ns.Util

---------------------------------------------------------------------------
-- Nearby's fight mode. In an open-world group fight (core/World.lua) the
-- kill order ranks Nearby's sightings, and this list is its only panel: the
-- board stays hidden (Core.PanelWanted). Rows follow the rank instead of
-- recency, and add a rank tile on the class icon (accent on the kill
-- target), a health line and the board's eye for enemies targeting you.
-- Bindings still change out of combat only (world/Nearby.lua); each
-- kill-order tick repaints the rows shown.
---------------------------------------------------------------------------

-- In a live world fight, or in samples shown in fight mode (Battlegrounds →
-- Open world → Preview, the guide's world-fight step).
function Nearby.Fighting()
  if Nearby.test then return false end
  if Nearby.preview then return Nearby.previewFight == true end
  return ns.InWorldFight ~= nil and ns.InWorldFight()
end

-- The kill order's key for a sighting, worked out once per sighting.
local function KeyOf(e)
  local key = e.canon
  if key == nil then key = Core.Canon(e.name) or false; e.canon = key end
  return key or nil
end

-- The kill order's entry for a sighting, or nil.
local function Entry(e)
  local key = Core.enemies and KeyOf(e)
  return key and Core.enemies[key] or nil
end

local rankOf, rankByKey = {}, {} -- [sighting] / [entry key] = kill-order rank
local function Ranks()
  wipe(rankByKey)
  for i, entry in ipairs(Core.order or {}) do rankByKey[entry.key] = i end
end

local newer
-- Ranked first, by rank; the rest in the list's own order (newer).
local function ByRank(a, b)
  local ra, rb = rankOf[a], rankOf[b]
  if ra and rb then return ra < rb end
  if ra or rb then return ra ~= nil end
  return newer(a, b)
end

-- Sorts the list by kill-order rank in fight mode with Target
-- recommendations on; samples carry their own ranks. Returns whether the
-- list is in fight mode.
function Nearby.Rank(list, recent)
  wipe(rankOf)
  local fighting = Nearby.Fighting()
  if not (fighting and Core.PriorityOn()) then return fighting end
  if Nearby.preview then
    for _, e in ipairs(list) do rankOf[e] = e.fight and e.fight.rank end
  else
    Ranks()
    for _, e in ipairs(list) do
      local key = KeyOf(e)
      rankOf[e] = key and rankByKey[key]
    end
  end
  newer = recent
  table.sort(list, ByRank)
  return fighting
end

-- Health along the bottom, a rank tile over the icon's corner, an accent
-- tint on the kill target and the eye. Built on a row's first fight-mode
-- paint: most sessions never need them.
local function Parts(r)
  r.hp = CreateFrame("StatusBar", nil, r)
  Core.StatusBar(r.hp); r.hp:SetMinMaxValues(0, 1); r.hp:EnableMouse(false)
  Theme.Fill(r.hp, "BACKGROUND", "bg"):SetAllPoints()
  r.hp:Hide()
  r.killTint = Theme.Fill(r, "BORDER", "accent", "topTint")
  r.killTint:SetAllPoints(); r.killTint:Hide()
  r.rankBox = CreateFrame("Frame", nil, r)
  r.rankBox:SetFrameLevel(r:GetFrameLevel() + 2)
  r.tile = Theme.Fill(r.rankBox, "BACKGROUND", "surface")
  r.tile:SetAllPoints()
  r.rank = Theme.Text(r.rankBox, "caption", "textMuted")
  r.rank:SetPoint("CENTER")
  r.rankBox:Hide()
  r.eye = r:CreateTexture(nil, "OVERLAY")
  r.eye:SetTexture("Interface\\Icons\\Ability_EyeOfTheOwl")
  r.eye:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  r.eye:SetAlpha(0)
  Nearby.LayoutFight(r, math.max(1, Core.FontScale()))
end

-- Places the fight parts once built; returns the room the eye takes at the
-- right of the sub line, kept free either way.
function Nearby.LayoutFight(r, scale)
  local size = math.floor(14 * scale + 0.5)
  if not r.hp then return size end
  r.eye:ClearAllPoints(); r.eye:SetPoint("BOTTOMRIGHT", -6, 5); r.eye:SetSize(size, size)
  r.hp:ClearAllPoints(); r.hp:SetPoint("BOTTOMLEFT", 1, 1); r.hp:SetPoint("BOTTOMRIGHT", -1, 1)
  r.hp:SetHeight(3 * scale)
  r.rankBox:ClearAllPoints(); r.rankBox:SetPoint("BOTTOMRIGHT", r.icon, "BOTTOMRIGHT", 2, -2)
  r.rankBox:SetSize(size, size)
  return size
end

-- The time since the sighting, written again only when it changes.
function Nearby.PaintAge(r, secs)
  if r.age == secs then return end
  r.age = secs
  r.right:SetText(secs < 2 and ns.Locale:Get("shared.nearby.now.e3b820") or Util.Ago(secs))
  Theme.Paint(r.right, "text")
end

-- A row's fight details, or none outside fight mode. The time since the
-- sighting gives way to health while the enemy is in view.
function Nearby.PaintFight(r, e, now, fighting)
  local entry = fighting and not Nearby.preview and Entry(e)
  local f = fighting and (Nearby.preview and e.fight or entry) or nil
  if f and not r.hp then Parts(r) end
  local secs = math.floor(now - e.last)
  if not r.hp then return Nearby.PaintAge(r, secs) end
  local rank = f and rankOf[e]
  local kill = f and Core.PriorityOn() and (Nearby.preview and f.kill or entry ~= nil and entry == Core.killNow)
  local unit = entry and not entry.dead and entry.unit or nil
  local dead = f and f.dead
  r.rankBox:SetShown(rank ~= nil)
  if rank then
    r.rank:SetText(rank)
    Theme.Paint(r.tile, kill and "accent" or "surface")
    Theme.Paint(r.rank, kill and "onAccent" or "textMuted")
  end
  r.killTint:SetShown(kill and true or false)
  r.hp:SetShown(f ~= nil)
  if f and (unit or dead or f.hp) then
    local cc = Util.ClassColor(e.class)
    local hp, drawn = Hud.Health(r.hp, unit, dead, Nearby.preview and f.hp or nil)
    Timers.BarColor(r.hp, cc and Core.BarColor and Core.BarColor(cc, nil, hp, true) or cc or "textMuted", 1)
    Hud.HealthText(r.right, unit, hp, drawn, dead)
    r.age = nil
  else
    if f then Hud.Health(r.hp, nil, false) end
    Nearby.PaintAge(r, secs)
  end
  if f and f.onMe then
    r.eye:SetAlpha(1)
  elseif entry and entry.onMeRaw ~= nil and Core.issecret(entry.onMeRaw) and r.eye.SetAlphaFromBoolean then
    pcall(r.eye.SetAlphaFromBoolean, r.eye, entry.onMeRaw, 1, 0)
  else
    r.eye:SetAlpha(0)
  end
end

-- Every kill-order tick of a world fight (0.25 s): health, ranks and the
-- kill target of the rows shown, without rebinding them. Out of combat, a
-- row order that no longer follows the rank asks for a full update.
function Nearby.RefreshFight()
  if not (Nearby.win and Nearby.win:IsShown() and Nearby.rows and Nearby.Fighting()) then return end
  local now, ranked, last, stale = GetTime(), Core.PriorityOn() and not Nearby.preview, nil, false
  if ranked then Ranks() end
  for i = 1, Nearby.shownCount or 0 do
    local r = Nearby.rows[i]
    local e = r.who and Nearby.seen[r.who]
    if e then
      if ranked then
        local key = KeyOf(e)
        rankOf[e] = key and rankByKey[key]
        local rank = rankOf[e] or math.huge
        if last and rank < last then stale = true end
        last = rank
      end
      Nearby.PaintFight(r, e, now, true)
    end
  end
  if stale and not InCombatLockdown() and Nearby.Refresh then Nearby.Refresh() end
end
