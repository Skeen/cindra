# Cindra Freeze-Radius PoC (ci-b5i)

A **standalone** spike that measures, headlessly, whether a **high
`heating_radius`** can drive Cindra's freeze mechanic by INVERSION: turn on the
engine's whole-surface freeze (`entities_require_heating = true`) and keep the
warm band thawed with a sparse LINE of high-radius heat emitters on the
lava/fire edge, so "from the lava side outward, ice starts where the warmth runs
out." Revisits ci-p7z; lives in its own mod dir, shares no files, touches no
other planet (it acts only on its own `freeze-radius-poc` planet surface).

## Headline answer: **YES, it works - with a hard clamp at ~100 tiles.**

A single hot heat-interface with `heating_radius = 100` keeps a freezable machine
**100 tiles away** thawed on a surface with `entities_require_heating = true`,
while an identical machine 100 tiles from no emitter freezes for real. Proven by
reading `LuaEntity.frozen` in `factorio-test`.

## What it proves (all green in `factorio-test`)

| Claim | Test |
|---|---|
| r100 emitter thaws a machine **100 tiles away**; control at 100t with no emitter freezes | `tests/test_headline.lua` |
| Works for assembler, inserter AND pipe (native pipe/fluid freeze the damage model can't do); an emitter **thaws already-frozen** machines (no hysteresis) | `tests/test_headline.lua` |
| reach ≈ `heating_radius` below the clamp; **HARD ENGINE CLAMP at ~100 tiles** (r150/r200/r300 reach no further than r100) | `tests/test_radius_sweep.lua` |
| Reactor, heat-pipe AND heat-interface all honour a large radius identically; reach is **temperature-independent** (any hot buffer) | `tests/test_source_kinds.lua` |
| The thaw region is a **Chebyshev SQUARE** (thawed iff \|dx\|≤R and \|dy\|≤R), not a disc | `tests/test_shape.lua` |
| One fire-edge line thaws a ~100-wide warm band; the night beyond freezes; overshoot is bounded by the clamp | `tests/test_band_split.lua` |
| Square reach ⇒ a **straight** freeze front (no scallop) for spacing ≤ ~2·reach; cold gaps open beyond that | `tests/test_band_split.lua` |
| A sparse high-radius line covers a band with >1000× fewer emitters than a radius-1 grid | `tests/test_perf.lua` |

## The engine model (what the spike discovered)

**Freezing is per-entity and energy-gated.** `EntityPrototype.heating_energy`
(space-age) > 0 makes an entity freezable; space-age sets it on machines
(assembler 100 kW, inserter 30 kW, pipe 1 kW, storage-tank 100 kW, …). A freezable
entity freezes on an `entities_require_heating` surface unless a heat source
supplies that heating energy within range.

**`heating_radius` (float, default 1, on HeatInterface / Reactor / HeatPipe) is
that range.** A hot source thaws freezable entities inside it as an ambient
source - no heat-network connection needed (the 2.0.64 "heat interface can now
heat entities and tiles" feature). Key measured facts:

- **reach ≈ radius, clamped at ~100 tiles.** r5→5, r10→10, r50→~48, r100→100.
  r128/r150/r200/r300 all reach the *same* ~100–101 tiles. **Max effective
  heating radius ≈ 100.** Setting it higher is inert.
- **The region is a SQUARE (Chebyshev), not a circle.** Thawed iff both axes are
  within reach. The corner (100,100) thaws; (101, y) freezes. This is why an
  emitter line yields a **straight** freeze front.
- **Prevent is fast, thaw is slower, both hold.** An emitter present when a
  machine is placed keeps it thawed within ~10 s; an emitter arriving at an
  already-frozen machine reclaims it out to full reach in ~30–50 s. Steady state
  sustains indefinitely (verified to ~3.8 min).
- **Source-agnostic + temperature-independent.** Reactor, heat-pipe and
  heat-interface behave identically; reach is the same from a 100 °C buffer to a
  1000 °C buffer (a distance mechanic, not an energy-falloff one).
- **`entities_require_heating` is whole-planet and cannot be associated onto a
  scratch surface** (`LuaPlanet::associate_surface` refuses it). The PoC uses the
  planet's own surface via `LuaPlanet::create_surface`. This confirms ci-p7z: the
  freeze is whole-surface, not scopeable - hence the inversion approach.

## Design recommendation for Cindra

- **`heating_radius = 100`** - the max effective value; higher is wasted.
- **Emitter spacing along the fire edge ≤ ~190 tiles** (2·reach, with margin) for
  a straight, gap-free ice line. Far more generous than the circular-reach
  `sqrt(R²−(S/2)²)` scallop the bead anticipated, because the engine reach is a
  square.
- **Warm-band width per single edge line ≤ ~100 tiles.** The ~128-tile functional
  ribbon needs the ice line placed ≤100 tiles from the fire edge, *or* a second
  interior emitter row to thaw the full width. The deep nightward tail (>100 from
  the only line) stays frozen - exactly "ice starts where the warmth runs out."
- **Emitter kind:** a fueled reactor-typed emitter (heating-tower-like: burn fuel
  to project warmth) is the natural gameplay fit; heat-interface is the simplest
  test rig (buffer temperature is directly settable, no fuel).

## Caveats / not covered headless

- **UPS / per-tick cost is NOT measured** (the Lua sandbox has no wall clock).
  The entity-count collapse (a handful of emitters vs thousands of heat pipes) is
  strongly favourable, but the engine's per-emitter O(R²) heating scan at radius
  100 is an untested regime. Flagged to `PLAYTEST.md` for a live UPS capture
  before committing to the mechanic.
- **Frost overlays / stopped-machine visuals / native pipe-freeze animation** need
  a display; also flagged to `PLAYTEST.md` (known Cindra GLX-headless limit). The
  frozen *state* (machines stop, pipes freeze) is proven headless via
  `LuaEntity.frozen`.

## Running the tests

The Factorio install and `node_modules` are gitignored (see repo-root `SETUP.md`);
`factorio-test` is built by the repo `flake.nix`. Inside `nix develop`, seed the
framework and point the runner's `--mod-path` at this mod:

```sh
mkdir -p factorio-test-data-dir/mods
ver=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$FACTORIO_TEST_MOD/info.json" | head -1)
ln -sfn "$FACTORIO_TEST_MOD" "factorio-test-data-dir/mods/factorio-test_$ver"

./node_modules/.bin/factorio-test run \
  --factorio-path "${FACTORIO_PATH:-./factorio/bin/x64/factorio}" \
  --data-directory ./factorio-test-data-dir \
  --mod-path <repo>/mods/freeze-radius-poc \
  --mods space-age quality elevated-rails recycler
```

All 13 tests should pass.

## Why the tests use disjoint "fresh regions"

A hot emitter warms the ground TILES within its radius, and those tiles do NOT
cool back down on any test timescale. So two measurements that share ground
contaminate each other (an old emitter's warmth thaws a later probe). Every
measurement therefore sits on fresh, never-heated ground handed out by a
monotonic cursor (`tests/helpers.lua`, `H.fresh_region`). This is what makes the
suite deterministic - do not reuse a region.
