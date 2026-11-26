local _, ns = ...
local Core = ns.Core

-- Target calling. Addons can't send chat during a PvP match (chat messaging
-- lockdown), so we PRE-FILL your chat box and you press Enter: the message is
-- then sent by you, not by addon code.
Core.CALL_CHANNELS = { s = "/s ", i = "/i ", raid = "/raid ", y = "/y ", party = "/p " }
-- Core.callEntry is the current call target, set by Render.
-- Core.killNow is the sticky live target (see PickKillNow).

function Core.CallTarget(e)
  if Core.guidedTest then return end
  e = e or Core.callEntry
  if not e then
    ns.Util.Say(ns.Locale:Get("highground.calling.no_kill_target_to_call.ce45a3"))
    return
  end
  local name = Core.ShortName(e)
  local who = Core.ClassName(e)
  local extra = ""
  local stacks = Core.CarrierStacks(e)
  if e.carrier and Core.obj.mode == "orb" then
    extra = ns.Locale:Format("highground.calling.orb_value1.9ffb19", { value1 = string.format("%d", stacks or 30) })
  elseif e.carrier then
    extra = stacks and ns.Locale:Format("highground.calling.flag_carrier_stacks_stacks.6750d7", { stacks = string.format("%d", stacks) }) or ns.Locale:Get("highground.calling.flag_carrier.6cbcf8")
  elseif e.burnedAt and GetTime() - e.burnedAt < Core.O("goWindow") then
    extra = ns.Locale:Get("highground.calling.defensive_down_go.56bc07")
  end
  local msg = ns.Locale:Format("highground.calling.rt8_kill_name_who_extra_rt8.36ac69", { marker = "{rt8}", name = string.format("%s", name), who = string.format("%s", who), extra = string.format("%s", extra) })
  local open = (ChatFrameUtil and ChatFrameUtil.OpenChat) or ChatFrame_OpenChat
  if open then
    open((Core.CALL_CHANNELS[Core.db.callChannel] or "/s ") .. msg)
  end
end
-- Shift-click shares (timers, forecast, flag carriers) use the same
-- channel. Text goes into the chat box you're typing in, or opens one.
function Core.ShareInChat(text)
  local ok, problem = ns.Chat.Draft(text, Core.CALL_CHANNELS[Core.db.callChannel] or "/s ")
  if not ok then
    ns.Util.Say(problem == "full" and ns.Locale:Get("battlegrounds.share.full") or ns.Locale:Get("shared.share.chat_is_not_available.20aba3"))
  end
  return ok
end
Highground_Call = function()
  Core.CallTarget()
end
ns.Localization.Define(_G, { BINDING_NAME_HIGHGROUND_CALL = "highground.calling.call_kill_target_in_chat_press_enter.1771a4" })
