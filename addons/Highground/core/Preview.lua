local _, ns = ...
local Core = ns.Core

-- Test enemies with mana where enemy power is readable.
local MANA_CLASSES = { PRIEST = true, MAGE = true, WARLOCK = true, SHAMAN = true, PALADIN = true, DRUID = true }
function Core.TestUsesMana(class)
  return ns.Caps.enemyStats and MANA_CLASSES[class] or false
end

-- Cooldowns as if seen used, so tooltips, row trinkets and the card show
-- them: about half of each kit is down for part of its cooldown, and
-- n = 2 has a defensive running right now.
local function SeedCooldowns(e, n)
  local kit = Core.KitFor(e)
  if #kit == 0 or e.dead then return end
  local now = GetTime()
  e.cds = {}
  for i, entry in ipairs(kit) do
    if (i + n) % 2 == 0 then
      e.cds[entry[1]] = now + entry[2] * (0.15 + ((i * 7 + n * 3) % 8) / 10)
    end
  end
  if n == 2 then
    for _, entry in ipairs(kit) do
      if entry[3] == "def" or entry[3] == "immune" or entry[3] == "external" then
        e.activeCooldowns = { [entry[1]] = true }
        break
      end
    end
  end
end

local SAMPLE_NAMES = { "Lunara", "Stormcall", "Dawnshield", "Wildleaf", "Ashveil", "Thorn", "Vexa", "Duskveil", "Frostbane", "Ironclaw" }
local function SeedEnemies(guided)
  -- Borrow names from visible nameplates (NPCs are fine) so row clicks
  -- actually target something; pad with fake names.
  local nearby, seenName = {}, {}
  for i = 1, guided and 0 or 40 do
    local name = Core.FullUnitName("nameplate" .. i)
    if type(name) == "string" and name ~= "" and not seenName[name] then
      seenName[name] = true
      nearby[#nearby + 1] = name
    end
  end
  local pool = { 1468, 270, 257, 105, 65, 254, 261, 102, 252, 70, 71, 258, 63, 577, 73 }
  if ns.Caps.classicSpecs then
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
  -- Health and mana across the range: n = 3 is under the execute threshold,
  -- n = 2 a healer out of mana, n = 9 dead, n = 10 out of view with its last
  -- seen health (muted until Keep last seen health runs out).
  local HP = { 0.92, 0.64, 0.28, 0.45, 1, 0.73, 0.55, 0.12, 0, 0.85 }
  local MANA = { 0.81, 0.04, 0.47, 0.66, 0.95, 0.3, 0.58, 0.22, 0, 0.74 }
  for n = 1, 10 do
    local id = pool[n]
    local si = Core.specInfo[id]
    if si then
      local key = guided and (SAMPLE_NAMES[n] .. "-Sample") or nearby[n] and Core.Canon(nearby[n]) or ("Enemy" .. n .. "-Test")
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
        -- In view (clickable, live distance); health and mana are fixed.
        unit = (n == 1 or n == 3 or n == 4) and "player" or nil,
        testHp = n ~= 10 and HP[n] or nil, hpPct = n ~= 10 and HP[n] or nil,
        hpSeen = n == 10 and HP[n] * 100 or nil, lastSeen = n == 10 and GetTime() or nil,
      }
      if Core.TestUsesMana(si.class) then
        Core.enemies[key].manaPct, Core.enemies[key].manaAt = MANA[n], math.huge
      end
      SeedCooldowns(Core.enemies[key], n)
    end
  end
end

-- Guides supply observations to the normal panel, layout and renderer.
-- Secure actions stay empty while the panel contains invented identities.
function Core.StartTest(guided, enemies)
  if ns.Modules and not ns.Modules.Require("battlegrounds") then return false end
  Core.testMode, Core.guidedTest = true, guided == true
  Core.killNow = nil
  wipe(Core.enemies)
  Core.ClearPreviewSpecTags()
  if enemies then
    for key, enemy in pairs(enemies) do Core.enemies[key] = enemy end
  else
    SeedEnemies(guided)
  end
  Core.SetActive(false)
  Core.SetActive(true)
end
