# Asset attribution

The "arc-furnace" building graphics in this directory
(`arc-furnace-hr-animation-1.png`, `arc-furnace-hr-emission-1.png`,
`arc-furnace-hr-shadow.png`) and the matching icons in
`../../icons/arc-furnace-icon.png` / `arc-furnace-icon-big.png` are externally
sourced. They are shipped here under the terms below.

> **Custody note (ci-a6z → ci-hs1j):** this set previously dressed the
> electrolysis cell. The cell now wears the "oxidizer" set (see
> `../electrolysis-cell/`), so the arc-furnace art was relocated to this neutral,
> model-named directory. **ci-hs1j wired it** onto the iron-recovery building
> (`cindra-arc-furnace`, renamed from the carbothermic furnace) via
> `prototypes/red-mud.lua`. See `../../ART-MANIFEST.md`.

| field   | value                                                              |
| ------- | ------------------------------------------------------------------ |
| Asset   | arc-furnace building graphics + icon                               |
| Author  | Hurricane (https://mods.factorio.com/user/Hurricane046)            |
| Source  | Custom graphics made for the "LL" mod                              |
| License | CC-BY (Creative Commons Attribution)                               |

CC-BY permits use and redistribution provided the author is credited, which the
credit line below satisfies, so this art is cleared for use in the mod.

The source PNGs were indexed/palette (PNG colour type 3) and the shadow was
grey+alpha (type 4); both render as a black box in Factorio. They were converted
to truecolour RGBA (type 6) with no other pixel edit (the same fix the
lava-manufacturer's glass-furnace set needed, ci-8r6).

## Derived work in this directory (ci-u92y)

`arc-furnace-hr-frozen.png` is **not** part of Hurricane's original set: the set
ships no frozen layer, and the furnace freezes for real on Cindra's nightside, so
one had to be authored. It is a **DERIVATIVE** of the body render above --
`scripts/gen-frost-layer.py` reads frame 0 of `arc-furnace-hr-animation-1.png`
and computes where rime would settle on it (up-facing surfaces, silhouette top
edges, patchy accretion), emitting a pale-blue ice patch masked to that body's
own silhouette. The generator is deterministic (`./scripts/render-frost-layer.sh`
reproduces it byte-for-byte).

CC-BY explicitly permits adaptations, provided the original author is credited --
which the credit line below does for this file too. The derived layer therefore
carries the SAME attribution and the SAME CC-BY terms as the body it is derived
from; it is not independent work and must not be re-credited as such.

## Required credit (include verbatim)

> Thank you to Hurricane for the incredible custom graphics made for LL: core
> extractor, low gravity assembling machine, and arc furnace.
