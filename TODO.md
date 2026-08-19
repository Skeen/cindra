# Cindra — backlog

Work follows the **§15 implementation order** from the design brief. Each item is
tracked by a bead (prefix `ci-`); check `bd show <id>` for detail and `bd ready`
for what's unblocked. Deliver each item as tested sub-commits, land through the
merge queue.

> **Test-first (non-negotiable):** every gameplay change needs an integration
> test (`mods/cindra/tests/test_*.lua`) and/or a plain-Lua unit test
> (`mods/cindra/unit-tests/`). Those tests assert what the PLAYER OBSERVES
> (conservation, damage, on/off, demand-driven), never a restatement of the
> implementation constants — a test that could still pass while the behavior is
> broken is the wrong test (`ci-m96z`). See [`AGENTS.md`](AGENTS.md).

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
  - Nightside NATIVE freeze (`ci-bvk`, replaced the interim scripted building-heat):
    the planet's `entities_require_heating` flag + an invisible worldgen heat-pipe
    "lava-heat" emitter line (`scripts/freeze.lua`, `scripts/freeze-emitters.lua`,
    `prototypes/freeze-emitter.lua`) keep the habitable band thawed while the
    nightside freezes for real; a nearby heat source (ci-f5l heater) thaws a pocket.
  - SUPERSEDED since (`ci-oe83` / `ci-ma18` / `ci-wly`, retired by `ci-7k6`): damage
    is keyed to the TILE under an entity (`scripts/tile-damage.lua`), the boundaries
    come from the one heightmap's per-zone widths (`scripts/terrain.lua`), and the
    world edge is the map-gen's finite dimension = the sum of those widths. There is
    no `wall_at` and no hard-wall backstop; `ribbon.zone` / `ribbon.damage_per_second`
    / `ribbon.past_wall` and the three settings that fed them are gone.
  - Tested: `tests/test_tile_damage.lua`, `tests/test_worldgen.lua`,
    `tests/test_settings_live.lua`, `tests/test_freeze.lua`, `unit-tests/test_freeze.lua`,
    `unit-tests/test_freeze_emitters.lua`.
- [x] **§15-3 — Resources.** `ci-l72` (worldgen track `ci-9nj`).
  - `prototypes/resources.lua` + `scripts/resource-field.lua` (pure band geometry)
    + runtime placement in `scripts/worldgen.lua`: stone (ribbon), ice
    (nightside), scattered finite bootstrap rocks near the terminator;
    best nodes at the lethal margins (edge-pushing).
  - Tested: `tests/test_worldgen.lua`, `unit-tests/test_resource_field.lua`.
  - *Unblocks 4, 5* — the mechanics track consumes `stone` / `ice`
    (recipes are theirs to add).
- [x] **§15-5 — Lava + metal.** `ci-8mw`, `ci-669`, **`ci-9yg` (current model)**,
  `ci-eat` (sulfur), `ci-4ee` (spazz fix) (mechanics track).
  - **The ci-9yg REDO supersedes ci-669's `cindra-lava` fluid.** `prototypes/lava.lua`:
    recipe `cindra-lava` — `1 stone + [ruinous power] → 5 lava` (nerfed from 1:10),
    cast as a 64:320 batch, outputting the **ONE vanilla `lava` fluid** (no
    `cindra-lava` fluid at all), in a private `cindra-lava-manufacturing` category
    so ONLY the dedicated caster (ci-e8a) crafts it. Cindra casts through the
    **unmodified vanilla** `molten-iron/copper-from-lava` recipes — no Cindra cast
    clone. Productivity is **DISABLED** so stone-in per cast is fixed. Gated behind
    the `cindra-lava` tech (prereqs foundry + `planet-discovery-cindra`).
  - **The exploit is closed by ECONOMICS, not gating:** one cast's 500 lava costs
    100 stone in (fixed, prod off); the vanilla casts return ≤ 10·4=40 (iron) /
    15·4=60 (copper) stone at the +300% cap — both below 100 — so `stone → lava →
    cast → metal + stone` net-consumes stone on every surface at every module tier.
  - **Sulfur (ci-eat):** the melt IS the roast — the stone→lava recipe also yields
    a small `sulfur` byproduct (`ignored_by_productivity`), which feeds the vanilla
    `sulfur + water + iron-plate → sulfuric-acid` recipe the tech unlocks (never
    mutated). This is the Option-B acid route the ci-6vj graph (§8) builds on.
  - Tested: `tests/test_lava.lua` (1:5 ratio, single vanilla fluid, prod-off
    invariant, the ci-9yg stone net-negativity proof at 0%/+300% for both metals,
    never-mutate guard on the shared fluid + molten recipes, throughput/power pins,
    live foundry casts on Cindra) and `tests/test_sulfur.lua` (small byproduct,
    productivity double-lock, vanilla acid chain closes). See DESIGN §5 / §7 / §8.

