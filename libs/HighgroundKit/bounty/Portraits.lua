local _, ns = ...
local B, Core, U = ns.Bounty, ns.Core, ns.Util
local P = B.Public
-- revision counts saved likeness changes, so open posters retry only then.
local R = { MAX_SAVED = 256, MAX_NATIVE = 32, MAX_AGE = 30 * 86400, revision = 0 }
B.Portraits = R
local native, samples = {}, {}
local keeper, probe
local UNITS, PLATES, RESOLUTIONS = { "target", "focus", "mouseover", "player" }, {}, { true, false }
for i = 1, 40 do PLATES[i] = "nameplate" .. i end
local function CacheKey(name) return B.Scope.Key() .. ":" .. B.Key(name) end

function R.Matches(unit, name)
  return unit and U.read(UnitExists, unit) and U.read(UnitIsPlayer, unit)
    and U.read(UnitIsVisible, unit) and B.Key(Core.CanonUnit(unit)) == B.Key(name)
end

function R.FindUnit(name, preferred)
  if R.Matches(preferred, name) then return preferred end
  local seen = B.seen[B.Key(name)]
  if seen and R.Matches(seen.unit, name) then return seen.unit end
  for _, unit in ipairs(UNITS) do
    if R.Matches(unit, name) then return unit end
  end
  for _, unit in ipairs(PLATES) do if R.Matches(unit, name) then return unit end end
end

-- Render-target names such as RTPortrait1 are local GPU resources, not
-- image files. Save observed race/body type even when SetUnit cannot supply
-- a creature display ID; customized player models commonly report zero.
function R.Validate(a, name)
  if type(a) ~= "table" or not P.Name(a.name) or B.Key(a.name) ~= B.Key(name or a.name)
    or not P.Integer(a.displayID, 0, 10000000) or not P.Integer(a.at, 1, P.Now() + 30)
    or P.Now() - a.at > R.MAX_AGE or type(a.guid) ~= "string" or #a.guid > 64
    or a.guid ~= "" and not a.guid:match("^Player%-%w[%w%-]*$")
    or type(a.class) ~= "string" or #a.class > 20 or a.class ~= "" and not a.class:match("^[A-Z]+$")
    or not P.Integer(a.race, 0, 1000) or not P.Integer(a.sex, 0, 3)
    or a.displayID == 0 and (a.race == 0 or a.sex < 2) then return end
  return { name = P.Name(a.name), guid = a.guid, displayID = a.displayID, class = a.class,
    race = a.race, sex = a.sex, at = a.at }
end

local function Data()
  if not P.ready then return end
  local db = P.Data()
  if type(db.portraits) ~= "table" then db.portraits = {} end
  return db.portraits
end

function R.Record(name)
  if not P.ready then return end
  local db = P.Data().portraits
  return type(db) == "table" and R.Validate(db[B.Key(name)], name) or nil
end

