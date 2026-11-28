local _, ns = ...
local Core, Commands, L = ns.Core, ns.Commands, ns.Locale

-- /hg sizes [10|15|40|world] [on|off] | copy SIZE… | preview: the size the
-- Battlegrounds settings edit (the size bar on those pages). A size alone
-- selects it; with on|off it switches where Highground runs.
local SIZES = { ["10"] = "bg10", ["15"] = "bg15", ["40"] = "bg40", world = "world" }

local function Status(say)
  local CS, names = ns.CharacterSettings, {}
  for _, scope in ipairs(CS.SCOPES) do
    if Core.SizeEnabled(scope) then names[#names + 1] = CS.Label(scope) end
  end
  say(L:Format("sizes.status.editing", { size = CS.Label(CS.Editing()) }))
  say(#names == 0 and L:Get("sizes.status.none") or L:Format("sizes.status.runs", { sizes = L:List(names) }))
end

local function Usage(say)
  local row = ns.CommandCatalog.byId.sizes
  say((row[1]:gsub("|", "||")) .. "  " .. ns.CommandCatalog.Description(row))
end

function Commands.sizes(arg, msg, say)
  local CS = ns.CharacterSettings
  local first, rest = arg:match("^(%S*)%s*(.-)$")
  if first == "" then return Status(say) end
  if first == "preview" then
    local ok, problem = CS.TogglePreview()
    return say(not ok and problem or L:Get(CS.Previewing() and "sizes.preview.started" or "sizes.preview.stopped"))
  end
  if first == "copy" then
    local targets, any = {}, false
    for word in rest:gmatch("%S+") do
      if not SIZES[word] then return Usage(say) end
      targets[SIZES[word]], any = true, true
    end
    if not any then return Usage(say) end
    local count = CS.CopyScope(targets)
    return say(L:Format("sizes.copy.done", { size = CS.Label(CS.Editing()), count = count }))
  end
  local scope = SIZES[first]
  if not scope or (rest ~= "" and rest ~= "on" and rest ~= "off") then return Usage(say) end
  if rest ~= "" then
    Core.SetSizeEnabled(scope, rest == "on")
    if rest == "on" and scope == "world" and not Core.On("nearby") then Core.SetFeature("nearby", true) end
    if ns.Options.RefreshScopeBars then ns.Options.RefreshScopeBars() end
    return Status(say)
  end
  if not CS.Select(scope) then return say(L:Format("sizes.locked", { size = CS.Label(CS.Locked()) })) end
  Status(say)
end
