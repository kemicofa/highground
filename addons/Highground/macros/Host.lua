local _, ns = ...
ns.Macros = ns.Macros or {}
local Macros = ns.Macros

---------------------------------------------------------------------------
-- Everything the macro tools take from the addon that hosts them. The other
-- macros/ files use only ns.Macros and this table (tests/simulation/
-- scenarios/macros.lua checks it), so a standalone macro addon replaces
-- this file and macros/Highground.lua (Highground's own catalog entries) and
-- keeps the rest.
---------------------------------------------------------------------------
local Host = {}
Macros.Host = Host
local Core, Util = ns.Core, ns.Util

Host.PREFIX = "Highground" -- frame names: HighgroundMacroFrame, HighgroundMacroShare
Host.SHARE_TAG = "WBM1" -- export strings; keep it so old strings still import
Host.Theme, Host.Kit, Host.Codec = ns.Theme, ns.Kit, ns.Codec
Host.call, Host.value = Util.call, Util.value
Host.Say, Host.Events, Host.ClassColor = Util.Say, Util.Events, Util.ClassColor

-- "retail", "cata" or "forever": which spells and commands exist.
function Host.Game() return ns.GAME end
-- "retail" or "cata": which API the client has.
function Host.Client() return ns.CLIENT end
-- What the game allows (config/Client.lua), e.g. Host.Can("spellRanks").
function Host.Can(key) return ns.Caps and ns.Caps[key] == true end

function Host.Class()
  return Core.me and Core.me.class or select(2, UnitClass("player"))
end
function Host.UpdatePlayer()
  if Core.UpdateMe then pcall(Core.UpdateMe) end
end

-- A feature switch (General settings page); nil = on.
function Host.On(key) return Core.On(key) end

-- Saved account settings the macro tools may write (macroMode).
function Host.Get(key) return Core.db and Core.db[key] end
function Host.Set(key, value) if Core.db then Core.db[key] = value end end

-- /hg <name> [arg].
function Host.Command(name, fn) ns.Commands[name] = fn end

-- The Highground window borrows the macros window; give it back first.
function Host.Release(frame)
  if ns.Hub then ns.Hub.Release(frame) end
end
