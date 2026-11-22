"""Reviewed in-game assets and their runtime users; unlisted extras fail closed.

An asset must be listed here, have its reader loaded by the addon's TOC/XML,
and still be named in that reader. Dynamic names (guide logos and stealth
sounds) name the literal selected by their reader. Promotional exports and
editable artwork belong outside addon packages, even inside a media folder.
"""
import re


# Source paths are repository-relative, after resolving package symlinks.
# Each (reader, literal) must be present in this particular addon's runtime.
ASSETS = {
    **{f"libs/HighgroundKit/bounty/media/{name}": (("libs/HighgroundKit/bounty/PosterStyle.lua", name),)
       for name in ("WantedDisplay.ttf", "WantedName.ttf", "WantedCaption.ttf", "WantedPaper.tga", "WantedScroll.tga")},
    **{f"libs/HighgroundKit/media/{name}": (("libs/HighgroundKit/ui/Style.lua", name),)
       for name in ("BarlowCondensed-Bold.ttf", "BarlowCondensed-SemiBold.ttf",
                    "BarlowCondensed-Medium.ttf", "JetBrainsMono-Bold.ttf",
                    "HighgroundCrest.tga", "HighgroundIcon.tga", "ControlCorners.tga", "ProgressCircle.tga")},
    **{f"libs/HighgroundKit/sounds/{name}.ogg": (("libs/HighgroundKit/core/Stealth.lua", name),)
       for name in ("stealth-enter", "stealth-exit")},
    "libs/HighgroundKit/sounds/nearby.ogg": (("libs/HighgroundKit/world/Nearby.lua", "nearby.ogg"),),
    "addons/HighgroundBounties/src/sounds/bounty.ogg": (("libs/HighgroundKit/bounty/Alerts.lua", "bounty.ogg"),),
    **{f"addons/Highground/sounds/{name}.ogg": (("addons/Highground/ui/Sniper.lua", f"{name}.ogg"),)
       for name in ("go", "lockon")},
    **{f"addons/Highground/assets/logos/{name}.tga": (
           ("addons/Highground/hub/TourSteps.lua", f"logo={name}"),
           ("addons/Highground/hub/TourView.lua", ".tga"))
       for name in ("Highground", "Arena", "Battlegrounds", "Bounties", "Macros", "Nearby", "Reputation")},
}

# Licenses and source notices accompany their used assets, not arbitrary media.
NOTICES = {
    "libs/HighgroundKit/bounty/media/OFL-wanted.txt": "libs/HighgroundKit/bounty/media/WantedDisplay.ttf",
    "libs/HighgroundKit/media/OFL-barlow.txt": "libs/HighgroundKit/media/BarlowCondensed-Bold.ttf",
    "libs/HighgroundKit/media/OFL-jb.txt": "libs/HighgroundKit/media/JetBrainsMono-Bold.ttf",
    "libs/HighgroundKit/media/HighgroundCrest.txt": "libs/HighgroundKit/media/HighgroundCrest.tga",
    "libs/HighgroundKit/sounds/stealth.txt": "libs/HighgroundKit/sounds/stealth-enter.ogg",
    "libs/HighgroundKit/sounds/nearby.txt": "libs/HighgroundKit/sounds/nearby.ogg",
}

# Match strings before looking for another comment, so '--' inside strings is
# preserved. Commented-out references cannot keep an obsolete asset approved.
TOKENS = re.compile(r'''--\[(?P<level>=*)\[.*?\](?P=level)\]|--[^\n]*|<!--.*?-->|(?P<string>"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')''', re.S)


def literal_names(source):
    """Quoted filenames/choices and field=value uses, excluding comments."""
    text = TOKENS.sub(lambda match: match['string'] or ' ', source.read_text())
    names = set()
    for match in TOKENS.finditer(text):
        value = match['string'][1:-1].replace('\\\\', '/').rsplit('/', 1)[-1]
        names.add(value)
        field = re.search(r'\b(\w+)\s*=\s*$', text[:match.start()])
        if field:
            names.add(f'{field[1]}={value}')
    return names


def validate(addon, files, runtime):
    """Allow loaded code, addon documentation, and assets with loaded users."""
    base = addon.path
    root = base.resolve().parent.parent
    sources = {path: (base / path).resolve().relative_to(root).as_posix() for path in files}
    loaded = {sources[path] for path in runtime if path.suffix in {'.toc', '.lua', '.xml'}}
    literals = {}
    for path, source in sources.items():
        if path in runtime and path.suffix in {'.toc', '.lua', '.xml'}:
            continue
        if path.as_posix() in {'README.md', 'CHANGELOG.md', 'LICENSE'} or (
                path.parts[0] == 'docs' and path.suffix == '.md'):
            continue
        if source in NOTICES and NOTICES[source] in sources.values():
            continue
        readers = ASSETS.get(source)
        if not readers:
            raise ValueError(f"{addon.name}: unapproved package asset: {path}")
        for reader, literal in readers:
            if reader not in loaded:
                raise ValueError(f"{addon.name}: unused package asset {path}; reader is not loaded: {reader}")
            if reader not in literals:
                literals[reader] = literal_names(root / reader)
            if literal not in literals[reader]:
                raise ValueError(f"{addon.name}: unused package asset {path}; no runtime reference in {reader}")
