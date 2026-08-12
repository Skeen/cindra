# Agent orientation — Cindra mod

Factorio 2.1 / Space Age mod adding **Cindra**, a tidally-locked "ribbon planet"
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

## 🚨 Definition of Done / pre-submit self-check

Before running `gt done` or submitting an MR, STOP and re-read the bead you were
assigned. Then self-check every mandatory item. Premature bead-close (shipping a
partial, or weakening a test to make a skipped requirement pass) is the single
most common cause of a rejected MR.

- **Re-read the whole bead and enumerate its mandatory items** — every `TEST:`,
  `DO:`, enumerated fix, and acceptance criterion. Confirm each one is actually
  done. A bead with 8 enumerated fixes needs all 8.
- **Do NOT close or submit if ANY mandatory item is unmet.** Partial work is not
  done. The only exception is an explicit deferral agreed with the mayor.
- **NEVER delete, weaken, or rewrite a mandatory guard TEST** to make a skipped
  requirement pass. If two requirements seem to conflict, mail the mayor — do
  not unilaterally drop one.
- **If a mandatory item is genuinely blocked or infeasible**, mail the mayor and
  keep the bead `in_progress`. Do not silently ship a partial.
- **Nothing ships without its tests.** Every change needs a test (see
  Conventions). The fix for a bug MUST add a test that fails on main and passes
  on the fix.
- **Ship at least one PLAYER-OBSERVABLE INVARIANT test** for any new or changed
  mechanic (see the section below). A suite of prototype-field assertions does
  not satisfy this for anything with runtime behavior.

## 🚨 TESTS ASSERT PLAYER-OBSERVABLE BEHAVIOR, NOT THE IMPLEMENTATION

**Players only ever see behavior. That is all a test may assert.**

A test that restates the code cannot catch a wrong model: it passes precisely
because the code says what the code says. Two green suites shipped exactly that
way -- a power diode that drew 10 MW forever AND generated 10 MW from nothing
(ci-76if, `energy_usage == X` asserted), and a tile-damage regression (ci-ma18,
the damage CONSTANT asserted instead of "standing on concrete shields you").

**The test:** if this test could still pass while the player-visible behavior is
broken, it is the WRONG test. Rewrite it against the observable outcome.

Observable invariants look like:

- **conservation** -- no entity creates energy/items from nothing; what comes out
  is at most what went in plus legitimate generation
  (`tests/test_power_conservation.lua` is the worked example, and the mod-wide
  policy suite for power)
- **tile-based damage** -- concrete shields, lava/cracks burn
- **on/off actually gates** -- a disabled thing transfers nothing AND draws nothing
- **demand-driven** -- an idle consumer causes ~zero upstream draw
- **the right thing renders** -- correct model/overlay, selection box matches it

Prototype-field assertions (`energy_usage == X`, `box == Y`) are fine as a
supplement -- they pin intent and catch typos -- but they never stand alone for
anything with runtime behavior. Prefer a runtime/behavioral test; the runtime
API exposes enough world state to measure nearly anything (see the next section).

**Coverage guards beat good intentions.** Where a class of entity shares an
invariant, enumerate the class LIVE from `prototypes.*` and fail when a member
has no case (`test_power_conservation.lua` does this for every Cindra power
entity). A new entity then cannot ship without its invariant test.

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
  cindra-start/          sibling: any-planet-start integration (Cindra as a start; APS optional)
  cindra-dev-default/    sibling: dev-only planet-picker default

flake.nix                dev/test shell: factorio-test (built from upstream, NOT
                         vendored) + art/test toolchain. any-planet-start is an
                         optional external dep, NOT provided by the flake.
scripts/                 tooling (patchelf-factorio.sh, render-*.sh)
factorio/                Factorio install (gitignored — see SETUP.md)
```

## Run tests

The toolchain lives in the flake dev shell — `factorio-test` (built from
upstream), node, lua, and the art tools. Enter it, then use `cindra-test`
(seeds the flake-built factorio-test into the data dir and invokes the CLI):

```sh
nix develop
npm install          # one-time: fetch factorio-test-cli
cindra-test          # integration suite
```

`cindra-test` passes the DLC set the suite needs — `recycler` is a required
built-in DLC in 2.1 (`quality` / `space-age` depend on it). It resolves the
Factorio binary from `FACTORIO_PATH` / `FACTORIO_DIR` / `./factorio`, so one
shared install serves every clone (see SETUP.md). The "Could not download mod:
recycler" line is a harmless warning — recycler loads from the Factorio
install's bundled DLC data. Extra args are forwarded to the CLI (e.g.
`cindra-test cindra-start cindra-dev-default` for the companion suite).

Plain-Lua unit tests (pure logic) run without Factorio:

```sh
npm run test:unit                    # all unit-tests/test_*.lua (in the dev shell)
# or a single one:
cd mods/cindra && lua unit-tests/test_ribbon.lua
```

Python pixel tests (the from-space planet art, guarded off-game with numpy +
pillow) live alongside the Lua ones as `unit-tests/test_*.py` and run under the
flake's `pythonEnv`:

```sh
npm run test:unit:py                  # all unit-tests/test_*.py (in the dev shell)
# or a single one:
python3 mods/cindra/unit-tests/test_planet_maps.py
```

Both `test:unit` and `test:unit:py` are part of the top-level `npm test` target.

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

- **`any-planet-start`** (optional external dep, NOT vendored) — startable-planet
  picker. `mods/cindra-start` declares it as `? any-planet-start` and registers
  Cindra as a game-start option ONLY when APS is installed (guarded on
  `mods["any-planet-start"]`); without it the companion mods load clean and
  register nothing. Install it from the mod portal to use the Cindra start chain.
- **`factorio-test`** (3.1.1, dev/test-only) — the integration-test framework.
  Built from its upstream GitHub source by `flake.nix` (a flake input, NOT
  vendored) and seeded into the runner by `cindra-test`. It is deliberately NOT
  a dependency of any shipped mod (`info.json`) and is not in the release
  archive; the mods load/play fine without it (`control.lua` boots the suite
  only when `script.active_mods["factorio-test"]`).

## Conventions

- **🚨 EVERY CHANGE NEEDS A TEST.** Prototype field, recipe, script, world-gen
  tweak — all of it. If a player finds a bug, the fix MUST add a test that fails
  on main and passes on the fix. The test asserts what the PLAYER OBSERVES, never
  a restatement of the implementation (see the player-observable section above).
- **Don't `git add -A`/`.`.** Always name specific files.
- **Commits:** short subject (<70 chars), body explains *why*.
- **Don't bypass hooks** (`--no-verify`, `--amend` unless asked).
- **Confirm before destructive ops** (force push, reset --hard, dropping
  branches).
- **Run tests after any prototype change.** Many invariants are encoded as tests.
- **Unknown CLI tools:** run via `nix shell nixpkgs#<package> -c <cmd>`.
- **Avoid em-dashes in comments and commit messages.**
