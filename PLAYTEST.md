# Playtest checklist

The things `factorio-test` **structurally cannot reach**: sprite appearance,
look/feel, audio, UI wording, multiplayer. Everything here is already
test-covered for FUNCTION (each entry names the suite); what is open is the
JUDGEMENT a test cannot make. Always prefer a test first — see
[`AGENTS.md`](AGENTS.md).

This list describes the CURRENT `main`. Entries that have been confirmed or
superseded are deleted, not archived, so if it is written here it is still open.

**Two markers, so you know what has and has not been looked at:**

- **[UNSEEN]** — nobody has ever seen this render, in any engine. If something
  is visibly wrong, you are the first to know.
- **[SHOT]** — a headless in-engine render exists (`docs/verification/`, made
  under Xvfb + software GL). The geometry is confirmed; you are confirming it on
  a real client with a real GPU, in motion.

Numbers quoted below are the current `(tune)` values; the balance pass (ci-63d)
will move them. A number that feels wrong is tuning, not a v1 bug — say so and
move on.

## The route

Walk it in this order and you cross the whole planet once: **new-game screen →
approach from orbit → crash site → build a base in the habitable band → walk
sunward to the lava → walk back nightward to the ice → launch to orbit.** Two
judgement calls that are not pass/fail are collected in §7 — read those before
you start so you know to look.

---

## 0. Before you start — launch and the new-game screen

- [ ] **The playtest mod set loads clean (ci-7s3, ci-xor).**
  *Do:* `./play.sh` on an install logged into factorio.com (first run fetches
  any-planet-start + helmod into `.play-cache/`).
  *See:* no missing-dependency errors; the Mods screen lists **cindra,
  env-scanner, any-planet-start, cindra-start, cindra-dev-default, helmod** all
  enabled; **New Game** opens the Any-Planet-Start picker defaulted to
  **Cindra**; the Helmod button is in the toolbar.
  *Broken if:* any of those is missing or disabled, or the picker does not
  default to Cindra. (`tests/play-sh.test.sh` proves the mod-list wiring;
  `tests/test_env_scanner.lua` proves env-scanner loads.)

- [ ] **[UNSEEN] The map-gen screen carries the band-geometry controls (ci-i4z).**
  *Do:* New Game → Cindra → **Terrain** tab. Start once at defaults, then again
  with **Habitable band: Size 200%**, then once with **Hot zone: 200%**.
  *See:* three rows — **Habitable band**, **Hot zone**, **Cold zone** — grouped
  after the vanilla terrain entries, with no enable/disable checkbox; the map
  PREVIEW visibly redraws as you change Size (a wider dark ash band at 200%);
  in-game, 200% Habitable band is an obviously roomier build zone still centred
  on the landing spot, and 200% Hot zone puts the lava sea further sunward with
  more slope to cross. Chunk generation while exploring feels no slower.
  *Broken if:* a row is missing, the preview does not react, or the world
  generates identically at 200% (that is the ci-7k6 dead-knob failure returning).
  What the world actually generates is asserted in
  `tests/test_worldgen_sliders.lua`.
  *Judge:* each row's **Frequency** dropdown is deliberately inert (nothing on a
  fixed band for "how often" to mean) — decide whether that reads as broken. At
  400-600% the bands cannot all fit and the oceans sit on their minimum wall;
  check the extremes still read as a sane planet.

- [ ] **Resources + settings screens are clean (ci-3yl, ci-y19, ci-7k6).**
  *Do:* New Game → **Resources** tab with Cindra selected; then Settings → Mod
  settings → **Startup**.
  *See:* exactly two Cindra resource sliders, labelled plainly **Stone** and
  **Ice**, grouped at the bottom below Aquilo; no "Frozen volatiles"; no Nauvis
  water / moisture / terrain-type sliders on the Terrain tab. Startup shows nine
  Cindra settings, all in plain words: **Habitable band orientation** (a worded
  dropdown, not raw `vertical`/`horizontal`), **Peak edge damage per second**, and
  **seven per-zone width sliders** ordered hot→cold, from *Hot-lava ocean width*
  through *Habitable middle width* to *Ice ocean width*.
  *Broken if:* any label shows a raw key, or the word "Ribbon" appears where a
  functional name belongs. Three sliders that shaped **nothing** were deleted in
  ci-7k6 (`tests/test_settings_live.lua` now enumerates the settings LIVE and
  fails any knob with no proven consumer), so if you retune a setting, generate a
  world, and get the identical planet, that is a real bug — say which knob.
  *Note:* the Stone/Ice sliders really do move the ore
  (`tests/test_worldgen_resource_sliders.lua` measures it patch by patch, ci-y19).
  The gap this file used to list here is FIXED and landed: ice Frequency was inert
  above 0.5 (ice saturated the engine's spot ceiling at the default setting, so
  0.5/1/2/4/6 came out identical) until ci-l3k3 sized each resource's spot budget.
  The whole range is live now and the suite enumerates it, so identical worlds at
  two different Frequency settings IS a real bug again — say which knob. The new
  default density has its own feel check in §5.
  If you do crank the sliders, ore on lethal ground is its own check — see the
  patch-edge entry in §4 (ci-bgpm).

- [ ] **PlanetsLib co-install is harmless (ci-dza6, ci-ndm9).**
  *Do:* install **PlanetsLib** from the portal alongside Cindra and start a
  Cindra game; then load a Nauvis save.
  *See:* the game loads with no data-stage error, Cindra plays identically, and
  Nauvis/Vulcanus are unchanged.
  *Broken if:* the data stage crashes, or Cindra behaves differently with the
  library present. The dependency is optional (`? PlanetsLib`) and both the
  present and absent paths are proven in a real engine
  (`tests/test_planetslib_coload.lua`, `tests/test_planetslib_absent.lua`), so
  this is a thin check — but it is the first time a human runs the pair.

## 1. The approach — star-map and orbit

- [ ] **[SHOT] The globe reads fire → dark mountains → ice, and holds still.**
  This one entry replaces the whole from-space art chain (ci-i9m → ci-nyj →
  ci-2f7 → ci-pde → ci-6y9 → ci-lcv → ci-6i1 → ci-4qyj). The globe is now painted
  from the terrain module itself (`scripts/terrain_ramp.py` replays
  `terrain.lua`), so orbit and ground are meant to agree.
  *Do:* open the star-map, select Cindra, then navigate the orbital approach and
  WATCH the globe for ~30 s (`./play.sh`; `scripts/render-orbit.sh` for the
  headless version).
  *See:* a single sun from the LEFT; a blown-out near-white molten limb falling
  off hard through orange/red into a **broad band of dark basalt mountains**,
  then a pale blue-white **ICE** hemisphere; ONE soft terminator running
  vertically down the disc (~55% of the disc lit); the globe is **completely
  still** — no spin, no slow nod — with the terminator steam band the only
  motion; Cindra sits tight to the star, fully clear of the sun disc; the fiery
  side faces the star.
  *Broken if:* a **gray or tan sandy stripe** appears at the terminator (that is
  the ci-6i1 veto — see §7b); a second light boundary or pie-slice wedge where
  emission and shading disagree; a hard vertical seam; the cold side reads as
  Fulgora electric-blue on black or as a black void; the globe rotates or wobbles;
  the disc clips the sun; the icy side faces the star; any white/yellow plume
  streak at the bottom.
  *Covered:* `unit-tests/test_planet_maps.py`, `test_starmap_lighting.py`,
  `test_terrain_ramp_lockstep.py`, `unit-tests/test_space_appearance.lua`,
  `tests/test_space_appearance.lua`, `tests/test_planet.lua`. Shots:
  `docs/verification/ci-4qyj-orbital-three-part.png`,
  `ci-6i1-terminator-orbital.png`, `ci-lcv-orbital-light-axis.png`.
  Re-bake with `scripts/render-planet.sh` (which also regenerates `thumbnail.png`).

