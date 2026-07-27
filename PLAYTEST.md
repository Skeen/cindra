# Playtest checklist

Items pending in-game visual / interactive confirmation — the things
`factorio-test` **structurally cannot reach** (sprite appearance, day/night feel,
audio, UI, multiplayer). **Always prefer a test first** (see [`AGENTS.md`](AGENTS.md));
this list is the last resort when no test path exists.

## Pending

- [ ] **Reach and stand on Cindra (v1 smoke test).** *Repro:* `./play.sh` → New
  Game (with `cindra-dev-default` enabled, Any-Planet-Start lands on Cindra), or
  research `planet-discovery-cindra` from an existing save and travel from
  Vulcanus. *Look for:* the surface loads, the character spawns on buildable
  land, and you can place/mine entities. *Fallback:* the headless `factorio
  --create` load + `test_planet.lua` already prove the prototype loads and the
  surface generates; this entry is only for the interactive "it feels like a
  place you can stand" confirmation.

- [ ] **Ice crusher fluid-pipe visuals (§15-4).** *Repro:* build a
  `cindra-ice-crusher`, run `Ice crushing (water)`, and connect a pipe to its
  south face. *Look for:* the water output connects and drains cleanly. The
  crusher reuses the vanilla space-crusher art, which has no built-in pipe-covers
  sprite for the added output box, so the connection point may look bare (no
  pipe-cover graphic) even though it functions. Confirm the two south-edge output
  connections line up with pipes and that the building still reads as a crusher.
  Bespoke art (pipe stubs) is a later art pass, not a v1 bug. (Functionality —
  ice → water production and both recipes — is integration-tested.)

- [ ] **Redesigned globe reads FIERY → SANDY → ICY in orbit (ci-hmc).** The
  planet globe was re-themed to the ribbon world: a radiant molten dayside, the
  DARKEST icy-blue nightside, and a warm SANDY terminator seam down the middle
  (fixing the old black centre). The baked star-map sprite is verified off-game
  (`unit-tests/test_planet_maps.py` asserts the fiery/sandy/icy split and that the
  sandy seam carries its own emission so the middle is never black; sampled centre
  ≈ RGB [139,108,61] sandy, fire limb ≈ [244,168,137], ice limb ≈ [40,57,77]).
  *Repro:* `./play.sh`, open the star-map / navigate the orbital approach to
  Cindra. *Look for:* the LIVE orbital backdrop (which `factorio-test` cannot
  render) shows the same split — luminous lava on the left limb, a clearly lit
  sandy band across the centre (NOT black), and a dark blue-shimmer nightside on
  the right; the globe does NOT rotate (tidally locked) while the terminator
  steam band and the solar flares off the fire limb animate in place.

- [ ] **Electric heater reads as electric, not a furnace (§15-10).** The building
  reuses vanilla heating-tower art with the burner fire-glow removed. *Repro:*
  research `cindra-electric-heating`, build a `cindra-electric-heater`, wire it to
  power and a heat-pipe network. *Look for:* it draws power and warms the heat
  network to ~600°C (no higher), shows no combustion flame, and reads as an
  electric heater rather than a fuel-burning tower. (Prototype fields + runtime
  placement are tested in `tests/test_heater.lua`; only the *visual read* is a
  playtest, pending bespoke art.)

- [ ] **Cryo-quench art + hot-pipe read (§15-6).** The quench wears the delivered
  signature sprite (`graphics/entity/cryo-quench/`, ART-MANIFEST ci-pru), a single
  static frame with the chemical-plant animation/foam/smoke stripped. *Repro:*
  research `cindra-cryo-quenching`, build a `cindra-cryo-quench`, pipe `lava` into
  its input fluid box and belt in `cindra-cryo-coolant`. *Look for:* it reads as a
  two-temperature forge (not a chemical plant), the hot-fluid input connects and
  drains, and the alloy comes out on the item side. The manifest defers the
  animated "quench flash" (a working-visualisation layer over this idle base) to a
  later art pass, so no craft-time glow is expected in v1 — do not file that as a
  bug. (Recipe shape, temperature gate, category isolation, and the end-to-end
  both-inputs-required craft are integration-tested in `tests/test_cryo_alloy.lua`;
  only the *visual read* and pipe alignment are a playtest.)

