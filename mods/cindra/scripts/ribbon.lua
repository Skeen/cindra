-- The ribbon temperature axis (§4) — the geometric heart of Cindra, and the
-- SINGLE SOURCE OF TRUTH for "where am I on the hot-cold axis." (worldgen v2)
--
-- Cindra's map is a 1D RIBBON: long along the terminator, shallow perpendicular
-- to it. The perpendicular axis IS the planet's identity: hot at one end, cold at
-- the other, temperate in the seam. Everything (terrain, damage, resources) keys
-- off ONE signed coordinate: how far a point sits from the terminator centre
-- along that perpendicular axis.
--
--   +perp ->  SUNWARD   (ENERGY / heat)  : temperature RISES, lethal by heat
--      0      TERMINATOR (temperate)      : the survivable ribbon, no damage
--   -perp ->  NIGHTWARD  (MATTER / cold)  : temperature FALLS, lethal by cold
--
-- ORIENTATION (§15 v2 item 1): the ribbon's LONG axis is either east-west
-- (default: perpendicular axis = Y) or north-south (perpendicular axis = X). The
-- `perp(position)` / `along(position)` accessors are the ONE place that knows
-- which world coordinate is the sunward-nightward axis, so every downstream
-- system reads the axis the same way in BOTH orientations and no code hard-codes
-- x/y.
--
-- This module is DELIBERATELY PURE: no `game.*` / `prototypes.*` / `settings.*`
-- access. It maps a perpendicular coordinate (and, via the accessors, a position
-- + orientation) to a temperature, a zone and a damage profile, nothing more.
-- That keeps the axis maths fast, deterministic, and testable in plain Lua
-- (unit-tests/). Runtime application (ticking damage, freezing machines, painting
-- terrain, placing resources) lives in the scripts that consume this module.

local M = {}

-- The two ribbon orientations (the mod setting stores one of these strings).
M.ORIENTATIONS = { EAST_WEST = "east-west", NORTH_SOUTH = "north-south" }

