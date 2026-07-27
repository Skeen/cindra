-- Where each Cindra resource lives on the ribbon axis, and how rich it is (§5,
-- §15 item 3). PURE module (no game.* / prototypes.*): it maps a ribbon Y
-- coordinate to a per-band richness, so the placement geometry is deterministic
-- and unit-testable off the game entirely.
--
-- The ONE source of truth for every Cindra resource's placement, read entirely at
-- the DATA stage (prototypes/resources.lua): stone / ice patches and the finite
-- bootstrap rocks are ALL placed by NATIVE map-gen autoplace (spot-noise patches,
-- not a script grid), CONSTRAINED to their axis band by multiplying the autoplace
-- probability/richness by a perpendicular-axis MASK this module emits as a
-- noise-expression string (see *_mask_expr / *_richness_mult_expr /
-- rock_probability_expr). There is NO runtime placement any more (ci-3yl).
--
-- The single organising idea (the planet's thesis, §1): ENERGY sunward, MATTER
-- nightward, and the BEST of everything at the lethal margins (edge-pushing).
--
--   stone      ribbon + sunward margin   richer toward the HOT lethal edge
--   ice        nightward of the safe band richer DEEPER (colder) toward the wall
--              (deep ice ALSO yields the science pack's frozen volatiles)
--   rocks      scattered around the terminator (finite bootstrap scatter, §6)
--
-- Every band reads the SAME axis geometry (safe_half_width / lethal_at / wall_at)
-- as scripts/ribbon.lua, so resources and damage share one source of truth. The
-- numeric richness_* fns (unit-tested) and the *_expr emitters describe the SAME
-- band boundaries + gradient; keep them in lockstep.

local ribbon = require("scripts.ribbon")
local axis = require("scripts.axis")

local M = {}

-- The perpendicular (sunward-nightward) axis, as a Factorio noise-expression
-- string. The ORIENTATION (scripts/axis.lua) decides whether "hot vs cold" is x
-- or y; the band masks read this ONE expression so they never re-derive it. In
-- the default vertical orientation this is "(0 - x)" (hot on the left / west).
M.PERP_AXIS = axis.perp_expr()

-- Cindra resource / entity prototype names (defined in prototypes/resources.lua).
-- Only Stone + Ice are mineable resources (map-gen sliders); the frozen volatiles
-- the science pack needs come from the deep-nightside ICE chain, not a standalone
-- resource (ci-3yl). The bootstrap ROCK is a finite simple-entity scatter.
M.STONE = "cindra-stone"
M.ICE = "cindra-ice"
M.ROCK = "cindra-bootstrap-rock"

-- Node richness (resource `amount`) starting points, all (tune).
M.STONE_BASE = 600
M.STONE_PEAK = 5000     -- at the sunward lethal margin (best stone)
M.ICE_BASE = 600
M.ICE_PEAK = 5000       -- deep nightside (best ice)

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

-- Bootstrap rocks scatter around the terminator only (inside the safe band, so
-- they are reachable at landing with no damage). Boolean: is `y` in the scatter
-- band. Finiteness comes from being confined to a bounded disk near spawn (see
-- rock_probability_expr) AND from the entity (a mined rock is destroyed).
function M.rock_zone(y, cfg)
  cfg = ribbon.resolve(cfg)
  return math.abs(y) <= cfg.safe_half_width
end

-- How far from spawn (tiles) bootstrap rocks scatter along the ribbon. Beyond
-- this the native autoplace probability is zero, so the rocks are FINITE (a
-- bounded disk near the landing terminator), never an infinite metal supply. (tune)
M.ROCK_SPAWN_RANGE = 130
-- Per-tile spawn probability inside the rock band (sparse hand-gathered scatter).
M.ROCK_PROBABILITY = 0.006

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

local Y = M.PERP_AXIS -- the sunward-positive perpendicular axis expression.
local NY = axis.perp_neg_expr() -- the nightward-positive axis (-perp), for cold bands.

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

-- Bootstrap rocks: a native simple-entity autoplace, confined to the terminator
-- safe band (|perp| <= safe_half_width) AND to a bounded disk of radius
-- ROCK_SPAWN_RANGE around spawn (`distance` = tiles from the nearest starting
-- point), so the scatter is FINITE. A comparison yields 1/0, so the product is a
-- logical AND masking the constant per-tile probability. This replaces the old
-- on_chunk_generated script scatter (ci-3yl): the whole ribbon is now map-gen.
function M.rock_probability_expr(cfg)
  cfg = ribbon.resolve(cfg)
  local S = cfg.safe_half_width
  return "(" .. Y .. " < " .. num(S) .. ")" ..
         " * (" .. Y .. " > " .. num(-S) .. ")" ..
         " * (distance < " .. num(M.ROCK_SPAWN_RANGE) .. ")" ..
         " * " .. num(M.ROCK_PROBABILITY)
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
  local frac = "(" .. NY .. " - " .. num(cfg.safe_half_width) .. ") / " .. num(span)
  return lerp_expr(1, M.ICE_PEAK / M.ICE_BASE, frac)
end

return M