- [ ] **Ribbon reads as a ribbon (§15-2/3 landed).** The lethal-edge damage,
  hard-wall backstop, and resource bands are implemented and integration-tested
  (`test_edge_damage`, `test_worldgen`, `test_building_heat`). Confirm in-game the
  *feel*: the playable band reads long east–west and constrained north–south; the
  `out-of-map` void beyond the wall reads as a clean boundary (not a jarring
  cliff); walking sunward visibly cooks and nightward visibly chills the
  character HP; and pushing to the lethal margins for the richest stone/ice/
  volatiles feels like a deliberate, survivable-with-gear risk. (The axis *values*
  and *placement* are tested; the *felt geometry* is a playtest.)

- [ ] **Resources read as NATURAL PATCHES + map-gen sliders respond (ci-8nh).**
  Stone / ice / volatiles now use NATIVE Factorio resource autoplace (spot-noise),
  band-masked to the ribbon axis, replacing the old uniform script grid. Placement,
  band constraint (stone on the ribbon+hot margin, ice nightward, volatiles deep
  cold-lethal), edge-pushing richness, and NO-water are integration-tested
  (`tests/test_worldgen.lua`, on a fixed-seed surface). Confirm in-game the parts a
  test cannot: *Repro:* `./play.sh` onto Cindra. *Look for:* (1) stone/ice appear as
  IRREGULAR patches of varying size/richness (like nauvis ore), NOT a repeating grid
  of identical deposits; (2) on the New Game map-gen screen, the Resources tab shows
  `cindra-stone` / `cindra-ice` / `cindra-volatiles` Frequency/Size/Richness sliders,
  and cranking them visibly changes patch count/size/richness; (3) NO water tiles or
  starting lake anywhere at any water-slider setting; (4) volatiles patches actually
  appear out in the deep cold-lethal nightside (their band is thin, so presence is
  playtest-confirmed, not asserted). Native autoplace is the fix for the reported
  "grid of identical 1920-stone deposits" bug.

- [ ] **From-nothing bootstrap start works (ci-8nh / §6).** Cindra has NO ore or
  coal patches at all; the finite hand-mined bootstrap rocks are the ONLY landing
  metal, and now drop stone + iron ore + copper ore + coal (yields are
  prototype-tested in `tests/test_worldgen.lua`). Confirm the actual bootstrap loop:
  *Repro:* start a fresh Cindra game with nothing, hand-mine the terminator rocks.
  *Look for:* enough stone to hand-craft stone furnaces AND enough iron/copper ore +
  coal to smelt a first trickle of plates and fuel — i.e. you can stand up the first
  foundry / power / ice-processing without a pre-existing ore patch, after which the
  infinite lava→metal economy takes over. If a from-nothing start soft-locks, that
  is a balance bug (coordinate amounts with ci-arw / ci-uex).

- [ ] **Resource art is placeholder.** Stone/ice/volatiles resources are cloned
  from vanilla `stone` (recoloured via `map_color`) and bootstrap rocks from the
  vanilla `huge-rock`; the volatiles item reuses the vanilla ice icon. Expected in
  v1 — bespoke Cindra resource art is a later pass. Do not file as a bug.

- [ ] **Cindra science art is placeholder (§15-12).** The `cindra-science-pack`
  reuses the vanilla automation-science-pack icon tinted a hot amber, and the
  `cindra-starforge` reuses the vanilla assembling-machine-3 sprite/icon. *Repro:*
  research `cindra-science`, build a starforge, craft a pack. *Look for:* the pack
  reads as a distinct Cindra pack in the lab/tech GUI and the starforge reads as a
  special (not just another assembler) building. Bespoke art is a later pass, not
  a v1 bug — functionality is fully test-covered (`tests/test_science.lua`).

