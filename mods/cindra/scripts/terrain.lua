-- Themed terrain gradient across the ribbon's perpendicular axis (§15 v2 item 2).
-- PURE module (no `game.*` / `prototypes.*`): it maps a perpendicular coordinate
-- to a terrain BAND and the placeholder TILE that paints it, so the gradient
-- geometry is deterministic and unit-testable off the game entirely.
-- scripts/worldgen.lua is the runtime layer that paints these tiles per chunk.
--
-- The full hot -> cold sequence, symmetric about the temperate centre:
--
--   lava ocean -> molten rock -> sand -> [TEMPERATE] -> icy -> ice wall -> death
--   (+hot_wall)                    (0)                          (-cold_wall)
--
-- Bands and their perpendicular extent (per-side, read off the ribbon cfg):
--   temperate    |p| <= safe                         the playable ribbon
--   sand         safe   < p  < hot_lethal            sunward survivable margin
--   molten rock  hot_lethal <= p < hot_ocean_at      sunward lethal (fire)
--   lava ocean   hot_ocean_at <= p < hot_wall        sunward lethal, IMPASSABLE
--   icy          safe   < -p < cold_lethal           nightward survivable margin
--   ice wall     cold_lethal <= -p < cold_wall       nightward lethal (freeze)
--   void         |p| >= wall (per side)              the hard-wall / death zone
--
-- v1 art reuse: each band paints a vanilla placeholder tile (a legible hot->cold
-- palette). Bespoke Cindra tile art is a follow-up (see ART-MANIFEST.md); this
-- module names the BANDS, so swapping the placeholder tiles later is one table.

local ribbon = require("scripts.ribbon")

local M = {}

-- Band names, ordered sunward-most -> nightward-most (the gradient sequence).
M.BANDS = { "lava_ocean", "molten_rock", "sand", "temperate", "icy", "ice_wall" }

-- Placeholder vanilla tiles per band. `void` bands paint no tile (worldgen voids
-- them to out-of-map instead). Swap these for bespoke Cindra tiles later.
M.TILE = {
  temperate   = "volcanic-soil-light", -- neutral bare regolith, the seam
  sand        = "sand-1",              -- warm sunward margin
  molten_rock = "volcanic-cracks-hot", -- glowing cracked rock (fire band)
  lava_ocean  = "lava",                -- molten ocean (impassable fluid)
  icy         = "brash-ice",           -- frosted nightward margin
  ice_wall    = "ice-rough",           -- the icy mountain range (lethal cold)
}

-- Bands where resources may be placed: only the survivable playable band (§15 v2
-- item 6 -- NO resources in molten rock / lava / beyond the ice wall).
M.PLAYABLE = { temperate = true, sand = true, icy = true }

-- Sunward split between the molten-rock band and the lava ocean: the midpoint of
-- the sunward lethal region, unless a cfg override is given.
local function hot_ocean_at(cfg)
  return cfg.hot_ocean_at or math.floor((cfg.hot_lethal_at + cfg.hot_wall_at) / 2)
end

-- Band at perpendicular coordinate `p`. Returns "void" past the hard wall.
function M.band(p, cfg)
  cfg = ribbon.resolve(cfg)
  if p >= 0 then
    if p >= cfg.hot_wall_at then return "void" end
    if p <= cfg.safe_half_width then return "temperate" end
    if p < cfg.hot_lethal_at then return "sand" end
    if p < hot_ocean_at(cfg) then return "molten_rock" end
    return "lava_ocean"
  else
    local d = -p
    if d >= cfg.cold_wall_at then return "void" end
    if d <= cfg.safe_half_width then return "temperate" end
    if d < cfg.cold_lethal_at then return "icy" end
    return "ice_wall"
  end
end

-- Placeholder tile for the band at `p`, or nil in the void (out-of-map).
function M.tile_for(p, cfg)
  return M.TILE[M.band(p, cfg)]
end

-- Is `p` in a band where resources may spawn (the playable ribbon)?
function M.is_playable(p, cfg)
  return M.PLAYABLE[M.band(p, cfg)] == true
end

return M
