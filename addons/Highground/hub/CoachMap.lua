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
    { "fresh", "Vexa", "ROGUE", 0.50, 0.44, 0, ns.Locale:Get("highground.coachmap.a_teammate.aa3d91"), "coords" },
    { "healer", "Lunara", "PRIEST", 0.57, 0.49, 0, "you", "coords" },
    { "old", "Ashveil", "MAGE", 0.39, 0.66, 36, ns.Locale:Get("highground.coachmap.a_teammate.aa3d91"), "coords" },
    { "rough", "Ironclaw", "WARRIOR", 0.50, 0.15, 12, ns.Locale:Get("highground.coachmap.a_teammate.aa3d91"), "area", ns.Locale:Get("highground.coachmap.silverwing_hold.e68140") },
    { "south", "Thorn", "HUNTER", 0.53, 0.85, 0, ns.Locale:Get("highground.coachmap.a_teammate.aa3d91"), "coords" },
  }) do
    local key = sample[1]
    data.enemies[key] = { key = key, display = ns.Locale:Format("shared.copy.name_sample.c1067c", { name = sample[2] }), class = sample[3] }
    data.intel[key] = { x = sample[4], y = sample[5], t = data.now - sample[6],
      by = sample[7], how = sample[8], area = sample[9] }
  end
  data.killNow = data.enemies.fresh
  return data
end

function M.Show()
  if not WorldMapFrame then ns.Api.LoadAddOn("Blizzard_WorldMap") end
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
    { id = "map", feature = "intel", title = ns.Locale:Get("highground.coachmap.enemies_on_your_world_map.7062f3"), target = Canvas,
      text = function() return M.mapID
        and ns.Locale:Get("highground.coachmap.this_is_wow_s_world_map_with.e5b392")
        or ns.Locale:Get("highground.coachmap.warsong_gulch_is_unavailable_in_this_client.da444f") end },
    { id = "fresh", title = ns.Locale:Get("highground.coachmap.start_with_a_fresh_sighting.d7f307"), target = function() return M.Pin("fresh") end, event = "OnEnter",
      text = ns.Locale:Get("highground.coachmap.this_bright_rogue_pin_is_a_fresh.bbd705"), hint = ns.Locale:Get("highground.coachmap.hover_the_highlighted_enemy_then_choose_next.7c672d") },
    { id = "target", title = ns.Locale:Get("highground.coachmap.spot_the_suggested_target.2d4580"), target = function() return M.Pin("fresh") end,
      text = ns.Locale:Get("highground.coachmap.the_outer_ring_marks_the_suggested_target.9f5fc2") },
    { id = "old", title = ns.Locale:Get("highground.coachmap.older_sightings_fade.039a3d"), target = function() return M.Pin("old") end, event = "OnEnter",
      text = ns.Locale:Get("highground.coachmap.this_faded_mage_was_last_seen_36.2fe437") },
    { id = "rough", title = ns.Locale:Get("highground.coachmap.a_location_can_be_approximate.08cdfb"), target = function() return M.Pin("rough") end, event = "OnEnter",
      text = ns.Locale:Get("highground.coachmap.a_faint_circle_marks_roughly_where_an.47c0a0") },
    { id = "share", feature = "intelShare", title = ns.Locale:Get("highground.coachmap.use_the_whole_picture.b9e5f8"), target = Canvas,
      text = ns.Locale:Get("highground.coachmap.compare_fresh_pins_older_sightings_and_the.a2fa1f") },
  }
  for _, step in ipairs(steps) do
    step.enter, step.context = M.Show, function() return M.win end
    step.missing = function() return not M.mapID and ns.Locale:Get("highground.coachmap.warsong_gulch_is_unavailable_in_this_client.ccb80d")
      or ns.Locale:Get("highground.coachmap.use_replay_to_reopen_warsong_gulch_on.5dd141") end
  end
  return steps
end
