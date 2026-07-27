-- Cindra per-chunk world generation (worldgen v2: §15 items 2-3, 6-7).
--
-- Three jobs as each chunk generates on a Cindra surface, all keyed to the ribbon
-- PERPENDICULAR axis (scripts/ribbon.lua, read via ribbon.perp so it is correct
-- in BOTH orientations):
--   1. TERRAIN GRADIENT (§15 v2 item 2): paint each tile with its themed band
--      tile (lava ocean -> molten rock -> sand -> temperate -> icy -> ice wall),
--      per scripts/terrain.lua.
--   2. HARD-WALL BACKSTOP (§15 v2 item 5): tiles at/beyond the per-side wall
--      become out-of-map, so the playable world is a finite-width RIBBON. The
--      damage gradient (scripts/edge-damage.lua) teaches; this void is the
--      bulletproof floor (and the death zone beyond the ice wall / lava ocean).
--   3. RESOURCE PLACEMENT (§15 v2 item 6): stone / ice / volatiles / bootstrap
--      rocks, ONLY in the survivable playable band (never in molten rock, lava,
--      or beyond the ice wall), scaled by the density sliders. Placement is
--      DETERMINISTIC (a coordinate hash, not math.random) so it is reproducible
--      and multiplayer-safe.
--
-- 🚨 Scoped to `surface.name == "cindra"`. Everything is a Cindra-exclusive
-- `cindra-*` resource; only Cindra's own surface tiles are painted; no vanilla
-- prototype is mutated.

local ribbon = require("scripts.ribbon")
local terrain = require("scripts.terrain")
local field = require("scripts.resource-field")
local config = require("scripts.config")

local M = {}

-- Placement lattice: candidate node every STEP tiles. Coarser = sparser world.
M.STEP = 6
-- Per-band placement probability at a candidate lattice point (0..1), at density
-- 1.0. The density sliders scale these (and node richness). All (tune).
M.STONE_CHANCE = 0.22
M.ICE_CHANCE = 0.22
M.VOLATILES_CHANCE = 0.16
M.ROCK_CHANCE = 0.05      -- sparse scatter (finite bootstrap trickle, not a patch)

local function clamp(x, lo, hi)
  if x < lo then return lo end
  if x > hi then return hi end
  return x
end

local function is_cindra(surface)
  return surface and surface.valid and surface.name == "cindra"
end

-- Effective placement chance / richness after a density multiplier. Pure so it is
-- unit-testable and the density behaviour is asserted off the game.
function M.scaled_chance(base, density)
  return clamp(base * (density or 1), 0, 1)
end
function M.scaled_amount(amount, density)
  return math.floor(amount * (density or 1))
end

-- Read a resource autoplace-control's world-gen-screen slider values off a
-- surface's map gen (§15 v2 item 7). Returns (chance_mult, amount_mult):
--   Frequency -> how OFTEN a node appears (chance)
--   Size * Richness -> how RICH each node is (amount)
-- Each defaults to 1 when the control/surface is absent (e.g. a bare test
-- surface), so placement is identical to the neutral baseline. Pure over its
-- table input, so it is unit-testable without the game.
function M.control_scale(map_gen_settings, name)
  local ac = map_gen_settings and map_gen_settings.autoplace_controls
  local c = ac and ac[name]
  if not c then return 1, 1 end
  local freq = c.frequency or 1
  local size = c.size or 1
  local rich = c.richness or 1
  return freq, size * rich
end

-- Deterministic pseudo-random fraction in [0,1) from integer tile coords, with a
-- `salt` so different resources draw independent streams. Integer maths stays
-- well under 2^53, so it is exact.
local function frac(x, y, salt)
  local h = (x * 49632 + y * 325176 + salt * 2606459) % 100000
  if h < 0 then h = h + 100000 end
  return h / 100000
end

