-- Drive the visible creation steps without bypassing validation or confirmation.
local F = {}
function F.click(button)
  assert(button and button:IsVisible() and button:IsEnabled(), "visible, enabled bounty action")
  button:Click("LeftButton")
end
function F.save(form)
  for _ = 1, 3 do
    F.click(form.action)
    if not form:IsVisible() or form.error:GetText() ~= "" then return end
  end
  error("Bounty creation did not finish in three steps")
end
function F.action(window, label)
  for _, button in ipairs(window.actions) do
    if button:IsShown() and button:GetText() == label then return button end
  end
  error("Missing visible bounty action: " .. label)
end
return F
