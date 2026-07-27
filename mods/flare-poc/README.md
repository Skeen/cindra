# Cindra Flare PoC

A **standalone** proof-of-concept for Cindra's signature power mechanic:
telegraphed **solar flares** and the **disposal-deficit panel-damage** rule, with
a two-tier storage + dissipator sink web. It lives in its own mod dir
(`mods/flare-poc/`), runs in parallel with anything else, shares no files, and
touches no other planet: every runtime handler is gated on
`surface.name == "flare-poc"`.

Spec: `planet_design.md` §10 (power / solar / flares / panel-damage), §12 items
5-6 (storage), §16 (tuning rows). This module exists so the mechanics track can
later integrate a **proven** flare module rather than inventing one.

## What it proves (all green in `factorio-test`)

| Claim (definition of done) | Test |
|---|---|
| A flare cycle occurs on schedule with a telegraph and a ~100× peak vs baseline | `tests/test_flare_cycle.lua` |
| Insufficient disposal → panels degrade, then die if sustained; damage ∝ deficit; edge-biased; self-correcting (no death spiral) | `tests/test_panel_damage.lua` |
| Sufficient disposal (dissipator + capacitor + battery) → zero panel loss; dissipator is the sacrificial fuse (absorbed first, never panels-first) | `tests/test_disposal.lua` |
| Storage charges on the flare and discharges after; the fast capacitor fills the spike, the bulk battery soaks the plateau | `tests/test_storage.lua` |
| The ~100× peak outruns any buildable **capture** rate at every scale → there is always overflow to dump | `tests/test_catchability.lua` |

## The model

**Flare = engine daylight curve × fixed high surface solar multiplier** (no
overdrive hack, per the locked §10 model). `surface.solar_power_multiplier` is a
fixed `100`; the flare swing comes from driving `surface.daytime` along the
telegraph → fast ramp → plateau → fast decay curve. The engine's own solar factor
`sf(daytime)` ramps `1 → 0` linearly across `[dusk, evening]`, so:

- **Baseline / "dim" trough**: a near-night daytime where `sf ≈ 0.01`. Scaled by
  the ×100 multiplier this delivers **≈ one Nauvis-full-day** of power — the
  never-zero night floor that runs the factory between flares.
- **Flare peak**: full day (`sf = 1.0`) → **≈ 100× baseline**.

Because we drive daytime with a fixed multiplier, a real panel's actual output is
exactly `PANEL_NOMINAL_W × intensity`, where `intensity` runs `1 → 100`
(Nauvis-full-day equivalents). `scripts/flare.lua` is the canonical, pure schedule
(`flare.state(tick)`); `scripts/flare.apply` embodies it on a real surface.

**Panel damage = disposal-deficit rule.** Each sweep, per electric network:
`deficit = potential − capture`, where `capture = consumption + dissipators +
storage-with-room`. If `deficit > 0`, the surplus with nowhere to go damages
panels, HP budget ∝ deficit, spent **sunward-first** (edge-biased). A mild deficit
only dents the sunmost panels (degrade, recoverable); a sustained/severe deficit
consumes their health and **kills** them. Killing panels shrinks the array, which
lowers the potential and the flare peak — **negative feedback** that converges to
"alive panels ≤ disposal" instead of spiralling to zero. The **dissipator's**
capacity is counted in `capture` before any panel is touched, so it is the
reliable floor and the sacrificial fuse; recovery heals degraded panels once
disposal is added.

**Sinks.** Dissipator (infinite safe waste, rate-limited per building) +
two-tier storage: capacitor (fast, small — catches the spike) and molten-salt
battery (bulk, slow — soaks the plateau, with a small heat-upkeep self-discharge
when idle-cold). Capture (recoverable storage) can never match the peak flow, so
overflow to dump always remains.

## Tuning numbers (all PoC starting points, §16)

| Value | This PoC | Notes |
|---|---|---|
| Surface solar multiplier | `100` (×) | Fixed; the flare swing is daytime, not this. |
| Panel nominal output | `100 kW` | Per panel at one Nauvis-full-day. |
| Baseline intensity | `1×` (≈ Nauvis full day) | Non-zero night floor; runs the factory. |
| Flare peak intensity | `100×` baseline | = full-day ÷ dim-floor at the ×100 multiplier. |
| Flare cadence (period) | `1320 ticks` (22 s) | Compressed for tests; scale up for play. |
| ↳ calm / warning / ramp / plateau / decay | `600 / 180 / 120 / 300 / 120` ticks | Telegraph then fast-up / plateau / fast-down. |
| Panel max health | `200` | Condition/degradation gauge. |
| Damage budget | `4 HP / MW of deficit / sweep` | Scales with deficit, never panel count. |
| Recovery | `6 HP / safe sweep` | Degradation is reversible. |
| Damage sweep cadence | every `20 ticks` | Distinct N from the flare tick (`21`). |
| Dissipator draw | `20 MW` / building | Infinite safe waste, rate-limited. |
| Capacitor | `5 MJ` buffer, `5 MW` flow | Fast, small: catches the spike. |
| Molten-salt battery | `200 MJ` buffer, `2 MW` flow | Bulk, slow: soaks the plateau. |
| Battery heat upkeep | `0.05 % of capacity / driver tick` | Idle self-discharge; a mild sink. |

Real-play cadence: multiply the flare schedule ticks by ~10-30 (a flare every few
minutes) once the sky-telegraph visuals exist. The magnitudes (×100, panel/sink
sizes) should be validated against the real lava recipe's energy cost (§10:
"set the surface multiplier by working backwards from the lava recipe").

## Running the tests

The Factorio install and `node_modules` are gitignored (see the repo-root
`SETUP.md`); `factorio-test` is built by the repo `flake.nix` and exposed in the
dev shell as `$FACTORIO_TEST_MOD`. Inside `nix develop`, seed it and point the
runner's `--mod-path` at this mod:

```sh
mkdir -p factorio-test-data-dir/mods
ver=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$FACTORIO_TEST_MOD/info.json" | head -1)
ln -sfn "$FACTORIO_TEST_MOD" "factorio-test-data-dir/mods/factorio-test_$ver"

./node_modules/.bin/factorio-test run \
  --factorio-path "${FACTORIO_PATH:-./factorio/bin/x64/factorio}" \
  --data-directory ./factorio-test-data-dir \
  --mod-path <path>/mods/flare-poc \
  --mods space-age quality elevated-rails recycler
```

All 18 tests should pass.

## PoC scope / simplifications

- The flare intensity and the disposal-deficit accounting are **scripted** (the
  engine cannot damage panels from over-production on its own); the flare's power
  swing and the storage charge/discharge are **real engine** behaviour, driven by
  the daylight cycle and captured by real accumulators.
- Entities are created directly by the tests (no items/recipes/tech-gating yet)
  and have placeholder graphics — this proves the mechanic, not the art. Visual
  telegraph (sky brightening, alarm, countdown UI) and real sprites belong to the
  integration pass.
- Consumption is modelled as a per-grid scalar; a full build would read live
  consumers. `boil-off` (§10) is intentionally left out of this PoC (a follow-up).
