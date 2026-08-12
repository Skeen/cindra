-- The ambient THERMAL GRADE fill sprite (ci-nw0; supersedes the ci-7tl damage tint).
--
-- The runtime (scripts/damage-feedback.lua) draws this sprite screen-filling and
-- character-anchored via the rendering API, and re-tints it continuously from the
-- player's position on the hot-cold axis: a warm ORANGE wash sunward of the temperate
-- band, a cool BLUE wash nightward, nothing at all in between. It is a plain white
-- fill TINTED at draw time, so ONE sprite serves both hues at every depth -- and the
-- alpha the runtime supplies is deliberately low (capped at 0.22), because this is a
-- gentle colour GRADE, not the opaque damage overlay it replaces. Drawn on the
-- `cursor` render layer (over the world, under the GUI) and scaled huge so it covers
-- the viewport at any zoom.
--
-- 🚨 A `sprite` prototype only: it adds NOTHING to any entity and changes no other
-- planet. The runtime that uses it is scoped to `surface.name == "cindra"`, and it
-- applies no damage of any kind.

data:extend({
  {
    type = "sprite",
    name = "cindra-thermal-grade",
    filename = "__core__/graphics/white-square.png",
    size = 10,
    flags = { "no-crop" },
  },
})
