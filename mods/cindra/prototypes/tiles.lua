-- Cindra's own terrain tiles (§4, §15-2; ci-3yl real-map-gen rewrite, ci-da2 zones).
--
-- The ribbon's ground is painted by REAL noise-driven map-gen, not a script. Each
-- ZONE (scripts/terrain.lua) is a NEW `cindra-*` tile cloned from a vanilla tile
-- purely for its art, then given a Cindra noise-expression autoplace keyed to the
-- perpendicular ribbon axis. We enable ONLY these tiles in the Cindra map-gen
-- (prototypes/planet.lua), so NO vanilla / Nauvis tile (no grass, no water) is ever
-- a placement candidate -- the "zero nauvis terrain leakage" requirement.
--
-- 🚨 We CLONE (deep-copy) the vanilla tiles; we never enable or mutate the shared
-- vanilla prototype, so no other planet's terrain changes.
--
-- WALKABILITY (ci-da2): most zones are made BUILDABLE + WALKABLE ground, including
-- the walkable-but-lethal edges (lava-crust heat, deep-ice cold) so a machine can
-- be built on a damaging tile and take damage -- the "tile that damages everything
-- on it" the design calls for (lethality applied at runtime by
-- scripts/tile-damage.lua). The two HOT lava zones (hot-lava, lava) are the
-- exception: they keep their cloned lava collision + fluid so they are IMPASSABLE
-- like Vulcanus lava -- the hot backstop you cannot walk or build into.

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
for i, spec in ipairs(terrain.ZONES) do
  local src = data.raw.tile[spec.clone_from]
  if not src then
    error("cindra tiles: missing clone source tile " .. tostring(spec.clone_from))
  end
  local t = util.table.deepcopy(src)
  t.name = spec.name
  t.subgroup = "cindra-tiles"
  t.order = string.format("a[cindra]-%s[%s]", string.char(96 + i), spec.role)
  t.localised_name = { "tile-name." .. spec.name }
  t.layer = base_layer + i
  -- Override the inherited (muddy vanilla) map_color with Cindra's danger-zone
  -- gradient so the hot/cold lethal bands read as a coordinated coloured edge on
  -- the map view (ci-4h7). Set only on the clone -- the vanilla tile is untouched.
  t.map_color = terrain.map_color(spec.name)
  -- The clone carries its own noise-expression autoplace keyed to the ribbon axis
  -- (band widths come from the per-zone mod settings, read inside terrain.lua).
  t.autoplace = { probability_expression = terrain.probability_expr(spec.name) }

  if spec.walkable then
    -- Buildable + walkable ground. The lethal edges (lava-crust, deep-ice) stay
    -- ground precisely so machines can be placed on them and be damaged.
    t.collision_mask = tile_collision_masks.ground()
    -- A cloned fluid tile would otherwise behave like a liquid (unbuildable,
    -- offshore-pump target). Strip the fluid so it is solid, buildable ground.
    t.fluid = nil
    -- Do not force neighbour adjacency on the vanilla tiles we no longer place, and
    -- do not silently vanish dropped items on a now-buildable tile.
    t.allowed_neighbors = nil
    t.destroys_dropped_items = nil
    t.default_destroyed_dropped_item_trigger = nil
  else
    -- Impassable lava (hot-lava, lava): keep the cloned lava collision mask + fluid
    -- so it is unbuildable and blocks movement exactly like Vulcanus lava -- the
    -- hot backstop. Only the vanilla lava tiles are cloned here, so their fluid/
    -- collision are already the impassable ones; we leave them intact.
    t.collision_mask = tile_collision_masks.lava()
    t.allowed_neighbors = nil
  end

  tiles[#tiles + 1] = t
end

data:extend(tiles)
