local F = {}
F.names = { "Battlegrounds", "Arena", "Nearby", "Bounties", "Reputation", "Macros" }

function F.configure(disabled, legacy, missing, standalones)
  return function(s, e)
    s.moduleStates, s.moduleWrites, s.moduleWork = {}, {}, {}
    s.standaloneCopies, s.standaloneReads = standalones or {}, 0
    for _, name in ipairs(F.names) do
      s.moduleStates["HighgroundModule" .. name] = not (disabled and disabled[name:lower()])
    end
    local originalMetadata = e.C_AddOns.GetAddOnMetadata
    e.C_AddOns.GetAddOnMetadata = function(name, key)
      if key == "Title" and name:match("^Highground") and not name:match("^HighgroundModule") and name ~= "Highground" then
        s.standaloneReads = s.standaloneReads + 1
        if s.standaloneCopies[name] ~= nil then return name end
      end
      if s.moduleStates[name] ~= nil and not (missing and missing[name]) and key == "X-Highground-Module" then
        return name:sub(#"HighgroundModule" + 1):lower()
      end
      return originalMetadata(name, key)
    end
    local function state(name, character)
      assert(character ~= nil and character ~= 0 and character ~= "0", "never query all characters")
      return s.moduleStates[name] and 2 or 0
    end
    local function change(name, character, enabled)
      assert(character ~= nil and character ~= 0 and character ~= "0", "never change all characters")
      assert(s.moduleStates[name] ~= nil, "only change the requested bundled module")
      s.moduleStates[name] = enabled
      s.moduleWrites[#s.moduleWrites + 1] = { name = name, character = character, enabled = enabled }
    end
    if legacy then
      e.GetAddOnMetadata = e.C_AddOns.GetAddOnMetadata
      e.GetAddOnEnableState = function(character, name) return state(name, character) end
      e.EnableAddOn = function(name, character) change(name, character, true) end
      e.DisableAddOn = function(name, character) change(name, character, false) end
    else
      e.C_AddOns.GetAddOnEnableState = state
      e.C_AddOns.EnableAddOn = function(name, character) change(name, character, true) end
      e.C_AddOns.DisableAddOn = function(name, character) change(name, character, false) end
    end
    e.ReloadUI = function() s.reloads = (s.reloads or 0) + 1 end
    local load = s.load
    function s:load(path)
      load(self, path)
      if path == "libs/core/Events.lua" then
        local run = self.ns.Util.RunGuarded
        self.ns.Util.RunGuarded = function(stage, fn, ...)
          self.moduleWork[stage] = (self.moduleWork[stage] or 0) + 1
          return run(stage, fn, ...)
        end
      end
    end
    dofile("../../tools/wowsim/geometry.lua")(s)
  end
end
return F
