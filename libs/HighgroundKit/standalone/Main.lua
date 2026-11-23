local addon, ns = ...
local Core, Util, Theme = ns.Core, ns.Util, ns.Theme

---------------------------------------------------------------------------
-- Start-up of a standalone addon, from its own Main.lua:
--   ns.Standalone.Start({
--     command = "HIGHGROUNDMACROS", slash = { "/hgm", "/hgmacros" },
--     help = { "/hgm pve: ..." },           -- lines for /<cmd> help
--     commands = { name = fn(rest) },       -- /<cmd> name rest
--     default = fn(cmd, rest),              -- anything else (cmd may be "")
--     settings = { hint, keys, buttons },   -- standalone/Settings.lua page
--     onLoad = fn(db),                      -- after the saved variable loads
--   })
-- Every addon also gets /<cmd> help, theme NAME and config. On standby
-- (Highground loaded, standalone/Bootstrap.lua) the command only points to
-- /hg, and nothing else starts.
---------------------------------------------------------------------------
local Standalone = {}
ns.Standalone = Standalone

function Standalone.Refresh()
  if ns.StandaloneSettings then ns.StandaloneSettings.Refresh() end
end

local function Register(spec, handler)
  for i, slash in ipairs(spec.slash) do _G["SLASH_" .. spec.command .. i] = slash end
  SlashCmdList[spec.command] = function(msg) Util.Guard("slash", handler, msg) end
end

local function Standby(spec)
  local text = ns.Locale:Format("shared.main.value1_is_loaded_and_already_has_this.f20b61", { value1 = (ns.STANDBY_LABEL or "Highground"), value3 = (ns.STANDBY_COMMAND or "/hg"), ns_LABEL = ns.LABEL })
  if not ns.STANDBY_LABEL or ns.STANDBY_LABEL == "Highground" then
    text = ns.Locale:Format("shared.main.highground_already_includes_this_feature_recommended_unins.75f576", { addon = addon, value4 = (ns.STANDBY_COMMAND or "/hg") })
  end
  Register(spec, function() Util.Say(text) end)
  -- Once per session; Util.Events registers nothing on standby.
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGIN")
  f:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    Util.Say(text)
  end)
end

-- Shapes of the catalog's saved switches and settings. Damaged values
-- (another type, NaN, out of range) are cleared so their defaults apply.
function Standalone.Schema()
  local schema = {}
  for _, def in ipairs(ns.OptionsConfig.features) do if def.key then schema[def.key] = "boolean" end end
  for _, def in ipairs(ns.OptionsConfig.behavior) do
    if def.key and def.def ~= nil then
      schema[def.key] = type(def.def) == "number" and { type = "number", min = def.min, max = def.max } or type(def.def)
    end
  end
  schema.alerts, schema.positions, schema.windows = "table", "table", "table"
  return schema
end

function Standalone.Start(spec)
  Standalone.spec = spec
  if ns.STANDBY then return Standby(spec) end
  local first = spec.slash[1]
  local help = {}
  for _, line in ipairs(spec.help or {}) do help[#help + 1] = line end
  help[#help + 1] = ns.Locale:Format("shared.main.first_alerts_alert_presets_and_channels.fc7c78", { first = first })
  help[#help + 1] = ns.Locale:Format("shared.main.first_config_settings.9d0ae4", { first = first })
  help[#help + 1] = ns.Locale:Format("shared.main.first_theme_name_value3.7f440f", { first = first, value3 = table.concat(Theme.Names(), ", ") })
  Register(spec, function(msg)
    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    if cmd == "help" or cmd == "?" then
      for _, line in ipairs(help) do Util.Say(line) end
    elseif cmd == "theme" then
      Util.Say(Theme.Use(rest:lower()) and (ns.Locale:Format("highground.settings.theme_value2.85ee12", { value2 = rest:lower() })) or ns.Locale:Get("shared.main.no_such_theme.682b89"))
    elseif cmd == "alerts" and ns.Alerts then
      ns.Alerts.Open()
    elseif cmd == "config" and ns.StandaloneSettings then
      ns.StandaloneSettings.Open()
    elseif spec.commands and spec.commands[cmd] then
      spec.commands[cmd](rest)
    elseif spec.default then
      spec.default(cmd, rest)
    else
      for _, line in ipairs(help) do Util.Say(line) end
    end
  end)
  Util.Events({
    ADDON_LOADED = function(_, name)
      if name ~= addon then return end
      local db = _G[ns.SAVED_VARIABLE]
      local fresh = type(db) ~= "table"
      db = type(db) == "table" and db or {}
      if fresh then ns.ApplyFirstRunDefaults(db)
      else
        if ns.Alerts then ns.Alerts.Upgrade(db, db) end
        ns.Saved.Check(db, Standalone.Schema())
      end
      _G[ns.SAVED_VARIABLE] = db
      Core.db = db
      if ns.Localization then ns.Localization.Initialize(db) end
      Theme.Sync()
      if spec.settings and ns.StandaloneSettings then ns.StandaloneSettings.Page(spec.settings) end
      if spec.onLoad then spec.onLoad(db) end
    end,
  }, "load")
end
