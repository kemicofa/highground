"""Upload an addon ZIP to a Wago Addons project.

https://docs.wago.io/#manual-api-upload
  GET  /api/data/game                        -> {patches: {retail: [...], cata: [...], ...}}
  POST /api/projects/{id}/version            multipart: metadata (JSON), file
Authentication: a Bearer token (a Wago API key).
"""
import uploads

API = "https://addons.wago.io"


def patches(known, names):
    """Wago's supported_<game>_patches fields for these game versions; unknown ones are reported and skipped.

    known: {game: [patch, ...]} from /api/data/game. A version names its game
    (1.60.1 is WoW Forever, 1.15.9 Classic Era), so each goes where Wago lists it.
    """
    fields, missing = {}, []
    for name in names:
        game = next((g for g, listed in known.items() if name in listed), None)
        if game:
            fields.setdefault(f"supported_{game}_patches", []).append(name)
        else:
            missing.append(name)
    if missing:
        print(f"Wago has no game version {', '.join(missing)}; skipped")
    if not fields:
        raise ValueError("None of the TOC game versions exist on Wago: " + ", ".join(names))
    return fields


def known_patches():
    return uploads.request("GET", API + "/api/data/game", {"Accept": "application/json"})["patches"]


def upload(project, token, archive, changelog, label, game_versions):
    """Upload archive as a stable version; returns Wago's reply."""
    metadata = {"label": label, "stability": "stable", "changelog": changelog,
                **patches(known_patches(), game_versions)}
    body, content_type = uploads.multipart(metadata, archive)
    return uploads.request("POST", f"{API}/api/projects/{project}/version",
                           {"Authorization": f"Bearer {token}", "Accept": "application/json",
                            "Content-Type": content_type}, body)
