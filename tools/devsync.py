#!/usr/bin/env python3
"""
devsync - push src/ into a running Roblox Studio without the Rojo plugin.

Rojo stays the source of truth: it owns the DataModel mapping in
default.project.json and it is what `rojo build` uses. This is only a hands-off
substitute for a human clicking "Connect" in the Rojo Studio plugin, so an
automated session can sync and playtest on its own.

Serves src/ as JSON on 127.0.0.1:PORT. The Studio half lives in
tools/devsync.luau and is run through the Studio MCP.

    python tools/devsync.py [port]
"""
import http.server
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")

# Mirrors the tree in default.project.json. Keep the two in step.
CONTAINERS = {
    "shared": "ReplicatedStorage/Shared",
    "server": "ServerScriptService/Server",
    "client": "StarterPlayer/StarterPlayerScripts/Client",
}


def classify(filename):
    """Rojo's filename rules: .server.luau is a Script, .client.luau a LocalScript."""
    if filename.endswith(".server.luau"):
        return filename[: -len(".server.luau")], "Script"
    if filename.endswith(".client.luau"):
        return filename[: -len(".client.luau")], "LocalScript"
    if filename.endswith(".luau"):
        return filename[: -len(".luau")], "ModuleScript"
    return None, None


def build_tree():
    entries = []
    for folder, path in CONTAINERS.items():
        directory = os.path.join(SRC, folder)
        if not os.path.isdir(directory):
            continue
        for filename in sorted(os.listdir(directory)):
            name, cls = classify(filename)
            if not name:
                continue
            with open(os.path.join(directory, filename), encoding="utf-8") as handle:
                entries.append(
                    {"path": path, "name": name, "class": cls, "source": handle.read()}
                )
    return entries


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        payload = json.dumps(build_tree()).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, fmt, *args):
        sys.stderr.write("devsync: " + (fmt % args) + "\n")


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8777
    count = len(build_tree())
    print("devsync serving %d modules on http://127.0.0.1:%d" % (count, port), flush=True)
    http.server.HTTPServer(("127.0.0.1", port), Handler).serve_forever()
