-- Cindra map-gen named noise expressions (§4, §15-2; ci-3yl).
--
-- The Cindra planet drives its map generation through NAMED NOISE EXPRESSIONS via
-- map_gen_settings.property_expression_names (prototypes/planet.lua), the same
-- mechanism the vanilla planets use. The organic ribbon tile bands are noise
-- expressions on the tiles themselves (scripts/terrain.lua); this file supplies
-- the generic terrain property Cindra overrides.
--
-- `cindra_ribbon_elevation`: a FLAT positive elevation everywhere. Cindra is all
-- dry land -- a molten dayside and frozen nightside leave no room for lakes -- so
-- pinning elevation to a constant land value guarantees the map-gen never carves
-- water or lakes from a Nauvis-style elevation field, on any map-gen setting. The
-- finite perpendicular bound (the void backstop) is the map-gen's own `width` /
-- `height`, not an elevation trough (Factorio has no elevation->void mapping).

local terrain = require("scripts.terrain")

data:extend({
  {
    type = "noise-expression",
    name = "cindra_ribbon_elevation",
    expression = "50",
  },
  -- ICE CLIFF wall (ci-a35). `cindra_cliff_elevation` is a LINEAR RAMP across the
  -- perpendicular axis, zero exactly on the rough-ice / smooth-ice boundary
  -- (scripts/terrain.cliff_elevation_expr). The planet's cliff_settings place a
  -- cliff on every contour cliff_elevation = cliff_elevation_0 + n*interval; with
  -- cliff_elevation_0 = 0 and an interval bigger than the whole map (see
  -- prototypes/planet.lua), the ONLY in-map contour is the boundary itself -- so a
  -- single cliff line runs continuously along the ribbon's long axis.
  {
    type = "noise-expression",
    name = "cindra_cliff_elevation",
    expression = terrain.cliff_elevation_expr(),
  },
  -- A high CONSTANT cliffiness so the wall is GAPLESS (the vanilla cliffiness
  -- deliberately opens passages; the ice cliff is an impassable backstop, so we
  -- suppress the gaps). 10 matches the vanilla "cliff present" value.
  {
    type = "noise-expression",
    name = "cindra_cliffiness",
    expression = "10",
  },
})
