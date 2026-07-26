# Cindra — backlog

Work follows the **§15 implementation order** from the design brief. Each item is
tracked by a bead (prefix `ci-`); check `bd show <id>` for detail and `bd ready`
for what's unblocked. Deliver each item as tested sub-commits, land through the
merge queue.

> **Test-first (non-negotiable):** every gameplay change needs an integration
> test (`mods/cindra/tests/test_*.lua`) and/or a plain-Lua unit test
> (`mods/cindra/unit-tests/`). See [`AGENTS.md`](AGENTS.md).

## Done

- [x] **§15-1 — Planet + surface + ribbon temperature axis.** `ci-m1n` (root).
  - Planet prototype: reachable (gated after Vulcanus), discovery tech, clean
    Nauvis-based map gen (no vanilla ores/enemies/trees/rocks), canonical
    physical params. `prototypes/planet.lua`.
  - Ribbon temperature axis: pure `scripts/ribbon.lua` (temperature / zone /
    damage-per-second / hard-wall), the single source of truth for the hot–cold
    axis. Settings-tunable. Unit-tested + integration-tested.
  - Companion mods: `cindra-start` (Any-Planet-Start choice), `cindra-dev-default`
    (dev picker default). Full APS chain loads headless.
  - Scaffold: vendored deps, test harness, `play.sh`, docs.

## Backlog (§15 order)

- [ ] **§15-2 — Lethal edges.** `ci-318` — gradient ticking damage (heat sunward /
  cold nightward) consuming `ribbon.damage_per_second`; hard-wall backstop
  geometry at `wall_at`; Aquilo-style nightside building-heat requirement. This
  is where the axis value becomes *felt*.
- [ ] **§15-3 — Resources.** `ci-l72` — stone (ribbon, mineable), ice (nightside),
  scattered bootstrap rocks near the terminator (hand-gatherable, finite, NOT a
  patch), optional deep-nightside volatiles. *Blocks 4, 5.*
- [ ] **§15-4 — Ice processing.** `ci-rgv` — crusher building; `ice → water` and
  `ice → water + calcite` (asteroid-crushing model, player picks the ratio).
  *Needs 3.*
- [ ] **§15-5 — Lava + metal.** `ci-8mw` — `1 stone + [ruinous power] → 5 lava`
  (fluid); Vulcanus foundry integration (brought, not re-unlocked); stone
  loop-back kept slightly net-consuming. *Needs 3.*
- [ ] **§15-6 — Cryo-hardened alloy.** `ci-gd4` — two-temperature quench building
  (hot molten input + cold cryo-coolant input in one craft). The signature.
  *Needs 4 + 5.*
- [ ] **§15-7 — Solar + flare.** `ci-9k6` — high surface solar multiplier +
  dark-weighted daylight curve; telegraph / fast-ramp / plateau / fast-decay;
  regular cadence; ~100× peak. Replaces the placeholder baseline in
  `prototypes/planet.lua`. *Blocks 8.*
- [ ] **§15-8 — Panel damage.** `ci-9ay` — disposal-deficit rule, degrade-before-
  death, self-correcting (negative feedback), dissipator-as-fuse. *Needs 7.*
- [ ] **§15-9 — Storage.** `ci-tii` — capacitor (fast spike) + molten-salt battery
  (bulk plateau, heat-upkeep or it "freezes") + dedicated dissipator.
- [~] **§15-10 — Electric heater.** `ci-f5l` — capped heat (600°) / uncapped power
  draw; roles: nightside warmth, flare sink, water boil-off, safe dissipation;
  built from a native ingredient (import-gated / clumsy elsewhere).
  - Building landed: `prototypes/electric-heater.lua` (heating-tower clone →
    electric source, 600° heat cap), item + recipe + `cindra-electric-heating`
    tech (variant of the heating-tower tech). Tested: `tests/test_heater.lua`
    (heat cap, electric-not-burner, situational-not-strictly-better vs heating
    tower §12, gated recipe/tech, runtime placement on Cindra).
  - TODO(ci-gd4): swap the vanilla recipe ingredients for the native cryo-alloy
    once it lands, to make the "clumsy off-world" import gate real.
- [ ] **§15-11 — Mass driver.** `ci-r10` — launch = power (bursty, flare-timed) +
  platform-side catcher; optional native projectile shell (A) vs pure-electric
  pods (B). Removes launch chemistry entirely.
- [ ] **§15-12 — Cindra science pack + tech tree.** `ci-3or` — petrochemical-free
  recipe (native inputs only); the unlocks for items 3–11.
- [ ] **§15-13 — Bootstrap traversal check.** `ci-uex` — verify landing → first
  foundry is traversable: no chicken-and-egg, no soft-lock; bootstrap-rock output
  is a one-time/durable cost only. *Needs 5.*
- [ ] **§15-14 — Balance pass.** `ci-63d` — tune all `(tune)` values against the
  lava energy cost; verify exportable buildings are **situational-not-strictly-
  better** than vanilla (§12 guardrail).

## Deferred / cross-cutting

- **Custom art.** v1 reuses vanilla Vulcanus icons. Bespoke ribbon/terminator
  ground, star-map, and orbital-backdrop art is a later art pass — see
  [`PLAYTEST.md`](PLAYTEST.md).
- **Optional self-sufficiency mode (§11).** CO₂ + water + power → carbon →
  plastic/sulfur synthesis, as an optional flare-timed endgame flex. Ship
  zero-chemistry/import first; not required for v1.
- **Advanced cryo heat-sink loop (§8).** Circulating coolant that re-chills on the
  nightside, as an optional depth variant over the consumed-material default.
- **Flare-response circuit building (§12-8).** Power-grid sensor / priority-switch
  for first-class flare automation.
