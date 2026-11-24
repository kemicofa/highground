local _, ns = ...
local Timers, Flags, Kit, Theme, Core = ns.Timers, ns.Flags, ns.Kit, ns.Theme, ns.Core

---------------------------------------------------------------------------
-- /hgbg test: the resurrection, objective and flag carrier windows with
-- sample rows (those switched on), to place them outside battlegrounds and
-- out of combat. Click or type again to stop; a battleground starting ends
-- it (timers/Driver.lua).
---------------------------------------------------------------------------
local Preview = {}
ns.BattlegroundsPreview = Preview

local SAMPLE_CARRIERS = { mine = { "Aldric", "PALADIN", 0.82, "x2  0:41" }, theirs = { "Vexa", "ROGUE", 0.31, "x2  0:37" } }

local function ResurrectionRows(me, them)
  return {
    Timers.Tag({ team = me, color = Timers.TeamColor(me), text = ns.Locale:Get("battlegrounds.preview.stables.4f2cd9"), left = 12, total = 30 }, "YOU"),
    Timers.Tag({ team = me, color = Timers.TeamColor(me), text = ns.Locale:Get("battlegrounds.preview.farm.c3215b"), left = 12, total = 30 }, "OURS"),
    Timers.Tag({ team = them, color = Timers.TeamColor(them), text = ns.Locale:Get("battlegrounds.preview.blacksmith.191a40"), left = 23, total = 30, est = true }, "THEIRS"),
  }
end

local function ObjectiveRows(me, them)
  local name = { A = "Alliance", H = "Horde" }
  return {
    Timers.Tag({ team = me, color = Timers.TeamColor(me), frac = 0.72, time = "3:10", text = name[me] .. "  1500-1180" }, "WIN"),
    Timers.Tag({ team = them, color = Timers.TeamColor(them), text = ns.Locale:Get("battlegrounds.arathibasin.lumber_mill.c02615"), left = 38, total = 60 }, "CAP"),
    Timers.Tag({ color = Theme.Rgb("white"), text = ns.Locale:Get("battlegrounds.objectives.respawn.5a0bd4"), left = 8, total = 11 }, "FLAG"),
    Timers.Tag({ team = them, color = Timers.TeamColor(them), text = ns.Locale:Get("battlegrounds.preview.vexa_gold_mine.895476"), left = 4, total = 8 }, "CAPPING"),
  }, Timers.Hex(Timers.TeamColor(me)) .. "1080|r  " .. Timers.Hex(Timers.TeamColor(them)) .. "940|r"
end

-- Sample carriers in the flag window (its rows are secure: out of combat).
local function ShowCarriers(me, them)
  Flags.BuildFlags()
  if not Flags.flagWin then return end
  wipe(Flags.carriers)
  for _, r in ipairs(Flags.frows) do
    local s = SAMPLE_CARRIERS[r.side]
    r.team = r.side == "mine" and me or them
    Kit.ClassIcon(r.icon, s[2])
    Flags.Crest(r, true)
    local color = ns.Util.ClassColor(s[2])
    ns.Hud.PaintEnemy(r.classBg, color); ns.Hud.PaintClass(r.name, color)
    r.name:SetText(s[1])
    ns.Hud.Health(r.bar, nil, false, s[3])
    Timers.BarColor(r.bar, color and Core.BarColor(color, r.team, s[3]) or Timers.TeamColor(r.team), 1)
    ns.Hud.HealthText(r.hpText, nil, s[3], true)
    r.hpText:Show(); r.healthTextBg:SetShown(not Timers.Compact())
    r.right:SetText(s[4])
    Theme.Paint(r.right, "textMuted")
  end
  -- No real carriers: the rows' macros fall back to the arena tokens.
  Flags.SetMacros()
  Timers.SecureShow(Flags.flagWin)
end

-- Secure carrier rows only show and hide out of combat.
function Preview.Allowed()
  return not (InCombatLockdown() or Flags.InBG())
end

function Preview.Start(guided)
  if ns.Modules and not ns.Modules.Require("battlegrounds") then return false end
  if not Preview.Allowed() then return false end
  Timers.previewing = true
  local me = Timers.MyTeam()
  local them = Timers.Other(me)
  local res, obj = Timers.Windows()
  if guided or Core.On("timers") then
    Timers.ShowRows(res, ResurrectionRows(me, them))
    if guided or Core.On("objectives") then
      -- The sample capture arrives after opening, so it flashes like a live one.
      local rows, info = ObjectiveRows(me, them)
      local capping = table.remove(rows)
      Timers.ShowRows(obj, rows, info)
      rows[#rows + 1] = capping
      Timers.ShowRows(obj, rows, info)
    end
  end
  if guided or Core.On("flags") then ShowCarriers(me, them) end
  ns.PvPEvents.Refresh() -- a battleground or arena ends the preview (timers/Driver.lua)
  if ns.QuickCalls then ns.QuickCalls.Update() end
  return true
end

function Preview.Stop()
  if InCombatLockdown() then return false end
  Timers.previewing = nil
  Timers.HideWindows()
  Timers.SecureHide(Flags.flagWin)
  ns.PvPEvents.Refresh()
  if ns.QuickCalls then ns.QuickCalls.Update() end
  return true
end

-- Returns whether the preview is showing now, and whether that changed.
function Preview.Toggle()
  if Timers.previewing then
    local stopped = Preview.Stop()
    return not stopped, stopped
  end
  local started = Preview.Start()
  return started, started
end
