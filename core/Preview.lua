local _, ns = ...
local Core = ns.Core

function Core.StartTest()
  Core.testMode = true
  wipe(Core.enemies)
  -- Borrow names from visible nameplates (NPCs are fine) so row clicks
  -- actually target something; pad with fake names.
  local nearby, seenName = {}, {}
  for i = 1, 40 do
    local ok, name = pcall(UnitName, "nameplate" .. i)
    if ok and Core.plain(name) and type(name) == "string" and name ~= "" and not seenName[name] then
      seenName[name] = true
      nearby[#nearby + 1] = name
    end
  end
  local pool = { 1468, 270, 257, 105, 65, 254, 261, 102, 252, 70, 71, 258, 63, 577, 73 }
  if not Core.IS_RETAIL then
    -- Classic spec IDs differ: take one spec per class from the client.
    pool = {}
    local classes = { "PRIEST", "SHAMAN", "PALADIN", "DRUID", "MAGE", "HUNTER", "ROGUE", "WARLOCK", "DEATHKNIGHT", "WARRIOR" }
    for n, cls in ipairs(classes) do
      local ids = Core.classSpecs[cls]
      if ids and #ids > 0 then
        pool[#pool + 1] = ids[(n % #ids) + 1]
      end
    end
  end
  for n = 1, 10 do
    local id = pool[n]
    local si = Core.specInfo[id]
    if si then
      local key = nearby[n] and Core.Canon(nearby[n]) or ("Enemy" .. n .. "-Test")
      Core.enemies[key] = {
        key = key, display = key, class = si.class,
        specID = (n ~= 7) and id or nil, specSrc = (n % 3 == 0) and "hist" or "live",
        def = (n == 2), cc = (n == 5), dead = (n == 9), burst = (n == 6),
        burnedAt = (n == 4) and GetTime() - 10 or nil,
        range = (n == 1 or n == 3) and "attack" or (n == 4) and "reach" or nil,
        yards = (n == 1 or n == 3) and 5 or (n == 4) and 30 or nil,
        testStacks = (n == 7) and 4 or nil,
        allyCount = (n == 1) and 4 or (n == 3) and 1 or 0,
        onMe = (n == 2 or n == 6),
        marker = (n == 1) and 8 or (n == 5) and 7 or nil,
        -- Preview a live health bar using your own health.
        unit = (n == 1 or n == 3 or n == 4) and "player" or nil,
      }
    end
  end
  Core.SetActive(false)
  Core.SetActive(true)
end
