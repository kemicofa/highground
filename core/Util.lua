local _, ns = ...

-- Helpers shared by every subsystem. No dependencies, so it loads before
-- core/State.lua and isolated test fixtures can load it alone.
local Util = {}
ns.Util = Util

-- Midnight returns secret values for enemy data; they must not be compared
-- or used as table keys. Looked up per call: the global is client-only.
function Util.secret(v)
  return issecretvalue ~= nil and issecretvalue(v) or false
end

-- True for a readable, non-nil value.
function Util.plain(v)
  return v ~= nil and not Util.secret(v)
end

-- The value when readable, otherwise nil.
function Util.value(v)
  if Util.plain(v) then return v end
end

-- pcall that returns the results, or nothing when fn is missing or errors.
function Util.call(fn, ...)
  if type(fn) ~= "function" then return end
  local ok, a, b, c, d, e, f = pcall(fn, ...)
  if ok then return a, b, c, d, e, f end
end

-- First result of Util.call when readable.
function Util.read(fn, ...)
  return Util.value((Util.call(fn, ...)))
end

-- "A" or "H": the battleground faction (from core), else the character's.
function Util.MyTeam()
  local f = ns.GetAllyFaction and ns.GetAllyFaction()
  if f == 1 then
    return "A"
  elseif f == 0 then
    return "H"
  end
  return UnitFactionGroup("player") == "Alliance" and "A" or "H"
end

function Util.ClassColor(class)
  local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
  return colors and class and colors[class]
end
