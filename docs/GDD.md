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
- Mid state: still dark and blue, meltwater pooling on the floor, a single lantern.
- End state: the cave mouth blown open to daylight, a campfire lit, warm light, a few blue
  ice pillars left standing.

> **Correction (2026-08-24):** the two cave reference files were named the wrong way round,
> and an earlier version of this document repeated the error. Checked against the captions in
> `Document 7.pdf`: the 416x416 bright image sits with *"Asta ar fi finalul hartii"* (the end)
> and the 607x341 dark image with *"Si asta undeva pe la mijloc"* (the middle). The files have
> been renamed to match. The arc runs **dark and blue -> bright and warm**, which is also the
> tool arc: the map starts with no light source and its capstone is learning to make fire.
> **Lighting is the progress bar**, and meltwater pooling on the floor is the other half of it.

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

Built: seventeen looks across the seven tools, strictly cosmetic (colour, material, and flame
tint for the fire tools), bought and worn from the WEAPONS tab. Cosmetic-only is the point -
there is no number in a skin that could reach a swing, so the server validates ownership and
nothing else.

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

### AD-4: Maps are data, not code

Cave / Pyramid / Troy are three **map definitions** consumed by one generic builder, not three
generators. `src/shared/MapDefs.luau` holds volume, chunk size, palette, lighting arc, prop set,
tool set and finale; `src/server/IceField.luau` and `src/server/PlotManager.luau` turn a
definition plus a plot origin into a
built map, idempotently (AD-3).

This is what makes three maps tractable, and it lets each map choose its own `CHUNK_SIZE`
(4 for the cave, 8 for the much larger pyramid — both multiples of the 4-stud terrain voxel)
so a bigger map does not mean proportionally more Parts.

### AD-5: A plot hosts one map at a time

A player is only ever *on* one map, so a plot holds the current one and rebuilds when the player
advances, rather than holding all three at once. Terrain memory therefore stays flat as maps are
added, which is what keeps AD-2's plot count viable. `build(origin)` becomes
`build(origin, mapId)`; the idempotence AD-3 already demands is exactly the mechanism.

### AD-6: Per-player presentation goes through the client

The same trap as the Terrain singleton, one layer up: `Lighting` is a **global service**, so a
per-player lighting arc cannot be driven from the server. Two mechanisms, both genuinely
per-player:

- **Client-side `Lighting` edits.** A LocalScript changing `Lighting` / `Atmosphere` /
  `ColorCorrection` affects only that client. This drives the global grade from the player's own
  `ThawedPct` attribute.
- **Local lights inside the plot.** Anything positional is a light parented to plot geometry;
  StreamingEnabled keeps it off every other client.

The server stays authoritative for **state**; the client owns **presentation**. No cosmetic ever
decides an outcome.

### AD-7: Landmarks rise through the ice

Each map is built around a structure - the pyramid, the Parthenon - placed on the ice
footprint and built **taller than the ice**, so its top stands clear from the moment the
player spawns while the bulk is encased. That gives a map both a goal and a payoff: you can
see what you are working toward, and clearing the map is what uncovers it. Roughly 44% of
the pyramid map's cells sit inside the pyramid, so most of what is dug out is dug off the
monument itself.

They live in their own per-plot folder, never in the ice folder: `MeltService` raycasts with
an Include filter scoped to exactly that folder, so anything inside it becomes a melt target
and gets wiped on every rebuild. Buried finds are filtered against the landmark volume,
because a find inside solid stonework could never be uncovered.

Each map tags one Part as its beacon, which the finale lights - "sa se aprinda varful
priamidei". The cave's is the campfire from its end-state reference.

### AD-8: A map declares its setting, and only the cave is a cave

`MapDef.setting` is either `cave` or `open`. A cave hollows a chamber out of solid rock,
seals it overhead and lights it entirely from inside. An open map lays a ground slab under
an open sky - no ceiling, no walls, a horizon lost in fog.

The pyramid and Troy were caves only because the cave needed a chamber and all three maps
shared one generator. A pyramid is a thing that stands in a desert and Troy is a city; both
read wrong sealed in rock, and the reference this genre works from (Melt The Ice, ~11K
likes) puts its ice under a bright open sky on green grass rather than underground.

Three things follow from the split rather than being separate choices:

- **Rebuilding wipes the plot's whole slice first, but only when the map changes.** A plot
  hosts whichever map its owner is on (AD-5) and the maps differ hugely in size, so
  switching used to leave the previous one's terrain standing - Troy's rock around a room a
  fifth of the size, or a cave roof over a desert. It is a big volume to write, so
  re-freezing the same map skips it; the ordinary fills already overwrite everything that
  map put down, which is what keeps regeneration idempotent (AD-3).
- **Fill lights and the spawn lantern are cave-only.** They exist because a sealed chamber
  has no light of its own. Dropping blue point lights into daylight only flattens it.
- **`WorldLight` carries two pairs of presets.** The cave keeps its dark-to-daylight arc from
  the design doc. Outdoors runs cold, hazy and overcast to warm and clear - the same idea of
  lighting as the progress bar, travelled in a different direction. Which pair is used comes
  off the player's `CurrentMap` attribute.

The cave stayed a cave and got bigger instead: walkway 12 -> 28 and ceiling gap 8 -> 28, so
there is room to walk right around the block, hang torches on the walls and look up at
something. The grid is untouched - growing the ice would have lengthened the first map every
new player meets, which is where they leave.

### AD-9: Shaped ice is safe because collision does not follow the mesh

