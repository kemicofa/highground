local ADDON, ns = ... -- ADDON: this addon's folder name
local Core = ns.Core
local Theme = ns.Theme

-- Layered sniper sight anchored to the kill target's nameplate.
-- Nameplate-addon safe (Plater, Kui, Platynator...): the scope is our own
-- UIParent child that is only ANCHORED to the plate; we never reparent, hook,
-- resize or add children to any nameplate, and it ignores the mouse.
-- Neutral RGBA art keeps the rim tintable; the skull is an independent layer.
-- A gentle alpha pulse signals a finishing opportunity; no rotation or zoom.

local ART = "Interface\\AddOns\\" .. ADDON .. "\\assets\\sniper\\"
local scopes = {}
Core.SNIPER_STYLES = {
  ns.Localization.Define({ key = "layered", label = ns.Locale:Get("highground.sniper.new_icon_default.9421ed") }, { label = "highground.sniper.new_icon_default.9421ed" }),
  ns.Localization.Define({ key = "legacy", label = ns.Locale:Get("highground.sniper.legacy_crosshair.77cff4") }, { label = "highground.sniper.legacy_crosshair.77cff4" }),
}

-- Head/body positions are screen-space estimates below the nameplate.
-- Addons have no supported attachment to the live character's helmet/bones.
Core.SNIPER_PLACEMENTS = {
  ns.Localization.Define({ key = "head", label = ns.Locale:Get("highground.sniper.head_area_approx.985517"), point = "CENTER", relative = "BOTTOM", y = -24 }, { label = "highground.sniper.head_area_approx.985517" }),
  ns.Localization.Define({ key = "body", label = ns.Locale:Get("highground.sniper.body.718a7e"), point = "CENTER", relative = "BOTTOM", y = -40 }, { label = "highground.sniper.body.718a7e" }),
  ns.Localization.Define({ key = "left", label = ns.Locale:Get("highground.sniper.left_of_nameplate.99d9ab"), point = "RIGHT", relative = "LEFT", y = 0, gapX = -1 }, { label = "highground.sniper.left_of_nameplate.99d9ab" }),
  ns.Localization.Define({ key = "right", label = ns.Locale:Get("highground.sniper.right_of_nameplate.3e69c2"), point = "LEFT", relative = "RIGHT", y = 0, gapX = 1 }, { label = "highground.sniper.right_of_nameplate.3e69c2" }),
  ns.Localization.Define({ key = "above", label = ns.Locale:Get("highground.sniper.above_nameplate.d804a6"), point = "BOTTOM", relative = "TOP", y = 0, gapY = 1 }, { label = "highground.sniper.above_nameplate.d804a6" }),
}

function Core.SniperPlacement(key)
  for _, placement in ipairs(Core.SNIPER_PLACEMENTS) do
    if placement.key == (key or (Core.db and Core.db.sniperPlacement) or "head") then return placement end
  end
end

local function RefreshPosition()
  local scope = Core.sniper
  if scope and scope.unit then Core.UpdateSniper(scope.entry or { plateUnit = scope.unit }, scope.isGo) end
  if ns.Options and ns.Options.byKey["battlegrounds-appearance"] then ns.Options.RefreshPage(ns.Options.byKey["battlegrounds-appearance"]) end
end

function Core.SetSniperStyle(key)
  if key ~= "layered" and key ~= "legacy" then return false end
  Core.db.sniperStyle = key
  Core.RefreshScopes()
  RefreshPosition()
  return true
end

function Core.SetSniperPlacement(key)
  local placement = Core.SniperPlacement(key)
  if not placement then return false end
  if Core.db.sniperPlacement ~= key then
    Core.db.sniperPlacement, Core.db.sniperY = key, placement.y
  end
  RefreshPosition()
  return true
end

function Core.SetSniperNumber(key, value)
  if not ({ sniperX = true, sniperY = true, sniperPadding = true, sniperScale = true })[key]
    or type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return false end
  local def = Core.SavedDefs[key]
  Core.db[key] = math.max(def.min, math.min(def.max, value))
  RefreshPosition()
  return true
end

function Core.AnchorSniper(plate, sample)
  local scope, db = sample or Core.sniper, Core.db
  local placement = Core.SniperPlacement() or Core.SNIPER_PLACEMENTS[1]
  -- Divide offsets by our scale so padding stays in UI pixels at every size.
  local scale = scope:GetScale()
  local x = ((db.sniperX or 0) + (placement.gapX or 0) * (db.sniperPadding or 8)) / scale
  local y = ((db.sniperY or placement.y) + (placement.gapY or 0) * (db.sniperPadding or 8)) / scale
  if scope.anchor == plate and scope.anchorPlacement == placement.key and scope.anchorX == x and scope.anchorY == y then
    return true
  end
  scope.anchor = nil
  scope:ClearAllPoints()
  if not pcall(scope.SetPoint, scope, placement.point, plate, placement.relative, x, y) then return false end
  scope.anchor, scope.anchorPlacement, scope.anchorX, scope.anchorY = plate, placement.key, x, y
  return true
