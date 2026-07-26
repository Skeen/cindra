# Agent orientation — Cindra mod

Factorio 2.1 / Space Age mod adding **Cindra**, a tidally-locked "Ribbon World"
where survival is **routing the star's surplus between fire and ice**. A molten
dayside, a frozen nightside, and a narrow survivable ribbon at the terminator.
No oil, no biology: it runs on rock, ice, metal, and dangerous starlight. Mod
identifier: `cindra`. The main mod plus its two sibling mods live under `mods/`.

> **Status: foundation.** §15 item 1 (planet + surface + ribbon temperature axis)
> is implemented and tested. Build the planet out from `DESIGN.md` following the
> §15 order in `TODO.md`.

All paths relative to repo root.

## Read first

1. **`DESIGN.md`** — authoritative design (the implementation spec). If code
   contradicts it, the doc is right.
2. **`TODO.md`** — open work / backlog (the §15 order, each item a `ci-` bead).
3. **`PLAYTEST.md`** — items pending in-game visual/interactive confirmation.
   Anything that can't be fully validated by `factorio-test` (visuals, audio, UI
   feel, multiplayer) MUST get a checklist entry here.
4. **`git log --oneline -20`** — commit bodies explain why.

## 🚨 ALWAYS PREFER TESTS OVER PLAYTEST

Tests are FIRST CHOICE. PLAYTEST.md is the LAST RESORT when no test path exists.
The runtime API exposes most prototype fields and all world state, so the
reachable surface is large:

- **Prototype shape / fields** — read `prototypes.entity[name].<field>` (or
  `.item` / `.recipe` / `.technology`) and assert.
- **Recipe ingredients / costs / lock states** — walk `.ingredients` /
  `.products` / `.enabled`.
- **Tech prereqs / costs / unlock effects** — walk `.prerequisites`,
  `.research_unit_count`, `.effects`.
- **Runtime behaviour** — place entities, advance ticks via `async() +
  after_ticks()`, assert state.
- **Per-surface runtime state** — pollution, daytime, `solar_power_multiplier`,
  surface properties, `entity.electric_network_id` are queryable; assert
  before/after.
- **Pure logic** — anything with no `game.*` / `prototypes.*` access (e.g. the
  ribbon axis maths) goes in a plain-Lua unit test AND is reachable from an
  integration test.

Only after ruling out a test path is PLAYTEST.md the right home (sprite
appearance, day/night feel, audio, multiplayer desync, UI feel).

## Project layout

```
mods/
  cindra/                The main mod
    info.json / control.lua / data.lua / settings.lua
    prototypes/          planet.lua (surface, reachability, discovery tech)
    scripts/             ribbon.lua (pure temperature axis; more per §15)
    tests/               factorio-test integration tests
    unit-tests/          plain-Lua tests for pure logic
    graphics/ locale/    assets (v1 reuses vanilla art)
  cindra-start/          sibling: any-planet-start integration (Cindra as a start)
  cindra-dev-default/    sibling: dev-only planet-picker default

vendor/                  any-planet-start, factorio-test (self-contained)
scripts/                 tooling (patchelf-factorio.sh, render-*.sh)
factorio/                Factorio install (gitignored — see SETUP.md)
```

## Run tests

Integration suite (`recycler` is a required built-in DLC in 2.1 — `quality` /
`space-age` depend on it, so it must be in the `--mods` list):

```sh
nix shell nixpkgs#nodejs -c ./node_modules/.bin/factorio-test run \
  --factorio-path ./factorio/bin/x64/factorio \
  --data-directory ./factorio-test-data-dir \
  --mod-path ./mods/cindra \
  --mods space-age quality elevated-rails recycler
```

`node` isn't on PATH — wrap via `nix shell nixpkgs#nodejs -c`. The vendored
factorio-test must be visible to the runner as
`factorio-test-data-dir/mods/factorio-test_3.1.1 -> ../../vendor/factorio-test`
(pre-seeded so the runner doesn't try to download it). The "Could not download
mod: recycler" line is a harmless warning — recycler loads from the Factorio
install's bundled DLC data.

Plain-Lua unit tests (pure logic) run without Factorio:

```sh
cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_ribbon.lua
```

## Launch game for manual testing

```sh
./play.sh
```

## Load-bearing invariants

- **🚨 NEVER MUTATE GLOBAL STATE THAT AFFECTS OTHER PLANETS.** Hard rule. This
  mod adds Cindra; it MUST NOT change Nauvis/Vulcanus/Gleba/Fulgora/Aquilo
  gameplay. Traps: `map_settings.*` singletons, shared vanilla prototypes,
  `data.raw[...][ "vanilla-name" ]` mutations. Prefer per-surface runtime
  overrides, Cindra-exclusive entity clones, or handlers gated on `surface.name
  == "cindra"`. Deep-copy shared vanilla tables before overriding. If a fix needs
  a global change, first look for a per-surface API; if none, document the leak
  in a TODO and SKIP rather than ship it.
- **`script.on_nth_tick(N, fn)` is REPLACE-not-add.** One handler per N; give each
  periodic system a distinct N.
- **The ribbon axis has ONE source of truth:** `scripts/ribbon.lua`. Every system
  that needs "where am I on the hot–cold axis" reads it; don't re-derive the
  curve.

## Upstream dependencies & vanilla reuse

Cindra REUSES existing Space Age content where it can (extend, don't
re-implement): Vulcanus **foundries** + lava fluid (manufactured lava chain),
the space-platform **asteroid-crushing** model (relocated to ground ice
processing), **accumulators** (bulk storage baseline). New content is the
signature stuff: the cryo-quench, the flare/panel-damage power system, the
storage tier, the electric heater, the mass driver, the science pack.

- **`any-planet-start`** (vendored) — startable-planet picker. `mods/cindra-start`
  registers Cindra as a game-start option.
- **`factorio-test`** (vendored, 3.1.1) — the integration-test framework.

## Conventions

- **🚨 EVERY CHANGE NEEDS A TEST.** Prototype field, recipe, script, world-gen
  tweak — all of it. If a player finds a bug, the fix MUST add a test that fails
  on main and passes on the fix.
- **Don't `git add -A`/`.`.** Always name specific files.
- **Commits:** short subject (<70 chars), body explains *why*.
- **Don't bypass hooks** (`--no-verify`, `--amend` unless asked).
- **Confirm before destructive ops** (force push, reset --hard, dropping
  branches).
- **Run tests after any prototype change.** Many invariants are encoded as tests.
- **Unknown CLI tools:** run via `nix shell nixpkgs#<package> -c <cmd>`.
- **Avoid em-dashes in comments and commit messages.**
