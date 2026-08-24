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

Mapping is defined in `default.project.json`, which also carries the properties that
**cannot be set from a script at all** — `Lighting.Technology` and the streaming radii are
file-format only, so they have to be declared there or they simply do not exist.

## Where things live

| Module | Owns |
|---|---|
| `shared/MapDefs` | The three maps as data: volume, grid, palette, props, tools, payout |
| `shared/Tools` | Per-tool damage, reach, cooldown, gate, area and burn |
| `shared/Upgrades` | The tree: costs, prerequisites, and what each level does |
| `shared/Feel` | Presentation only: shake, particles, sound ids, timings, palette |
| `shared/Config` | The little that is genuinely global: plot pool, gate baselines |
| `server/MeltService` | The single place a swing turns into melted ice |
| `server/IceField` | The chunk grid for whichever map a plot is hosting |
| `server/Discoveries` | What is buried, and uncovering it |
| `client/*` | Input and presentation. Never decides an outcome. |

## Working on it

```bash
# 1. Start the sync server (leave running)
.tools/rojo.exe serve

# 2. In Roblox Studio: Plugins tab -> Rojo -> Connect
```

Build a standalone place file without Studio:

```bash
.tools/rojo.exe build -o build/MeltAllTheIce.rbxl
```

### Type checking

`.luaurc` sets strict mode, so every file carries `--!strict` and should stay type-clean:

```bash
./tools/check.sh
```

That regenerates the sourcemap first, which is what lets luau-lsp resolve
`require(script.Parent.Foo)` to a real module — so it has to be rerun after adding or
moving files.

### Syncing without the Rojo plugin

`tools/devsync.py` serves `src/` as JSON on `127.0.0.1:8777`, and `tools/devsync.luau` is
run inside Studio (via the Studio MCP) to pull it in. This exists so an automated session
can sync and playtest without a human clicking **Connect**; Rojo remains the source of
truth for the DataModel mapping and for `rojo build`.

```bash
python tools/devsync.py
```

## Asset pipeline

Props are authored in Blender **headlessly** and uploaded once through Roblox Open Cloud.

```bash
# Build the meshes and look at them before uploading anything
"/c/Program Files/Blender Foundation/Blender 5.1/blender.exe" \
    -b -P assets/blender/props.py -- --out build/props.fbx --render build/preview

# One upload covers every prop
python tools/upload_assets.py build/props.fbx "MeltAllTheIce Props"
```

Roblox turns each mesh object in an FBX into its own `MeshPart` inside a single Model
asset, so fourteen props cost one upload. The resulting mesh ids are read back out of the
import and committed to `src/shared/PropAssets.luau` — the pipeline never has to run again
to build the game.

Two things that will bite otherwise:

- **Blender exports FBX in centimetres**, so every mesh arrives 100× too big. `MeshPart.Size`
  is writable and rescales the mesh, so authored dimensions are stored in `PropAssets` and
  applied on creation.
- **No textures are exported, deliberately.** `MeshPart.Color` only applies to an untextured
  mesh, so colour stays in the palette with everything else.

Credentials live in `.env` (gitignored — never commit the key):

```
ROBLOX_OPEN_CLOUD_KEY=...
ROBLOX_USER_ID=...
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

## Enabling the Studio MCP server

Studio ships its own MCP server (no separate install). Turn it on:

**Assistant → … → Manage MCP Servers → "Enable Studio as MCP server"**

It is already registered with Claude Code as `Roblox_Studio`
(`cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat`). It only does anything while Studio is open.

## Things code cannot do for you

- **`Players.MaxPlayers`** is read-only from scripts. Set it by hand in
  **Home → Game Settings → Players → Max Players**, and keep it equal to `Config.PLOT_COUNT`
  (currently **6**). Plots are handed out one per player and the server kicks anyone who
  arrives with none free, so a higher value just means the surplus get kicked on join.
- **Saving needs the place published once**, plus
  **Game Settings → Security → Enable Studio Access to API Services**. Until then
  `SaveService` detects that DataStores are unavailable, says so once, and the game runs
  normally with saving off.
- **`Lighting.Technology` and the streaming radii** are not settable from any script, at any
  privilege level. They live in `default.project.json`.

## Remote-work setup (PC stays on)

This machine is a laptop. On AC power it never sleeps or hibernates; **on battery it sleeps
after 3 minutes**, which would kill the session. So: leave it plugged in.

Checklist before walking away:

- [ ] Plugged into AC (battery = 3 min to sleep)
- [ ] Lid open, or lid-close action set to *Do nothing*
      (`powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0 && powercfg /S SCHEME_CURRENT`)
- [ ] Roblox Studio open, with **Assistant → … → Manage MCP Servers → Enable Studio as MCP server** ON
- [ ] A Claude Code session running with Remote Control connected

MCP servers are read at session start, so start the session *after* the toggles above.

## Repo layout

```
default.project.json   Rojo tree mapping and place properties
.luaurc                Luau strict mode + path aliases
src/                   game source
assets/blender/        Blender prop sources
tools/                 check.sh, devsync, Open Cloud upload
docs/GDD.md            design document
docs/original-notes-ro.md   verbatim source notes
docs/reference/        reference images from the design doc
```
