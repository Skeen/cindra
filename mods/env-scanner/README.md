# Environmental Scanner (standalone)

A buildable **circuit-network hub** that reads the surface it stands on and
broadcasts it as circuit signals. Works on **any planet**; it is *situational*,
not strictly-better than a clock combinator: valuable where a daylight or flare
rhythm drives your factory, unremarkable where it does not.

Realizes `planet_design.md` §12 item 8 ("circuit-logic building"). Built as its
own independent mod (the same standalone pattern as `mass-driver`, `flare-poc`,
`quench-poc`), so it can ship in parallel and has no shared-file conflict with
`mods/cindra`.

## What it does

Place the **Environmental scanner** and wire it into a circuit network. Every
`UPDATE_INTERVAL` ticks (default 15) it refreshes its output with the readings
below. Recipe is deliberately **chemistry-free** (iron + copper + electronic
circuits: no plastic, sulfur, or oil), preserving Cindra's zero-chemistry
identity while staying craftable on a vanilla planet.

## Signals

Values are integers (circuit networks carry no floats), so continuous readouts
are scaled to fixed integer ranges. A network treats an absent signal as `0`.

### Generic (any surface)

| Signal | Meaning | Range / scaling |
|---|---|---|
| `env-daytime` | Day/night cycle position (time-of-day) | permille, `0..1000` (0 = noon, 500 = midnight) |
| `env-daylight` | Daylight fraction from the solar curve | percent, `0..100` |
| `env-solar` | Current solar output = daylight × surface solar multiplier | percent (can exceed 100 on Cindra during a flare) |
| `env-tick-of-day` | Tick within the current day | `0..DAY_TICKS-1` |

`env-tick-of-day` is scaled by a nominal day length (`config.DAY_TICKS`,
default 25000 = Nauvis' day). It is an approximation where a surface's day
length differs; `env-daytime` (the normalised position) is always exact.

The daylight fraction uses the engine's own solar curve
(`dusk`/`evening`/`morning`/`dawn` read from the surface), so it matches what a
solar panel actually produces there.

### Cindra flare forecast (optional)

Emitted **only** when a flare-forecast source is present (see below). Absent
otherwise, so the mod runs standalone with no Cindra.

| Signal | Meaning | Range / scaling |
|---|---|---|
| `env-flare-countdown` | Ticks until the next flare ramp | ticks |
| `env-flare-phase` | Current flare phase, as a code | `calm=0, warning=1, ramp=2, plateau=3, decay=4` |
| `env-flare-intensity` | Current intensity in Nauvis-full-day equivalents | percent (`100` = baseline 1×, `10000` = 100× peak) |

This is the planet's Fulgora-accumulator-rhythm equivalent: wire the countdown +
phase to drive the flare-response ladder (fill capacitors → overclock
lava/quench/boil-off → dump to dissipators) that `planet_design.md` §10
describes.

## Cross-mod contract (for the flare system, ci-9k6)

The scanner does **not** own or duplicate any flare-timing logic. It asks for a
forecast via a documented remote interface. The flare system (or any mod)
registers it:

```lua
-- In the flare system's control.lua:
remote.add_interface("cindra-flare", {
  forecast = function(surface_index)
    -- Return nil when no flare schedule applies to this surface, else:
    return {
      countdown = <ticks:int>,          -- until the next ramp
      phase     = <"calm".."decay">,    -- one of the five phase names
      intensity = <number>,             -- Nauvis-full-day equivalents (1.0 = baseline)
    }
  end,
})
```

If no mod registers `cindra-flare`, the flare signals stay inactive. The
interface name is defined once in `scripts/config.lua`
(`C.FLARE_INTERFACE` / `C.FLARE_METHOD`); coordinate any change with the
flare-system owner.

## Layout

```
info.json / data.lua / control.lua
prototypes/scanner.lua   entity (constant-combinator clone) + item + recipe + virtual signals
scripts/readings.lua     PURE reading maths (solar curve, signal scaling) -- single source of truth
scripts/config.lua       shared names/constants + the cross-mod contract
scripts/forecast.lua      optional flare-forecast source (remote interface; test seam)
scripts/scanner.lua       runtime: track scanners, compute + write signals
tests/test_scanner.lua    factorio-test integration (prototype shape + runtime signals + flare path)
unit-tests/test_readings.lua  plain-Lua unit test of the pure maths
```

## Tests

Plain-Lua unit tests (pure logic, no Factorio):

```sh
cd mods/env-scanner && lua unit-tests/test_readings.lua   # inside `nix develop`
```

factorio-test integration suite. `cindra-test` targets `mods/cindra`, so this
standalone mod uses the CLI directly with the flake-built factorio-test seeded
into the data dir. From the repo root, inside `nix develop`:

```sh
mkdir -p factorio-test-data-dir/mods
ver=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$FACTORIO_TEST_MOD/info.json" | head -1)
ln -sfn "$FACTORIO_TEST_MOD" "factorio-test-data-dir/mods/factorio-test_$ver"

./node_modules/.bin/factorio-test run \
  --factorio-path "${FACTORIO_PATH:-./factorio/bin/x64/factorio}" \
  --data-directory ./factorio-test-data-dir \
  --mod-path ./mods/env-scanner \
  --mods space-age quality elevated-rails recycler
```

## Notes

* Entity art and signal icons are **placeholder** (a renamed constant combinator;
  reused base signal icons). Bespoke art is tracked as a follow-up bead.
* Never mutates another planet: it only adds its own entity and reads surface
  state. Setting a constant combinator's own output affects nothing but that
  building's wires.