- [ ] **Starforge power draw feels like a real sink (§15-12, feel).** The starforge
  draws ~10 MW active (a `(tune)` value, §15-14). *Look for:* running an array of
  them visibly leans on the grid / flare capture the way the design intends
  ("research is a power sink"), without being so punishing that early science
  stalls. Balance against the flare numbers (ci-9k6) and the balance pass (ci-63d).

- [ ] **Discovery lore reads well in the tech GUI (ci-11b).** The
  `planet-discovery-cindra` technology now carries the full §3 planet-discovery
  entry as its description. *Repro:* open the technology screen and hover/select
  the Cindra discovery tech. *Look for:* the longer lore paragraph fits the
  tooltip/description panel and reads cleanly (no awkward truncation). The five
  standalone codex blurbs (`cindra-lore.discovery/ribbon/flare/nightside/alloy`)
  are keyed for a future discovery-codex / tips-and-tricks reader and are not yet
  surfaced in-game; their *presence and shape* are unit-tested
  (`unit-tests/test_locale.lua`), so this playtest is only the tech-tooltip read.

- [ ] **Nightside cold damage vs Aquilo freeze (feel).** Unheated machines past
  the cold threshold take ticking cold damage (the spec's "take cold damage"
  option) rather than a reversible Aquilo-style freeze. Confirm the pace (default
  20 dps) gives enough time to run a heat umbilical out before a machine dies, and
  that it reads as "drag heat with you," not "instant loss." If the reversible
  freeze feels better, that is a future refinement, not a v1 bug.

- [ ] **Flare reads as a telegraphed surge (§15-7).** The flare cycle drives the
  frozen daylight curve calm → warning → fast ramp → plateau → fast decay, ~100×
  peak over a dim night floor. The schedule, ~100× swing, and non-100%-catchability
  are integration- + unit-tested (`test_flare`, `unit-tests/test_flare`,
  `test_catchability`); only the *sky read* is a playtest. *Look for:* the sky
  visibly dims between flares and blazes at the peak; there is no engine
  telegraph/alarm/countdown UI yet (the `warning` phase is exposed in
  `flare.state` but not surfaced to the player). A sky-brightening cue + a
  countdown alarm are a follow-up art/UI pass. Cadence magnitudes are (tune)
  (§15-14): the test-scale event is ~12 s; real play scales it up.

- [ ] **Sporadic flare timing FEELS fair, not punishing (ci-2ba).** Flare
  *timing* is now randomized (calm gap drawn from a band, mean = the old fixed
  cadence); the event shape and ~100× magnitude are unchanged. That the gaps are
  randomized-within-band, that every event is still telegraphed, and that the
  scanner only forecasts during the window are all tested (`test_flare` sporadic +
  forecast blocks). *Look for (feel, cannot be asserted):* the randomness reads as
  "unpredictable but fair" — you are never starved for minutes nor hit back-to-back
  with no time to recover; the warning window is long enough to react per event
  when you could NOT see it coming on a clock; riding flares still feels like a
  windfall you respond to, not a survival timer. Tune `CALM_MIN_TICKS`/
  `CALM_MAX_TICKS` (and the warning length) if it feels starved, clustered, or
  un-reactable. Ties into the §15-14 balance pass (ci-63d).

- [ ] **Panel damage reads as degrade-before-death (§15-8).** Undisposed flare
  surplus degrades the most-sunward panels first (recoverable), then destroys them
  under a sustained deficit; adding a dissipator/storage heals them. The rule,
  edge-bias, self-correction, and dissipator-as-fuse are integration-tested
  (`test_panel_damage`, `test_disposal`). *Look for:* the visual/health read of a
  panel array cooking sunward-first during an over-built flare, and recovering
  once disposal is added. Panels currently have no bespoke "overheating" visual
  (just the health bar); an emissive damage cue is a follow-up art pass.

