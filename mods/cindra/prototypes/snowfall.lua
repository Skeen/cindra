-- The ICY-SIDE SNOWFALL flake sprite (ci-mk5y, the ci-wly epic's "consider snow-fall only
-- on the icy side").
--
-- The runtime (scripts/snowfall.lua) draws a drifting field of these, one render object per
-- flake, over the frozen half of the ribbon only -- so the nightside reads as actively
-- snowing while the lava side stays clear. Each flake is drawn small and semi-transparent
-- at its own scale/alpha, so the field reads as fine snow rather than a row of dots.
--
-- v1 art: the stock white square, tinted and scaled down at draw time -- the same
-- dependency-free approach the damage-feedback fill takes (prototypes/feedback.lua). A
-- bespoke flake sprite (a soft, slightly irregular flake) is an art/PLAYTEST follow-up.
--
-- 🚨 A `sprite` prototype only: it adds NOTHING to any entity and changes no other planet.
-- The runtime that draws it is scoped to `surface.name == "cindra"` AND to positions on the
-- icy side of the ribbon.

data:extend({
  {
    type = "sprite",
    name = "cindra-snowflake",
    filename = "__core__/graphics/white-square.png",
    size = 10,
    flags = { "no-crop" },
  },
})
