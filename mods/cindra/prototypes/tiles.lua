-- Cindra's own terrain tiles (§4, §15-2; ci-3yl real-map-gen rewrite, ci-da2 zones).
--
-- The ribbon's ground is painted by REAL noise-driven map-gen, not a script. Each
-- concrete TILE (scripts/terrain.lua M.TILES, one per vanilla clone source) is a NEW
-- `cindra-<vanilla>` tile cloned from a vanilla tile purely for its art, then given
-- a Cindra noise-expression autoplace that mixes it into every ZONE it is a member
-- of, keyed to the perpendicular ribbon axis. We enable ONLY these tiles in the
-- Cindra map-gen (prototypes/planet.lua), so NO un-cloned vanilla / Nauvis tile is
-- ever a placement candidate -- the "zero nauvis terrain leakage" requirement.
--
-- 🚨 We CLONE (deep-copy) the vanilla tiles; we never enable or mutate the shared
-- vanilla prototype, so no other planet's terrain changes.
--
-- WALKABILITY (ci-da2): a per-TILE property. Every tile is made BUILDABLE + WALKABLE
-- ground EXCEPT the two lava tiles (lava-hot, lava), which keep their cloned lava
-- collision + fluid so they stay IMPASSABLE like Vulcanus lava. That makes zones 1+2
-- (pure lava) the impassable hot WALL, while zone 3 is mostly walkable crust with
-- occasional impassable lava hazards. Environmental DAMAGE is applied PER TILE at
-- runtime (scripts/tile-damage.lua reads terrain.tile_damage for the tile(s) under
-- an entity), so a machine sitting on hot ground or the ice cap burns/freezes and
-- one overlapping a lava tile burns -- keyed to the actual tile, not a coordinate.

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
  t.order = string.format("a[cindra]-%03d[%s]", i, spec.clone_from)
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
