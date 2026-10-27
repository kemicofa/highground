local _, ns = ...
local Macros = ns.Macros
local Host = Macros.Host

---------------------------------------------------------------------------
-- Highground Macros' half of Macros.Host (the shared half:
-- shared/macros/HostBase.lua), backed by HighgroundMacrosDB and /hgm.
---------------------------------------------------------------------------
local Core = ns.Core

Host.PREFIX = "HighgroundMacros"

function Host.Class() return select(2, UnitClass("player")) end
function Host.UpdatePlayer() end

-- Switches (highestRank, highestRankMacros) are on unless set to false.
function Host.On(key) return not (Core.db and Core.db[key] == false) end

-- Commands the shared files register; Main.lua routes /hgm to "macros".
Host.commands = {}
function Host.Command(name, fn) Host.commands[name] = fn end

function Host.Release() end
