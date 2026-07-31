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
  asteroids), NOT the dense Nauvis-tier field it used to show. The globe reads as a
  NATURAL left-lit gradient (ci-i9m): a radiant molten LAVA hemisphere on the left
  (sunward) falling off through a smooth sandy-neutral terminator into a dark ICE
  hemisphere on the right, with NO hard painted seam down the middle; it does NOT
  rotate (tidally locked) while the terminator steam band drifts. The baked
  star-map sprite is verified off-game (`unit-tests/test_planet_maps.py`); only the
  LIVE orbital backdrop is the playtest.

- [ ] **[LANDED] From-space planet: natural left-lit gradient, ice reads as ice,
  no plume artifact (ci-i9m).** Supersedes the ci-fg6 painted-sandy-seam look. The
  bake now lights the globe with a single PARALLEL sun from the LEFT, so the
  day/night terminator is a natural light falloff, not a self-lit stripe; the
  surface albedo follows the in-game terrain ramp (lava -> volcanic -> sandy ->
  pale frost -> icy white-blue); and the orbital backdrop's oversized hero-flare
  overlay (which rendered as white/yellow **rocket-plume** streaks at the bottom of
  the globe) is REMOVED. *Repro:* open the star-map and the orbital-approach view
  of Cindra (`./play.sh`, then navigate/travel to it). *Look for:* a **bright fiery
  lava limb on the LEFT** fading smoothly to a **dark, shimmery-blue ICE hemisphere
  on the right** with **NO hard vertical seam**; the cold side reads as recognisable
  **ICE** (pale frosted blue), NOT Fulgora electric-blue lightning on black; and
  **NO plume/streak artifact** anywhere (esp. the bottom). Dark overall with the
  lava glowing (self-lit even where the light grazes) and the ice softly shimmering;
  fire faces the star, ice faces away (tidal-lock orientation preserved). *Fallback:*
  the baked star-map sprite + maps are verified off-game
  (`unit-tests/test_planet_maps.py` guards the smooth ramp / no self-lit seam / pale
  non-electric ice / strongly glowing lava; `unit-tests/test_space_appearance.lua`
  guards the removed hero-flare overlay). This entry is only the "the live orbital
  backdrop looks right (gradient, ice, no plume)" confirmation a still-image test
  cannot judge. Re-bake via `scripts/render-planet.sh`. **Note:** a tasteful
  limb-flare visual could return as a follow-up bead (the flare spritesheet art
  `graphics/space/cindra-flare.png` still exists for reuse).

- [ ] **[LANDED] Star-map icon: soft ~55%-lit terminator (ci-nyj).** The baked
  star-map globe used to split at a HARD 50% Lambertian half. The bake now adds a
  subtle wrap-around ambient/reflected-ground bleed so a little light spills just
  PAST the terminator onto the near-dark side: the terminator softens and ~55% of
  the disc reads as lit, while the deep ice limb stays dark. *Repro:* open the
  star-map / navigate to Cindra (`./play.sh`). *Look for:* the fire->ice boundary
  is clearly SOFTER than a crisp centre line, with a thin lit spill onto the near
  side, yet still a clear lit/dark planet (dark side still reads as shadowed ice).
  *Fallback:* the baked sprite is verified off-game -- `unit-tests/test_starmap_lighting.py`
  guards the ~55% lit fraction and the soft-terminator bleed (both FAIL on the old
  hard-50% bake), on top of the existing left-sun / blow-out / no-wedge guards.
  Re-bake via `scripts/render-planet.sh` (also regenerates the mod `thumbnail.png`
  from the same globe so the portal card matches).

- [ ] **[LANDED] In-game ORBITAL view parity with the star-map icon (ci-6y9).**
  The user reported the LIVE orbital/platform globe did NOT read like the polished
  star-map icon: it was a dull orange globe with a muddy tan terminator and a dark
  olive nightside, not the icon's blown-out fire limb + deep-blue ice. The orbital
  backdrop is engine-lit from `platform_surface_render_parameters.platform_backdrop`
  (`prototypes/space-appearance.lua`), separate from the Blender-baked icon, so it
  was tuned independently against an ACTUAL in-engine orbital screenshot. The old
  "headless can't render the globe" blocker was WRONG: the full client runs under
  Xvfb + software GL via **EGL/llvmpipe** (`SDL_VIDEO_FORCE_EGL=1`, the ci-036 /
  ci-ijk path -- NOT the `SDL_VIDEO_X11_FORCE_EGL` variant that fails). Harness:
  `scripts/render-orbit.sh` loads `scenarios/orbit-shot` (spawns a platform in
  orbit of Cindra, screenshots its surface). Before/after/target proof:
  `docs/verification/ci-6y9-orbital-parity.png`. Tuning applied: near-horizontal
  left `light_direction`, `emission_scalar` cranked to blow out the lava AND lift
  the emission map's blue ice-side self-glow (the engine has no cool-ambient field,
  so that self-glow stands in for the bake's cool world-ambient), a cool-blue
  `atmosphere_color`, thinned `cloudiness`, and dropped `specular_intensity` (its
  old 0.95 lit the sandy terminator into a bright cream wall). *Repro:*
  `scripts/render-orbit.sh`, or in-game open the star-map / travel to Cindra
  (`./play.sh`). *Look for:* the engine-lit globe reads like the icon -- single sun
  from the LEFT, blown-out molten limb, soft ~half-lit terminator, deep-blue ICE
  nightside. *Fallback:* the tuned param values are guarded off-game and under the
  real runtime (`unit-tests/test_space_appearance.lua`,
  `tests/test_space_appearance.lua`: "orbital parity"). This entry is only the
  "the live globe visibly reads like the icon in motion" confirmation a still image
  cannot fully judge (the terminator steam still drifts, ci-ane).

- [ ] **[LANDED] Terminator reads as DARK VOLCANIC MOUNTAINS, no gray/tan band (ci-6i1).**
  The human flagged an ugly wide GRAY/TAN vertical stripe wedged between the volcanic
  side and the ice side of the star-map globe. It was painted into the ALBEDO by the
  two middle `TERRAIN_STOPS` (a sandy building-neutral + a cool grey dust) in
  `scripts/gen-planet-maps.py`, mirrored in `scripts/terrain.lua` `COLOR_STOPS`. Both
  ramps now replace those neutrals with a BROAD band of DARK VOLCANIC MOUNTAINS
  (reddish-brown / near-black basalt: `#5A3524`, `#3E2A20`, `#4A3A30`) filling the
  middle third, so the disc reads molten -> dark mountains -> ice with NO gray/tan
  blur. Maps regenerated + star-map re-baked via `scripts/render-planet.sh`. *Repro:*
  in-game open the star-map / navigate to Cindra (`./play.sh`), or render the live
  orbital backdrop with `scripts/render-orbit.sh`. *Look for:* a dark basalt mountain
  belt between the fire limb and the ice side, and NO gray/tan stripe anywhere.
  *Fallback:* the baked star-map sprite + maps are verified off-game
  (`unit-tests/test_planet_maps.py`: the terminator asserts DARK, WARM basalt --
  low luminance, R>G>B, not neutral gray), AND a real in-engine orbital screenshot
  was captured headless (Xvfb + EGL/llvmpipe) confirming the dark belt with no
  gray/tan stripe: `docs/verification/ci-6i1-terminator-orbital.png`. This entry is
  ONLY the remaining "does it read right in the live client, in motion" judgement a
  still + headless render cannot fully make (needs a display-capable operator /
  Overseer); do NOT block the map/art merge on it.

