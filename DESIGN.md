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
- **Nightward edge = MATTER** (ice → water, calcite, coolant, volatiles). Lethal
  by cold.
- **Temperate ribbon (middle) = COMBINATION** (manufacture lava, process to
  metal, quench to alloy). The only survivable zone.

Every signature craft reaches toward **both** lethal edges. The player's core
skill is **conducting the flare**: catching a periodic power surge and routing it
into productive sinks, storage, or safe waste.

## 2. The four-part "well-formed planet" checklist (verify at the end, §14)

- **Signature building:** the cryo-quench (two-temperature) machine.
- **Central intermediate:** manufactured lava (everything routes through it).
- **Headline science:** Cindra science pack (petrochemical-free recipe).
- **Distinctive metal/chemistry solution:** *manufacture* lava from stone with
  power; launch with a mass driver so oil/coal chemistry → **zero**.

## 3. Geography & the ribbon (§4) — IMPLEMENTED (item 1)

The map is a 1D **ribbon**: long along the terminator, shallow perpendicular (the
sunward–nightward temperature axis). Expansion is mostly lateral; scarcity is on
the perpendicular axis.

**Orientation (worldgen v2):** the ribbon's long axis is a mod setting —
`east-west` (default: perpendicular axis = Y) or `north-south` (perpendicular axis
= X). `ribbon.perp(position)` / `ribbon.along(position)` are the **only** place
that maps a world position to the axes, so every downstream system (terrain,
damage, resources, feedback) reads the same perpendicular coordinate in both
orientations — no code hard-codes x/y.

`mods/cindra/scripts/ribbon.lua` is the **single source of truth** for the
hot–cold axis. It is a pure module (no `game.*` / `prototypes.*` / `settings.*`)
mapping a perpendicular coordinate `p` (and, via the accessors, a position +
orientation) to:

- **temperature(p)** — °C, `temp_center` (25) at `p`=0, rising linearly to
  `temp_hot_max` (1500) sunward and falling to `temp_cold_min` (−270) nightward,
  saturating at the per-side wall.
- **zone(p)** — `safe` | `hot_warn` | `hot_lethal` | `cold_warn` | `cold_lethal`.
- **damage_per_second(p)** — 0 inside the safe band, ramping 0→`max_dps` (200)
  across the margin, saturating at the lethal edge. Returns the matching damage
  type (`heat` sunward, `cold` nightward).
- **past_wall(p)** — the hard-wall backstop bounding the playable ribbon.

Band layout, from centre outward on **each** side. The hot and cold zones can be
tuned to **different depths** (per-side `hot_*` / `cold_*` boundaries); the table
shows the symmetric defaults (all `(tune)`, driven by the mod-setting sliders:
orientation, playable half-width, hot-zone depth, cold-zone depth):

| Band | Distance (tiles) | Terrain tile (placeholder) | Effect |
|---|---|---|---|
| Temperate ribbon | `|p| ≤ 24` | volcanic-soil | no damage; resources OK |
| Sand / icy margin | `24 < |p| < 96` | sand-1 / brash-ice | damage ramps 0→max; resources OK |
| Molten rock / ice wall | `96 ≤ |p| < 128` | volcanic-cracks-hot, lava / ice-rough | full damage; **no resources** |
| Hard wall (death zone) | `|p| ≥ 128` | out-of-map | impassable backstop |

The sunward lethal band splits into **molten rock** (inner) then the impassable
**lava ocean** (outer, vanilla lava tile) — fire damage across both prevents
reaching/pumping the free lava (the economy must *manufacture* lava). The
nightward lethal band is the **ice wall** (icy mountain range); beyond each wall
is the out-of-map **death zone**. The pure gradient geometry lives in
`scripts/terrain.lua` (unit-tested); `scripts/worldgen.lua` paints it per chunk.

**Chosen edge model:** Implementation **A** (gradient ticking damage) as the
teacher, plus **B** (hard wall) as the extreme-edge backstop, per the spec's
recommendation — both **IMPLEMENTED (item 2)**:

