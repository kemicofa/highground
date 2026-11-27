local _, ns = ...
local Core = ns.Core
local Read, Call = ns.Util.read, ns.Util.call

---------------------------------------------------------------------------
-- The icon each group member shows: the leader's hand mark, else the
-- leader's automatic rule, else none (core/TeamIcons.lua). "class" gives
-- everyone their class icon. "role" gives Tank, Healer, Melee or Caster
-- from what this client knows: the group role, team healers
-- (core/HealerTags.lua), a known spec, else the class when all its damage
-- specs are melee or all ranged; mixed classes get no icon. Each client
-- applies the rule to its whole group, strangers in a battleground too.
-- Automatic icons take the next free outline colours in name order, so
-- clients agree. Rebuilt after a change; never per frame.
---------------------------------------------------------------------------
local resolved, dirty = {}, true
local units, auto, used, counts = {}, {}, {}, {}

function Core.InvalidateTeamIcons() dirty = true end

-- "melee" or "caster" when every damage spec of the class is one of them.
local reach = {}
local function ClassReach(class)
  local specs = Core.classSpecs[class]
  if not specs or #specs == 0 then return end
  if reach[class] == nil then
    local melee, ranged = false, false
    for _, id in ipairs(specs) do
      local info, p = Core.specInfo[id], ns.Specs and ns.Specs[id]
      local role = info and info.role
      if role ~= "TANK" and role ~= "HEALER" and not (p and p.healer) then
        if p and p.melee then melee = true else ranged = true end
      end
    end
    reach[class] = melee ~= ranged and (melee and "melee" or "caster") or false
  end
  return reach[class] or nil
end

local function SpecRole(spec)
  local info, p = Core.specInfo[spec], ns.Specs and ns.Specs[spec]
  if not (info or p) then return end
  if info and info.role == "TANK" then return "tank" end
  if info and info.role == "HEALER" or p and p.healer then return "healer" end
  return p and p.melee and "melee" or "caster"
end

local function RoleIcon(unit, key, class)
  if Read(UnitGroupRolesAssigned, unit) == "TANK" then return "tank" end
  if Core.TeamHealer(unit, key) then return "healer" end
  local spec
  if key == Core.TeamKey("player") then
    spec = Core.me and Core.me.specID
  else
    local tag = Core.HealerTag(key)
    spec = tag and tag.spec
  end
  return spec and SpecRole(spec) or class and ClassReach(class)
end

local function AutoIcon(rule, unit, key)
  local _, class = Call(UnitClass, unit)
  class = Core.plain(class) and type(class) == "string" and class or nil
  if rule == "class" then return class and Core.ValidTeamIcon(class) and class or nil end
  return RoleIcon(unit, key, class)
end

local function ByKey(a, b) return a.key < b.key end

-- The next outline colour for an icon: the lowest one free, else in turn.
local function NextColor(icon)
  local taken = used[icon]
  if not taken then taken = {}; used[icon] = taken end
  local n = #Core.TEAM_ICON_COLORS
  local color = 1
  while taken[color] and color <= n do color = color + 1 end
  if color > n then color = (counts[icon] or 0) % n + 1 end
  taken[color], counts[icon] = true, (counts[icon] or 0) + 1
  return color
end

-- out[key] = { icon, color, auto } for members, a list of { key, auto }:
-- a hand mark in marks wins, else auto (the rule's icon, or nil). Shared
-- by the live group and the sample window.
function Core.ResolveTeamIcons(out, marks, list)
  wipe(out); wipe(used); wipe(counts)
  local n = 0
  for _, member in ipairs(list) do
    local m = marks[member.key]
    if m then
      if m.icon ~= "none" then
        out[member.key] = m
        local taken = used[m.icon] or {}
        used[m.icon], taken[m.color or 1] = taken, true
        counts[m.icon] = (counts[m.icon] or 0) + 1
      end
    elseif member.auto then
      n = n + 1
      local a = auto[n] or {}
      auto[n], a.key, a.icon = a, member.key, member.auto
    end
  end
  for i = #auto, n + 1, -1 do auto[i] = nil end
  table.sort(auto, ByKey)
  for i = 1, n do
    local a = auto[i]
    out[a.key] = { icon = a.icon, color = NextColor(a.icon), auto = true }
  end
  return out
end

-- Player key -> { icon, color, auto } for every group member with an icon.
local members = {}
function Core.TeamIconsResolved()
  if not dirty then return resolved end
  dirty = false
  if not Core.db then wipe(resolved); return resolved end
  local rule, n = Core.TeamIconRule(), 0
  for _, unit in ipairs(Core.TeamUnits(units)) do
    local key = Core.CanonUnit(unit)
    if key then
      n = n + 1
      local member = members[n] or {}
      members[n], member.key, member.auto = member, key, rule and AutoIcon(rule, unit, key) or nil
    end
  end
  for i = #members, n + 1, -1 do members[i] = nil end
  return Core.ResolveTeamIcons(resolved, Core.TeamIconMarks(), members)
end

-- Roles and specs change the "role" icons.
ns.Util.Events({
  PLAYER_SPECIALIZATION_CHANGED = function() if Core.TeamIconRule() == "role" then Core.TeamIconsChanged() end end,
  ROLE_CHANGED_INFORM = function() if Core.TeamIconRule() == "role" then Core.TeamIconsChanged() end end,
}, "team icon rules", "battlegrounds")
