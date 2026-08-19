# Cindra

A Factorio 2.1 / Space Age mod adding **Cindra**, a tidally-locked planet
orbiting perilously close to its star. One hemisphere is a molten dayside, the
other a frozen nightside, and the factory lives only in the narrow temperate
**ribbon** at the terminator. The planet has no oil and no biology; it runs on
**rock, ice, metal, and starlight**.

> *The star gives too much, and survival is routing that surplus between fire and
> ice.*

Its identity is a single tension expressed through every system — **hot vs
cold** — and the player's core skill is **conducting the flare**: catching a
periodic ~100× solar power surge and routing it into productive sinks, storage,
or safe waste before it burns your own solar farm down.

> **Status: foundation.** The planet is reachable, landable, and its ribbon
> temperature axis is implemented and tested. The rest of the systems (lava,
> aluminium, flares, storage, mass driver, science) are the backlog — see
> [`DESIGN.md`](DESIGN.md) and [`TODO.md`](TODO.md).

## Repo layout

- `mods/cindra/` — the main mod.
- `mods/cindra-start/` — sibling: integrates with
  [`any-planet-start`](https://mods.factorio.com/mod/any-planet-start) (an
  optional dependency) to let you start a new game directly on Cindra when it is
  installed.
- `mods/cindra-dev-default/` — dev-only: defaults the planet-picker to Cindra.
- `flake.nix` — dev/test shell: builds `factorio-test` from its upstream source
  (no longer vendored) and provides the art + test toolchain. `any-planet-start`
  is NOT provided here; install it from the mod portal to use the Cindra start
  chain.
- `scripts/` — project tooling.
- `factorio/` — local Factorio 2.1.9 install (gitignored; optional — a shared
  install in any parent directory is found automatically, or point
  `FACTORIO_PATH` / `FACTORIO_DIR` at one, see [`SETUP.md`](SETUP.md)).

## Quick start

After a fresh clone, provide the gitignored pieces (Factorio install, node deps)
— see [`SETUP.md`](SETUP.md). Then:

```sh
./play.sh                 # launch the game
```

## Running the test suite

The toolchain (including `factorio-test`, built from upstream) lives in the
flake dev shell. Enter it, install the CLI once, then run `cindra-test`:

```sh
nix develop
npm install          # one-time: fetch factorio-test-cli
cindra-test          # full integration suite
```

`cindra-test` symlinks the flake-built factorio-test into the data dir and runs
the CLI with the DLC set the suite needs — `recycler` is a required built-in DLC
in Factorio 2.1 (`quality` / `space-age` depend on it). It resolves the Factorio
binary from `FACTORIO_PATH` / `FACTORIO_DIR` / `./factorio` / a
`factorio-patched` or `factorio` install in any parent directory, and exits
non-zero if none resolves — an in-engine run is never silently skipped (see
[`SETUP.md`](SETUP.md)). For the same reason a run that executes **zero** tests
exits non-zero: a filter that stops matching otherwise prints
`525 skipped, 0 passed` and exits 0, which reads as a gate that passed without
running anything. Plain-Lua unit tests run without Factorio:

```sh
npm run test:unit                    # all unit-tests/test_*.lua
# or a single one:
cd mods/cindra && lua unit-tests/test_ribbon.lua
```

### The horizontal (E-W) ribbon run

The ribbon orientation (`cindra-ribbon-orientation`) is a **startup** setting
baked into the tile probability expressions and the resource band masks at the
data stage, so one engine run generates exactly one orientation — nothing at
runtime can rotate a world that already generated vertical. The E-W ribbon
therefore gets its own run:

```sh
npm run test:integration:horizontal   # == CINDRA_ORIENTATION=horizontal cindra-test
```

