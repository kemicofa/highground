local _, ns = ...
local Core = ns.Core
local Theme = ns.Theme

-- Sniper scope floating above the kill target's nameplate in the world.
-- Nameplate-addon safe (Plater, Kui, Platynator...): the scope is our own
-- UIParent child that is only ANCHORED to the plate; we never reparent, hook,
-- resize or add children to any nameplate, and it ignores the mouse.
-- Built from plain lines (no external art): crosshair with a center gap,
-- corner brackets, center dot. Pulses; bigger/brighter during a kill window.

-- Crosshair colours the player picks (/wb sniper color, WarboardDB.sniperColor):
-- high-contrast colours that rarely appear in BG scenery, the same in every
-- theme. The kill-window (GO) look uses the "kill" token.
Core.SNIPER_COLORS = {
  magenta = Theme.Rgb("sniperMagenta"),
  cyan = Theme.Rgb("sniperCyan"),
  yellow = Theme.Rgb("sniperYellow"),
  lime = Theme.Rgb("sniperLime"),
  white = Theme.Rgb("white"),
  orange = Theme.Rgb("sniperOrange"),
}
Core.SNIPER_DEFAULT = "magenta"
local GO_COLOR = "kill"
local OUTLINE_ALPHA = 0.9

Core.sniper = CreateFrame("Frame", "WarboardSniper", UIParent)
Core.sniper:SetSize(52, 52)
Core.sniper:SetFrameStrata("HIGH")
Core.sniper:EnableMouse(false)
Core.sniper:Hide()
Core.sniper.parts = {} -- colored strokes
do
  -- Each stroke = black outline underneath + colored core on top, so it reads
  -- on any background (grass, snow, water, spell effects).
  local OUT = 2 -- outline width on each side
  local function Stroke(w, h, point, rel, x, y)
    local o = Theme.Fill(Core.sniper, "ARTWORK", "black", OUTLINE_ALPHA)
    o:SetSize(w + OUT * 2, h + OUT * 2)
    o:SetPoint(point, Core.sniper, rel or "CENTER", x + (point:find("LEFT") and -OUT or point:find("RIGHT") and OUT or 0),
      y + (point:find("TOP") and OUT or point:find("BOTTOM") and -OUT or 0))
    -- White core, tinted with the scope colour (Core.UpdateSniper).
    local c = Core.sniper:CreateTexture(nil, "OVERLAY")
    c:SetTexture(Core.WHITE)
    c:SetSize(w, h)
    c:SetPoint(point, Core.sniper, rel or "CENTER", x, y)
    table.insert(Core.sniper.parts, c)
  end
  local S, G, T = 26, 7, 4 -- half-size, center gap, stroke thickness
  Stroke(T, S - G, "BOTTOM", nil, 0, G) -- up
  Stroke(T, S - G, "TOP", nil, 0, -G) -- down
  Stroke(S - G, T, "RIGHT", nil, -G, 0) -- left
  Stroke(S - G, T, "LEFT", nil, G, 0) -- right
  Stroke(5, 5, "CENTER", nil, 0, 0) -- dot
  local B = 11 -- bracket arm length
  for _, c in ipairs({ { -1, 1 }, { 1, 1 }, { -1, -1 }, { 1, -1 } }) do
    local cx, cy = c[1] * S, c[2] * S
    Stroke(B, T, c[1] < 0 and "LEFT" or "RIGHT", nil, cx, cy + (c[2] > 0 and -T / 2 or T / 2))
    Stroke(T, B, c[2] > 0 and "TOP" or "BOTTOM", nil, cx + (c[1] < 0 and T / 2 or -T / 2), cy)
  end
  Core.sniper.pulse = Core.Bounce(Core.sniper, 1, 0.6, 0.6)
end

-- Lock-on sounds: our own synthesized file first, then SoundKit IDs
-- (see SoundKitConstants.lua).
Core.SNIPER_SOUNDS = {
  { file = "Interface\\AddOns\\Warboard\\sounds\\lockon.ogg", name = "Warboard lock-on" },
  { id = 3175, name = "ping" }, -- MAP_PING
  { id = 37666, name = "boss whisper" }, -- UI_RAID_BOSS_WHISPER_WARNING
  { id = 12889, name = "alarm" }, -- ALARM_CLOCK_WARNING_3
  { id = 76995, name = "prestige" }, -- UI_PVP_HONOR_PRESTIGE_OPEN_WINDOW
}

