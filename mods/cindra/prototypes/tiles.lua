-- Cindra's own terrain tiles + the impassable ice cliff (§4, §15-2; ci-3yl real
-- map-gen, rewritten for the per-zone gradient in ci-a35).
--
-- The ribbon's ground is painted by REAL noise-driven map-gen, not a script. Each
-- band (scripts/zones.lua) is a NEW `cindra-*` tile cloned from a vanilla tile
-- purely for its art, then given a Cindra noise-expression autoplace
-- (scripts/terrain.lua) keyed to the perpendicular ribbon axis. We enable ONLY
-- these tiles in the Cindra map-gen (prototypes/planet.lua), so NO vanilla /
-- Nauvis tile (no grass, no water) is ever a placement candidate -- the "zero
-- nauvis terrain leakage" requirement.
--
-- 🚨 We CLONE (deep-copy) the vanilla tiles; we never enable or mutate the shared
-- vanilla prototype, so no other planet's terrain changes. Every clone is made
-- BUILDABLE + WALKABLE (ground collision), including the lethal fire/ice bands:
-- that is what lets a machine be built on a damaging tile (and take damage), the
-- "tile that damages everything on it" the design calls for. Lethality itself is
-- applied at runtime by scripts/tile-damage.lua (there is no native per-tick
-- damaging-tile field); the tiles just define WHERE it is lethal.
--
-- The ICE CLIFF (ci-a35) is a Cindra-exclusive clone of the vanilla cliff, tinted
-- icy, placed by the map-gen's cliff_settings along the rough-ice / smooth-ice
-- boundary as a CONTINUOUS impassable wall (prototypes/planet.lua + noise.lua).

local util = require("util")
local terrain = require("scripts.terrain")
local tile_collision_masks = require("__base__.prototypes.tile.tile-collision-masks")

-- The item-subgroup the Cindra tiles sit in (under the vanilla "tiles" group),
-- so they list cleanly in Factoriopedia alongside the other planets' tiles.
data:extend({
  { type = "item-subgroup", name = "cindra-tiles", group = "tiles", order = "z[cindra]" },
})

-- Distinct render layers so no two Cindra tiles share one (avoids ambiguous tile
-- draw ordering); the exact values only matter relative to each other.
local base_layer = 60

local tiles = {}
for i, spec in ipairs(terrain.TILES) do
  local src = data.raw.tile[spec.clone_from]
  if not src then
    error("cindra tiles: missing clone source tile " .. tostring(spec.clone_from))
  end
  local t = util.table.deepcopy(src)
  t.name = spec.name
  t.subgroup = "cindra-tiles"
  -- Order by the zone's hot->cold position, then variant, for Factoriopedia.
  t.order = string.format("a[cindra]-%02d[%s]", spec.order_key, spec.name)
  t.localised_name = { "tile-name." .. spec.name }
  -- Every Cindra tile is buildable + walkable ground. The lethal bands stay ground
  -- (not impassable lava/water) precisely so machines can be placed on them and be
  -- damaged; the void beyond the ribbon is the impassable backstop.
  t.collision_mask = tile_collision_masks.ground()
  -- The clone carries its own noise-expression autoplace keyed to the ribbon axis.
  t.autoplace = { probability_expression = terrain.probability_expr(spec.name) }
  t.layer = base_layer + i
  -- A cloned fluid tile (lava / lava-hot) would otherwise behave like a liquid
  -- (unbuildable, offshore-pump target). Strip the fluid so it is solid, buildable
  -- lethal ground.
  t.fluid = nil
  -- Do not force neighbour adjacency on the vanilla tiles we no longer place, and
  -- do not silently vanish dropped items on a now-buildable tile.
  t.allowed_neighbors = nil
  t.destroys_dropped_items = nil
  t.default_destroyed_dropped_item_trigger = nil
  tiles[#tiles + 1] = t
end

data:extend(tiles)

-- The ICE CLIFF wall (ci-a35): a Cindra-exclusive clone of the vanilla cliff so
-- it reads as a sheer wall, tinted icy (bespoke ice-cliff art is a later pass --
-- see PLAYTEST.md). It is IMPASSABLE (inherits the cliff collision), placed by the
-- map-gen's cliff_settings (prototypes/planet.lua) along a single continuous
-- contour at the rough-ice / smooth-ice boundary. We deep-copy so the vanilla
-- cliff is never mutated (no other planet changes).
local ice_cliff = util.table.deepcopy(data.raw.cliff["cliff"])
ice_cliff.name = "cindra-ice-cliff"
ice_cliff.map_color = { r = 0.62, g = 0.90, b = 0.98 } -- pale frost-cyan, like the ice field
ice_cliff.localised_name = { "entity-name.cindra-ice-cliff" }
-- Deconstructing/removing an ice cliff still uses cliff explosives like any cliff;
-- keep the inherited behaviour. The cliff must NOT deconstruct-alternative to the
-- vanilla "cliff" (which is not placed here); point it at itself.
ice_cliff.deconstruction_alternative = nil
data:extend({ ice_cliff })
