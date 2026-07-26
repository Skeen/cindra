# Cindra — backlog

Work follows the **§15 implementation order** from the design brief. Each item is
tracked by a bead (prefix `ci-`); check `bd show <id>` for detail and `bd ready`
for what's unblocked. Deliver each item as tested sub-commits, land through the
merge queue.

> **Test-first (non-negotiable):** every gameplay change needs an integration
> test (`mods/cindra/tests/test_*.lua`) and/or a plain-Lua unit test
> (`mods/cindra/unit-tests/`). See [`AGENTS.md`](AGENTS.md).

## Done

- [x] **§15-1 — Planet + surface + ribbon temperature axis.** `ci-m1n` (root).
  - Planet prototype: reachable (gated after Vulcanus), discovery tech, clean
    Nauvis-based map gen (no vanilla ores/enemies/trees/rocks), canonical
    physical params. `prototypes/planet.lua`.
  - Ribbon temperature axis: pure `scripts/ribbon.lua` (temperature / zone /
    damage-per-second / hard-wall), the single source of truth for the hot–cold
    axis. Settings-tunable. Unit-tested + integration-tested.
  - Companion mods: `cindra-start` (Any-Planet-Start choice), `cindra-dev-default`
    (dev picker default). Full APS chain loads headless.
  - Scaffold: vendored deps, test harness, `play.sh`, docs.

- [x] **§15-2 — Lethal edges.** `ci-318` (worldgen track `ci-9nj`).
  - Gradient ticking damage: `scripts/edge-damage.lua` consumes
    `ribbon.damage_per_second` and cooks (heat) / chills (cold) characters on the
    Cindra surface; custom `cindra-heat` / `cindra-cold` damage types
    (`prototypes/damage-types.lua`).
  - Hard-wall backstop: `scripts/worldgen.lua` voids tiles at/beyond `wall_at`
    (`out-of-map`), making the map a finite-width ribbon.
  - Nightside building-heat: `scripts/building-heat.lua` ticks cold damage on
    unheated machines past the cold threshold; a nearby heat source spares them.
  - Tested: `tests/test_edge_damage.lua`, `tests/test_worldgen.lua`,
    `tests/test_building_heat.lua`.
- [x] **§15-3 — Resources.** `ci-l72` (worldgen track `ci-9nj`).
  - `prototypes/resources.lua` + `scripts/resource-field.lua` (pure band geometry)
    + runtime placement in `scripts/worldgen.lua`: stone (ribbon), ice
    (nightside), scattered finite bootstrap rocks near the terminator, deep
    volatiles; best nodes at the lethal margins (edge-pushing).
  - Tested: `tests/test_worldgen.lua`, `unit-tests/test_resource_field.lua`.
  - *Unblocks 4, 5* — the mechanics track consumes `stone` / `ice` /
    `cindra-volatiles` (recipes are theirs to add).

## Backlog (§15 order)
- [x] **§15-4 — Ice processing.** `ci-rgv` — `prototypes/ice-processing.lua`: a
  ground-standing `cindra-ice-crusher` (clone of the space crusher; drops the
  zero-gravity gate + space-platform heating draw, gains a water output fluid box)
  plus two recipes the player picks between — `cindra-ice-crushing` (ice → water)
  and `cindra-ice-crushing-calcite` (ice → water + calcite, trading water for
  calcite). A private `cindra-ice-crushing` recipe category keeps the recipes off
  vanilla space crushers (and vice versa); gated behind the `cindra-ice-processing`
  tech. Tested: `tests/test_ice_processing.lua` (category isolation, water fluid
  box, ground-placeability, recipe shapes/ratio, no vanilla-crusher leak, tech
  gating, and an end-to-end powered crush of ice → water on Cindra).
- [ ] **§15-5 — Lava + metal.** `ci-8mw` — `1 stone + [ruinous power] → 5 lava`
  (fluid); Vulcanus foundry integration (brought, not re-unlocked); stone
  loop-back kept slightly net-consuming. *Needs 3.*
- [ ] **§15-6 — Cryo-hardened alloy.** `ci-gd4` — two-temperature quench building
  (hot molten input + cold cryo-coolant input in one craft). The signature.
  *Needs 4 + 5.*
- [ ] **§15-7 — Solar + flare.** `ci-9k6` — high surface solar multiplier +
  dark-weighted daylight curve; telegraph / fast-ramp / plateau / fast-decay;
  regular cadence; ~100× peak. Replaces the placeholder baseline in
  `prototypes/planet.lua`. *Blocks 8.*
- [ ] **§15-8 — Panel damage.** `ci-9ay` — disposal-deficit rule, degrade-before-
  death, self-correcting (negative feedback), dissipator-as-fuse. *Needs 7.*
- [ ] **§15-9 — Storage.** `ci-tii` — capacitor (fast spike) + molten-salt battery
  (bulk plateau, heat-upkeep or it "freezes") + dedicated dissipator.
- [~] **§15-10 — Electric heater.** `ci-f5l` — capped heat (600°) / uncapped power
  draw; roles: nightside warmth, flare sink, water boil-off, safe dissipation;
  built from a native ingredient (import-gated / clumsy elsewhere).
  - Building landed: `prototypes/electric-heater.lua` (heating-tower clone →
    electric source, 600° heat cap), item + recipe + `cindra-electric-heating`
    tech (variant of the heating-tower tech). Tested: `tests/test_heater.lua`
    (heat cap, electric-not-burner, situational-not-strictly-better vs heating
    tower §12, gated recipe/tech, runtime placement on Cindra).
  - TODO(ci-gd4): swap the vanilla recipe ingredients for the native cryo-alloy
    once it lands, to make the "clumsy off-world" import gate real.
- [ ] **§15-11 — Mass driver.** `ci-r10` — launch = power (bursty, flare-timed) +
  platform-side catcher; optional native projectile shell (A) vs pure-electric
  pods (B). Removes launch chemistry entirely.
- [ ] **§15-12 — Cindra science pack + tech tree.** `ci-3or` — petrochemical-free
  recipe (native inputs only); the unlocks for items 3–11.
- [ ] **§15-13 — Bootstrap traversal check.** `ci-uex` — verify landing → first
  foundry is traversable: no chicken-and-egg, no soft-lock; bootstrap-rock output
  is a one-time/durable cost only. *Needs 5.*
- [ ] **§15-14 — Balance pass.** `ci-63d` — tune all `(tune)` values against the
  lava energy cost; verify exportable buildings are **situational-not-strictly-
  better** than vanilla (§12 guardrail).

## Deferred / cross-cutting

- **Custom art.** v1 reuses vanilla Vulcanus icons. Bespoke ribbon/terminator
  ground, star-map, and orbital-backdrop art is a later art pass — see
  [`PLAYTEST.md`](PLAYTEST.md).
- **Optional self-sufficiency mode (§11).** CO₂ + water + power → carbon →
  plastic/sulfur synthesis, as an optional flare-timed endgame flex. Ship
  zero-chemistry/import first; not required for v1.
- **Advanced cryo heat-sink loop (§8).** Circulating coolant that re-chills on the
  nightside, as an optional depth variant over the consumed-material default.
- **Flare-response circuit building (§12-8).** Power-grid sensor / priority-switch
  for first-class flare automation.