function Core.PlaySniperSound()
  if not Core.On("sound") then return end
  local snd = Core.SNIPER_SOUNDS[Core.db.sniperSound or 0]
  if snd and snd.file then
    -- New files are only visible after a full client restart; until then
    -- PlaySoundFile returns false, so fall back to a built-in chime.
    if not PlaySoundFile(snd.file, "Master") then
      PlaySound(37666, "Master")
    end
  elseif snd then
    PlaySound(snd.id, "Master")
  end
end

-- Kill-window sting (custom file; raid warning until the client has been
-- restarted once and can see the new file).

local GO_SOUND = "Interface\\AddOns\\Warboard\\sounds\\go.ogg"
Core.PlayGoSound = function()
  if not PlaySoundFile(GO_SOUND, "Master") then
    PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master")
  end
end

-- Scope colour: the GO token in a kill window, else the player's pick.
function Core.SniperColor(isGo)
  if isGo then return Theme.Rgb(GO_COLOR) end
  return Core.SNIPER_COLORS[Core.db.sniperColor] or Core.SNIPER_COLORS[Core.SNIPER_DEFAULT]
end

function Core.UpdateSniper(e, isGo)
  local plate = Core.On("sniper") and e and e.plateUnit and C_NamePlate and C_NamePlate.GetNamePlateForUnit
    and C_NamePlate.GetNamePlateForUnit(e.plateUnit)
  if not plate or (plate.IsForbidden and plate:IsForbidden()) then
    Core.sniper.unit = nil
    Core.sniper:Hide()
    Core.sniper.pulse:Stop()
    return
  end
  Core.sniper.unit = e.plateUnit
  -- Lock-on sound only when the scope moves to a NEW enemy: the same enemy's
  -- nameplate dropping out and back in stays silent.
  local key = e.key or Core.CanonUnit(e.plateUnit)
  if key and key ~= Core.sniper.soundKey then
    Core.sniper.soundKey = key
    Core.PlaySniperSound()
  end
  if Core.sniper.anchor ~= plate or Core.sniper.anchorY ~= Core.db.sniperY then
    Core.sniper:ClearAllPoints()
    -- On the body: centered below the nameplate (the plate floats over the
    -- head), clear of overhead orb/flag effects. /wb sniper y N adjusts.
    if not pcall(Core.sniper.SetPoint, Core.sniper, "CENTER", plate, "BOTTOM", 0, Core.db.sniperY) then
      Core.sniper:Hide()
      return
    end
    Core.sniper.anchor, Core.sniper.anchorY = plate, Core.db.sniperY
  end
  local col = Core.SniperColor(isGo)
  for _, t in ipairs(Core.sniper.parts) do
    Theme.Tint(t, col, 1)
  end
  Core.sniper:SetScale((Core.db.sniperScale or 1) * (isGo and 1.3 or 1))
  if not Core.sniper:IsShown() then
    Core.sniper:Show()
    Core.sniper.pulse:Play()
  end
end

-- Nameplate unit token of your current target (hostile only if asked).
function Core.TargetPlateUnit(hostile)
  if not (UnitExists("target") and C_NamePlate and C_NamePlate.GetNamePlateForUnit) then
    return nil
  end
  if hostile then
    local ok, harm = pcall(UnitCanAttack, "player", "target")
    if not (ok and Core.plain(harm) and harm) then return nil end
  end
  local plate = C_NamePlate.GetNamePlateForUnit("target")
  local unit = plate and plate.namePlateUnitToken
  if unit then return unit end
  for i = 1, 40 do
    local ok, same = pcall(UnitIsUnit, "nameplate" .. i, "target")
    if ok and Core.plain(same) and same == true then
      return "nameplate" .. i
    end
  end
end

-- /wb sniper test: scope on your current target's nameplate, anywhere
-- (open world, no panel). /wb go toggles the kill-window look while testing.
-- Shown/hidden by the command; a hidden frame gets no OnUpdate.
Core.sniperTest = { on = false, go = false }
Core.sniperDriver = ns.Util.Every(0.1, function()
  local unit = Core.TargetPlateUnit()
  Core.UpdateSniper(unit and { plateUnit = unit } or nil, Core.sniperTest.go)
end, "sniper").frame
Core.sniperDriver:Hide()
