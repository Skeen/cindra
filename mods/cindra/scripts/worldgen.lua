-- Cindra per-chunk world generation (§4 ribbon geometry, §15 item 2 + bootstrap).
--
-- Three jobs as each chunk generates on a Cindra surface:
--   1. HARD-WALL BACKSTOP (§15-2 / §4 Impl B): tiles at or beyond `wall_at`
--      perpendicular distance become out-of-map, so the playable world is a
--      finite-width RIBBON (constrained on the sunward-nightward axis, infinite
--      along the ribbon). The gradient damage (scripts/edge-damage.lua) is the
--      teacher; this void is the bulletproof floor so the player can never walk
--      off the usable map into instant death.
--   2. TERRAIN GRADIENT (§4 tile layers): paint each tile from its perpendicular
--      coordinate (scripts/terrain.lua) so the VISIBLE ground IS the hot-cold
--      axis -- molten lava tiles on the hot edge, ice on the cold edge, temperate
--      land at the ribbon. The tiles line up with the fire/freeze damage zone.
--   3. BOOTSTRAP-ROCK SCATTER (§6): finite, hand-gathered rocks around the
--      terminator, the landing-tier trickle of metal. Placement is DETERMINISTIC
--      (a coordinate hash, not math.random) so it is reproducible, testable, and
--      never desyncs in multiplayer -- but NATURALLY SCATTERED: rocks are jittered
--      off the sampling grid and clumped by a smooth noise field, so there is no
--      visible lattice.
--
-- Which world axis is "hot vs cold" is the ORIENTATION (scripts/axis.lua): the
-- default is vertical (ribbon runs N-S, hot on the LEFT / west). Every job below
-- reads the perpendicular coordinate from axis.perp, so both orientations are
-- correct and nothing re-derives the gradient direction.
--
-- The mineable RESOURCES (stone / ice / volatiles) are NOT placed here: they use
-- NATIVE Factorio resource autoplace (prototypes/resources.lua) so they form
-- natural spot-noise PATCHES with real map-gen sliders, band-masked to the ribbon.
-- The rocks stay script-scattered because they are simple-entities, not a resource
-- (and must stay finite, per §6 -- no ore/coal patches anywhere).
--
-- 🚨 Scoped to `surface.name == "cindra"`. Resources are Cindra-exclusive
-- `cindra-*` prototypes; the painted terrain REUSES vanilla Vulcanus/Aquilo tiles
-- (read, never mutated) via set_tiles, so no vanilla prototype is changed.

local ribbon = require("scripts.ribbon")
local field = require("scripts.resource-field")
local axis = require("scripts.axis")
local terrain = require("scripts.terrain")

local M = {}

-- Sampling grid pitch: one placement is CONSIDERED per STEP*STEP cell. The rock
-- never SITS on this grid though -- it is jittered across the whole cell (M.JITTER)
-- so the grid is an invisible sampling lattice, not a visible one. Coarser = sparser.
M.STEP = 6
-- Base probability a cell yields a rock, before clustering (0..1): sparse scatter,
-- a finite bootstrap trickle, not a patch. (tune)
M.ROCK_CHANCE = 0.05
-- Per-rock position jitter: a placed rock is offset up to +/-JITTER tiles on each
-- axis from its cell center, so rocks never share a fixed spacing (kills the grid).
M.JITTER = M.STEP / 2
-- Clustering wavelength: rock density is modulated by a smooth value-noise field at
-- this pitch, so rocks clump irregularly instead of sprinkling uniformly. (tune)
M.CLUSTER_STEP = 48

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

-- Smooth value-noise in [0,1] at a world point: a coarse CLUSTER_STEP lattice of
-- deterministic `frac` hashes, bilinearly blended with a smoothstep so density
-- varies in soft irregular clumps (no visible cell edges). Pure integer/float
-- maths, so it stays reproducible and multiplayer-safe like the rest of placement.
local function cluster_field(x, y)
  local g = M.CLUSTER_STEP
  local gx, gy = math.floor(x / g), math.floor(y / g)
  local fx, fy = x / g - gx, y / g - gy
  fx = fx * fx * (3 - 2 * fx)
  fy = fy * fy * (3 - 2 * fy)
  local h00 = frac(gx, gy, 7)
  local h10 = frac(gx + 1, gy, 7)
  local h01 = frac(gx, gy + 1, 7)
  local h11 = frac(gx + 1, gy + 1, 7)
  local top = h00 + (h10 - h00) * fx
  local bot = h01 + (h11 - h01) * fx
  return top + (bot - top) * fy
end

