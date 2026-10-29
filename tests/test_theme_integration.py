"""Exercise the real shared kit through every standalone addon's manifests."""
import subprocess
import unittest

from support import addons


SCENARIO = r'''
local addon, client = arg[1], arg[2]
local new = dofile(addon == "HighgroundBattlegrounds" and "../../tools/wowsim/battleground/runtime.lua"
  or "../../tools/wowsim/runtime.lua")
local saved = { theme = "azeroth", bgAlpha = 0.35, style = { fontScale = 1.2 }, reducedMotion = true }
local function start()
  return new(client, saved, function(s) s.addon = addon end)
end
local sim = start()
local T, Kit, Core = sim.ns.Theme, sim.ns.Kit, sim.ns.Core
local page = assert(sim.ns.StandaloneSettings.frame)
page.Refresh()
assert(T.Current() == "azeroth" and page.themeSelect:GetValue() == "azeroth", "saved theme and picker")
assert(page.motionToggle:GetChecked(), "saved motion preference")
assert(page.fontSize:GetValue() == 120, "saved font size")
page:Show()
page.themeSelect.scripts.OnClick(page.themeSelect)
local menu = assert(Kit.Dropdown.Frame(), "settings picker opens a choice list")
local dialog = Kit.Dialog and Kit.Dialog(nil, { title = "Theme test" }) or menu
local alphaToken = Kit.Dialog and "dialog" or "menu"
dialog:Show()
local painted
dialog.SetBackdropColor = function(_, r, g, b, a) painted = { r, g, b, a } end
local text = T.Text(dialog, "body")
for _, name in ipairs(T.Names()) do
  assert(T.Use(name))
  assert(page.themeSelect:GetValue() == name, "standalone picker follows switch")
  for i = 1, 3 do assert(painted[i] == T.Rgb("bg")[i], "open standalone backdrop repainted") end
  assert(painted[4] == 1, "opaque dialog")
  assert(saved.bgAlpha == 0.35, "explicit HUD opacity preserved")
  assert(text.font[2] == select(2, T.Font("body")) * 1.2, "text scale preserved on switch")
end
assert(T.Register("translucent", { alpha = { dialog = 0.8, menu = 0.7 } }))
T.Use("translucent")
assert(painted[4] == T.Alpha(alphaToken), "surface alpha re-read from tokens")
page.fontSize:SetValue(150)
assert(Core.FontScale() == 1.5 and text.font[2] == select(2, T.Font("body")) * 1.5, "text resizes live")
page.motionToggle:SetChecked(false)
assert(not Core.ReducedMotion(), "motion preference changes")
page.themeSelect:SetValue("parchment")
local again = start()
assert(again.ns.Theme.Current() == "parchment", "theme survives reload")
assert(again.ns.Core.FontScale() == 1.5 and not again.ns.Core.ReducedMotion(), "accessibility settings survive reload")
'''


class ThemeIntegrationTests(unittest.TestCase):
    def test_standalone_settings_and_live_surfaces(self):
        for name, addon in addons.load().items():
            if name == "Highground":
                continue  # Full addon is covered by its combat simulations.
            for client in ("cata", "retail"):
                with self.subTest(addon=name, client=client):
                    result = subprocess.run(
                        ["luajit", "-", name, client], input=SCENARIO,
                        cwd=addon.path, text=True, capture_output=True,
                    )
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
