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

The live orbital backdrop (`platform_surface_render_parameters.platform_backdrop`)
is drawn by Factorio's expansion-shaders pass, which is disabled on headless /
0-VRAM machines (see the note carried over from the Cindra tooling in
`scripts/screenshot-cindra.sh`). A headless in-engine capture therefore cannot
show the globe at all. The Cycles bake is the faithful, deterministic stand-in:
it is built from the exact same equirectangular maps the engine samples, so it
reads as the same planet, and it renders identically on any machine.

To regenerate everything (maps, bake, sprite, icon):

```bash
scripts/render-planet.sh
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
