local _, ns = ...
local Macros = ns.Macros
local Host = Macros.Host

---------------------------------------------------------------------------
-- Highground's half of Macros.Host (the shared half: macros/HostBase.lua).
-- The other macros/ files use only ns.Macros and Macros.Host
-- (tests/simulation/scenarios/macroranks.lua checks it), so Highground
-- Macros swaps this file for its own Host.lua and leaves out
-- macros/Highground.lua (Highground's own catalog entries).
---------------------------------------------------------------------------
local Core, Util = ns.Core, ns.Util

Host.PREFIX = "Highground" -- frame names: HighgroundMacroFrame, HighgroundMacroShare

function Host.Class()
  return Core.me and Core.me.class or select(2, UnitClass("player"))
end
function Host.UpdatePlayer() Util.call(Core.UpdateMe) end

-- A feature switch (General settings page); nil = on.
function Host.On(key) return Core.On(key) end

-- /hg <name> [arg].
function Host.Command(name, fn) ns.Commands[name] = fn end

-- The Highground window borrows the macros window; give it back first.
function Host.Release(frame)
  if ns.Hub then ns.Hub.Release(frame) end
end
