local _, ns = ...
local A, U, Core = ns.Arena, ns.Util, ns.Core
local call, plain = U.call, U.value

function A.SpecIcon(info)
  if not info then return end
  if info.specIcon then return info.specIcon end
  local byName = info.class and Core.specByName[info.class]
  local spec = byName and Core.specInfo[byName[info.spec]]
  if spec then return spec.icon end
  for _, entry in pairs(A.specCatalog) do
    if entry.class == info.class and entry.name == info.spec then return entry.icon end
  end
end

-- Keep identification details in the tooltip, not a redundant text row.
function A.SpecLabel(info)
  return info and info.spec
end

-- Specs the arena announces before the gates.
function A.RememberSpec(info, index)
  if not A.InArena() then return end
  local id = U.read(GetArenaOpponentSpec, index)
  if type(id) ~= "number" or id <= 0 then return end
  local _, name, _, icon, _, class = call(GetSpecializationInfoByID, id)
  name, icon, class = plain(name), plain(icon), plain(class)
  if type(name) == "string" and name ~= "" and (not info.class or not class or info.class == class) then
    info.specID, info.spec, info.specIcon, info.class = id, name, icon, info.class or class
  end
end
