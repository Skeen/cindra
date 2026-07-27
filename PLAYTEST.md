# Playtest checklist

Items pending in-game visual / interactive confirmation - the things
`factorio-test` **structurally cannot reach** (sprite appearance, day/night feel,
audio, UI, multiplayer). **Always prefer a test first** (see [`AGENTS.md`](AGENTS.md));
this list is the last resort when no test path exists.

## How to read this list

Every item is tagged so you know what to expect from the CURRENT `main`:

- **[LANDED]** - merged to `main`; you can playtest it today. The functionality
  is test-covered; the checkbox is for the *look/feel* a test cannot judge.
- **[IN-FLIGHT]** - designed and beaded, but NOT yet on `main`. Do **not** expect
  it in-game yet. Listed so you know it is coming and can tell "not built yet"
  apart from "built and broken." These are collected in
  [In-flight (not yet in-game)](#in-flight-not-yet-in-game) at the bottom.

Values called out below (route length, solar multiplier, dps, etc.) are the
CURRENT `(tune)` values on `main`; the balance pass (ci-63d) will move them.

## Reach & map view

- [ ] **[LANDED] Reach and stand on Cindra (smoke test).** *Repro:* `./play.sh`
  -> New Game with `cindra-dev-default` enabled (Any-Planet-Start lands on
  Cindra), or research `planet-discovery-cindra` from an existing save and travel
  from Vulcanus. *Look for:* the surface loads, the character spawns on buildable
  land, and you can place/mine entities. *Fallback:* the headless load +
  `test_planet.lua` already prove the prototype loads and the surface generates;
  this entry is only the interactive "it feels like a place you can stand"
  confirmation.

- [ ] **[LANDED] Map view / orbit reads as Cindra (ci-hmc).** *Repro:* open the
  star-map / navigate the orbital approach to Cindra. *Look for:* the planet is
  named **Cindra** with a description; it sits in a close orbit; `solar_power_in_space`
  is high (currently **2000**, i.e. far above Nauvis); "contains" reads **stone +
  ice**; the Vulcanus->Cindra space route shows the Cindra icon with a length
  (currently **80000**). The globe reads FIERY (radiant molten dayside) ->
  SANDY (a clearly lit warm terminator band down the middle, NOT black) -> ICY
  (dark blue-shimmer nightside); it does NOT rotate (tidally locked) while the
  terminator steam band and the flares off the fire limb animate in place. The
  baked star-map sprite split is verified off-game
  (`unit-tests/test_planet_maps.py`: centre ~RGB [139,108,61] sandy, fire limb
  ~[244,168,137], ice limb ~[40,57,77]); only the LIVE orbital backdrop is the
  playtest. *Note:* the display name currently still carries the
  "- The Ribbon World" suffix; dropping it to a bare "Cindra" is IN-FLIGHT (see
  below).

- [ ] **[LANDED] No day/night cycle (tidally locked).** *Repro:* stand on Cindra
  and watch the sky over several minutes without a flare. *Look for:* daylight
  does NOT free-run through a dawn/dusk cycle; the flare driver freezes daytime and
  only moves it during a flare event (see the flare item). It should read as a
  fixed, dark-weighted "always the same time of day" until a flare hits.

- [ ] **[LANDED] Discovery lore reads well in the tech GUI (ci-11b).** *Repro:*
  open the technology screen and hover/select the `planet-discovery-cindra` tech.
  *Look for:* the full §3 planet-discovery lore paragraph fits the tooltip/
  description panel and reads cleanly (no awkward truncation). The five standalone
  codex blurbs (`cindra-lore.*`) are keyed for a future codex reader and not yet
  surfaced in-game; their presence/shape are unit-tested
  (`unit-tests/test_locale.lua`), so this playtest is only the tech-tooltip read.

## Ribbon & terrain

- [ ] **[LANDED] Ribbon reads as a ribbon (§15-2/3).** The temperature axis is
  currently **vertical** (Y): the playable band runs long **east-west** and is
  constrained **north-south**, hot toward one Y edge, cold toward the other. The
  lethal-edge damage, hard-wall backstop, and resource bands are integration-tested
  (`test_edge_damage`, `test_worldgen`, `test_building_heat`). *Look for* the
  *feel*: the band reads long along X and narrow along Y; the `out-of-map` void
  beyond the wall reads as a clean boundary (not a jarring cliff); walking sunward
  visibly cooks and nightward visibly chills character HP (peak 200 dps at the
  lethal edge); pushing to the lethal margins for the richest stone/ice/volatiles
  feels like a deliberate, survivable-with-gear risk. (Axis *values* and
  *placement* are tested; *felt geometry* is the playtest.) *Note:* the themed
  terrain gradient, the LEFT->RIGHT (horizontal) default orientation, the
  impassable ice-mountain edge tile, world-gen size sliders, and the on-screen
  burning/freezing feedback are all part of worldgen v2 and are IN-FLIGHT (see
  below); on `main` the surface still uses Nauvis-base tiles with a void wall and
  NO screen-tint feedback.

- [ ] **[LANDED] Resources read as NATURAL PATCHES + map-gen sliders respond
  (ci-8nh).** Stone / ice / volatiles use NATIVE Factorio resource autoplace
  (spot-noise), band-masked to the ribbon axis. Placement, band constraint (stone
  on the ribbon + hot margin, ice nightward, volatiles deep cold-lethal),
  edge-pushing richness, and NO-water are integration-tested
  (`tests/test_worldgen.lua`, fixed seed). *Repro:* `./play.sh` onto Cindra.
  *Look for* the parts a test cannot: (1) stone/ice appear as IRREGULAR patches of
  varying size/richness (like Nauvis ore), NOT a repeating grid; (2) on the New
  Game map-gen Resources tab, `cindra-stone` / `cindra-ice` / `cindra-volatiles`
  Frequency/Size/Richness sliders exist and visibly change patch count/size/
  richness (these come free from native autoplace-controls; the ribbon-width /
  stone-density / ice-density sliders described in worldgen v2 are separate and
  IN-FLIGHT); (3) NO water tiles or starting lake at any water-slider setting;
  (4) volatiles patches actually appear out in the deep cold-lethal nightside
  (thin band, so presence is playtest-confirmed).

- [ ] **[LANDED] Nightside cold damage vs Aquilo freeze (feel).** Unheated
  machines past the cold threshold (axis temp < -30 °C default) take ticking cold
  damage rather than a reversible Aquilo-style freeze. *Look for:* the pace
  (default 20 dps) gives enough time to run a heat umbilical out before a machine
  dies, and reads as "drag heat with you," not "instant loss." If a reversible
  freeze feels better, that is a future refinement, not a v1 bug.

## Bootstrap from nothing

- [ ] **[LANDED] From-nothing bootstrap start works (ci-8nh / ci-fs4 / §6).**
  Cindra has NO ore or coal patches at all; the finite hand-mined bootstrap rocks
  are the ONLY landing metal and drop stone + iron ore + copper ore + coal (and a
  little tungsten). Yields and natural (off-lattice) scatter are prototype-tested
  (`tests/test_worldgen.lua`). *Repro:* start a fresh Cindra game with nothing,
  hand-mine the terminator rocks. *Look for:* the rocks are scattered naturally
  (NOT a repeating grid); enough stone to hand-craft stone furnaces AND enough
  iron/copper ore + coal to smelt a first trickle of plates and fuel, i.e. you can
  stand up the first foundry / power / ice-processing without a pre-existing ore
  patch, after which the infinite lava->metal economy takes over. If a from-nothing
  start soft-locks, that is a balance bug (coordinate with ci-arw / ci-uex).

- [ ] **[LANDED] Start-on-Cindra foundry bootstrap reads well (ci-arw).** The
  no-Vulcanus foundry path (finite bootstrap coal -> `cindra-crude-lubricant`,
  renewable `cindra-mineral-lubricant`, and the Cindra-buildable
  `cindra-field-foundry`, all under `cindra-improvised-metallurgy`) is fully
  logic-tested (`tests/test_foundry_bootstrap.lua`, `tests/test_aps_foundry.lua`).
  *Repro:* start on Cindra via any-planet-start. *Look for* the *felt* opening: the
  improvised-metallurgy recipes are visible/craftable from tick zero (the APS start
  pre-researches the tech), hand-mining a few rocks yields enough coal to
  crude-liquefy the lubricant for a first `cindra-field-foundry`, and building +
  running that foundry (lava -> molten metal) feels like a deliberate, non-tedious
  bootstrap rather than a soft-lock or a grind. Normal (post-Vulcanus) play imports
  finished foundries instead; those recipes reuse vanilla lubricant/foundry icons
  (v1 placeholder art), do not file that as a bug.

## Economy: lava, ice, aluminium

- [ ] **[LANDED] Ice processing two-stage read (§15-4, ci-4or).** *Repro:* build a
  `cindra-ice-crusher` and a `cindra-ice-melter`; run `Ice crushing (shards)` on
  the crusher, belt the crushed-ice to the melter, run `Ice melting (water)`, and
  pipe the melter's water out. *Look for:* the crusher is a clean solid-in/solid-out
  machine with NO pipe stub (it emits no fluid); the melter reuses vanilla
  chemical-plant art, so its pipe connections read as a chemical plant does.
  Confirm the chain reads as "grind, then melt" and the crusher never sprouts a
  water tap. (Both crush recipes, the no-fluid crusher, and the end-to-end ice ->
  shards -> water chain are integration-tested.)

- [ ] **[LANDED] Manufactured lava reads as a ruinous power sink (§15-5).** Lava is
  crafted in the **brought Vulcanus foundry** (metallurgy category) - there is NO
  dedicated lava-manufacturer building on `main`; power is the lever via the recipe's
  long craft time against the foundry draw. *Repro:* research `cindra-lava` (gated
  behind the foundry + Cindra discovery), feed a foundry stone + power, run the
  1 stone -> 5 lava recipe, and route lava on into the foundry chain for molten
  metal. *Look for:* the stone->lava->metal spine feels like "power is the lever"
  (a visibly heavy draw at scale), and productivity modules are allowed on the lava
  + aluminium recipes (ci-095). *Note:* the design intends to move lava to a few
  distinct HIGH-POWER lava-manufacturer buildings with their own tint; that is not
  yet built (foundry-only today).

- [ ] **[LANDED] Cryo-quench signature build + hot-pipe read (§15-6, ci-gd4).**
  *Repro:* research `cindra-cryo-quenching`, build a `cindra-cryo-quench`, pipe
  `lava` into its input fluid box and belt in `cindra-cryo-coolant`. *Look for:* it
  reads as a two-temperature forge (not a chemical plant), the hot-fluid input
  connects and drains, and `cindra-cryo-hardened-alloy` comes out on the item side;
  feed cold stock and nothing crafts. Recipe shape, temperature gate, category
  isolation, and the both-inputs-required craft are integration-tested
  (`tests/test_cryo_alloy.lua`). *Note:* the cryo-quench is still the landed
  signature building AND still the ingredient for Cindra science. Dropping it in
  favour of aluminium-as-signature is IN-FLIGHT (ci-wfv); until that lands, the
  quench is live and part of the science chain. Art is a v1 placeholder single
  frame (no craft-time "quench flash"); do not file that as a bug.

- [ ] **[LANDED] Aluminium chain, the power sink (ci-txh).** The signature material:
  native stone + calcite -> alumina -> aluminium (electrolysis cell, ruinous power,
  petrochemical-free), gated behind ONE tech (prereqs `cindra-lava` +
  `cindra-ice-processing`). *Repro:* research the aluminium tech, build the
  electrolysis cell, feed alumina + ruinous power. *Look for:* the cell reads as its
  own building (currently a reused electric-furnace sprite), out-draws the foundry
  on power, and leans hard on the grid/flare/capacitors; alumina and aluminium icons
  read as distinct materials (calcite tinted white / steel-plate tinted cool silver,
  v1 placeholders). The full chain, gating, cell power draw, and a powered cell
  smelting are integration-tested (`tests/test_aluminium.lua`). Aluminium is
  consumed by the flare **capacitor** (as its plates) and by the **mass driver**
  (pressed into the launch CAN and ground into the aluminium-powder SOLID ROCKET
  FUEL). *Note:* on `main` aluminium COEXISTS with the cryo-quench chain; the plan to
  make aluminium the sole signature (retiring cryo-quench, re-basing science) is
  IN-FLIGHT. Productivity is OFF on the electrolysis recipe (power stays the honest
  cost).

## Power (signature)

- [ ] **[LANDED] Flare reads as a telegraphed surge (§15-7, ci-9k6).** The flare
  cycle drives the frozen daylight curve calm -> warning -> fast ramp -> plateau ->
  fast decay, ~100x peak over a dim night floor. Schedule, ~100x swing, and
  non-100%-catchability are integration- + unit-tested (`test_flare`,
  `unit-tests/test_flare`, `test_catchability`). *Look for:* the sky visibly dims
  between flares and blazes at the peak. There is no engine telegraph/alarm/
  countdown UI yet (the `warning` phase is exposed in `flare.state` but not
  surfaced to the player); a sky-brightening cue + countdown alarm are a follow-up.
  Cadence magnitudes are (tune): the test-scale event is ~12 s; real play scales up.

- [ ] **[LANDED] Sporadic flare timing FEELS fair, not punishing (ci-2ba).** Flare
  *timing* is randomized (calm gap drawn from a band, mean = the old fixed cadence);
  event shape and ~100x magnitude are unchanged and every event is still
  telegraphed (all tested). *Look for (feel):* the randomness reads as
  "unpredictable but fair" - never starved for minutes nor hit back-to-back with no
  recovery time; the warning window is long enough to react per event; riding
  flares feels like a windfall you respond to, not a survival timer. Tune
  `CALM_MIN_TICKS` / `CALM_MAX_TICKS` (and warning length) if it feels starved,
  clustered, or un-reactable. Ties into the balance pass (ci-63d).

- [ ] **[LANDED] Panel damage reads as degrade-before-death (§15-8, ci-9ay).**
  Undisposed flare surplus degrades the most-sunward panels first (recoverable),
  then destroys them under a sustained deficit; adding a dissipator/storage heals
  them. Rule, edge-bias, self-correction, and dissipator-as-fuse are
  integration-tested (`test_panel_damage`, `test_disposal`). *Look for:* the
  health read of a panel array cooking sunward-first during an over-built flare,
  and recovering once disposal is added. Panels have no bespoke "overheating"
  visual yet (just the health bar); an emissive cue is a follow-up.

- [ ] **[LANDED] Sunward-position solar output, no visual band cue (ci-9ht,
  ci-8al).** Cindra uses the **vanilla** `solar-panel` (ci-8al). A placed panel
  silently morphs to a reduced-output variant matching its Y, so nightward panels
  produce ~nothing and sunward panels produce full. *Repro:* build a row of vanilla
  `solar-panel` spanning deep nightward to deep sunward, then compare their
  contribution during a flare (power graph or panel tooltips). *Look for:* the
  sunward end carries the array and the nightward end is near-dead (placement
  toward the heat/danger is rewarded). All bands share ONE sprite, so there is
  currently NO in-game indicator of a panel's output band (a per-band tint/lamp is
  a possible follow-up). Gradient, morph, flare composition, and the damage-model
  tie are integration-tested (`tests/test_panel_solar.lua`).

