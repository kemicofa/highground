local _, ns = ...
local O, Kit, Core = ns.Options, ns.Kit, ns.Core

-- One owner for each settings page. Hub routing and Blizzard settings use
-- these same identities; the feature catalogs already identify switch owners.
O.addonPages = {}
local settings = { nearby = "nearby", bounties = "bounty", reputation = "reputation-settings" }
for i, module in ipairs(ns.Modules.list) do
  local owner = module.key
  local pages = { settings = settings[owner] or owner .. "-settings", previews = owner .. "-previews", commands = owner .. "-commands" }
  if owner ~= "macros" and owner ~= "reputation" then pages.appearance = owner .. "-appearance" end
  O.addonPages[owner] = pages
  for kind, key in pairs(pages) do
    if not ns.OptionsConfig.pages[key] then
      local label = kind == "commands" and "Commands" or kind == "previews" and "Previews and guide" or kind == "appearance" and "Appearance" or "Settings"
      ns.OptionsConfig.pages[key] = { name = module.name .. ": " .. label, module = owner,
        order = 10 + i + (kind == "commands" and 0.3 or kind == "previews" and 0.2 or kind == "appearance" and 0.1 or 0), stepper = false,
        hint = kind == "commands" and "Commands owned by this addon, with controls for each action. /highground works like /hg."
          or kind == "previews" and "Try sample panels or follow the guide. Stop samples when you are done."
          or kind == "appearance" and "Adjust this addon's panels. Shared theme and accessibility settings apply to every addon."
          or "Choose this addon's features and preferences. Changes save automatically." }
    end
  end
end

function O.Link(page, text, action)
  local button = Kit.Button(page.child, text, 300, 32, { onClick = action })
  button:SetPoint("TOPLEFT", 24, page.y)
  button:SetPoint("TOPRIGHT", -24, page.y)
  page.y = page.y - 44
  page.child:SetHeight(-page.y + 12)
  return button
end

function O.AddAlertControls(page, owner)
  local definitions = {}
  for _, def in ipairs(ns.Alerts.categories) do
    if def.module == owner then definitions[#definitions + 1] = def end
  end
  if #definitions == 0 then return end
  O.Section(page, "Alerts", "Text and sound follow your shared alert level and master sound preference.")
  page.alertRows = {}
  for _, def in ipairs(definitions) do
    local row = { key = def.key }
    local label = ns.Theme.Text(page.child, "body", "text")
    label:SetPoint("TOPLEFT", 24, page.y - 4); label:SetWidth(210)
    label:SetJustifyH("LEFT"); label:SetText(def.label)
    for i, channel in ipairs({ "text", "sound" }) do
      row[channel] = Kit.Toggle(page.child, channel == "text" and "Text" or "Sound", { width = 115,
        onChange = function(_, on)
          local prefs = ns.Alerts.Settings()
          prefs.channels[def.key] = prefs.channels[def.key] or {}
          prefs.channels[def.key][channel] = on
        end })
      row[channel]:SetPoint("TOPLEFT", 250 + (i - 1) * 140, page.y)
    end
    page.alertRows[#page.alertRows + 1] = row
    page.y = page.y - 44
  end
  O.Link(page, "Shared alert level and sound", function() ns.Hub.Open("alerts") end)
  local refresh = page.RefreshBehavior
  page.RefreshBehavior = function()
    if refresh then refresh() end
    local prefs = ns.Alerts.Settings()
    for _, row in ipairs(page.alertRows) do
      local channels = prefs.channels[row.key] or {}
      row.text:SetChecked(channels.text ~= false, true); row.sound:SetChecked(channels.sound ~= false, true)
      row.sound:SetEnabled(ns.Alerts.AllowedFor({ mode = prefs.mode }, row.key, "sound", Core.On("sound")))
      row.text:SetEnabled(ns.Alerts.AllowedFor({ mode = prefs.mode }, row.key, "text", true))
    end
  end
end
