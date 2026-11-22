local _, ns = ...
local C, Win = ns.Onboarding.Coach, ns.Macros.Window

local function MacroWindow()
  local w = Win.Build()
  ns.Hub.Release(w); ns.Kit.Windows.Show(w); C.Native.Track(w)
  C.Native.Fit(w)
  return w
end
local function Catalog()
  local w = MacroWindow()
  if Win.tab ~= "class" then Win.SetTab("class") end
  Win.Refresh()
  return w
end
local function Card()
  local w = Win.win
  for _, row in ipairs(w.rows) do if row:IsVisible() and row.entry then return row end end
end
local function MacroStep(id, title, text, enter, target, hint)
  return { id = id, title = title, text = text, enter = enter, target = target, hint = hint,
    context = function() return Win.win end }
end
function C.MacroSteps()
  local library = MacroStep("library", "Find your saved macros", "Click My macros to see the macros already saved in WoW.",
    Catalog, function() return Win.win.tabs.mine end, "Click My macros.")
  library.requireAction = true; library.advance = function() return Win.tab == "mine" end
  local open = MacroStep("wow", "Open WoW's macro window", "This button opens the game's own macro window. Your saved macros appear there too.",
    function() MacroWindow(); if Win.tab ~= "mine" then Win.SetTab("mine") end end,
    function() return Win.win.open end, "Click Open WoW macros, or continue to read the last step.")
  open.event = "OnClick"
  return {
    MacroStep("class", "Start with For my class", "These are the real presets for your class. Players (PvP) and World (PvE) choose the kind of activity.",
      Catalog, function() return Win.win.tabs.class end),
    MacroStep("preset", "Choose an ability you know", "Read the preset's purpose. Ready to use means its spells are learned; Spell not learned means it may not work yet.",
      Catalog, function() local r = Card(); return r and r.name or Win.win.empty end),
    MacroStep("target", "Choose who receives the ability", "Open the target menu. Focus keeps a second target; mouseover uses the unit under your pointer. This previews a version of the macro.",
      Catalog, function() local r = Card(); return r and r.target:IsVisible() and r.target or r and r.desc or Win.win.empty end,
      function() local r = Card(); return r and not r.target:IsVisible() and "This preset has a fixed target; there is no target menu." or "A focus macro needs a focus set in game first." end),
    MacroStep("save", "Use macro saves it to WoW", "Use macro saves for this character. If it is already saved, the button says Edit macro. Nothing casts when you save.",
      Catalog, function() local r = Card(); return r and r.use or Win.win.empty end,
      "Optional: this is a real save button. Next continues without saving."),
    MacroStep("casting", "Create a spell macro with casting options",
      "Open Create, choose Cast spell and enter an ability. Under Casting options, Stop casting after spell adds /stopcasting at the end. It starts off. The code preview and warning explain the result; Stop my current cast first is a separate choice.",
      MacroWindow, function() return Win.win.tabs.build end,
      "This cannot guarantee instant-only casting or check for a proc. Test with and without the proc in game. Opening Create does not save a macro; your existing draft is kept."),
    library, open,
    MacroStep("bar", "Drag its icon onto your action bar", "In WoW's macro window, select your macro and drag its icon to an action-bar slot. Press that slot's key to use it.",
      MacroWindow, function() return MacroFrame and MacroFrame:IsVisible() and MacroFrame or Win.win.open end,
      "Your key press runs the macro. You can return to this guide anytime."),
  }
end

-- Quick calls use the real battleground panel. Only sends are simulated.
local Quick = ns.QuickCalls
function C.CallSteps()
  local function Context() return Quick.win end
  local function Enter(mode) return function() Quick.StartGuide(mode) end end
  local function Feedback(fallback)
    return function() return Quick.guide and Quick.guide.message and ("Sample: " .. Quick.guide.message) or fallback end
  end
  local function Clicked() return Quick.guide and Quick.guide.message ~= nil end
  return {
    { id = "location", title = "This is the battleground Quick Call panel",
      text = "Farm is your current location in this example. Calls use the location shown here.",
      enter = Enter("local"), context = Context, target = function() return Quick.win.area end,
      feature = "quickCalls", settingLabel = "Enable Quick Call panel in game" },
    { id = "help", title = "Call for two enemies",
      text = "Click 2. In a battleground this immediately tells your team you need help against two enemies at Farm.",
      enter = Enter("local"), context = Context, target = function() return Quick.win.buttons[3] end,
      hint = Feedback("Try 2. This sample sends nothing to chat."), complete = Clicked, event = "OnClick" },
    { id = "clear", title = "Tell your team when it is clear",
      text = "Click All clear when the threat has passed. Help sends a request without an enemy count.",
      enter = Enter("local"), context = Context, target = function() return Quick.win.buttons[5] end,
      hint = Feedback("Try All clear."), complete = Clicked, event = "OnClick" },
    { id = "destination", title = "Choose where enemies are going",
      text = "This optional row calls a destination instead of your location. Choose a base from the menu.",
      enter = Enter("destinations"), context = Context, target = function() return Quick.win.destination end,
      feature = "quickCallsDestinations", settingLabel = "Enable destination calls in game",
      advance = function() return Quick.win.destination:GetValue() ~= "" end, requireAction = true,
      hint = "Click Choose destination, then pick a base." },
    { id = "count", title = "Send the destination and count",
      text = "Click 1, 2 or 3+ below the destination. The call names where those enemies are heading.",
      enter = function()
        if not Quick.guide or Quick.guide.mode ~= "destinations" then Quick.StartGuide("destinations") end
        if Quick.win.destination:GetValue() == "" then Quick.win.destination:SetValue("Blacksmith") end
      end,
      context = Context, target = function() return Quick.win.destinationButtons[2] end,
      hint = Feedback("Try 2 under the destination."), complete = Clicked, event = "OnClick" },
    { id = "carrier", title = "Call the flag carrier's route",
      text = "On flag maps, these buttons report the enemy flag carrier's route. Click the route you observed.",
      enter = Enter("routes"), context = Context, target = function() return Quick.win.routeButtons[1] end,
      feature = "quickCallsRoutes", settingLabel = "Enable flag-carrier calls in game",
      hint = Feedback("Try a route. Sample messages stay here."), complete = Clicked, event = "OnClick" },
  }
end
