-- Shared building blocks, exercised through every retained host manifest
-- by ui_components.lua.
return function(s, t, fire)
  local K, env = s.ns.Kit, s.env
  local tip = env.GameTooltip

  t.test("tooltips replace their content without stacking hooks and close with their owner", function()
    local button = K.Button(env.UIParent, "Apply", 120, 24)
    local function Count(event) return #(button.hooks[event] or {}) end
    local enter, leave, hide = Count("OnEnter"), Count("OnLeave"), Count("OnHide")
    K.Tooltip(button, { "First", "Old detail" })
    for i = 1, 20 do K.Tooltip(button, { "Refreshed " .. i, "New detail" }) end
    t.equal(Count("OnEnter") - enter, 1, "repeated tooltip setup keeps one hover hook")
    t.equal(Count("OnLeave") - leave, 1, "one leave hook")
    t.equal(Count("OnHide") - hide, 1, "one hide hook")
    fire(button, "OnEnter")
    t.equal(tip.lines[1], "Refreshed 20", "the latest content wins")
    t.equal(#tip.lines, 2, "earlier content is not appended")
    fire(button, "OnLeave"); assert(not tip:IsShown(), "leaving closes the tooltip")

    local other = K.Button(env.UIParent, "Other", 120, 24)
    K.Tooltip(other, function() return { "Other owner" } end)
    fire(button, "OnEnter"); fire(other, "OnEnter")
    fire(button, "OnLeave")
    assert(tip:IsShown() and tip:GetOwner() == other, "leaving one control keeps another owner's tooltip")
    fire(other, "OnLeave")

    fire(button, "OnEnter"); button:Hide()
    assert(not tip:IsShown(), "hiding the owner closes its tooltip")
    button:Show()
    K.Tooltip(button, function() return nil end)
    fire(other, "OnEnter"); fire(button, "OnEnter")
    assert(tip:IsShown() and tip:GetOwner() == other, "empty content shows nothing and keeps the current tooltip")
    fire(other, "OnLeave"); button:Hide(); other:Hide()
  end)
end