- [ ] **[LANDED] Planet is STATIC in the space view: no rotate, no wobble (ci-ane).**
  The Overseer flagged the Cindra globe as ROTATING / WOBBLING in the space/starmap
  view when it should sit still (tidal lock). The spin was already frozen
  (`rotation_seconds = NO_ROTATION`), but the orbital backdrop had inherited a
  non-zero `planet_axis_deviation_amplitude = {6,6}` (vanilla planets use this to
  gently nod their globes), so the frozen face still wobbled on its axis. Zeroed
  the amplitude (`{0,0}`) so the tidally-locked face is truly static. *Repro:* open
  the star-map and select/navigate to Cindra, then WATCH the globe for ~30s
  (`./play.sh`). *Look for:* the fire/ice globe holds a **completely still** pose --
  no spin, no slow nod/wobble/tilt drift; the ONLY motion is the terminator steam
  band drifting across the seam (clouds animate, globe does not). Fire limb stays
  fixed on the left (sunward), ice on the right. *Fallback:* the zeroed deviation
  amplitude is guarded off-game and under the real runtime
  (`unit-tests/test_space_appearance.lua`, `tests/test_space_appearance.lua`); this
  entry is only the "the live globe visibly holds still over time" confirmation a
  static prototype assert cannot judge.

- [ ] **[LANDED] Orbital view: the two light axes are aligned, no wedge (ci-lcv).**
  The human flagged that from the ORBITAL view Cindra showed TWO different light
  axes -- one from the BAKED fire->ice gradient in the surface/emission maps, one
  from the engine's in-game `light_direction` -- crossing at an angle as an ugly
  pie-slice **wedge**. Cause: a rolled `planet_axis = {-18,-4}` tilted the baked
  `lon=0` meridian off the vertical diffuse terminator (the analogue of the bake's
  ci-pde X-tilt wedge). Fix in `prototypes/space-appearance.lua`: un-roll
  `planet_axis` to `{0,0}` (baked meridian vertical) and zero the vertical (y)
  component of `light_direction` (diffuse terminator vertical) so the two coincide.
  Before/after captured in-engine: `docs/verification/ci-lcv-orbital-light-axis.png`
  (+ `-wide`). *Repro:* `scripts/render-orbit.sh`, or in-game park a platform in
  orbit of Cindra / travel the approach (`./play.sh`). *Look for:* a single clean
  fire->ice terminator running VERTICAL down the disc (molten limb left, dark
  basalt + blue ice right); NO second boundary and NO pie-slice wedge where the
  emission and the shading disagree. *Fallback:* the un-rolled axis + vertical
  terminator are guarded off-game and under the runtime
  (`unit-tests/test_space_appearance.lua`, `tests/test_space_appearance.lua`:
  "aligns the two light axes"), and the fix was verified against a real in-engine
  render; this entry is only the "reads as one planet, no wedge, in the live
  client" confirmation.

- [ ] **[LANDED] Star-map: Cindra dropped closer to the sun (ci-lcv).** The human
  said the star-map view "looks great" but reads a touch far, and asked to drop
  Cindra closer to really sell it running up against the sun. `ORBIT_DISTANCE` in
  `prototypes/planet.lua` was moved from **6 back in to 4.5** (ci-bu4 had earlier
  pulled it OUT from a distance-3 position that overlapped the sun disc, so 4.5
  keeps clear margin). *Repro:* open the star-map / navigate the orbital approach
  (`./play.sh`). *Look for:* Cindra sits noticeably TIGHTER to the star than before
  (the innermost world, well sunward of Vulcanus) while its globe stays **fully
  clear of the sun disc** -- not clipped or overlapping it. *Fallback:* the
  distance value + the "clear of the sun (>3), closer than the old 6, sunward of
  Vulcanus" guards are pinned in `tests/test_planet.lua`; this entry is only the
  interactive "the closer orbit looks right and never touches the sun" judgement a
  distance assert cannot make. If a visual check shows any sun-disc overlap, nudge
  `ORBIT_DISTANCE` back up a touch (toward 5) and re-run the test.

- [ ] **[LANDED] Star-map sun-side blows out to near-WHITE (ci-2f7).** Follow-up
  to ci-i9m: the left-lit gradient was correct but too subtle. The bake now drives
  the single parallel sun WAY up (energy 4 -> 13, warm-white), aimed exactly
  horizontal so it hits PERPENDICULAR to the vertical lava line. *Repro:* open the
  star-map and select/approach Cindra (`./play.sh`). *Look for:* the sun-side
  (LEFT) limb now **blows out to a near-WHITE hot highlight** with a bloom halo,
  falling off HARD through yellow/orange/red to a **dark** ice hemisphere on the
  right (dramatic light->dark pop, not the earlier flat wash); light direction,
  albedo, and geometry are otherwise unchanged from ci-i9m. *Fallback:* the baked
  sprite is verified off-game (`unit-tests/test_starmap_lighting.py` guards the
  near-white left-limb blow-out, the strong left->dark falloff, and the dark-but-
  not-void ice side; `unit-tests/test_planet_maps.py` still guards the unchanged
  albedo/emission maps). This entry is only the in-game "does the star-map really
  POP" confirmation. Re-bake via `scripts/render-planet.sh`.

- [ ] **[LANDED] Star-map lava/sand belt is square to the light, NO wedge (ci-pde).**
  Follow-up to ci-2f7: the light crank was right but the geometry was wrong. The
  bake tilted the sphere 8 deg about the (horizontal) light axis for a pole-peek,
  which slid the lon=0 lava/sand meridian off vertical while the light terminator
  stayed vertical, so the belt and the lit/dark boundary crossed at an angle -- a
  pie-slice WEDGE (Overseer flag). The X-tilt is now zero, so the belt runs
  straight vertical and coincides with the vertical light terminator. *Repro:*
  open the star-map and select/approach Cindra (`./play.sh`). *Look for:* the
  disc reads as a clean **half-lit sphere** -- the sandy/lava belt runs **straight
  vertical** down the centre, PERPENDICULAR to the horizontal (left) sun, with the
  bright sun-side crescent on the left and the dark ice hemisphere on the right;
  **no angled wedge / pie-slice** where the belt meets the terminator. *Fallback:*
  `unit-tests/test_starmap_lighting.py` now guards the belt's verticality (its
  horizontal drift across the disc must be < 0.025 of the diameter; the ci-2f7
  wedge drifted ~0.066). Re-bake via `scripts/render-planet.sh`.

- [ ] **[SUPERSEDED by ci-i9m] Planet from-space graphic is VIVID, not dull (ci-fg6).** The
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

