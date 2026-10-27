local _, ns = ...
local Core = ns.Core

-- Target calling. Addons can't send chat during a PvP match (chat messaging
-- lockdown), so we PRE-FILL your chat box and you press Enter: the message is
-- then sent by you, not by addon code.
Core.CALL_CHANNELS = { s = "/s ", i = "/i ", raid = "/raid ", y = "/y ", party = "/p " }
-- Core.callEntry is the current call target, set by Render.
-- Core.killNow is the sticky live target (see PickKillNow).

function Core.CallTarget(e)
  e = e or Core.callEntry
  if not e then
    ns.Util.Say("no kill target to call")
    return
  end
  local name = e.display:match("^[^-]+")
  local si = e.specID and Core.specInfo[e.specID]
  local who = si and (ns.SpecLabel(e, si.name) .. " " .. (LOCALIZED_CLASS_NAMES_MALE[e.class] or e.class))
    or (LOCALIZED_CLASS_NAMES_MALE[e.class] or e.class)
  local extra = ""
  local stacks = Core.CarrierStacks(e)
  if e.carrier and Core.obj.mode == "orb" then
    extra = string.format(" - ORB +%d%%", stacks or 30)
  elseif e.carrier then
    extra = stacks and string.format(" - FLAG CARRIER %d stacks", stacks) or " - FLAG CARRIER"
  elseif e.burnedAt and GetTime() - e.burnedAt < Core.O("goWindow") then
    extra = " - defensive down, GO"
  end
  local msg = string.format("{rt8} KILL %s (%s)%s {rt8}", name, who, extra)
  local open = (ChatFrameUtil and ChatFrameUtil.OpenChat) or ChatFrame_OpenChat
  if open then
    open((Core.CALL_CHANNELS[Core.db.callChannel] or "/s ") .. msg)
  end
end
Highground_Call = function()
  Core.CallTarget()
end
BINDING_NAME_HIGHGROUND_CALL = "Call kill target in chat (press Enter to send)"