function R.Save(a)
  a = R.Validate(a)
  local db = a and Data()
  if not db then return end
  local key, old = B.Key(a.name), R.Record(a.name)
  if old and old.at > a.at then return end
  db[key] = a
  R.revision = R.revision + 1
  local ordered = {}
  for k, value in pairs(db) do
    if not R.Validate(value, k) then db[k] = nil
    else
      ordered[#ordered + 1] = { key = k, at = value.at }
    end
  end
  if #ordered > R.MAX_SAVED then
    table.sort(ordered, function(x, y)
      if x.at ~= y.at then return x.at > y.at end
      if (x.key == key) ~= (y.key == key) then return x.key == key end
      return x.key < y.key
    end)
    for i = R.MAX_SAVED + 1, #ordered do db[ordered[i].key] = nil end
  end
  return a
end

function R.Release(w)
  local entry = w.borrowedPortrait
  if entry then
    entry.owner = nil
    entry.texture:SetParent(keeper); entry.texture:ClearAllPoints(); entry.texture:Hide()
    w.portrait, w.borrowedPortrait = w.ownPortrait, nil
    w.hasPortrait, w.portraitKind = nil, nil
  end
  if w.portraitModel then w.portraitModel:Hide() end
end

local function Native(cache, name)
  local key, count, oldest, stamp = CacheKey(name), 0, nil, math.huge
  if cache[key] then return cache[key] end
  for k, entry in pairs(cache) do
    count = count + 1
    if not (entry.owner and entry.owner:IsVisible()) and entry.used < stamp then oldest, stamp = k, entry.used end
  end
  if not keeper then keeper = CreateFrame("Frame", nil, UIParent); keeper:Hide() end
  local entry
  if count >= R.MAX_NATIVE then
    if not oldest then return end
    entry = cache[oldest]; cache[oldest] = nil
    if entry.owner then R.Release(entry.owner) end
    entry.texture:SetTexture(nil)
  else entry = { texture = keeper:CreateTexture(nil, "ARTWORK") } end
  entry.ready, entry.used, entry.nextCapture = nil, GetTime(), nil
  cache[key] = entry
  return entry
end

local function Portrait(texture, unit)
  if type(SetPortraitTexture) ~= "function" then return end
  local ok = pcall(SetPortraitTexture, texture, unit, true)
  if not ok then ok = pcall(SetPortraitTexture, texture, unit) end
  if ok then texture:SetTexCoord(0, 1, 0, 1) end
  return ok
end

local function CommitModel()
  if not (probe and probe.snapshot) then return end
  if probe.captureScope ~= B.Scope.Key() then probe.snapshot = nil; return end
  local a, unit = probe.snapshot, probe.captureUnit
  if U.read(UnitExists, unit) and not R.Matches(unit, a.name) then return end
  local id = U.read(probe.GetDisplayInfo, probe)
  if not P.Integer(id, 1, 10000000) then return end
  a.displayID = id
  a = R.Save(a)
  if a then
    probe.snapshot = nil
    if R.Share then R.Share(a) end
  end
end

local function CaptureModel(name, unit)
  local _, _, race = U.call(UnitRace, unit)
  local _, class = U.call(UnitClass, unit)
  local a = { name = name, guid = U.read(UnitGUID, unit) or "", class = U.value(class) or "",
    race = U.value(race) or 0, sex = U.read(UnitSex, unit) or 0, at = P.Now(), displayID = 0 }
  local saved = R.Save(a)
  if saved and R.Share then R.Share(saved) end
  if not probe then
    probe = U.call(CreateFrame, "PlayerModel", nil, UIParent)
    if not probe then return end
    probe:SetSize(1, 1); probe:Hide()
    if probe.SetKeepModelOnHide then probe:SetKeepModelOnHide(true) end
    probe:SetScript("OnModelLoaded", function() U.Guard("bounty portrait model", CommitModel) end)
  end
  if type(probe.SetUnit) ~= "function" or type(probe.GetDisplayInfo) ~= "function" then return end
  if probe.ClearModel then probe:ClearModel() end
  probe.captureUnit = unit
  probe.captureScope = B.Scope.Key()
  probe.snapshot = a
  local ok, success = pcall(probe.SetUnit, probe, unit)
  if not ok or success == false then probe.snapshot = nil; return end
  CommitModel()
end

function R.Capture(name, unit, preview, force)
  if not R.Matches(unit, name) then return end
  local cache, key, now = preview and samples or native, CacheKey(name), GetTime()
  if not force and cache[key] and cache[key].ready and now < (cache[key].nextCapture or 0) then
    return cache[key]
  end
  if not preview then CaptureModel(name, unit) end
  if IsUnitModelReadyForUI and not U.read(IsUnitModelReadyForUI, unit) then return end
  local entry = Native(cache, name)
  if entry then
    entry.ready, entry.used = Portrait(entry.texture, unit), now
    local _, class = U.call(UnitClass, unit)
    entry.class = U.value(class)
    entry.nextCapture = now + 5
  end
  return entry
end

-- Try a local render-target reference, then move the retained texture when
-- that client cannot copy it. Never serialize a render-target reference.
local function RestoreNative(w, entry)
  if not (entry and entry.ready) then return end
  entry.used = GetTime()
  if w.borrowedPortrait == entry then return true end
  local texture = U.read(entry.texture.GetTexture, entry.texture)
  if texture then
    local ok, success = pcall(w.portrait.SetTexture, w.portrait, texture)
    if ok and success == true then w.portrait:SetTexCoord(0, 1, 0, 1); return true end
  end
  if entry.owner and entry.owner:IsVisible() then return end
  if entry.owner then R.Release(entry.owner) end
  R.Release(w)
  w.ownPortrait = w.ownPortrait or w.portrait
  w.ownPortrait:Hide()
  entry.owner, w.borrowedPortrait, w.portrait = w, entry, entry.texture
  w.portrait:SetParent(w.portraitWell); w.portrait:ClearAllPoints(); w.portrait:SetAllPoints()
  return true
end

local function RestoreModel(w, a)
  if a.displayID == 0 then return end
  if w.modelDisplayID == a.displayID and (w.portraitKind == "model" or w.portraitKind == "modelFrame") then
    return w.portraitKind
  end
  if SetPortraitTextureFromCreatureDisplayID and pcall(SetPortraitTextureFromCreatureDisplayID, w.portrait, a.displayID) then
    w.portrait:SetTexCoord(0, 1, 0, 1)
    w.modelDisplayID = a.displayID
    return "model"
  end
  if not w.portraitModel then
    local model = U.call(CreateFrame, "PlayerModel", nil, w.portraitWell)
    if not model then return end
    model:SetAllPoints(); model:EnableMouse(false)
    if model.SetKeepModelOnHide then model:SetKeepModelOnHide(true) end
    model:Hide()
    w.portraitModel = model
  end
  local model = w.portraitModel
  if type(model.SetDisplayInfo) ~= "function" then return end
  if not pcall(model.SetDisplayInfo, model, a.displayID) then return end
  w.modelDisplayID = a.displayID
  if model.SetPortraitZoom then model:SetPortraitZoom(1) end
  if model.SetFacing then model:SetFacing(0) end
  model:Show()
  return "modelFrame"
end

local function RestoreRace(w, a)
  if a.race == 0 or a.sex < 2 then return end
  local info = C_CreatureInfo and U.call(C_CreatureInfo.GetRaceInfo, a.race)
  local race = type(info) == "table" and U.value(info.clientFileString)
  if type(race) ~= "string" then return end
  local gender = a.sex == 2 and "male" or "female"
  local lookup = C_Texture and C_Texture.GetAtlasInfo or GetAtlasInfo
  for _, hiRes in ipairs(RESOLUTIONS) do
    local atlas = U.call(GetRaceAtlas, race:lower(), gender, hiRes)
    if type(atlas) == "string" and U.call(lookup, atlas)
      and pcall(w.portrait.SetAtlas, w.portrait, atlas, false) then return "race" end
  end
end

-- A ready captured image this poster is not already showing.
function R.HasNative(w, name, preview)
  local entry = (preview and samples or native)[CacheKey(name)]
  return entry ~= nil and entry.ready == true and w.borrowedPortrait ~= entry
end

function R.Apply(w, name, unit, preview)
  local key, cache = CacheKey(name), preview and samples or native
  if R.Matches(unit, name) then
    R.Capture(name, unit, preview)
    if not IsUnitModelReadyForUI or U.read(IsUnitModelReadyForUI, unit) then
      if Portrait(w.portrait, unit) then return "native" end
    end
  end
  if RestoreNative(w, cache[key]) then return "native" end
  local a = not preview and R.Record(name)
  if a then return RestoreModel(w, a) or RestoreRace(w, a) end
end
