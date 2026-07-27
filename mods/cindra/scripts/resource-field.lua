-- Where each Cindra resource lives on the ribbon axis, and how rich it is (§5,
-- §15 item 3). PURE module (no game.* / prototypes.*): it maps a ribbon Y
-- coordinate to a per-band richness, so the placement geometry is deterministic
-- and unit-testable off the game entirely.
--
-- Two consumers read this ONE source of truth:
--   * DATA stage (prototypes/resources.lua): stone / ice / volatiles are placed
--     by NATIVE Factorio resource autoplace (spot-noise patches, not a script
--     grid), CONSTRAINED to their axis band by multiplying the autoplace
--     probability/richness by a perpendicular-axis (Y) MASK this module emits as
--     a noise-expression string (see *_mask_expr / *_richness_mult_expr).
--   * RUNTIME (scripts/worldgen.lua): the finite bootstrap-rock scatter still
--     reads rock_zone (rocks are simple-entities, not an autoplace resource).
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
-- as scripts/ribbon.lua, so resources and damage share one source of truth. The
-- numeric richness_* fns (unit-tested) and the *_expr emitters describe the SAME
-- band boundaries + gradient; keep them in lockstep.

local ribbon = require("scripts.ribbon")

local M = {}

-- The perpendicular (sunward-nightward) axis variable, as named in the Factorio
-- noise-expression DSL. Cindra's ribbon runs east-west (long X), so "hot vs cold"
-- is the Y coordinate -- the same axis scripts/ribbon.lua reads. One constant so
-- the band masks never re-derive the orientation.
M.PERP_AXIS = "y"

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

-- ---------------------------------------------------------------------------
-- Native-autoplace band masks (§15-v2 item 1: patches, not a grid).
--
-- These emit Factorio noise-expression STRINGS that prototypes/resources.lua
-- multiplies into each resource's autoplace probability/richness so the spot-
-- noise patches only appear inside the band -- keeping the natural, irregular,
-- slider-driven patches CONSTRAINED to the correct ribbon zone. A comparison in
-- the DSL yields 1/0, so multiplying two of them is a logical AND; multiplying a
-- resource's probability by the mask zeroes it outside the band. The boundaries
-- MATCH the numeric richness_* fns above (stone on the ribbon+hot margin, ice
-- nightward, volatiles deep nightside), so the emitted patches land exactly where
-- the pure geometry says they should.
-- ---------------------------------------------------------------------------

-- Format a number for the DSL (trim to avoid float noise; integers stay clean).
local function num(v)
  if v == math.floor(v) then return string.format("%d", v) end
  return string.format("%.6g", v)
end

local Y = "y" -- M.PERP_AXIS; local alias for the emitters below.

-- Stone: present from the nightward edge of the safe band out to the sunward
-- lethal edge, i.e. y in [-safe_half_width, lethal_at].
function M.stone_mask_expr(cfg)
  cfg = ribbon.resolve(cfg)
  return "(" .. Y .. " >= " .. num(-cfg.safe_half_width) .. ")" ..
         " * (" .. Y .. " <= " .. num(cfg.lethal_at) .. ")"
end

-- Ice: nightward of the safe band, in to the wall, i.e. y in [-wall_at, -safe).
function M.ice_mask_expr(cfg)
  cfg = ribbon.resolve(cfg)
  return "(" .. Y .. " < " .. num(-cfg.safe_half_width) .. ")" ..
         " * (" .. Y .. " > " .. num(-cfg.wall_at) .. ")"
end

-- Volatiles: only the deep nightside cold-lethal band, y in [-wall_at, -lethal].
function M.volatiles_mask_expr(cfg)
  cfg = ribbon.resolve(cfg)
  return "(" .. Y .. " <= " .. num(-cfg.lethal_at) .. ")" ..
         " * (" .. Y .. " > " .. num(-cfg.wall_at) .. ")"
end

-- Edge-pushing richness multiplier (>= 1): scales the native patch richness so
-- the BEST nodes sit at the lethal margins, honouring the planet's thesis. The
-- ramp shape mirrors the numeric richness_* gradients (peak/base ratio), so a
-- patch at the hot/cold edge is richer than one near the terminator.
local function lerp_expr(from, to, frac_expr)
  return "lerp(" .. num(from) .. ", " .. num(to) .. ", clamp(" .. frac_expr .. ", 0, 1))"
end

function M.stone_richness_mult_expr(cfg)
  cfg = ribbon.resolve(cfg)
  local span = cfg.lethal_at + cfg.safe_half_width
  local frac = "(" .. Y .. " + " .. num(cfg.safe_half_width) .. ") / " .. num(span)
  return lerp_expr(1, M.STONE_PEAK / M.STONE_BASE, frac)
end

function M.ice_richness_mult_expr(cfg)
  cfg = ribbon.resolve(cfg)
  local span = math.max(1, cfg.wall_at - cfg.safe_half_width)
  local frac = "(-" .. Y .. " - " .. num(cfg.safe_half_width) .. ") / " .. num(span)
  return lerp_expr(1, M.ICE_PEAK / M.ICE_BASE, frac)
end

function M.volatiles_richness_mult_expr(cfg)
  cfg = ribbon.resolve(cfg)
  local span = math.max(1, cfg.wall_at - cfg.lethal_at)
  local frac = "(-" .. Y .. " - " .. num(cfg.lethal_at) .. ") / " .. num(span)
  return lerp_expr(1, M.VOLATILES_PEAK / M.VOLATILES_BASE, frac)
end

return M