- [ ] **The planet panel and the route read right (ci-hmc, ci-2sr, ci-bu4, ci-06j, ci-11b).**
  *Do:* select Cindra on the star-map and read the panel; travel the
  Vulcanus→Cindra leg; open the mod manager; open the `planet-discovery-cindra`
  tech.
  *See:* named exactly **Cindra** with no tagline, a real description (molten
  dayside / frozen nightside / thin ribbon / sporadic flares); "contains" reads
  **stone + ice** with distinct icons; the route icon follows the vanilla
  convention (transfer arrows, Vulcanus badge top-left, Cindra globe
  bottom-right and in front, both badges the same size) and the leg is short;
  the asteroid field on the way reads hot Vulcanus/Gleba-tier, not dense
  Nauvis-tier; the **Day/night cycle** line reads as effectively none, not "5
  minutes"; the mod tile shows the planet globe, not the no-thumbnail
  placeholder; the discovery lore paragraph fits the tech tooltip without
  awkward truncation.
  *Broken if:* the ice patch wears a stone icon, Cindra appears twice in the
  route icon or oversized, the day/night line reads as a real cycle, or the lore
  is cut off mid-sentence.

## 2. The crash site

- [ ] **[UNSEEN] The bootstrap kit rides in the crashed ship (ci-8wu, ci-q6nh).**
  *Do:* start on Cindra via any-planet-start, let the cutscene finish, walk to
  the wreck and open it. Save and reload, open it again.
  *See:* exactly **1 foundry, 1 lava manufacturer, 3 solar panels, 2
  accumulators, 8 small electric poles** — and **no firearm magazines** (there is
  nothing to shoot here). NO extra chest anywhere near the landing site. The kit
  is present on the first open and is not duplicated after reload.
  *Broken if:* a chest capsule appears, the ship is empty, magazines are still
  aboard, the kit duplicates, or a kit arrives on a NON-Cindra start.
  *Judge:* it should feel like a genuine leg-up (power plus a first
  foundry+caster without the hand-craft grind), not a free base.
  *Covered:* `tests/test_aps_kit.lua` proves contents, the ammo strip, the
  five-slot fit and the no-extra-container guarantee; only the opening FLOW needs
  a real cargo-pod cutscene.

- [ ] **The from-nothing opening is playable, not a grind (ci-8nh, ci-arw).**
  *Do:* start fresh with nothing. Hand-mine the terminator rocks for stone +
  iron + copper, walk sunward to the volcanic rocks for **coal** (the only coal
  source), crude-liquefy the lubricant, and stand up a `cindra-field-foundry`.
  *See:* rocks scattered naturally (no repeating grid); enough metal and coal to
  reach the first foundry and a first trickle of plates; the
  improvised-metallurgy recipes craftable from tick zero.
  *Broken if:* you soft-lock — no reachable coal, or not enough stone to
  hand-craft a furnace. That is a balance bug (coordinate ci-arw / ci-uex).
  *Judge:* deliberate bootstrap vs. tedious grind.
  *Covered:* `tests/test_foundry_bootstrap.lua`, `tests/test_aps_foundry.lua`,
  `tests/test_worldgen.lua` (yields + off-lattice scatter).

- [ ] **[SHOT] The rocks and the deposits read as the right substance (ci-jvc, ci-9bb).**
  *Do:* while hand-mining, look at the scattered **rocks** on the terminator band,
  then find an **ice field** and a **stone patch** and open the map over them.
  *See:* the rocks are a warm golden-tan **STONE**, reading like Factorio
  stone/sandstone rather than the stock cool brown-grey rubble, and still legible
  against the dark ash ground rather than washed into it; rocks appear along the
  WHOLE band as you explore, not just around spawn. The **ice field** reads as
  ICY/frosted on the ground — a pale frost-blue patch, clearly not warm stone
  rubble and clearly not vanilla iron ore — with a pale cyan map colour distinct
  from iron's steel-blue. The stone deposit is labelled just **Stone**.
  *Broken if:* the ice field wears the iron-ore look or a stone map colour, any
  label reads "Cindra stone", or rocks only generate near spawn.
  *Judge:* does the warm tint feel like stone against live terrain and lighting?
  *Covered:* `unit-tests/test_rock_tint.lua` (a warm yellow multiply on every
  sprite variation), `tests/test_worldgen.lua` (the icy map colour distinct from
  both stone and iron; band-wide rock generation). Shot:
  `docs/verification/ci-jvc-rock-stone-tint.png`.

## 3. The habitable band — your base

- [ ] **[UNSEEN] The ambient thermal grade is invisible in the band (ci-nw0).**
  Replaced the old damage-triggered overlay. You will confirm the deepening in
  §4 and §5; here, confirm the NEUTRAL half.
  *Do:* stand at spawn and walk around the whole temperate middle.
  *See:* the screen is **completely untinted** — no wash at all, anywhere in the
  band.
  *Broken if:* there is any colour cast on safe ground, or the wash snaps on at a
  threshold rather than easing in as you leave.
  *Judge:* the two knobs are single constants at the top of
  `scripts/damage-feedback.lua` — max alpha **0.22** at the extreme, `GAMMA` 1.4
  for the ease-in. Too much? Too little? Arriving too late out of the band?
  *Covered:* `tests/test_feedback.lua` (neutrality, monotone deepening, cap,
  Cindra-only, damage-independent), `unit-tests/test_feedback.lua` (the curve).
  *Note:* still a flat white fill tinted at runtime; a soft-edged radial vignette
  is an art follow-up.

- [ ] **The flare reads as a telegraphed surge, and its timing feels fair (ci-9k6, ci-2ba).**
  *Do:* build a small solar grid and watch several full flare cycles.
  *See:* the sky visibly dims between flares and blazes at the peak
  (calm → warning → fast ramp → plateau → fast decay, ~100x over a dim night
  floor); the gaps are randomized around the old fixed cadence.
  *Broken if:* an event arrives with no visible ramp, or two land back to back
  with no recovery.
  *Judge:* "unpredictable but fair" — never starved for minutes, warning window
  long enough to react per event, riding a flare feels like a windfall rather
  than a survival timer. Tune `CALM_MIN_TICKS` / `CALM_MAX_TICKS`.
  *Note:* there is no engine telegraph/alarm/countdown UI yet — the `warning`
  phase exists in `flare.state` but is only surfaced through the environmental
  scanner. A sky cue + alarm is a follow-up.
  *Covered:* `test_flare`, `unit-tests/test_flare`, `test_catchability`.

