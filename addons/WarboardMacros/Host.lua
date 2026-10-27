local _, ns = ...
ns.Macros = ns.Macros or {}
local Macros = ns.Macros

---------------------------------------------------------------------------
-- The macro tools' host when they run on their own: the same table as
-- Warboard's macros/Host.lua, backed by WarboardMacrosDB and /wbm.
---------------------------------------------------------------------------
local Host = {}
Macros.Host = Host
local Core, Util = ns.Core, ns.Util

Host.PREFIX = "WarboardMacros"
Host.SHARE_TAG = "WBM1" -- the same strings as Warboard's macros window
Host.Theme, Host.Kit, Host.Codec = ns.Theme, ns.Kit, ns.Codec
Host.call, Host.value = Util.call, Util.value
Host.Say, Host.Events, Host.ClassColor = Util.Say, Util.Events, Util.ClassColor

function Host.Game() return ns.GAME end
function Host.Client() return ns.CLIENT end
function Host.Can(key) return ns.Caps and ns.Caps[key] == true end
function Host.Class() return select(2, UnitClass("player")) end
function Host.UpdatePlayer() end

-- Switches (highestRank, highestRankMacros) are on unless set to false.
function Host.On(key) return not (Core.db and Core.db[key] == false) end
function Host.Get(key) return Core.db and Core.db[key] end
function Host.Set(key, value) if Core.db then Core.db[key] = value end end

-- Commands the shared files register; Main.lua routes /wbm to "macros".
Host.commands = {}
function Host.Command(name, fn) Host.commands[name] = fn end

function Host.Release() end
