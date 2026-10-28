"""HTTP helpers for the addon sites' upload APIs (standard library only)."""
import json
from pathlib import Path
import urllib.request
import uuid

# Wago's firewall refuses Python's default User-Agent (HTTP 403).
USER_AGENT = "highground-release (+https://github.com/kemicofa/highground)"


def request(method, url, headers, body=None):
    """Send a request; returns the decoded JSON reply (None when empty)."""
    req = urllib.request.Request(url, data=body, method=method, headers={"User-Agent": USER_AGENT, **headers})
    with urllib.request.urlopen(req, timeout=60) as response:
        data = response.read().decode("utf-8")
    return json.loads(data) if data.strip() else None


def multipart(metadata, archive):
    """A multipart body with a "metadata" JSON part and the "file" ZIP; returns (body, content type)."""
    boundary = uuid.uuid4().hex
    archive = Path(archive)
    body = b"".join([
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"metadata\"\r\n"
        f"Content-Type: application/json\r\n\r\n".encode(), json.dumps(metadata).encode(), b"\r\n",
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"{archive.name}\"\r\n"
        f"Content-Type: application/zip\r\n\r\n".encode(), archive.read_bytes(), b"\r\n",
        f"--{boundary}--\r\n".encode(),
    ])
    return body, f"multipart/form-data; boundary={boundary}"
