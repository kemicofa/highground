local addonName, ns = ...
local Catalog, Secret = ns.Catalog, ns.Secret

---------------------------------------------------------------------------
-- /hgprobe unit [token]: call each read-only candidate (Catalog.Candidates)
-- with the unit and record, per return, its type, whether it is secret and
-- its value when readable. Secret values are only described, never compared,
-- converted or saved. Runs over several frames; /reload saves the result.
---------------------------------------------------------------------------
local Probe = {}
ns.Probe = Probe

local PER_TICK, MAX_RETURNS, MAX_FIELDS, MAX_TEXT = 40, 20, 40, 60

local function Say(text)
  print("|cffd4a72cHighground API probe:|r " .. text)
end
Probe.Say = Say

local function SecretTable(v)
  return issecrettable ~= nil and issecrettable(v) == true or canaccesstable ~= nil and canaccesstable(v) == false
end

-- { t = type, s = true when secret, v = readable scalar, k/f = table size and fields }.
local function Describe(v, nested)
  local d = { t = type(v) }
  if Secret(v) then
    d.s = true
  elseif d.t == "string" then
    d.v = #v > MAX_TEXT and v:sub(1, MAX_TEXT) or v
  elseif d.t == "number" or d.t == "boolean" then
    d.v = v
  elseif d.t == "table" then
    if SecretTable(v) then
      d.s = true
    elseif not nested then
      local fields, count = {}, 0
      d.err = not pcall(function()
        for key, value in pairs(v) do
          count = count + 1
          local kind = type(key)
          if count <= MAX_FIELDS and not Secret(key) and (kind == "string" or kind == "number") then
            fields[tostring(key)] = Describe(value, true)
          end
        end
      end) or nil
      d.k, d.f = count, fields
    end
  end
  return d
end
Probe.Describe = Describe

local function Pack(...)
  return select("#", ...), { ... }
end

-- The first result when readable, "secret" when not, nil on error.
local function Read(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, value = pcall(fn, ...)
  if not ok then return nil end
  if Secret(value) then return "secret" end
  return value
end
Probe.Read = Read

local function Context(unit)
  local okInstance, inInstance, kind = pcall(IsInInstance)
  if not okInstance then inInstance, kind = nil, nil end
  return { date = date("%Y-%m-%d %H:%M:%S"), build = ns.Build(), unit = unit,
    zone = Read(GetRealZoneText) or Read(GetZoneText), inInstance = inInstance, instanceType = kind,
    lockdown = C_ChatInfo and Read(C_ChatInfo.InChatMessagingLockdown),
    combat = Read(InCombatLockdown), exists = Read(UnitExists, unit), enemy = Read(UnitCanAttack, "player", unit),
    player = Read(UnitIsPlayer, unit), name = Read(UnitName, unit) }
end
Probe.Context = Context

-- { ok, n = return count, r = described returns } or { ok = false, err }.
function Probe.Invoke(fn, ...)
  local n, r = Pack(pcall(fn, ...))
  local record = { ok = r[1] == true, n = n - 1 }
  if not record.ok then
    local err = r[2]
    record.err = type(err) == "string" and not Secret(err) and err:sub(1, 120) or "error"
    return record
  end
  record.r = {}
  for i = 2, math.min(n, MAX_RETURNS + 1) do record.r[i - 1] = Describe(r[i]) end
  return record
end

local function Call(candidate, unit)
  local args = {}
  args[candidate.unit] = unit
  local record = Probe.Invoke(candidate.fn, unpack(args, 1, candidate.unit))
  record.doc = candidate.documented or nil
  return record
end

-- Readable, non-nil returns (and readable fields of returned tables).
local function PlainCount(record)
  local plain, secret = 0, 0
  for _, d in ipairs(record.r or {}) do
    if d.s then
      secret = secret + 1
    elseif d.t ~= "nil" then
      plain = plain + 1
    end
    for _, field in pairs(d.f or {}) do
      if field.s then secret = secret + 1 end
    end
  end
  return plain, secret
end
Probe.Count = PlainCount

function Probe.Run(unit)
  if Probe.running then return Say("a run is already in progress.") end
  local list = Catalog.Candidates()
  local run = { context = Context(unit), candidates = #list, called = 0, errors = 0, plain = 0, secret = 0, results = {} }
  Probe.running = true
  Say(string.format("calling %d read-only functions with %s ...", #list, unit))
  local i = 0
  local function Finish()
    Probe.running = false
    run.after = Context(unit)
    local runs = HighgroundApiProbeDB.runs
    runs[#runs + 1] = run
    Say(string.format("%d called, %d errors, %d readable and %d secret returns. Type /reload to save.",
      run.called, run.errors, run.plain, run.secret))
  end
  local function Step()
    for _ = 1, PER_TICK do
      i = i + 1
      local candidate = list[i]
      if not candidate then return Finish() end
      local record = Call(candidate, unit)
      run.results[candidate.name] = record
      run.called = run.called + 1
      if not record.ok then run.errors = run.errors + 1 end
      local plain, secret = PlainCount(record)
      run.plain, run.secret = run.plain + plain, run.secret + secret
    end
    C_Timer.After(0, Step)
  end
  Step()
end

function Probe.Summary()
  local db = HighgroundApiProbeDB
  local list = db.list
  if list then
    Say(string.format("list %s: %d functions present, %d documented (%d systems), %d undocumented, docs %s.",
      list.date, list.presentCount or 0, list.documentedCount or 0, list.systems or 0, #(list.undocumented or {}),
      list.docsLoaded and "loaded" or ("missing: " .. tostring(list.docsError))))
  end
  for index, run in ipairs(db.runs) do
    local c = run.context or {}
    Say(string.format("run %d %s %s in %s (%s): %d called, %d errors, %d readable, %d secret.", index, tostring(c.date),
      tostring(c.unit), tostring(c.zone), c.enemy == true and "enemy" or "not enemy", run.called or 0, run.errors or 0,
      run.plain or 0, run.secret or 0))
  end
  local world = ns.World.Summary()
  if not list and #db.runs == 0 and not world then Say("nothing recorded yet.") end
end

local USAGE = "/hgprobe list | unit [token] | world | summary | clear  (token: target, focus, nameplate1, raid3target...)"

SLASH_HGPROBE1 = "/hgprobe"
SlashCmdList.HGPROBE = function(msg)
  local command, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
  command = command:lower()
  if command == "list" then
    local list = Catalog.List()
    Say(string.format("%d functions present, %d documented, %d undocumented. Type /reload to save.",
      list.presentCount, list.documentedCount, #list.undocumented))
  elseif command == "unit" then
    local unit = rest ~= "" and rest or "target"
    if not unit:match("^%a+%d*%a*$") then return Say("not a unit token: " .. unit) end
    Probe.Run(unit)
  elseif command == "world" then
    ns.World.Snapshot()
  elseif command == "summary" then
    Probe.Summary()
  elseif command == "clear" then
    HighgroundApiProbeDB.list, HighgroundApiProbeDB.runs = nil, {}
    HighgroundApiProbeDB.world, HighgroundApiProbeDB.kills = {}, {}
    Say("cleared.")
  else
    Say(USAGE)
  end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, name)
  if name ~= addonName then return end
  self:UnregisterEvent("ADDON_LOADED")
  if type(HighgroundApiProbeDB) ~= "table" then HighgroundApiProbeDB = {} end
  for _, key in ipairs({ "runs", "world", "kills" }) do
    if type(HighgroundApiProbeDB[key]) ~= "table" then HighgroundApiProbeDB[key] = {} end
  end
end)
