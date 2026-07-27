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

data:extend({
  {
    type = "noise-expression",
    name = "cindra_ribbon_elevation",
    expression = "50",
  },
})