- [ ] **[LANDED] THREE-PART TWO-HEIGHTMAP terrain redesign (ci-wly) — MAYOR MUST SCREENSHOT.**
  The whole planet was rebuilt into three regions across the hot-cold axis: a **HOT**
  side, a habitable **MIDDLE**, and a **COLD** side (sides ~equal width). Each side is an
  **OCEAN + a damaging heightmap inner slope + a safe cool flat outer slope**; both
  oceans are **~200 tiles** of nothing but ocean, **folded into the heightmap** (not
  stamped on top). Geometry, ocean solidity, ring insulation, the family split, resource
  banding, walkable-ice and no-pave are all integration-tested (`tests/test_worldgen.lua`,
  `tests/test_paving.lua`); only the *look/feel* is the playtest. *Repro:* `./play.sh`
  onto Cindra. *Look for:* (1) walking WEST from spawn: ash middle → cool cracked/smooth
  volcanic rock → glowing cracks-hot / warm stone rings → **lava pools** → a solid
  **hot-lava OCEAN** that reads as going on forever, then the void; (2) walking EAST:
  ash middle → cool **dust** (frosted → lumpy → crested → flat) → **snow** rings →
  **rough ice** → a solid **smooth-ice OCEAN**; (3) the lava and ice oceans are SOLID
  (no gaps/holes) and each thins into pools/fingers as you move toward the middle
  (heightmap, not a flat stripe); (4) the middle is a dark/pale **ash** mix with small
  **soil** patches — a clean habitable build zone at spawn; (5) organic wavy boundaries
  everywhere, never straight stripes. NOTE: the from-orbit view / star-map still show the
  OLD colour ramp until the ci-4qyj orbital re-render lands (expected mismatch, not a bug).

- [ ] **[LANDED] Smooth-ice is now WALKABLE-but-damaging; the old ice WALL is gone (ci-wly).**
  ci-wly drops the impassable deep-ice wall. Only the two **lava** tiles remain
  impassable (the hot-lava ocean is the one hard wall). You can now **RUN onto the
  smooth-ice ocean** — it just freezes you (cold damage that scales with depth), so a
  dash across the ice is survivable briefly with mitigation, not an instant stop.
  Damage now SCALES by tile (hot-lava hottest → warm cracks mildest; smooth-ice coldest →
  patchy snow mildest). You **cannot pave** (concrete/stone-path) over the lava, warm
  stone, cracks-hot, or ice tiles to neutralise them (the paving reverts). *Repro:*
  `./play.sh`, walk east onto the ice. *Look for:* you step onto the smooth ice (not
  blocked like lava), the cold damage feedback tint rises, and it hurts more the deeper
  you go; trying to concrete over a lava/ice tile bounces back with a "cannot pave" note.

- [ ] **[SUPERSEDED by ci-wly] THIN ribbon (~128-tile functional band) + impassable ICE WALL (ci-qqt) — MAYOR MUST SCREENSHOT.**
  NOTE (ci-wly): this entry describes the OLD 11-zone model, now REPLACED by the 3-part
  heightmap (≈200-tile oceans, WALKABLE smooth-ice, no ice wall). Kept for history;
  validate the two ci-wly entries above instead.
  The playfield was thinned: the **functional band** — the survivable space between the
  LAVA TRIGGER (where heat death begins, the hot walkable margin's outer edge) and the
  ICE WALL (where the impassable/cold-lethal deep ice begins) — is now **~128 tiles**,
  matching the vanilla ribbon-world default (was ~500). And the cold side finally has a
  **real, visible, impassable ICE WALL**: the smooth deep-ice cap is now impassable (you
  cannot walk onto or build on it), the cold-side twin of the molten lava wall. The band
  width, the two triggers, and the ice-wall impassability are all integration-tested
  (`tests/test_worldgen.lua`); only the *look/feel* is the playtest. *Repro:* `./play.sh`
  onto Cindra. *Look for:* (1) the survivable ribbon feels **tight** — a short walk west
  from spawn reaches the hot lava, a short walk east reaches the ice; pace it out, it is
  ~128 tiles wall-to-wall (~64 each side of spawn); (2) walking EAST you hit a hard
  **wall of smooth ice** you cannot step onto or build on (it stops you like the lava
  does to the west), not a walkable icy field that just hurts; (3) the zone ORDER and
  feel are preserved — lava sea → volcanic → sandy building centre → dust → rough-ice →
  the ice wall — just compressed; (4) the map view reads as a narrow habitable ribbon
  between a molten west edge and a frozen east wall; (5) the ribbon is **flat/cliff-free**
  everywhere (no Vulcanus cliffs — the thin band has no room for them; see below).

- [ ] **[LANDED] NO cliffs on the thin ribbon (ci-qqt).** ci-da2 grew Vulcanus-style
  cliffs in the volcanic zones; the thin 128-tile ribbon dropped them (a cliff would
  wall the narrow traversable band, and the engine strips any placed in it). This is
  test-covered (`tests/test_worldgen.lua` asserts zero cliffs). *Look for:* the volcanic
  band west of spawn is flat rocky ground with NO cliff faces walling lanes; every part
  of the ribbon stays walkable/workable. (A bespoke thin-ribbon or ice-mountain cliff is
  future work under ci-70r.)

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

- [ ] **Hot region reads as a SOLID SEA + RINGS radiating out (ci-cwk, reworked ci-48z) — VISUAL.**
  The far-west edge is **ALWAYS a solid, contiguous hot-lava SEA** (~50 tiles, zone 1):
  pure lava-hot, no pools/gaps/rings. OUTWARD of the sea a distance-to-lava **heightmap**
  drives the tiles, so **lava breaks into fingers/pools** with **volcanic-smooth-stone-warm
  wrapping each pool** (the warm shoreline adjacent to the lava) and **volcanic-cracks-hot
  ringing IT one step further out**, the heat falling off as **concentric contour rings**
  (lava-hot → lava → smooth-stone-warm → cracks-hot → cracks-warm → temperate). Per the
  ci-48z contour fix, **smooth-stone-warm sits inside cracks-hot, not the reverse.** The X
  gradient governs density: **dense/large pools next to the sea, thinning to none by the
  temperate zone**. The solid sea (zero gaps, seed-independent), the pool/ring structure and
  the contour order are asserted in `tests/test_worldgen.lua`; the ring elevation model and
  the sea guarantee in `unit-tests/test_terrain.lua`; only the *visual read* is the playtest.
  *Repro:* land on Cindra, open the map (M) and chart the sunward/west edge, and walk west
  from spawn. *Look for:* (1) the far-west edge is a **solid molten sea**, no holes; (2)
  moving east the lava **breaks into fingers/pools**, thinning to none by the temperate zone;
  (3) each pool is **ringed by smooth-stone-warm first, then cracks-hot** (never abutting
  plain ground directly); (4) the heat visibly **radiates outward in rings** from the sea and
  the pools; (5) it plays nicely with the tile-based damage (ci-4jl) — the closer to lava you
  stand, the more it burns. *Fallback:* none — the sea/ring read is inherently visual.

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
  (not a grid); no water at any setting; the deep-nightside ice field yields a
  fixed **mix of ice + calcite** when mined (ci-9l6: no oxide chunk, no volatiles
  item).

- [ ] **[LANDED] Ice field, stone patch + rocks read right (ci-9bb).**
  *Repro:* explore the ribbon on Cindra; mine an ice field and a stone patch; open
  the map view. *Look for:* the **ice field** deposit reads as ICY/frosted on the
  ground (a pale frost-blue ore patch), clearly NOT the warm stone rubble and NOT
  the vanilla iron-ore look; its map colour is a pale cyan/frost, distinct from
  iron ore's steel-blue. The **stone** deposit is labelled just **Stone** (never
  "Cindra stone"). Mining an ice field drops a fixed **mix of ice + calcite**
  (ci-9l6: no oxide chunk, no volatiles item; the science pack's cold-edge input is
  the mined `ice`). **Rocks** appear scattered along
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

