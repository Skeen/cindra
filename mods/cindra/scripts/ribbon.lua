-- The ribbon temperature axis (§4, §15 item 1) — the geometric heart of Cindra.
--
-- Cindra's map is a 1D RIBBON: a long survivable strip with a shallow perpendicular
-- (sunward-nightward) axis. The whole planet's identity is "hot vs cold," and that
-- tension is a function of ONE coordinate: the signed PERPENDICULAR coordinate `p`,
-- how far a point sits from the terminator centre toward the sun (or the night).
--
--   +p  ->  SUNWARD   (ENERGY / heat)  : temperature RISES, lethal by heat
--    0      TERMINATOR (temperate)      : the survivable ribbon, no damage
--   -p  ->  NIGHTWARD  (MATTER / cold)  : temperature FALLS, lethal by cold
--
-- Which WORLD axis (x or y) that coordinate maps to is an ORIENTATION choice made
-- once in scripts/axis.lua (DEFAULT: vertical ribbon, hot on the LEFT / west, so
-- p = -x). This module never sees x/y; callers hand it p. Older comments/tests
-- that say "+Y" describe the legacy horizontal orientation -- the maths is the
-- same, only which axis is perpendicular differs.
--
-- This module is DELIBERATELY PURE: no `game.*` / `prototypes.*` access. It maps
-- a perpendicular coordinate to a temperature and a damage profile, nothing more.
-- That keeps
-- the axis maths fast, deterministic, and testable in plain Lua (unit-tests/),
-- and lets every downstream system (lethal-edge damage §15-2, nightside heat,
-- resource placement, edge-pushing rewards) read the SAME single source of truth
-- for "where am I on the hot-cold axis."
--
-- Runtime application (ticking the player for damage, freezing nightside
-- machines) lives in scripts that consume this module; see TODO.md §15 item 2.

local M = {}

-- Tuning defaults (§16). Distances are in TILES from the ribbon centre (Y = 0);
-- temperatures are flavour/scaling values in degrees Celsius. All (tune).
--
-- The band layout, from centre outward on EACH side:
--   [0 .. safe_half_width]            temperate, no damage           (the ribbon)
--   (safe_half_width .. lethal_at]    damage ramp 0 -> max            (the margin)
--   (lethal_at .. wall_at]            full lethal damage              (the deep edge)
--   beyond wall_at                    hard wall backstop (§15-2)      (off the map)
M.DEFAULTS = {
  safe_half_width = 24, -- |Y| <= 24: guaranteed-safe temperate band
  lethal_at       = 96, -- |Y| >= 96: damage has ramped to its maximum
  wall_at         = 128, -- |Y| >= 128: hard-wall backstop (never walk into instant death)

  temp_center  = 25, -- terminator centre: room temperature
  temp_hot_max = 1500, -- sunward saturation: manufactured-lava hot
  temp_cold_min = -270, -- nightward saturation: near absolute zero (gases freeze out)

  -- Damage-per-second at the lethal saturation point, applied to the player
  -- (and, later, unshielded buildings). Survivable BRIEFLY with gear so the
  -- best edge resources are reachable at a cost (§4 edge-pushing).
  max_dps = 200,

  -- Solar output falloff (§ solar-scales-with-sunward-position, ci-9ht). Solar
  -- panels only REALLY work on the sunny (sunward, +Y) part of the ribbon: a
  -- panel's output fraction ramps from `solar_floor` (nightward) up to 1.0
  -- (deep sunward), so placement is a real decision (build sunward, toward the
  -- heat/danger, for power). Anchored to the SAME axis as everything else so
  -- when the axis orientation becomes configurable (worldgen-v2, ci-i8a) this
  -- follows automatically. (tune) -- balance pass is §15-14.
  solar_full_at = 96,  -- y >= this (the sunward lethal margin): full output.
  solar_zero_at = -24, -- y <= this (the nightward safe edge): floor output.
  solar_floor   = 0.0, -- output fraction on the far nightward side (~nothing).
}

-- Clamp helper (kept local so the module has zero external deps).
local function clamp(x, lo, hi)
  if x < lo then return lo end
  if x > hi then return hi end
  return x
end

-- Linear interpolation.
local function lerp(a, b, t)
  return a + (b - a) * t
end

