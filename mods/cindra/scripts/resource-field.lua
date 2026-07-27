-- Where each Cindra resource lives on the ribbon axis, and how rich it is (§5,
-- §15 v2 item 6). PURE module (no game.* / prototypes.*): it maps a ribbon
-- PERPENDICULAR coordinate to a resource-node richness, so the placement geometry
-- is deterministic and unit-testable off the game entirely. scripts/worldgen.lua
-- is the runtime layer that turns these richnesses into actual entities (and it
-- ALSO gates placement to playable bands via scripts/terrain.lua -- so this
-- module and the terrain gate agree: nothing spawns in molten rock, lava, the ice
-- wall, or the death zone).
--
-- The single organising idea (the planet's thesis, §1): ENERGY sunward, MATTER
-- nightward, and the BEST of everything at the EDGE of the survivable band
-- (edge-pushing) -- never out in the lethal terrain, per the v2 resource rule.
--
--   stone      temperate + sunward sand margin   richer toward the HOT edge
--   ice        temperate edge + nightward icy     richer toward the COLD edge
--   volatiles  deepest survivable icy slice       richest at the cold edge
--   rocks      scattered around the terminator     (finite bootstrap scatter, §6)
--
-- Every band reads the SAME per-side axis geometry (safe_half_width /
-- hot_lethal_at / cold_lethal_at) as scripts/ribbon.lua, so resources and damage
-- share one source of truth, and both hot/cold zones can differ in depth.

local ribbon = require("scripts.ribbon")

local M = {}

-- Cindra resource / entity prototype names (defined in prototypes/resources.lua).
M.STONE = "cindra-stone"
M.ICE = "cindra-ice"
M.VOLATILES = "cindra-volatiles"
M.ROCK = "cindra-bootstrap-rock"

-- Node richness (resource `amount`) starting points, all (tune).
M.STONE_BASE = 600
M.STONE_PEAK = 5000     -- at the sunward playable edge (best stone)
M.ICE_BASE = 600
M.ICE_PEAK = 5000       -- at the nightward playable edge (best ice)
M.VOLATILES_BASE = 1500
M.VOLATILES_PEAK = 8000 -- the coldest survivable node

-- Width (tiles) of the deep-cold volatiles sub-band, just inside the cold lethal
-- edge. (tune)
M.VOLATILES_BAND = 24

local function clamp(x, lo, hi)
  if x < lo then return lo end
  if x > hi then return hi end
  return x
end

local function lerp(a, b, t)
  return a + (b - a) * t
end

-- Stone: the playable sunward band -- from the nightward edge of the safe band
-- out to just inside the sunward lethal edge (temperate + sand margin). Richest
-- toward the HOT edge so pushing sunward is rewarded. Returns 0 outside (never in
-- molten rock / lava).
function M.stone_richness(p, cfg)
  cfg = ribbon.resolve(cfg)
  if p < -cfg.safe_half_width or p >= cfg.hot_lethal_at then return 0 end
  -- Fraction from the nightward edge of the stone band to the hot playable edge.
  local span = cfg.hot_lethal_at + cfg.safe_half_width
  local f = clamp((p + cfg.safe_half_width) / span, 0, 1)
  return math.floor(lerp(M.STONE_BASE, M.STONE_PEAK, f))
end

-- Ice: the playable nightside band -- from just nightward of the safe band out to
-- just inside the cold lethal edge (the icy margin). Richer the DEEPER (colder)
-- you go, peaking at the playable edge. Returns 0 elsewhere (never in the ice
-- wall / death zone).
function M.ice_richness(p, cfg)
  cfg = ribbon.resolve(cfg)
  if p > -cfg.safe_half_width or p <= -cfg.cold_lethal_at then return 0 end
  local depth = -p - cfg.safe_half_width          -- tiles past the safe band, nightward
  local span = cfg.cold_lethal_at - cfg.safe_half_width
  local f = clamp(depth / span, 0, 1)
  return math.floor(lerp(M.ICE_BASE, M.ICE_PEAK, f))
end

-- Volatiles: the BEST cold reward -- only the deepest SURVIVABLE slice of the icy
-- margin, just inside the cold lethal edge (never out in the ice wall). Richest
-- right at the edge. Returns 0 elsewhere.
function M.volatiles_richness(p, cfg)
  cfg = ribbon.resolve(cfg)
  local edge = cfg.cold_lethal_at
  local inner = math.max(cfg.safe_half_width, edge - M.VOLATILES_BAND)
  local d = -p
  if p >= 0 or d <= inner or d >= edge then return 0 end
  local f = clamp((d - inner) / math.max(1, edge - inner), 0, 1)
  return math.floor(lerp(M.VOLATILES_BASE, M.VOLATILES_PEAK, f))
end

-- Bootstrap rocks scatter around the terminator only (inside the safe band, so
-- they are reachable at landing with no damage). Boolean: is `p` in the scatter
-- band. Finiteness comes from the entity (a mined rock is destroyed), not here.
function M.rock_zone(p, cfg)
  cfg = ribbon.resolve(cfg)
  return math.abs(p) <= cfg.safe_half_width
end

return M
