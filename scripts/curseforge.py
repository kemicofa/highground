"""Upload an addon ZIP to a CurseForge project with the upload API.

https://support.curseforge.com/support/solutions/articles/9000197321-curseforge-api
  GET  /api/game/versions                    -> [{id, gameVersionTypeID, name, slug}]
  POST /api/projects/{id}/upload-file        multipart: metadata (JSON), file
Authentication: the X-Api-Token header (a CurseForge API token).
"""
import uploads

API = "https://wow.curseforge.com"


def request(method, path, token, body=None, headers=None):
    return uploads.request(method, API + path, {"X-Api-Token": token, **(headers or {})}, body)


def game_version_ids(token, names):
    """CurseForge IDs of these game version names; names CurseForge doesn't know are reported and skipped."""
    known = {}
    for v in request("GET", "/api/game/versions", token):
        known.setdefault(v["name"], v["id"])
    ids = [known[n] for n in names if n in known]
    missing = [n for n in names if n not in known]
    if missing:
        print(f"CurseForge has no game version {', '.join(missing)}; skipped")
    if not ids:
        raise ValueError("None of the TOC game versions exist on CurseForge: " + ", ".join(names))
    return ids


def upload(project, token, archive, changelog, display_name, game_versions):
    """Upload archive as a release file; returns the CurseForge file ID."""
    metadata = {"changelog": changelog, "changelogType": "markdown", "displayName": display_name,
                "gameVersions": game_versions, "releaseType": "release"}
    body, content_type = uploads.multipart(metadata, archive)
    result = request("POST", f"/api/projects/{project}/upload-file", token, body, {"Content-Type": content_type})
    return result["id"]
