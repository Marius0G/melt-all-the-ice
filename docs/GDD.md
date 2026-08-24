# MELT ALL THE ICE — Game Design Document

> Source: `Document 7.pdf` (original notes in Romanian, by Marius). This is the structured
> English working version. Reference images live in `docs/reference/`.

## Core loop

The world is frozen. You melt it. Everything else hangs off that.

1. Hit ice → ice breaks → you earn money.
2. Money → upgrades (income multiplier, fire power, ice-breaking power, stamina/fuel).
3. Upgrades → reach harder ice → unlock the next tier of tool.
4. Fully thaw the map → the map's "finale" fires → next map unlocks.

Two resource gates keep it from being a pure idle clicker:

- **Stamina (oboseală)** — gates the physical tools (stone, axe). Regenerates.
- **Fuel (combustibil)** — gates the fire tools (torch, campfire, scepter, greek fire).

## Progression through maps

Maps are ordered as a historical narrative — *why did all of this freeze?* — and get
progressively larger and harder.

### 1. Cave (Pestera) — tutorial map

Smallest, easiest, introductory. As you melt the ice you uncover things frozen inside it:
dinosaur bones, mammoths, frozen people. These are the discovery hook.

- Reference: `docs/reference/cave-mid-state.png` (mid-melt), `cave-end-state.png` (end state)
- Start state: fully iced-over cavern, no light source.
- End state: open cave, water pooled at the bottom, warm light.

**Tools:** start with a bare **stone**. Progress → find a **stick**, tie it to the stone →
**axe**. The skill tree's capstone on this map is *learning to make fire*, so the final
tool is the **torch**.

### 2. Pyramid (Piramida) — Egypt

Bigger, much more satisfying to clear. You start in a **small town next to the pyramid**
and work toward it. Along the way you find **entrances into the pyramid** containing new
tools that make melting easier.

- Reference: `docs/reference/pyramid-town-ref.png`
- Finale: **the tip of the pyramid lights up** once the map is fully thawed.

**Tools:** torch carries over and gets stronger. New: **campfires** — a placeable ability
that thaws an area over time. Capstone: **Ra's scepter** (Ra = sun god), melts a huge radius.

### 3. Troy (Troia) — Greece

A Greek region. Set pieces: a **Parthenon** and the **Trojan horse**.

- Reference: `docs/reference/troy-parthenon-ref.png`, `troy-horse-ref.png`

**Tools:** **Greek fire** — green, burns continuously for ~30 seconds. Very weak at first,
upgrades make it absurd. Capstone: **the Chains of Kratos**, even more broken.

## Tool progression summary

| Map | Start | Mid | Capstone | Gate |
|---|---|---|---|---|
| Cave | Stone | Axe (stone + stick) | Torch | Stamina → Fuel |
| Pyramid | Torch | Campfire (area ability) | Ra's Scepter | Fuel |
| Troy | Greek Fire | Greek Fire upgrades | Chains of Kratos | Fuel |

## Upgrades

Money buys upgrades along these axes:

- **Income** — money earned per unit of ice broken
- **Fire power** — how fast/hot a fire tool melts
- **Break power** — how much ice a hit removes
- **Stamina** — capacity and regen for physical tools
- **Fuel** — capacity and burn rate for fire tools

## Skill tree

A visual, branching skill tree — reference: `docs/reference/skilltree-ui-ref.png`
(Kingdom Rush style: icon nodes, connecting lines, per-branch tiers, RESET / DONE buttons).
One tree per map tier, with the map's capstone tool as the deepest node.

## Weapon customization

> "La arme vreau sa facem chestia de ati selecta tu cum vrei sa fie arma, gen ca pe jocurile de genu"

Players choose how their weapon looks/behaves — cosmetic and/or stat variants selected by
the player, in the style of the genre (skins + modifiers on the same base tool).

---

## Architecture decisions

Decided 2026-08-24. These are settled — build against them.

### AD-1: Ice is hybrid — Parts for scoring, Terrain for looks

The authoritative gameplay unit is an **ice chunk**: a `Part` on a 3D grid, each with its
own HP. Roblox `Terrain` (Ice material) fills the same volume purely as the visual layer.

Melting one chunk:

1. Tool swing → server raycast → resolve which chunk was hit
2. Subtract HP (scaled by tool break-power / fire-power)
3. On HP ≤ 0: `Terrain:FillBlock` that chunk's volume with `Enum.Material.Air`,
   destroy the chunk Part, award money, increment the melted counter

Map progress is `destroyedChunks / totalChunks` — cheap, exact, and drives the "% thawed"
UI and the map finale (pyramid tip lighting up, etc.) without inspecting voxels.

Chunk Parts should be non-collidable and either invisible or near-invisible; the Terrain is
what the player actually sees. Grid resolution is a tuning knob — start coarse (4-8 studs)
and only go finer if melting feels chunky.

### AD-2: Per-player worlds, via spatially separated plots

Each player melts their own copy of the map. No shared progress.

⚠️ **Constraint worth knowing up front:** Roblox `Terrain` is a *single global singleton* —
there is exactly one Terrain object per place and it replicates to everyone. Per-player
terrain does not exist natively.

The workable pattern is **plots**: allocate N plot regions spaced far apart in world space,
and give each joining player one. Terrain is still one object, but each player's carved
region is physically separate, so writes never collide and nobody sees anyone else's map.
Combined with `StreamingEnabled` (already on in `default.project.json`), distant plots
aren't streamed to the client at all.

Trade-offs to respect:

- Terrain memory scales with `plots × map volume` — this caps max players per server.
  Size the cave accordingly and pick the plot count deliberately.
- Plots must be released and re-frozen on player leave (see AD-3).

### AD-3: Cleared maps re-freeze

Once a map is fully thawed, it resets to frozen for the next run. So map generation must be
**idempotent and re-runnable on a live plot** — the same generator that builds a fresh plot
also restores a cleared one. Build it as `generate(plotOrigin)` from the start rather than
retrofitting a reset path later.

Plot release on player leave should re-freeze too, so a recycled plot never hands the next
player a half-melted map.

## Still open

- **Monetization** — gamepasses / dev products aren't in the source doc but are the norm for
  this genre. Out of scope until asked.
- **Chunk grid resolution** and **plot count** — tuning values, settle them by feel once the
  cave is playable.
