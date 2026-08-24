# Handoff prompt

Paste the block below into a fresh Claude Code session started in
`C:\Users\mariu\Documents\Proiecte\RobloxFreeze`.

Start that session *after* Studio's MCP toggle is on and Blender has been restarted —
MCP servers are read at session start.

---

I'm building a Roblox game called **Melt All The Ice**. The project is at
`C:\Users\mariu\Documents\Proiecte\RobloxFreeze`, git remote
`https://github.com/Marius0G/melt-all-the-ice`.

**Read first:** `README.md` for toolchain and workflow, `docs/GDD.md` for the design and the
three settled architecture decisions (AD-1 hybrid ice, AD-2 per-player plots, AD-3 maps
re-freeze). `docs/reference/` holds the mood-board images. Don't relitigate AD-1/2/3 —
they're decided.

**Already set up, do not redo:**
- Rojo 7.7.0 at `.tools/rojo.exe`, Studio plugin installed, `default.project.json` maps
  `src/{shared,server,client}` into the DataModel. `rojo build` is verified working.
- `Roblox_Studio` MCP registered, and "Enable Studio as MCP server" is ON in Studio.
- `blender` MCP registered.
- `.luaurc` sets Luau strict mode — write `--!strict` and keep it type-clean.

**Workflow:**
- All game logic lives as `.luau` files under `src/`. The files are the source of truth —
  never author logic that exists only inside Studio.
- Run `.tools/rojo.exe serve` and connect the Rojo plugin in Studio for live sync.
- Use the Roblox Studio MCP to actually playtest and read console output. Verify things run;
  don't just assert they compile.
- Commit and push as you go, small commits.

**Build this first — the cave vertical slice.**

Goal: a player spawns on their plot, hits ice with a stone, watches it melt, and sees money
and "% thawed" climb.

1. **Plot system** (AD-2): N plot regions spaced far apart, allocated on join, released and
   re-frozen on leave.
2. **Idempotent cave generator** (AD-3): `generate(plotOrigin)` both builds a fresh plot and
   restores a cleared one. Write it re-runnable from the start.
3. **Hybrid ice** (AD-1): grid of chunk Parts with HP, Terrain Ice skin over the same volume.
   Melting a chunk = `Terrain:FillBlock` Air + destroy the Part + award money + bump the
   melted counter.
4. **Stone tool**: swing → server-side raycast → damage the hit chunk. Stamina gate with regen.
5. **Minimal UI**: money, % thawed, stamina bar.

Everything server-authoritative — the client never decides what melted or what it earned.

**Not in this slice:** axe/torch progression, skill tree, pyramid, Troy, monetization,
Blender assets.

**Check with me before** locking chunk grid resolution or plot count — those are tuning
calls I want to weigh in on, and plot count caps players-per-server via terrain memory.
