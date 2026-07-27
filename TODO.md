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
    (dev picker default). APS is an OPTIONAL dependency (`ci-gfp`): the companion
    mods load clean with AND without it. Full APS chain loads headless when APS
    is installed.
  - Scaffold: flake dev shell (factorio-test built from upstream, `ci-9u3`),
    test harness, `play.sh`, docs.

- [x] **§15-2 — Lethal edges.** `ci-318` (worldgen track `ci-9nj`).
  - Gradient ticking damage: `scripts/edge-damage.lua` consumes
    `ribbon.damage_per_second` and cooks (heat) / chills (cold) characters on the
    Cindra surface; custom `cindra-heat` / `cindra-cold` damage types
    (`prototypes/damage-types.lua`).
  - Hard-wall backstop: `scripts/worldgen.lua` voids tiles at/beyond `wall_at`
    (`out-of-map`), making the map a finite-width ribbon.
  - Nightside building-heat: `scripts/building-heat.lua` ticks cold damage on
    unheated machines past the cold threshold; a nearby heat source spares them.
  - Tested: `tests/test_edge_damage.lua`, `tests/test_worldgen.lua`,
    `tests/test_building_heat.lua`.
- [x] **§15-3 — Resources.** `ci-l72` (worldgen track `ci-9nj`).
  - `prototypes/resources.lua` + `scripts/resource-field.lua` (pure band geometry)
    + runtime placement in `scripts/worldgen.lua`: stone (ribbon), ice
    (nightside), scattered finite bootstrap rocks near the terminator, deep
    volatiles; best nodes at the lethal margins (edge-pushing).
  - Tested: `tests/test_worldgen.lua`, `unit-tests/test_resource_field.lua`.
  - *Unblocks 4, 5* — the mechanics track consumes `stone` / `ice` /
    `cindra-volatiles` (recipes are theirs to add).
- [x] **§15-5 — Lava + metal.** `ci-8mw` (mechanics track).
  - `prototypes/lava.lua`: recipe `cindra-lava` — `1 stone + [ruinous power] → 5
    lava` (fluid), metallurgy category so the brought-not-re-unlocked Vulcanus
    foundry crafts it. Power is the only cost lever (single-stone input,
    productivity off, cost carried by `energy_required`); gated behind a
    dedicated `cindra-lava` tech (prereqs foundry + `planet-discovery-cindra`).
  - Foundry integration is *brought, not re-unlocked*: the Vulcanus
    `molten-iron/copper-from-lava` recipes are left untouched and simply consume
    this lava fluid. Their stone byproduct (10/15) is the stone loop-back.
  - Tested: `tests/test_lava.lua` (ratio, power lever, gating, foundry-category
    fit, unmodified molten recipes + byproduct, never-mutate guard, live foundry
    accepts the recipe on Cindra).
  - **Balance note (§15-14):** the "net slightly consuming" target is not
    reachable with the fixed 1:5 ratio + the shared (uneditable) Vulcanus
    byproduct; reconciling it (batch scaling / a Cindra casting tier) is the
    balance pass's, flagged in `lava.lua`.

## Backlog (§15 order)
- [x] **§15-4 — Ice processing.** `ci-rgv`, `ci-4or` —
  `prototypes/ice-processing.lua`: a **two-stage** chain, faithful to the
  item-only space crusher. Stage 1 `cindra-ice-crusher` (clone of the space
  crusher; drops the zero-gravity gate + space-platform heating draw, SOLID →
  SOLID, no fluid) runs the two crush recipes the player picks between —
  `cindra-ice-crushing` (ice → crushed-ice) and `cindra-ice-crushing-calcite`
  (ice → crushed-ice + calcite, trading shards for calcite). Stage 2
  `cindra-ice-melter` (chemical-plant clone) runs `cindra-ice-melting`
  (crushed-ice → water) — the only step that makes fluid (ci-4or). Private
  `cindra-ice-crushing` / `cindra-ice-melting` categories keep the recipes off
  vanilla space crushers + chemical plants (and vice versa); the
  `cindra-ice-processing` tech unlocks both machines + all three recipes. Tested:
  `tests/test_ice_processing.lua` (category isolation, crusher has NO fluid output,
  melter water output box, ground-placeability, recipe shapes/ratio, no vanilla
  leak, tech gating, and an end-to-end powered crush ice → shards → water on Cindra).