- [ ] **[LANDED] Storage two-tier + electric heater (§15-9/10, ci-tii, ci-f5l).**
  *Repro:* build a capacitor, a molten-salt battery, a dissipator, and a
  `cindra-electric-heater`; wire them into a flare-riding grid. *Look for:* the
  capacitor absorbs a fast spike, the molten-salt battery holds a cheap bulk
  plateau but **self-discharges when left idle** (a heat-upkeep leak, so it is not
  free long-term storage), the dissipator burns surplus as safe waste, and the heater draws power
  and warms the heat network to ~600 °C (no higher) with NO combustion flame (it
  reuses heating-tower art with the burner glow removed, so it reads electric, not
  a furnace). Prototype fields + runtime are tested (`test_heater.lua`,
  `test_storage`/`test_disposal`); the visual read + the leak *feel* are the
  playtest. Bespoke animated art for these is a later pass, not a bug.

- [ ] **[LANDED] Power buildings reuse first-pass Cindra art (§15-9, ci-sop).** The
  capacitor, molten-salt battery, and dissipator use delivered first-pass sprites
  (`graphics/ART-MANIFEST.md`, ci-pru): single static frames, no charge-lamp/working
  animation. *Look for:* scale/shift/tint look right and every building is actually
  VISIBLE in world (ci-sop fixed the capacitor + molten-salt battery, which were
  invisible because accumulator art must live in `chargable_graphics.picture`, not
  `picture`; a data-stage audit `prototypes/graphics-audit.lua` now fails the load
  if any custom Cindra entity lacks a wired sprite). This playtest is only the
  visual read, not presence.

