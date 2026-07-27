# Cindra entity/building art — manifest (ci-pru)

First-pass ART for Cindra's signature buildings: **icons** (inventory / recipe /
GUI) and **in-world entity base sprites**. Generated deterministically by
`scripts/gen-entity-art.py` (orchestrated by `scripts/render-entity-art.sh`);
re-running reproduces byte-identical output (seed `0xC19D2A`).

**This is delivered art only.** Wiring the assets into prototypes is the owning
track's job — this bead did **not** edit any prototype file. Each row below
names the building, the file(s), and the owning bead/track that should wire it.

Art direction (planet_design.md §8/§10/§11/§12): fire/ice tension, industrial,
one visual family — a shared brushed-steel chassis with a coloured functional
core (hot = ember/orange, cold = cyan/ice, energy = violet). Readable at icon
size.

## Icon format

Every icon in `icons/` is a **120×64 RGBA mipmap strip** (base 64 + mips
32/16/8, laid out left-to-right). Wire with:

```lua
icon = "__cindra__/graphics/icons/<name>.png",
icon_size = 64,
icon_mipmaps = 4,
```

## Entity sprite format

`entity/<name>/<name>.png` is a **256×256** static single-frame HR sprite (3/4
top-down), with a matching `<name>-shadow.png` (soft projected ground shadow).
First-pass placeholders — a single frame, no directional/animation variants.
Suggested wiring (tune `scale`/`shift` to the entity footprint):

```lua
picture = {
  layers = {
    { filename = "__cindra__/graphics/entity/<name>/<name>.png",
      width = 256, height = 256, scale = 0.5, shift = {0, -0.3} },
    { filename = "__cindra__/graphics/entity/<name>/<name>-shadow.png",
      width = 256, height = 256, scale = 0.5, shift = {0.3, 0}, draw_as_shadow = true },
  },
}
```

## Asset → building → owning track

| Building / item            | Icon                              | Entity sprite | Owning bead(s)        |
|----------------------------|-----------------------------------|:-------------:|-----------------------|
| Electrolysis cell ⭐        | (v1: reused electric-furnace)     | (v1 reuse)    | **ci-txh** (signature aluminium); art **ci-wfv** |
| Aluminium (item)           | (v1: steel-plate, cool silver)    | —             | **ci-txh** |
| Lava-manufacture building  | `icons/lava-manufacturer.png`     | —             | **ci-8mw** (§15-5 lava recipe) |
| Ice crusher / processor    | `icons/ice-crusher.png`           | —             | **ci-rgv** (§15-4 ice processing) |
| Ice (item)                 | `icons/ice.png`                   | —             | **ci-rgv** / **ci-l72** (resources) |
| Cindra stone (item)        | `icons/cindra-stone.png`          | —             | **ci-l72** (§15-3 resources) |
| Electric heater            | `icons/electric-heater.png`       | —             | **ci-f5l** (§15-10 heater) |
| Mass driver                | `icons/mass-driver.png`           | ✔ `entity/mass-driver/`         | **ci-r10** (§15-11); PoC **ci-epp** |
| Capacitor (fast storage)   | `icons/capacitor.png`             | ✔ `entity/capacitor/`           | **ci-tii** (§15-9 storage) |
| Molten-salt battery (bulk) | `icons/molten-salt-battery.png`   | ✔ `entity/molten-salt-battery/` | **ci-tii** |
| Dissipator (heat sink)     | `icons/dissipator.png`            | ✔ `entity/dissipator/`          | **ci-tii** / **ci-9ay** (panel damage) |
| Cindra science pack        | `icons/cindra-science-pack.png`   | —             | **ci-3or** (§15-12 science/tech) |

⭐ = signature building (the aluminium electrolysis cell, ci-84s pivot; bespoke
art tracked in ci-wfv, v1 reuses the electric-furnace sprite). Priority buildings
(mass driver, flare-PoC storage/dissipator) all have both an icon and an entity
sprite. Cindra reuses the plain vanilla solar panel (ci-8al), so there is no
custom panel art.

## Scope / known limits (honest first pass)

- **Entity sprites are single static frames**, not directional or animated.
  Machines that want a working animation (e.g. electrolysis glow, driver charge
  cycle) should treat this as the idle base layer and add emission/animation
  layers later, or commission bespoke art. Filed as follow-up: see the bead.
- **Naming is provisional.** Rename files to match final prototype names before
  wiring if a track chooses different ids; the manifest maps intent, not a
  frozen contract.
- Regenerate everything with `./scripts/render-entity-art.sh` after any edit to
  `scripts/gen-entity-art.py` (deterministic).
