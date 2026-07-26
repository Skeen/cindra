# Cindra — The Ribbon World

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
> cryo-quench, flares, storage, mass driver, science) are the backlog — see
> [`DESIGN.md`](DESIGN.md) and [`TODO.md`](TODO.md).

## Repo layout

- `mods/cindra/` — the main mod.
- `mods/cindra-start/` — sibling: integrates with
  [`any-planet-start`](https://mods.factorio.com/mod/any-planet-start) to let you
  start a new game directly on Cindra.
- `mods/cindra-dev-default/` — dev-only: defaults the planet-picker to Cindra.
- `vendor/` — bundled dependencies (`any-planet-start`, `factorio-test`).
- `scripts/` — project tooling.
- `factorio/` — local Factorio 2.1.9 install (gitignored).

## Quick start

After a fresh clone, provide the gitignored pieces (Factorio install, node deps)
— see [`SETUP.md`](SETUP.md). Then:

```sh
./play.sh                 # launch the game
```

## Running the test suite

```sh
nix shell nixpkgs#nodejs -c ./node_modules/.bin/factorio-test run \
  --factorio-path ./factorio/bin/x64/factorio \
  --data-directory ./factorio-test-data-dir \
  --mod-path ./mods/cindra \
  --mods space-age quality elevated-rails recycler
```

`recycler` became a required built-in DLC in Factorio 2.1 (`quality` /
`space-age` depend on it), so it must be in the `--mods` list. Plain-Lua unit
tests run without Factorio:

```sh
cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_ribbon.lua
```

See [`AGENTS.md`](AGENTS.md) for development conventions and the test-first
workflow.

## Concept overview

Cindra is a 1D **ribbon**: long east–west along the terminator, shallow
perpendicular (the sunward–nightward temperature axis). Push sunward and heat
kills you; push nightward and cold does. The factory lives in the seam.
Manufactured **lava** (`1 stone + ruinous power → 5 lava`) is the central
intermediate; the signature product is a **cryo-hardened alloy** forged in a
two-temperature quench (hot molten input + cold cryo-coolant in one craft) that
is impossible anywhere else. Goods leave by a power-hungry **mass driver**, not a
rocket, so the planet's oil/coal chemistry footprint is **zero**. See
[`DESIGN.md`](DESIGN.md) for the complete spec.
