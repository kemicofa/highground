"""Upload an addon ZIP to a CurseForge project with the upload API (standard library only).

https://support.curseforge.com/support/solutions/articles/9000197321-curseforge-api
  GET  /api/game/versions                    -> [{id, gameVersionTypeID, name, slug}]
  POST /api/projects/{id}/upload-file        multipart: metadata (JSON), file
Authentication: the X-Api-Token header (a CurseForge API token).
"""
import json
from pathlib import Path
import re
import urllib.request
import uuid

API = "https://wow.curseforge.com"


def interface_versions(addon):
    """Game versions from the TOCs' "## Interface" lines: 120105 -> "12.1.5", 40402 -> "4.4.2"."""
    names = []
    for toc in sorted(Path(addon).glob("*.toc")):
        line = re.search(r"^## Interface:\s*(.+)$", toc.read_text(), re.M)
        for number in re.findall(r"\d+", line.group(1) if line else ""):
            n = int(number)
            name = f"{n // 10000}.{n // 100 % 100}.{n % 100}"
            if name not in names:
                names.append(name)
    return names


def request(method, path, token, body=None, headers=None):
    req = urllib.request.Request(API + path, data=body, method=method,
                                 headers={"X-Api-Token": token, **(headers or {})})
    with urllib.request.urlopen(req, timeout=60) as response:
        return json.loads(response.read().decode("utf-8"))


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
    boundary = uuid.uuid4().hex
    archive = Path(archive)
    body = b"".join([
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"metadata\"\r\n"
        f"Content-Type: application/json\r\n\r\n".encode(), json.dumps(metadata).encode(), b"\r\n",
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"{archive.name}\"\r\n"
        f"Content-Type: application/zip\r\n\r\n".encode(), archive.read_bytes(), b"\r\n",
        f"--{boundary}--\r\n".encode(),
    ])
    result = request("POST", f"/api/projects/{project}/upload-file", token, body,
                     {"Content-Type": f"multipart/form-data; boundary={boundary}"})
    return result["id"]
