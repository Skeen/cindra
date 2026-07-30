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

-- NO `cindra_cliff_elevation` (ci-qqt): the ci-da2 world drove Vulcanus-style CLIFFS as
-- terrain flavour in the volcanic zones via a separate cliff-elevation field. The thin
-- 128-tile functional ribbon (ci-qqt) has no room for cliffs -- a cliff walls the narrow
-- traversable band, and the engine strips any cliff placed in the walkable ribbon (an
-- in-engine measurement on the thinned world found ZERO cliffs survive in the volcanic
-- band) -- so the cliff field is gone and the ribbon is flat/cliff-free. (terrain.cliff_band
-- survives only as the volcanic-tile band geometry the burned-rock autoplace reads, not a
-- cliff driver.) A bespoke thin-ribbon cliff treatment is deferred to ci-70r.
--
-- `cindra_decorative_peaks`: a smooth high-frequency peaks field (0..~1) that
-- modulates the zone-appropriate decorative scatter (ci-6fq, scripts/decorative-
-- field.lua) so the ice/snow and rock/crater decals CLUMP naturally instead of
-- spreading uniformly. Same multioctave formula Aquilo uses for its own decal
-- density ("do as Aquilo does"), but Cindra-owned so the decoratives never depend on
-- an Aquilo-internal named expression. Uses only core noise + map_seed, so it
-- evaluates on the Cindra surface with no Vulcanus/Aquilo biome inputs.
data:extend({
  {
    type = "noise-expression",
    name = "cindra_ribbon_elevation",
    expression = "50",
  },
  {
    type = "noise-expression",
    name = "cindra_decorative_peaks",
    expression = "abs(multioctave_noise{x = x, y = y, persistence = 0.85, seed0 = map_seed, seed1 = 1, octaves = 3, input_scale = 1/6})",
  },
})
