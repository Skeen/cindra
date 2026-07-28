-- Cindra's own terrain tiles (§4, §15-2; ci-3yl real-map-gen rewrite).
--
-- The ribbon's ground is painted by REAL noise-driven map-gen, not a script. Each
-- band is a NEW `cindra-*` tile cloned from a vanilla tile purely for its art, then
-- given a Cindra noise-expression autoplace (scripts/terrain.lua) keyed to the
-- perpendicular ribbon axis. We enable ONLY these tiles in the Cindra map-gen
-- (prototypes/planet.lua), so NO vanilla / Nauvis tile (no grass, no water) is ever
-- a placement candidate -- the "zero nauvis terrain leakage" requirement.
--
-- 🚨 We CLONE (deep-copy) the vanilla tiles; we never enable or mutate the shared
-- vanilla prototype, so no other planet's terrain changes. Every clone is made
-- BUILDABLE + WALKABLE (ground collision), including the lethal lava/ice edges:
-- that is what lets a machine be built on a damaging tile (and take damage), the
-- "tile that damages everything on it" the design calls for. Lethality itself is
-- applied at runtime by scripts/tile-damage.lua (there is no native per-tick
-- damaging-tile field in the engine); the tiles just define WHERE it is lethal.

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

-- One cindra-* tile per zone in the hot->cold gradient (scripts/terrain.lua
-- M.ZONES). Each borrows a vanilla tile's art but carries its OWN noise-expression
-- autoplace keyed to the per-zone width layout (ci-a35); the widths come from the
-- mod settings, read inside terrain.probability_expr.
local tiles = {}
for i, spec in ipairs(terrain.ZONES) do
  local src = data.raw.tile[spec.clone_from]
  if not src then
    error("cindra tiles: missing clone source tile " .. tostring(spec.clone_from))
  end
  local t = util.table.deepcopy(src)
  t.name = spec.name
  t.subgroup = "cindra-tiles"
  t.order = string.format("a[cindra]-%02d[%s]", i, spec.key)
  t.localised_name = { "tile-name." .. spec.name }
  -- Every Cindra tile is buildable + walkable ground. The lethal edges stay
  -- ground (not impassable lava/water) precisely so machines can be placed on
  -- them and be damaged; the void beyond the ribbon is the impassable backstop.
  t.collision_mask = tile_collision_masks.ground()
  -- The clone carries its own noise-expression autoplace keyed to the ribbon axis.
  t.autoplace = { probability_expression = terrain.probability_expr(spec.name) }
  t.layer = base_layer + i
  -- A cloned fluid tile (lava) would otherwise behave like a liquid (unbuildable,
  -- offshore-pump target). Strip the fluid so it is solid, buildable lethal ground.
  t.fluid = nil
  -- Do not force neighbour adjacency on the vanilla tiles we no longer place, and
  -- do not silently vanish dropped items on a now-buildable tile.
  t.allowed_neighbors = nil
  t.destroys_dropped_items = nil
  t.default_destroyed_dropped_item_trigger = nil
  tiles[#tiles + 1] = t
end

data:extend(tiles)