`CINDRA_ORIENTATION=horizontal` seeds `mods/cindra-dev-horizontal` (a dev-only
mod that flips the setting's *default*) into the data dir and enables it; the
default run removes that seed again. That run swaps the suite for the two that
describe a rotated world — `test_worldgen_horizontal` (fire at the top, ice at
the bottom, resources and lethal ground banded on Y, all in raw coordinates) and
the orientation-agnostic `test_orientation`. `npm test` runs both orientations.

### Companion mods (Any-Planet-Start chain)

`any-planet-start` (APS) is an **optional** dependency (`? any-planet-start`), so
the companion mods (`cindra-start` + `cindra-dev-default`) must load clean both
with and without it — and when APS *is* installed, the player still has to
**choose** Cindra in its planet picker. Installed and chosen are different worlds
(`ci-e9sj`: keying on the mod alone made 14 tests assert a Cindra start that was
not happening), so there are **three** configs and control.lua registers exactly
one suite per config, on
`settings.startup["aps-planet"].value == "cindra"` — the same predicate
`cindra-start` gates its own runtime grants on:

| Config | Suite | What it proves |
| --- | --- | --- |
| no APS | `test_aps_absent` | the companion mods load clean and register nothing |
| APS + Cindra chosen | `test_aps_start` + `_foundry` + `_kit` + `_bootstrap` | the start chain: registration, pre-research, kit, end-to-end bootstrap |
| APS + another start | `test_aps_offered` | Cindra is offered but nothing fired: normal discovery gate, no free research, no free kit |

`cindra-test [MOD ...] [-- CLI-ARG ...]`: bare words are extra mods to enable
alongside the base DLC set, and anything after `--` goes to the CLI verbatim
(flags, or a Lua filter pattern). So each config runs by seeding the companion
mods into the data dir and naming them on the `cindra-test` line. Run these from
inside `nix develop`.

**Without APS — `test_aps_absent` (no external mod needed).** Proves the
companion mods load clean and register nothing when APS is absent (the guarded
APS calls are skipped, no data-stage error). Symlink only the in-repo companion
mods:

```sh
mkdir -p factorio-test-data-dir/mods
for m in cindra-start cindra-dev-default; do
  ln -sfn "../../mods/$m" "factorio-test-data-dir/mods/$m"
done

cindra-test cindra-start cindra-dev-default
```

**With APS — `test_aps_start`.** Proves the companion mods wire Cindra into APS
end-to-end (add_choice / set_default_choice / add_planet) and the full set loads
clean headless with the picker defaulting to Cindra. APS is not vendored:
install it from the [mod portal](https://mods.factorio.com/mod/any-planet-start)
and point `APS_PATH` at that checkout so it can be linked into the data dir:

```sh
: "${APS_PATH:?set APS_PATH to a local any-planet-start checkout}"
mkdir -p factorio-test-data-dir/mods
ln -sfn "$(realpath "$APS_PATH")" factorio-test-data-dir/mods/any-planet-start
for m in cindra-start cindra-dev-default; do
  ln -sfn "../../mods/$m" "factorio-test-data-dir/mods/$m"
done
# fresh mod-settings so the picker regenerates its default (cindra-dev-default -> "cindra")
rm -f factorio-test-data-dir/mods/mod-settings.dat factorio-test-data-dir/mod-settings.dat

cindra-test any-planet-start cindra-start cindra-dev-default
```

That mod set rewrites Cindra's discovery tech (APS treats it as the start
planet), so it is deliberately kept out of the default run. It is nonetheless a
FULLY GREEN run: the whole suite must pass under it, exactly as under the default
mod set. Cindra's gating tests state the discovery gate per world rather than
asserting the default tech tree unconditionally (`tests/helpers.lua`
`assert_behind_cindra_discovery` + `tests/test_discovery_gate.lua`, ci-r7w4) --
before that, three of them were red on clean main here, which made a target-side
failure look like the branch's own. The actual in-game start (cargo-pod drop,
playable opening) is a [`PLAYTEST.md`](PLAYTEST.md) item.

**APS installed, another start chosen — `test_aps_offered`.** The way a player
who is not specifically after a Cindra start installs this chain: APS plus
`cindra-start`, picker left alone. APS's `aps-planet` then keeps its own default
(`none`), its `data-final-fixes` returns early, and nothing about the game
changes — Cindra keeps its Vulcanus discovery gate and `cindra-start`'s runtime
grants stay off. Drop `cindra-dev-default` from the set (it is the mod that
forces the picker to Cindra) and reuse the APS link above:

