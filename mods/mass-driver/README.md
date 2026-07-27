# Mass Driver — electric launch-to-orbit PoC

A **standalone, self-contained** Factorio: Space Age mod that proves the
mass-driver concept from Cindra's `planet_design.md` §11: a building that flings
cargo to orbit using **essentially only electricity** (plus an optional
native-metal projectile shell), caught by a platform-side catcher. **No rocket
fuel, no chemistry.**

It lives in its own mod dir (`mods/mass-driver/`) so it develops fully in
parallel with the Cindra planet mod (`mods/cindra/`) — no shared files. Once
proven here, the mechanic folds into Cindra.

## Why a mass driver

On a normal planet the recurring chemistry burden comes from the **rocket**
(rocket fuel + LDS + processing units per launch). Replacing the rocket with an
electric mass driver removes all launch-driven chemistry. What launching costs
instead is **power** — bursty power: charge a buffer, then fire. On Cindra this
rhymes with the solar-flare cadence; this PoC just proves the
`charge → fire → deliver` loop.

## How the launch loop works

The launch building is a **composite of two entities** — no single vanilla
entity type has both an item inventory *and* a script-readable, chargeable
electric buffer, so we pair them:

| Prototype | Type | Role |
|---|---|---|
| `mass-driver` | `container` | Visible building. Load it (belt / inserter / hand) with **cargo** + **projectile shells**. |
| `mass-driver-charger` | `accumulator` (hidden) | Spawned by the runtime on the driver's tile (empty collision mask, so it overlaps). Charges the per-shot energy from the grid. `output_flow_limit = 0` → never feeds the grid back; energy only leaves as a shot. |
| `mass-driver-catcher` | `container` | One-time platform-side structure, built in orbit. Receives the payload. |
| `mass-driver-shell` | item | Consumable projectile shell, forged from native metal. |

Each tick-check (`scripts/launch.lua`), a driver **fires** when **all** hold:

1. its charger buffer is full (`>= 99%` of capacity),
2. it holds at least one `mass-driver-shell`,
3. it holds at least one cargo item,
4. a `mass-driver-catcher` of the same force exists (the destination).

On fire it spends the **whole** electric buffer, consumes **one** shell, and
moves up to `SHOT_CAPACITY` cargo items **across surfaces** into the catcher.
Then it must recharge before the next shot — naturally **bursty**. With no
catcher or no shell, nothing is consumed (payload preserved).

### Payload container decision

- **Option A (implemented, preferred):** each shot spends a **projectile shell
  made of native metal** (`mass-driver-shell`, from `steel-plate`, standing in
  for Cindra's cryo-hardened alloy). Puts the recurring launch cost on **local
  metallurgy**, off chemistry.
- **Option B (not implemented):** no consumable projectile — cargo pods caught
  and returned, launch cost = pure electricity + minor upkeep. To switch, set
  `SHELL_PER_SHOT = 0` in `scripts/launch.lua` and drop the shell recipe.

## Tuning (all PoC starting points — `(tune)`)

| Knob | Value | Where | Notes |
|---|---|---|---|
| Per-shot energy | **500 MJ** | charger `buffer_capacity` | Whole buffer spent per shot — a real power decision. |
| Charge rate | **10 MW** | charger `input_flow_limit` | ~50 s per shot from a strong grid → bursty. |
| Cargo per shot | **100 items** | `SHOT_CAPACITY` | Delivered to the catcher per fire. |
| Shell per shot | **1** | `SHELL_PER_SHOT` | Native-metal projectile (option A). |
| Shell recipe | **5 × steel-plate → 1 shell** | `prototypes/mass-driver.lua` | Pure native metal. No plastic/acid/fuel. |
| Fire-check cadence | **every 20 ticks** | `FIRE_INTERVAL` | |

Launch cost = **500 MJ electricity + 5 steel-plate per 100 items**, and
**zero** rocket fuel / plastic / sulfuric acid / lubricant. A test locks this.

## What's proven (in-engine, `factorio-test`)

`tests/test_mass_driver.lua` — 11 tests, all green:

- **prototype shape** — driver is a fuel-less container; charger is a hidden
  electric accumulator with a ≥100 MJ buffer; catcher + shell exist; no recipe
  in the loop uses rocketry/chemistry inputs.
- **charges from the grid** — a solar-fed grid fills the hidden charger.
- **FULL LOOP** — a charged, loaded driver delivers exactly `SHOT_CAPACITY`
  cargo **across surfaces** into an orbital catcher, spends one shell, drains
  its buffer to zero.
- **needs a shell / needs a catcher / needs a full charge** — each missing
  precondition blocks the launch with nothing consumed.
- **bursty** — two shots require two independent charge cycles.

## Running the tests

Needs a local Factorio install (2.1.9 Space Age) and node deps — both
gitignored; see the repo-root `SETUP.md`. The runner (`factorio-test`) is built
by the repo `flake.nix` and exposed in the dev shell as `$FACTORIO_TEST_MOD`.
The repo's `cindra-test` targets `mods/cindra`, so this standalone PoC uses the
CLI directly. From the repo root, inside `nix develop`:

```sh
# seed the flake-built factorio-test into the data dir
mkdir -p factorio-test-data-dir/mods
ver=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$FACTORIO_TEST_MOD/info.json" | head -1)
ln -sfn "$FACTORIO_TEST_MOD" "factorio-test-data-dir/mods/factorio-test_$ver"

./node_modules/.bin/factorio-test run \
  --factorio-path "${FACTORIO_PATH:-./factorio/bin/x64/factorio}" \
  --data-directory ./factorio-test-data-dir \
  --mod-path ./mods/mass-driver \
  --mods space-age quality elevated-rails recycler
```

`--mod-path ./mods/mass-driver` selects this mod (overriding the repo default,
which targets `mods/cindra`). `recycler` is a required built-in DLC in 2.1; the
runner may print `Could not download mod: recycler` and then proceed — that is
harmless (the DLC is resolved from the Factorio install). Expected:
`Tests: 11 passed (11 total)`.
```

## Layout

```
mods/mass-driver/
  info.json  data.lua  control.lua
  prototypes/mass-driver.lua   entities, items, recipes
  scripts/launch.lua           build tracking + charge→fire→deliver loop
  tests/test_mass_driver.lua   factorio-test integration suite
  locale/en/mass-driver.cfg
```
