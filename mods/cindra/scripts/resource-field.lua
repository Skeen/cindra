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

-- The mutually-exclusive placement RULE (ci-7w0), the single source of truth for
-- "may this resource generate here": stone on the temperate ribbon + hot margin,
-- ice on the nightside, and both keyed off the SAME divider at the safe-band edge
-- (-safe_half_width). Because the two zones share that one divider and never
-- overlap it, STONE can NEVER generate in the icy (cold) zone and ICE can NEVER
-- generate in the hot zone -- the purity guarantee, expressed as pure geometry.
-- The richness fns below early-return 0 outside these zones, and the band-mask
-- emitters (stone_mask_expr / ice_mask_expr) encode the SAME boundaries as
-- noise-expression strings, so the numeric geometry, the live map-gen, and the
-- runtime damage axis all agree. Keep the three in lockstep.
--
-- `y` is the signed perpendicular coordinate (sunward-positive); the cold/icy zone
-- is y < -safe_half_width, the hot zone is y > safe_half_width, and |y| <= safe is
-- the temperate ribbon where stone (the ribbon feedstock) lives but ice never does.
function M.stone_zone(y, cfg)
  cfg = ribbon.resolve(cfg)
  return y >= -cfg.safe_half_width and y <= cfg.lethal_at
end

function M.ice_zone(y, cfg)
  cfg = ribbon.resolve(cfg)
  return y < -cfg.safe_half_width and y > -cfg.wall_at
end

-- Stone: present from just nightward of the safe band out to the sunward lethal
-- edge (the whole ribbon surface + the hot margin), richest toward the HOT edge
-- so pushing sunward is rewarded. Returns 0 where stone should not appear (the
-- icy/cold zone and past the hot lethal edge), via M.stone_zone.
function M.stone_richness(y, cfg)
  cfg = ribbon.resolve(cfg)
  if not M.stone_zone(y, cfg) then return 0 end
  -- Fraction of the way from the nightward edge of the stone band to the hot edge.
  local span = cfg.lethal_at + cfg.safe_half_width
  local f = clamp((y + cfg.safe_half_width) / span, 0, 1)
  return math.floor(lerp(M.STONE_BASE, M.STONE_PEAK, f))
end

-- Ice: nightward of the safe band, richer the DEEPER (colder) you go, up to the
-- wall. Returns 0 on the sunward side / inside the safe band (the hot + temperate
-- zones) and beyond the wall, via M.ice_zone.
function M.ice_richness(y, cfg)
  cfg = ribbon.resolve(cfg)
  if not M.ice_zone(y, cfg) then return 0 end
  local depth = -y - cfg.safe_half_width           -- tiles past the safe band, nightward
  local span = cfg.wall_at - cfg.safe_half_width
  local f = clamp(depth / span, 0, 1)
  return math.floor(lerp(M.ICE_BASE, M.ICE_PEAK, f))
end

-- Bootstrap rocks scatter along the terminator (inside the safe band, so they are
-- reachable with no damage) across the WHOLE ribbon, not just near spawn. Boolean:
-- is `y` in the scatter band. Finiteness is a property of the ENTITY, not the
-- placement: a mined rock is a destroyed simple-entity, so each rock is one-shot
-- and its metal trickle never feeds a per-craft loop (§6, guarded in tests).
function M.rock_zone(y, cfg)
  cfg = ribbon.resolve(cfg)
  return math.abs(y) <= cfg.safe_half_width
end

-- Per-tile spawn probability inside the rock band (sparse hand-gathered scatter).
M.ROCK_PROBABILITY = 0.006

-- Burned volcanic rocks (ci-qy0) live in the HOT region only: sunward of the safe
-- band, in to the wall. This EXCLUDES the temperate/building band (|y| <= safe)
-- and the ENTIRE cold/ice zone (y < 0), so they read as "in the lava areas" and
-- never appear in the buildable ribbon or on the nightside. Boolean, pure.
function M.burned_rock_zone(y, cfg)
  cfg = ribbon.resolve(cfg)
  return y > cfg.safe_half_width and y < cfg.wall_at
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
-- lethal edge, i.e. y in [-safe_half_width, lethal_at]. Encodes M.stone_zone as a
-- noise-expression string, so the map-gen zeroes stone probability/richness in the
-- icy (cold) zone -- stone can never generate there (ci-7w0).
function M.stone_mask_expr(cfg)
  cfg = ribbon.resolve(cfg)
  return "(" .. Y .. " >= " .. num(-cfg.safe_half_width) .. ")" ..
         " * (" .. Y .. " <= " .. num(cfg.lethal_at) .. ")"
end

-- Ice: nightward of the safe band, in to the wall, i.e. y in [-wall_at, -safe).
-- Encodes M.ice_zone as a noise-expression string, so the map-gen zeroes ice
-- probability/richness across the whole hot + temperate zone -- ice can never
-- generate in the hot zone (ci-7w0).
function M.ice_mask_expr(cfg)
  cfg = ribbon.resolve(cfg)
  return "(" .. Y .. " < " .. num(-cfg.safe_half_width) .. ")" ..
         " * (" .. Y .. " > " .. num(-cfg.wall_at) .. ")"
end

-- Bootstrap rocks: a native simple-entity autoplace, confined to the terminator
-- safe band (|perp| <= safe_half_width) but present along the WHOLE ribbon -- they
-- appear in new chunks as you explore, not just around spawn (ci-9bb: playtest
-- wanted them everywhere along the ribbon, not a spawn-only disk). There is NO
-- `distance` cutoff: finiteness is a property of the ENTITY (a mined rock is a
-- destroyed simple-entity, one-shot, off every loop recipe), not of a bounded
-- spawn disk. A comparison yields 1/0, so the product is a logical AND masking the
-- constant per-tile probability to the band. Replaces the old on_chunk_generated
-- script scatter (ci-3yl): the whole ribbon is map-gen.
function M.rock_probability_expr(cfg)
  cfg = ribbon.resolve(cfg)
  local S = cfg.safe_half_width
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
  cfg = ribbon.resolve(cfg)
  local S, L, W = cfg.safe_half_width, cfg.lethal_at, cfg.wall_at
  local in_zone = "(" .. Y .. " > " .. num(S) .. ")" ..
                  " * (" .. Y .. " < " .. num(W) .. ")"
  -- Fraction of the way from the safe-band edge to the lethal lava edge (clamped
  -- to 1 past the lava edge, so the lava band itself stays at peak density).
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
