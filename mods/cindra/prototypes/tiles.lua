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

-- Ribbon geometry (startup settings, available at the data stage): the band noise
-- expressions read these so the tile bands line up with the damage axis.
local function ribbon_cfg()
  local s = settings.startup
  return {
    safe_half_width = s["cindra-ribbon-safe-half-width"].value,
    lethal_at = s["cindra-ribbon-lethal-at"].value,
    wall_at = s["cindra-ribbon-wall-at"].value,
  }
end
local CFG = ribbon_cfg()

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
  t.order = string.format("a[cindra]-%s[%s]", string.char(96 + i), spec.role)
  t.localised_name = { "tile-name." .. spec.name }
  -- Every Cindra tile is buildable + walkable ground. The lethal edges stay
  -- ground (not impassable lava/water) precisely so machines can be placed on
  -- them and be damaged; the void beyond the ribbon is the impassable backstop.
  t.collision_mask = tile_collision_masks.ground()
  -- The clone carries its own noise-expression autoplace keyed to the ribbon axis.
  t.autoplace = { probability_expression = terrain.probability_expr(spec.name, CFG) }
  t.layer = base_layer + i
  -- Override the inherited (muddy vanilla) map_color with Cindra's danger-zone
  -- gradient so the hot/cold lethal bands read as an alarming coloured edge on the
  -- map view (ci-4h7). Set only on the clone -- the vanilla tile is untouched.
  t.map_color = terrain.map_color(spec.name)
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
