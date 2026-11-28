local _, ns = ...
local Options, Kit, L = ns.Options, ns.Kit, ns.Locale
local Profiles = Options.Profiles

---------------------------------------------------------------------------
-- Export and import windows for profiles (options/ProfileList.lua). Export
-- shows one addon's settings of this character as a code, with Share in
-- chat; import keeps a pasted code in the profile list without applying it.
---------------------------------------------------------------------------
function Profiles.AddonLabel(addon) return L:Get("profiles.addon." .. addon) end

local exporter, importer
local function Exporter()
  if exporter then return exporter end
  exporter = Kit.CopyBox("HighgroundProfileExport", { title = L:Get("profiles.share.export_title"), width = 640, height = 380,
    buttons = { { key = "chat", label = L:Get("profiles.share.chat"), onClick = function(c)
      local ok, message = Profiles.Chat.ToChat(c.addon)
      c:SetStatus(message, ok and "success" or "error")
    end } } })
  return exporter
end
local function Importer()
  if importer then return importer end
  importer = Kit.CopyBox("HighgroundProfileImport", { title = L:Get("profiles.share.import_title"), width = 640, height = 380,
    buttons = { { key = "add", label = L:Get("profiles.share.add"), tone = "accent", onClick = function(c)
      local ok, message = ns.CharacterSettings.Import(c:GetText())
      c:SetStatus(message, ok and "success" or "error")
    end } } })
  return importer
end

-- Buttons fit their labels at every text size and language.
local function Fit(c) for _, b in pairs(c.actions) do Kit.FitButton(b, 100) end end
ns.Core.OnFontScaleChange(function()
  for _, c in ipairs({ exporter, importer }) do if c and c:IsShown() then Fit(c) end end
end)

function Profiles.ShowExport(addon)
  local c = Exporter()
  c.addon = addon
  local code = ns.CharacterSettings.Export(addon)
  c:Open(L:Format("profiles.share.export_heading", { addon = Profiles.AddonLabel(addon) }),
    L:Format("profiles.share.export_hint", { name = ns.CharacterSettings.Name() }), code or "", true)
  Fit(c)
  return c
end

function Profiles.ShowImport(text)
  local c = Importer()
  c:Open(L:Get("profiles.share.import_title"), L:Get("profiles.share.import_hint"), text or "")
  Fit(c)
  return c
end