- [ ] **[UNSEEN] Panels cook sunward-first, spark, and BREAK (ci-9ay, ci-snq, ci-clf, ci-sz8q).**
  ci-sz8q rewrote this: overload now follows the REAL surplus, the death is a
  proper death, and the effect art was redone.
  *Do:* build a sunward panel array with NO disposal (no dissipator, no battery),
  enable the driver and ride a real flare peak. Watch the health bars. Then let
  the sunmost panel burn all the way down. Then add a dissipator and ride another
  flare.
  *See:* (1) the most-sunward panels degrade first and the front advances inward;
  (2) the instant a panel is damaged, the vanilla **accumulator discharge glow**
  pulses over it — sitting ON the panel, one pulse per damage tick, self-clearing,
  reading as "too much power is moving through this"; (3) a panel that dies plays
  the destruction explosion, fires the break sound, and leaves a **solar-panel
  wreck on the ground**; (4) with enough disposal, panels take zero damage and
  show **nothing**; (5) a near-full buffer raises the alarm.
  *Broken if:* a dying panel simply pops out of existence mid-flare (the old
  bug); an accumulator BODY is drawn over the panel; re-tinted arc sparks or
  Fulgora-blue lightning instead of the discharge glow; a lingering artifact; a
  spared panel sparks anyway; damage without any surplus.
  *Judge:* is the pulse readable but not spammy at array scale?
  *Covered:* `tests/test_panel_damage.lua`, `test_panel_damage_runtime.lua`,
  `test_panel_overload.lua` (the remnant), `test_disposal.lua`,
  `unit-tests/test_panel_spark_graphics.lua`, `tests/test_power_prototypes.lua`,
  and the mod-wide `tests/test_power_conservation.lua`.

- [ ] **Sunward position pays, with no cue to tell you so (ci-9ht, ci-8al).**
  *Do:* build a row of vanilla `solar-panel` spanning deep nightward to deep
  sunward; compare their contribution during a flare (power graph or tooltips).
  *See:* the sunward end carries the array, the nightward end is near-dead.
  *Broken if:* output does not track position at all.
  *Judge:* all bands share ONE sprite, so there is currently **no in-game
  indicator** of a panel's output band. Does that read as a missing affordance
  worth a per-band tint/lamp follow-up?
  *Covered:* `tests/test_panel_solar.lua`.

- [ ] **[UNSEEN] The flare-storage kit shows what it is doing (ci-z94).**
  *Do:* build a bank of capacitors, a bank of molten-salt batteries and a couple
  of dissipators on one flare-riding grid. Stand back far enough to see all of
  them and watch a full cycle.
  *See:* (1) during the ramp you can tell which units are charging **without
  opening a GUI**, and during the calm which are giving power back; (2) the
  capacitor and the battery are clearly not the same machine — violet arc
  filaments crawling fast vs. a slow ember pool, and the capacitor's light snaps
  off after a surge while the battery's lingers (`charge_cooldown` 12 vs 90
  ticks); (3) the capacitor's dump **strobes** — a flash and an outward shock
  ring, not a steady glow; (4) the dissipator is dark and still with no surplus,
  fins running hot under a flare; (5) the shadow stays put for the whole cycle.
  *Broken if:* a black box over any body (the ci-036 additive-blend trap), a
  light hanging in the air beside a machine, a flicker or blank frame at the loop
  wrap.
  *Judge:* is a big bank too loud? Animation speeds and light intensities are in
  `prototypes/storage.lua`.
  *Covered:* `unit-tests/test_entity_anim.py` (frames move, cycles loop, no
  emission outside the silhouette, sheets byte-identical to the generator),
  `unit-tests/test_storage_graphics.lua` (grid matches the PNG, additive blend,
  body holds).

- [ ] **The storage tier and the electric heater behave (ci-tii, ci-f5l).**
  *Do:* wire a capacitor, a molten-salt battery, a dissipator and a
  `cindra-electric-heater` into the flare grid. Leave the battery idle a while.
  *See:* the capacitor absorbs a fast spike; the battery holds a cheap bulk
  plateau but **self-discharges when idle** (heat upkeep — not free long-term
  storage); the dissipator burns surplus as safe waste; the heater draws power
  and warms the heat network to ~600 °C and no higher, with **NO combustion
  flame** (it is heating-tower art with the burner glow removed, so it must read
  electric, not as a furnace).
  *Broken if:* a flame or ember glow appears on the heater, or the battery never
  leaks.
  *Judge:* does the idle leak feel like a fair cost or like a punishment?
  *Covered:* `tests/test_heater.lua`, `test_storage.lua`, `test_disposal.lua`.

- [ ] **The lava chain: one "Lava", calm machine, ruinous power (ci-e8a, ci-9yg, ci-72c4).**
  *Do:* research `cindra-lava`, build ~6 `cindra-lava-manufacturer`, feed stone +
  power, route lava into foundries. Open the fluid in a pipe/tank/factoriopedia.
  Run a red/green wire to a manufacturer.
  *See:* exactly **one "Lava"** everywhere — the recipe makes "Lava", the casts
  are vanilla "Molten iron"/"Molten copper", and there is no second lava and no
  "Manufactured lava" in factoriopedia, tooltips or filters; the running
  manufacturer's animation and working sound play at a **calm, normal rate**; the
  glass-furnace model sits vertically CENTRED in its 5x5 selection box; the
  circuit wire terminates at the **bottom-right corner**, not mid-right.
  *Broken if:* a second lava fluid exists; the animation flickers/blurs or the
  sound stutters; the model sits low or floats; the wire lands in the middle of
  the body.
  *Judge:* ~6 manufacturers visibly feeding one melting foundry at a heavy grid
  draw — an honest "power is the lever" cost, not an absurd machine wall.
  Productivity is deliberately DISABLED on the lava recipe (stone-negativity), so
  a module gives no bonus there.
  *Covered:* `tests/test_lava.lua` (machine count, fixed energy-per-lava,
  ruinous aggregate draw), `unit-tests/test_lava_graphics.lua` (the
  centred-body / bottom-right-wire windows; the pre-ci-72c4 values fail them).

- [ ] **The aluminium chain and the oxidizer read right (ci-txh, ci-a6z, ci-sz0k, ci-6vj).**
  *Do:* research the aluminium tech; run the leach in a chemical plant (acid +
  water); feed alumina + power to a `cindra-electrolysis-cell`; pipe the O2 out;
  run a red/green wire to it; hover it to see the selection box.
  *See:* the cell reads as its own bulbous riveted **oxidizer** vessel (not an
  electric furnace, not a placeholder, not a black box); the body animates
  (60-frame loop); the emissive layer glows green, especially in the dark; a
  ground shadow casts under it; the base sits ON the tiles; the selection box is
  a clean **4x4** framing the body; a real circuit-connector LED nub renders at
  the **bottom-right** and the wire attaches there; the O2 output pipe on the
  north edge connects and reads sensibly; alumina and aluminium icons read as
  distinct materials (white mineral pile vs. metal plate).
  *Broken if:* a **black square** where the body should be (the ci-036 palette-PNG
  trap — watch for this if the sheets are ever re-exported); an
  electric-furnace heater glow or pipe overlay leaking through; a 3x3 box with
  the body overhanging; the wire floating from centre-top; no connector sprite.
  *Judge:* `BODY_SCALE` 0.45 / `BODY_SHIFT` -6 px in `prototypes/aluminium.lua` —
  is the smidge right, and does the 700x500 shadow land under the 280x320 body?
  *Covered:* `unit-tests/test_aluminium_graphics.lua`, `tests/test_aluminium.lua`
  (full chain, gating, stone-negativity, 30-O2 byproduct, a powered cell
  electrolysing), plus the data-stage graphics audit.

