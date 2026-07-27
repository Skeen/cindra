# Cindra — The Ribbon World (design)

Authoritative design for the **Cindra** Factorio 2.1 / Space Age mod. This is
the implementation spec; if code contradicts it, the doc is right. The full
narrative brief this is derived from lives at `planet_design.md` in the parent
workspace (referenced by the originating issue `ci-m1n`); this file is the
in-repo condensation plus the concrete decisions taken during implementation.

> **Status: foundation + worldgen + ice processing + headline science.** §15 items 1–4 are
> implemented and tested: the planet + surface + ribbon temperature axis (item 1),
> the lethal edges — gradient damage, hard-wall backstop, nightside building-heat
> (item 2), the world resources — stone / ice / volatiles / bootstrap rocks
> (item 3), and ice processing — the ground crusher + ice → water (+ calcite)
> recipes (item 4, §5a). The remaining §15 items (5–14) are the backlog in
> [`TODO.md`](TODO.md), each tracked by a follow-up bead (prefix `ci-`).

## 1. Core design thesis (the tie-breaker for every decision)

**The star gives too much, and survival is routing that surplus between fire and
ice.** Every system must express this one idea:

- **Sunward edge = ENERGY** (solar, flares, the power that makes lava). Lethal by
  heat.
- **Nightward edge = MATTER** (ice → water, calcite, volatiles). Lethal
  by cold.
- **Temperate ribbon (middle) = COMBINATION** (manufacture lava, process to
  metal, electrolyse to aluminium). The only survivable zone.

The core thesis is **power-manufactured aluminium + flare mastery**: the planet's
signature product is a metal torn out of rock and ice by brute electricity, so
mastering it *is* mastering the star's surplus. The player's core skill is
**conducting the flare**: catching a periodic power surge and routing it into
productive sinks (aluminium chief among them), storage, or safe waste. (The fire/
ice terrain remains as a survival hazard and the water source, not a two-
temperature craft: the earlier cryo-quench thesis is retired, ci-84s.)

## 2. The four-part "well-formed planet" checklist (verify at the end, §14)

- **Signature building:** the aluminium electrolysis cell (the power-manufactured
  metal). **Signature product:** aluminium (the primary mass-driver export).
- **Central intermediate:** manufactured lava (everything routes through it).
- **Headline science:** Cindra science pack (petrochemical-free recipe, built on
  the signature aluminium).
- **Distinctive metal/chemistry solution:** *manufacture* lava from stone with
  power and *electrolyse* aluminium from rock+ice with power; launch with a mass
  driver so oil/coal chemistry → **zero**.

## 3. Geography & the ribbon (§4) — IMPLEMENTED (item 1)

The map is a 1D **ribbon**: long along the terminator, shallow perpendicular to it
(the sunward–nightward temperature axis). Expansion is mostly lateral; scarcity is
on the perpendicular axis.

**Orientation** (setting `cindra-ribbon-orientation`, `scripts/axis.lua`): the
DEFAULT is **vertical** — the ribbon runs bottom-to-top (long **Y**), so the hot–cold
gradient runs left↔right (perpendicular **X**) with **HOT on the LEFT (west)**, cold
on the right. `horizontal` keeps the legacy layout (long east–west, gradient on Y,
hot sunward). Every band/damage/resource/terrain system reads the perpendicular
coordinate from `axis.perp`, so both orientations are correct and nothing
re-derives the direction. The **terrain tiles are the gradient** (`scripts/terrain.lua`):
from the hot edge inward — `lava-hot` → `lava` → `volcanic-cracks-hot` → temperate
land; mirrored on the cold side `ice-smooth` → `ice-rough` → `ammoniacal-ocean` (the
frozen "ice wall"). The three hot tiles sit exactly in the fire-damage zone, so the
visible terrain change lands on the damage boundary.

`mods/cindra/scripts/ribbon.lua` is the **single source of truth** for the
hot–cold axis. It is a pure module (no `game.*` / `prototypes.*`) mapping a
perpendicular coordinate to:

- **temperature(y)** — °C, `temp_center` (25) at Y=0, rising linearly to
  `temp_hot_max` (1500) sunward and falling to `temp_cold_min` (−270) nightward,
  saturating at the wall.
- **zone(y)** — `safe` | `hot_warn` | `hot_lethal` | `cold_warn` | `cold_lethal`.
- **damage_per_second(y)** — 0 inside the safe band, ramping 0→`max_dps` (200)
  across the margin, saturating at the lethal edge. Returns the matching damage
  type (`heat` sunward, `cold` nightward).
- **past_wall(y)** — the hard-wall backstop bounding the playable ribbon.

Band layout, from centre outward on **each** side (all `(tune)`, mirrored in mod
settings so they're editable without touching Lua):

| Band | Distance (tiles) | Effect |
|---|---|---|
| Safe ribbon | `|Y| ≤ 24` | temperate, no damage |
| Margin | `24 < |Y| < 96` | damage ramps 0→max (survivable briefly with gear) |
| Lethal deep edge | `|Y| ≥ 96` | full damage; best edge resources live here |
| Hard wall | `|Y| ≥ 128` | impassable backstop (§15-2) |

**Chosen edge model:** Implementation **A** (gradient ticking damage) as the
teacher, plus **B** (hard wall) as the extreme-edge backstop, per the spec's
recommendation — both **IMPLEMENTED (item 2)**:

- **Player damage** — `scripts/edge-damage.lua` reads `ribbon.damage_per_second`
  each sweep and applies it to every character on the Cindra surface as
  `cindra-heat` (sunward) or `cindra-cold` (nightward). Base ships no heat/cold
  damage type, so both are new prototypes in `prototypes/damage-types.lua`;
  `ribbon.lua` stays pure and returns the *semantic* kind, mapped to the concrete
  prototype at application time. Character resistances (gear) mitigate, never
  zero, the geography — that is edge-pushing.
- **Hard wall** — `scripts/worldgen.lua` voids every tile at/beyond `wall_at`
  perpendicular distance (`out-of-map`) as chunks generate, so the playable map is
  a finite-width ribbon: constrained on the perpendicular axis, infinite along the
  ribbon. The molten `lava`/`lava-hot` and frozen `ammoniacal-ocean` edge tiles are
  impassable, forming a natural wall just inside the void. The damage ramp teaches;
  the void is the bulletproof floor.
- **Nightside building-heat** — `scripts/building-heat.lua` ticks `cindra-cold`
  damage on unheated machines past the cold threshold (axis temperature <
  `freeze_temp`, default −30 °C). A heat source (heat pipe / reactor / heat
  interface, or the future electric heater, which registers by name) within range
  spares the machine. This is the "drag a heat umbilical nightward" pressure;
  cold *damage* is used rather than toggling `active` (read-only for crafting
  machines) and matches the spec's "take cold damage" option.

## 4. Planet prototype decisions — IMPLEMENTED (item 1)

- **Reachability (§6):** gated **after Vulcanus**. `vulcanus-cindra`
  space-connection + `planet-discovery-cindra` tech with
  `planet-discovery-vulcanus` prerequisite. (Any-Planet-Start removes the tech
  when you start *on* Cindra.)
- **Map gen:** Nauvis base (working water + buildable land), stripped of all
  vanilla ores, enemies, trees, rocks, cliffs. Cindra's real resources are added
  deliberately at runtime (see §4a), not via vanilla autoplace.
- **Surface properties:** heavy gravity (20), thin atmosphere (pressure 500), no
  biology. `solar-power` = 400 is a **placeholder baseline**; §15 item 7 sets the
  real ~10000%-of-Nauvis surface multiplier + dark-weighted daylight curve that
  drives the flare.
- **Art:** v1 reuses vanilla Vulcanus icons (a hot sunward world reads
  correctly). Bespoke ribbon/terminator art is a later pass — see
  [`PLAYTEST.md`](PLAYTEST.md). Gameplay does not depend on it.

## 4a. Resources & runtime worldgen — IMPLEMENTED (item 3)

The planet strips vanilla autoplace, so Cindra's resources are placed at runtime
by `scripts/worldgen.lua` (`on_chunk_generated`), keyed to the ribbon Y axis. The
*pure* band geometry lives in `scripts/resource-field.lua` (no `game.*`), so the
placement is deterministic and unit-testable; placement uses a coordinate hash
(never `math.random`) so it is reproducible and multiplayer-safe.

| Resource (`cindra-*`) | Band on the axis | Richness | Yields |
|---|---|---|---|
| stone | ribbon + hot margin (`−safe ≤ Y ≤ lethal_at`) | richest toward the HOT edge | `stone` |
| ice | nightside (`Y < −safe`) | richer deeper (colder) | `ice` |
| volatiles | deep cold-lethal (`Y ≤ −lethal_at`) | richest deepest | `cindra-volatiles` |
| bootstrap rock | terminator scatter (`|Y| ≤ safe`) | n/a (finite scatter) | `stone` + `iron-ore` + `copper-ore` + `coal` + a little `tungsten-ore` |

The best of everything sits at the lethal margins (edge-pushing reward). Every
resource is a Cindra-exclusive clone of a vanilla base (`stone` resource /
`huge-rock`); the shared vanilla prototypes are **never mutated**. Bootstrap rocks
are mined simple-entities (destroyed on mining → inherently finite, never a
per-craft supply, per the §6 no-soft-lock rule). Cindra has **no ore/coal patches
at all** (ci-8nh), so these finite rocks are the only landing-tier metal: each drops
stone plus a small trickle of iron ore + copper ore + coal (and a little tungsten,
the Vulcanus-legacy metal accepted in §5) — enough to hand-smelt a first trickle of
plates and to crude-liquefy the lubricant for the first foundry on a start-on-Cindra
game (the foundry bootstrap, ci-arw, §5b). The coal in particular is the **only coal
on the planet** (no mineable coal source), spent once and never scalable. **Role
only lives here** — the recipes that *consume* these (ice processing §15-4, lava
§15-5, chemistry §11, the foundry bootstrap `prototypes/lubricant.lua`) belong to the
mechanics track.

## 4b. File-ownership map (parallel tracks — avoid conflicts)

The post-foundation work runs as parallel beads. To keep merges clean, each track
owns a disjoint set of files. **Coordinate via `gt mail` before editing another
track's files or a shared file.**

- **Worldgen track (`ci-9nj`, this work):** `prototypes/damage-types.lua`,
  `prototypes/resources.lua`, `scripts/edge-damage.lua`,
  `scripts/building-heat.lua`, `scripts/worldgen.lua`,
  `scripts/resource-field.lua`, `scripts/driver.lua`, and their tests. Reads (does
  not own) `scripts/ribbon.lua`.
- **Mechanics/economy track (`ci-4xj`):** the recipe / building / tech / power
  files — e.g. `prototypes/ice-processing.lua`, `prototypes/lava.lua`,
  `prototypes/aluminium.lua`, `prototypes/flare.lua`, `prototypes/storage.lua`,
  `prototypes/electric-heater.lua`, `prototypes/mass-driver.lua`,
  `prototypes/science.lua`, and their runtime. Consumes the worldgen resources
  (`stone` / `ice` / `cindra-volatiles`) and registers heat sources by adding
  their name to `building-heat.HEAT_SOURCE_NAMES`.
- **Companion mods (`ci-27s`):** `mods/cindra-start`, `mods/cindra-dev-default`.
- **Foundation-owned, shared (edit minimally, additively):** `data.lua`,
  `control.lua`, `settings.lua`, `prototypes/planet.lua`. Each track appends its
  own `require` / handler registration; the base planet prototype stays the
  foundation's.

## 5. Systems still to build (summary; detail in TODO.md)

Manufactured **lava** is the central intermediate (`1 stone + [ruinous power] →
5 lava`), cast in a **dedicated Cindra lava-manufacturer** (a high-speed,
high-draw machine, not the shared foundry — ci-e8a) and then processed via
**Vulcanus foundries** (brought, not re-unlocked) into metal, with a **stone
loop-back** that stays slightly net-consuming. The manufacturer exists to fix
usability without cheapening lava: the machine's crafting speed sets how many
machines feed a foundry (a **single-digit** count, vs ~100 on the plain
foundry), while its draw is pinned proportional to that speed so **energy per
unit lava is unchanged and ruinous**. Machine count and per-lava energy are the
same knob on a single machine type, so lava gets its OWN machine to decouple
them. The signature product is **aluminium** (ci-txh), electrolysed from
rock+ice feedstock (`stone + calcite → alumina → [ruinous power] → aluminium`) in
a **dedicated high-draw electrolysis cell** — the planet's biggest continuous
power sink and its primary mass-driver export. Aluminium carries the core thesis
(power-manufactured metal, petrochemical-free) and is the input to the headline
science pack. (The earlier signature — a cryo-hardened alloy forged in a
two-temperature quench — is retired, ci-84s: the fire/ice terrain stays as a
hazard and water source, not a craft.)

Power is **high-intensity solar via the daylight curve**: a dark-weighted cycle
whose night floor ≈ Nauvis full day (runs the factory) and whose day peak ≈ the
**solar flare** (~100× baseline). The flare is **sporadic but telegraphed**
(ci-2ba, overriding the old "regular/predictable cadence" of §10): its *timing*
is randomized within a band so you cannot predict the next one by clock, yet
every event is still preceded by a **warning window** (alarm + countdown) so you
can react and circuit-automate a response per event, and the magnitude stays
~100× so capacity sizing still matters. It must **never be 100%-catchable**, and
undisposed surplus **damages the panels producing it** (self-correcting,
dissipator-as-fuse, degrade-before-death).
Storage is a two-tier puzzle: **capacitor** (fast spike) + **molten-salt battery**
(bulk plateau, heat-upkeep). The **electric heater** (capped heat / uncapped
draw) is the flare sink + water boil-off + nightside warmth. Goods leave by
**mass driver** — a reskinned rocket-silo whose launch burns an **aluminium can**
+ **aluminium-powder solid fuel** + a huge slug of power (§15-11, ci-o39), never
oil-based rocketry — so the planet's oil/coal chemistry footprint is **zero**. The
**Cindra science pack** is petrochemical-free.

Exportable buildings (capacitor, molten-salt battery, electric heater) must be
**situational-better, never strictly better** than vanilla (§12 guardrail).

### 5b. Cindra science + tech tree — IMPLEMENTED (item 12)

The headline science (§2 checklist). `prototypes/science.lua` adds the
**`cindra-science-pack`** and the machine + tech tree around it, expressing the
planet thesis (§1) in the player's largest standing activity: **research is a
power sink.**

- **Petrochemical-free, native inputs only.** The recipe consumes the signature
  `cindra-aluminium` (the power-manufactured metal), deep-nightside
  `cindra-volatiles`, and ice-chain `calcite` — no oil/coal/plastic/sulfur
  anywhere. You cannot make Cindra science without already commanding both lethal
  edges (power-manufactured aluminium reaches toward fire/power; the volatiles
  toward cold). This is the §2 "petrochemical-free headline science" requirement,
  locked by a blacklist **and** a native-only allowlist in tests.
- **A significant power sink.** Two honest levers: a long craft
  (`energy_required`) run in a dedicated **`cindra-starforge`** (a clone of
  assembling-machine-3 with a ~10 MW active draw, far above a normal assembler).
  One pack costs on the order of the flare's own scale in energy, so science
  throughput scales with captured flare / baseline power (ties to §15-7/§15-9 and
  the balance pass §15-14). A private `cindra-science` recipe category keeps the
  recipe off vanilla assemblers and vice versa.
- **A real science pack.** It is a `science-pack`-subgroup item appended to the
  shared labs' `inputs` — purely additive, changing no other planet's gameplay
  (no other planet can make or needs it), which is the only way a new pack can be
  researched at all (research is force-wide; there is no per-surface lab-inputs
  API). Tested behaviourally: a lab accepts the Cindra pack and refuses a non-pack.
- **The folded tech tree.** `cindra-science` (the pack-unlock) is gated behind the
  signature **aluminium** tech (which itself needs both lava and ice) and is
  researched with the **brought** vanilla packs — paying for the pack-unlock with
  the pack itself would be a soft-lock (§15-13). Every DEEPER unlock then costs the
  Cindra pack: **orbital launch (§15-11)** is folded in as the first, now branching
  off `cindra-science` and researched with the Cindra pack.

Tested end-to-end in `tests/test_science.lua`, including a powered starforge that
only makes crafting progress when it has power.

### 5a. Ice processing — IMPLEMENTED (item 4)

The nightside's matter economy starts here. `prototypes/ice-processing.lua` adds a
**two-stage** chain that turns `ice` into the factory's water, faithful to the
Space Age asteroid model (whose crusher is item-only): the crusher grinds solids;
the fluid appears only at a later melt step.

- **Stage 1 — `cindra-ice-crusher`** (SOLID → SOLID): a clone of the
  space-platform `crusher`. The vanilla crusher is gated to zero gravity
  (`surface_conditions`) and emits only solids, so the clone **drops the space-only
  surface condition** (and the space-platform heating draw) and stays item-only —
  it grinds `ice` into `cindra-crushed-ice` shards and emits **no fluid** (a
  crusher is a grinder, not a boiler — ci-4or). Art is the vanilla crusher (v1
  reuse).
- **Two crush recipes = the ratio knob.** `cindra-ice-crushing` grinds ice to
  shards only; `cindra-ice-crushing-calcite` grinds the same ice to *fewer* shards
  plus a `calcite` item. Choosing the recipe *is* choosing the water↔calcite ratio
  (fewer shards ⇒ less downstream water), matching the asteroid-crushing "pick your
  output" model.
- **Stage 2 — `cindra-ice-melter`** (SOLID → FLUID): a clone of the
  `chemical-plant` that runs `cindra-ice-melting` (crushed-ice → `water`). This
  separate heat/melt step is the **only** place the fluid is born. Art is the
  vanilla chemical plant (v1 reuse).
- **Private recipe categories** (`cindra-ice-crushing` and `cindra-ice-melting`,
  not vanilla `"crushing"`/`"chemistry"`) keep each recipe on its Cindra machine
  only — they never appear in vanilla space crushers or chemical plants, and
  vanilla recipes never appear in ours (the never-mutate-other-planets invariant,
  §6). Both shared vanilla prototypes are deep-copied, never mutated.
- Gated behind the **`cindra-ice-processing`** tech (prereq: Cindra discovery),
  which unlocks both machines and all three recipes; the full Cindra tech tree
  (§15-12) folds this in later.

Tested end-to-end in `tests/test_ice_processing.lua`, including a powered crush of
ice → shards → water on the Cindra surface, asserting the crusher emits no fluid.

### 5b. Start-on-Cindra foundry bootstrap — IMPLEMENTED (ci-arw)

Normal play **imports** foundries from Vulcanus: the vanilla `foundry` build
recipe is surface-gated to `pressure = 4000` (Vulcanus) and costs oil `lubricant`,
so it can never be crafted on Cindra (pressure 500, no oil) — you carry finished
foundries over. But a **start-on-Cindra** game (`any-planet-start`, `mods/cindra-start`)
has no Vulcanus to import from and no petrochemistry, so with only the vanilla
recipe it would **soft-lock**. `prototypes/lubricant.lua` adds a native, gated path:

- **`cindra-crude-lubricant`** (bootstrap): `coal → lubricant`. Its coal comes only
  from the **finite** hand-mined bootstrap rocks (§4a) — Cindra has no mineable
  coal — so it builds the first foundry(ies) once and can never scale (a one-time
  durable cost, per §6).
- **`cindra-mineral-lubricant`** (sustain): `stone + water → lubricant`, a renewable
  petrochemical-free "silica oil". Deliberately effortful (heavy stone + water +
  power) so it is situational-not-strictly-better than oil lubricant (§12).
- **`cindra-field-foundry`**: a `crafting-with-fluid` recipe that yields the vanilla
  `foundry` item **without** the pressure gate, so it is Cindra-buildable. Costlier
  than the import recipe, so a post-Vulcanus player keeps importing.

All three are locked and unlocked by one tech, **`cindra-improvised-metallurgy`**
(prereq: Cindra discovery, which itself sits behind Vulcanus in normal play, §6).
`mods/cindra-start/control.lua` **pre-researches** that tech (plus `foundry`,
`cindra-lava`, `cindra-ice-processing`) on a Cindra start, so the from-scratch
opening reaches the lava→metal economy with no soft-lock. The shared vanilla
`foundry` recipe and `lubricant` fluid are **never mutated** — the imported-foundry
path (normal play) is untouched. Tested in `tests/test_foundry_bootstrap.lua`
(prototypes + never-mutate + a powered coal→lubricant craft + an on-Cindra lava
caster + foundry reaching the metal economy) and, under the APS invocation,
`tests/test_aps_foundry.lua` (the
pre-research grant). The physical starting **kit** (machines, power, initial items)
is the bootstrap-traversal work (§15-13, ci-uex), layered on top of this.

## 6. Invariants (locked by tests as they land)

- **🚨 NEVER MUTATE GLOBAL STATE THAT AFFECTS OTHER PLANETS.** This mod adds
  Cindra; it MUST NOT change Nauvis/Vulcanus/Gleba/Fulgora/Aquilo gameplay.
  Prefer per-surface runtime overrides, Cindra-exclusive entity clones, or
  handlers gated on `surface.name == "cindra"`. Deep-copy shared vanilla tables
  before overriding (never mutate the shared table).
- **`script.on_nth_tick(N, fn)` is REPLACE-not-add.** One handler per N; give each
  periodic system a distinct N.
- **The ribbon axis has one source of truth:** `scripts/ribbon.lua`. Every system
  that needs "where am I on the hot–cold axis" reads it; don't re-derive the
  curve.

## 7. Key tuning values (all `(tune)`, §16)

| Value | Start | Notes |
|---|---|---|
| Ribbon safe half-width | 24 tiles | no-damage band |
| Ribbon lethal-at | 96 tiles | damage saturates |
| Ribbon wall-at | 128 tiles | hard backstop |
| Ribbon peak dps | 200 | survivable briefly with gear |
| Lava recipe | 1 stone → 5 lava | fixed per spec; power is the lever |
| Lava manufacturer | crafting_speed 64, 40 MW draw | dedicated caster (ci-e8a); draw÷speed matched to the foundry so energy-per-lava is fixed; a single-digit count feeds one foundry |
| Lava power cost | very high | rival/exceed baseline solar at scale |
| Molten iron | 500 lava + 1 calcite + 10 stone → 250 | Vulcanus values |
| Molten copper | 500 lava + 1 calcite + 15 stone → 250 | Vulcanus values |
| Surface solar multiplier | ~10000% (validate) | set by working back from lava energy cost |
| Baseline (night floor) | ≈ Nauvis full day | dark-weighted, never true zero |
| Flare peak vs baseline | ~100× | must stay relevant; <100% catchable |
| Electric heater temp cap | 600° | below reactor, above steam threshold |
| Stone loop-back net | slightly net-consuming | fresh mining stays a slow activity |
