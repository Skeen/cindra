-- Overload-damage effect (ci-clf; VFX replaced by ci-sz8q; DESIGN.md §5
-- "undisposed surplus damages the panels producing it"). The disposal-deficit
-- rule (scripts/panels.lua) degrades a solar panel silently -- a playtest
-- reported you cannot SEE which panels are burning up from an unabsorbed flare.
-- This is the missing VISUAL: a one-shot effect that pops on a panel the instant
-- it takes overload damage.
--
-- WHY AN EXPLOSION ENTITY (not a persistent render object): an `explosion` plays
-- its animation ONCE and then destroys itself, so a one-shot pulse needs no
-- storage tracking, no per-tick cleanup, and no lifetime bookkeeping -- the engine
-- reaps it. scripts/panels.lua just `create_entity`s one per damaged panel during
-- the damage sweep (which is already gated to `surface.name == "cindra"`, so no
-- other planet ever sees one).
--
-- ART (ci-sz8q): the vanilla ACCUMULATOR DISCHARGE effect --
-- `accumulator-discharge.png`, the 24-frame glow the game already plays over an
-- accumulator dumping its charge back into the grid. Playtest called the previous
-- art (the re-tinted `sparks-0x.png` electric-arc sheets, ci-clf / ci-vx3ge) bad,
-- and the discharge glow reads far better here: it is the game's OWN visual
-- vocabulary for "too much power moving through this building", which is exactly
-- what an overloading panel is doing. We take the discharge GLOW LAYER ONLY, not
-- the accumulator body underneath it, so the effect overlays the panel rather than
-- drawing a second building on top of it.
--
-- REUSE, don't mutate: this is a NEW prototype referencing a __base__ art file; it
-- clones nothing and touches no vanilla prototype, so the
-- never-mutate-other-planets invariant holds trivially. The graphics-audit guard
-- (prototypes/graphics-audit.lua) does not audit `explosion` types, so the
-- vanilla-art reference here needs no skip entry.

local C = require("scripts.flare-config")

-- The vanilla accumulator-discharge glow, copied field-for-field from the base
-- game's `accumulator_discharge()` helper (base/prototypes/entity/entities.lua)
-- MINUS its accumulator-body layer: the effect, not the building. Frame geometry,
-- shift and scale must stay in step with the sheet or the animation tears.
local DISCHARGE = {
  filename = "__base__/graphics/entity/accumulator/accumulator-discharge.png",
  priority = "high",
  draw_as_glow = true,
  width = 174,
  height = 214,
  line_length = 6,
  frame_count = 24,
  shift = { -1 / 32, -21 / 32 },
  scale = 0.5,
}

data:extend({
  {
    type = "explosion",
    name = C.PANEL_SPARK,
    flags = { "not-on-map" },
    hidden = true,
    -- No map/tooltip presence: a purely cosmetic world effect.
    icons = {
      { icon = "__base__/graphics/icons/solar-panel.png" },
    },
    subgroup = "hit-effects",
    order = "cindra-a",
    height = 0,
    animations = { DISCHARGE },
  },
})
