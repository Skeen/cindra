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