- [ ] **The arc furnace and the red-mud items read right (ci-hs1j, ci-zdp, ci-1p1z).**
  *Do:* build a `cindra-arc-furnace`, pipe CO2 in, hover and click it, and look
  at red mud + slag in the inventory.
  *See:* the animated arc-furnace body with its molten glow at a sane scale, soft
  shadow grounded, no blink-out on trailing frames; the whole visible body is
  clickable — the selection highlight frames the full **5x5** model; the
  circuit-wire attach point is unchanged (bottom/centre); CO2 still pipes in; the
  recipe still reads red mud + CO2 → iron + slag; red mud reads as a rusty-red
  residue and slag as a dark inert clinker, distinct from each other and from
  stone.
  *Broken if:* an un-selectable outer ring, an assembling-machine-3 or old
  carbothermic icon, or a CO2 pipe that no longer connects.
  *Judge:* collision stays **3x3** deliberately (a 5x5 collision would bury the
  north CO2 pipe), so belts and machines CAN be built in the 1-tile ring under the
  model's painted edge. If that overlap reads badly, it is a follow-up that must
  also move the pipe connections outward.
  *Covered:* `tests/test_red_mud.lua`, `unit-tests/test_red_mud.lua`.

- [ ] **[SHOT] The environmental scanner reads as a circuit hub (ci-3o3, ci-0e8, ci-kuu, ci-6jz).**
  *Do:* build an **Environmental scanner** (craftable from the start), press **R**
  over it, drag red and green wires onto it, open the signal picker, and wire
  `env-daylight` and `env-flare-countdown` to a lamp.
  *See:* the radio-station building — a 2x2 body FILLING its box with its base
  planted on the ground, shadow pooled under the legs; a gentle ~1.3 s idle
  animation; the emissive openings glowing at night; **R does nothing** (the body
  is identical from every side); wires attaching at the **front base**, flanking
  the legs (red left, green right); the seven signals under a clustered subgroup
  with **bespoke** glyphs — warm-sun family for the surface readings, ember/flare
  family for the forecast block — each readable at picker size and at ~16px in a
  combinator. Wired to a lamp, daylight tracks the day, and on Cindra the flare
  signals are **ABSENT during calm** and appear only once a flare enters its
  warning window.
  *Broken if:* a solid **black box** (the ci-ijk regression — the emission strip
  is fully opaque and needs `blend_mode = "additive"`); a floating body or
  detached shadow; a wire endpoint mid-structure; any signal showing a stray
  vanilla item icon; flare signals present during calm.
  *Judge:* the shadow shift `(2, -18)` and the wire-point offsets in
  `mods/env-scanner/prototypes/scanner.lua`; and whether flare-countdown stays
  distinguishable from flare-intensity despite the shared flare motif.
  *Covered:* `mods/env-scanner/tests/test_scanner.lua`,
  `mods/env-scanner/unit-tests/test_scanner_graphics.lua` +
  `test_readings.lua`, `mods/cindra/tests/test_env_scanner.lua`. Run the
  scanner's own suite with `--mod-path mods/env-scanner` — `cindra-test` skips it.

- [ ] **The Cindra science pack, and its planet lock in the GUI (ci-3or, ci-gk4u).**
  *Do:* research `cindra-science`. On **Nauvis or Vulcanus**, open an assembling
  machine's recipe picker and find the Cindra pack. Then do the same on Cindra,
  craft one, and feed it to a lab.
  *See:* off Cindra the pack is greyed and unselectable with the engine's "cannot
  be crafted on this surface" tooltip **naming the solar-power requirement** —
  exactly the way metallurgic science reads off Vulcanus. On Cindra it is
  selectable and crafts normally, and the pack reads as a distinct Cindra pack in
  the lab and tech GUI (currently the automation-pack icon tinted hot amber).
  *Broken if:* the pack is silently absent off Cindra rather than greyed with a
  reason, or the tooltip is generic/empty.
  *Covered:* `tests/test_science.lua` — a player carrying every ingredient is
  refused off Cindra and served on Cindra, with a vanilla surface-locked pack as
  the control, plus a live guard that no other planet or platform satisfies the
  gate. Only the picker's TOOLTIP WORDING is unreachable from a test.

- [ ] **The petrochemical icons read as distinct materials (ci-6vj S6).**
  *Do:* research materials-chemistry + aluminium and open the recipe/crafting
  menus; inspect the new fluids in pipes.
  *See:* twelve bespoke icons where tinted-vanilla placeholders used to be —
  molecule renders for **hydrogen, oxygen, carbon dioxide, methanol**; dedicated
  item renders for **quicklime, alumina** (white mineral), **aluminium** (plate),
  **nano-aluminium powder** (metal dust), and the two catalyst pairs with their
  greyed **spent** forms. The fluids stay colour-distinct in pipes, each spent
  catalyst reads visibly duller than its live form, and the materials-chemistry
  tech icon reads as methanol.
  *Broken if:* a reused petroleum-gas cloud, a tinted calcite, or a tinted
  copper-plate shows up anywhere; a spent catalyst is indistinguishable from its
  live form.
  *Covered:* `unit-tests/test_materials_graphics.lua` (wiring, PNGs ship, RGBA,
  no placeholder).

- [ ] **Mixed ice: the sort puzzle and the early surplus (ci-9l6).**
  *Do:* drop an electric mining drill on an ice field and belt its output. Split
  the ice + calcite apart, melt the ice in a chemical plant (`Ice melting`) for
  water, and let the calcite side back up with no sink.
  *See:* the field tooltip says it drops both, both ride out on the belt, and
  when the calcite belt fills the drill **stalls and chokes the ice too** (the
  intended Fulgora-scrap puzzle).
  *Broken if:* the mix does not read at all, or the early surplus **permanently
  deadlocks** the base with no buffer or lossy vent available.
  *Judge:* does the 2:1 ratio feel right — plenty of ice for water/science/fuel,
  a steady minor calcite stream? Is "burden early, resource later" fun or
  frustrating? If no acceptable early voiding path exists in practice, file a
  follow-up for a lossy calcite/ice voider.

- [ ] **[UNSEEN] The power diode: three things the headless shutter cannot reach (ci-gcd, ci-8l4, ci-qj5k, ci-ntgh).**
  Editor-spawn only — it has no recipe or tech yet. `scripts/render-diode.sh`
  already confirms in-engine that the model is pixel-identical to a vanilla power
  switch with nothing stray around it, but that renderer draws no STATUS icons
  and no water reflections.
  *Do:* in the editor, place ONE **Power diode** (a pale-blue power switch).
  Then: (a) wire ONLY its source side to a network that cannot supply it (poles,
  no generation); (b) **hold a power pole in hand** next to it; (c) place one
  **beside water**.
  *See:* nothing but the switch, in all three cases — and, wired to a powered
  source and a loaded sink, power flowing source→sink and never back, with the
  switch staying visually OPEN and un-toggleable.
  *Broken if:* (a) a "no power" / "no network" warning symbol floats in open
  ground ~3 tiles to either side (the reported symptom — the hidden buffers now
  opt out of both icons, but confirm it on screen); (b) stray supply-area overlay
  patches appear either side; (c) a power-pole reflection appears on the water.
  Also broken: stray batteries/accumulators/poles, or floating copper wire
  between the switch and its hidden taps.
  *Covered:* `tests/test_power_diode.lua`, `unit-tests/test_diode.lua`,
  `unit-tests/test_power_diode_graphics.lua`, `tests/test_power_conservation.lua`.

