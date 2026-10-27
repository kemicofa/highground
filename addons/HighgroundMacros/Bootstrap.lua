local addon, ns = ...

-- Loads first. What Highground's class configuration and core otherwise
-- provide to the shared files: the game, the font folder and an empty Core
-- for the UI kit (ui/Style.lua fills it; Main.lua sets Core.db).
-- Interface number -> ns.CLIENT (which API) and ns.GAME (which content):
--   1150x Classic Era, 2050x The Burning Crusade (Anniversary): classic API;
--   1600x WoW Forever: classic content on the Midnight client;
--   4040x Cataclysm Classic; 12xxxx Retail.
local toc = type(GetBuildInfo) == "function" and select(4, GetBuildInfo()) or 0
if toc < 16000 then
  ns.CLIENT, ns.GAME = "classic", "classic"
elseif toc < 20000 then
  ns.CLIENT, ns.GAME = "retail", "forever"
elseif toc < 30000 then
  ns.CLIENT, ns.GAME = "classic", "tbc"
elseif toc >= 40000 and toc < 50000 then
  ns.CLIENT, ns.GAME = "cata", "cata"
else
  ns.CLIENT, ns.GAME = "retail", "retail"
end
ns.MEDIA = "Interface\\AddOns\\" .. addon .. "\\shared\\media\\"
-- Names the shared files use: chat label, global frame prefix, saved variable.
ns.LABEL, ns.FRAME_PREFIX, ns.SAVED_VARIABLE = "Highground Macros", "HighgroundMacros", "HighgroundMacrosDB"
ns.Core = { me = {} }
