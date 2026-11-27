local _, ns = ...
local Core, Options, Commands, L = ns.Core, ns.Options, ns.Commands, ns.Locale

-- /hg sizes [10|15|40] [on|off]: the battleground sizes Highground runs in
-- for this character (Battlegrounds settings, Battleground sizes card).
-- A size alone toggles it; no arguments prints the current choices.
local SIZES = { ["10"] = "bg10", ["15"] = "bg15", ["40"] = "bg40" }

function Commands.sizes(arg, msg, say)
  if arg ~= "" then
    local size, state = arg:match("^(%d+)%s*(%a*)$")
    local key = SIZES[size or ""]
    if not key or (state ~= "" and state ~= "on" and state ~= "off") then
      local row = ns.CommandCatalog.byId.sizes
      return say((row[1]:gsub("|", "||")) .. "  " .. ns.CommandCatalog.Description(row))
    end
    local on = state == "on" or (state == "" and not Core.SizeEnabled(key))
    Core.SetSizeEnabled(key, on)
  end
  local names = {}
  for _, def in ipairs(Options.BATTLEGROUND_SIZES) do
    if Core.SizeEnabled(def.key) then names[#names + 1] = L:Get(def.label) end
  end
  local character = Options.CharacterName()
  if #names == 0 then
    say(L:Format("battlegrounds.sizes.status_none", { character = character }))
  else
    say(L:Format("battlegrounds.sizes.status", { character = character, sizes = table.concat(names, ", ") }))
  end
  if not Core.On("allBGs") and (Core.SizeEnabled("bg15") or Core.SizeEnabled("bg40")) then
    say(L:Get("battlegrounds.sizes.status_unrated"))
  end
end
