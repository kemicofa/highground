local _, ns = ...
ns.Macros = ns.Macros or {}
local Macros = ns.Macros

---------------------------------------------------------------------------
-- The part of Macros.Host that is the same in every addon embedding the
-- macro tools: the UI kit, codec and helpers this addon loaded. Each
-- addon's macros Host.lua then adds PREFIX, Class, UpdatePlayer, On,
-- Command and Release (Highground: macros/Host.lua; Highground Macros:
-- its own Host.lua).
---------------------------------------------------------------------------
local Host = {}
Macros.Host = Host
local Util = ns.Util

Host.SHARE_TAG = "WBM1" -- export strings; kept so older strings still import
Host.Theme, Host.Kit, Host.Codec = ns.Theme, ns.Kit, ns.Codec
Host.call, Host.value = Util.call, Util.value
Host.Say, Host.Events, Host.ClassColor = Util.Say, Util.Events, Util.ClassColor
Host.Trim, Host.Split, Host.Plural, Host.ClassName = Util.Trim, Util.Split, Util.Plural, Util.ClassName
Host.SpellName, Host.SpellTexture, Host.SpellID = Util.SpellName, Util.SpellTexture, Util.SpellID

-- "retail", "cata", "forever", "classic" or "tbc": which spells and commands exist.
function Host.Game() return ns.GAME end
-- "retail", "cata" or "classic": which API the client has.
function Host.Client() return ns.CLIENT end
-- What a game allows (config/Client.lua), e.g. Host.Can("spellRanks");
-- game defaults to the one running.
function Host.Can(key, game)
  local caps = game and ns.GameCaps and ns.GameCaps[game] or ns.Caps
  return caps ~= nil and caps[key] == true
end
-- A game's name, label, arena size (config/Client.lua ns.Games).
function Host.GameInfo(game) return ns.Games[game or ns.GAME] or {} end

-- Saved settings of the macro tools (macroMode, highestRank, ...).
function Host.Get(key) return ns.Core.db and ns.Core.db[key] end
function Host.Set(key, value) if ns.Core.db then ns.Core.db[key] = value end end
function Host.FontScale() return ns.Core.FontScale() end
function Host.OnFontScaleChange(fn) return ns.Core.OnFontScaleChange(fn) end
