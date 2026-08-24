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

## Open design questions

These need a decision before the relevant system is built:

1. **Ice representation** — voxel `Terrain` (Ice material, melt = write Air) vs. a grid of
   `Part` blocks. Terrain looks far better and melts organically; Parts are easier to score,
   replicate cheaply, and drive "X% melted" progress from. A hybrid (Parts for scoring
   chunks, Terrain for visual dressing) is likely the answer.
2. **Per-player vs. shared world** — does each player melt their own instance of the map,
   or do all players in a server melt one shared map? Shared is more social; per-player is
   the simulator norm and avoids "someone already cleared it".
3. **Map reset** — once a map is fully thawed, does it re-freeze for the next run?
4. **Monetization** — gamepasses / dev products are not in the source doc but are the norm
   for this genre. Out of scope until asked.