## 4. Sunward — the hot side

- [ ] **The walk west: ash → slope → glowing crust → lava ocean (ci-wly, ci-oe83).**
  *Do:* walk WEST from spawn all the way to the void, then back.
  *See:* dark/pale **ash** middle with small soil patches → cool cracked or
  folded volcanic rock → glowing hot cracks and warm stone → **lava pools and
  fingers** → a **solid hot-lava OCEAN** (~200 tiles, no gaps or holes) → the
  void. The ocean is **contour-continuous** with the ground in front of it — the
  field ramps INTO it, with no stamped-on-top cut-off at the shore. Boundaries
  are organic wavy curves, never straight stripes. The warm orange screen grade
  deepens continuously the further you commit (ci-nw0), a clear mood colour at the
  lava shore but still a grade, not a blackout — terrain, entities and GUI stay
  readable. Lava tiles are impassable (the one hard wall).
  *Broken if:* a **high-ground path lets you walk right up to the lava taking
  zero damage** (the old ci-oe83 bug — you must always cross a damaging belt
  first); holes in the ocean; a visible stamped edge; a straight-line boundary;
  the safe middle pinching into a pocket ringed by lava.
  *Screenshot this one for the mayor.*
  *Covered:* `tests/test_worldgen.lua`, `tests/test_heightmap.lua` (driving the
  real damage sweep), `tests/test_paving.lua`.

- [ ] **[UNSEEN] The hot slope carries TWO texture families (ci-72bw).**
  A low-frequency noise picks, per region, between a folded/pumice run
  (`folds-warm → folds → folds-flat → ash-cracks → pumice-stones`) and the
  main-line cracked run (`cracks-warm → cracks → smooth-stone`). Both converge on
  `ash-dark` at the middle.
  *Do:* walk NORTH–SOUTH **along** the hot slope (roughly x −130..−72 on the
  default vertical ribbon), and open the map over that band.
  *See:* **broad patches** (~90 tiles across) that are clearly folded/pumice
  alternating with clearly cracked ones; where two meet they **interpenetrate**
  for a few tiles; both fade into the same dark ash as you walk inward; the
  glowing `cracks-hot` crust above the slope is unchanged in both kinds of
  region; on the map the slope still reads as ONE continuous hot→cold ramp.
  *Broken if:* a per-tile salt-and-pepper mix of both families; a straight seam
  where patches meet; a visible family boundary in the middle; the folds tiles
  standing out on the map as a differently-coloured band.
  *Judge:* do the two families read as distinct TERRAIN, or just as noise? No
  test can answer that.
  *Covered:* `tests/test_worldgen.lua` (both generate, converge, stay on the
  slope, carry no damage).

- [ ] **[LANDED] Cosmetic cross-region scatter — kill the 3-band look (ci-frcw).**
  An occasional patch now paints a tile a band or two away from its own: cool
  volcanic ground (`smooth-stone` / `cracks`) out in the ash middle, `dust` mixed
  in among the ash, ash bleeding out onto the slopes. It moves only the value the
  TILE is chosen from, never the field the damage and resources read, and is
  windowed shut short of both damage thresholds.
  *Do:* `./play.sh` onto Cindra, walk WEST and EAST from spawn across the middle,
  then open the map view over the whole ribbon.
  *See:* (1) the middle reads as **ash with patches of other ground in it**, not
  as a uniform ash stripe — but still unmistakably as the ash middle, not as mush;
  (2) the patches are **patches** (roughly 30-ish tiles across), not per-tile
  salt-and-pepper speckle; (3) the hot/middle and middle/cold transitions no
  longer read as a line at all — the tiles interleave across them; (4) NOTHING
  glowing and no sea in the middle: no `cracks-hot` glow, no lava, no smooth/rough
  ice — the scattered volcanic ground is the dull cool kind; (5) in the map view
  the ribbon still reads as one hot→cold ramp, with no visible speckle noise on
  the map colours; (6) the hot slope's folds/cracks families (ci-72bw, above)
  still read as broad families, now with ash mixed into them, rather than being
  drowned by the mixing.
  *Expected, not a bug:* pale **snow** patches in the middle — the scattered
  `dust-*` tiles carry Aquilo's `frozen_variant`, so on frozen ground the engine
  swaps them to plain `snow-*`. Judge whether that reads as frosted dust or as a
  mistake.
  *Covered:* that it really scatters, that nothing damaging leaks into the safe
  corridor, and that standing on a scattered patch does nothing are all
  integration-tested (`tests/test_worldgen.lua`, `tests/test_heightmap.lua`); only
  the *look* is the playtest.

- [ ] **[UNSEEN] Litter sits on the slope and the crust, never on lava (ci-mk5y).**
  *Do:* walk west from spawn across the brown middle, onto the cracked/folded
  slope, and on to the lava shore.
  *See:* the brown ash middle carries **NO rocks or craters** — volcanic litter
  starts only once the ground turns cracked/folded; the litter continues over the
  glowing hot crust so the burning shore is not bare; the lava itself is **CLEAN**
  — nothing floats on the molten surface and nothing is cut in half at the
  shoreline; both transitions thin out along a wobbly contour.
  *Broken if:* a rock or crater on molten ground, a half-cut decal at the shore,
  litter strewn across the middle, or a straight stamped edge.
  *Judge:* if the slope now reads too sparse, tune the biases in
  `scripts/decorative-field.lua`.
  *Covered:* `tests/test_decoratives.lua` (every rock/crater inside the slope
  band on solid ground, zero on molten tiles, crust still gets its share),
  `unit-tests/test_decorative_field.lua`.

- [ ] **[UNSEEN] Volcanic rocks GLOW where the ground burns (ci-w87).**
  *Do:* walk west across the hot slope and on into the heat-damage band (the
  glowing-cracks ground), watching the boulders as you cross.
  *See:* plain charred rock on the safe slope; the same boulders with a live
  **emissive glow** once the ground starts burning — so a glowing rock is a
  warning that the ground under it hurts; the change happens exactly where the
  TILES change; both sizes appear in both models.
  *Broken if:* a stripe of glowing rocks on cool ground, or plain rocks sitting
  on burning ground.
  *Judge:* does the glow actually read, in daylight and in the dark?
  *Covered:* `tests/test_worldgen.lua` proves on the live surface that every
  rock's model matches its side of the lava edge.

- [ ] **The lava is scenery, not a well — and the refusal must read (ci-8vu).**
  *Do:* walk to the hot ocean shore, put an **offshore pump** in the cursor, and
  aim it at the lava.
  *See:* the lava still looks molten and still burns and blocks exactly as
  before; you get **no lava out of the pump** (lava is manufactured from stone).
  *Broken if:* the pump produces lava.
  *Judge — this is what the entry is here for:* does the game refuse the
  placement outright (red build preview), or does the pump PLACE and then sit
  idle forever with no hint why? If it places and idles, that reads as a bug to a
  player — **file a follow-up** for build-time feedback (a refusal, or a
  flying-text "Cindra's lava cannot be pumped — melt stone instead").
  *Covered:* `tests/test_lava_tap.lua` (a pump on natural Cindra lava draws zero
  while the same pump on vanilla lava fills; no Cindra tile declares a fluid;
  shared vanilla tiles keep theirs).

