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

- [ ] **Resource art is placeholder.** Stone/ice/volatiles resources are cloned
  from vanilla `stone` (recoloured via `map_color`) and bootstrap rocks from the
  vanilla `huge-rock`; the volatiles item reuses the vanilla ice icon. Expected in
  v1 — bespoke Cindra resource art is a later pass. Do not file as a bug.

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
  (§15-14): the test-scale period is a flare every ~22 s; real play scales it up.

- [ ] **Panel damage reads as degrade-before-death (§15-8).** Undisposed flare
  surplus degrades the most-sunward panels first (recoverable), then destroys them
  under a sustained deficit; adding a dissipator/storage heals them. The rule,
  edge-bias, self-correction, and dissipator-as-fuse are integration-tested
  (`test_panel_damage`, `test_disposal`). *Look for:* the visual/health read of a
  panel array cooking sunward-first during an over-built flare, and recovering
  once disposal is added. Panels currently have no bespoke "overheating" visual
  (just the health bar); an emissive damage cue is a follow-up art pass.

- [ ] **Power buildings reuse vanilla-derived art (§15-9).** The solar panel,
  capacitor, molten-salt battery, and dissipator use the delivered first-pass
  Cindra sprites/icons (`graphics/ART-MANIFEST.md`, ci-pru): single static frames,
  no charge-lamp/working animation. Expected in v1 — bespoke animated art is a
  later pass. Do not file as a bug.

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
  Cindra save with the flare system loaded, counts down to the next flare.

- [ ] **Sunward-position solar output has no visual band cue (ci-9ht).** Solar
  panels only really work on the sunny (sunward, +Y) part of the ribbon: a placed
  panel silently morphs to a reduced-output variant matching its Y, so nightward
  panels produce ~nothing and sunward panels produce full. *Repro:* build a row of
  `cindra-solar-panel` spanning from deep nightward to deep sunward, then compare
  their contribution during a flare (e.g. watch a power graph, or the panels'
  tooltips). *Look for:* the sunward end carries the array and the nightward end is
  near-dead — placement toward the heat/danger is rewarded. All bands share ONE
  sprite, so there is currently NO in-game visual indicator of a panel's output
  band (a tint/lamp per band is a possible follow-up art/UX pass). The output
  gradient itself, the morph, flare composition, and the damage-model tie are all
  integration-tested (`tests/test_panel_solar.lua`); only the "which band am I in"
  visual read and overall balance *feel* are the playtest.
