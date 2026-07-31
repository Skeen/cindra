# Environmental Scanner (standalone)

A buildable **circuit-network hub** that reads the surface it stands on and
broadcasts it as circuit signals. Works on **any planet**; it is *situational*,
not strictly-better than a clock combinator: valuable where a daylight or flare
rhythm drives your factory, unremarkable where it does not.

Realizes `planet_design.md` §12 item 8 ("circuit-logic building"). Built as its
own independent mod (the same standalone pattern as `mass-driver` and
`flare-poc`), so it can ship in parallel and has no shared-file conflict with
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

### Cindra flare forecast (optional, reactive early-warning)

Emitted **only** when a flare-forecast source is present **and** a sporadic flare
is actually imminent or active. Cindra's flares are **sporadic** (ci-2ba): they
fire at randomized, unpredictable times, so there is no schedule to read off a
clock. This block therefore appears **only once a flare enters its telegraph**
(and stays through the surge), and is absent during calm - which is exactly what
makes the scanner valuable: it is an **early-warning device**, not a clock.

| Signal | Meaning | Range / scaling |
|---|---|---|
| `env-flare-countdown` | Ticks until the ramp begins (during the telegraph) | ticks |
| `env-flare-phase` | Current flare phase, as a code | `calm=0, warning=1, ramp=2, plateau=3, decay=4` |
| `env-flare-intensity` | Current intensity in Nauvis-full-day equivalents | percent (`100` = baseline 1×, `10000` = 100× peak) |

This is the planet's Fulgora-accumulator-rhythm equivalent, but **event-driven**:
when the block appears, wire the countdown + phase to drive the flare-response
ladder per event (fill capacitors → overclock lava/aluminium/boil-off → dump to
dissipators). Because timing is random, the circuit must REACT to this signal
rather than anticipate a fixed cadence.

## Cross-mod contract (for the flare system, ci-9k6 / ci-2ba)

The scanner does **not** own or duplicate any flare-timing logic. It asks for a
forecast via a documented remote interface. The flare system (or any mod)
registers it:

```lua
-- In the flare system's control.lua:
remote.add_interface("cindra-flare", {
  forecast = function(surface_index)
    -- Return nil during CALM (no imminent/active flare) or for a non-cindra
    -- surface. Once a sporadic flare is telegraphing or active, return:
    return {
      countdown = <ticks:int>,          -- until the ramp begins (0 once active)
      phase     = <"warning".."decay">, -- the current phase name
      intensity = <number>,             -- Nauvis-full-day equivalents (1.0 = baseline)
    }
  end,
})
```

If no mod registers `cindra-flare`, or it returns nil, the flare signals stay
inactive. The
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

* Entity + item art is the user-supplied **radio-station** set by Hurricane
  (CC-BY; see `graphics/entity/scanner/ATTRIBUTION.md` and `CREDITS.md`). The
  building keeps a static first-frame `sprites` for ghost/blueprint/factoriopedia
  previews and the runtime draws animated body + emissive-glow overlays on each
  placed scanner (a constant-combinator body cannot frame-animate on its own).
  The seven **virtual-signal icons** are bespoke too (ci-kuu): a self-authored,
  deterministic set (`scripts/gen-signal-art.py`, own work) drawn as one family
  with the Cindra art -- a shared dark steel signal plate with a coloured glyph,
  warm-sun for the generic surface readings and ember/flare for the forecast
  block. Regenerate byte-for-byte with `scripts/render-signal-art.sh`.
* Never mutates another planet: it only adds its own entity and reads surface
  state. Setting a constant combinator's own output affects nothing but that
  building's wires.