## Backlog (§15 order)
- [x] **§15-4 — Ice processing.** `ci-rgv`, `ci-4or`, `ci-3mx`, **`ci-9l6`
  (current model)** — `prototypes/ice-processing.lua`. **The ci-9l6 rework
  SUPERSEDES the old oxide-chunk/crusher model** (ci-3mx/ci-4xx): there is no
  feedstock chunk and **no ground crusher** any more. The nightside ice field
  (`cindra-ice`, in `resources.lua`) is now a **multi-product resource** — one
  mining action drops a fixed **`ice` + `calcite` mix** (ice-majority), making
  `calcite` a native mined resource. `ice-processing.lua` adds **nothing but the
  melt-unlock effect**: melting is the vanilla `ice-melting` recipe in the vanilla
  chemical plant (ice → water); no custom melter/item/recipe/category/tech. The
  melt is unlocked by the existing `planet-discovery-cindra` tech (APS enables it
  from tick zero on a Cindra start). The ci-8n6 free-metal/coal exploit is closed
  BY CONSTRUCTION (no crushing machine, no asteroid chunk to reprocess). Tested:
  `tests/test_ice_processing.lua` (field mines the fixed ice+calcite mix, no
  crusher/oxide-chunk/custom-ice survives, no free-metal/coal path reachable,
  vanilla prototypes unchanged, discovery unlocks the melt, end-to-end powered
  drill → ice+calcite then chemical-plant melt ice → water on Cindra). See
  DESIGN §4a / §5a.
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
  (native inputs only — the signature aluminium + deep-nightside ice +
  ice-chain calcite; the former volatiles input was removed entirely by ci-ml1,
  re-based off the retired cryo-hardened alloy by ci-84s)
  crafted in an ordinary assembling machine (stock `crafting` category) via a
  long, power-hungry craft, so the largest continuous activity is another flare-timed power sink
  (ties to ci-9k6 / ci-63d). Gated behind the signature aluminium tech
  (`cindra-science` tech, researched with brought packs to avoid a soft-lock),
  and it FOLDS orbital launch into the tree as the first
  downstream unlock. Pack appended to the labs' inputs (additive, safe). Tested:
  `tests/test_science.lua` (petrochemical-free/native-only, high energy cost,
  stock assembler that only crafts when powered, no bespoke machine/private
  category, tech gating + fold, a lab actually accepts the pack). Balance of amounts/draw is
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
- [~] **§8 — Materials/petrochemical economy: the authoritative recipe graph.**
  `ci-6vj` (EPIC). The design of record for Cindra's full chemistry is now
  **DESIGN §8** — the canonical recipe graph (lava/sulfur, water electrolysis,
  calcination → quicklime + CO2, alumina acid-leaching, alumina electrolysis + O2,
  nano-Al powder, ALICE + methanol rocket fuels, methanol synthesis, MTO+poly, the
  two catalyst systems with make/reprocess/regen loops, quicklime disposal, and the
  byproduct vents). It **reconciles** the already-merged ci-400 (plastics), ci-eat
  (sulfur), ci-8g1 (ALICE), ci-9l6 (ice mix). Implementation is staged
  dependency-ordered under the epic (see `bd show ci-6vj`); land in order:
  1. **[x] quicklime rename + disposal sink** (`ci-6vj.1`, landed) — `cindra-lime`
     → `cindra-quicklime`; added quicklime disposal (`quicklime + lava → stone`,
     prod off, net stone-negative) and the vent-quicklime/vent-CO2 emergency sinks.
     Tested in `tests/test_plastics.lua`.
  2. **aluminium line reshape** — alumina by acid leaching (`stone + acid + water →
     alumina + 70% stone + sulfur`); alumina electrolysis emits 30 O2.
  3. **calcination move** — into the lava manufacturer, product renamed quicklime.
  4. **catalyst systems** — methanol-catalyst + zeolite-catalyst, each with a
     make recipe + a reprocess/regen loop; methanol synthesis + MTO+poly consume
     them (70% return / 20% spent); remove the ci-400 `olefins` intermediate and
     `cu-al-catalyst`.
  5. **rocket fuels** — ALICE takes O2 as oxidiser; add methanol rocket fuel.
  6. **balance + invariant proof** — the O2 economy balances (sinks absorb the
     electrolysis flood or vent), and a graph-balance test proves the stone/metal/
     carbon loops stay net-negative at the +300% productivity cap.
  Every stage keeps the shared item/fluid/machine interfaces in DESIGN §8 and adds
  its tests. Feeds directly into §15-14.