- [ ] **[UNSEEN] Patch edges where the ore meets lethal ground (ci-bgpm).**
  Stone and ice patches may no longer generate on ANY tile that damages you (an
  autoplace tile restriction to the damage-free tiles), because the glowing crust
  and freezing snow really do bleed ~20 tiles inside the nominal safe side — 16
  stone tiles per measured strip were landing on burning crust at maxed sliders,
  which is ore you cannot take, since you mine a patch by standing on it. The
  bands keep their full width; what no test can judge is whether the resulting
  patch OUTLINE still reads natural.
  *Do:* walk sunward along the hot outer slope until stone patches sit beside
  glowing `volcanic-cracks-hot` crust (perp ~110-120, x ≈ −110..−120 on the
  default vertical ribbon). Repeat on the icy side (§5) where ice patches meet the
  snow. Worth a second pass with every Stone/Ice slider at 6, where patches are
  fattest and press hardest against the lethal ground.
  *See:* the ore stopping AT the crust or snow with a **ragged organic edge**.
  *Broken if:* a straight cut where the ore stops; a patch full of one-tile holes;
  any patch reduced to isolated specks.
  *Covered:* `tests/test_worldgen_field_ground.lua` reads the ground under every
  single ore tile with all sliders at 6, plus a no-retreat guard (the ore must
  still reach within 15 tiles of lethal ground, so a fix that pulled the bands
  inland fails too) and a live coverage guard over the `resource` prototypes.
  *Note:* the ice-ROCKS had the identical leak; that is FIXED and landed too
  (ci-pxlz gave them the same tile gate), so a rock standing in burning or
  freezing ground is now a real find worth filing. Its own look check is in §5.

- [ ] **The lethal bands burn you and your machines, and read on the map (ci-4h7, ci-qqt, ci-ma18).**
  *Do:* walk into the hot damage band and build a machine there. Then open the
  map (M) and chart out to BOTH edges.
  *See:* your HP drains and the machine takes damage too, scaling with how deep
  you are (hot-lava hottest, warm cracks mildest) and reading as a smooth danger
  band rather than a per-tile flicker; concrete and stone-path **revert** on lava,
  warm stone, hot cracks and ice, so you cannot pave the hazard away. On the map,
  the sunward half is a clear **red→hot-orange** band deepening toward the lava,
  the nightward half a **pale-ice→bright-cyan** band toward the deep ice, and the
  safe centre a neutral tone — so the safe↔danger boundary is legible as a colour
  change at every zoom, following the wavy band boundaries automatically.
  *Broken if:* the tint is a muddy blur, paving neutralises a hazard tile, or any
  **cliff** walls off a lane on the thin ribbon (`tests/test_worldgen.lua` asserts
  zero cliffs — a bespoke thin-ribbon cliff is future work under ci-70r).
  *Screenshot the map view for the mayor.*
  *Covered:* `tests/test_tile_damage.lua`, `tests/test_worldgen.lua`,
  `unit-tests/test_terrain.lua`, `tests/test_paving.lua`.

## 5. Nightward — the cold side

- [ ] **The walk east: dust → snow → rough ice → a frozen sea (ci-wly, ci-oe83).**
  *Do:* walk EAST from spawn to the void, then run out **onto** the smooth ice.
  *See:* ash middle → cool **dust** (frosted → lumpy → crested → flat) → **snow**
  rings → **rough ice** → a solid **smooth-ice OCEAN** → the void, contour-
  continuous the whole way. The ice is **WALKABLE** (the old impassable ice wall
  is gone) — you step onto it and it freezes you, damage scaling with depth, so a
  dash across is survivable briefly with mitigation. The cool blue grade deepens
  as you commit.
  *Broken if:* the ice blocks you like lava; you can reach the ocean without
  crossing a damaging belt first; a stamped edge at the shore.
  *Covered:* `tests/test_heightmap.lua`, `tests/test_tile_damage.lua`,
  `tests/test_paving.lua`.