-- Paint the themed terrain gradient across the chunk, and void every tile at/over
-- the per-side wall (the ribbon is finite perpendicular). One set_tiles pass.
function M.paint_terrain(surface, area, cfg)
  cfg = cfg or config.ribbon_cfg()
  local x1, y1 = area.left_top.x, area.left_top.y
  local x2, y2 = area.right_bottom.x, area.right_bottom.y
  local tiles = {}
  for y = y1, y2 - 1 do
    for x = x1, x2 - 1 do
      local p = ribbon.perp({ x = x, y = y }, cfg)
      local band = terrain.band(p, cfg)
      local name = (band == "void") and "out-of-map" or terrain.TILE[band]
      if name then
        tiles[#tiles + 1] = { name = name, position = { x, y } }
      end
    end
  end
  if #tiles > 0 then surface.set_tiles(tiles, true) end
end

-- Try to place one resource node of `name`/`amount` at (x,y) if the tile can host
-- it (buildable land, nothing already there).
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

-- Scatter resources across the chunk on the lattice, each in its own axis band,
-- ONLY where the band is playable (never in molten rock / lava / beyond the ice
-- wall). Stone / ice richness + chance scale with the density sliders.
function M.place_resources(surface, area, cfg)
  cfg = cfg or config.ribbon_cfg()
  -- Density/richness come from the world-gen-screen sliders (autoplace-controls),
  -- read off this surface's map gen.
  local mgs = surface.map_gen_settings
  local stone_chance_mult, stone_amount_mult = M.control_scale(mgs, "cindra-stone")
  local ice_chance_mult, ice_amount_mult = M.control_scale(mgs, "cindra-ice")
  local x1, y1 = area.left_top.x, area.left_top.y
  local x2, y2 = area.right_bottom.x, area.right_bottom.y
  -- Snap the lattice to global coords so it is continuous across chunk borders.
  local sx = x1 - (x1 % M.STEP)
  local sy = y1 - (y1 % M.STEP)
  for y = sy, y2 - 1, M.STEP do
    if y >= y1 then
      for x = sx, x2 - 1, M.STEP do
        if x >= x1 then
          local p = ribbon.perp({ x = x, y = y }, cfg)
          -- The gate: resources live ONLY in the survivable playable band.
          if terrain.is_playable(p, cfg) then
            -- Each band draws an independent stream (distinct salt), so bands can
            -- overlap near the terminator (rocks + stone) without lockstep.
            local stone = M.scaled_amount(field.stone_richness(p, cfg), stone_amount_mult)
            if stone > 0 and frac(x, y, 1) < M.scaled_chance(M.STONE_CHANCE, stone_chance_mult) then
              try_resource(surface, x, y, field.STONE, stone)
            end
            local ice = M.scaled_amount(field.ice_richness(p, cfg), ice_amount_mult)
            if ice > 0 and frac(x, y, 2) < M.scaled_chance(M.ICE_CHANCE, ice_chance_mult) then
              try_resource(surface, x, y, field.ICE, ice)
            end
            -- Volatiles ride the ICE control (both are the nightside's matter).
            local vol = M.scaled_amount(field.volatiles_richness(p, cfg), ice_amount_mult)
            if vol > 0 and frac(x, y, 3) < M.scaled_chance(M.VOLATILES_CHANCE, ice_chance_mult) then
              try_resource(surface, x, y, field.VOLATILES, vol)
            end
            if field.rock_zone(p, cfg) and frac(x, y, 4) < M.ROCK_CHANCE then
              try_rock(surface, x, y)
            end
          end
        end
      end
    end
  end
end

function M.on_chunk_generated(event)
  if not is_cindra(event.surface) then return end
  local cfg = config.ribbon_cfg()
  -- Paint terrain (incl. the void backstop) FIRST so we never place a resource on
  -- a tile we are about to void, then scatter resources on the painted land.
  M.paint_terrain(event.surface, event.area, cfg)
  M.place_resources(event.surface, event.area, cfg)
end

return M
