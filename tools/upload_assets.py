#!/usr/bin/env python3
"""
Upload the prop FBX to Roblox via Open Cloud and report the resulting asset id.

    python tools/upload_assets.py build/cave_props.fbx "Cave Props"

Needs ROBLOX_OPEN_CLOUD_KEY and ROBLOX_USER_ID in .env (which is gitignored -
the key must never reach the repo).

Notes worth knowing before changing this:

  * An FBX goes up as assetType "Model", not "Mesh". The Mesh type only accepts
    Roblox's own .mesh format. The whole scene becomes one Model asset with one
    MeshPart per mesh object in the file, so a single upload carries every prop.
  * Creation is asynchronous: the POST returns an Operation, and the asset id
    only exists once that operation reports done.
  * Uploaded meshes are moderated and do not render until approved. The
    operation response carries moderationState, so that is checked rather than
    assumed - an unmoderated mesh on the critical path shows up as an invisible
    prop and a retry storm in Studio, not as an error.
"""

import io
import json
import mimetypes
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

API = "https://apis.roblox.com/assets/v1/assets"
OPERATIONS = "https://apis.roblox.com/assets/v1/operations/"


def load_env(path=".env"):
    values = {}
    if not os.path.exists(path):
        return values
    for line in io.open(path, encoding="utf-8"):
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    return values


def multipart(fields, files):
    """Build a multipart/form-data body by hand, to avoid a requests dependency."""
    boundary = "----MeltAllTheIce" + uuid.uuid4().hex
    body = io.BytesIO()

    for name, value in fields.items():
        body.write(("--%s\r\n" % boundary).encode())
        body.write(('Content-Disposition: form-data; name="%s"\r\n\r\n' % name).encode())
        body.write(value.encode("utf-8"))
        body.write(b"\r\n")

    for name, (filename, content, content_type) in files.items():
        body.write(("--%s\r\n" % boundary).encode())
        body.write((
            'Content-Disposition: form-data; name="%s"; filename="%s"\r\n'
            % (name, filename)
        ).encode())
        body.write(("Content-Type: %s\r\n\r\n" % content_type).encode())
        body.write(content)
        body.write(b"\r\n")

    body.write(("--%s--\r\n" % boundary).encode())
    return body.getvalue(), "multipart/form-data; boundary=%s" % boundary


def request(url, key, data=None, content_type=None, method="GET"):
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("x-api-key", key)
    if content_type:
        req.add_header("Content-Type", content_type)
    try:
        with urllib.request.urlopen(req, timeout=120) as response:
            return response.status, json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        raw = error.read().decode("utf-8", "replace")
        try:
            return error.code, json.loads(raw)
        except ValueError:
            return error.code, {"raw": raw}


def upload(path, display_name, key, user_id):
    with open(path, "rb") as handle:
        content = handle.read()

    payload = {
        "assetType": "Model",
        "displayName": display_name,
        "description": "Low-poly cave props for Melt All The Ice.",
        "creationContext": {"creator": {"userId": str(user_id)}},
    }
    guessed = mimetypes.guess_type(path)[0]
    content_type = "model/fbx" if path.lower().endswith(".fbx") else (guessed or "application/octet-stream")

    body, boundary_type = multipart(
        {"request": json.dumps(payload)},
        {"fileContent": (os.path.basename(path), content, content_type)},
    )

    print("uploading %s (%d KB) as %r" % (path, len(content) // 1024, display_name))
    status, result = request(API, key, body, boundary_type, method="POST")
    if status not in (200, 201):
        print("FAILED  HTTP %s\n%s" % (status, json.dumps(result, indent=2)[:1500]))
        return None

    operation = result.get("operationId") or result.get("path", "").rsplit("/", 1)[-1]
    print("operation: %s" % operation)

    # Poll until the asset exists. Backs off so a slow moderation queue does not
    # turn into a hot loop.
    delay = 2.0
    for attempt in range(40):
        time.sleep(delay)
        delay = min(delay * 1.25, 12.0)
        status, result = request(OPERATIONS + operation, key)
        if status != 200:
            print("  poll %d: HTTP %s %s" % (attempt + 1, status, str(result)[:200]))
            continue
        if result.get("done"):
            response = result.get("response", {})
            asset_id = response.get("assetId")
            moderation = (response.get("moderationResult") or {}).get("moderationState")
            print("\ndone.")
            print("  assetId:        %s" % asset_id)
            print("  moderationState: %s" % moderation)
            return {"assetId": asset_id, "moderationState": moderation, "raw": response}
        print("  poll %d: still working" % (attempt + 1))

    print("gave up waiting; the operation may still complete later")
    return None


def main():
    env = load_env()
    key = env.get("ROBLOX_OPEN_CLOUD_KEY") or os.environ.get("ROBLOX_OPEN_CLOUD_KEY")
    user_id = env.get("ROBLOX_USER_ID") or os.environ.get("ROBLOX_USER_ID")
    if not key or not user_id:
        print("missing ROBLOX_OPEN_CLOUD_KEY / ROBLOX_USER_ID (.env)")
        return 1

    path = sys.argv[1] if len(sys.argv) > 1 else "build/cave_props.fbx"
    name = sys.argv[2] if len(sys.argv) > 2 else "MeltAllTheIce Cave Props"
    if not os.path.exists(path):
        print("no such file: %s" % path)
        return 1

    result = upload(path, name, key, user_id)
    if not result or not result.get("assetId"):
        return 1

    # Record it next to the build so the id survives the shell session.
    os.makedirs("build", exist_ok=True)
    with io.open("build/asset_ids.json", "w", encoding="utf-8") as handle:
        json.dump(result, handle, indent=2)
    print("  written to build/asset_ids.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
