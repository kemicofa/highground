local _, ns = ...
local A, U, Theme, Core = ns.Arena, ns.Util, ns.Theme, ns.Core
local call, plain = U.call, U.value
A.ROW_H = A.ROW_H + 38
A.control, A.kicks = {}, {}

function A.BuildActivity(r)
  r.name:SetPoint("RIGHT", -114, 0)
  r.right:ClearAllPoints(); r.right:SetPoint("TOPRIGHT", -7, -28)
  r.trinket:ClearAllPoints(); r.trinket:SetPoint("TOPRIGHT", -52, -9)
  r.number = Theme.Text(r.bar, "code", "accent")
  r.number:SetPoint("TOPLEFT", 7, -3); r.number:SetText("A" .. r.index)
  r.icon:ClearAllPoints(); r.icon:SetPoint("TOPLEFT", 8, -20); r.icon:SetSize(22, 22)
  r.spec:ClearAllPoints(); r.spec:SetPoint("TOPLEFT", 44, -24); r.spec:SetPoint("RIGHT", -110, 0)
  r.cc = r.bar:CreateTexture(nil, "OVERLAY"); r.cc:SetSize(26, 26); r.cc:SetPoint("TOPRIGHT", -82, -9)
  r.ccCD = CreateFrame("Cooldown", nil, r.bar, "CooldownFrameTemplate")
  r.ccCD:SetAllPoints(r.cc); r.ccCD:EnableMouse(false)
  r.ccText = Theme.Text(r.bar, "label", "danger")
  r.ccText:SetPoint("TOPLEFT", 44, -40); r.ccText:SetPoint("RIGHT", -8, 0); r.ccText:SetJustifyH("LEFT")
  r.cast = CreateFrame("StatusBar", nil, r)
  Core.StatusBar(r.cast); r.cast:SetHeight(14)
  r.cast:SetPoint("BOTTOMLEFT", 5, 19); r.cast:SetPoint("BOTTOMRIGHT", -5, 19)
  ns.Timers.BarColor(r.cast, "warning")
  r.castText = Theme.Text(r.cast, "label", "text"); r.castText:SetAllPoints(); r.castText:SetJustifyH("LEFT")
  r.dr = Theme.Text(r.bar, "label", "textMuted")
  r.dr:SetPoint("BOTTOMLEFT", 7, 3); r.dr:SetPoint("RIGHT", -7, 0); r.dr:SetJustifyH("LEFT")
  r.cast:Hide(); r.cc:Hide(); r.ccCD:Hide()
end

local function Cast(r)
  local name, _, _, start, finish = call(UnitCastingInfo, r.unit)
  local channel = type(name) == "nil"
  if channel then name, _, _, start, finish = call(UnitChannelInfo, r.unit) end
  if type(name) == "nil" then r.cast:Hide(); return end
  -- Only display the raw spell text/duration. Restricted values do not
  -- participate in comparisons, arithmetic, ranking or saved records.
  pcall(r.castText.SetText, r.castText, name)
  local duration = call(channel and UnitChannelDuration or UnitCastingDuration, r.unit)
  if type(duration) ~= "nil" and r.cast.SetTimerDuration then
    local direction = Enum and Enum.StatusBarTimerDirection
    if pcall(r.cast.SetTimerDuration, r.cast, duration, 0, direction and
      (channel and direction.RemainingTime or direction.ElapsedTime) or 0) then r.cast:Show(); return end
  end
  start, finish = plain(start), plain(finish)
  if type(start) == "number" and type(finish) == "number" and finish > start then
    r.cast:SetMinMaxValues(0, (finish - start) / 1000)
    r.cast:SetValue(channel and math.max(0, finish / 1000 - GetTime()) or math.max(0, GetTime() - start / 1000))
    r.cast:Show()
  else r.cast:Hide() end
end

