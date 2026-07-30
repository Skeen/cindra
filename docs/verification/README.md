# Cindra planet art: verification

![Static tidally-locked globe](cindra-static-globe.png)

`cindra-static-globe.png` is the Blender/Cycles bake of the Cindra planet, produced
by `scripts/bake-starmap.py` from the procedural equirectangular maps in
`mods/cindra/graphics/space/`. It is the same render that becomes the star-map
sprite (`mods/cindra/graphics/icons/starmap-planet-cindra.png`), shown here at
full 1024x1024 for inspection.

## What it verifies

- **Tidally locked, one face presented.** The molten **dayside** (left, white-hot
  at the sub-stellar limb, cooling to magma orange), a dark **terminator** seam
  down the centre, and the frozen **nightside** (right, blue ice). The fire/ice
  split is the whole planet identity (planet_design.md sections 1-4).
- **No rotation.** The star-map sprite is a static PNG, so it cannot spin. The
  live orbital backdrop is frozen the same way: `rotation_seconds` is set to an
  enormous value (`NO_ROTATION = 1e9`) in `prototypes/space-appearance.lua`, so
  the same face is presented permanently. Only the cloud (terminator steam band)
  and hero-flare layers animate, via `rotate_with_planet = false`.

## Why this bake and not an in-engine screenshot

The Cycles bake is the deterministic, machine-independent stand-in for the
star-map sprite: it is built from the exact same equirectangular maps the engine
samples, so it reads as the same planet and renders identically anywhere.

**Update (ci-6y9): the live orbital backdrop CAN now be captured headless.** The
old claim here was that Factorio's expansion-shaders pass is disabled on headless
/ 0-VRAM machines so an in-engine capture "cannot show the globe at all." That is
no longer true: the full client runs under `Xvfb` with software GL via **EGL +
llvmpipe** (the ci-036 / ci-ijk incantation, `SDL_VIDEO_FORCE_EGL=1`), which gets
a real GL context without a working GLX. `scripts/render-orbit.sh` uses that path
to drive `scenarios/orbit-shot` (a platform spawned in orbit of Cindra, then
`game.take_screenshot` of its surface) and produce the real orbital screenshots
below. The bake is still the canonical star-map sprite; the live backdrop is now
tunable against an actual engine render instead of blind.

To regenerate everything (maps, bake, sprite, icon):

```bash
scripts/render-planet.sh
```

---

# In-game orbital parity with the star-map icon (ci-6y9)

![Orbital backdrop before/after vs the star-map icon](ci-6y9-orbital-parity.png)

`ci-6y9-orbital-parity.png` is the before/after for tuning the LIVE orbital
backdrop (`platform_surface_render_parameters.platform_backdrop`, wired in
`prototypes/space-appearance.lua`) to read like the baked star-map icon. All
three panels are real, unedited renders:

- **BEFORE** and **AFTER** are ACTUAL in-engine orbital screenshots (headless
  Factorio under Xvfb + EGL/llvmpipe, `scripts/render-orbit.sh`) of a space
  platform in orbit of Cindra. The small chip near the centre is the platform's
  starter hub.
- **TARGET** is the baked star-map icon (`starmap-planet-cindra.png`), untouched
  by this bead.

## What it verifies

- **Single sun from the LEFT, blown-out molten limb.** The engine light was
  aimed near-HORIZONTAL from the left (matching the bake's perpendicular sun) and
  the emission scalar cranked so the sunward limb clips to near-WHITE like the
  icon's hot highlight, falling off through orange/red toward the terminator.
- **Deep-blue ICE nightside, not a warm void.** Before, the shadowed hemisphere
  read dark olive/brown. The engine has no cool world-ambient field like the
  Blender bake's, so the emission map's blue ice-side self-glow (kept
  independent of shadow) is scaled up to stand in for it, and the atmosphere rim
  turned cool blue: the ice now reads as the icon's deep blue.
- **Soft ~half-lit terminator, clean seam.** The heavy grey steam band was
  thinned and the grazing specular sheen dropped so the sandy transition strip
  no longer reads as a bright cream wall but as the icon's darker rocky
  terminator.

The tuned values are guarded off-game and under the real runtime
(`unit-tests/test_space_appearance.lua`, `tests/test_space_appearance.lua`:
"orbital parity"). To reproduce the screenshots:

```bash
scripts/render-orbit.sh   # writes orbit-close.png / orbit-wide.png to .orbit-render/script-output/
```

---

# Bootstrap rock: stone tint (ci-jvc)

![Rock stone-tint before/after](ci-jvc-rock-stone-tint.png)

`ci-jvc-rock-stone-tint.png` is the before/after for the warm "vanilla stone"
tint laid over the finite bootstrap **rocks** (`cindra-rock`, a deep-copy of the
vanilla `huge-rock`). **Left:** the stock huge-rock art (cool brown-grey rubble).
**Right:** the same variations under the `{1.0, 0.93, 0.62}` multiply-tint wired
in `prototypes/resources.lua` (value + rationale: `scripts/rock_tint.lua`). Both
are composited over the dark volcanic-soil colour of the Cindra terminator so the
legibility read is honest.

## What it verifies

- **Reads as yellowish STONE, not generic rubble.** Red stays full, green is
  trimmed a little and blue a lot, which pulls the brown-grey toward a warm
  sandstone gold while keeping the crevice depth (stronger blue cuts tip over
  into a muddy olive). This is the look ci-jvc asked for.
- **Still legible against Cindra terrain.** The rocks pop against the dark warm
  terminator soil in both states; the tint does not wash them into the ground.

## Why a faithful multiply, not an in-engine screenshot

The engine renders a `Sprite.tint` as a per-pixel multiply into the source
texture, so this PIL multiply of the exact vanilla source PNGs is pixel-faithful
to what the game draws (and unlike an FBSR render, which does not honour sprite
tint, it actually shows the shift). The remaining "does it feel like stone in
motion, against live terrain and lighting" read is the one thing a still cannot
judge -- that is the PLAYTEST.md entry.

To regenerate:

```bash
# calibrated in the ci-jvc spike; see the bead for the tint-sweep sheets
nix-shell -p "python3.withPackages(ps: with ps; [numpy pillow])" \
  --run "python3 scripts/render-rock-tint.py"
```
