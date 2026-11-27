local _, ns = ...
local Core, P = ns.Core, ns.Options.Profiles

---------------------------------------------------------------------------
-- Battleground layouts: a whole setup (P.Snapshot) per battleground size,
-- per character. Entering a size with a layout loads it; leaving saves the
-- changes made there (Remember changes) and brings back the setup from
-- before the match, unless Automatic switching has a profile for the new
-- place. Layouts live account-wide, keyed by character GUID, so another
-- character can copy them: HighgroundDB.sizeLayouts[guid] =
-- { name, class, bg10 = { snap, saved }, ... }. The applied size and the
-- setup to restore are per character: HighgroundCharDB.sizeLayout =
-- { bracket, stash = { snap, activeProfile, importedProfileName } }.
---------------------------------------------------------------------------
local Layouts = {}
P.Layouts = Layouts

-- The character's GUID; its name only while the game has no GUID yet.
function Layouts.Key()
  local guid = UnitGUID and UnitGUID("player")
  if type(guid) == "string" and guid ~= "" then return guid end
  local name = UnitName and UnitName("player")
  return type(name) == "string" and name ~= "" and "name:" .. name or nil
end

local function Store() return ns.Saved.Table(Core.db, "sizeLayouts") end

-- A character's entry; nil without one. create adds this character's.
function Layouts.Entry(key, create)
  key = key or Layouts.Key()
  if not key or not Core.db then return nil end
  local entry = type(Core.db.sizeLayouts) == "table" and Core.db.sizeLayouts[key]
  if type(entry) ~= "table" then
    if not create then return nil end
    entry = {}
    Store()[key] = entry
  end
  return entry
end

function Layouts.Get(bracket, key)
  local entry = Layouts.Entry(key)
  local layout = entry and entry[bracket]
  return type(layout) == "table" and type(layout.snap) == "table" and layout or nil
end

function Layouts.Save(bracket, snap)
  if not Core.SIZE_KEYS_SET[bracket] then return false end
  local entry = Layouts.Entry(nil, true)
  if not entry then return false end
  entry.name = Core.me.name or UnitName("player")
  entry.class = Core.me.class or select(2, UnitClass("player"))
  entry[bracket] = { snap = snap or P.Snapshot(), saved = time() }
  return true
end

-- Other characters with at least one layout, by name.
function Layouts.Characters()
  local own, list = Layouts.Key(), {}
  for key, entry in pairs(type(Core.db.sizeLayouts) == "table" and Core.db.sizeLayouts or {}) do
    if key ~= own and type(entry) == "table" and type(entry.name) == "string" then
      for _, bracket in ipairs(Core.SIZE_KEYS) do
        if Layouts.Get(bracket, key) then list[#list + 1] = { key = key, name = entry.name, class = entry.class }; break end
      end
    end
  end
  table.sort(list, function(a, b) return a.name < b.name end)
  return list
end

function Layouts.Remember() return not (Core.pos and Core.pos.rememberLayouts == false) end
function Layouts.SetRemember(on) Core.pos.rememberLayouts = on and true or false end

-- The size whose layout is applied now, or nil.
function Layouts.Active()
  local state = Core.pos and Core.pos.sizeLayout
  return type(state) == "table" and Core.SIZE_KEYS_SET[state.bracket] and state.bracket or nil
end

local function Load(snap, fields)
  local prepared = P.Prepare(snap)
  if not prepared then return false end
  for key, value in pairs(fields or {}) do prepared[key] = value end
  P.Apply(prepared)
  return true
end

-- The live setup is the layout unless its switch still waits for combat.
local function Applied() return not (P.pending and P.pending.sizeLayout) end

local function Leave(state, save)
  if save and Layouts.Remember() and Applied() then Layouts.Save(state.bracket) end
  if P.pending and P.pending.sizeLayout then P.pending = nil end
  Core.pos.sizeLayout = nil
  P.lastAssignment = nil
end

local function Restore(stash)
  if type(stash) ~= "table" then return end
  Load(stash.snap, { profileName = stash.activeProfile, importedProfileName = stash.importedProfileName })
end

-- Whether Automatic switching loads a profile here, so nothing is restored.
local function Assigned()
  if not Core.pos.autoProfiles then return false end
  local who, context = P.Context()
  local assignments = Core.db.profileAssignments and Core.db.profileAssignments[who]
  local name = assignments and assignments[context]
  return name ~= nil and Core.db.profiles and Core.db.profiles[name] ~= nil
end

-- Called by P.Automatic before profile assignments. true while a layout
-- is applied, so assignments leave the battleground alone.
function Layouts.Update()
  if not (Core.db and Core.pos) or Core.testMode then return Layouts.Active() ~= nil end
  local state = type(Core.pos.sizeLayout) == "table" and Core.pos.sizeLayout or nil
  local bracket = Core.CurrentBracket and Core.CurrentBracket()
  local target = bracket and Core.SizeEnabled(bracket) and Layouts.Get(bracket) and bracket or nil
  if state and state.bracket == target then return true end
  local stash = state and state.stash
  if state then Leave(state, true) end
  if target then
    stash = stash or { snap = P.Snapshot(), activeProfile = Core.db.activeProfile, importedProfileName = Core.db.importedProfileName }
    Core.pos.sizeLayout = { bracket = target, stash = stash }
    Load(Layouts.Get(target).snap, { sizeLayout = target })
    return true
  end
  if stash and not Assigned() then Restore(stash) end
  return false
end

-- Removing the layout in use puts the setup from before the match back.
function Layouts.Remove(bracket)
  local entry = Layouts.Entry()
  if not (entry and entry[bracket]) then return false end
  local state = Core.pos.sizeLayout
  if type(state) == "table" and state.bracket == bracket then
    Leave(state, false)
    if not Assigned() then Restore(state.stash) end
  end
  entry[bracket] = nil
  P.Automatic()
  return true
end

-- A new layout starts from the current setup and applies at once in a
-- match of that size.
function Layouts.Create(bracket)
  if not Layouts.Save(bracket) then return false end
  P.Automatic()
  return true
end

-- Changes made in a match survive a reload or logout.
ns.Util.Events({
  PLAYER_LOGOUT = function()
    local active = Layouts.Active()
    if active and Layouts.Remember() and Applied() then Layouts.Save(active) end
  end,
}, "battleground layouts")