- [ ] **[LANDED] Ice-rocks read as ICY and land in the safe cold band (ci-18n).**
  *Repro:* explore the cold/ice side of the ribbon (east of the terminator, before
  the lethal deep-ice cap) and look at the scattered hand-minable **ice-rocks**.
  *Look for:* (1) a pale frost-blue **icy** boulder (the vanilla `huge-rock` under a
  `{0.62, 0.82, 1.0}` cool multiply-tint) that reads as ice/frost, clearly distinct
  from the warm yellow-tan sandy rocks on the other side; (2) it sits sensibly on the
  cold-dust / rough-ice ground (not washed into it, not on bare sand); (3) mining one
  gives an early **ice + stone** trickle. *Fallback:* `unit-tests/test_rock_tint.lua`
  proves the tint is a cool blue multiply distinct from the stone tint, and
  `tests/test_worldgen.lua` proves ice-rocks generate only in the safe cold band
  (never the lethal deep-ice zone or the warm side) and yield ice + stone; only the
  "does the frost tint read icy against live cold terrain + lighting" is the playtest.

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
  Cindra has NO ore or coal patches at all; the finite hand-mined rocks are the ONLY
  landing metal. Split by side (ci-18n): the temperate **sandy rocks** drop stone +
  iron ore + copper ore (NO coal, no tungsten); **coal** comes from the **volcanic
  rocks** in the hot/lava margin (stone + coal); the cold-side **ice-rocks** drop ice
  + stone. Yields and natural (off-lattice) scatter are prototype-tested
  (`tests/test_worldgen.lua`). *Repro:* start a fresh Cindra game with nothing,
  hand-mine the terminator sandy rocks, then walk sunward to the volcanic rocks for
  coal. *Look for:* the rocks are scattered naturally (NOT a repeating grid); enough
  stone to hand-craft stone furnaces AND enough iron/copper ore from the sandy rocks
  plus coal from the (safely reachable, non-lethal) volcanic rocks to smelt a first
  trickle of plates and fuel, i.e. you can stand up the first foundry / power /
  ice-processing without a pre-existing ore patch, after which the infinite
  lava->metal economy takes over. If a from-nothing start soft-locks, that is a
  balance bug (coordinate with ci-arw / ci-uex).

- [ ] **[LANDED] Start-on-Cindra foundry bootstrap reads well (ci-arw).** The
  no-Vulcanus foundry path (finite bootstrap coal -> `cindra-crude-lubricant`,
  renewable `cindra-mineral-lubricant`, and the Cindra-buildable
  `cindra-field-foundry`, all under `cindra-improvised-metallurgy`) is fully
  logic-tested (`tests/test_foundry_bootstrap.lua`, `tests/test_aps_foundry.lua`).
  *Repro:* start on Cindra via any-planet-start. *Look for* the *felt* opening: the
  improvised-metallurgy recipes are visible/craftable from tick zero (the APS start
  pre-researches the tech), hand-mining a few volcanic rocks (the coal source since
  ci-18n) yields enough coal to crude-liquefy the lubricant for a first
  `cindra-field-foundry`, and building +
  running that foundry (lava -> molten metal) feels like a deliberate, non-tedious
  bootstrap rather than a soft-lock or a grind. Normal (post-Vulcanus) play imports
  finished foundries instead; those recipes reuse vanilla lubricant/foundry icons
  (v1 placeholder art), do not file that as a bug.