Chunks are faceted crystal MeshParts rather than cubes. This was previously off the table:
chunk Parts are the raycast targets, and the last time their geometry moved - damaged chunks
shrinking 4% - a ray aimed near a boundary slipped through the gap into the chunk behind and
mining silently stopped working for anything not hit dead centre.

Raycasts read a MeshPart's **collision** geometry, not its visual mesh. At
`CollisionFidelity.Box` a crystal is a perfect cube to every ray - measured at 8.000 studs
dead centre and near a corner, identical to a plain Part - so the shape is free.

The mesh is still constrained, for a different reason. Interior chunks are hidden by going to
Transparency 1 rather than being destroyed, so all eight corners stay at exactly +-0.5 and
neighbours meet along their whole shared edge; a pulled-in corner would show through the
seam, past the invisible chunk, and out into the chamber. Only the face centres recede. The
generator asserts the unit cube.

### AD-10: Rarity is derived from reward, not stored beside it

Reward is already the "how valuable is this find" axis, so a second hand-maintained rarity
field would only be a chance for the two to disagree - a legendary worth less than a common
is the kind of thing nobody notices until a player screenshots it. `Rarity.forReward` reads
the number; the `hero` flag still floors a map's headline finds at Epic.

One tier then drives the payout multiplier, how loud the reveal is, and the colour the popup,
the collection log and the quest list all agree on.

## Settled tuning

Maps are data (`src/shared/MapDefs.luau`). Chunk size is per-map and is what keeps the
larger maps affordable: Troy is nine times the cave's footprint for about twice the Parts.

| Map | Setting | Chunk | Grid | Ice volume | Max chunks | $/chunk | Chunk HP |
|---|---|---|---|---|---|---|---|
| Cave | cave | 4 | 12 x 5 x 12 | 48 x 20 x 48 | 720 | 1 | 30 |
| Pyramid | open | 8 | 24 x 4 x 24 | 192 x 32 x 192 | 2304 | 6 | 60 |
| Troy | open | 8 | 28 x 4 x 28 | 224 x 32 x 224 | 3136 | 20 | 110 |

The later maps are four chunk layers deep rather than five so their landmarks read from the
spawn. At 40 studs of ice only the Parthenon's roof cleared the surface and it looked like a
grey lump; at 32 the top of the colonnade shows and it is legibly a temple.

Tools (`src/shared/Tools.luau`). Damage is set against each map's chunk HP so every tool
lands on a whole hit count - a tool that takes 2.2 hits reads as inconsistent, because
some chunks go in two and some in three for no reason the player can see.

| Tool | Map | Damage | Gate | Cost | Area | Burns |
|---|---|---|---|---|---|---|
| Stone | Cave | 10 | stamina | 8 | - | - |
| Axe | Cave | 20 | stamina | 9 | - | - |
| Torch | Cave | 30 | fuel | 9 | - | - |
| Campfire | Pyramid | 45 | fuel | 18 | r1 | x2 |
| Ra's Scepter | Pyramid | 70 | fuel | 30 | r2 | x2 |
| Greek Fire | Troy | 40 | fuel | 26 | r2 | x6 |
| Chains of Kratos | Troy | 110 | fuel | 34 | r3 | x3 |

The later tools escalate by **area**, not by a bigger number, which is what the source
notes actually describe: campfires thawing "o anumita zona", a scepter that melts "super
mult", greek fire that "arde incontinuu".

Other settled values:

| Value | Setting | Why |
|---|---|---|
| Plot count | 6, built lazily on join | Caps players/server; idle plots hold nothing |
| Plot spacing | 1024 studs | Must exceed the streaming radius and the widest map (304) |
| Ice look | Visible Parts, `SmoothPlastic`, ~0.12 transparent | Terrain's PBR grit fights the cartoony target |
| Stamina | 100 base, +12/s | Baseline; upgrades move it per player |
| Fuel | 72 base, +9/s | Tuned so the torch beats the stone *sustained*, not just per swing |

## Keeping at it

Four systems sit on top of the melt loop, all server-authoritative.

**Combo.** Any swing that *connects* extends a streak; five seconds of nothing drops it. The
streak multiplies chunk income up to double at fifty.

Connecting rather than breaking had to be measured. The stone costs 24 stamina against a 100
bar regenerating at 12/s, so it swings about every two seconds and breaks a 30 HP chunk about
every six. Keyed to breaks with a 3.5s window the streak was mathematically unreachable with
the starting tool - peak 0 over sixty swings - which is exactly when a player most needs the
encouragement. Keyed to connections at 5s it reaches 19 in nine seconds. Burn ticks
deliberately do not extend it, or a torch would hold a streak for one click.

**Rarity.** Five tiers (see AD-10) multiplying payout from 1.0x to 2.0x and scaling the whole
reveal - sparks, colour, shake, pitch, how long the banner holds.

**Collection and quests.** Every find is counted and kept. Three quests are active at a time
and rotate daily; the rotation is derived from the day number rather than stored and
replicated, so every server and client agrees on today's set without anyone sending it.
Progress carries the day it was earned on and is dropped when that is not today, which is the
whole of the rotation logic. Rewards are flat rather than map-scaled, so a quest is worth
doing early and fades into irrelevance by Troy - which is what stops it becoming the optimal
way to earn.

**Rebirth.** Needs the final map actually cleared, which needs its own flag: clearing a map
unlocks the *next* one, so the last map being unlocked only means the one before it was
finished. Wipes upgrades, tools and unlocks; keeps skins, the collection log and the count.
Worth a flat 25% income each, additive - so the tenth still matters and the fortieth does not
break the economy.

## Still open

- **Monetization** — gamepasses / dev products aren't in the source doc but are the norm for
  this genre. Out of scope until asked.
