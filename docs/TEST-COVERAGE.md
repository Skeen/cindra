# Cindra test-coverage matrix (ci-d7x audit)

Authoritative feature -> test map for the whole Cindra mod set. This is a
**recurring standard**: re-run the audit after major merges and keep this matrix
and the gap register in sync.

- **Integration** = `factorio-test` suites in `mods/cindra/tests/` (run by
  `cindra-test`; the companion APS suites are seeded per SETUP.md).
- **Unit** = plain-Lua suites in `mods/*/unit-tests/` (run by `npm run test:unit`,
  which now iterates every mod's `unit-tests/`, not just `mods/cindra`).
- **Python** = pixel tests in `mods/cindra/unit-tests/*.py` (NOT yet wired into a
  runner; see gap register / ci-3aw).

Baseline at audit time: **integration 369 pass** (366 default + 3 APS-absent
companion), **unit 22 files pass**. The with-APS companion suite (`test_aps_start`,
`test_aps_foundry`) needs the un-vendored `any-planet-start` portal mod (`APS_PATH`)
and is not runnable on a bare rig; it is exercised where APS is available.

## Feature -> test (the bead's enumerated feature list)

| Feature | Primary test(s) | Kind |
|---|---|---|
| Planet reachable (gated after Vulcanus) | `test_planet.lua` (space-connection + discovery-tech prereq) | integration |
| Planet **landable** (spawn + pad safe, zero landing damage) | `test_worldgen.lua` "LANDABLE:" (spawn tile, 17x17 pad, live tile-damage sweep on a character) | integration |
| Ribbon + orientation (E-W & N-S mapping) | `test_axis.lua`, `test_nightward_freeze_spike.lua` (orientation-independent) | unit |
| Terrain gradient bands (11 zones, organic, hot rings) | `test_worldgen.lua`, `test_terrain.lua` | both |
| Smooth fire/freeze damage, ramps with depth | `test_tile_damage.lua`, `test_terrain.lua` (intensity ramp), `test_ribbon.lua` | both |
| Impassable ice wall | `test_worldgen.lua`, `test_terrain.lua` (walkability) | both |
| Resource exclusion (lava / molten / beyond-wall / cold cap) | `test_worldgen.lua`, `test_resource_field.lua` | both |
| Size sliders: **zone-width (thin/thick)** geometry | `test_terrain.lua`, `test_resource_field.lua` (per-zone-width override) | unit |
| Size sliders: **Stone/Ice** map-gen controls | `test_worldgen.lua` (existence only -- EFFECT gap, ci-y19) | integration |
| Minable ice -> ice+calcite MIX (ci-9l6, replaces "chunks") | `test_ice_processing.lua` (proto + runtime drill) | integration |
| Ice -> water via vanilla chemical plant (retired ground crusher) | `test_ice_processing.lua` (recipe + runtime melt + removal guards) | integration |
| Lava recipe + foundry cast + stone loop-back | `test_lava.lua`, `test_bootstrap.lua` (runtime spine) | integration |
| Stone loop-back net-negative @0% and +300% (every source) | `test_materials_graph.lua`, `test_lava.lua`, `test_aluminium.lua`, `test_plastics.lua` | integration |
| Cryo-quench **removal** (pivot) guarded | `test_pivot.lua` | integration |
| Solar baseline vs Vulcanus (400kW vs 240kW; see note) | `test_solar_magnitude.lua` (engine-measured) | integration |
| Flare cycle (shape/timing/embodiment/forecast) | `test_flare.lua`, `unit-tests/test_flare.lua` | both |
| Panel-damage disposal-deficit rule | `test_panel_damage.lua`, `test_panel_damage_runtime.lua` (live driver) | integration |
| Storage: capacitor / molten-salt battery / dissipator | `test_storage.lua`, `test_power_prototypes.lua`, `test_disposal.lua`, `test_catchability.lua` | integration |
| Electric heater (proto + **runtime heat/no-fuel**) | `test_heater.lua` (incl. new powered-heats / unpowered-cold runtime) | integration |
| Building-heat (nightside cold-damage/thaw) | `test_building_heat.lua` | integration |
| Power diode (one-way transfer) | `test_power_diode.lua`, `unit-tests/test_diode.lua` | both |
| Mass driver (proto/gating/petro-free/prod modules) | `test_mass_driver.lua` | integration |
| Mass driver launch->**catch** (delivery runtime) | none -- **gap, ci-zcx** (PLAYTEST-deferred) | -- |
| Science pack petrochemical-free + tech (+ runtime craft) | `test_science.lua` | integration |
| Aluminium (leach + Bayer + electrolysis) | `test_aluminium.lua`, `test_red_mud.lua` | integration |
| Red mud / iron recovery / slag sinks | `test_red_mud.lua`, `test_materials_graph.lua` | integration |
| Plastics / methanol / catalysts / sulfur | `test_plastics.lua`, `test_sulfur.lua` | integration |
| Materials graph invariants (no deadlock, byproduct sinks) | `test_materials_graph.lua` | integration |
| Bootstrap-from-nothing viability | `test_bootstrap.lua`, `test_foundry_bootstrap.lua` | integration |
| Companion APS start (with / without APS) | `test_aps_start.lua`, `test_aps_absent.lua`, `test_aps_foundry.lua`, `unit-tests/test_aps_locale.lua` | both |
| env-scanner (buildable scanner + forecast readings) | `test_env_scanner.lua`, `mods/env-scanner/tests` + `unit-tests` | both |
| Misc: feedback tint / decoratives / no-paving / space art / graphics-audit / rock-tint / locale / branding | `test_feedback.lua`, `test_decoratives.lua`, `test_paving.lua`, `test_space_appearance.lua`, `unit-tests/*` | both |
| PlanetsLib interop (planet-str length, missing-parent placeholder, gas-percentage assert) | `test_planetslib_compat.lua` (see `docs/planetslib-evaluation.md`) | integration |

## Gap register (filed as ci- beads, discovered-from ci-d7x)

| Bead | Gap | Sev |
|---|---|---|
| ci-p00 | Starmap pixel test RED after ci-6i1 dark-terminator re-bake; hidden because python tests aren't run. Needs mayor (update contract vs re-bake). | P1 |
| ci-3aw | Python pixel tests (`test_planet_maps.py`, `test_starmap_lighting.py`) run by no runner. Wire in (blocked on ci-p00). | P2 |
| ci-7k6 | `cindra-ribbon-lethal-at` / `wall-at` settings have no world effect (dead knobs). Wire up or remove. | P2 |
| ci-zcx | Mass driver launch->catch has no runtime delivery test (only proto + hub-exists). | P2 |
| ~~ci-eao~~ | RESOLVED: the three orphaned PoC mods (`flare-poc`, `mass-driver`, `freeze-radius-poc`) were deleted -- the first two duplicate shipped `mods/cindra` coverage, freeze-radius-poc was a concluded, un-adopted spike (findings live in PLAYTEST.md / ci-b5i). `tests/no-orphan-suites.test.sh` now guards against a `mods/*/tests/` suite that no runner executes. | P2 |
| ci-y19 | Stone/Ice map-gen slider EFFECT untested (only existence). | P3 |
| ci-vjc | Horizontal (E-W) orientation has no full-worldgen integration test (mapping-only). | P3 |
| ci-xs6 | Minor polish: dissipator rated draw, freeze-temp override, graph exhaustiveness, cindra-start MP force path. | P3 |

## Notes

- The bead text says solar is "2x-3x Vulcanus"; DESIGN.md (400kW vs 240kW, ~1.67x)
  and `test_solar_magnitude.lua` encode ~1.67x. The tests follow DESIGN; the
  "2x-3x" figure in the bead is a spec-text discrepancy, not a coverage gap.
- What ci-d7x fixed directly (not beaded): wired the 3 orphaned Lua unit suites
  (`env-scanner` x2, `cindra-start` x1) into `test:unit`; added electric-heater
  runtime tests; added landability/spawn-safety tests; added a cindra-dev-default
  APS-absent guard assertion.
</content>
</invoke>
