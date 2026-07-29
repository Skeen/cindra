-- Where each Cindra resource lives on the ribbon axis, and how rich it is (§5,
-- §15 item 3; rebanded to the ci-da2 zones). PURE module (no game.* /
-- prototypes.*): it maps a perpendicular coordinate to a per-band richness, so the
-- placement geometry is deterministic and unit-testable off the game entirely.
--
-- The ONE source of truth for every Cindra resource's placement, read entirely at
-- the DATA stage (prototypes/resources.lua): stone / ice patches and the finite
-- bootstrap rocks are ALL placed by NATIVE map-gen autoplace (spot-noise patches,
-- not a script grid), CONSTRAINED to their zone by multiplying the autoplace
-- probability/richness by a perpendicular-axis MASK this module emits as a
-- noise-expression string. There is NO runtime placement (ci-3yl).
--
-- The single organising idea (the planet's thesis, §1): ENERGY sunward, MATTER
-- nightward, and the BEST of everything at the lethal margins (edge-pushing).
--
--   stone      the building ribbon + the walkable HOT margin, richer toward the
--              hot lethal edge (the lava-crust); never into the cold zone.
--   ice        the cold cap east of the building band, richer DEEPER (colder)
--              toward the deep-ice edge; never into the hot/temperate zone.
--   rocks      scattered across the building band (finite bootstrap scatter, §6).
--
-- The zone boundaries come from scripts/terrain.lua (M.resource_bounds), the SAME
-- geometry that lays the tile gradient, so resources and terrain share one source
-- of truth: stone on the hot ribbon, ice on the cold cap, split at the one divider
-- (the cold edge of the building band) so the purity guarantee (ci-7w0) holds --
-- stone can NEVER generate in the icy zone, ice NEVER in the hot/temperate zone.

local terrain = require("scripts.terrain")
local axis = require("scripts.axis")

local M = {}

-- The perpendicular (sunward-positive) axis as a noise-expression string. The
-- ORIENTATION (scripts/axis.lua) decides whether "hot vs cold" is x or y; the band
-- masks read this ONE expression so they never re-derive it. Default vertical
-- orientation: "(0 - x)" (hot on the left / west).
M.PERP_AXIS = axis.perp_expr()

-- Cindra resource / entity prototype names (defined in prototypes/resources.lua).
M.STONE = "cindra-stone"
M.ICE = "cindra-ice"
M.ROCK = "cindra-rock"

-- Burned volcanic rocks (ci-qy0): charred Vulcanus-style boulders that generate in
-- the HOT / lava region only, clustered toward the lava edge so they read as "in
-- the lava areas". Two size variants for visual variety; both are finite
-- simple-entities that yield STONE + COAL only (see prototypes/resources.lua).
-- The names live here (with the other Cindra worldgen entity names) so
-- prototypes/resources.lua, prototypes/planet.lua's autoplace allow-list, and the
-- tests all read the SAME list.
M.BURNED_ROCK = "cindra-volcanic-rock"
M.BURNED_ROCK_HUGE = "cindra-volcanic-rock-huge"
function M.burned_rock_names()
  return { M.BURNED_ROCK, M.BURNED_ROCK_HUGE }
end

-- Node richness (resource `amount`) starting points, all (tune).
M.STONE_BASE = 600
M.STONE_PEAK = 5000     -- at the hot (lava-crust) margin (best stone)
M.ICE_BASE = 600
M.ICE_PEAK = 5000       -- deep cold cap (best ice)

local function clamp(x, lo, hi)
  if x < lo then return lo end
  if x > hi then return hi end
  return x
end

local function lerp(a, b, t)
  return a + (b - a) * t
end

-- The zone boundaries (perp-space) resources band against, from the tile geometry.
local function bounds(cfg)
  return terrain.resource_bounds(cfg)
end

-- The mutually-exclusive placement RULE (ci-7w0): stone on the building ribbon +
-- the walkable hot margin (p in [building_lo, hot_edge]); ice on the cold cap
-- (p in [cold_edge, building_lo)); both keyed off the SAME divider at building_lo.
-- Because the two zones share that one divider and never overlap it, STONE can
-- NEVER generate in the cold zone and ICE can NEVER generate in the hot/temperate
-- zone -- the purity guarantee, expressed as pure geometry. `y` is the signed
-- perpendicular coordinate (sunward-positive).
function M.stone_zone(y, cfg)
  local b = bounds(cfg)
  return y >= b.building_lo and y <= b.hot_edge
end

function M.ice_zone(y, cfg)
  local b = bounds(cfg)
  return y < b.building_lo and y >= b.cold_edge
end

-- Stone: from the cold edge of the building band out to the hot walkable margin,
-- richest toward the HOT edge so pushing sunward is rewarded. Returns 0 where
-- stone should not appear (the cold zone and past the walkable hot margin).
function M.stone_richness(y, cfg)
  local b = bounds(cfg)
  if not M.stone_zone(y, cfg) then return 0 end
  local span = math.max(1, b.hot_edge - b.building_lo)
  local f = clamp((y - b.building_lo) / span, 0, 1)
  return math.floor(lerp(M.STONE_BASE, M.STONE_PEAK, f))
end

-- Ice: east of the building band, richer the DEEPER (colder) you go, to the cap
-- edge. Returns 0 in the hot/temperate zone and beyond the cap.
function M.ice_richness(y, cfg)
  local b = bounds(cfg)
  if not M.ice_zone(y, cfg) then return 0 end
  local span = math.max(1, b.building_lo - b.cold_edge)
  local depth = b.building_lo - y                     -- tiles past the divider, coldward
  local f = clamp(depth / span, 0, 1)
  return math.floor(lerp(M.ICE_BASE, M.ICE_PEAK, f))
end

-- Bootstrap rocks scatter across the building band (|p| <= building_half), so they
-- are reachable with no damage, along the WHOLE ribbon (not just near spawn).
-- Finiteness is a property of the ENTITY (a mined rock is a destroyed simple-
-- entity, one-shot, off every loop recipe), not of the placement (§6).
function M.rock_zone(y, cfg)
  local b = bounds(cfg)
  return math.abs(y) <= b.building_half
end

-- Per-tile spawn probability inside the rock band (sparse hand-gathered scatter).
M.ROCK_PROBABILITY = 0.006

-- Burned volcanic rocks (ci-qy0) live in the HOT region only, re-banded to the
-- ci-da2 zone geometry: from the building band's hot (sunward) edge out to the
-- walkable hot margin (the lava-crust edge, terrain.resource_bounds.hot_edge). This
-- EXCLUDES the temperate/building band (|p| <= building_half) and the ENTIRE
-- cold/ice zone, and stops at the walkable hot edge (never into the impassable lava
-- wall, where a simple-entity could not place), so they read as "in the lava areas"
-- and never clutter the buildable ribbon or the nightside. Boolean, pure.
function M.burned_rock_zone(y, cfg)
  local b = bounds(cfg)
  return y > b.building_half and y <= b.hot_edge
end

-- Per-tile spawn probability at the two ends of the hot region: sparse at the
-- inner (safe-band) edge, densest toward the lava (lethal) edge and beyond, so the
-- rocks cluster where the lava is. The emitter below ramps between them.
M.BURNED_ROCK_PROBABILITY_MIN = 0.003
M.BURNED_ROCK_PROBABILITY_MAX = 0.02

-- ---------------------------------------------------------------------------
-- Native-autoplace band masks (§15-v2 item 1: patches, not a grid).
--
-- These emit Factorio noise-expression STRINGS that prototypes/resources.lua
-- multiplies into each resource's autoplace probability/richness so the spot-noise
-- patches only appear inside the zone. A comparison in the DSL yields 1/0, so
-- multiplying two of them is a logical AND; multiplying a resource's probability by
-- the mask zeroes it outside the band. The boundaries MATCH the numeric richness_*
-- fns above (they read the SAME terrain.resource_bounds), so the emitted patches
-- land exactly where the pure geometry says they should.
-- ---------------------------------------------------------------------------

-- Format a number for the DSL (trim to avoid float noise; integers stay clean).
local function num(v)
  if v == math.floor(v) then return string.format("%d", v) end
  return string.format("%.6g", v)
end

local Y = M.PERP_AXIS -- the sunward-positive perpendicular axis expression.

-- Stone: p in [building_lo, hot_edge]. Encodes M.stone_zone as a noise-expression
-- string, so the map-gen zeroes stone probability/richness in the cold zone.
function M.stone_mask_expr(cfg)
  local b = bounds(cfg)
  return "(" .. Y .. " >= " .. num(b.building_lo) .. ")" ..
         " * (" .. Y .. " <= " .. num(b.hot_edge) .. ")"
end

-- Ice: p in [cold_edge, building_lo). Encodes M.ice_zone, so the map-gen zeroes ice
-- probability/richness across the whole hot + temperate zone.
function M.ice_mask_expr(cfg)
  local b = bounds(cfg)
  return "(" .. Y .. " < " .. num(b.building_lo) .. ")" ..
         " * (" .. Y .. " >= " .. num(b.cold_edge) .. ")"
end

-- Bootstrap rocks: a native simple-entity autoplace confined to the building band
-- (|p| <= building_half) but present along the WHOLE ribbon. A comparison yields
-- 1/0, so the product is a logical AND masking the constant per-tile probability to
-- the band.
function M.rock_probability_expr(cfg)
  local b = bounds(cfg)
  local S = b.building_half
  return "(" .. Y .. " < " .. num(S) .. ")" ..
         " * (" .. Y .. " > " .. num(-S) .. ")" ..
         " * " .. num(M.ROCK_PROBABILITY)
end

-- Burned volcanic rocks (ci-qy0): a native simple-entity autoplace confined to the
-- HOT region (sunward of the safe band, in to the wall) and CLUSTERED toward the
-- lava. Encodes M.burned_rock_zone as a noise-expression string (a comparison
-- yields 1/0, so the product is a logical AND masking probability to the band),
-- then ramps the per-tile probability from MIN at the inner (safe-band) edge to
-- MAX at the lethal lava edge and beyond -- so density rises toward the lava and
-- the rocks read as "in the lava areas". The mask zeroes probability across the
-- temperate/building band and the whole cold/ice zone, so burned rocks can NEVER
-- generate there (matches M.burned_rock_zone; keep the two in lockstep).
function M.burned_rock_probability_expr(cfg)
  local b = bounds(cfg)
  local S, L = b.building_half, b.hot_edge
  local in_zone = "(" .. Y .. " > " .. num(S) .. ")" ..
                  " * (" .. Y .. " <= " .. num(L) .. ")"
  -- Fraction of the way from the building band's hot edge to the walkable lava edge
  -- (clamped), so density ramps from sparse near the ribbon to densest at the lava.
  local span = math.max(1, L - S)
  local frac = "clamp((" .. Y .. " - " .. num(S) .. ") / " .. num(span) .. ", 0, 1)"
  local prob = "lerp(" .. num(M.BURNED_ROCK_PROBABILITY_MIN) .. ", " ..
               num(M.BURNED_ROCK_PROBABILITY_MAX) .. ", " .. frac .. ")"
  return "(" .. in_zone .. ") * (" .. prob .. ")"
end

-- Edge-pushing richness multiplier (>= 1): scales the native patch richness so
-- the BEST nodes sit at the lethal margins, honouring the planet's thesis. The
-- ramp shape mirrors the numeric richness_* gradients (peak/base ratio), so a
-- patch at the hot/cold edge is richer than one near the terminator.
local function lerp_expr(from, to, frac_expr)
  return "lerp(" .. num(from) .. ", " .. num(to) .. ", clamp(" .. frac_expr .. ", 0, 1))"
end

function M.stone_richness_mult_expr(cfg)
  local b = bounds(cfg)
  local span = math.max(1, b.hot_edge - b.building_lo)
  local frac = "(" .. Y .. " - " .. num(b.building_lo) .. ") / " .. num(span)
  return lerp_expr(1, M.STONE_PEAK / M.STONE_BASE, frac)
end

function M.ice_richness_mult_expr(cfg)
  local b = bounds(cfg)
  local span = math.max(1, b.building_lo - b.cold_edge)
  local frac = "(" .. num(b.building_lo) .. " - " .. Y .. ") / " .. num(span)
  return lerp_expr(1, M.ICE_PEAK / M.ICE_BASE, frac)
end

return M
