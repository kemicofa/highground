local _, ns = ...
local Core, P, Parts, CS, Codec, L = ns.Core, ns.Options.Profiles, ns.SettingsParts, ns.CharacterSettings, ns.Codec, ns.Locale

---------------------------------------------------------------------------
-- Profiles: your other characters' settings and imported ones, per addon.
-- Imports are named after the character that exported them:
-- HighgroundDB.profileImports = { { name, received, addons = { [addon] =
-- data } } }, or { name, received, snap } for a profile saved by an older
-- version (every addon's part of one snapshot). Copying replaces this
-- character's settings for that addon; for Battlegrounds, every size.
---------------------------------------------------------------------------
local function Imports() return ns.Saved.Table(Core.db, "profileImports") end
local function Valid(addon) for _, key in ipairs(Parts.ADDONS) do if key == addon then return true end end end

-- A whole profile from an older version kept shared panel values (timer
-- scale and widths, compact) that each addon's own values derive from:
-- derive them before taking one addon's part.
local function Normalized(snap)
  local setup = type(snap.setup) == "table" and snap.setup
  if not setup then return snap end
  local copy = ns.Saved.Copy(snap)
  local prepared = P.PrepareSetup(ns.Saved.Copy(setup))
  if prepared then copy.setup.style = prepared.style end
  return copy
end

-- What a profile holds for addon: a snapshot, or for Battlegrounds one per size.
local function Data(source, addon)
  if source.character then
    local entry = CS.Entry(source.character)
    return entry and entry.addons[addon]
  end
  local item = Imports()[source.import]
  if type(item) ~= "table" then return end
  if type(item.addons) == "table" then return item.addons[addon] end
  if type(item.snap) ~= "table" then return end
  local snap = Normalized(item.snap)
  if addon ~= "battlegrounds" then return Parts.Filter(snap, addon) end
  local sizes = {}
  for _, scope in ipairs(CS.SCOPES) do sizes[scope] = Parts.Filter(snap, addon) end
  return sizes
end
CS.ProfileData = Data

-- Profiles offering addon, this character first: { source, name, class, kind, received }.
function CS.Profiles(addon)
  local own, list = CS.Key(), {}
  for key, entry in pairs(type(Core.db.characters) == "table" and Core.db.characters or {}) do
    if key ~= own and type(entry) == "table" and type(entry.name) == "string" and Data({ character = key }, addon) then
      list[#list + 1] = { source = { character = key }, name = entry.name, class = entry.class, kind = "character" }
    end
  end
  for i, item in ipairs(Imports()) do
    if type(item) == "table" and type(item.name) == "string" and Data({ import = i }, addon) then
      list[#list + 1] = { source = { import = i }, name = item.name, kind = "import", received = item.received }
    end
  end
  table.sort(list, function(a, b)
    if a.kind ~= b.kind then return a.kind == "character" end
    return a.name < b.name
  end)
  table.insert(list, 1, { source = { character = own }, name = CS.Name(), class = Core.me.class, kind = "self" })
  return list
end

local function Fail(key) return false, L:Get(key) end

-- Replace this character's settings for addon with a profile's.
function CS.Copy(source, addon)
  if not Valid(addon) then return Fail("profiles.list.unknown_addon") end
  if InCombatLockdown() then return Fail("profiles.list.after_combat") end
  if source.character == CS.Key() then return Fail("profiles.list.same") end
  local data = Data(source, addon)
  if type(data) ~= "table" then return Fail("profiles.list.missing") end
  -- Panels unlocked for a preview or placement relock first.
  CS.StopPreview()
  if ns.Setup and ns.Setup.placement then ns.Setup.EndPlacement(false) end
  -- Nothing is stored unless every part validates (older saved profiles).
  for _, snap in pairs(addon == "battlegrounds" and data or { data }) do
    if type(snap) ~= "table" or not P.Prepare(snap) then return Fail("profiles.list.invalid") end
  end
  CS.Save()
  local entry = CS.Entry(nil, true)
  if addon == "battlegrounds" then
    local sizes = {}
    -- A profile without a size starts it from its 10v10 settings.
    for _, scope in ipairs(CS.SCOPES) do sizes[scope] = ns.Saved.Copy(data[scope] or data.bg10) end
    entry.addons.battlegrounds = sizes
    Core.pos.liveScope = nil
    CS.Update()
  else
    entry.addons[addon] = ns.Saved.Copy(data)
    CS.LoadPart(addon, data)
    Parts.Refresh()
  end
  CS.Changed()
  return true
end

function CS.Delete(source)
  if source.character then
    if source.character == CS.Key() or not CS.Entry(source.character) then return false end
    Core.db.characters[source.character] = nil
  elseif not Imports()[source.import] then return false
  else table.remove(Imports(), source.import) end
  CS.Changed()
  return true
end

---------------------------------------------------------------------------
-- Export and import. WB2: base64 of "WB2;n=<character>;f=<client>;a=<addon>;
-- x=<base64 of Codec.Pack(data)>". Older "WB1" profile codes still import.
---------------------------------------------------------------------------
function CS.Export(addon)
  if not Valid(addon) then return nil end
  CS.Save()
  local data = CS.Entry(nil, true).addons[addon]
  if type(data) ~= "table" then return nil end
  local name = P.CleanName(CS.Name()) or "?"
  return Codec.Encode64(table.concat({ "WB2", "n=" .. name, "f=" .. ns.CLIENT, "a=" .. addon,
    "x=" .. Codec.Encode64(Codec.Pack(data)) }, ";"))
end

-- Every snapshot of an import must validate before anything is kept.
local function Check(snap, flavor)
  if type(snap) ~= "table" then return false end
  snap.flavor = flavor
  return P.Prepare(snap) ~= nil
end

function CS.Parse(text)
  text = (text or ""):gsub("%s+", "")
  local plain = Codec.Decode64(text) or ""
  if plain:match("^WB2;") then
    local fields = {}
    for key, value in plain:gmatch("(%a)=([^;]*)") do fields[key] = value end
    local raw = fields.x and Codec.Decode64(fields.x)
    local data = raw and Codec.Unpack(raw)
    local addon, flavor = fields.a, fields.f
    if not (Valid(addon) and type(data) == "table" and (flavor == "cata" or flavor == "retail")) then
      return nil, L:Get("profiles.list.invalid")
    end
    if addon == "battlegrounds" then
      for key, snap in pairs(data) do
        if not CS.SCOPE_SET[key] or not Check(snap, flavor) then return nil, L:Get("profiles.list.invalid") end
      end
    elseif not Check(data, flavor) then return nil, L:Get("profiles.list.invalid") end
    return { name = P.CleanName(fields.n), addons = { [addon] = data }, addon = addon }
  end
  local snap, err = P.ParseString(text)
  if not snap then return nil, err end
  if not P.Prepare(snap) then return nil, L:Get("profiles.list.invalid") end
  return { name = snap.name, snap = snap }
end

local function Unique(name)
  local taken = {}
  for _, item in ipairs(Imports()) do if type(item) == "table" then taken[item.name] = true end end
  if not taken[name] then return name end
  local n = 2
  while taken[name .. " (" .. n .. ")"] do n = n + 1 end
  return name .. " (" .. n .. ")"
end

-- Keep an import in the list; nothing changes until it is copied. sender
-- names a profile received in chat.
function CS.Import(text, sender)
  local parsed, err = CS.Parse(text)
  if not parsed then return false, err end
  local name = Unique(P.CleanName(sender) or parsed.name or L:Get("profiles.list.imported_name"))
  local item = { name = name, received = time(), addons = parsed.addons, snap = parsed.snap }
  local imports = Imports()
  imports[#imports + 1] = item
  CS.Changed()
  return true, L:Format("profiles.list.imported", { name = name }), #imports, parsed.addon
end
