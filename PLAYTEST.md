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

- [ ] **[LANDED] `./play.sh` launches the full playtest set (ci-7s3).** *Repro:*
  `./play.sh` on an install logged into factorio.com (first run fetches
  any-planet-start + helmod into `.play-cache/`). *Look for:* the game boots with
  no missing-dependency errors; the Mods screen lists **cindra, any-planet-start,
  cindra-start, cindra-dev-default, helmod** all enabled; **New Game** opens the
  Any-Planet-Start picker defaulted to **Cindra**; the **Helmod** button appears
  in the toolbar. *Fallback:* `tests/play-sh.test.sh` already proves play.sh wires
  all five into `mods-bundle/mod-list.json` with resolving symlinks; this entry is
  only the interactive "the real game loads them and the start chain lands on
  Cindra" confirmation.

- [ ] **[LANDED] Reach and stand on Cindra (smoke test).** *Repro:* `./play.sh`
  -> New Game with `cindra-dev-default` enabled (Any-Planet-Start lands on
  Cindra), or research `planet-discovery-cindra` from an existing save and travel
  from Vulcanus. *Look for:* the surface loads, the character spawns on buildable
  land, and you can place/mine entities. *Fallback:* the headless load +
  `test_planet.lua` already prove the prototype loads and the surface generates;
  this entry is only the interactive "it feels like a place you can stand"
  confirmation.

- [ ] **[LANDED] Map view / orbit reads as Cindra (ci-hmc, ci-2sr, ci-bu4).** *Repro:* open
  the star-map / navigate the orbital approach to Cindra. *Look for:* the planet is
  named exactly **Cindra** (no tagline suffix anywhere, ci-06j / ci-8ua) with a
  real planet description (molten
  dayside / frozen nightside / thin ribbon / sporadic flares); it sits **clearly in
  space** at a close orbit sunward of Vulcanus, NOT overlapping the sun disc (ci-bu4
  pulled it from distance 3, which planted it inside the sun, out to 6);
  `solar_power_in_space` is high (currently **1000**, above Vulcanus's 600);
  "contains" reads **stone + ice** with distinct icons (the ice patch no longer
  wears a stone icon, ci-2sr); the Vulcanus->Cindra space route icon matches the
  other routes' convention (ci-bu4): little **transfer arrows** (the planet-route
  base), the **Vulcanus** origin badge top-left and the **Cindra** destination
  globe bottom-right and **in front**, both badges the SAME size (Cindra is no
  longer oversized, and it is no longer two Vulcanus planets), and a SHORT length
  (currently **12000**, was 80000). Travelling the leg, the asteroid field reads as
  a hot Vulcanus/Gleba-tier route (ci-bu4: sparse Vulcanus/Gleba chunks + medium
  asteroids), NOT the dense Nauvis-tier field it used to show. The globe reads FIERY
  (radiant molten dayside) -> SANDY (a clearly
  lit warm terminator band down the middle, NOT black) -> ICY (dark blue-shimmer
  nightside); it does NOT rotate (tidally locked) while the terminator steam band
  and the flares off the fire limb animate in place. The baked star-map sprite
  split is verified off-game (`unit-tests/test_planet_maps.py`: centre ~RGB
  [185,150,88] sandy, fire limb ~[189,73,20] molten orange, ice limb ~[57,93,135]
  icy blue); only the LIVE orbital backdrop is the playtest.