-- Void every tile at/over the wall so the ribbon is finite perpendicular. The
-- wall is on the PERPENDICULAR axis (X in the default vertical orientation), so
-- we test each tile's perp coordinate, not a raw row. Runs first so we never
-- place a resource on a tile we're about to remove.
function M.apply_hard_wall(surface, area, cfg)
  local wall = ribbon.resolve(cfg).wall_at
  local orient = axis.orientation()
  local x1, y1 = area.left_top.x, area.left_top.y
  local x2, y2 = area.right_bottom.x, area.right_bottom.y
  local void = {}
  for y = y1, y2 - 1 do
    for x = x1, x2 - 1 do
      if math.abs(axis.perp(x, y, orient)) >= wall then
        void[#void + 1] = { name = "out-of-map", position = { x, y } }
      end
    end
  end
  if #void > 0 then surface.set_tiles(void, true) end
end

-- The set of terrain tile names that actually exist in the running data, resolved
-- once. A mistyped / DLC-absent tile is skipped (never a crash), so the gradient
-- degrades gracefully rather than erroring a chunk.
local valid_tiles
local function tile_exists(name)
  if not valid_tiles then
    valid_tiles = {}
    for _, n in ipairs(terrain.all_tiles()) do
      valid_tiles[n] = (prototypes and prototypes.tile and prototypes.tile[n]) ~= nil
    end
  end
  return valid_tiles[name] == true
end

-- Paint the hot-cold terrain gradient across the chunk: each tile becomes the
-- vanilla tile scripts/terrain.lua assigns to its perpendicular coordinate, so
-- the visible ground IS the temperature axis (lava hot edge -> temperate ribbon
-- -> ice cold edge). Tiles inside the wide safe band are left as natural land
-- (tile_for returns nil), keeping spawn buildable and recognizably temperate.
function M.paint_terrain(surface, area, cfg)
  local rcfg = ribbon.resolve(cfg)
  local orient = axis.orientation()
  local x1, y1 = area.left_top.x, area.left_top.y
  local x2, y2 = area.right_bottom.x, area.right_bottom.y
  local tiles = {}
  for y = y1, y2 - 1 do
    for x = x1, x2 - 1 do
      local name = terrain.tile_for(axis.perp(x, y, orient), rcfg)
      if name and tile_exists(name) then
        tiles[#tiles + 1] = { name = name, position = { x, y } }
      end
    end
  end
  if #tiles > 0 then surface.set_tiles(tiles, true) end
end

-- Placement takes an already-jittered FLOAT world position (see the scatter loop).
local function try_rock(surface, px, py)
  local pos = { x = px, y = py }
  if surface.can_place_entity({ name = field.ROCK, position = pos }) then
    surface.create_entity({ name = field.ROCK, position = pos })
  end
end

-- Scatter finite bootstrap rocks across the chunk, only within the terminator
-- scatter band (field.rock_zone). Each STEP*STEP cell is a SAMPLING point, not a
-- placement point: a winning cell drops its rock at a JITTERed offset across the
-- whole cell, and the win probability is modulated by a smooth clustering field --
-- so rocks land NATURALLY SCATTERED (no visible lattice), never on a fixed grid.
-- The mineable resources are placed by native autoplace (prototypes/resources.lua).
function M.place_bootstrap_rocks(surface, area, cfg)
  local orient = axis.orientation()
  local x1, y1 = area.left_top.x, area.left_top.y
  local x2, y2 = area.right_bottom.x, area.right_bottom.y
  -- Snap the sampling grid to global coords so the scatter is continuous across
  -- chunk borders (no seam, no doubled or dropped cells at chunk edges).
  local sx = x1 - (x1 % M.STEP)
  local sy = y1 - (y1 % M.STEP)
  for cy = sy, y2 - 1, M.STEP do
    if cy >= y1 then
      for cx = sx, x2 - 1, M.STEP do
        -- rock_zone reads the PERPENDICULAR coordinate, so rocks scatter only in
        -- the terminator (safe) band whichever axis the orientation makes
        -- perpendicular; that band already lies well inside the wall.
        if cx >= x1 and field.rock_zone(axis.perp(cx, cy, orient), cfg) then
          -- Clumping: density rides a smooth noise field, bounded so no stretch of
          -- band ever goes fully empty (0.4x in gaps, up to 1.6x in clumps; the
          -- field averages ~0.5, so the mean density -- and rock count -- is ~1x).
          local density = 0.4 + 1.2 * cluster_field(cx, cy)
          if frac(cx, cy, 4) < M.ROCK_CHANCE * density then
            -- Jitter off the sampling grid: independent [-JITTER, JITTER) offset
            -- per axis, so placed rocks fill the plane with no regular spacing.
            local jx = (frac(cx, cy, 5) - 0.5) * 2 * M.JITTER
            local jy = (frac(cx, cy, 6) - 0.5) * 2 * M.JITTER
            try_rock(surface, cx + 0.5 + jx, cy + 0.5 + jy)
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
  M.paint_terrain(event.surface, event.area, cfg)
  M.place_bootstrap_rocks(event.surface, event.area, cfg)
end

return M