- **Player damage** — `scripts/edge-damage.lua` reads `ribbon.damage_per_second`
  each sweep and applies it to every character on the Cindra surface as
  `cindra-heat` (sunward) or `cindra-cold` (nightward). The ramp is a **smooth
  ease-in** (t², gentle at the zone entry, accelerating continuously with depth to
  the lethal edge, strictly increasing) so edge-pushing is a telegraphed, graded
  risk on both sides. Base ships no heat/cold damage type, so both are new
  prototypes in `prototypes/damage-types.lua`; `ribbon.lua` stays pure and returns
  the *semantic* kind, mapped to the concrete prototype at application time.
  Character resistances (gear) mitigate, never
  zero, the geography — that is edge-pushing.
- **Hard wall** — `scripts/worldgen.lua` voids every tile at/beyond the per-side
  wall (`out-of-map`) as chunks generate, so the playable map is a finite-width
  ribbon: constrained on the perpendicular axis, infinite along it. The damage
  ramp teaches; the void is the bulletproof floor.
- **Player feedback (worldgen v2, item 4)** — `scripts/damage-feedback.lua` shows
  a warm "Overheating" / cold "Freezing" screen banner while a character is in a
  hot / cold band on Cindra, cleared the instant it steps back to safety, so the
  cause of the damage is unmistakable. (v1 is a coloured GUI banner; a full-screen
  tint/shader is a follow-up.)
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
by `scripts/worldgen.lua` (`on_chunk_generated`), keyed to the ribbon perpendicular
axis (via `ribbon.perp`, correct in both orientations). The *pure* band geometry
lives in `scripts/resource-field.lua` (no `game.*`), so the placement is
deterministic and unit-testable; placement uses a coordinate hash (never
`math.random`) so it is reproducible and multiplayer-safe.

**Worldgen v2 resource rule (item 6):** resources spawn **ONLY in the survivable
playable band** — never in molten rock, the lava ocean, the ice wall, or the death
zone. The best of everything therefore sits at the *playable edge* (the deepest
survivable slice), preserving the edge-pushing reward without letting nodes hide
in lethal terrain. Stone + ice **density/size are new-game WORLD-GEN-SCREEN
sliders** (Frequency/Size/Richness), driven by the `cindra-stone` / `cindra-ice`
`autoplace-control` prototypes wired into the planet's map gen; `scripts/worldgen
.lua` reads the chosen values off `surface.map_gen_settings.autoplace_controls`.
`p` is the perpendicular coordinate.

| Resource (`cindra-*`) | Band on the axis | Richness | Yields |
|---|---|---|---|
| stone | temperate + sunward sand (`−safe ≤ p < hot_lethal`) | richest toward the HOT playable edge | `stone` |
| ice | nightward icy margin (`−cold_lethal < p < −safe`) | richer toward the COLD playable edge | `ice` (chunk) |
| volatiles | deepest survivable icy slice (just inside `−cold_lethal`) | richest at the cold edge | `cindra-volatiles` |
| bootstrap rock | terminator scatter (`|p| ≤ safe`) | n/a (finite scatter) | `stone` + `tungsten-ore` + a little `coal` |

Every resource is a Cindra-exclusive clone of a vanilla base (`stone` resource /
`huge-rock`); the shared vanilla prototypes are **never mutated**. Bootstrap rocks
are mined simple-entities (destroyed on mining → inherently finite, never a
per-craft supply, per the §6 no-soft-lock rule); tungsten (Vulcanus-legacy) is the
spec-endorsed landing metal, and each rock also drops a **little finite COAL** —
Cindra has NO mineable coal patch anywhere, so this bootstrap trickle is the only
coal (it seeds the foundry bootstrap, `ci-arw`). **Minable ice (item 8):** the ice field is mineable
and drops the vanilla `ice` item (Space Age's chunk-of-ice raw) that the ice
crusher (§15-4) consumes — one unbroken mine → crush → water loop. **Role only
lives here** — the recipes that *consume* these (ice processing §15-4, lava §15-5,
chemistry §11) belong to the mechanics track.

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
  `prototypes/cryo-alloy.lua`, `prototypes/flare.lua`, `prototypes/storage.lua`,
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
5 lava`), processed via **Vulcanus foundries** (brought, not re-unlocked) into
metal, with a **stone loop-back** that stays slightly net-consuming. The
signature product is the **cryo-hardened alloy**, forged in a **two-temperature
quench** (hot molten input + cold cryo-coolant input in the same craft) —
impossible on Vulcanus (no cold) or Aquilo (no lava).