- [x] **§15-6 — Cryo-hardened alloy. DROPPED (superseded by `ci-84s`).** The
  original signature was a two-temperature quench (`prototypes/cryo-alloy.lua`,
  `ci-gd4`): a `cindra-cryo-quench` building crafting `cindra-cryo-hardened-alloy`
  from a hot `lava` fluid + a cold `cindra-cryo-coolant` item in one recipe. The
  `ci-84s` PIVOT retired that whole two-temperature thesis: **aluminium** (ci-txh)
  is now the signature product + primary export, and the headline science is
  re-based onto it. Removed cleanly (no dangling refs): the quench building,
  cryo-coolant + cryo-hardened-alloy items/recipes, the `cindra-cryo-quenching`
  tech, the private `cindra-quenching` category, and `tests/test_cryo_alloy.lua`.
  The fire/ice terrain remains as a survival hazard + water source, not a craft.
  Guarded by `tests/test_pivot.lua` (no cryo prototype survives; science + export
  are aluminium-based). The `TODO(ci-gd4)` native-ingredient notes in
  `prototypes/electric-heater.lua` now point at aluminium (`TODO(ci-txh)`).
- [x] **§15-7 — Solar + flare.** `ci-9k6` — high surface solar multiplier +
  dark-weighted daylight curve; telegraph / fast-ramp / plateau / fast-decay;
  ~100× peak. Replaced the placeholder baseline in
  `prototypes/planet.lua` (`solar-power` = 10000, the ~100× surface multiplier;
  the flare swing is the frozen daylight curve, `scripts/flare.lua`). Integrated
  from the proven flare-poc (ci-zg3). Tested: `tests/test_flare.lua` +
  `unit-tests/test_flare.lua` (pure schedule) + `tests/test_catchability.lua`
  (never 100%-catchable). Cadence magnitudes are (tune) → §15-14.
  - **`ci-2ba` (sporadic timing, landed):** flare *timing* is now SPORADIC, not a
    fixed metronome — the calm gap before each event is a random draw in
    `[CALM_MIN_TICKS, CALM_MAX_TICKS]` (mean = the old fixed calm), so the next
    flare is unpredictable by clock. The telegraph, ramp/plateau/decay shape, and
    ~100× magnitude are unchanged (capacity sizing still matters; every event is
    still reactable). Scheduling is a deterministic, save/load-stable Lehmer PRNG
    in `storage` (not `math.random`). The environmental scanner (ci-3o3) reads the
    new `cindra-flare` remote interface (`flare.forecast`) and so becomes a
    REACTIVE early-warning device: forecast only while a flare telegraphs/is
    active, `nil` (calm) otherwise.
- [x] **§15-8 — Panel damage.** `ci-9ay` — disposal-deficit rule, degrade-before-
  death, self-correcting (negative feedback), dissipator-as-fuse. `scripts/panels.lua`
  (edge-bias reads the ribbon sunward axis). Tested: `tests/test_panel_damage.lua`,
  `tests/test_disposal.lua`. Closed under ci-9k6.
- [x] **§15-9 — Storage.** `ci-tii` — capacitor (fast spike) + molten-salt battery
  (bulk plateau, heat-upkeep or it "freezes") + dedicated dissipator.
  `prototypes/storage.lua` + `scripts/sinks.lua`; exportable buildings are
  situational-not-strictly-better (§12). Tested: `tests/test_storage.lua`,
  `tests/test_power_prototypes.lua`. Closed under ci-9k6.
- [~] **§15-10 — Electric heater.** `ci-f5l` — capped heat (600°) / uncapped power
  draw; roles: nightside warmth, flare sink, water boil-off, safe dissipation;
  built from a native ingredient (import-gated / clumsy elsewhere).
  - Building landed: `prototypes/electric-heater.lua` (heating-tower clone →
    electric source, 600° heat cap), item + recipe + `cindra-electric-heating`
    tech (variant of the heating-tower tech). Tested: `tests/test_heater.lua`
    (heat cap, electric-not-burner, situational-not-strictly-better vs heating
    tower §12, gated recipe/tech, runtime placement on Cindra).
  - TODO(ci-txh): swap the vanilla recipe ingredients for the signature aluminium
    to make the "clumsy off-world" import gate real (the old cryo-alloy plan is
    dropped, ci-84s).
