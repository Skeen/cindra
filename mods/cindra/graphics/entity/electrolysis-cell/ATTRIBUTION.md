# Asset attribution

The electrolysis-cell building graphics in this directory
(`oxidizer-hr-animation-1.png`, `oxidizer-hr-emission-1.png`,
`oxidizer-hr-shadow.png`) and the matching icon
`../../icons/oxidizer-icon.png` are externally sourced. They are the "oxidizer"
set and are shipped here under the terms below.

> **History (ci-a6z):** the cell previously wore Hurricane046's "arc furnace"
> set. It was reassigned the "oxidizer" set (a bigger, bulbous machine that
> reads as a grand power sink and matches the enlarged 4x4 footprint), freeing
> the arc-furnace set for the iron-recovery building (bead **ci-hs1j**, now in
> `../arc-furnace/`).

| field   | value                                                              |
| ------- | ------------------------------------------------------------------ |
| Asset   | "oxidizer" building graphics + icon                                |
| Author  | Hurricane (https://mods.factorio.com/user/Hurricane046)            |
| Source  | Hurricane046's building set (as bundled in the Nullius Visual Overhaul) |
| License | CC-BY 4.0 (Creative Commons Attribution 4.0)                       |

CC-BY permits use and redistribution provided the author is credited, which the
credit line below satisfies, so this art is cleared for use in the mod.

The source PNGs were indexed/palette (PNG colour type 3) and the shadow was
grey+alpha (type 4); both render as a solid black box in Factorio. They were
converted to truecolour RGBA (type 6) with no other pixel edit (the same fix the
arc-furnace and glass-furnace sets needed, ci-8r6 / ci-wfv).

## Sheet geometry (load-bearing)

The animation and emission sheets are `2240x2560`, an **8x8 grid of 280x320-px
frames** = 64 cells, of which only the **first 60 are non-empty** (rows 0-6 full
+ the first 4 of row 7). `frame_count = 60`, `line_length = 8`; the trailing 4
empty cells are excluded so the machine never blinks out mid-cycle. The emission
sheet is opaque-black with bright arc openings, so it blends `additive` under
`draw_as_glow` (bare `draw_as_glow` would paint a black box, the ci-036 bug).

## Required credit (include verbatim)

> Thank you to Hurricane for the incredible custom graphics made for LL: core
> extractor, low gravity assembling machine, and arc furnace.