- [ ] **[LANDED] Planet from-space graphic is VIVID, not dull (ci-fg6).** The
  earlier bake read flat: a dull matte peach dayside and a flat navy nightside.
  *Repro:* open the star-map and the orbital-approach view of Cindra (`./play.sh`,
  then navigate/travel to it). *Look for:* the LAVA hemisphere (left limb, sunward
  per tidal lock) reads as **strongly GLOWING** radiant molten orange/red with a
  soft bloom halo bleeding off the fire limb and bright magma veins; the ICE
  hemisphere (right limb) reads as a **shimmery cool BLUE** frozen vault with icy
  glints catching the light, NOT flat grey/navy; the sandy terminator band down
  the centre is now a **THIN sliver** (slimmed ~10x per the space-view
  refinement) so the disc reads as mostly FIERY + ICY hemispheres, NOT thirds.
  The whole planet stays DARK (glow/shimmer are accents on a dark base, not an
  overall wash-out). Fire faces the star, ice faces away
  (orientation preserved). *Fallback:* the baked star-map sprite is verified
  off-game (`unit-tests/test_planet_maps.py` guards the strongly-glowing dayside,
  the visible icy-blue shimmer, and the thin sandy terminator; `unit-tests/test_space_appearance.lua` guards
  the orbital backdrop's boosted emission_scalar + specular sheen). This entry is
  only the "the glow/shimmer looks vivid on the live orbital backdrop, bloom and
  all" confirmation a still-image test cannot judge. Re-bake via
  `scripts/render-planet.sh` (tunes: gen-planet-maps.py emission/albedo,
  bake-starmap.py Standard view transform + Emission Strength + Glare bloom +
  cold-blue fill, space-appearance.lua emission_scalar/specular_intensity).

- [ ] **[LANDED] Mod thumbnail reads as Cindra (ci-06j).** *Repro:* open the
  in-game mod manager (or the mod portal listing) and find **Cindra** by **Vuza**.
  *Look for:* the mod tile shows a planet-globe thumbnail (the 144x144 downscale of
  the star-map globe art) rather than the generic no-thumbnail placeholder, and the
  title reads exactly **Cindra** with no tagline suffix. *Fallback:*
  `unit-tests/test_branding.lua` already proves `thumbnail.png` ships at the mod
  root as a real PNG and the title/author strings are correct; this entry is only
  the "the globe crop looks good at tile size" visual confirmation.

- [ ] **[LANDED] Star-map icon faces the fiery dayside at the sun (ci-2sr).** As a
  tidally-locked world the fiery dayside must point TOWARD the star. The engine's
  default aims the icon's top sunward, which left the baked fire limb ~90 deg off;
  planet.lua now sets `starmap_icon_orientation = (orientation - 0.25) = 0.8` so the
  fire limb points at the star (the prototype value is asserted in
  `tests/test_planet.lua`, but the on-screen rotation is a render only the engine
  shows). *Repro:* `./play.sh`, open the system/star-map view and look at Cindra.
  *Look for:* the FIERY (warm orange) hemisphere faces toward the central star and
  the icy nightside faces away; the fire/ice terminator is roughly perpendicular to
  the planet->sun line. If the ICY side faces the sun, the orientation is a
  half-turn off (add 0.5); if the terminator points at the sun, it is a
  quarter-turn off (adjust by +/-0.25).

- [ ] **[LANDED] No day/night cycle (tidally locked, ci-2sr).** *Repro:* select
  Cindra on the star-map and read the planet panel, then stand on the surface for
  several minutes without a flare. *Look for:* the panel's **Day/night cycle** line
  reads as effectively none (an enormous value), NOT "5 minutes" -- the surface
  property is now an effectively-infinite length (not 0, which would flip the
  surface to always_day and flatten the flare's daylight curve). On the ground,
  daylight does NOT free-run through a dawn/dusk cycle; the flare driver freezes
  daytime and only moves it during a flare event. It reads as a fixed,
  dark-weighted "always the same time of day" until a flare hits.

- [ ] **[LANDED] Discovery lore reads well in the tech GUI (ci-11b).** *Repro:*
  open the technology screen and hover/select the `planet-discovery-cindra` tech.
  *Look for:* the full §3 planet-discovery lore paragraph fits the tooltip/
  description panel and reads cleanly (no awkward truncation). The five standalone
  codex blurbs (`cindra-lore.*`) are keyed for a future codex reader and not yet
  surfaced in-game; their presence/shape are unit-tested
  (`unit-tests/test_locale.lua`), so this playtest is only the tech-tooltip read.

## Ribbon & terrain

- [ ] **[LANDED] REAL noise-driven ribbon planet (ci-3yl) — MAYOR MUST SCREENSHOT.**
  The ribbon is now generated by the MAP-GEN itself (no on_chunk_generated script).
  Finiteness, Cindra-only tile bands, organic (wavy) boundaries, no grass/water,
  banded resources, and finite rocks are integration-tested
  (`tests/test_worldgen.lua`); the lethal-tile damage is in `tests/test_tile_damage.lua`.
  *Repro:* `./play.sh` onto Cindra (dev-default lands you there). *Look for* the
  parts a test cannot judge: (1) the world is a genuine **ribbon** — a long
  habitable band with a hard `out-of-map` void a fixed distance west and east
  (default vertical: hot to the **west**, cold to the **east**); (2) the ground is
  the full **11-zone gradient** (ci-da2) — pure **lava** at the hot edge → a
  lava/crust mix → warm volcanic cracks/stone → jagged basalt → scorched dirt → dirt
  → the wide sandy **building** centre → dust → **rough ice** → the smooth **deep-ice**
  cap; (3) each zone is a **NOISE MIX of several tiles that interpenetrate**, and the
  band boundaries are **organic wavy curves, NOT straight lines**, with **no Nauvis
  grass** or water; (4) the map view shows the colour gradient (red hot → sandy
  centre → cyan cold); (5) spawn sits in the **wide safe building** band you can
  build across freely.

- [ ] **Hot region reads as RINGS around lava pools (ci-cwk) — VISUAL.** The hot
  region is no longer a flat perpendicular stripe: a distance-to-lava **heightmap**
  drives the tile choice, so **lava sits in pools/blobs** with **volcanic-cracks-hot
  wrapping each pool like a shoreline** and the heat falling off with distance from
  lava as **concentric contour rings** (lava-hot core → lava → cracks-hot ring → warm
  cracks/smooth-stone → temperate). The X gradient still governs where lava appears:
  **dense/large pools toward the west/sunward edge, thinning to none by the temperate
  zone**. The pool/ring structure (pools intermix along a fixed column, lava is always
  insulated by a cracks-hot ring, lava thins west→temperate) is asserted in
  `tests/test_worldgen.lua`; the ring elevation model in `unit-tests/test_terrain.lua`;
  only the *visual read* is the playtest. *Repro:* land on Cindra, open the map (M) and
  chart the sunward/west edge, and walk west from spawn. *Look for:* (1) lava reads as
  **pools/blobs**, not a solid wall stripe — largest and most merged near the west edge,
  breaking into isolated pools as you move east; (2) **every lava pool is ringed by
  volcanic-cracks-hot** (the hot "shoreline"), never abutting plain ground directly;
  (3) the heat visibly **radiates outward in rings** from each pool (cracks-hot →
  warm crust → temperate), so hotness reads as distance-from-lava, not a flat band;
  (4) it plays nicely with the tile-based damage (ci-4jl) — the closer to a lava pool
  you stand, the more it burns. *Fallback:* none — the ring/pool read is inherently
  visual.

- [ ] **[LANDED] Danger zone reads on the MAP VIEW like a demolisher tint (ci-4h7)
  — MAYOR MUST SCREENSHOT.** The lethal edges now carry a distinct alarming
  `map_color` (set on the Cindra tile clones, never the vanilla tiles), so the
  hot/cold danger bands read at a glance on the map/chart at every zoom, the way a
  Vulcanus demolisher territory reads as a tinted region — but produced positionally
  by the tile bands, with **no** dependence on the demolisher territory API. The
  colours and their distinctness are asserted in `tests/test_worldgen.lua` +
  `unit-tests/test_terrain.lua`; only the *visual read* is the playtest. *Repro:*
  land on Cindra, open the map (M) and chart out to both edges. *Look for:* (1) the
  sunward half reads as a clear **red→hot-orange** band deepening toward the lethal
  lava edge; (2) the nightward half reads as a **pale-ice→bright-cyan** band toward
  the lethal deep-ice edge; (3) the safe **building** centre is a neutral sand tone,
  so the safe↔danger boundary is legible as a colour change, not a muddy blur; (4)
  the tint follows the organic wavy band boundaries automatically. *Fallback:* none
  — the exact map colour read at zoom is inherently visual.

- [ ] **[LANDED] Lethal ZONES burn/freeze the player AND machines (ci-3yl/ci-da2).**
  *Repro:* walk west into the hot zones (1+2+3) and build a machine there, then walk
  east onto the smooth deep-ice cap. *Look for:* being in the **hot zones** drains HP
  (heat) and a machine built there takes damage too; the **smooth deep-ice cap**
  drains HP (cold); the walkable middle (including **rough ice** and the volcanic
  warm zones) is safe. Damage is now **positional** (keyed to the perpendicular axis,
  since the zones mix tiles), so it should feel like a smooth danger band, not a
  per-tile flicker. (Damage is tested; the *feel* — is the lethal edge readable and
  fair? — is the playtest. The screen-tint feedback is the next item.)

- [ ] **[LANDED] Full-screen heat/cold damage feedback tint (ci-7tl) — VISUAL.**
  *Repro:* walk **west** into the hot zones until HP starts dropping, then walk
  **east** across the ribbon onto the smooth deep-ice cap. *Look for:* (1) the
  instant you enter the lethal HEAT band the whole screen gains a **warm red tint**,
  and the lethal COLD cap gives a **frost-blue tint** — so it is unmistakable WHY
  you are losing health; (2) the tint appears/clears **exactly** as the ticking
  damage starts/stops (both read the same `terrain.lethal_at` bands), never a tint
  without damage; (3) the tint **deepens** the further you push toward the lava /
  ice edge (alpha scales with intensity); (4) it **never fully blacks out** the
  view (max alpha ~0.55), the GUI stays usable, and it clears the moment you step
  back to the safe ribbon. Show/hide/switch and the Cindra-only gate are
  integration-tested (`tests/test_feedback.lua`) and the band+intensity maths is
  unit-tested (`unit-tests/test_feedback.lua`); only the *look/feel* (is the tint
  strength readable and not nauseating? does a flat fill suffice or is a soft
  **radial vignette** wanted?) is the playtest. *Note:* v1 is a flat white fill
  tinted at runtime; a bespoke soft-edged vignette sprite is an art follow-up.

- [ ] **[LANDED] Cliffs generate in the volcanic zones only (ci-da2) — VISUAL.**
  *Repro:* land on Cindra, walk/scan the volcanic band (zones 3–6, west of the
  building area). *Look for:* (1) **Vulcanus-style cliffs** appear scattered through
  the rocky/volcanic zones as terrain flavour; (2) the **building band is cliff-free**
  and freely buildable (no cliff walls block spawn); (3) the **deep-ice cap is
  cliff-free**; (4) cliffs never fully wall off a zone in a way that blocks
  progression. Presence/absence per band is asserted in `tests/test_worldgen.lua`;
  only the *look/feel* (do they read as natural volcanic cliffs, are they too dense?)
  is the playtest. *Note:* a bespoke **ice-mountain cliff** for the zone-11 rough→
  smooth-ice wall is deferred to **ci-70r**; today that wall is the lethal-cold cap.

- [ ] **[LANDED] Map-gen + settings UI: Stone/Ice only, no "Ribbon" wording (ci-3yl).**
  *Repro:* New Game → map-gen → Resources tab (Cindra selected), and the
  mod-settings screen. *Look for:* exactly two Cindra resource sliders labelled
  plainly **Stone** and **Ice** (no "Cindra stone/ice", no icon soup), grouped at
  the BOTTOM below Aquilo, and **NO** "Frozen volatiles" slider. Terrain tab: **no**
  Nauvis water / moisture / starting-moisture / terrain-type sliders. Settings: the
  ribbon-tuning settings read as functional names with **no raw keys and no the
  word "Ribbon"**, and the orientation dropdown shows worded options (not raw
  `vertical`/`horizontal`). Patches: stone/ice appear as IRREGULAR natural patches
  (not a grid); no water at any setting; deep-nightside ice yields volatiles when mined.

- [ ] **[LANDED] Ice field, stone patch + rocks read right (ci-9bb).**
  *Repro:* explore the ribbon on Cindra; mine an ice field and a stone patch; open
  the map view. *Look for:* the **ice field** deposit reads as ICY/frosted on the
  ground (a pale frost-blue ore patch), clearly NOT the warm stone rubble and NOT
  the vanilla iron-ore look; its map colour is a pale cyan/frost, distinct from
  iron ore's steel-blue. The **stone** deposit is labelled just **Stone** (never
  "Cindra stone"). Mining an ice field drops the oxide chunk plus **Frozen
  volatiles** wearing their OWN vial-of-gas icon (violet/cyan), NOT a second batch
  of "ice cubes" (the old placeholder). **Rocks** appear scattered along
  the WHOLE ribbon terminator band as you explore (naturally scattered, no lattice,
  finite per rock), not only around spawn. *Fallback:* `test_worldgen.lua` proves
  the icy map_color (distinct from stone AND iron) and band-wide rock generation;
  the sprite/icon *appearance* is what this entry confirms.

- [ ] **[LANDED] Rocks read as yellowish STONE (ci-jvc).** *Repro:*
  explore the ribbon on Cindra and look at the scattered hand-minable **rocks**.
  *Look for:* a warm, golden-tan **stone** rock (the vanilla `huge-rock` under a
  `{1.0, 0.93, 0.62}` warm multiply-tint), reading like a Factorio stone/sandstone
  rock rather than the stock cool brown-grey rubble, and still clearly legible
  against the dark volcanic-soil terminator ground (not washed into it). *Fallback:*
  `unit-tests/test_rock_tint.lua` proves the tint is a warm yellow multiply and is
  applied to every sprite variation, and `docs/verification/ci-jvc-rock-stone-tint.png`
  is a pixel-faithful before/after; this entry is only the "does it feel like stone
  against live terrain + lighting" confirmation a still cannot judge.

- [ ] **[LANDED] Nightside cold damage vs Aquilo freeze (feel).** Unheated
  machines past the cold threshold (axis temp < -30 °C default) take ticking cold
  damage rather than a reversible Aquilo-style freeze. *Look for:* the pace
  (default 20 dps) gives enough time to run a heat umbilical out before a machine
  dies, and reads as "drag heat with you," not "instant loss." If a reversible
  freeze feels better, that is a future refinement, not a v1 bug.

- [ ] **[IN-FLIGHT] Zone-appropriate decoratives read right (ci-6fq).** Cosmetic
  decals scattered per gradient zone: volcanic **rocks + pebbles + craters** on the
  hot (west) rocky/lava half, **ice + light-snow** decals on the cold (east) icy
  half, keyed to the ribbon X-gradient. *Repro:* explore the ribbon west and east of
  the terminator on Cindra. *Look for:* (1) the hot half is strewn with occasional
  volcanic rocks and the odd crater (scatter, NOT a carpet); (2) the cold half reads
  as a frosted/snowy ground (ice + snow decals, denser, like Aquilo); (3) NO rocks
  or craters on the icy ground and NO snow/ice decals in the rocky/lava region (no
  bleed across the terminator); (4) the temperate terminator spawn band stays clean
  (no decals); (5) decal sprites sit sensibly on the terrain (no jarring seams), and
  the densities feel right (tune the biases in `scripts/decorative-field.lua` if the
  rocks read too sparse/dense). *Fallback:* `tests/test_decoratives.lua` proves the
  zone placement + purity (rocks only on the hot half, ice/snow only on the cold
  half, none on the terminator) on the live map; only the *look* is the playtest.

## Bootstrap from nothing

- [ ] **[LANDED] From-nothing bootstrap start works (ci-8nh / ci-fs4 / §6).**
  Cindra has NO ore or coal patches at all; the finite hand-mined rocks
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

- [ ] **[LANDED] Manufactured lava: dedicated lava-manufacturer, ruinous power (§15-5, ci-e8a).**
  Lava is now cast in a dedicated **`cindra-lava-manufacturer`** (a fast, 40 MW foundry
  clone in a private category), NOT the shared foundry; the foundry only MELTS lava into
  metal. This fixes the old ~100-foundries-per-melt unusability without cheapening lava:
  the machine's speed sets the count (single-digit, ~6 per melting foundry) while its draw
  is pinned proportional so **energy-per-lava is unchanged and ruinous**. Machine count,
  fixed energy-per-lava, the ruinous aggregate draw, and the recipe tint are all
  headless-tested (`tests/test_lava.lua`, `prototypes/lava-icon.lua`). *Repro:* research
  `cindra-lava` (gated behind the foundry + Cindra discovery), build a handful (~6) of
  `cindra-lava-manufacturer`, feed them stone + power, and route the lava into foundries
  for molten metal. *Look for:* (1) the `cindra-lava` recipe icon is the vanilla lava
  sprite under a warm amber-tinted layer - it reads a touch hotter/brighter than natural
  Vulcanus lava at icon size, still obviously lava (placeholder tint, do not file as a
  bug); (2) the manufacturer now wears the bespoke glass-furnace art (Hurricane046 /
  CC-BY, ci-oi8) instead of the foundry sprite - see the dedicated art entry below;
  (3) the *feel*: ~6 manufacturers visibly feed one melting foundry without an absurd
  machine wall, at a visibly heavy grid draw ("power is the lever"), and productivity
  modules are allowed on the lava recipe (ci-095). Balance the ruinous 40 MW draw against
  the flare/solar numbers (ci-9k6, ci-63d).

- [ ] **[LANDED] Lava-manufacturer glass-furnace art looks right (ci-oi8).** The
  `cindra-lava-manufacturer` wears the user-supplied Hurricane046 **glass-furnace**
  set (CC-BY): an animated furnace body, a ground shadow, and an always-on emissive
  molten glow, wired into the assembling-machine `graphics_set.animation` (replacing
  the inherited foundry art + its pipe working-visualisations). *Repro:* build a
  `cindra-lava-manufacturer` and run it. *Look for:* the machine shows the glass-furnace
  building (not a foundry, not an invisible/placeholder box) and its body visibly
  **animates** (the 80-frame furnace loop); the emissive layer **glows** (reads as a lit
  molten furnace, especially in the dark); a ground **shadow** casts correctly; the
  item/entity **icon** is the glass-furnace icon in the inventory, build preview, and
  factoriopedia; and the inherited foundry **pipe glow overlay is gone** (no stray
  foundry-shaped effects near the fluid connections). *Judge the tuning:* `BODY_SCALE`
  / `BODY_SHIFT` in `mods/cindra/prototypes/lava.lua` place the furnace on the
  foundry-sized footprint - confirm the base sits on the tiles (not floating, buried,
  or oversized) and the shadow lands under the body. The geometry (270x310 frames,
  two-part 80-frame sheet, 8-wide), layer wiring, dropped foundry overlays, and icon
  are test-covered (`unit-tests/test_lava_graphics.lua`, and the mod-loads +
  runtime-craft checks in `tests/test_lava.lua` / `tests/test_bootstrap.lua`); only
  the on-screen look/scale/shift and animation feel need eyes.
  **ci-8r6 fix (2026-07-30):** the ci-oi8 sheets shipped as INDEXED/palette PNGs,
  which Factorio renders as an opaque BLACK square - in-game the body vanished behind
  a black box and only the emission glow showed (user screenshot `lavaman.png`).
  Every other Cindra entity ships RGBA; the glass-furnace set was the anomaly. Fixed
  by converting all five glass-furnace PNGs (body -1/-2, emission -1/-2, shadow) to
  32-bit RGBA. `unit-tests/test_lava_graphics.lua` now asserts every layer sheet is
  truecolour RGBA (fails on the old palette art, passes on the fix). *Eyes still
  need to confirm:* the base furnace body now renders in full colour (NOT a black
  square) and the scale/shift sit right on the footprint.

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
  consumed by the flare **capacitor** (as its plates), by the **mass driver**
  (pressed into the launch CAN and ground into the aluminium-powder SOLID ROCKET
  FUEL), and by the **Cindra science pack** (its signature input). *Note:*
  aluminium is now Cindra's SOLE signature product + primary export (ci-84s):
  the cryo-quench / cryo-hardened-alloy chain is retired and Cindra science is
  re-based onto aluminium. Productivity is OFF on the electrolysis recipe (power
  stays the honest cost).

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

- [ ] **[LANDED] Panel damage reads as degrade-before-death (§15-8, ci-9ay,
  ci-snq).** Undisposed flare surplus degrades the most-sunward panels first
  (recoverable), then destroys them under a sustained deficit; adding a
  dissipator/storage heals them. Rule, edge-bias, self-correction, and
  dissipator-as-fuse are integration-tested (`test_panel_damage`, `test_disposal`),
  and the whole thing is now proven END-TO-END through the live driver path (ci-snq,
  `test_panel_damage_runtime`): driver enabled, a real sporadic flare,
  `panels.sweep()` reading the schedule intensity -- insufficient disposal degrades
  panels, sufficient disposal is zero loss, a near-full buffer raises the alarm
  (Cindra's "full battery"), only Cindra panels are touched, and it fires with no
  day/night cycle (tidal-lock safe). *Look for:* the health read of a panel array
  cooking sunward-first during an over-built flare, and recovering once disposal is
  added. Panels have no bespoke "overheating" visual yet (just the health bar); an
  emissive cue is a follow-up.

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
  cargo pod, `launch_to_space_platforms`, a raw-aluminium+fuel launch charge,
  productivity-module support, a vanilla platform hub as the destination);
  end-to-end behaviour is the playtest. *Repro:* research `cindra-orbital-launch`,
  build a `cindra-mass-driver`, power it, feed it raw aluminium + solid rocket fuel
  (no pre-made can), optionally slot productivity modules, and load cargo (or
  request from a platform in orbit). *Look for:* the silo assembles a launch charge
  internally (consuming raw aluminium + fuel + a large slug of power), the rocket
  rises, and cargo lands in the space platform's hub inventory, with NO catcher or
  bespoke platform-side building. If the cargo pod is rejected by the hub, that is a
  bug (the clone must keep the vanilla `rocket_entity`).

- [ ] **[LANDED] Mass driver + launch-chain art are placeholders (ci-o39).** The
  driver is a full deep-copy of the vanilla rocket-silo, so in world it wears the
  vanilla silo animation; only its inventory/tech ICON is the delivered mass-driver
  art (`graphics/icons/mass-driver.png`). The aluminium powder (calcite tinted) and
  solid rocket fuel (rocket-fuel tinted) are v1 placeholder icons. *Look for:* the
  building reads acceptably as a launcher, its icon reads as the mass driver in the
  Space crafting tab, and the chain icons read as distinct materials. A bespoke
  rail-gun/coilgun silo reskin is a later art pass, not a v1 bug.

## Science & circuits

- [ ] **[LANDED] Cindra science pack (§15-12, ci-3or).** *Repro:*
  research `cindra-science`, craft a pack in an ordinary assembling machine, feed it
  to a lab. *Look for:* the pack reads as a distinct Cindra pack in the lab/tech GUI
  (currently the vanilla automation-science-pack icon tinted hot amber). Functionality
  is fully test-covered (`tests/test_science.lua`), including a powered stock assembler
  that only progresses with power. *Note:* the pack recipe consumes the signature
  **aluminium** + deep-nightside volatiles + calcite (petrochemical-free); it was
  re-based off the retired cryo-hardened alloy by ci-84s.

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

- [ ] **[LANDED] Environmental scanner radio-station art looks right (ci-0e8).**
  The scanner uses the user-supplied Hurricane radio-station art (CC-BY): a
  static first-frame body is wired into the constant-combinator `sprites` (for
  ghost/blueprint/factoriopedia previews) and the runtime draws an animated
  body + emissive-glow overlay on each placed scanner. *Look for:* the built
  scanner shows the radio-station building (not an invisible/placeholder combinator)
  and its body visibly **animates** (a gentle ~1.3 s idle loop); the emissive
  layer **glows at night**; a ground **shadow** casts correctly; the item/entity
  **icon** is the radio-station icon in the inventory, build preview, and
  factoriopedia. *Judge the tuning:* `BODY_SCALE` / `BODY_SHIFT` in
  `mods/env-scanner/prototypes/scanner.lua` place a tall masted building on a 1x1
  footprint - confirm the base sits on the tile (not floating or buried), the
  scale is not oversized, and the animated overlay lands exactly on top of the
  static body with no visible double-image or seam. Also confirm the ghost
  (build preview) and a blueprint of it still show the building body. The
  geometry (160x290 frames, 20-frame / 8-wide strip), layer wiring, overlay
  draw/teardown, and icon are test-covered (`tests/test_scanner.lua`,
  `unit-tests/test_scanner_graphics.lua`); only the on-screen look/scale/shift
  and animation feel need eyes.

## Placeholder art (expected in v1, do NOT file as bugs)

- [ ] **[LANDED] Resource art is placeholder.** Stone/ice/volatiles resources are
  cloned from vanilla `stone` (recoloured via `map_color`) and rocks from
  vanilla `huge-rock` (warm stone-tinted, ci-jvc). The stone + ice resources now carry the Cindra stone/ice
  icons so the map "contains" list reads correctly (ci-2sr); the volatiles resource
  + item still reuse the vanilla ice icon. Bespoke Cindra resource art is a later
  pass.

- [ ] **[LANDED] Signature-building art is placeholder.** The aluminium
  electrolysis cell, lava manufacturer, electric heater, and mass driver
  reuse vanilla-derived sprites/icons (see `graphics/ART-MANIFEST.md`). Bespoke and
  animated art is tracked across ci-z94, ci-eb9, ci-kuu, and ci-wfv. Do not file
  placeholder art as a gameplay bug.

## In-flight (not yet in-game)

These are DESIGNED and beaded but NOT on `main`. Do not expect them in a playtest
of the current build; they are listed so "not built yet" is distinguishable from
"built and broken." Re-tag them **[LANDED]** as their beads merge.

- [ ] **[IN-FLIGHT] Power diode PoC: the two poles are visible and distinct
  (ci-gcd).** A research spike (one-way power transfer between two networks). Its
  behaviour -- energy A->B up to a rate cap, never B->A, networks isolated -- is
  fully test-covered (`tests/test_power_diode.lua`, `unit-tests/test_diode.lua`),
  so this checkbox is only for the look a test cannot judge. *Repro:* in the
  editor, place a **Power diode (input)** and a **Power diode (output)** (each on
  its own pole network). *Look for:* both poles render (they reuse the vanilla
  accumulator sprite) and are visually distinguishable -- input tinted **green**,
  output tinted **red** -- and are selectable/minable. *Note:* isolated PoC with
  no recipe/tech, so it is editor-spawn only; there is no crafting-tab entry yet.

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

- [ ] **[LANDED] Aluminium is the sole signature; cryo-quench dropped (ci-84s).**
  Aluminium (the electrolysis cell) is now Cindra's signature product + primary
  export, and the cryo-quench / cryo-hardened-alloy chain is fully removed with
  Cindra science re-based onto aluminium. Prototype removal + re-base are
  test-covered (`tests/test_pivot.lua`, `tests/test_science.lua`); no cryo
  prototype survives. Bespoke signature building art (electrolysis caster,
  modelled on Hurricane's arc/glass furnace, CC-BY) remains a separate art bead
  (ci-wfv) - a v1 electric-furnace placeholder ships in the meantime.

- [ ] **Ribbon terrain gradient reads as the temperature axis (ci-6c9).** The
  default orientation is now VERTICAL: the ribbon runs bottom-to-top, so the
  hot↔cold gradient runs left↔right with HOT on the LEFT (west). `scripts/worldgen.lua`
  paints the vanilla terrain to match: from the left/hot edge inward `lava-hot` →
  `lava` → `volcanic-cracks-hot` → a sand fringe → the temperate spawn band, mirrored
  on the right/cold side `snow` → `ice-smooth` → `ice-rough` → `ammoniacal-ocean` (the
  frozen "ice wall"). The tile bands, the wall void, and the fire/freeze damage
  alignment are all integration-tested (`tests/test_worldgen.lua`,
  `tests/test_edge_damage.lua`); only the *visual read* and *interactive feel* are the
  playtest. *Look for:* (1) landing on the wide temperate band at spawn with molten
  ground visibly to the WEST and ice to the EAST; (2) walking west, the ground shifts
  volcanic-cracks-hot → lava at the same point the heat damage bites, and the `lava` /
  `lava-hot` tiles are IMPASSABLE (like water) so you cannot walk into the molten edge
  — the visible terrain IS the damage boundary and wall; (3) walking east mirrors it into ice,
  with `ammoniacal-ocean` the impassable frozen edge; (4) tile transitions look sane
  (no jarring seams) and the set_tiles gradient does not tank chunk-gen performance as
  you explore along the ribbon.

- [ ] **Deep-edge resources under impassable tiles (ci-6c9).** The very deepest ice
  (`> edge_mid` nightward) and any resource in the outermost hot band fall under the
  impassable `ammoniacal-ocean` / `lava-hot` tiles. This is intended (the absolute edge
  is a molten/frozen wall), but the reachable edge-pushing reward is the band just
  inside it (walkable `ice-rough` / `volcanic-cracks-hot`). *Look for:* the richest
  reachable ice/volatiles sit at the walkable/impassable boundary and mining feels like
  a graded risk, not a dead cliff; confirm no resource is stranded such that the
  economy is starved.

- [ ] **Burned volcanic rocks read as charred boulders in the lava areas (ci-qy0).**
  Charred Vulcanus-style boulders (the `big-`/`huge-volcanic-rock` art) generate by
  worldgen across the HOT region, clustered toward the lava edge; mining one yields
  stone + coal only. Placement confinement (hot region only, never temperate/ice),
  the density-toward-lava ramp, and the stone+coal drop are all integration-tested
  (`tests/test_worldgen.lua`) plus the pure autoplace geometry
  (`unit-tests/test_resource_field.lua`); only the *visual read* is the playtest.
  *Look for:* (1) walking WEST from spawn toward the molten ground, dark volcanic
  boulders appear on the walkable `molten-rock` band and get denser the closer you
  get to the impassable lava; (2) they look distinctly charred/volcanic (reused
  Vulcanus rock art), visually separable from the pale hand-minable terminator
  `rock`; (3) none appear in the temperate spawn band or anywhere on the cold/ice
  side; (4) they never spawn ON the impassable lava tiles (collision keeps them on
  solid ground), so they read as "at the lava's edge," not floating in it.
