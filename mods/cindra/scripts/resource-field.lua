-- Where each Cindra resource lives on the ribbon axis, and how rich it is (§5,
-- §15 item 3). PURE module (no game.* / prototypes.*): it maps a ribbon Y
-- coordinate to a resource-node richness, so the placement geometry is
-- deterministic and unit-testable off the game entirely. scripts/worldgen.lua is
-- the runtime layer that turns these richnesses into actual entities.
--
-- The single organising idea (the planet's thesis, §1): ENERGY sunward, MATTER
-- nightward, and the BEST of everything at the lethal margins (edge-pushing).
--
--   stone      ribbon + sunward margin   richer toward the HOT lethal edge
--   ice        nightward of the safe band richer DEEPER (colder) toward the wall
--   volatiles  deep nightside cold-lethal richer deeper still (the coldest, best)
--   rocks      scattered around the terminator (finite bootstrap scatter, §6)
--
-- Every band reads the SAME axis geometry (safe_half_width / lethal_at / wall_at)
-- as scripts/ribbon.lua, so resources and damage share one source of truth.

local ribbon = require("scripts.ribbon")

local M = {}

-- Cindra resource / entity prototype names (defined in prototypes/resources.lua).
M.STONE = "cindra-stone"
M.ICE = "cindra-ice"
M.VOLATILES = "cindra-volatiles"
M.ROCK = "cindra-bootstrap-rock"

-- Node richness (resource `amount`) starting points, all (tune).
M.STONE_BASE = 600
M.STONE_PEAK = 5000     -- at the sunward lethal margin (best stone)
M.ICE_BASE = 600
M.ICE_PEAK = 5000       -- deep nightside (best ice)
M.VOLATILES_BASE = 1500
M.VOLATILES_PEAK = 8000 -- the coldest, deepest, best node

local function clamp(x, lo, hi)
  if x < lo then return lo end
  if x > hi then return hi end
  return x
end

local function lerp(a, b, t)
  return a + (b - a) * t
end

-- Stone: present from just nightward of the safe band out to the sunward lethal
-- edge (the whole ribbon surface + the hot margin), richest toward the HOT edge
-- so pushing sunward is rewarded. Returns 0 where stone should not appear.
function M.stone_richness(y, cfg)
  cfg = ribbon.resolve(cfg)
  if y < -cfg.safe_half_width or y > cfg.lethal_at then return 0 end
  -- Fraction of the way from the nightward edge of the stone band to the hot edge.
  local span = cfg.lethal_at + cfg.safe_half_width
  local f = clamp((y + cfg.safe_half_width) / span, 0, 1)
  return math.floor(lerp(M.STONE_BASE, M.STONE_PEAK, f))
end

-- Ice: nightward of the safe band, richer the DEEPER (colder) you go, up to the
-- wall. Returns 0 on the sunward side / inside the safe band.
function M.ice_richness(y, cfg)
  cfg = ribbon.resolve(cfg)
  if y > -cfg.safe_half_width then return 0 end
  local depth = -y - cfg.safe_half_width           -- tiles past the safe band, nightward
  local span = cfg.wall_at - cfg.safe_half_width
  local f = clamp(depth / span, 0, 1)
  return math.floor(lerp(M.ICE_BASE, M.ICE_PEAK, f))
end

-- Volatiles: only in the DEEP nightside cold-lethal band (>= lethal_at
-- nightward), the coldest edge-pushing reward. Returns 0 elsewhere.
function M.volatiles_richness(y, cfg)
  cfg = ribbon.resolve(cfg)
  if y > -cfg.lethal_at then return 0 end
  local depth = -y - cfg.lethal_at
  local span = math.max(1, cfg.wall_at - cfg.lethal_at)
  local f = clamp(depth / span, 0, 1)
  return math.floor(lerp(M.VOLATILES_BASE, M.VOLATILES_PEAK, f))
end

-- Bootstrap rocks scatter around the terminator only (inside the safe band, so
-- they are reachable at landing with no damage). Boolean: is `y` in the scatter
-- band. Finiteness comes from the entity (a mined rock is destroyed), not here.
function M.rock_zone(y, cfg)
  cfg = ribbon.resolve(cfg)
  return math.abs(y) <= cfg.safe_half_width
end

return M