- [ ] **[LANDED] Bootstrap kit capsule drops on landing (ci-8wu).** A start-on-Cindra
  game lands with a MINIMAL supply chest ("capsule") pre-stocked with the two machines
  that are painful to hand-bootstrap plus basic power: 1 `foundry`, 1
  `cindra-lava-manufacturer`, 3 `solar-panel`, 2 `accumulator`, 8 `small-electric-pole`.
  The kit CONTENTS + one-chest-only minimality are logic-tested
  (`tests/test_aps_kit.lua`, via `cindra-start`'s spawn seam); what stays a playtest is
  the in-game DROP FLOW, which needs a real cargo-pod cutscene. *Repro:* start on Cindra
  via any-planet-start and watch the opening. *Look for:* exactly ONE steel chest appears
  near where the character lands (not before the cargo-pod cutscene finishes, not a
  second copy on reload/save), it is openable and holds the kit above, and the kit gives
  a genuine leg-up (build power + a first foundry+caster without the hand-craft grind)
  without feeling like a free base. If it drops twice, drops on a non-Cindra start, or
  never drops, that is a bug.

## Economy: lava, ice, aluminium

- [ ] **[LANDED] Mixed ice field: sort + backpressure feel (§15-4, ci-9l6).**
  *Repro:* drop an electric mining drill on an ice field and belt its output; the
  drill emits a fixed **ice + calcite mix** (currently 2:1). Split the two apart,
  melt the ice in a chemical plant (`Ice melting`) for water. Now let the calcite
  side back up (no sink for it early). *Look for:* the mix reads clearly (the field
  tooltip says it drops both, and both items ride out on the belt); when the calcite
  belt fills, the drill **stalls and chokes the ice too** (the intended
  mixed-output-patch puzzle, like Fulgora scrap). Confirm the ratio feels right:
  plenty of ice for water/science/fuel, a steady minor calcite stream.
  *(Structurally tested: the field yields ice+calcite at an ice-majority ratio, a
  powered drill deposits both, and ice->water melts end-to-end. What a test cannot
  judge is the feel of the ratio and whether the early backpressure is fun vs.
  frustrating.)*

- [ ] **[LANDED] Early calcite/ice surplus is not a hard soft-lock (ci-9l6).**
  *Repro:* play the early game before any calcite sink (aluminium refine, ci-400
  calcination) is unlocked, mining the mixed field. *Look for:* the surplus product
  (usually calcite, sometimes ice) can be dealt with WITHOUT permanently deadlocking
  the base -- e.g. buffered, or voided/vented lossily -- so the line keeps flowing.
  The overseer's intended pacing is "burden early, resource later"; confirm early
  players are not *hard* stuck. **If no acceptable early voiding path exists in
  practice, file a follow-up bead** for a lossy calcite/ice voider (e.g. a
  vent/dump), per the overseer's "consider ventable/voidable surplus" note. This is
  a balance/feel judgement `factorio-test` cannot make.

- [ ] **[LANDED] Manufactured lava: dedicated lava-manufacturer, ruinous power (§15-5, ci-e8a / ci-9yg).**
  Lava is cast in a dedicated **`cindra-lava-manufacturer`** (a 40 MW foundry clone in a
  private category), NOT the shared foundry; the foundry only MELTS lava into metal. This
  fixes the old ~100-foundries-per-melt unusability without cheapening lava: a single-digit
  count (~6) feeds one melting foundry at a ruinous, **unchanged energy-per-lava**. Machine
  count, fixed energy-per-lava, and the ruinous aggregate draw are all headless-tested
  (`tests/test_lava.lua`). *Repro:* research `cindra-lava` (gated behind the foundry +
  Cindra discovery), build a handful (~6) of `cindra-lava-manufacturer`, feed them stone +
  power, route the lava into foundries for molten metal. *Look for:* (1) the *feel*: ~6
  manufacturers visibly feed one melting foundry without an absurd machine wall, at a heavy
  grid draw ("power is the lever"); note that productivity is now **DISABLED** on the lava
  recipe (ci-9yg, the stone-negativity invariant), so a productivity module gives no bonus
  there; (2) the manufacturer wears the bespoke glass-furnace art (Hurricane046 / CC-BY,
  ci-oi8) instead of the foundry sprite - see the dedicated art entry below. Balance the
  ruinous 40 MW draw against the flare/solar numbers (ci-9k6, ci-63d).

- [ ] **[ci-9yg] ONE true "Lava" + the machine no longer spazzes (REDO of ci-a0y + ci-4ee).**
  There is now exactly one lava fluid: the **vanilla `lava`**, used end-to-end (the separate
  `cindra-lava` fluid is deleted; Cindra casts through the unmodified vanilla molten
  recipes). And the manufacturer's `crafting_speed` dropped from 64 to **2** (batch scaled
  up to keep throughput), fixing the animation/sound spazz. Both are visual/interactive and
  cannot be headless-checked. *Repro:* on Cindra, research + build the lava chain; run a
  manufacturer; open the fluid in a pipe/tank/factoriopedia and the `cindra-lava` recipe.
  *Look for:* (1) exactly **one "Lava"** everywhere - the recipe makes "Lava", the casts are
  the vanilla "Molten iron"/"Molten copper", and there is **no second lava / no "Manufactured
  lava"** in factoriopedia, tooltips, or filters; (2) the running manufacturer's animation
  and working sound play at a **calm, normal rate** - no fast flicker/blur, no stuttering
  sound. (The tech that unlocks the chain is still "Lava casting".)

- [x] **[LANDED] Lava-manufacturer glass-furnace art looks right (ci-oi8).** The
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
  **ci-ijk RESOLVED + VERIFIED IN-ENGINE (2026-07-30):** the manufacturer was
  FLOATING above the ground and its sprite did NOT fill its 5x5 box (too small).
  Root cause: `BODY_SCALE` 0.5 was too small for the 5x5 foundry footprint and
  `BODY_SHIFT` lifted it -24 px. Retuned to scale 0.64 / shift 0 (the vanilla
  foundry, 356x384 @ 0.5, is the size reference); an actual Factorio render
  (headless Xvfb + llvmpipe, `game.take_screenshot`, day + night, with the 5x5
  selection box drawn and a vanilla foundry beside it) confirms the furnace now
  fills the 5x5 box and its base sits on the ground, all layers (body / shadow /
  emission) aligned, with the ci-036 additive molten glow intact at night. Guard:
  `unit-tests/test_lava_graphics.lua` now asserts scale >= 0.6, shift not lifted,
  and body/emission share scale+shift.
  **ci-cge PENDING VISUAL CONFIRM (2026-07-31):** a later playtest found three
  positioning issues at scale 0.64 / shift 0. Retuned in `prototypes/lava.lua`:
  `BODY_SHIFT` is now `by_pixel(6, -12)` (nudged UP so the body's base aligns with
  the bottom of the 5x5 selection box instead of overhanging south, and slightly
  RIGHT), the shadow shift tracks the body to `by_pixel(30, -4)`, and the circuit
  connector is rebuilt from the universal template at `by_pixel(48, 34)` so the
  wires attach at the BOTTOM-RIGHT of the model (they were connecting mid/top).
  *Repro:* build a `cindra-lava-manufacturer`, drop a pipe on each fluid side, and
  run a red/green wire to it. *Look for:* (1) the body's base sits ON the bottom
  edge of the selection box (no southward overhang, still not floating); (2) the
  RIGHT-side pipe connectors meet the body instead of floating off it (the left
  side was already fine); (3) circuit wires terminate at the lower-right of the
  furnace, not its middle. If any offset needs a further nudge, adjust `BODY_SHIFT`
  / the shadow shift / `CONNECTOR_OFFSET` in `prototypes/lava.lua`. The direction
  of each move (up, right, bottom-right wire point) is guarded in
  `unit-tests/test_lava_graphics.lua`; only the exact pixel amounts need eyes.
  *Deferred:* the TOP/BOTTOM pipe connectors are a separate later test.
  **ci-036 RESOLVED + VERIFIED IN-ENGINE (2026-07-30):** the black-square bug is
  fixed and confirmed with an actual Factorio render (headless client under Xvfb +
  llvmpipe, `game.take_screenshot`), NOT just "the code looks right". The REAL root
  cause was NOT the palette/RGBA theory ci-8r6 chased: the emission layer was missing
  `blend_mode = "additive"`. The emission sheet is FULLY OPAQUE (alpha 1 everywhere)
  with a black background and bright molten openings; `draw_as_glow` alone does not
  change the blend op, so the opaque black background was drawn straight over the
  furnace body - a solid black square with only the openings showing (exactly the
  user's `lavaman.png`). Adding `blend_mode = "additive"` (the same wiring the vanilla
  foundry lights layer uses) makes the black background contribute nothing and only
  the openings add glow. The day render now shows the full colour furnace body at the
  foundry-scale footprint; the night render shows the body lit with glowing molten
  openings. Guarded by `unit-tests/test_lava_graphics.lua` (asserts the emission layer
  sets `blend_mode = "additive"`; fails on the pre-fix spec). The ci-8r6 RGBA
  conversion is retained as a defensive format requirement but was never the bug.