- [ ] **[SHOT] The cold half is legible — and the ice ocean reads as an OCEAN (ci-tizx, ci-10ze).**
  Two human reports fixed in sequence: the decal scatter buried the ground, and
  then the open sheet was still too cluttered to read as a sea.
  *Do:* walk east from spawn across the brown dust band, into the frost belt, and
  on out onto the frozen sea (or `scripts/render-mapgen.sh`).
  *See:* (1) the brown dust band carries **NO snow or ice decals at all** — just
  ground and the odd ice-rock; (2) frost thickens **gradually** as you cross into
  the snow tiles, with no stamped line where it starts; (3) the open sheet reads
  as **one flat expanse of ice — a SEA** — with the odd drift for scale, while
  the frost shore just inside it keeps its detail so the sheet reads smooth BY
  CONTRAST; (4) no stamped line where the offshore thinning starts.
  *Broken if:* decals carpet the brown band again, or the open sheet reads as a
  field of snow lumps.
  *Judge:* the sheet must not read EMPTY either. If it feels dead, raise
  `OCEAN_DENSITY`; if it still reads as ground, lower it (with `OCEAN_FADE_SPAN`,
  in `scripts/decorative-field.lua`).
  *Covered:* `unit-tests/test_decorative_field.lua`, `unit-tests/test_terrain.lua`,
  `tests/test_decoratives.lua` (habitable band decal-free, the fade ramps, the
  open sheet carries a small fraction of the shore's coverage). Shots:
  `docs/verification/ci-tizx-cold-decal-density.png`,
  `ci-10ze-ice-ocean-decals.png`.

- [ ] **[UNSEEN] It SNOWS on the icy side, and nowhere else (ci-mk5y).**
  v1 flake art is the stock white square, tinted and scaled small — no bespoke
  asset yet.
  *Do:* walk east across the dust band into the frost belt, **stop right at the
  boundary**, then walk on out to the ice ocean. Then walk west to the lava to
  confirm it is dry there.
  *See:* gentle falling SNOW — fine flakes drifting down with a little sideways
  wind; standing at the boundary, snow falls on your **nightward side only**, the
  brown band beside you staying clear, and the edge is not a hard curtain; flakes
  read in front of buildings without hiding alerts or icons; no stutter with the
  field up (at most 48 sprites every 3 ticks per player).
  *Broken if:* it reads as dots or as rain; snow falls on the habitable band, the
  hot side, or another planet; a hard curtain at the boundary; alert icons hidden.
  *Judge:* density and speed against the frozen ground — tune `FLAKES` /
  `FALL_SPEED` / `DRIFT` / `SCALE_*` / `ALPHA_*` in `scripts/snowfall.lua`. If the
  square reads badly at high zoom, file the bespoke-flake art follow-up.
  *Covered:* `tests/test_snowfall.lua` proves against a live player that it snows
  on the ice and nowhere else, that at the boundary every visible flake is over
  icy ground, and that flakes actually fall.

- [ ] **[UNSEEN] Cold rocks read as ICE, not tinted boulders (ci-18n, ci-w87).**
  *Do:* explore the cold side east of the terminator, before the lethal cap, and
  mine an ice-rock.
  *See:* faceted, translucent **ice formations** (Aquilo's `lithium-iceberg`
  big/huge models, drawn as authored) with the medium/small/tiny members of the
  same family scattered around them as chips and grit, so the icy ground reads as
  one substance from grit to landmark; they sit sensibly on the cold-dust and
  rough-ice ground; mining gives an early **ice + stone** trickle.
  *Broken if:* a recoloured brown boulder — that is the ci-18n blue-multiply-tint
  the playtest already rejected once.
  *Covered:* `unit-tests/test_rock_models.lua` + a data-stage guard (sprites are
  invisible to the runtime API, so this cannot be a factorio-test);
  `tests/test_worldgen.lua` proves both sizes generate only in the safe cold band
  and yield ice + stone.

- [ ] **[LANDED] Nightside ice density FEELS right after the spot-budget fix (ci-l3k3).**
  *Do:* new game on Cindra at DEFAULT map-gen sliders; walk/drive the cold side of
  the ribbon and look at the ice fields, then start a new game with Ice
  **Frequency** at 4 and again at 6.
  *See:* at default, ice fields are a reliable but still worth-travelling-for find
  on the nightside — roughly 1.7x the ore the pre-fix world had, which should read
  as "the cold side is worth a rail line", NOT as "ice is everywhere and the
  nightside logistics puzzle is trivial". At Frequency 4 and 6 the cold side should
  visibly fill with MORE separate patches (not fatter ones), and the two settings
  should look clearly different from each other and from the default.
  *Covered:* `tests/test_worldgen_resource_sliders.lua` proves the counts move and
  that the whole slider range is live; only the BALANCE FEEL of the new default
  density and the crowding at maximum Frequency need eyes on them.

- [ ] **[LANDED] The ice-rock band's outer edge still reads as populated after the
  damage gate (ci-pxlz).**
  *Do:* walk out to the coldest end of the ice-rock scatter, right up against the
  lethal deep-ice cap, and look back along the band.
  *See:* the outermost stretch still reads as a scatter you would walk out for,
  with no visible "combed" line where rocks stop and the icy ground goes bare — the
  tile gate removes rocks tile by tile on bled snow rather than cutting the band
  back, so the thinning should be invisible.
  *Covered:* the numbers are done — `tests/test_worldgen_rock_ground.lua` measures
  579 → 574 rocks (0.9%) with the scatter still reaching within 0.44 tiles of the
  lethal boundary, and pins both the reach and the population against a future
  retreat. Whether a 0.9% trim concentrated on one tile family is *perceptible* as
  patchiness is a look judgement no test can make.

- [ ] **[UNSEEN] Machines FROST and stop past the freeze onset (ci-bvk, ci-z7nu, ci-6qyk).**
  ci-6qyk is the fresh part: the glass furnace was **accidentally immune** to the
  planet's core freeze (its `heating_energy` had been cleared to shed the
  foundry's Aquilo power cost — not knowing the engine uses that same field as the
  freeze switch). It now carries a **100 kW** heating draw like its siblings, so
  its `frozen_patch` renders for the first time ever.
  *Do:* build a machine, a pipe, an **oxidizer** (electrolysis cell) and a
  **glass furnace** (lava manufacturer) in the thawed band. Walk them nightward
  past the onset (~one screen east of spawn) and leave them a while. Then run a
  heat line back out to them.
  *See:* machines past the onset grow **frost** and STOP (the vanilla frozen
  animation), pipes and fluids freeze natively; the oxidizer wears the
  electric-furnace frost sprite and the glass furnace the foundry frost sprite,
  each **centred on its body**, reading as frost rather than floating off or badly
  clipped; the freeze ONSET reads as a clean line where the ice-side gradient
  begins, not a fuzzy fade; an electric heater thaws a visible pocket and the
  machines resume.
  *Broken if:* the glass furnace keeps running in the dark with no heat (the
  ci-6qyk regression), or any machine freezes with no frost at all.
  *Judge:* (a) the frost's scale/shift on the bulbous oxidizer and the tall
  glass-furnace body — a nudge there is cosmetic, not a v1 bug; (b) whether the
  heat infrastructure a nightside lava chain now demands is a fair tax rather than
  a wall that makes nightside glass production pointless. 100 kW beside the
  machine's 40 MW crafting draw is a deliberate cut from the vanilla foundry's
  300 kW, and the mayor called it a starting point, not a locked constant.
  *Covered:* `tests/test_freeze.lua`, `tests/test_frost.lua` (the ci-6qyk
  class-wide guard: every Cindra machine freezes in the dark and thaws beside
  heat), `unit-tests/test_aluminium_graphics.lua`,
  `unit-tests/test_lava_graphics.lua`.

- [ ] **[UNSEEN] The arc furnace's created frost layer (ci-u92y).**
  Hurricane046's set ships no frozen layer and the riveted vessel looks nothing
  like the assembling-machine-3 it clones, so unlike the two above there was no
  vanilla frost sprite to borrow — the layer was **created**
  (`scripts/gen-frost-layer.py` derives it from the furnace's own frozen frame:
  rime on the up-facing domes, rims and ledges; bare metal on the down-faces).
  Nothing headless can see how it reads.
  *Do:* build an arc furnace in the thawed band, walk it nightward past the
  onset, and leave it to freeze.
  *See:* a pale ice crust following the vessel's domes and rims, matching the
  other frozen buildings; the crust sitting **ON** the body — no ice floating off
  the silhouette, no visible offset; the machine still reading as an arc furnace
  through the ice rather than as a white blob; the arc animation **halted on frame
  0** so it reads as stopped.
  *Broken if:* ice off the silhouette, or a white blob.
  *Judge:* **see §7a — the emissive glow question.**
  *Covered:* `unit-tests/test_frost_layer.py` (geometry, colour, coverage,
  silhouette masking, byte-determinism), `unit-tests/test_red_mud.lua` (wiring),
  plus the data-stage audit `prototypes/frost-audit.lua`, which fails the LOAD if
  any freezing Cindra crafting machine lacks a patch.

- [ ] **[UNSEEN] Two things the freeze audit turned up — your verdict wanted (ci-qha1).**
  The mod-wide audit measured every Cindra-added entity in-engine for the first
  time and found two reads no headless test can judge.
  *Do:* **(A)** build a **mass driver** and a **power diode** in the thawed band,
  walk them nightward past the onset, and leave them. **(B)** leave a bank of
  capacitors / molten-salt batteries / a dissipator running out on the frozen
  nightside with no heat anywhere.
  *See / judge:* **(A)** both really do freeze (measured `frozen == true`) but
  neither has a frost layer — a rocket-silo takes no `graphics_set.frozen_patch`
  and a power switch's is a TOP-LEVEL field, so neither type is covered by the
  frost-art audit. They stop dead while looking perfectly alive. Does that
  mislead? A silo that has visibly stopped animating may read as frozen without
  art, in which case nothing is needed; if it reads as merely idle, it wants a
  created layer (`scripts/gen-frost-layer.py`) and the audit's `FROST_FIELDS`
  extended to those two types. **(B)** the whole storage/solar tier **cannot**
  freeze: the engine accepts `heating_energy` on an accumulator / solar panel /
  electric-energy-interface and then ignores it (measured), and vanilla Aquilo is
  the same. Does a battery bank humming away in the deep dark read as WRONG? If
  so that is the ci-de55 design question (script Cindra's own freeze for those
  types) and wants your verdict there, not a fix here.
  *Covered:* the ci-qha1 guard — no Cindra-added entity may be immune to the
  freeze (`scripts/frost-audit.lua`, `prototypes/frost-audit.lua`,
  `tests/test_frost.lua`, `unit-tests/test_frost_audit.lua`). The class is
  enumerated LIVE, so a new entity cannot ship unexamined.

