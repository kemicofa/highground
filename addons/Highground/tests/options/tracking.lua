-- Per-spell cooldown tracking: switches, search, bulk actions, profiles.
local o = ...
local client, equal = o.client, o.equal
local tracking = client("cata")
local rogue = { class = "ROGUE", cds = { [42292] = 150, [5277] = 150, [51713] = 150 } }
equal(tracking.ui.cooldown(rogue), 14, "all cooldowns start tracked")
local evasion = tracking:track(5277, false)
equal(evasion:GetChecked(), false, "unchecking a spell updates its control")
equal(tracking.db.disabledCooldowns[5277], true, "the spell preference is saved")
equal(tracking.ui.cooldown(rogue), 8, "untracked defensive contributes no score")
equal(tracking.ui.cdLeft(rogue, { 5277 }), nil, "direct clock consumers hide an untracked spell")
equal(tracking.ticks, 1, "changing tracking refreshes the HUD immediately")
for _, entry in ipairs(tracking.ui.kit(rogue)) do assert(entry[1] ~= 5277, "unchecked spell remains in tooltip kit") end
tracking:track(42292, false)
equal(tracking.ui.cooldown(rogue), 0, "untracked trinket contributes no score")
equal(tracking.ns.CooldownTracked(tracking.db, 59752), false, "racial trinket shares its tracking choice")
tracking:track(5277, true)
equal(tracking.db.disabledCooldowns[5277], nil, "re-enabling restores the default preference")
equal(tracking.ui.cooldown(rogue), 6, "re-enabling reuses the observed cooldown")
equal(rogue.cds[5277], 150, "tracking choices preserve observed clocks")

local page = tracking:tracking()
page.search:SetText(" offensive ")
equal(evasion.shown, false, "search filters defensive rows")
local dance = tracking:track(51713, true)
equal(dance.shown, true, "search finds offensive rows")
local untrack = assert(tracking:find("Button", "Untrack shown"))
untrack.scripts.OnClick(untrack)
equal(tracking.db.disabledCooldowns[51713], true, "bulk untrack changes matching spells")
equal(tracking.db.disabledCooldowns[5277], nil, "bulk untrack preserves hidden spell choices")
page.search:SetText("does not exist")
local enable = assert(tracking:find("Button", "Track shown"))
enable.scripts.OnClick(enable)
equal(tracking.db.disabledCooldowns[51713], true, "empty search results make bulk action a no-op")
page.search:SetText("rogue")
enable.scripts.OnClick(enable)
equal(tracking.db.disabledCooldowns[51713], nil, "class search allows enabling its spells")
equal(tracking.db.disabledCooldowns[31884], true, "class bulk action leaves another class alone")
page.search:SetText("")
tracking.db.cooldowns = false
equal(tracking.ui.cdLeft(rogue, { 5277 }), nil, "global cooldown switch also hides direct trinket-style consumers")
tracking.db.cooldowns = true
equal(tracking.db.disabledCooldowns[31884], true, "global feature toggle preserves spell choices")

local saved = client("cata", nil, { [5277] = true })
local savedBox
for _, cb in ipairs(saved:tracking().trackingBoxes) do if cb.spellID == 5277 then savedBox = cb end end
equal(savedBox:GetChecked(), false, "existing tracking preferences appear on first opening settings")
saved.ui.profiles.SaveProfile("Tuning")
saved:track(31884, false)
saved.ui.profiles.LoadProfile("Tuning")
equal(saved.db.disabledCooldowns[31884], true, "loading a tuning profile preserves feature choices")
saved.ui.profiles.ImportText("WB1;f=cata;p.defDown=9")
equal(saved.db.disabledCooldowns[5277], true, "importing old tuning preserves tracking preferences")
saved:find("Button", "Reset tuning").scripts.OnClick()
equal(saved.db.disabledCooldowns[5277], true, "reset tuning preserves tracking preferences")