-- Fill in any missing config keys from DEFAULTS, so callers can pass a partial
-- override table (or nil) and still get a complete, valid config.
function M.resolve(cfg)
  cfg = cfg or {}
  local out = {}
  for k, v in pairs(M.DEFAULTS) do
    local override = cfg[k]
    out[k] = (override ~= nil) and override or v
  end
  return out
end

-- Temperature (°C) at ribbon coordinate `y`.
--   y = 0            -> temp_center
--   y -> +wall_at    -> temp_hot_max  (sunward)
--   y -> -wall_at    -> temp_cold_min (nightward)
-- Interpolated linearly from the centre to each saturation edge, then held flat
-- beyond it. Symmetric geometry, asymmetric endpoints (fire one way, ice the
-- other) — the planet's whole thesis in one curve.
function M.temperature(y, cfg)
  cfg = M.resolve(cfg)
  local edge = cfg.wall_at
  if y >= 0 then
    local t = clamp(y / edge, 0, 1)
    return lerp(cfg.temp_center, cfg.temp_hot_max, t)
  else
    local t = clamp(-y / edge, 0, 1)
    return lerp(cfg.temp_center, cfg.temp_cold_min, t)
  end
end

-- Zone classification at coordinate `y`. One of:
--   "safe"        temperate ribbon, no damage
--   "hot_warn"    sunward margin: ticking heat damage, survivable briefly
--   "hot_lethal"  sunward deep edge: full heat damage
--   "cold_warn"   nightward margin: ticking cold damage, survivable briefly
--   "cold_lethal" nightward deep edge: full cold damage
function M.zone(y, cfg)
  cfg = M.resolve(cfg)
  local d = math.abs(y)
  if d <= cfg.safe_half_width then return "safe" end
  local sunward = y > 0
  if d >= cfg.lethal_at then
    return sunward and "hot_lethal" or "cold_lethal"
  end
  return sunward and "hot_warn" or "cold_warn"
end

-- True once past the hard-wall backstop (§15-2): the extreme edge where tiles
-- become impassable so the player can never walk off the usable map into instant
-- death. The damage ramp does the teaching; this is the bulletproof floor.
function M.past_wall(y, cfg)
  cfg = M.resolve(cfg)
  return math.abs(y) >= cfg.wall_at
end

-- Damage-per-second the environment inflicts at coordinate `y`.
--   |y| <= safe_half_width         -> 0                    (the ribbon is safe)
--   safe_half_width < |y| < lethal -> ramps 0 -> max_dps    (the survivable margin)
--   |y| >= lethal_at               -> max_dps               (the lethal deep edge)
-- The ramp is what makes edge-pushing a graded risk rather than a cliff: the
-- best resources sit just inside the lethal band, reachable with mitigation.
-- `damage_type` is "heat" sunward, "cold" nightward (callers pick the matching
-- Factorio damage prototype).
function M.damage_per_second(y, cfg)
  cfg = M.resolve(cfg)
  local d = math.abs(y)
  local dps
  if d <= cfg.safe_half_width then
    dps = 0
  elseif d >= cfg.lethal_at then
    dps = cfg.max_dps
  else
    local t = (d - cfg.safe_half_width) / (cfg.lethal_at - cfg.safe_half_width)
    dps = cfg.max_dps * t
  end
  local damage_type = (y > 0) and "heat" or "cold"
  return dps, damage_type
end

-- Solar output FRACTION (0..1) a panel earns at ribbon coordinate `y` (§ ci-9ht).
-- This is the "how sunny is it here" curve, the spatial companion to the flare's
-- temporal curve: the two MULTIPLY (a panel's real output = nominal * intensity
-- * sunward_factor(y)), they don't replace each other.
--   y >= solar_full_at   -> 1.0        (deep sunward: full sun, the reward for
--                                        building toward the heat/danger)
--   y <= solar_zero_at    -> solar_floor (nightward: ~nothing; a panel here is
--                                        near-useless, so placement matters)
--   between               -> linear ramp solar_floor -> 1.0
-- Same +Y-sunward convention as temperature()/zone(): this reads the ONE axis,
-- so it never re-derives the hot-cold orientation.
function M.sunward_factor(y, cfg)
  cfg = M.resolve(cfg)
  local full, zero, floor = cfg.solar_full_at, cfg.solar_zero_at, cfg.solar_floor
  if y >= full then return 1.0 end
  if y <= zero then return floor end
  local t = (y - zero) / (full - zero)
  return floor + (1 - floor) * t
end

return M