## Mass driver (space export)

- [ ] **[LANDED] Mass driver: full launch -> hub delivery (ci-o39).** The mass
  driver is a reskinned `rocket-silo`, so launch + cross-surface delivery are the
  ENGINE's vanilla rocket path. Prototype shape is fully integration-tested
  (`tests/test_mass_driver.lua`: type=rocket-silo, cloned vanilla `rocket_entity`/
  cargo pod, `launch_to_space_platforms`, a can+fuel launch charge, a vanilla
  platform hub as the destination); end-to-end behaviour is the playtest. *Repro:*
  research `cindra-orbital-launch`, build a `cindra-mass-driver`, power it, feed it
  an aluminium can + solid rocket fuel, and load cargo (or request from a platform
  in orbit). *Look for:* the silo builds a launch charge (consuming the can + fuel
  + a large slug of power), the rocket rises, and cargo lands in the space
  platform's hub inventory, with NO catcher or bespoke platform-side building. If
  the cargo pod is rejected by the hub, that is a bug (the clone must keep the
  vanilla `rocket_entity`).

- [ ] **[LANDED] Mass driver + launch-chain art are placeholders (ci-o39).** The
  driver is a full deep-copy of the vanilla rocket-silo, so in world it wears the
  vanilla silo animation; only its inventory/tech ICON is the delivered mass-driver
  art (`graphics/icons/mass-driver.png`). The aluminium can (steel-plate tinted),
  aluminium powder (calcite tinted), and solid rocket fuel (rocket-fuel tinted) are
  v1 placeholder icons. *Look for:* the building reads acceptably as a launcher, its
  icon reads as the mass driver in the Space crafting tab, and the three chain icons
  read as distinct materials. A bespoke rail-gun/coilgun silo reskin is a later
  art pass, not a v1 bug.

