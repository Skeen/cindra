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
- [x] **§15-4 — Ice processing.** `ci-rgv` — `prototypes/ice-processing.lua`: a
  ground-standing `cindra-ice-crusher` (clone of the space crusher; drops the
  zero-gravity gate + space-platform heating draw, gains a water output fluid box)
  plus two recipes the player picks between — `cindra-ice-crushing` (ice → water)
  and `cindra-ice-crushing-calcite` (ice → water + calcite, trading water for
  calcite). A private `cindra-ice-crushing` recipe category keeps the recipes off
  vanilla space crushers (and vice versa); gated behind the `cindra-ice-processing`
  tech. Tested: `tests/test_ice_processing.lua` (category isolation, water fluid
  box, ground-placeability, recipe shapes/ratio, no vanilla-crusher leak, tech
  gating, and an end-to-end powered crush of ice → water on Cindra).
- [x] **§15-6 — Cryo-hardened alloy.** `ci-gd4` — `prototypes/cryo-alloy.lua`: the
  SIGNATURE two-temperature quench. A `cindra-cryo-quench` building (chemical-plant
  clone, electric, single hot-fluid input, private `cindra-quenching` category, re-
  skinned with the delivered signature art) crafts `cindra-cryo-hardened-alloy` from
  a HOT half + a COLD half in one recipe: `lava` fluid gated with
  `minimum_temperature` (500 C, so "hot" is engine-enforced, not nominal) + a
  `cindra-cryo-coolant` consumed item (packed from nightside `ice`). Ships the PoC's
  recommended model (item + fluid, temperature-gated; ci-o4r). Gated behind the
  `cindra-cryo-quenching` tech, whose prerequisites are BOTH `cindra-lava` (hot) and
  `cindra-ice-processing` (cold) — the "needs 4 + 5" mechanic expressed as a tech
  dependency. Tested: `tests/test_cryo_alloy.lua` (recipe shape + temperature gate,
  electric fluid-crafter, private-category isolation + no chemical-plant leak, lava
  fluid unmutated, coolant recipe, gating, tech dual-prereq, and an end-to-end
  powered craft that produces alloy ONLY when both hot and cold inputs are present).
  The advanced circulating-coolant variant (a second, max-temperature-gated cold
  FLUID) is deferred. *Needs 4 + 5.*
  - Follow-up (unblocked, tracked in-code): the `TODO(ci-gd4)` notes in
    `prototypes/electric-heater.lua` and `prototypes/mass-driver.lua` want the
    cryo-hardened alloy folded into their recipes to make the native-ingredient
    import gate real. Left out of this bead: routing the heater/shell through the
    full quench chain is a progression/bootstrap decision (soft-lock risk, ci-uex)
    and a balance-pass call (ci-63d), not part of shipping the signature building.
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
  - TODO(ci-gd4): swap the vanilla recipe ingredients for the native cryo-alloy
    once it lands, to make the "clumsy off-world" import gate real.
- [x] **§15-11 — Mass driver.** `ci-r10`, `ci-98r` — launch = power (bursty,
  flare-timed) + optional native projectile shell (A) vs pure-electric pods (B).
  Removes launch chemistry entirely. NO platform-side catcher (ci-98r): cargo
  lands in the space platform hub like normal rocket cargo, reusing the vanilla
  launch-to-platform destination.
  - Landed: `prototypes/mass-driver.lua` (driver container + hidden accumulator
    charger + native shell item; delivered art wired) and
    `scripts/mass-driver.lua` (charge→fire→deliver-to-hub loop, fire tick N=31,
    distinct from edge-damage/building-heat). Recipes gated behind a dedicated
    `cindra-orbital-launch` tech (option A, native shell). Tested:
    `tests/test_mass_driver.lua` (prototype shape, gating, chemistry-free,
    no-catcher assertion, proto/runtime drift, full launch loop delivering to a
    real space platform hub + preconditions).
  - TODO(ci-gd4): swap the shell recipe input to cryo-hardened-alloy once it
    lands (currently steel-plate stand-in, still zero-chemistry).
  - DONE(ci-3or): folded into the Cindra science tree — `cindra-orbital-launch`
    now branches off `cindra-science` and is researched WITH the Cindra science
    pack (an advanced, headline-gated export capability).
- [x] **§15-12 — Cindra science pack + tech tree.** `ci-3or` — the HEADLINE
  science, `prototypes/science.lua`: a petrochemical-free `cindra-science-pack`
  (native inputs only — the signature cryo-hardened alloy + deep-nightside
  volatiles + ice-chain calcite) crafted in a dedicated power-hungry `cindra-
  starforge` (~10 MW draw, long craft), so the largest continuous activity is
  another flare-timed power sink (ties to ci-9k6 / ci-63d). Gated behind the
  signature cryo-quench (`cindra-science` tech, researched with brought packs to
  avoid a soft-lock), and it FOLDS orbital launch into the tree as the first
  downstream unlock. Pack appended to the labs' inputs (additive, safe). Tested:
  `tests/test_science.lua` (petrochemical-free/native-only, high energy cost,
  electric high-draw machine that only crafts when powered, private category, tech
  gating + fold, a lab actually accepts the pack). Balance of amounts/draw is
  `(tune)` → §15-14.
- [x] **§15-13 — Bootstrap traversal check.** `ci-uex` — `tests/test_bootstrap.lua`
  proves landing → self-sustaining lava→metal economy is traversable: the fire
  spine is driven end-to-end (stone→lava→molten-iron + stone loop-back), a
  reachability solver over the real recipes shows no chicken-and-egg up to the
  Cindra science pack (seed materials become locally renewable), and the finite
  bootstrap rock is asserted to never be a per-craft loop input. **Remaining:**
  the start-on-Cindra (any-planet-start) run from ABSOLUTE zero still soft-locks
  at the foundry (needs lubricant) — the solver documents this as a tripwire; the
  lubricant-free/kitted APS foundry is `ci-arw`, and the end-to-end APS-mods
  bootstrap proof is a follow-up (blocked on `ci-arw`).
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