## 6. Back to orbit — the export leg

- [ ] **The mass driver launches and the cargo lands (ci-o39, ci-zcx, ci-8g1).**
  *Do:* research `cindra-orbital-launch`, build a `cindra-mass-driver`, power it,
  feed it raw aluminium + ALICE solid rocket fuel (no pre-made can), optionally
  slot productivity modules, load cargo, and fire it at a platform in orbit. Open
  an assembler and read the fuel recipe.
  *See:* the silo assembles a launch charge internally (consuming aluminium +
  fuel + a large slug of power), the rocket rises, and the cargo lands in the
  space platform's **hub inventory** — with no catcher and no bespoke
  platform-side building. The recipe reads **"ALICE solid rocket fuel"** with a
  tooltip explaining the reaction: **nano-aluminium powder + ice + oxygen** →
  ordinary rocket fuel, fine metal as the fuel and ice/O2 as the oxidiser. All
  three inputs show, and because O2 is a fluid it needs an assembler with a fluid
  box (AM2/AM3, not AM1) — piping the electrolysis line's surplus O2 in here is
  the point (ci-6vj S5 made ALICE a real O2 sink).
  *Broken if:* the cargo pod is rejected by the hub (the clone must keep the
  vanilla `rocket_entity`).
  *Note:* the driver wears the vanilla silo animation in world — only its
  inventory/tech ICON is the bespoke mass-driver art. A rail-gun reskin is a later
  art pass, not a v1 bug.
  *Covered:* `tests/test_mass_driver.lua` drives a real launch and asserts the
  payload lands in `defines.inventory.hub_main`; only the visual rise/descent is
  left to eyeball.

- [ ] **[SHOT] Look back down: the globe IS the planet you just walked (ci-4qyj).**
  *Do:* from the platform in orbit, look at Cindra having now walked it.
  *See:* the ordering and rough proportions match what you crossed — a broad
  molten **lava ocean** reading as liquid rock with convection mottling (not a
  thin bright rim), a clearly readable **dark rocky band** between fire and ice
  matching the ash middle underfoot, and a broad pale **ice sheet** on the
  shadowed limb. Only the lethal ground glows (emission is gated on the heat
  field).
  *Broken if:* orbit and ground disagree on which regions exist or roughly how
  wide they are. That used to be an expected gap; since ci-4qyj it is a **bug**.
  *Covered:* `unit-tests/test_terrain_ramp_lockstep.py` pins the art to
  `terrain.lua`. Shot: `docs/verification/ci-4qyj-orbital-three-part.png`.

## 7. Two calls only you can make

Neither of these is pass/fail. Both were escalated deliberately for a human
verdict, and both are **[UNSEEN]** on a real client.

- [ ] **(a) Does the arc furnace's molten glow still read through the new frost?**
  Flagged by the brotherhood on ci-u92y. The body's emissive molten-arc glow is a
  layer of the BASE animation, so a frozen furnace may still glow orange under
  the frost even though its animation is halted on frame 0.
  *Do:* freeze an arc furnace on the nightside (§5) and look at it in the dark.
  *The call:* if it still glows, that is a real "frozen machine still running"
  read and wants its own bead — **report it, do not fix it here.** The fix is
  moving the emission into a working visualisation, which changes the IDLE look of
  every arc furnace too, so it is deliberately out of scope. If the glow reads as
  banked residual heat rather than as a running machine, say so and it stays.

- [ ] **(b) Is the from-space art still free of the gray/tan sandy terminator band?**
  You **VETOED** that band on ci-6i1. The two middle albedo stops (a sandy
  building-neutral and a cool grey dust) were replaced by a broad belt of dark
  volcanic mountains, and ci-4qyj then repainted the whole globe from
  `terrain.lua`. The intended read is **fire → dark mountains → ice**.
  *Do:* open the star-map and the live orbital approach on a real GPU (§1), and
  compare against `docs/verification/ci-6i1-terminator-orbital.png` and
  `ci-4qyj-orbital-three-part.png`.
  *The call:* is the middle third **dark, warm basalt** (low luminance, R>G>B), or
  has any gray/tan blur crept back in? The bake is guarded off-game and confirmed
  in a headless render, but the live client on real hardware is the only place the
  veto can actually be cleared. If it is clear, say so and this entry dies. If it
  is not, there is now exactly ONE place to change it: `COLOR_STOPS` in
  `mods/cindra/scripts/terrain.lua` (since ci-4qyj, `scripts/gen-planet-maps.py`
  no longer carries its own copy — it reads that table through
  `scripts/terrain_ramp.py`). Re-bake with `scripts/render-planet.sh`.

## 8. Expected placeholder art — do NOT file these

- **Resources** — stone/ice cloned from vanilla `stone` (recoloured via
  `map_color`), rocks from vanilla `huge-rock` (warm stone-tinted, ci-jvc).
  Bespoke resource art is a later pass.
- **The electric heater and the mass driver** still reuse vanilla-derived
  sprites; the driver wears the vanilla silo animation in world.
- **The flare-storage bodies** (capacitor, molten-salt battery, dissipator) are
  procedural first-pass art under the ci-z94 animated layers.
- **No Cindra entity sprite is DIRECTIONAL.** Remaining bespoke/animated art is
  tracked across ci-eb9 and ci-kuu.
- **Snowfall flakes** are tinted white squares (see §5).

Bespoke art that HAS landed and is therefore fair game to critique: the glass
furnace, the oxidizer, the arc furnace, the radio-station scanner, the twelve
materials/petrochemical icons (ci-6vj S6), the red mud + slag renders, and the
seven scanner signal glyphs.

## 9. Optional second run — the east-west ribbon (ci-65p, ci-vjc)

Only if you have time for a second world. The orientation is a startup setting
read at the DATA stage, so it needs its own game — and its own test run
(`npm run test:integration:horizontal`, part of `npm test`), which already
asserts the rotated world's geometry, oceans, resource bands and lethal belts in
raw x/y. What is left here is the LOOK of it, not the layout.

- [ ] **[UNSEEN] Fire at the TOP, endless east-west.**
  *Do:* Settings → Mod settings → Startup → **Habitable band orientation =
  Horizontal (east-west, hot to the north)**, then start a **NEW** game on Cindra.
  *See:* the **lava ocean at the TOP** (walk north into the heat) and the **ice
  ocean at the bottom**; walking EAST or WEST along the ribbon never hits a void
  wall — the ash middle runs on for thousands of tiles; the void backstop only
  past the lava (north) and past the ice (south); the map view reads as a
  horizontal band, not a square.
  *Broken if:* the world is boxed in on both axes, or the fire is at the bottom.
  *Expected, not a bug:* flipping the setting on an EXISTING save leaves a
  straight void scar along the old boundary — chunks already generated as void
  stay void. Start a new world.