## Science & circuits

- [ ] **[LANDED] Cindra science pack + starforge (§15-12, ci-3or).** *Repro:*
  research `cindra-science`, build a `cindra-starforge`, craft a pack, feed it to a
  lab. *Look for:* the pack reads as a distinct Cindra pack in the lab/tech GUI
  (currently the vanilla automation-science-pack icon tinted hot amber) and the
  starforge reads as a special building, not just another assembler (currently the
  assembling-machine-3 sprite). Functionality is fully test-covered
  (`tests/test_science.lua`), including a powered starforge that only progresses
  with power. *Note:* the pack recipe currently consumes the signature
  **cryo-hardened alloy** + deep-nightside volatiles + calcite (petrochemical-free).
  Re-basing the pack onto aluminium (retiring the alloy) is IN-FLIGHT; until then
  the alloy is a hard prerequisite for science.

- [ ] **[LANDED] Starforge power draw feels like a real sink (§15-12, feel).** The
  starforge draws ~10 MW active (a `(tune)` value). *Look for:* running an array
  visibly leans on the grid / flare capture ("research is a power sink") without
  being so punishing that early science stalls. Balance against the flare numbers
  and the balance pass (ci-63d).

- [ ] **[LANDED] Environmental scanner reads well as a circuit hub (ci-3o3).** The
  standalone `env-scanner` mod adds a buildable **Environmental scanner** (a renamed
  constant combinator, currently Hurricane radio-station art) that outputs surface
  signals (`env-daytime`, `env-daylight`, `env-solar`, `env-tick-of-day`, and, when
  a `cindra-flare` remote interface is present, `env-flare-countdown/phase/
  intensity`). Signal behaviour, recipe shape, and the flare-forecast path are
  integration-tested (`tests/test_scanner.lua`); the maths are unit-tested
  (`unit-tests/test_readings.lua`). *Look for:* the seven virtual signals appear in
  the picker under a clustered subgroup and read sensibly (placeholder icons; art is
  a follow-up, do not file); wiring `env-daylight` / `env-flare-countdown` to a lamp
  or combinator visibly tracks the day and, on a Cindra save with the flare system
  loaded, acts as a REACTIVE early warning (ci-2ba): the flare signals are ABSENT
  during calm and only appear (countdown, phase, intensity) once a sporadic flare
  enters its warning window.