- [ ] **Electrolysis-cell oxidizer art + 4x4 box + bottom-right wire (ci-a6z).**
  The signature aluminium building `cindra-electrolysis-cell` was reassigned from
  the arc-furnace set to Hurricane046's bespoke **oxidizer** set (CC-BY 4.0, as
  bundled in the Nullius Visual Overhaul) -- a big bulbous riveted vessel with a
  green electro-chemical glow -- and enlarged from a 3x3 to a **4x4** footprint,
  with its circuit wire re-anchored to the **bottom-right**. Wired into the
  furnace `graphics_set.animation` (replacing the inherited electric-furnace body
  + heater working-visualisations): animated oxidizer body, ground shadow,
  always-on additive glow. *Repro:* research the aluminium tech, build a
  `cindra-electrolysis-cell`, feed it alumina + power, and run a red/green circuit
  wire to it. *Look for:* (1) the cell reads as its own bulbous oxidizer (not an
  electric furnace, not an invisible/placeholder or **black** box) and its body
  visibly **animates** (the 60-frame loop); the emissive layer **glows** green
  (especially in the dark); a ground **shadow** casts under it; no electric-furnace
  **heater glow / pipe overlay** leaks; the item/entity **icon** is the oxidizer
  icon in inventory, build preview, and factoriopedia. (2) The **selection box is a
  clean 4x4** -- hover/marquee-select it and confirm the highlighted footprint
  matches the body (not a small 3x3 that leaves the body overhanging on all sides).
  (3) The **circuit wire attaches at the bottom-right** of the machine, not
  floating from the centre-top. *Judge the tuning:* `BODY_SCALE` (0.45) /
  `BODY_SHIFT` ({0,0}) in `mods/cindra/prototypes/aluminium.lua` seat the body on
  the 4x4 tiles -- confirm the base sits on the tiles (not floating, buried, or
  wildly over/under sized) and the **700x500 shadow lands under the body** (its
  canvas differs from the 280x320 body frame, so the shared scale/shift may need an
  in-engine nudge, as the glass furnace did in ci-ijk). Also confirm the
  points-only connector (no LED nub) still reads cleanly; if it looks bare, a
  repositioned connector sprite could be added later. The geometry (280x320
  frames, 60-frame 8-wide sheet, last 4 cells empty), the 3-layer wiring, the
  additive glow, the RGBA conversion of the (originally palette) source PNGs, the
  dropped electric-furnace overlays, the 4x4 box, the bottom-right wire point, and
  the icon are all test-covered (`unit-tests/test_aluminium_graphics.lua` +
  `tests/test_aluminium.lua` + the graphics-audit guard); only the on-screen
  scale/shift, animation feel, box read, and wire attach need eyes. **NOTE:** the
  source PNGs were indexed/palette (colour type 3) + grey-alpha shadow -- both
  render as a black box in Factorio (the ci-036 / ci-8r6 lava bug), so they were
  converted to truecolour RGBA on import; watch specifically for a black-square
  regression if the sheets are ever re-exported.

- [ ] **[LANDED] Aluminium chain, the power sink (ci-txh; leaching + O2 reshape
  ci-6vj S2).** The signature material: `20 stone + 30 sulfuric-acid + 20 water ->
  10 alumina + 14 stone + 2 sulfur` (acid LEACHING in a vanilla chemical plant),
  then `4 alumina -> 2 aluminium + 30 O2` (the electrolysis cell, ruinous power).
  Petrochemical-free except the honest acid input; gated behind ONE tech (prereq
  `cindra-lava`, which unlocks the acid the leach needs). *Repro:* research the
  aluminium tech, run the leach in a chemical plant (pipe in acid + water), then
  feed alumina + ruinous power to the electrolysis cell. *Look for:* the cell reads
  as its own building (the oxidizer art, ci-a6z; see the art entry above), out-draws the
  foundry on power, and leans hard on the grid/flare/capacitors; alumina and
  aluminium icons read as distinct materials (ci-6vj S6 bespoke renders: a white
  refined-mineral pile for alumina, an aluminium plate for the metal -- no longer
  the tinted calcite/steel placeholders). **The cell now has an O2 OUTPUT pipe on its
  north edge** (v1 has no bespoke pipe sprite): confirm the O2 gas can be piped out
  and that the pipe connection point reads sensibly on the north face (functional
  connection + O2 emission is integration-tested, only the pipe-sprite look needs
  an eye). The full chain, gating, net stone-negativity, the 30-O2 byproduct, cell
  power draw, and a powered cell electrolysing (fluid box included) are
  integration-tested (`tests/test_aluminium.lua`). Aluminium is consumed by the
  flare **capacitor** (as its plates), by the **mass driver** (pressed into the
  launch CAN and ground into the aluminium-powder SOLID ROCKET FUEL), and by the
  **Cindra science pack** (its signature input). *Note:* aluminium is Cindra's SOLE
  signature product + primary export (ci-84s). Productivity is OFF on the leach
  (matter honesty, net stone-negative at every module tier) but ON for the
  electrolysis step (aluminium is an intermediate); the O2 byproduct is
  `ignored_by_productivity` so a prod bonus can never mint free gas.

- [ ] **[LANDED] Materials/petrochemical bespoke icons read cleanly (ci-6vj S6).**
  Twelve new item/fluid icons replaced the tinted-vanilla placeholders: the four
  gases/liquid (**hydrogen, oxygen, carbon dioxide, methanol**) use molecule
  renders; **quicklime**, **alumina** (white mineral), **aluminium** (plate),
  **nano-aluminium powder** (metal dust), and the two catalyst pairs
  (**methanol/zeolite catalyst** + their greyed **spent** forms) use dedicated
  item renders (Malcolm Riley `unused-renders`, CC-BY-4.0; see
  `graphics/ART-MANIFEST.md`). Wiring, PNG existence, RGBA format, and no-placeholder
  are all unit-tested (`unit-tests/test_materials_graphics.lua`); only the *look* is
  here. *Repro:* research the materials-chemistry + aluminium techs and open the
  recipe/crafting menus, or inspect the fluids in pipes. *Look for:* each new
  item/fluid shows its own distinct icon (no reused petroleum-gas cloud / tinted
  calcite / tinted copper-plate); the fluids are still colour-distinct in pipes;
  the two spent catalysts read visibly duller than their live forms; the
  materials-chemistry tech icon reads as methanol, not the old petroleum cloud.

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
  added. Beyond the health bar, a damaged panel now pops an **overload spark**
  (ci-clf, next entry) so you can SEE which panels are cooking.

- [ ] **[LANDED] Overload-damage spark on a burning panel (ci-clf) — VISUAL.**
  *Repro:* build a sunward panel array with NO disposal (no dissipator/battery)
  and ride a flare (or force it: enable the driver and let a real flare peak). The
  most-sunward panels take disposal-deficit damage. *Look for:* the instant a panel
  is damaged, a short **electric-arc spark** flashes on it — a brief hot orange/white
  zap (the vanilla `sparks-0x` arc, re-tinted to Cindra's fire palette, drawn as a
  glow), NOT Fulgora electric-blue lightning. It fires once per damaged panel per
  damage tick, so a cooking array **shimmers with arcs sunward-first** and the front
  advances inward as panels die; a spared/recovering panel (enough disposal) throws
  **no** spark. The spark should read as "this panel is arcing from overload", pop
  cleanly, and self-clear (it is a one-shot explosion entity, no lingering artifact).
  *Fallback:* the spark prototype (a self-reaping `explosion`) and the fire-on-damage /
  no-fire-on-recovery / one-per-hit behaviour are integration-tested
  (`tests/test_panel_damage.lua` "overload spark visual", `tests/test_power_prototypes.lua`);
  only the *look/feel* (tint, scale, is the flash readable but not spammy?) is the
  playtest. *Note:* v1 reuses the vanilla arc sheets; a bespoke overload sprite is
  an optional art follow-up.

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
  art (`graphics/icons/mass-driver.png`). The aluminium powder now has a bespoke
  aluminium-dust render (ci-6vj S6); the solid rocket fuel is the vanilla
  rocket-fuel item (no bespoke icon needed). *Look for:* the
  building reads acceptably as a launcher, its icon reads as the mass driver in the
  Space crafting tab, and the chain icons read as distinct materials. A bespoke
  rail-gun/coilgun silo reskin is a later art pass, not a v1 bug.