end

-- Score/role alone is not urgency. Use observable health or a real GO window.
-- HealthFraction rejects restricted values; unknown health uses the idle pulse.
function Core.SniperUrgency(e, isGo)
  if not e or e.dead or e.immune then return nil end
  local hp = ns.Util.value(e.hpPct)
  if hp == nil and e.plateUnit then hp = ns.Util.HealthFraction(e.plateUnit) end
  if not Core.plain(hp) or type(hp) ~= "number" or hp ~= hp or hp < 0 or hp > 1 then hp = nil end
  if hp == 0 then return nil end
  if isGo then return 3 end
  if not hp or hp > 0.5 then return 0 end
  if hp <= 0.15 then return 3 end
  if hp <= 0.3 then return 2 end
  return 1
end

local PULSE = {
  [0] = { duration = 1.2, alpha = 0.88 },
  { duration = 0.9, alpha = 0.8 },
  { duration = 0.6, alpha = 0.65 },
  { duration = 0.4, alpha = 0.55 },
}

-- Original line-built marker, retained with its exact stroke geometry.
local function MakeLegacy(scope)
  local frame = CreateFrame("Frame", nil, scope)
  frame:SetAllPoints(scope); frame:EnableMouse(false)
  local parts, OUT = {}, 2
  local function Stroke(w, h, point, x, y)
    local outline = Theme.Fill(frame, "ARTWORK", "black", 0.9)
    outline:SetSize(w + OUT * 2, h + OUT * 2)
    outline:SetPoint(point, frame, "CENTER", x + (point:find("LEFT") and -OUT or point:find("RIGHT") and OUT or 0),
      y + (point:find("TOP") and OUT or point:find("BOTTOM") and -OUT or 0))
    local core = frame:CreateTexture(nil, "OVERLAY")
    core:SetTexture(Core.WHITE); core:SetSize(w, h)
    core:SetPoint(point, frame, "CENTER", x, y)
    parts[#parts + 1] = core
  end
  local S, G, T, B = 26, 7, 4, 11
  Stroke(T, S - G, "BOTTOM", 0, G)
  Stroke(T, S - G, "TOP", 0, -G)
  Stroke(S - G, T, "RIGHT", -G, 0)
  Stroke(S - G, T, "LEFT", G, 0)
  Stroke(5, 5, "CENTER", 0, 0)
  for _, corner in ipairs({ { -1, 1 }, { 1, 1 }, { -1, -1 }, { 1, -1 } }) do
    local cx, cy = corner[1] * S, corner[2] * S
    Stroke(B, T, corner[1] < 0 and "LEFT" or "RIGHT", cx, cy + (corner[2] > 0 and -T / 2 or T / 2))
    Stroke(T, B, corner[2] > 0 and "TOP" or "BOTTOM", cx + (corner[1] < 0 and T / 2 or -T / 2), cy)
  end
  scope.legacy, scope.legacyParts = frame, parts
end

function Core.PaintScope(scope, isGo)
  scope.isGo = isGo == true
  local legacy = Core.db and Core.db.sniperStyle == "legacy"
  local ring, aim = Core.SniperColor(scope.isGo), Core.SniperLayerColor("aim", scope.isGo)
  Theme.Tint(scope.reticle, ring, 1)
  for i, part in ipairs(scope.legacyParts) do Theme.Tint(part, i == 5 and aim or ring, 1) end
  Theme.Tint(scope.skull, Core.SniperLayerColor("skull", scope.isGo), 1)
  Theme.Tint(scope.aim, aim, 1)
  scope.reticle:SetShown(not legacy); scope.aim:SetShown(not legacy)
  scope.skull:SetShown(not legacy and Core.On("sniperSkull"))
  scope.legacy:SetShown(legacy == true)
  scope.parts = legacy and scope.legacyParts or scope.layeredParts
end

function Core.MakeScope(parent, name)
  local scope = CreateFrame("Frame", name, parent)
  scope:SetSize(52, 52)
  scope.urgency = 0
  scope:EnableMouse(false)
  scope:Hide()
  local function Layer(file, layer, size, x, y)
    local texture = scope:CreateTexture(nil, layer)
    texture:SetTexture(ART .. file)
    texture:SetSize(size, size)
    texture:SetPoint("CENTER", scope, "CENTER", x, y)
    return texture
  end
  scope.reticle = Layer("SniperReticle.tga", "BACKGROUND", 52, 0, 0)
  -- Visible skull bounds (alpha > 32) center at (126.5, 123) in the 256px
  -- texture. Compensate for that transparent padding, without lowering it.
  scope.skull = Layer("SniperSkull.tga", "ARTWORK", 30, 30 * 1.5 / 256, -30 * 5 / 256)
  scope.aim = Layer("SniperAim.tga", "OVERLAY", 16, 0, 0)
  scope.layeredParts = { scope.reticle }
  MakeLegacy(scope)
  local group = scope:CreateAnimationGroup()
  group:SetLooping("BOUNCE")
  scope.pulseAnimation = group:CreateAnimation("Alpha")
  scope.pulseAnimation:SetFromAlpha(1)
  scope.pulseAnimation:SetSmoothing("IN_OUT")
  scope.pulse = Core.MotionGroup(group, scope, 1, true)
  function scope:RefreshMotion()
    local pulse = PULSE[self.urgency]
    if self:IsVisible() and Core.On("sniperAnimate") and pulse then
      if self.pulseLevel ~= self.urgency then
        self.pulse:Stop(); self:SetAlpha(1)
        self.pulseAnimation:SetDuration(pulse.duration)
        self.pulseAnimation:SetToAlpha(pulse.alpha)
        self.pulseLevel = self.urgency
      end
      if not self.pulse:IsPlaying() then self.pulse:Play() end
    else
      self.pulse:Stop(); self:SetAlpha(1)
    end
  end
  scope:SetScript("OnShow", function(self)
    Core.PaintScope(self, self.isGo); self:RefreshMotion()
  end)
  scope:SetScript("OnHide", function(self)
    self.pulse:Stop(); self:SetAlpha(1)
  end)
  scopes[#scopes + 1] = scope
  Core.PaintScope(scope, false)
  return scope
end

function Core.RefreshScopes()
  for _, scope in ipairs(scopes) do
    Core.PaintScope(scope, scope.isGo)
    scope:RefreshMotion()
  end
end
Theme.OnChange(Core.RefreshScopes)

Core.sniper = Core.MakeScope(UIParent, "HighgroundSniper")
Core.sniper:SetFrameStrata("HIGH")

-- Lock-on sounds: our own synthesized file first, then SoundKit IDs
-- (see SoundKitConstants.lua).
Core.SNIPER_SOUNDS = {
  ns.Localization.Define({ file = "Interface\\AddOns\\" .. ADDON .. "\\sounds\\lockon.ogg", name = ns.Locale:Get("highground.sniper.highground_lock_on.8cbbfb") }, { name = "highground.sniper.highground_lock_on.8cbbfb" }),
  { id = 3175, name = "ping" }, -- MAP_PING
  { id = 37666, name = "boss whisper" }, -- UI_RAID_BOSS_WHISPER_WARNING
  { id = 12889, name = "alarm" }, -- ALARM_CLOCK_WARNING_3
  { id = 76995, name = "prestige" }, -- UI_PVP_HONOR_PRESTIGE_OPEN_WINDOW
}

function Core.SniperSound()
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
  return snd ~= nil
end

local function SniperSound() if Core.On("sound") then Core.SniperSound() end end

function Core.PlaySniperSound()
  if ns.Util.Notify then ns.Util.Notify("lockon", "target", nil, SniperSound) else SniperSound() end
end

-- Kill-window sting (custom file; raid warning until the client has been
-- restarted once and can see the new file).

local GO_SOUND = "Interface\\AddOns\\" .. ADDON .. "\\sounds\\go.ogg"
function Core.GoSound()
  if not PlaySoundFile(GO_SOUND, "Master") then
    PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master")
  end
end

Core.PlayGoSound = function()
  if ns.Util.Notify then ns.Util.Notify("go", "window", nil, Core.GoSound) else Core.GoSound() end
end

function Core.UpdateSniper(e, isGo)
  local plate = Core.On("sniper") and e and e.plateUnit and C_NamePlate and C_NamePlate.GetNamePlateForUnit
    and C_NamePlate.GetNamePlateForUnit(e.plateUnit)
  if not plate or (plate.IsForbidden and plate:IsForbidden()) or not plate:IsShown() then
    Core.sniper.unit, Core.sniper.entry, Core.sniper.anchor = nil, nil, nil
    Core.sniper:Hide()
    return
  end
  Core.sniper.unit, Core.sniper.entry = e.plateUnit, e
  Core.sniper.urgency = Core.SniperUrgency(e, isGo)
  -- Lock-on sound only when the scope moves to a NEW enemy: the same enemy's
  -- nameplate dropping out and back in stays silent.
  local key = e.key or Core.CanonUnit(e.plateUnit)
  if key and key ~= Core.sniper.soundKey then
    Core.sniper.soundKey = key
    Core.PlaySniperSound()
  end
  Core.PaintScope(Core.sniper, isGo)
  Core.sniper:SetScale(Core.db.sniperScale or 1)
  if not Core.AnchorSniper(plate) then Core.sniper:Hide(); return end
  if not Core.sniper:IsShown() then
    Core.sniper:Show()
  end
  Core.sniper:RefreshMotion()
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

-- /hg sniper test: scope on your current target's nameplate, anywhere
-- (open world, no panel). /hg go toggles the kill-window look while testing.
-- Started/stopped by the command; disabled previews schedule no work.
Core.sniperTest = { on = false, go = false }
Core.sniperDriver = ns.Util.Every(0.1, function()
  local unit = Core.TargetPlateUnit()
  Core.UpdateSniper(unit and { plateUnit = unit } or nil, Core.sniperTest.go)
end, "sniper", "battlegrounds")
Core.sniperDriver:Stop()