local function CrowdControl(r)
  local api, aura = C_UnitAuras, nil
  if ns.CLIENT == "retail" then
    aura = call(api and api.GetAuraDataByIndex, r.unit, 1, "HARMFUL|CROWD_CONTROL")
  elseif ns.ArenaCataData then
    for i = 1, 40 do
      local a = call(api and api.GetAuraDataByIndex, r.unit, i, "HARMFUL")
      if not a then
        local name, icon, _, _, duration, expirationTime, _, _, _, spellId = call(UnitDebuff, r.unit, i)
        if not name then break end
        a = { name = name, icon = icon, duration = duration, expirationTime = expirationTime, spellId = spellId }
      end
      if ns.ArenaCataData.categories[plain(a.spellId) or 0] then aura = a; break end
    end
  end
  if type(aura) ~= "table" then r.cc:Hide(); r.ccCD:Hide(); r.ccText:SetText(""); return end
  pcall(r.cc.SetTexture, r.cc, aura.icon); pcall(r.ccText.SetText, r.ccText, aura.name)
  r.cc:Show(); r.ccCD:Show(); r.ccCD:Clear()
  local duration = call(api and api.GetAuraDuration, r.unit, aura.auraInstanceID)
  if type(duration) ~= "nil" and r.ccCD.SetCooldownFromDurationObject then
    pcall(r.ccCD.SetCooldownFromDurationObject, r.ccCD, duration, true)
  else
    local length, ending = plain(aura.duration), plain(aura.expirationTime)
    if type(length) == "number" and type(ending) == "number" and length > 0 then r.ccCD:SetCooldown(ending - length, length) end
  end
end

function A.ActivityText(unit)
  local guid, now, parts = U.read(UnitGUID, unit), GetTime(), {}
  for category, state in pairs(guid and A.control[guid] or {}) do
    if not state.ends or state.ends > now then
      parts[#parts + 1] = category .. " " .. ({ "50%", "25%", "immune" })[state.level]
        .. (state.ends and (" ~" .. math.ceil(state.ends - now) .. "s") or "")
    else A.control[guid][category] = nil end
  end
  table.sort(parts)
  local kick = guid and A.kicks[guid]
  if kick and kick.ends > now then parts[#parts + 1] = (U.SpellName(kick.id) or "Interrupt") .. " ~" .. math.ceil(kick.ends - now) .. "s" end
  return table.concat(parts, " · ")
end

function A.UpdateActivity(r)
  if not r.cast then return end
  if A.preview then
    r.cast:SetMinMaxValues(0, 1); r.cast:SetValue(0.6); r.castText:SetText("Example cast"); r.cast:Show()
    r.dr:SetText("A" .. r.index .. " · target / focus"); r.cc:Hide(); r.ccCD:Hide(); r.ccText:SetText("")
    return
  end
  Cast(r); CrowdControl(r); r.dr:SetText(A.ActivityText(r.unit))
end

function A.ActivityLog()
  if not (ns.CLIENT == "cata" and A.InArena()) then return end
  local _, sub, _, src, _, _, _, dst, _, _, _, id = CombatLogGetCurrentEventInfo()
  local data, now = ns.ArenaCataData, GetTime()
  if sub == "UNIT_DIED" and dst then A.control[dst], A.kicks[dst] = nil, nil; return end
  if sub == "SPELL_CAST_SUCCESS" and src and data.interrupts[id] then
    A.kicks[src] = { id = id, ends = now + data.interrupts[id] }
  end
  local categories = data.categories[id]
  if not dst or not categories then return end
  if sub ~= "SPELL_AURA_APPLIED" and sub ~= "SPELL_AURA_REFRESH" and sub ~= "SPELL_AURA_REMOVED" then return end
  A.control[dst] = A.control[dst] or {}
  local aura = tostring(src or "") .. ":" .. id
  for _, category in ipairs(categories) do
    local state = A.control[dst][category]
    if sub == "SPELL_AURA_REMOVED" then
      if state and state.active[aura] then
        state.active[aura] = nil
        if not next(state.active) then state.ends = now + data.reset end
      end
    else
      if not state or (state.ends and state.ends <= now) then
        state = { level = 0, active = {} }; A.control[dst][category] = state
      end
      state.active[aura] = true
      state.level, state.ends = math.min(3, state.level + 1), nil
    end
  end
end

local events = { PLAYER_ENTERING_WORLD = function() wipe(A.control); wipe(A.kicks) end }
if ns.CLIENT == "cata" and CombatLogGetCurrentEventInfo then events.COMBAT_LOG_EVENT_UNFILTERED = A.ActivityLog end
U.Events(events, "arena activity")