- [ ] **[LANDED] ALICE solid rocket fuel: naming + tooltip reads on-theme (ci-8g1).**
  The fuel recipe now models real ALICE propellant (ALuminium-ICE): its ingredient
  and product shape (nano-aluminium powder + `ice` -> vanilla rocket-fuel), balance,
  and gating are fully integration-tested (`tests/test_mass_driver.lua`). What can
  only be eyeballed is the crafting-menu presentation. *Repro:* research
  `cindra-orbital-launch`, open an assembler and find the fuel recipe. *Look for:*
  the recipe reads **"ALICE solid rocket fuel"** with a tooltip explaining the
  powder+ice reaction; the fuel item is **"Nano-aluminium powder"** with the ALICE
  description; both inputs (powder + ice) show in the recipe and it crafts in a
  plain assembler (no fluid box). Placeholder icons are expected (see art section).

## Science & circuits

- [ ] **[LANDED] Cindra science pack (§15-12, ci-3or).** *Repro:*
  research `cindra-science`, craft a pack in an ordinary assembling machine, feed it
  to a lab. *Look for:* the pack reads as a distinct Cindra pack in the lab/tech GUI
  (currently the vanilla automation-science-pack icon tinted hot amber). Functionality
  is fully test-covered (`tests/test_science.lua`), including a powered stock assembler
  that only progresses with power. *Note:* the pack recipe consumes the signature
  **aluminium** + deep-nightside ice + calcite (petrochemical-free; ci-ml1 removed
  the former volatiles input); it was re-based off the retired cryo-hardened alloy
  by ci-84s.

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
  **ci-ijk RESOLVED + VERIFIED IN-ENGINE (2026-07-30):** the scanner rendered as
  a solid BLACK BOX - the SAME root cause as the ci-036 lava-manufacturer bug:
  the emission strip is FULLY OPAQUE (alpha 1 everywhere) with a black background
  and only bright openings, and its glow layers were missing `blend_mode =
  "additive"`, so the opaque black drew straight over the body. Added additive to
  BOTH the static `sprites` glow layer and the in-world `glow_animation` overlay;
  an actual Factorio render (headless client under Xvfb + llvmpipe,
  `game.take_screenshot`, day + night) confirms the radio-station body now shows
  with its openings glowing at night. Also (Overseer): the scanner is now a **2x2
  building** (was a 1x1 combinator), and `BODY_SCALE`/`BODY_SHIFT` were retuned
  (0.42 / -26 px) so the body FILLS the 2x2 box and its base SITS on the ground
  (was floating ~0.6 tile high), verified against a vanilla accumulator (2x2) in
  the same render. The additive blend, the 2x2 footprint, and the crafting-menu
  order (right after the programmable-speaker, same `circuit-network` subgroup)
  are now test-covered (`unit-tests/test_scanner_graphics.lua` +
  `../cindra/tests/test_env_scanner.lua`).

- [ ] **[LANDED] Environmental scanner signal icons read well in-game (ci-kuu).**
  The seven virtual signals now ship **bespoke** icons (were base-game
  placeholders: accumulator / solar-panel / substation / radar / lab /
  iron-plate / copper-plate). Each is a self-authored 64px glyph
  (`graphics/icons/signals/<name>.png`, generated by
  `scripts/gen-signal-art.py`): a shared dark steel signal plate with a coloured
  glyph -- warm-sun family for the generic surface readings (`env-daytime`
  day/night dial, `env-daylight` rayed sun, `env-solar` sun+bolt, `env-tick-of-day`
  clock) and ember/flare family for the Cindra forecast block
  (`env-flare-countdown` flare-in-a-dashed-ring, `env-flare-phase` warming ramp
  arc, `env-flare-intensity` flare + rising gauge). Wiring, bespoke-not-placeholder,
  icon_size, and file shipping are test-covered
  (`unit-tests/test_scanner_graphics.lua`). *Look for:* open the signal picker and
  the scanner's `env-scanner-signals` subgroup shows the seven bespoke glyphs
  (not base-game icons); each reads distinctly at picker size (~32px) and in a
  combinator/GUI at ~16px; the two clusters (warm surface vs ember flare) are
  visually distinguishable at a glance. *Judge:* nothing looks like a stray
  vanilla item icon; the flare-countdown vs flare-intensity glyphs stay
  distinguishable despite the shared flare motif.

