local _, ns = ...
local Macros = ns.Macros
local Host = Macros.Host

---------------------------------------------------------------------------
-- Highground Macros' half of Macros.Host (the shared half:
-- src/macros/HostBase.lua), backed by HighgroundMacrosDB and /hgm.
---------------------------------------------------------------------------
local Core = ns.Core

Host.PREFIX = ns.FRAME_PREFIX

function Host.Class() return select(2, UnitClass("player")) end
function Host.UpdatePlayer() end

-- Switches (highestRank, highestRankMacros): standalone/Core.lua.
Host.On = Core.On

-- Commands the shared files register; Main.lua routes /hgm to "macros".
Host.commands = {}
function Host.Command(name, fn) Host.commands[name] = fn end

function Host.Release() end
