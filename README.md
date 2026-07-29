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
- `factorio/` — local Factorio 2.1.9 install (gitignored; shareable via
  `FACTORIO_PATH` / `FACTORIO_DIR`, see [`SETUP.md`](SETUP.md)).

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
binary from `FACTORIO_PATH` / `FACTORIO_DIR` / `./factorio` (see
[`SETUP.md`](SETUP.md)). Plain-Lua unit tests run without Factorio:

```sh
npm run test:unit                    # all unit-tests/test_*.lua
# or a single one:
cd mods/cindra && lua unit-tests/test_ribbon.lua
```

### Companion mods (Any-Planet-Start chain)

`any-planet-start` (APS) is an **optional** dependency (`? any-planet-start`), so
the companion mods (`cindra-start` + `cindra-dev-default`) must load clean both
with and without it. There are two suites, and control.lua registers exactly one
based on whether APS is active:

`cindra-test` forwards any extra args straight to the CLI (appended after the
base DLC `--mods`), so both suites run by seeding the companion mods into the
data dir and passing them to `cindra-test`. Run these from inside `nix develop`.

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
planet), so it is deliberately kept out of the default run. The actual in-game
start (cargo-pod drop, playable opening) is a [`PLAYTEST.md`](PLAYTEST.md) item.

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
