"""Moved WoW APIs go through ns.Api (libs/HighgroundKit/config/Client.lua).

Retail and WoW Forever (the Midnight client) moved many globals into C_
namespaces and removed or deprecated the old names; Cataclysm Classic has most
namespaces too. Runtime code calls ns.Api, or reads a moved global only where
listed below with its reason. New direct reads fail; so do stale entries.
"""
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

from support import ROOT

# Globals that are removed, moved or deprecated on Retail and WoW Forever.
MOVED = {
    "GetSpellInfo", "GetSpellTexture", "GetSpellCooldown", "GetSpellCharges", "GetSpellLink",
    "GetSpellSubtext", "IsSpellKnown", "IsPassiveSpell", "IsHelpfulSpell", "IsHarmfulSpell",
    "SpellHasRange", "PickupSpell", "GetNumSpellTabs", "GetSpellTabInfo", "GetSpellBookItemName",
    "GetSpellBookItemInfo", "GetAddOnMetadata", "IsAddOnLoaded", "LoadAddOn", "EnableAddOn",
    "DisableAddOn", "SaveAddOns", "GetAddOnEnableState", "GetAddOnInfo", "GetNumAddOns",
    "GetItemInfo", "GetItemCount", "GetItemIcon", "IsEquippedItem", "UnitAura", "UnitBuff",
    "UnitDebuff", "GetContainerNumSlots", "GetContainerItemID", "GetContainerItemInfo",
    "UseContainerItem", "PickupContainerItem", "InterfaceOptions_AddCategory",
    "InterfaceOptionsFrame_OpenToCategory", "EasyMenu", "GetMouseFocus", "GuildRoster",
    "SendChatMessage", "GetSpecialization", "GetSpecializationInfo",
    "GetNumSpecializationsForClassID", "IsRatedBattleground", "GetAtlasInfo",
    "GetMerchantItemInfo", "GetWorldStateUIInfo", "GetNumWorldStateUI", "UIDropDownMenu_AddButton",
    "UIDropDownMenu_CreateInfo", "UIDropDownMenu_Initialize", "ToggleDropDownMenu", "GetCVar",
    "SetCVar", "GetNumBattlefieldFlagPositions", "GetBattlefieldFlagPosition",
}

LOADS_BEFORE_API = "loads before libs/config/Client.lua"
LEGACY = "older-client branch after the modern API"

# path -> (moved globals read there, reason)
ALLOWED = {
    "addons/Highground/core/Modules.lua": (
        {"DisableAddOn", "EnableAddOn", "GetAddOnEnableState", "GetAddOnMetadata", "SaveAddOns"}, LOADS_BEFORE_API),
    "addons/Highground/options/Register.lua": (
        {"InterfaceOptionsFrame_OpenToCategory", "InterfaceOptions_AddCategory"}, LEGACY),
    "addons/Highground/features/reputation/reputation/Menus.lua": (
        {"UIDropDownMenu_AddButton", "UIDropDownMenu_CreateInfo"}, LEGACY),
    "addons/Highground/features/battlegrounds/map/Flags.lua": (
        {"GetBattlefieldFlagPosition", "GetNumBattlefieldFlagPositions"}, LEGACY),
    "addons/Highground/features/macros/macros/Sources.lua": ({"UnitBuff"}, LEGACY),
    # Chat fallback used only where addon channels are unavailable (Cata).
    "libs/HighgroundKit/core/ProtocolTransport.lua": ({"SendChatMessage"}, LEGACY),
    # Hooks (does not call) the legacy global to notice manual whispers.
    "libs/HighgroundKit/core/Comms.lua": ({"SendChatMessage"}, LEGACY),
    "addons/Highground/features/battlegrounds/timers/Mechanics.lua": ({"GetNumWorldStateUI", "GetWorldStateUIInfo"}, LEGACY),
    "addons/Highground/features/arena/arena/Activity.lua": ({"UnitDebuff"}, LEGACY),
    "addons/Highground/features/macros/macros/Suggest.lua": (
        {"GetNumSpellTabs", "GetSpellBookItemName", "GetSpellTabInfo", "IsPassiveSpell"}, LEGACY),
}


def runtime_files():
    listed = subprocess.check_output(["git", "-C", str(ROOT), "ls-files", "-z", "--", "addons", "libs"])
    for name in listed.decode().split("\0"):
        if name.endswith(".lua") and "/tests/" not in name:
            yield name


def global_reads(path):
    """Global names a Lua 5.1 chunk reads (LuaJIT bytecode GGET)."""
    # The listing quotes string constants byte for byte; Lua strings need not be UTF-8.
    listing = subprocess.run(["luajit", "-bl", str(ROOT / path)], capture_output=True, check=True).stdout
    listing = listing.decode("latin-1")
    names = set()
    for line in listing.splitlines():
        if " GGET " in line and '"' in line:
            names.add(line.split('"')[1])
    return names


@unittest.skipUnless(shutil.which("luajit"), "requires LuaJIT")
class ApiCompatTests(unittest.TestCase):
    def test_reads_files_with_raw_bytes(self):
        with tempfile.TemporaryDirectory() as tmp:
            chunk = Path(tmp) / "raw.lua"
            chunk.write_bytes(b'local lead = "[\xc0-\xff][\x80-\xbf]*"\nreturn GetSpellInfo(lead), "\xc3\xa9\xff"\n')
            self.assertEqual(global_reads(chunk), {"GetSpellInfo"})

    def test_moved_globals_go_through_ns_api(self):
        found = {}
        for path in runtime_files():
            moved = global_reads(path) & MOVED
            if moved:
                found[path] = moved
        for path, moved in sorted(found.items()):
            allowed = ALLOWED.get(path, (set(), None))[0]
            with self.subTest(path=path):
                self.assertFalse(moved - allowed, f"{path}: call ns.Api for {sorted(moved - allowed)}")
        for path, (allowed, _) in sorted(ALLOWED.items()):
            with self.subTest(stale=path):
                self.assertFalse(allowed - found.get(path, set()), f"{path}: drop {sorted(allowed - found.get(path, set()))} from ALLOWED")


if __name__ == "__main__":
    unittest.main()