- [ ] **[LANDED] Environmental scanner rework: grounded shadow, no rotation,
  re-seated wires (ci-6jz).** Four playtest fixes on the 2x2 radio-station:
  **(1) Shadow re-grounded** - the ground shadow had been left at its old 1x1
  tuning `(30, 6)` when ci-ijk moved the body down and grew it, so the building
  read as floating with a shadow stranded low and to the right. It is re-seated
  under the legs at `(2, -18)` px (the shadow art's leg-feet now land on the
  body's leg-feet at the box bottom). **(2) Rotation disabled** - the body is one
  Sprite4Way that looks identical from every side, so the R key did nothing
  useful; the `not-rotatable` flag removes the rotation affordance. **(3) Circuit
  wires re-seated** - the red/green wire attach points were the inherited 1x1
  combinator points and floated mid-structure; they now sit at the front base of
  the machine, flanking the legs (red left, green right). **(4)** Investigated
  re-basing the scanner on a **selector-combinator** (playtest suggestion): NOT
  adopted - a selector's GUI modes cannot be restricted via the prototype, and
  its Time mode only emits three fixed engine time-signals (no writable output
  for the scanner's computed readings). Kept the constant-combinator; rationale
  is in `prototypes/scanner.lua`. The flag, the shadow re-seat, and the wire
  points are test-covered (`unit-tests/test_scanner_graphics.lua`,
  `tests/test_scanner.lua`); shadow/wire values were tuned against a scaled
  composite render (not a live client). *Look for:* the built scanner sits
  **planted on the ground** (shadow pooled under the legs, not detached to the
  side); pressing **R** over the ghost/placed scanner does **nothing**; dragging
  **red and green circuit wires** onto it, the wires attach at the **front base**
  of the building (not floating in its middle) and read tidily. *Judge:* the
  shadow grounding and the exact wire-attach pixels - nudge the `(2, -18)` shadow
  shift or the `wire_point` offsets in `prototypes/scanner.lua` if the shadow
  looks slightly off or a wire endpoint lands on an odd spot.

- [ ] **[LANDED] Environmental scanner is actually reachable in the Cindra
  playtest (ci-xor).** The `env-scanner` mod was never loaded in any launch
  config (missing from play.sh's mod-list, the test harness, and cindra's
  dependencies), so the two scanner items above could not be confirmed in a real
  Cindra game. cindra now declares a required `~ env-scanner` dependency and
  every launch config (play.sh + the flake test harness) wires the mod in; that
  it loads and the `environmental-scanner` entity/item/recipe exist is
  integration-tested (`mods/cindra/tests/test_env_scanner.lua`) and the play.sh
  wiring is covered (`tests/play-sh.test.sh`). *Look for:* on a fresh Cindra
  playtest (`./play.sh` → New Game), the **Environmental scanner** is craftable
  from the start and appears in the build menu with its radio-station icon.
  This unblocks the visual confirmation of the two items above.

## Placeholder art (expected in v1, do NOT file as bugs)

- [ ] **[LANDED] Resource art is placeholder.** Stone/ice resources are
  cloned from vanilla `stone` (recoloured via `map_color`) and rocks from
  vanilla `huge-rock` (warm stone-tinted, ci-jvc). The stone + ice resources now carry the Cindra stone/ice
  icons so the map "contains" list reads correctly (ci-2sr). Bespoke Cindra
  resource art is a later pass.

- [ ] **[LANDED] Some signature-building art is placeholder.** The electric
  heater and mass driver still reuse vanilla-derived sprites/icons (see
  `graphics/ART-MANIFEST.md`); the lava manufacturer (glass furnace, ci-oi8) and
  the aluminium electrolysis cell (oxidizer, ci-a6z; was arc furnace, ci-wfv) now
  wear bespoke Hurricane046 art. Remaining bespoke/animated art is tracked across ci-z94,
  ci-eb9, and ci-kuu. Do not file the remaining placeholder art as a gameplay bug.

- [ ] **[LANDED] Red-mud subsystem art is placeholder (ci-c7j).** Red mud and
  slag reuse the bespoke `cindra-stone` icon under a tint (reddish / dark-grey),
  and the carbothermic furnace reuses the vanilla assembling-machine-3 sprite +
  icon (see `graphics/ART-MANIFEST.md`). *Look for:* red mud reads reddish-brown
  and slag reads grey on the belt/in inventory, distinct from stone and from each
  other; the furnace is visible when placed. Bespoke art is tracked in ci-zdp. Do
  not file the placeholder art as a gameplay bug.

## In-flight (not yet in-game)

These are DESIGNED and beaded but NOT on `main`. Do not expect them in a playtest
of the current build; they are listed so "not built yet" is distinguishable from
"built and broken." Re-tag them **[LANDED]** as their beads merge.

- [ ] **[IN-FLIGHT] Native-freeze inversion: high-radius emitter UPS + frost
  visuals (ci-b5i).** The freeze-radius spike (its standalone `freeze-radius-poc`
  mod was removed with ci-eao once concluded; the shipped freeze is the
  cold-DAMAGE model in `scripts/building-heat.lua`, and these findings are the
  durable record of the un-adopted inversion path) proved
  headlessly that a hot heat source with `heating_radius = 100` thaws freezable
  machines out to a hard ~100-tile clamp (square/Chebyshev reach), thaws
  already-frozen machines, sustains indefinitely, and is source-agnostic, all via
  `LuaEntity.frozen`. Two things a headless run CANNOT judge and that gate adopting
  the mechanic on Cindra: **(1) UPS / per-tick cost** of the engine's O(R²) heating
  scan at radius 100, an untested regime (base game runs radius ~1 with dense heat
  pipes); the entity-count collapse (a handful of emitters vs thousands of pipes) is
  favourable but the per-emitter scan cost is unverified. **(2) The freeze VISUALS**:
  frost overlays, stopped-machine animations, and native pipe/fluid freeze
  animation. *Repro (once the mechanic is integrated into Cindra):* enable
  `entities_require_heating`, place an r100 emitter line on the fire edge, spacing
  ≤ ~190, and watch a machine field ~100 tiles out. *Look for:* (1) UPS stays sane
  with a live radius-100 emitter line over a populated band (profile via time-usage
  overlay on a large factory); (2) machines beyond the warm band visibly frost over
  and stop, pipes/fluids freeze, and the freeze front reads as a clean straight ice
  line just past the emitters; (3) no bleed of thaw past ~100 tiles.

- [ ] **[IN-FLIGHT] Power diode PoC: the single power-switch-style building
  (ci-gcd, reworked ci-8l4).** A research spike (one-way power transfer between two
  networks). Its behaviour -- energy source->sink up to a rate cap, never back,
  networks isolated -- is fully test-covered (`tests/test_power_diode.lua`,
  `unit-tests/test_diode.lua`), so this checkbox is only for the look/feel a test
  cannot judge. *Repro:* in the editor, place ONE **Power diode** (it looks like a
  vanilla power switch, tinted pale blue). Copper-wire one side to a powered
  network and the other side to a second, separate network with a load (e.g. an
  accumulator). *Look for:* (1) the building renders and reads as a power switch
  with two copper connection points; (2) power visibly flows from the wired
  source side into the sink side and never back; (3) the switch stays visually
  OPEN and cannot be toggled into a bridge (the runtime forces it open). *Note:*
  the two buffers + tap poles it spawns are hidden guts -- the player only ever
  sees/mines the one switch. Isolated PoC with no recipe/tech, so it is
  editor-spawn only; there is no crafting-tab entry yet.

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
  reachable ice sits at the walkable/impassable boundary and mining feels like
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

- [ ] **Red-mud subsystem bespoke art reads correctly (ci-zdp).** The Bayer/iron-
  recovery items and building carry bespoke art replacing the ci-c7j placeholders:
  `cindra-red-mud` (Malcolm Riley crushed-iron-ore render + an in-engine rust-red
  tint), `cindra-slag` (Malcolm Riley slag-chunk render), and the
  `cindra-carbothermic-furnace` (a procedural Cindra reduction-furnace icon + in-world
  sprite from `gen-entity-art.py`). The wiring, that every PNG ships and is RGBA, and
  that no assembling-machine-3 / vanilla art leaks are integration- + unit-tested
  (`unit-tests/test_red_mud.lua`, `tests/test_red_mud.lua`); only the *visual read* is
  the playtest. *Look for:* (1) red mud reads as a rusty-red residue and slag as a
  dark inert clinker, clearly distinct from each other and from `cindra-stone` in the
  inventory / recipe GUI; (2) the carbothermic furnace icon reads as a hot reduction
  furnace (ember pour, carbon charge band) and sits in the one-family brushed-steel
  style; (3) the placed furnace shows the bespoke sprite (not the assembling-machine-3
  body) at a sane scale for its 3×3 footprint, with the soft shadow grounded; (4) the
  furnace's CO2 input pipe still connects and renders (the fluid box survived replacing
  the graphics_set).
