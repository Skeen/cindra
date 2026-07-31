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
| Electrolysis cell ⭐        | `icons/arc-furnace-icon.png` (Hurricane046, CC-BY) | ✔ `entity/electrolysis-cell/` (arc-furnace, CC-BY) | **ci-txh** (signature aluminium); art **ci-wfv** |
| Aluminium (item)           | (v1: steel-plate, cool silver)    | —             | **ci-txh** |
| Lava-manufacture building  | `icons/lava-manufacturer.png`     | —             | **ci-8mw** (§15-5 lava recipe) |
| ~~Ice crusher / processor~~ | (retired ci-9l6)                 | —             | **ci-rgv** → retired: ice fields mine ice+calcite directly, no ground crusher |
| Ice (item)                 | `icons/ice.png`                   | —             | **ci-rgv** / **ci-l72** (resources) |
| Cindra stone (item)        | `icons/cindra-stone.png`          | —             | **ci-l72** (§15-3 resources) |
| Electric heater            | `icons/electric-heater.png`       | —             | **ci-f5l** (§15-10 heater) |
| Mass driver                | `icons/mass-driver.png`           | ✔ `entity/mass-driver/`         | **ci-r10** (§15-11); PoC **ci-epp** |
| Capacitor (fast storage)   | `icons/capacitor.png`             | ✔ `entity/capacitor/`           | **ci-tii** (§15-9 storage) |
| Molten-salt battery (bulk) | `icons/molten-salt-battery.png`   | ✔ `entity/molten-salt-battery/` | **ci-tii** |
| Dissipator (heat sink)     | `icons/dissipator.png`            | ✔ `entity/dissipator/`          | **ci-tii** / **ci-9ay** (panel damage) |
| Cindra science pack        | `icons/cindra-science-pack.png`   | —             | **ci-3or** (§15-12 science/tech) |

⭐ = signature building (the aluminium electrolysis cell, ci-84s pivot; bespoke
art wired in ci-wfv -- Hurricane046's "arc furnace" set, CC-BY, converted to RGBA;
see `entity/electrolysis-cell/ATTRIBUTION.md`). Priority buildings
(mass driver, flare-PoC storage/dissipator) all have both an icon and an entity
sprite. Cindra reuses the plain vanilla solar panel (ci-8al), so there is no
custom panel art.

## Materials/petrochemical item + fluid icons (ci-6vj S6)

**Source:** [`malcolmriley/unused-renders`](https://github.com/malcolmriley/unused-renders)
(Blender renders released by the author for reuse).
**License:** [Creative Commons Attribution 4.0 International (CC-BY-4.0)](https://creativecommons.org/licenses/by/4.0/).
**Author / attribution:** Malcolm Riley.

Per the CC-BY-4.0 terms, this attribution is the durable credit for every icon
listed below. Each render was downloaded from the repo above and resized from its
1024x1024 original to a 64x64 RGBA icon in `icons/`; no other edit was made to the
pixels (in-engine tints on the two *spent* catalysts are applied in the prototype,
not baked into the file). Wire with `icon = "__cindra__/graphics/icons/<name>.png",
icon_size = 64`.

| Cindra item / fluid            | Icon file                          | Source render (in the repo)                     | Wired by |
|--------------------------------|------------------------------------|-------------------------------------------------|----------|
| `cindra-hydrogen` (fluid)      | `icons/cindra-hydrogen.png`        | `fluid/original/molecule-hydrogen.png`          | `prototypes/plastics.lua` |
| `cindra-oxygen` (fluid)        | `icons/cindra-oxygen.png`          | `fluid/original/molecule-oxygen.png`            | `prototypes/plastics.lua` |
| `cindra-carbon-dioxide` (fluid)| `icons/cindra-carbon-dioxide.png`  | `fluid/original/molecule-carbon-dioxide.png`    | `prototypes/plastics.lua` |
| `cindra-methanol` (fluid)      | `icons/cindra-methanol.png`        | `fluid/original/molecule-methanol.png`          | `prototypes/plastics.lua` |
| `cindra-quicklime`             | `icons/cindra-quicklime.png`       | `item/original/material-quicklime-1.png`        | `prototypes/plastics.lua` |
| `cindra-methanol-catalyst`     | `icons/cindra-methanol-catalyst.png` | `item/original/pile-metal-dust-copper-1.png`  | `prototypes/plastics.lua` |
| `cindra-spent-methanol-catalyst` | `icons/cindra-spent-methanol-catalyst.png` | `item/original/scrap-metal-copper-1.png` | `prototypes/plastics.lua` (greyed tint) |
| `cindra-zeolite-catalyst`      | `icons/cindra-zeolite-catalyst.png` | `item/original/pile-crystal-zeolite-catalyst-1.png` | `prototypes/plastics.lua` |
| `cindra-spent-zeolite-catalyst`| `icons/cindra-spent-zeolite-catalyst.png` | `item/original/pile-crystal-zeolite-catalyst-3.png` | `prototypes/plastics.lua` (greyed tint) |
| `cindra-alumina`               | `icons/cindra-alumina.png`         | `item/original/pile-chunk-silica-gel-1.png`     | `prototypes/aluminium.lua` |
| `cindra-aluminium`             | `icons/cindra-aluminium.png`       | `item/original/metal-plate-aluminium.png`       | `prototypes/aluminium.lua` |
| `cindra-aluminium-powder`      | `icons/cindra-aluminium-powder.png`| `item/original/pile-dust-aluminium-1.png`       | `prototypes/mass-driver.lua` |

These replaced the earlier tinted-vanilla placeholders (petroleum-gas / water /
calcite / copper-plate / steel-plate). The aluminium electrolysis **cell** entity
now wears Hurricane046's "arc furnace" building art (CC-BY, wired in ci-wfv; see
`entity/electrolysis-cell/ATTRIBUTION.md`).

## Red-mud subsystem art (ci-c7j) — v1 placeholders

The Bayer/iron-recovery subsystem (`prototypes/red-mud.lua`) ships **placeholder**
art for v1; bespoke renders are a follow-up (cf. ci-eb9). To avoid any vanilla
placeholder leaking in, the two new items reuse the bespoke `cindra-stone` render
under an in-prototype tint, and the furnace reuses its assembling-machine clone
art. The **intended** bespoke sources below are again from Malcolm Riley's
[`unused-renders`](https://github.com/malcolmriley/unused-renders) (CC-BY-4.0,
author Malcolm Riley) — the durable attribution for when they are wired.

| Cindra item / building        | v1 placeholder                                   | Intended bespoke source (unused-renders)        | Wired by |
|-------------------------------|--------------------------------------------------|-------------------------------------------------|----------|
| `cindra-red-mud`              | `icons/cindra-stone.png` + reddish tint          | `item/original/pile-mud-1.png` (red-tinted)     | `prototypes/red-mud.lua` |
| `cindra-slag`                 | `icons/cindra-stone.png` + dark-grey tint        | `item/original/pile-slag-1.png`                 | `prototypes/red-mud.lua` |
| `cindra-carbothermic-furnace` | (v1: reused assembling-machine-3 art)            | bespoke reduction-furnace render                | `prototypes/red-mud.lua`; art follow-up ci-eb9 |

Iron is the vanilla `iron-plate` (no new icon needed). The furnace entity passes
the graphics audit via its assembler-clone sprite; bespoke building art is the
same ci-eb9 follow-up.

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