- [ ] **§15-14 — Balance pass.** `ci-63d` — tune all `(tune)` values against the
  lava energy cost; verify exportable buildings are **situational-not-strictly-
  better** than vanilla (§12 guardrail). Depends on the §8/ci-6vj graph landing.

## Worldgen redesign (ci-wly keystone + staged follow-ups)

- [x] **Heightmap tile redesign — 3-part hot/habitable/cold gradient + integrated
  oceans.** `ci-wly` — replaced the old 11-zone gradient with a THREE-PART,
  TWO-HEIGHTMAP world (HOT ocean+slope / habitable ash MIDDLE / COLD ocean+slope).
  Both oceans folded into the heightmap (never stamped); smooth-ice now WALKABLE (no
  ice wall); per-tile damage scaling; no-pave hazard tiles (HALF of `ci-8vu` -- the
  walkway; the tap itself was closed later by stripping the lava tiles' fluid). Supersedes
  `ci-4kz` (ice wall dropped), subsumes `ci-7jc` (ocean/heightmap integration) and
  `ci-70r` (bespoke gradient tiles). `scripts/terrain.lua`; tested in
  `unit-tests/test_terrain.lua` + `tests/test_worldgen.lua`.
- [x] **ONE continuous heightmap (not three) — emergent oceans, belt-confined damage.**
  `ci-oe83` — replaced the two-heightmap-plus-flat-middle model with a SINGLE monotonic
  value field `H(p)` over the perpendicular axis: edge-PINNED to the lava/ice extremes,
  CLAMPED strictly between the damage thresholds through the middle. Both oceans EMERGE as
  the field's pinned extremes (removing the ocean band does not remove the ocean). BOTH the
  tile art (`M.value_tile`) and the damage (`M.value_damage`/`M.field_damage`) derive from
  the one value, so damage follows the FIELD/position, not the tile-type — killing the
  walk-to-ocean no-damage corridor on both sides (`scripts/tile-damage.lua` rekeyed to the
  field). Gated by `tests/test_heightmap.lua` (repro/emergence/continuity/clamp/golden/
  no-enclosure, driving the real sweep) + `unit-tests/test_terrain.lua` +
  `unit-tests/test_tile_damage.lua`. `ci-bvk` freeze onset keys off this field now.
  FOLLOW-UP (aesthetic, enabled by the damage decoupling): deliberate cross-region cosmetic
  scatter (hot-looking tiles out in the safe middle) — safe because damage is positional;
  needs the family-separation guard relaxed. Not yet done; see PLAYTEST.
- [x] **Hot-side folds BRANCH.** `ci-72bw` — DONE. The alternate volcanic-folds /
  ash-cracks / pumice family covers the same value segment as the cracks main line below
  cracks-hot, picked per REGION by a low-frequency branch noise (`scripts/terrain.lua`
  `BRANCH_*`), both converging on ash-dark. Gated to the slope band so it never reaches
  the middle / cold side / heat belt, and damage-neutral (folds-warm == cracks-warm).
  Gated by `unit-tests/test_terrain.lua` + `tests/test_worldgen.lua`; the look is a
  PLAYTEST entry.
- [x] **Decals + icy-side snowfall.** `ci-mk5y` — DONE. The COLD side landed with `ci-tizx`
  (ice/snow decals start at the icy-ground edge `terrain.damage_bounds().cold_from` instead
  of the safe band, fade in over 40 tiles, thinned to a fraction of the mirrored Aquilo
  density so the tiles read through — see `docs/verification/ci-tizx-cold-decal-density.png`).
  This bead closed the other two halves:
  * **HOT re-gate onto the heightmap tiles.** The rock/crater decals were still gated on the
    ribbon safe band (`perp > 24`) with NO outer bound, so they littered the brown ash middle
    and floated out over the molten lava. They now ride the volcanic slope + crust: the value
    segment from the ash convergence (`terrain.BRANCH_SPAN.lo`) up to the molten floor
    (`terrain.MOLTEN_FLOOR`), converted to two gate lines by the new `terrain.field_crossing`
    (the field's inverse) with a value margin for the terrain's own wiggle + speckle. A zone
    band edge would NOT have worked: the lava contour sits ~35 tiles inside the hot-ocean band.
  * **Icy-side snowfall.** `scripts/snowfall.lua` + `prototypes/snowfall.lua`: a drifting
    per-player flake field on its own nth-tick (3), gated PER FLAKE on the perpendicular axis
    at the same icy-ground edge the cold decals use — stand at the boundary and it snows on
    your nightward side only. Render objects (not engine particles) so the "snow only on the
    ice" invariant is testable; the stock white square as v1 flake art.
  Gated by `unit-tests/test_decorative_field.lua` + `unit-tests/test_snowfall.lua` +
  `unit-tests/test_terrain.lua` and, on a live surface/player,
  `tests/test_decoratives.lua` + `tests/test_snowfall.lua`. The LOOK of both is a PLAYTEST
  entry.
  * **ICE-OCEAN thinning.** `ci-10ze` — DONE. ci-tizx's fade-in reaches full strength ~18
    tiles short of the smooth-ice sheet, which then runs ~212 tiles to the map edge, so the
    frozen SEA carried the densest clutter on the planet and did not read as an ocean at
    all. The cold decals now fade back OUT offshore (`OCEAN_DENSITY` 0.12 over
    `OCEAN_FADE_SPAN` 24 tiles), gated on the smooth-ice TILE contour (the new
    `terrain.FROZEN_CEILING` through `terrain.field_crossing`) rather than the cold-ocean
    band edge, which sits ~12 tiles too far out. Measured 0.090 -> 0.010 decals/tile on the
    open sheet; before/after: `docs/verification/ci-10ze-ice-ocean-decals.png`.
  * **COLD-DECAL COVERAGE BUDGET.** `ci-fwaq` — DONE. ci-tizx's 0.1 decals/tile ceiling was
    guarded by ONE in-engine measurement on ONE seed, so the `ci-w87` iceberg families
    joined the cold set with no re-balance and took the frost shore from 0.059 to 0.090 --
    a 90% spend nobody had to re-read. Coverage is now PREDICTED from the catalogue in
    closed form off the game (`field.coverage_budget`: each scatter's covered fraction is
    an integral over its `random_penalty`, times its `density`), and the guard is split in
    two halves that together bound the measured coverage on ANY seed rather than on the
    fixed one: `unit-tests` hold `budget * (1 + tolerance) <= ceiling`, and
    `tests/test_decoratives.lua` proves the engine really generates what the budget
    predicts (measured 0.0896 vs budget 0.0850, +5.5%, tolerance 15%). A new cold family
    now costs its ground the moment the row is written, so the density pass lands in the
    same commit; the ceiling constant carries its own upper bound so "raise it to fit"
    fails a test. No art changed — the densities are exactly as ci-w87 left them.
- [x] **Orbital / star-map re-render.** `ci-4qyj` — DONE. The from-space art no longer
  keeps a colour ramp of its own: `scripts/terrain_ramp.py` reads `scripts/terrain.lua`
  and replays its position -> heat -> tile -> colour chain, so the globe shows the real
  three-part planet (broad lava ocean / habitable middle / broad ice ocean) at the
  terrain's own widths, and emission is gated on the heat field so only lethal ground
  glows. Maps + bake + star-map sprite + icon + thumbnail regenerated. Guarded by
  `unit-tests/test_terrain_ramp_lockstep.py` (runs the real Lua module and the Python
  replay side by side), plus the extended `test_planet_maps.py` / `test_starmap_lighting.py`.
- [x] **Worldgen sliders on the new-game map-gen screen.** `ci-i4z` — DONE. `ci-i8a`
  landed stone + ice DENSITY as autoplace-control sliders; this adds the ribbon
  GEOMETRY: **Habitable band**, **Hot zone**, **Cold zone** on the Terrain tab, whose
  *Size* multiplier scales the playable middle band and the two zone depths. The engine
  has no custom scalar map-gen slider, so the encoding is a `terrain`
  autoplace-control's Size read from the noise system (`control:<name>:size`) and
  applied as ONE warp of the perpendicular coordinate every band is read against
  (`scripts/zone-scale.lua`, the `cindra_perp` named expression that `axis.perp_expr`
  now returns) — so tiles, resources, decoratives, the freeze line and the solar curve
  all follow with no per-system change, and the tile-keyed damage follows the tiles for
  free. The two oceans absorb the difference, so the map's finite width and void
  backstop never move; off Cindra (and at default sliders) the warp is the identity.
  Startup zone widths stay the NOMINAL geometry the sliders multiply. Gated by
  `unit-tests/test_zone_scale.lua` (including an evaluation of the emitted map-gen
  expression against the runtime warp) + `tests/test_worldgen_sliders.lua`; the
  screen's look/feel is a PLAYTEST entry.
- [x] **Stone/Ice slider EFFECT measured, not just their existence.** `ci-y19` — DONE.
  `tests/test_worldgen_resource_sliders.lua` generates fixed-seed surfaces with one
  resource slider moved and counts the ore actually in the ground, patch by patch
  (flood-filled clusters): Richness puts ~4x the ore in a bit-identical footprint,
  Size fattens the patches without scattering new ones, Frequency scatters more of
  them, Size 0 removes the resource and leaves the other one untouched, and no
  setting pushes a field out of its band. Verified sensitive by pinning every
  `control:*` var to 1 in `banded_autoplace`: all five effect tests fail. It turned
  up two bugs, both now FIXED below: `ci-l3k3` (ICE *Frequency* inert above 0.5) and
  `ci-bgpm` (at maxed sliders 16 stone tiles landed on heat-damaging crust) -- the
  suite's damaging-ground check runs on the maxed-out world too now.
- [x] **The ICE Frequency slider actually moves the ore.** `ci-l3k3` — DONE. The engine's
  spot placer will not put more than `candidate_spot_count` spots in a 1024x1024 region
  and its default is 21 (~20 spots/km2), so ice -- which declares 40 -- was truncated:
  the nightside was generated at HALF its declared density, and every Frequency from 0.5
  to the slider maximum produced a BIT-IDENTICAL world (measured in-engine, seed 24680,
  8192 chunks: 3339 ice tiles at Frequency 1, 2, 4 and 6 alike). `banded_autoplace` now
  derives each resource's budget from its own declared density (`spot_budget` =
  spots/km2 x the maximum Frequency x the region area, floored at the engine's 21), so
  the WHOLE slider range is live: 2003 / 3057 / 5665 / 12375 / 25292 / 37166 ice tiles at
  Frequency 0.25 / 0.5 / 1 / 2 / 4 / 6. Stone is unchanged (2.5/km2 never reached the
  budget, and the floor keeps its spec byte-identical). Worldgen cost of the 12x bigger
  candidate pool measured over the same 8192 chunks: 5.85-6.12 s vs 5.82-6.59 s before,
  i.e. no measurable cost. THE BALANCE SHIFT: default-slider nightside ice is ~1.7x what
  it was, which is the density the `ci-wly` tuning comment always intended. Tests:
  `tests/test_worldgen_resource_sliders.lua` -- the Ice Frequency 4 case (fails on main),
  plus a class-wide guard that enumerates the resource sliders LIVE off the map-gen
  screen and fails any whose Frequency 6 world is not much richer than its default, so a
  new resource cannot ship saturated.
- [ ] **Decals + icy-side snowfall.** `ci-mk5y` — re-gate decals to the new tiles; add
  snowfall on the cold side only. PARTIALLY DONE by `ci-tizx` for the COLD side: the
  ice/snow decals now start at the icy-ground edge (`terrain.damage_bounds().cold_from`)
  instead of the safe band, fade in over 40 tiles, and are thinned to a fraction of the
  mirrored Aquilo density, so the tiles read through them (see
  `docs/verification/ci-tizx-cold-decal-density.png`). Still open here: the HOT-side
  re-gate (rocks/craters still key off the ribbon safe band) and the snowfall effect.
- [x] **Bootstrap rocks off damaging ground.** `ci-pxlz` — DONE. The ice-rock band was
  clamped positionally at the nominal cold-damage boundary with NO keep-back, and
  `ci-18n`'s comment read that clamp as "hand-gatherable with no cold damage". It was
  not: cold-damaging snow bleeds ~20 tiles middle-ward of that boundary, so 10 of 579
  ice-rocks (seed 24680, 2800 rows) were planted in freezing ground — on the
  landing-tier trip you make before owning any cold gear. Fixed the `ci-w87` way, by
  TILE: both bootstrap scatters carry `field.bootstrap_rock_tile_restriction()`
  (= `terrain.tiles_by_damage(nil)`). It costs the bands nothing measurable — ice-rocks
  579 → 574 (0.9%, not the 4.5% the bead estimated), the scatter still reaching to
  within 0.4 tiles of the lethal boundary, and the sandy scatter unchanged at 1763
  (its band is all safe ground, so the gate there is structural insurance). Proven in
  `tests/test_worldgen_rock_ground.lua`, which reads the ground under every rock that
  generated and then stands a character in each of those grounds on the LIVE surface
  and runs the real damage sweep, plus no-retreat and LIVE coverage guards; rotated
  in `tests/test_worldgen_horizontal.lua`; the pure gate in
  `unit-tests/test_resource_field.lua`. `ROCK_COLD_MARGIN` stays as the cosmetic fade
  it always was — the bead's noted sandy-rock-on-frost-LOOKING-dust mismatch is
  looks-only (both tiles are safe ground) and is left as it is.
- [ ] **Orbital / star-map re-render.** `ci-4qyj` — re-bake the from-space art +
  `scripts/gen-planet-maps.py` colour ramp to MATCH the new terrain (required follow-up).
- [x] **No field ever lies on ground that damages you.** `ci-bgpm` — DONE. `ci-fb9`/`ci-4iw`
  rested that promise on a POSITIONAL keep-back (`FIELD_DAMAGE_MARGIN`, 9.5 tiles, sized
  off the tile-boundary noise amplitudes), and it was ~6x too small: the tile family comes
  from the noisy heightmap VALUE, where the per-tile speckle is a 0.012 FIELD-unit
  tie-break worth ~6 tiles per competing tile on the gentle outer slopes. Measured
  in-engine (seed 24680, 8192 rows): heat crust reaches 18 tiles warmward of its nominal
  boundary, cold snow 20 middle-ward — so at maxed Stone sliders 16 stone tiles (of 17681)
  generated on `cindra-volcanic-cracks-hot` and burned you as you mined them. Fixed the
  `ci-w87` way (gate on the TILE, not the coordinate): both field resources carry an
  autoplace `tile_restriction` to `terrain.tiles_by_damage(nil)`. It removed exactly those
  16 tiles and nothing else — the bands keep their full width and still reach to within
  ~10 tiles of lethal ground, so unlike a widened margin (~24 tiles, eating the richest end
  of both bands) it costs the edge-push reward nothing. Gated by
  `tests/test_worldgen_field_ground.lua` (every slider at 6, plus a live coverage guard
  over the `resource` prototypes and a no-retreat guard on the band's reach), a rotated
  sanity pass in `tests/test_worldgen_horizontal.lua`, and the pure gate in
  `unit-tests/test_resource_field.lua`. FOLLOW-UP: `ci-pxlz` — the ice-ROCKS have the same
  leak (38 of 840 stand on cold-damaging snow) and no keep-back at all; fixing it thins the
  bootstrap trickle, so it is its own balance call.
- **SEQUENCE NOTE:** native freeze (`ci-bvk`) is DONE and aligned onto this tile layout:
  its onset ties to the cold-side gradient (the middle's cold edge, ~p −60), not a wall.
  NB the emitter had to become a 1×1 heat-pipe (a heat-interface ignores `heating_radius`)
  and the measured reach is 101 / spacing 203, not the spike's 100 / 201.

## Deferred / cross-cutting

- **Custom art.** v1 reuses vanilla Vulcanus icons. Bespoke ribbon/terminator
  ground, star-map, and orbital-backdrop art is a later art pass — see
  [`PLAYTEST.md`](PLAYTEST.md).
- **~~Optional self-sufficiency mode (§11).~~ PROMOTED to core (ci-6vj, §8).** The
  CO₂/water/power → plastic + sulfur chemistry is no longer an optional flex: it is
  the authoritative materials graph in DESIGN §8, tracked by the ci-6vj epic above.
- **Flare-response circuit building (§12-8).** Power-grid sensor / priority-switch
  for first-class flare automation.
- **PlanetsLib.** Evaluated at 1.23.5 (`ci-810e`, see
  [`docs/planetslib-evaluation.md`](docs/planetslib-evaluation.md)). Verdict:
  **partially adopt, optional dependency only** — the orbit hierarchy buys a
  moonless star-orbiting planet nothing, and a hard dep would drag PlanetsLib's
  vanilla mutations (centrifuge, ~100 item rocket weights, tech-tree prereq
  unlinking) into every player's game, violating the never-touch-other-planets
  invariant. Cindra stays a good *citizen*: `tests/test_planetslib_compat.lua`
  pins the preconditions PlanetsLib's `data-final-fixes` imposes. The co-load is
  now **confirmed in-engine** (`ci-gg3x`, evaluation §5.1): both mods load, and
  PlanetsLib's only effect on Cindra is additive (retro-fitted orbit at the same
  coordinates, `is-freezing`, `planet-str`) — `tests/test_planetslib_coload.lua`
  keeps it that way. Remaining follow-ups: `ci-ndm9` guarded surface-condition
  helpers, `ci-dza6` optional dep, `ci-82ib` prototype migration; the last two
  need human sign-off.