- [x] **§15-11 — Mass driver.** `ci-r10`, `ci-98r`, `ci-o39` — the DEFINITIVE spec:
  a **reskinned rocket-silo**. Launch + cross-surface delivery are the ENGINE's
  vanilla behaviour (no runtime loop, no platform-side catcher — cargo lands in the
  space platform hub like normal rocket cargo). A launch burns an **aluminium can**
  (cargo container) + **aluminium-powder solid rocket fuel** + a shitton of power,
  all PETROCHEMICAL-FREE — the recurring cost lands on Cindra metallurgy + power,
  never oil/coal rocketry.
  - Landed (ci-o39): `prototypes/mass-driver.lua` — the driver is a full deep-copy of
    the vanilla `rocket-silo` (keeps `rocket_entity`/cargo pod so delivery is
    hub-accepted), reskinned with the mass-driver icon, `fixed_recipe` = a private
    launch-charge that consumes `{ aluminium can + solid rocket fuel }` over a long,
    high-draw craft. Adds the launch-fuel chain (aluminium → can; aluminium → powder
    → solid fuel). Item lives in the Space crafting tab. Deleted the old composite
    (container + hidden charger + `scripts/mass-driver.lua` fire loop + native shell).
    Recipes gated behind `cindra-orbital-launch`. Tested: `tests/test_mass_driver.lua`
    (type=rocket-silo, launch cost = can+fuel+huge power, petrochemical-free chain,
    private-category / never-mutate-vanilla-silo, Space-tab placement, no catcher,
    builds on Cindra with a vanilla platform hub as its destination). Full visual
    launch → hub delivery is a PLAYTEST item (rides the vanilla rocket path).
  - DONE(ci-3or): folded into the Cindra science tree — `cindra-orbital-launch`
    now branches off `cindra-science` and is researched WITH the Cindra science
    pack (an advanced, headline-gated export capability).
- [x] **§15-12 — Cindra science pack + tech tree.** `ci-3or` — the HEADLINE
  science, `prototypes/science.lua`: a petrochemical-free `cindra-science-pack`
  (native inputs only — the signature aluminium + deep-nightside volatiles +
  ice-chain calcite; re-based off the retired cryo-hardened alloy by ci-84s)
  crafted in a dedicated power-hungry `cindra-starforge` (~10 MW draw, long
  craft), so the largest continuous activity is another flare-timed power sink
  (ties to ci-9k6 / ci-63d). Gated behind the signature aluminium tech
  (`cindra-science` tech, researched with brought packs to avoid a soft-lock),
  and it FOLDS orbital launch into the tree as the first
  downstream unlock. Pack appended to the labs' inputs (additive, safe). Tested:
  `tests/test_science.lua` (petrochemical-free/native-only, high energy cost,
  electric high-draw machine that only crafts when powered, private category, tech
  gating + fold, a lab actually accepts the pack). Balance of amounts/draw is
  `(tune)` → §15-14.
- [x] **Start-on-Cindra foundry bootstrap.** `ci-arw` (cross-cutting; APS +
  mechanics). The no-Vulcanus start needs a foundry but the vanilla recipe is
  pressure-gated to Vulcanus and needs oil lubricant. `prototypes/lubricant.lua`
  adds a native, gated path: `cindra-crude-lubricant` (finite bootstrap
  coal → lubricant — coal now dabbed into the bootstrap rocks, §4a), the renewable
  `cindra-mineral-lubricant` (stone + water → lubricant), and `cindra-field-foundry`
  (a Cindra-buildable `foundry` recipe with no pressure gate), all behind the
  `cindra-improvised-metallurgy` tech; `mods/cindra-start/control.lua` pre-researches
  it on a Cindra start. Vanilla foundry recipe + lubricant fluid untouched, so
  normal imported play (DESIGN §8) is unaffected. See DESIGN §5b. Tested:
  `tests/test_foundry_bootstrap.lua` + (APS) `tests/test_aps_foundry.lua`.
- [x] **§15-13 — Bootstrap traversal check.** `ci-uex` — `tests/test_bootstrap.lua`
  proves landing → self-sustaining lava→metal economy is traversable: the fire
  spine is driven end-to-end (stone→lava→molten-iron + stone loop-back), a
  reachability solver over the real recipes shows no chicken-and-egg up to the
  Cindra science pack (seed materials become locally renewable), and the finite
  bootstrap rock is asserted to never be a per-craft loop input. The start-on-Cindra
  (any-planet-start) run from ABSOLUTE zero still soft-locks at the foundry
  (building one needs metal + lubricant) — the solver documents this as a tripwire.
  `ci-arw` (above) has now landed the native-lubricant + Cindra-buildable
  `cindra-field-foundry` recipe path and its APS tech pre-research; the **remaining
  follow-up** is the physical starting KIT (a starter foundry / metal seed) plus an
  end-to-end APS-mods bootstrap proof, after which the tripwire is revisited.
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
- **Flare-response circuit building (§12-8).** Power-grid sensor / priority-switch
  for first-class flare automation.
