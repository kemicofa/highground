---
name: highground-curseforge-copy
description: Keep Highground's CurseForge summary punchy and its description short and feature-focused. Apply whenever addons/Highground/docs/curseforge.md changes, including releases. A player must understand what Highground does at a glance.
---

# Highground CurseForge copy

Applies to the **Summary** and **Description** blocks in `addons/Highground/docs/curseforge.md`. The page sells the addon to a PvP player who has never seen it. Release details belong in `CHANGELOG.md`, help in the guides.

## Glance test

Read only the Summary, the Description's intro and its section headings. A player must be able to say what Highground is (a PvP addon), what it does for them and which games it supports. If not, rewrite before adding anything else.

## Summary

- Plain text, 200 characters at most. The build fails above that. Check with `printf '%s' "<summary>" | wc -m`.
- Hook first: what the player gets in a fight. Then the headline features, then the games (Retail, Forever and Cata).
- Headline features only: battleground intel, arena and duels, nearby enemies, bounties, macros. Pick the ones that fit.
- Never mention languages, translations, performance, fixes, themes, settings, renames, versions or "new".

## Description

- **Intro:** at most two sentences: what Highground is, what it does and which games it supports.
- **Features:** one section per area a player recognizes: Battlegrounds, Arena and duels, Open world, Bounties, Reputation, Macros, the Highground window, and client extras. At most five bullets per section.
- **Bullets:** one line each, about 20 words at most. Start with a bold feature name, then what it does for the player. Name a command only when it is how players reach the feature.
- **Game support:** a short table of real differences between clients. Features that work everywhere share one row.
- **Getting started:** at most five steps from install to first use.
- **Links:** Discord and GitHub.

Leave out:

- Release notes: "now", "no longer", "fixed", "improved", "(new)", refreshed layouts and other change history.
- Performance, memory, saved-data repair and other internals.
- Implementation details, such as the combat log, readable casts, addon messages, channels or saved variables.
- Edge cases, limits and caveats. The guides cover them.
- Defaults, settings paths and individual options, unless a player needs them to find the feature.
- Migration, standalone deprecation and installation minutiae. One line for the Warboard rename is enough.
- Languages, except one bullet in the Highground window section.

## When features change

- A new headline feature gets one bullet in its section. A smaller addition updates an existing bullet or stays in the changelog.
- Remove bullets for features that no longer exist, and fix renamed pages or commands.
- Update the game-support table only when a client difference changes.
- Do not grow the page with each release. If a section exceeds five bullets, merge or cut.

## Style

- Plain words, player view, no hype in the description. Catchy belongs in the Summary only.
- Use the UI's terms: "Highground window", "Bounties", "Nearby", "target marker".
- Check every claim against the current UI and `addons/Highground/docs/commands.md`.
- Name the games "Retail", "WoW Forever" and "Cataclysm Classic".

## Before finishing

1. Run the glance test.
2. Check the Summary length.
3. Search the Description for "now", "no longer", "fixed", "(new)", "language" and setting paths, and remove what slipped in.
4. Run `python3 scripts/build.py Highground` to confirm the version marker and Summary pass.
