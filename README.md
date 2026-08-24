# Melt All The Ice

A Roblox game about thawing frozen historical maps. Design: [`docs/GDD.md`](docs/GDD.md).

## How this project is wired

All game code lives on disk as `.luau` text files and is synced into Roblox Studio by
**Rojo**. Nothing important lives only inside a `.rbxl`. That means the game can be worked
on from anywhere — including a machine that has never had Roblox Studio installed.

```
src/shared   ->  ReplicatedStorage/Shared
src/server   ->  ServerScriptService/Server
src/client   ->  StarterPlayer/StarterPlayerScripts/Client
```

Mapping is defined in `default.project.json`.

## Working on it at the PC

```bash
# 1. Start the sync server (leave running)
.tools/rojo.exe serve

# 2. In Roblox Studio: Plugins tab -> Rojo -> Connect
#    Studio now live-reloads every file change.
```

Build a standalone place file without Studio:

```bash
.tools/rojo.exe build -o build/MeltAllTheIce.rbxl
```

## Toolchain

| Tool | Where | Notes |
|---|---|---|
| Rojo 7.7.0 | `.tools/rojo.exe` | gitignored, re-download per machine |
| Rojo Studio plugin | `%LOCALAPPDATA%\Roblox\Plugins\Rojo.rbxm` | installed |
| Roblox Studio MCP | ships inside Studio | must be toggled on in Studio, see below |
| Blender 5.1 | `C:\Program Files\Blender Foundation\Blender 5.1` | headless: `blender.exe -b -P script.py` |

Re-download Rojo on a fresh machine:

```bash
mkdir -p .tools && cd .tools
curl -sL -o rojo.zip https://github.com/rojo-rbx/rojo/releases/download/v7.7.0/rojo-7.7.0-windows-x86_64.zip
unzip rojo.zip && rm rojo.zip
```

## Enabling the Studio MCP server

Studio ships its own MCP server (no separate install). Turn it on:

**Assistant → … → Manage MCP Servers → "Enable Studio as MCP server"**

It is already registered with Claude Code as `Roblox_Studio`
(`cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat`). It only does anything while Studio is open.

## Repo layout

```
default.project.json   Rojo tree mapping
.luaurc                Luau strict mode + path aliases
src/                   game source
assets/blender/        Blender sources + export scripts
docs/GDD.md            design document
docs/original-notes-ro.md   verbatim source notes
docs/reference/        reference images from the design doc
```
