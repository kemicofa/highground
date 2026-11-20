local _, ns = ...
local C, M = ns.Onboarding.Coach, {}
C.Map = M

local function MapID()
  if not (C_Map and C_Map.GetMapInfo) then return end
  local ids = ns.CLIENT == "cata" and { 1460, 1339 } or { 1339, 1460 }
  for _, id in ipairs(ids) do
    local ok, info = pcall(C_Map.GetMapInfo, id)
    if ok and info then return id end
  end
end

-- Observations are session data. The live intel layer builds their labels,
-- fading, target ring and tooltips; the world map owns the actual pins.
local function Samples(mapID)
  local data = { mapID = mapID, now = GetTime(), enemies = {}, intel = {} }
  for _, sample in ipairs({
    { "fresh", "Vexa", "ROGUE", 0.50, 0.44, 0, "a teammate", "coords" },
    { "healer", "Lunara", "PRIEST", 0.57, 0.49, 0, "you", "coords" },
    { "old", "Ashveil", "MAGE", 0.39, 0.66, 36, "a teammate", "coords" },
    { "rough", "Ironclaw", "WARRIOR", 0.50, 0.15, 12, "a teammate", "area", "Silverwing Hold" },
    { "south", "Thorn", "HUNTER", 0.53, 0.85, 0, "a teammate", "coords" },
  }) do
    local key = sample[1]
    data.enemies[key] = { key = key, display = sample[2] .. " · Sample", class = sample[3] }
    data.intel[key] = { x = sample[4], y = sample[5], t = data.now - sample[6],
      by = sample[7], how = sample[8], area = sample[9] }
  end
  data.killNow = data.enemies.fresh
  return data
end

function M.Show()
  if not WorldMapFrame then
    if C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_WorldMap")
    elseif LoadAddOn then pcall(LoadAddOn, "Blizzard_WorldMap") end
  end
  local map = WorldMapFrame
  if not (map and map.SetMapID and map.AddDataProvider) then return end
  if not M.session then
    M.session = { shown = map:IsShown(), mapID = map:GetMapID() }
    M.mapID = MapID()
    M.data = Samples(M.mapID)
  end
  M.win = map
  -- Opening the native map can reset its map ID. Choose Warsong afterwards.
  if OpenWorldMap then OpenWorldMap(M.mapID)
  elseif ShowUIPanel then ShowUIPanel(map)
  else map:Show() end
  if M.mapID then map:SetMapID(M.mapID) end
  if map.ResetZoom then map:ResetZoom() end
  ns.MapPins.SetPreview(map, function(id, width, height)
    return ns.Intel.Pins(id, width, height, M.data)
  end)
  return map
end

function M.Pin(key)
  return M.win and ns.MapPins.GetPin(M.win, key)
end

function M.Stop()
  local session, map = M.session, M.win
  M.session, M.data = nil, nil
  if not (session and map) then return end
  ns.MapPins.SetPreview(map, nil)
  if session.mapID then map:SetMapID(session.mapID) end
  if not session.shown then
    if HideUIPanel then HideUIPanel(map) else map:Hide() end
  end
  GameTooltip_Hide()
end

function C.MapSteps()
  local function Canvas()
    return M.win and (M.win.GetCanvasContainer and M.win:GetCanvasContainer() or M.win:GetCanvas())
  end
  local steps = {
    { id = "map", title = "Enemies on your world map", target = Canvas,
      text = function() return M.mapID
        and "This is WoW's world map with five sample enemies in Warsong Gulch. In a match, the same pins also appear on the battlefield map (Shift+M). Only observed enemies get a position."
        or "Warsong Gulch is unavailable in this client. This is your normal world map. Return to Guides to try another feature." end },
    { id = "fresh", title = "Start with a fresh sighting", target = function() return M.Pin("fresh") end, event = "OnEnter",
      text = "This bright rogue pin is a fresh sighting. Hover it to read who was seen and who observed them.", hint = "Hover the highlighted enemy, then choose Next." },
    { id = "target", title = "Spot the suggested target", target = function() return M.Pin("fresh") end,
      text = "The outer ring marks the suggested target when one is available. The class icon tells you which kind of enemy was observed." },
    { id = "old", title = "Older sightings fade", target = function() return M.Pin("old") end, event = "OnEnter",
      text = "This faded mage was last seen 36 seconds ago. The time is the age of the sighting. They may have moved; this is not a live position." },
    { id = "rough", title = "A location can be approximate", target = function() return M.Pin("rough") end, event = "OnEnter",
      text = "The ~ means an approximate position, such as a known area. Hover to see why it is approximate. A teammate's observation improves coverage without revealing unseen enemies." },
    { id = "share", title = "Use the whole picture", target = Canvas,
      text = "Compare fresh pins, older sightings and the objective before choosing a route. These sample sightings stay out of live tracking and group sharing. Done restores your previous map." },
  }
  for _, step in ipairs(steps) do
    step.enter, step.context = M.Show, function() return M.win end
    step.missing = function() return not M.mapID and "Warsong Gulch is unavailable in this client. Use Guides to return."
      or "Use Replay to reopen Warsong Gulch on the world map." end
  end
  return steps
end