```sh
: "${APS_PATH:?set APS_PATH to a local any-planet-start checkout}"
mkdir -p factorio-test-data-dir/mods
ln -sfn "$(realpath "$APS_PATH")" factorio-test-data-dir/mods/any-planet-start
ln -sfn "../../mods/cindra-start" factorio-test-data-dir/mods/cindra-start
# fresh mod-settings so the picker regenerates APS's own default ("none")
rm -f factorio-test-data-dir/mods/mod-settings.dat factorio-test-data-dir/mod-settings.dat

cindra-test any-planet-start cindra-start
```

Unlike the chosen-start config, this one keeps Cindra's normal tech tree, so the
whole default suite is valid here and the run must be fully green.

### PlanetsLib co-load

Cindra declares PlanetsLib as an **optional** dependency — `"? PlanetsLib"`, load
order only, so it forces nothing on the player (see
[`docs/planetslib-evaluation.md`](docs/planetslib-evaluation.md); a hard dependency
would drag the library's vanilla-prototype rewrites into every Cindra game). Plenty
of players do install it alongside planet mods, and its `data-final-fixes` reaches
into every planet in `data.raw.planet`. `test_planetslib_coload` proves the co-load
is harmless — the game loads and Cindra does not move on the star map. It registers
only when PlanetsLib is actually loaded, so the default run runs its mirror,
`test_planetslib_absent` (Cindra plays without the library, and none of its global
mutations are present); `test_planetslib_compat` guards the interop edges from our
own side in both configs.

It is also the only place the **delegated** half of
`scripts/surface-conditions.lua` runs in an engine. Cindra edits surface
conditions through that shim, which hands the work to PlanetsLib's helpers when
the library is present and runs its own implementation otherwise. The co-load
suite reads the backend the data stage recorded (so it knows the delegation
really happened) and pins that both paths produce the same gates. Off-engine,
`npm run test:unit` drives both branches with a stub library.

PlanetsLib is not vendored. Download it from the
[mod portal](https://mods.factorio.com/mod/PlanetsLib) and drop the zip (or an
unpacked copy) into the data dir:

```sh
mkdir -p factorio-test-data-dir/mods
cp -f ~/Downloads/PlanetsLib_*.zip factorio-test-data-dir/mods/

cindra-test PlanetsLib
```

Mind the engine version: PlanetsLib ≥ 1.23.5 requires `base >= 2.1.13`, and
Factorio refuses to enable a mod whose dependency bound the install does not
meet. On an older install, use the newest release that still declares
`base >= 2.1.7` (1.23.4 was verified in `ci-gg3x`).

See [`AGENTS.md`](AGENTS.md) for development conventions and the test-first
workflow.

## Art credits

* The **lava-manufacturer** (stone->lava melter) building + item art is the
  user-supplied **glass-furnace** set by Hurricane (CC-BY; see
  `mods/cindra/graphics/entity/lava-manufacturer/ATTRIBUTION.md` and
  `mods/cindra/CREDITS.md`). It ships as an animated furnace body, a ground
  shadow, and an always-on emissive molten glow that fits a lava melter.

## Concept overview

Cindra is a 1D **ribbon**: long east–west along the terminator, shallow
perpendicular (the sunward–nightward temperature axis). Push sunward and heat
kills you; push nightward and cold does. The factory lives in the seam.
Manufactured **lava** (`1 stone + ruinous power → 10 lava`) is the central
intermediate; the signature product is **aluminium**, electrolysed from rock+ice
feedstock with brute electricity (`stone + calcite → alumina → ruinous power →
aluminium`) — the planet's biggest power sink and its primary export. Goods leave
by a power-hungry **mass driver**, not a rocket, so the planet's oil/coal
chemistry footprint is **zero**. See [`DESIGN.md`](DESIGN.md) for the complete spec.
