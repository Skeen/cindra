-- Cindra per-chunk world generation (§4 ribbon geometry, §15 items 2-3).
--
-- Two jobs as each chunk generates on a Cindra surface:
--   1. HARD-WALL BACKSTOP (§15-2 / §4 Impl B): tiles at or beyond `wall_at`
--      perpendicular distance become out-of-map, so the playable world is a
--      finite-width RIBBON (constrained on the sunward-nightward Y axis, infinite
--      east-west). The gradient damage (scripts/edge-damage.lua) is the teacher;
--      this void is the bulletproof floor so the player can never walk off the
--      usable map into instant death.
--   2. RESOURCE PLACEMENT (§15-3): stone / ice / volatiles / bootstrap rocks,
--      each in its band on the axis with the best nodes at the lethal margins,
--      per scripts/resource-field.lua (the pure geometry). Placement is
--      DETERMINISTIC (a coordinate hash, not math.random) so it is reproducible
--      and testable, and so it never desyncs in multiplayer.
--
-- 🚨 Scoped to `surface.name == "cindra"`. Everything is a Cindra-exclusive
-- `cindra-*` prototype; no vanilla resource or tile is mutated anywhere.

local ribbon = require("scripts.ribbon")
local field = require("scripts.resource-field")

local M = {}

-- Placement lattice: candidate node every STEP tiles. Coarser = sparser world.
M.STEP = 6
-- Per-band placement probability at a candidate lattice point (0..1). Tuned so
-- the ribbon feels resourced without paving it. All (tune).
M.STONE_CHANCE = 0.22
M.ICE_CHANCE = 0.22
M.VOLATILES_CHANCE = 0.16
M.ROCK_CHANCE = 0.05      -- sparse scatter (finite bootstrap trickle, not a patch)

local function is_cindra(surface)
  return surface and surface.valid and surface.name == "cindra"
end

local function ribbon_cfg()
  local s = settings and settings.startup
  if not s or not s["cindra-ribbon-safe-half-width"] then return nil end
  return {
    safe_half_width = s["cindra-ribbon-safe-half-width"].value,
    lethal_at = s["cindra-ribbon-lethal-at"].value,
    wall_at = s["cindra-ribbon-wall-at"].value,
  }
end

-- Deterministic pseudo-random fraction in [0,1) from integer tile coords, with a
-- `salt` so different resources draw independent streams (stone and rocks don't
-- always co-locate). Integer maths stays well under 2^53, so it is exact.
local function frac(x, y, salt)
  local h = (x * 49632 + y * 325176 + salt * 2606459) % 100000
  if h < 0 then h = h + 100000 end
  return h / 100000
end

-- Void every tile at/over the wall so the ribbon is finite perpendicular. Runs
-- first so we never place a resource on a tile we're about to remove.
function M.apply_hard_wall(surface, area, cfg)
  local wall = ribbon.resolve(cfg).wall_at
  local x1, y1 = area.left_top.x, area.left_top.y
  local x2, y2 = area.right_bottom.x, area.right_bottom.y
  local void = {}
  for y = y1, y2 - 1 do
    if math.abs(y) >= wall then
      for x = x1, x2 - 1 do
        void[#void + 1] = { name = "out-of-map", position = { x, y } }
      end
    end
  end
  if #void > 0 then surface.set_tiles(void, true) end
end

-- Try to place one resource node of `name`/`amount` at (x,y) if the tile can
-- host it (buildable land, not water/void, nothing already there).
local function try_resource(surface, x, y, name, amount)
  if amount <= 0 then return end
  local pos = { x = x + 0.5, y = y + 0.5 }
  if surface.can_place_entity({ name = name, position = pos }) then
    surface.create_entity({ name = name, position = pos, amount = amount })
  end
end

local function try_rock(surface, x, y)
  local pos = { x = x + 0.5, y = y + 0.5 }
  if surface.can_place_entity({ name = field.ROCK, position = pos }) then
    surface.create_entity({ name = field.ROCK, position = pos })
  end
end

-- Scatter resources across the chunk on the lattice, each in its own axis band.
function M.place_resources(surface, area, cfg)
  local wall = ribbon.resolve(cfg).wall_at
  local x1, y1 = area.left_top.x, area.left_top.y
  local x2, y2 = area.right_bottom.x, area.right_bottom.y
  -- Snap the lattice to global coords so it is continuous across chunk borders.
  local sx = x1 - (x1 % M.STEP)
  local sy = y1 - (y1 % M.STEP)
  for y = sy, y2 - 1, M.STEP do
    if math.abs(y) < wall and y >= y1 then
      for x = sx, x2 - 1, M.STEP do
        if x >= x1 then
          -- Each band draws an independent stream (distinct salt), so bands can
          -- overlap near the terminator (rocks + stone) without lockstep.
          local stone = field.stone_richness(y, cfg)
          if stone > 0 and frac(x, y, 1) < M.STONE_CHANCE then
            try_resource(surface, x, y, field.STONE, stone)
          end
          local ice = field.ice_richness(y, cfg)
          if ice > 0 and frac(x, y, 2) < M.ICE_CHANCE then
            try_resource(surface, x, y, field.ICE, ice)
          end
          local vol = field.volatiles_richness(y, cfg)
          if vol > 0 and frac(x, y, 3) < M.VOLATILES_CHANCE then
            try_resource(surface, x, y, field.VOLATILES, vol)
          end
          if field.rock_zone(y, cfg) and frac(x, y, 4) < M.ROCK_CHANCE then
            try_rock(surface, x, y)
          end
        end
      end
    end
  end
end

function M.on_chunk_generated(event)
  if not is_cindra(event.surface) then return end
  local cfg = ribbon_cfg()
  M.apply_hard_wall(event.surface, event.area, cfg)
  M.place_resources(event.surface, event.area, cfg)
end

return M
