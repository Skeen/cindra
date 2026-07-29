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
--
-- ci-a35: the ribbon's perpendicular BAND LAYOUT is now the per-zone gradient in
-- scripts/zones.lua (an asymmetric hot->cold run of named bands, the SAND spawn
-- band OFF the geometric centre). So the temperate reference for the temperature
-- and solar curves is no longer p = 0 but the SAND-band centre (`ref`), with
-- asymmetric reaches to the hot / cold void edge -- all derived from zones. The
-- legacy safe_half_width / lethal_at / wall_at knobs remain UNCHANGED as the
-- resource-band geometry that scripts/resource-field.lua reads; player-facing
-- environmental damage is now the TILE damage (scripts/tile-damage.lua) keyed to
-- the visible bands, so the old abstract zone()/damage ramp is gone.

local zones = require("scripts.zones")

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
  -- RESOURCE-BAND geometry (scripts/resource-field.lua, atom's domain): unchanged
  -- symmetric knobs about p = 0. NOT the tile-band geometry (that is scripts/zones).
  safe_half_width = 24, -- resource: rocks scatter within |p| <= 24
  lethal_at       = 96, -- resource: stone band reaches out to +96 (hot margin)
  wall_at         = 128, -- resource: ice band reaches out to -128 (deep nightside)

  temp_center  = 25, -- the temperate SAND spawn (ref): room temperature
  temp_hot_max = 1500, -- sunward saturation: manufactured-lava hot
  temp_cold_min = -270, -- nightward saturation: near absolute zero (volatiles freeze out)

  -- Solar output falloff (§ solar-scales-with-sunward-position, ci-9ht). Solar is
  -- an ABSOLUTE function of sunward position (how much star flux reaches a tile),
  -- NOT a distance from the temperate spawn: a panel's output fraction ramps from
  -- `solar_floor` (nightward, ~nothing) up to 1.0 deep sunward (toward the fire
  -- bands), so building toward the heat/danger is the reward and placement is a
  -- real decision. Anchored to the sunward-positive perpendicular axis about 0.
  -- (tune) -- balance pass is §15-14.
  solar_full_at = 96,  -- perp >= this (deep sunward): full output.
  solar_zero_at = -24, -- perp <= this (nightward): floor output.
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

-- Fill in any missing config keys from DEFAULTS, and layer the zone-derived
-- geometry (the temperate reference `ref`, the asymmetric reaches to each void
-- edge, and the solar full/zero landmarks) on top, so callers can pass a partial
-- override table (or nil) and still get a complete, valid config. Explicit cfg
-- keys always win (so resource-field's {safe_half_width, lethal_at, wall_at} and
-- test overrides are honoured verbatim).
function M.resolve(cfg)
  cfg = cfg or {}
  local out = {}
  for k, v in pairs(M.DEFAULTS) do
    local override = cfg[k]
    out[k] = (override ~= nil) and override or v
  end
  -- Zone-derived temperate geometry (ci-a35). The SAND-band centre is the
  -- temperate reference; hot/cold reaches run from it to each void edge; solar is
  -- full on the hot fire margin and floors at the freeze boundary.
  local geo = zones.geometry()
  out.ref         = cfg.ref         or geo.ref
  out.hot_reach   = cfg.hot_reach   or math.max(1, geo.hot_reach)
  out.cold_reach  = cfg.cold_reach  or math.max(1, geo.cold_reach)
  out.solar_full  = cfg.solar_full  or geo.hot_damage_start
  out.solar_zero  = cfg.solar_zero  or geo.cold_damage_start
  return out
end

-- Temperature (°C) at perpendicular coordinate `p`.
--   p = ref               -> temp_center      (the SAND spawn: room temperature)
--   p -> +hot void edge    -> temp_hot_max     (sunward)
--   p -> -cold void edge   -> temp_cold_min    (nightward)
-- Interpolated linearly from the temperate reference to each saturation edge,
-- then held flat beyond it. Asymmetric reaches (the hot side is longer), asymmetric
-- endpoints (fire one way, ice the other) — the planet's whole thesis in one curve.
function M.temperature(p, cfg)
  cfg = M.resolve(cfg)
  local d = p - cfg.ref
  if d >= 0 then
    local t = clamp(d / cfg.hot_reach, 0, 1)
    return lerp(cfg.temp_center, cfg.temp_hot_max, t)
  else
    local t = clamp(-d / cfg.cold_reach, 0, 1)
    return lerp(cfg.temp_center, cfg.temp_cold_min, t)
  end
end

-- Solar output FRACTION (0..1) a panel earns at perpendicular coordinate `p`
-- (§ ci-9ht). The spatial companion to the flare's temporal curve: the two
-- MULTIPLY (real output = nominal * intensity * sunward_factor(p)).
--   p >= solar_full   -> 1.0         (deep sunward, toward the fire margin: full sun)
--   p <= solar_zero    -> solar_floor (deep nightward: ~nothing; placement matters)
--   between            -> linear ramp solar_floor -> 1.0
-- Reads the SAME zone gradient as temperature(), so it never re-derives the axis.
function M.sunward_factor(p, cfg)
  cfg = M.resolve(cfg)
  local full, zero, floor = cfg.solar_full, cfg.solar_zero, cfg.solar_floor
  if full <= zero then return floor end
  if p >= full then return 1.0 end
  if p <= zero then return floor end
  local t = (p - zero) / (full - zero)
  return floor + (1 - floor) * t
end

return M