Power is **high-intensity solar via the daylight curve**: a dark-weighted cycle
whose night floor ≈ Nauvis full day (runs the factory) and whose day peak ≈ the
**solar flare** (~100× baseline). The flare is **telegraphed and regular**, must
**never be 100%-catchable**, and undisposed surplus **damages the panels
producing it** (self-correcting, dissipator-as-fuse, degrade-before-death).
Storage is a two-tier puzzle: **capacitor** (fast spike) + **molten-salt battery**
(bulk plateau, heat-upkeep). The **electric heater** (capped heat / uncapped
draw) is the flare sink + water boil-off + nightside warmth. Goods leave by
**mass driver** (launch = power), so the planet's oil/coal chemistry footprint is
**zero**. The **Cindra science pack** is petrochemical-free.

Exportable buildings (capacitor, molten-salt battery, electric heater) must be
**situational-better, never strictly better** than vanilla (§12 guardrail).

### 5b. Cindra science + tech tree — IMPLEMENTED (item 12)

The headline science (§2 checklist). `prototypes/science.lua` adds the
**`cindra-science-pack`** and the machine + tech tree around it, expressing the
planet thesis (§1) in the player's largest standing activity: **research is a
power sink.**

- **Petrochemical-free, native inputs only.** The recipe consumes the signature
  `cindra-cryo-hardened-alloy` (fire quenched by ice), deep-nightside
  `cindra-volatiles`, and ice-chain `calcite` — no oil/coal/plastic/sulfur
  anywhere. You cannot make Cindra science without already commanding both lethal
  edges. This is the §2 "petrochemical-free headline science" requirement, locked
  by a blacklist **and** a native-only allowlist in tests.
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
  signature **cryo-quench** (which itself needs both lava and ice) and is
  researched with the **brought** vanilla packs — paying for the pack-unlock with
  the pack itself would be a soft-lock (§15-13). Every DEEPER unlock then costs the
  Cindra pack: **orbital launch (§15-11)** is folded in as the first, now branching
  off `cindra-science` and researched with the Cindra pack.

Tested end-to-end in `tests/test_science.lua`, including a powered starforge that
only makes crafting progress when it has power.

### 5a. Ice processing — IMPLEMENTED (item 4)

The nightside's matter economy starts here. `prototypes/ice-processing.lua` adds a
ground-standing crusher and the recipes that turn `ice` into the factory's water.
It REUSES the Space Age asteroid-crushing model, relocated from orbit to the
ground:

- **`cindra-ice-crusher`** — a clone of the space-platform `crusher`. Two
  adaptations make it work on Cindra: the vanilla crusher is gated to zero gravity
  (`surface_conditions`) and emits only solids, so the clone **drops the space-only
  surface condition** (and the space-platform heating draw) and **gains a water
  output fluid box**. Art is the vanilla crusher (v1 reuse); the added pipe has no
  bespoke connector sprite yet (a [`PLAYTEST.md`](PLAYTEST.md) entry).
- **Two recipes = the ratio knob.** `cindra-ice-crushing` grinds ice to water
  only; `cindra-ice-crushing-calcite` grinds the same ice to *less* water plus
  calcite. Choosing the recipe *is* choosing the water↔calcite ratio, matching the
  asteroid-crushing "pick your output" model.
- **A private recipe category** (`cindra-ice-crushing`, not vanilla `"crushing"`)
  keeps these recipes on the Cindra crusher only — they never appear in vanilla
  space-platform crushers, and vanilla asteroid recipes never appear in ours
  (the never-mutate-other-planets invariant, §6). The shared vanilla crusher
  prototype is deep-copied, never mutated.
- Gated behind the **`cindra-ice-processing`** tech (prereq: Cindra discovery);
  the full Cindra tech tree (§15-12) folds this in later.

Tested end-to-end in `tests/test_ice_processing.lua`, including a powered crush of
ice → water on the Cindra surface.

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
| Lava power cost | very high | rival/exceed baseline solar at scale |
| Molten iron | 500 lava + 1 calcite + 10 stone → 250 | Vulcanus values |
| Molten copper | 500 lava + 1 calcite + 15 stone → 250 | Vulcanus values |
| Surface solar multiplier | ~10000% (validate) | set by working back from lava energy cost |
| Baseline (night floor) | ≈ Nauvis full day | dark-weighted, never true zero |
| Flare peak vs baseline | ~100× | must stay relevant; <100% catchable |
| Electric heater temp cap | 600° | below reactor, above steam threshold |
| Stone loop-back net | slightly net-consuming | fresh mining stays a slow activity |
