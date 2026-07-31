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
| Electrolysis cell ⭐        | `icons/oxidizer-icon.png` (Hurricane046, CC-BY 4.0) | ✔ `entity/electrolysis-cell/` (oxidizer, CC-BY 4.0) | **ci-txh** (signature aluminium); art **ci-wfv** → **ci-a6z** (oxidizer swap, 4x4 box) |
| Arc furnace (iron recovery) | `icons/arc-furnace-icon.png` (Hurricane046, CC-BY) | ✔ `entity/arc-furnace/` (arc-furnace, CC-BY) | **ci-hs1j** — set freed by **ci-a6z**; wired to `cindra-arc-furnace` (renamed from carbothermic furnace) |
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
art first wired in ci-wfv -- Hurricane046's "arc furnace" set -- then reassigned
in ci-a6z to Hurricane046's "oxidizer" set, CC-BY 4.0, converted to RGBA, on an
enlarged 4x4 box; see `entity/electrolysis-cell/ATTRIBUTION.md`). The arc-furnace
set it vacated was moved to `entity/arc-furnace/` and is reserved for the
iron-recovery building (ci-hs1j), so the two machines never both claim it.
Priority buildings
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
now wears Hurricane046's "oxidizer" building art (CC-BY 4.0, reassigned from the
"arc furnace" set in ci-a6z; see `entity/electrolysis-cell/ATTRIBUTION.md`).

## Red-mud subsystem art (ci-c7j → bespoke ci-zdp → arc-furnace building ci-hs1j)

The Bayer/iron-recovery subsystem (`prototypes/red-mud.lua`) ships **bespoke**
item art (ci-zdp), replacing the ci-c7j placeholders (which reused the
`cindra-stone` render under a tint). The iron-recovery **building** wears the
arc-furnace model (ci-hs1j), replacing both the ci-c7j assembling-machine-3 clone
art and ci-zdp's interim procedural carbothermic-furnace sprite.

**Item icons** are Blender renders from Malcolm Riley's
[`unused-renders`](https://github.com/malcolmriley/unused-renders) — **CC-BY-4.0,
author Malcolm Riley** (the durable attribution for both files below). Each was
downloaded from the repo above and resized from its 1024×1024 original to a 64×64
RGBA icon; no other edit was made to the pixels. Red mud additionally carries an
in-prototype rust-red tint (not baked into the file), the same trick the spent
catalysts use. The iron-recovery **building** wears Hurricane046's animated "arc
furnace" set (see the asset table at the top of this file); ci-zdp's procedural
carbothermic-furnace icon + sprite were **retired** in ci-hs1j when the building
was renamed/reskinned to the arc-furnace model (mayor Option A: model/name/art
only; the CO2 recipe + economy are unchanged).

| Cindra item / building        | Delivered art                                                     | Source                                          | Wired by |
|-------------------------------|-------------------------------------------------------------------|-------------------------------------------------|----------|
| `cindra-red-mud`              | `icons/cindra-red-mud.png` (+ in-engine rust tint)                | `item/original/pile-dust-crushed-iron-ore-1.png`| `prototypes/red-mud.lua` |
| `cindra-slag`                 | `icons/cindra-slag.png`                                           | `item/original/material-chunk-slag-1.png`       | `prototypes/red-mud.lua` |
| `cindra-arc-furnace`          | `icons/arc-furnace-icon.png` + `entity/arc-furnace/` (animated)   | Hurricane046, CC-BY (freed by ci-a6z)           | `prototypes/red-mud.lua` |

Iron is the vanilla `iron-plate` (no new icon needed). The arc furnace's set is
wired as its `graphics_set.animation` (animated body + shadow + additive emission
glow), fully replacing the assembling-machine-3 art, so no vanilla sprite leaks
through. The slag vent recipe and the red-mud tech reuse the two new item icons
(slag / red-mud respectively).

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