## Placeholder art (expected in v1, do NOT file as bugs)

- [ ] **[LANDED] Resource art is placeholder.** Stone/ice/volatiles resources are
  cloned from vanilla `stone` (recoloured via `map_color`) and bootstrap rocks from
  vanilla `huge-rock`; the volatiles item reuses the vanilla ice icon. Bespoke
  Cindra resource art is a later pass.

- [ ] **[LANDED] Signature-building art is placeholder.** The cryo-quench, aluminium
  electrolysis cell, lava manufacturer, electric heater, starforge, and mass driver
  reuse vanilla-derived sprites/icons (see `graphics/ART-MANIFEST.md`). Bespoke and
  animated art is tracked across ci-z94, ci-eb9, ci-kuu, and ci-wfv. Do not file
  placeholder art as a gameplay bug.

## In-flight (not yet in-game)

These are DESIGNED and beaded but NOT on `main`. Do not expect them in a playtest
of the current build; they are listed so "not built yet" is distinguishable from
"built and broken." Re-tag them **[LANDED]** as their beads merge.

- [ ] **[IN-FLIGHT] Worldgen v2: themed terrain + orientation + size sliders
  (ci-i8a).** A configurable ribbon (default **vertical**, temperature axis
  **hot LEFT -> cold RIGHT**) with a smooth NOISY terrain gradient
  (hot-lava, lava, volcanic-cracks-hot/-warm/plain, volcanic-jagged-ground,
  dry-dirt, dirt-1, SAND at spawn, aquilo-dust, rough-ice, smooth-ice), an
  impassable ice-mountain edge tile, and new world-gen sliders (ribbon width,
  stone density, ice density; no Nauvis water/moisture/terrain sliders). *Status:*
  the prior attempt was rejected at the merge queue (it destructively reverted the
  aluminium feature); needs a clean redo. On `main` today the ribbon is a vertical
  (Y) temperature axis on Nauvis-base tiles with a void wall, NOT this gradient.
  Bespoke tiles are separately tracked in ci-70r.