-- Tuning defaults (§16). Distances are in TILES from the ribbon centre (perp = 0);
-- temperatures are flavour/scaling values in degrees Celsius. All (tune).
--
-- The band layout, from centre outward on EACH side (defaults are SYMMETRIC; the
-- per-side keys below let the hot and cold zones differ, driven by the sliders):
--   [0 .. safe_half_width]            temperate, no damage           (the ribbon)
--   (safe_half_width .. lethal_at]    damage ramp 0 -> max            (the margin)
--   (lethal_at .. wall_at]            full lethal damage              (the deep edge)
--   beyond wall_at                    hard wall backstop              (off the map)
M.DEFAULTS = {
  orientation = M.ORIENTATIONS.EAST_WEST,

  safe_half_width = 24, -- |perp| <= 24: guaranteed-safe temperate band

  -- Symmetric fallbacks. If the per-side keys (hot_/cold_ lethal_at / wall_at)
  -- are absent, both sides resolve from these — so an old symmetric config still
  -- works unchanged.
  lethal_at = 96,  -- |perp| >= 96: damage has ramped to its maximum
  wall_at   = 128, -- |perp| >= 128: hard-wall backstop

  temp_center  = 25, -- terminator centre: room temperature
  temp_hot_max = 1500, -- sunward saturation: manufactured-lava hot
  temp_cold_min = -270, -- nightward saturation: near absolute zero

  -- Damage-per-second at the lethal saturation point. Survivable BRIEFLY with
  -- gear so the player can push to the playable edge at a cost (§4 edge-pushing).
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

local function clamp(x, lo, hi)
  if x < lo then return lo end
  if x > hi then return hi end
  return x
end

local function lerp(a, b, t)
  return a + (b - a) * t
end

-- Fill in any missing config keys from DEFAULTS, then derive the per-side
-- (sunward "hot_" / nightward "cold_") boundaries, defaulting each to the
-- symmetric value so partial/symmetric configs keep working. Callers can pass a
-- partial override table (or nil) and always get a complete, valid config.
function M.resolve(cfg)
  cfg = cfg or {}
  local out = {}
  for k, v in pairs(M.DEFAULTS) do
    local override = cfg[k]
    out[k] = (override ~= nil) and override or v
  end
  -- Carry through any explicit per-side overrides too (not in DEFAULTS).
  out.hot_lethal_at  = cfg.hot_lethal_at  or out.lethal_at
  out.cold_lethal_at = cfg.cold_lethal_at or out.lethal_at
  out.hot_wall_at    = cfg.hot_wall_at    or out.wall_at
  out.cold_wall_at   = cfg.cold_wall_at   or out.wall_at
  return out
end

-- Orientation accessors — the ONLY place that maps a world position to the
-- ribbon axes. `perp` is the sunward-nightward (hot-cold) coordinate; `along` is
-- the long, resource-neutral axis. In east-west the ribbon runs left-right so the
-- perpendicular (scarcity) axis is Y; in north-south it runs top-bottom so the
-- perpendicular axis is X.
function M.perp(position, cfg)
  cfg = M.resolve(cfg)
  if cfg.orientation == M.ORIENTATIONS.NORTH_SOUTH then
    return position.x
  end
  return position.y
end

function M.along(position, cfg)
  cfg = M.resolve(cfg)
  if cfg.orientation == M.ORIENTATIONS.NORTH_SOUTH then
    return position.y
  end
  return position.x
end

-- Temperature (°C) at ribbon perpendicular coordinate `p`.
--   p = 0                -> temp_center
--   p -> +hot_wall_at    -> temp_hot_max  (sunward)
--   p -> -cold_wall_at   -> temp_cold_min (nightward)
-- Interpolated linearly from the centre to each saturation edge, then held flat
-- beyond it. Symmetric geometry, asymmetric endpoints (fire one way, ice the
-- other) — the planet's whole thesis in one curve.
function M.temperature(p, cfg)
  cfg = M.resolve(cfg)
  if p >= 0 then
    local t = clamp(p / cfg.hot_wall_at, 0, 1)
    return lerp(cfg.temp_center, cfg.temp_hot_max, t)
  else
    local t = clamp(-p / cfg.cold_wall_at, 0, 1)
    return lerp(cfg.temp_center, cfg.temp_cold_min, t)
  end
end

-- Zone classification at perpendicular coordinate `p`. One of:
--   "safe"        temperate ribbon, no damage
--   "hot_warn"    sunward margin: ticking heat damage, survivable briefly
--   "hot_lethal"  sunward deep edge: full heat damage
--   "cold_warn"   nightward margin: ticking cold damage, survivable briefly
--   "cold_lethal" nightward deep edge: full cold damage
function M.zone(p, cfg)
  cfg = M.resolve(cfg)
  local d = math.abs(p)
  if d <= cfg.safe_half_width then return "safe" end
  if p > 0 then
    return (d >= cfg.hot_lethal_at) and "hot_lethal" or "hot_warn"
  else
    return (d >= cfg.cold_lethal_at) and "cold_lethal" or "cold_warn"
  end
end

-- True once past the hard-wall backstop: the extreme edge where tiles become
-- impassable (out-of-map) so the player can never walk off the usable map into
-- instant death. Per-side (the hot and cold zones can differ in depth).
function M.past_wall(p, cfg)
  cfg = M.resolve(cfg)
  if p >= 0 then return p >= cfg.hot_wall_at end
  return -p >= cfg.cold_wall_at
end

-- Damage-per-second the environment inflicts at perpendicular coordinate `p`.
--   |p| <= safe_half_width         -> 0                    (the ribbon is safe)
--   safe < |p| < lethal (per side) -> SMOOTH ease-in 0 -> max_dps  (the margin)
--   |p| >= lethal (per side)       -> max_dps               (the lethal deep edge)
-- A SMOOTH GRADIENT (Implementation A): the ramp is an ease-in curve (t^2), so
-- damage starts GENTLE at the zone entry and accelerates CONTINUOUSLY with depth
-- toward the lethal edge -- a graded, telegraphed risk rather than a cliff, and
-- strictly increasing with depth so pushing further always hurts more. Applies to
-- both fire (sunward) and freeze (nightward). `damage_type` is "heat" sunward,
-- "cold" nightward (callers pick the matching damage prototype).
function M.damage_per_second(p, cfg)
  cfg = M.resolve(cfg)
  local d = math.abs(p)
  local lethal_at = (p > 0) and cfg.hot_lethal_at or cfg.cold_lethal_at
  local dps
  if d <= cfg.safe_half_width then
    dps = 0
  elseif d >= lethal_at then
    dps = cfg.max_dps
  else
    local t = (d - cfg.safe_half_width) / (lethal_at - cfg.safe_half_width)
    dps = cfg.max_dps * t * t -- ease-in: gentle at entry, ramps up with depth
  end
  local damage_type = (p > 0) and "heat" or "cold"
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