- [ ] **Aluminium chain uses placeholder art (ci-txh).** The alumina item (calcite
  icon tinted white), the aluminium item (steel-plate icon tinted cool silver), and
  the electrolysis cell (reused vanilla electric-furnace sprite + icon) are v1
  placeholders. The chain itself (native stone+calcite → alumina → ruinous-power
  electrolysis → aluminium, the cell out-drawing the foundry, capacitor demand,
  gating, and a powered cell actually smelting) is fully integration-tested
  (`test_aluminium`). *Look for:* the two tinted icons read as distinct materials
  and the cell reads as its own building, not a stray electric furnace. Bespoke art
  is a filed follow-up, not a v1 bug.

- [ ] **Power buildings reuse vanilla-derived art (§15-9).** The solar panel,
  capacitor, molten-salt battery, and dissipator use the delivered first-pass
  Cindra sprites/icons (`graphics/ART-MANIFEST.md`, ci-pru): single static frames,
  no charge-lamp/working animation. Expected in v1 — bespoke animated art is a
  later pass. Do not file as a bug.
  *Note (ci-sop):* the capacitor + molten-salt battery were previously INVISIBLE
  in world — their art was assigned to a top-level `picture`, which the engine
  ignores for accumulators (art must live in `chargable_graphics.picture`). Now
  fixed and guarded by an automated data-stage audit (every custom Cindra entity
  must have a wired render sprite, else the mod fails to load; see
  `prototypes/graphics-audit.lua`). This playtest is now only the *visual read*
  (scale/shift/tint look right), not presence.

- [ ] **Environmental scanner reads well as a circuit hub (ci-3o3).** The
  standalone `env-scanner` mod adds a buildable **Environmental scanner** (a
  renamed constant combinator) that outputs surface signals (`env-daytime`,
  `env-daylight`, `env-solar`, `env-tick-of-day`, and, when a `cindra-flare`
  remote interface is present, `env-flare-countdown/phase/intensity`). Signal
  behaviour, recipe shape, and the flare-forecast path are integration-tested
  (`tests/test_scanner.lua`) and the pure maths unit-tested
  (`unit-tests/test_readings.lua`); only the *visual/UX read* is a playtest.
  *Look for:* the seven virtual signals appear in the signal picker under a
  clustered subgroup and read sensibly (icons are placeholder base icons -- a
  renamed combinator body and reused base signal icons; bespoke art is a
  follow-up bead, do not file as a bug); wiring the scanner's `env-daylight` /
  `env-flare-countdown` to a lamp or combinator visibly tracks the day and, on a
  Cindra save with the flare system loaded, acts as a REACTIVE early warning
  (ci-2ba): the flare signals are ABSENT during calm and only appear — countdown,
  phase, intensity — once a sporadic flare enters its warning window, since timing
  is no longer predictable by clock.

- [ ] **Sunward-position solar output has no visual band cue (ci-9ht).** Solar
  panels only really work on the sunny (sunward, +Y) part of the ribbon: a placed
  panel silently morphs to a reduced-output variant matching its Y, so nightward
  panels produce ~nothing and sunward panels produce full. *Repro:* build a row of
  plain vanilla `solar-panel` (Cindra uses the vanilla panel, ci-8al) spanning from
  deep nightward to deep sunward, then compare
  their contribution during a flare (e.g. watch a power graph, or the panels'
  tooltips). *Look for:* the sunward end carries the array and the nightward end is
  near-dead — placement toward the heat/danger is rewarded. All bands share ONE
  sprite, so there is currently NO in-game visual indicator of a panel's output
  band (a tint/lamp per band is a possible follow-up art/UX pass). The output
  gradient itself, the morph, flare composition, and the damage-model tie are all
  integration-tested (`tests/test_panel_solar.lua`); only the "which band am I in"
  visual read and overall balance *feel* are the playtest.
