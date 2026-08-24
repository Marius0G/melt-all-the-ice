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
| luau-lsp 1.69.0 | `.tools/luau-lsp.exe` | type checking, gitignored |
| Rojo Studio plugin | `%LOCALAPPDATA%\Roblox\Plugins\Rojo.rbxm` | installed |
| Roblox Studio MCP | ships inside Studio | must be toggled on in Studio, see below |
| Blender 5.1 | `C:\Program Files\Blender Foundation\Blender 5.1` | headless: `blender.exe -b -P script.py` |

Re-download the toolchain on a fresh machine:

```bash
mkdir -p .tools && cd .tools

# Rojo
curl -sL -o rojo.zip https://github.com/rojo-rbx/rojo/releases/download/v7.7.0/rojo-7.7.0-windows-x86_64.zip
unzip rojo.zip && rm rojo.zip

# luau-lsp + Roblox API type definitions
curl -sL -o luau-lsp.zip https://github.com/JohnnyMorganz/luau-lsp/releases/download/1.69.0/luau-lsp-win64.zip
unzip luau-lsp.zip && rm luau-lsp.zip
curl -sL -o globalTypes.d.luau https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau
```

## Type checking

`.luaurc` sets strict mode, so every file carries `--!strict` and should stay
type-clean. Check it:

```bash
.tools/rojo.exe sourcemap default.project.json -o sourcemap.json
.tools/luau-lsp.exe analyze --sourcemap=sourcemap.json   --definitions=.tools/globalTypes.d.luau src/
```

The sourcemap is what lets luau-lsp resolve `require(script.Parent.Foo)` to a
real module and type it, so regenerate it after adding or moving files.

## Enabling the Studio MCP server

Studio ships its own MCP server (no separate install). Turn it on:

**Assistant → … → Manage MCP Servers → "Enable Studio as MCP server"**

It is already registered with Claude Code as `Roblox_Studio`
(`cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat`). It only does anything while Studio is open.

## Remote-work setup (PC stays on)

This machine is a laptop. On AC power it never sleeps or hibernates; **on battery it sleeps
after 3 minutes**, which would kill the session. So: leave it plugged in.

Checklist before walking away:

- [ ] Plugged into AC (battery = 3 min to sleep)
- [ ] Lid open, or lid-close action set to *Do nothing*
      (`powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0 && powercfg /S SCHEME_CURRENT`)
- [ ] Roblox Studio open, with **Assistant → … → Manage MCP Servers → Enable Studio as MCP server** ON
- [ ] Blender restarted, *Interface: Blender MCP* enabled in Preferences → Add-ons,
      **Start MCP Server** clicked in the N-panel
- [ ] A Claude Code session running with Remote Control connected

MCP servers are read at session start, so start the session *after* the toggles above.

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
