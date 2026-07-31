-- Overload-damage spark (ci-clf; DESIGN.md §5 "undisposed surplus damages the
-- panels producing it"). The disposal-deficit rule (scripts/panels.lua) degrades
-- a solar panel silently -- a playtest reported you cannot SEE which panels are
-- burning up from an unabsorbed flare. This adds the missing VISUAL: a short
-- electric arc that pops on a panel the instant it takes overload damage.
--
-- WHY AN EXPLOSION ENTITY (not a persistent render object): an `explosion` plays
-- its animation ONCE and then destroys itself, so a one-shot "zap" needs no
-- storage tracking, no per-tick cleanup, and no lifetime bookkeeping -- the engine
-- reaps it. scripts/panels.lua just `create_entity`s one per damaged panel during
-- the damage sweep (which is already gated to `surface.name == "cindra"`, so no
-- other planet ever sees a spark).
--
-- ART: the vanilla `sparks-0x.png` electric-arc sheets (base/graphics/entity/
-- sparks) -- the same 19-frame arc the game already uses for electrical sparking.
-- They read as "this thing is arcing" far more clearly than a static
-- accumulator-charge glow, and we tint them HOT (Cindra fire orange/white), NOT
-- Fulgora electric-blue -- the ice side must never read as Fulgora lightning
-- (PLAYTEST.md), so the overload cue stays in the planet's fire palette. Drawn as
-- a glow so it pops against the panel. The six sheets are registered as animation
-- VARIATIONS, so the engine picks one at random per spark and a damaged array
-- shimmers with varied arcs instead of one repeated frame.
--
-- REUSE, don't mutate: this is a NEW prototype referencing __base__ art files; it
-- clones nothing and touches no vanilla prototype, so the
-- never-mutate-other-planets invariant holds trivially. The graphics-audit guard
-- (prototypes/graphics-audit.lua) does not audit `explosion` types, so the empty
-- vanilla-spark reference here needs no skip entry.

local C = require("scripts.flare-config")

-- Hot Cindra-fire tint (orange-white), deliberately NOT Fulgora blue.
local SPARK_TINT = { r = 1.0, g = 0.82, b = 0.35, a = 1.0 }

-- The six vanilla electric-arc sheets, as animation variations. Dimensions match
-- the vanilla source (base/prototypes/entity/flying-robots.lua robot sparks); we
-- only re-tint them hot and slow the playback slightly so the arc reads as a
-- distinct "overload zap" rather than a one-frame flash.
local SPARK_SHEETS = {
  { file = "sparks-01.png", w = 39, h = 34, shift = { -0.109375, 0.3125 } },
  { file = "sparks-02.png", w = 36, h = 32, shift = { 0.03125, 0.125 } },
  { file = "sparks-03.png", w = 42, h = 29, shift = { -0.0625, 0.203125 } },
  { file = "sparks-04.png", w = 40, h = 35, shift = { -0.0625, 0.234375 } },
  { file = "sparks-05.png", w = 39, h = 29, shift = { -0.109375, 0.171875 } },
  { file = "sparks-06.png", w = 44, h = 36, shift = { 0.03125, 0.3125 } },
}

local animations = {}
for _, s in ipairs(SPARK_SHEETS) do
  animations[#animations + 1] = {
    filename = "__base__/graphics/entity/sparks/" .. s.file,
    draw_as_glow = true,
    width = s.w,
    height = s.h,
    frame_count = 19,
    line_length = 19,
    shift = s.shift,
    tint = SPARK_TINT,
    scale = 1.0,
    animation_speed = 0.5, -- 19 frames over ~38 ticks: a brief, readable zap
  }
end

data:extend({
  {
    type = "explosion",
    name = C.PANEL_SPARK,
    flags = { "not-on-map" },
    hidden = true,
    -- No map/tooltip presence: a purely cosmetic world effect.
    icons = {
      { icon = "__base__/graphics/icons/solar-panel.png", tint = SPARK_TINT },
    },
    subgroup = "hit-effects",
    order = "cindra-a",
    height = 0,
    animations = animations,
  },
})
