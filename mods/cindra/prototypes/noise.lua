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

-- `cindra_cliff_elevation`: drives Vulcanus-style CLIFFS as terrain flavour in the
-- volcanic/rocky zones only (lava-crust .. scorched; ci-da2 cliff comment). Elevation
-- is pinned flat (no lakes), so cliffs cannot come from it; this SEPARATE cliff-
-- elevation field is 0 (no cliffs) everywhere EXCEPT the volcanic band, where it is a
-- medium-frequency basis-noise hump straddling the cliff threshold so the cliff system
-- draws scattered cliff segments along its contours. The building band, the impassable
-- lava walls and the icy cap stay flat -> cliff-free, so no zone is walled off and the
-- building area stays workable. Keyed to the SAME perpendicular axis as the tiles
-- (scripts/axis.lua), gated to the exact volcanic zone span (scripts/terrain.lua
-- M.cliff_band), so cliffs and the tile gradient share one geometry.
--
-- `cindra_decorative_peaks`: a smooth high-frequency peaks field (0..~1) that
-- modulates the zone-appropriate decorative scatter (ci-6fq, scripts/decorative-
-- field.lua) so the ice/snow and rock/crater decals CLUMP naturally instead of
-- spreading uniformly. Same multioctave formula Aquilo uses for its own decal
-- density ("do as Aquilo does"), but Cindra-owned so the decoratives never depend on
-- an Aquilo-internal named expression. Uses only core noise + map_seed, so it
-- evaluates on the Cindra surface with no Vulcanus/Aquilo biome inputs.
local axis = require("scripts.axis")
local terrain = require("scripts.terrain")
local cb = terrain.cliff_band()
local perp = axis.perp_expr()

-- Cliff threshold (must match planet.lua cliff_settings.cliff_elevation_0) and the
-- noise amplitude that makes the field cross it repeatedly inside the band.
local CLIFF_BASE = 8
local CLIFF_NOISE_AMP = 26
local CLIFF_NOISE_WL = 40

local cliff_mask = "(" .. perp .. " >= " .. cb.lo .. ") * (" .. perp .. " <= " .. cb.hi .. ")"
local cliff_field = "(" .. CLIFF_BASE .. " + basis_noise{x = x, y = y, seed0 = 1, seed1 = 42, " ..
  "input_scale = " .. string.format("%.6g", 1 / CLIFF_NOISE_WL) .. ", output_scale = " .. CLIFF_NOISE_AMP .. "})"

data:extend({
  {
    type = "noise-expression",
    name = "cindra_ribbon_elevation",
    expression = "50",
  },
  {
    type = "noise-expression",
    name = "cindra_cliff_elevation",
    expression = "(" .. cliff_mask .. ") * " .. cliff_field,
  },
  {
    type = "noise-expression",
    name = "cindra_decorative_peaks",
    expression = "abs(multioctave_noise{x = x, y = y, persistence = 0.85, seed0 = map_seed, seed1 = 1, octaves = 3, input_scale = 1/6})",
  },
})