- [ ] **[IN-FLIGHT] Burning/freezing screen feedback (ci-7tl).** Worldgen v2 ships a
  coloured GUI banner while a character takes environmental damage; the follow-up
  upgrades it to a full-screen warm/red (heat) and blue/frost (cold) tint/shader.
  *Status:* on `main` there is NO on-screen damage feedback at all (the banner rides
  in with ci-i8a). Damage still applies; you just will not see a screen cue yet.

- [ ] **[IN-FLIGHT] Aluminium becomes the sole signature; cryo-quench dropped
  (ci-wfv).** The design is pivoting so aluminium (electrolysis caster) is the
  signature building - modelled on Hurricane's arc/glass furnace (CC-BY) - and the
  cryo-quench / cryo-hardened-alloy chain is retired, with Cindra science re-based
  onto aluminium. *Status:* on `main` the cryo-quench is fully present and IS the
  science ingredient; aluminium coexists as a second chain. The building-art bead
  is parked pending the pivot bead and the asset. Until this lands, playtest the
  cryo-quench and the current (alloy-based) science pack as the live systems.

- [ ] **[IN-FLIGHT] Planet name drops the "- The Ribbon World" suffix.** The map/
  planet display name currently reads **"Cindra - The Ribbon World"**; the target is
  a bare **"Cindra"** (with the tagline kept as the description). Not yet changed on
  `main`.
