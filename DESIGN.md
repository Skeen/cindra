# Cindra — The Ribbon World (design)

Authoritative design for the **Cindra** Factorio 2.1 / Space Age mod. This is
the implementation spec; if code contradicts it, the doc is right. The full
narrative brief this is derived from lives at `planet_design.md` in the parent
workspace (referenced by the originating issue `ci-m1n`); this file is the
in-repo condensation plus the concrete decisions taken during implementation.

> **Status: foundation.** §15 item 1 (planet + surface + ribbon temperature
> axis) is implemented and tested. The remaining §15 items (2–14) are the
> backlog in [`TODO.md`](TODO.md), each tracked by a follow-up bead (prefix
> `ci-`).

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

The map is a 1D **ribbon**: long east–west along the terminator (X axis), shallow
perpendicular (Y axis = the sunward–nightward temperature axis). Expansion is
mostly lateral; scarcity is on the perpendicular axis.

`mods/cindra/scripts/ribbon.lua` is the **single source of truth** for the
hot–cold axis. It is a pure module (no `game.*` / `prototypes.*`) mapping a Y
coordinate to:

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
recommendation. The damage *application* (ticking the player, freezing nightside
machines) and the physical wall geometry are **§15 item 2** — this foundation
supplies the axis value they consume, unit-tested end to end.

## 4. Planet prototype decisions — IMPLEMENTED (item 1)

- **Reachability (§6):** gated **after Vulcanus**. `vulcanus-cindra`
  space-connection + `planet-discovery-cindra` tech with
  `planet-discovery-vulcanus` prerequisite. (Any-Planet-Start removes the tech
  when you start *on* Cindra.)
- **Map gen:** Nauvis base (working water + buildable land), stripped of all
  vanilla ores, enemies, trees, rocks, cliffs. Cindra's real resources (stone,
  ice, bootstrap rocks) are added deliberately in **§15 item 3**, not via vanilla
  autoplace.
- **Surface properties:** heavy gravity (20), thin atmosphere (pressure 500), no
  biology. `solar-power` = 400 is a **placeholder baseline**; §15 item 7 sets the
  real ~10000%-of-Nauvis surface multiplier + dark-weighted daylight curve that
  drives the flare.
- **Art:** v1 reuses vanilla Vulcanus icons (a hot sunward world reads
  correctly). Bespoke ribbon/terminator art is a later pass — see
  [`PLAYTEST.md`](PLAYTEST.md). Gameplay does not depend on it.

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
