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
OPEN_PR = "fallback in a file with open cleanup work; move to ns.Api after it merges"

# path -> (moved globals read there, reason)
ALLOWED = {
    "addons/Highground/core/Modules.lua": (
        {"DisableAddOn", "EnableAddOn", "GetAddOnEnableState", "GetAddOnMetadata", "SaveAddOns"}, LOADS_BEFORE_API),
    "libs/HighgroundKit/standalone/Bootstrap.lua": ({"GetAddOnMetadata", "IsAddOnLoaded"}, LOADS_BEFORE_API),
    "addons/HighgroundNearby/Host.lua": ({"IsAddOnLoaded"}, LOADS_BEFORE_API),
    "addons/Highground/options/Register.lua": (
        {"InterfaceOptionsFrame_OpenToCategory", "InterfaceOptions_AddCategory"}, LEGACY),
    "libs/HighgroundKit/standalone/Settings.lua": (
        {"InterfaceOptionsFrame_OpenToCategory", "InterfaceOptions_AddCategory"}, LEGACY),
    "addons/HighgroundReputation/src/reputation/Menus.lua": (
        {"UIDropDownMenu_AddButton", "UIDropDownMenu_CreateInfo"}, LEGACY),
    "addons/HighgroundBattlegrounds/src/map/Flags.lua": (
        {"GetBattlefieldFlagPosition", "GetNumBattlefieldFlagPositions"}, LEGACY),
    "addons/HighgroundMacros/src/macros/Sources.lua": ({"UnitBuff"}, LEGACY),
    # Chat fallback used only where addon channels are unavailable (Cata).
    "libs/HighgroundKit/core/ProtocolTransport.lua": ({"SendChatMessage"}, LEGACY),
    "addons/HighgroundBattlegrounds/src/timers/Mechanics.lua": ({"GetNumWorldStateUI", "GetWorldStateUIInfo"}, LEGACY),
    "addons/HighgroundArena/src/arena/Activity.lua": ({"UnitDebuff"}, LEGACY),
    "addons/HighgroundMacros/src/macros/Suggest.lua": (
        {"GetNumSpellTabs", "GetSpellBookItemName", "GetSpellTabInfo", "IsPassiveSpell"}, LEGACY),
    "addons/HighgroundMacros/src/macros/Ranks.lua": (
        {"GetSpellInfo", "GetSpellSubtext", "IsHelpfulSpell", "PickupSpell", "SpellHasRange"}, OPEN_PR),
    "addons/HighgroundMacros/src/macros/Frame.lua": ({"LoadAddOn"}, OPEN_PR),
    "addons/HighgroundBattlegrounds/src/core/Objectives.lua": ({"IsRatedBattleground"}, OPEN_PR),
    "addons/Highground/core/PeerTransport.lua": ({"SendChatMessage"}, OPEN_PR),
    "addons/HighgroundReputation/src/reputation/Filtering.lua": ({"SendChatMessage"}, OPEN_PR),
    "libs/HighgroundKit/bounty/Alerts.lua": ({"SendChatMessage"}, OPEN_PR),
    "libs/HighgroundKit/bounty/PublicTransport.lua": ({"SendChatMessage"}, OPEN_PR),
    "libs/HighgroundKit/bounty/Portraits.lua": ({"GetAtlasInfo"}, OPEN_PR),
    "libs/HighgroundKit/ui/kit/Controls.lua": ({"GetAtlasInfo"}, OPEN_PR),
    "libs/HighgroundKit/core/Util.lua": ({"GetSpellInfo", "GetSpellTexture"}, OPEN_PR),
    "libs/HighgroundKit/pvp/Matches.lua": ({"GetSpecialization", "GetSpecializationInfo"}, OPEN_PR),
    "libs/HighgroundKit/social/Guild.lua": ({"GuildRoster"}, OPEN_PR),
    "libs/HighgroundKit/social/Organizations.lua": ({"LoadAddOn"}, OPEN_PR),
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
