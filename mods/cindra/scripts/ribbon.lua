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
-- This module is DELIBERATELY PURE: no `game.*` / `prototypes.*` access. It maps a
-- perpendicular coordinate to TWO continuous curves, and nothing else:
--   * TEMPERATURE (M.temperature) -- how hot it is here. Read by
--     scripts/damage-feedback.lua for the ambient thermal grade.
--   * SUNLIGHT (M.sunward_factor) -- what fraction of full output a solar panel
--     earns here. Read by scripts/panel-solar.lua.
-- That keeps the axis maths fast, deterministic, and testable in plain Lua
-- (unit-tests/), and lets both systems read the SAME single source of truth for
-- "where am I on the hot-cold axis."
--
-- WHAT IT IS NOT (ci-7k6). It does NOT own the world's BOUNDARIES -- not the safe
-- band, not the lethal edges, not the map edge. Those are all derived from the ONE
-- heightmap and its per-zone widths in scripts/terrain.lua, and the damage a player
-- actually takes is keyed to the TILE they stand on (scripts/tile-damage.lua).
-- A band layout used to live here too, with three mod settings feeding it and no
-- runtime caller reading it; see the note above M.DEFAULTS.
--
-- The one place it reaches sideways is the SOLAR falloff (M.sunward_factor): its
-- anchors are DERIVED from the live ci-da2 zone layout (scripts/terrain.lua, an
-- equally pure sibling that reads the same axis), so the solar curve tracks the
-- actual worldgen zone widths instead of stale fixed tiles (ci-22v). terrain reads
-- no game.*/prototypes.* either, so the module stays plain-Lua testable.

local terrain = require("scripts.terrain")

local M = {}

-- Tuning defaults (§16). Distances are in TILES from the ribbon centre (p = 0);
-- temperatures are flavour/scaling values in degrees Celsius. All (tune).
--
-- WHAT THIS MODULE STOPPED OWNING (ci-7k6). It used to carry a whole BAND LAYOUT
-- too -- a safe half-width, a damage ramp saturating at `lethal_at`, and a
-- `wall_at` hard-wall backstop -- with `zone()`, `damage_per_second()` and
-- `past_wall()` reading it, and three mod settings feeding it. Not one of those had
-- a runtime caller: the world's damage is keyed to the TILE an entity stands on
-- (scripts/tile-damage.lua + terrain.tile_damage, ci-ma18), the safe/lethal
-- boundaries are wherever the ONE heightmap crosses its damage thresholds
-- (scripts/terrain.lua), and ci-wly dropped the hard wall entirely (the world edge
-- is the map-gen's finite dimension = the sum of the zone widths). They were
-- deleted rather than re-wired, because a second copy of the ribbon geometry here
-- is precisely the "one source of truth" breach this module exists to prevent.
-- What remains is the TEMPERATURE curve and the SOLAR falloff -- both live, both
-- read by real systems (scripts/damage-feedback.lua, scripts/panel-solar.lua).
M.DEFAULTS = {
  -- Half-width (tiles) over which the temperature curve reaches its saturation
  -- endpoints. This is a curve parameter, NOT a world boundary -- there is no wall
  -- to hit at this distance. The live caller derives it from the real ribbon
  -- half-width (scripts/damage-feedback.lua); the default is only what a caller
  -- that passes no cfg gets.
  saturate_at   = 128,

  temp_center  = 25, -- terminator centre: room temperature
  temp_hot_max = 1500, -- sunward saturation: manufactured-lava hot
  temp_cold_min = -270, -- nightward saturation: near absolute zero (gases freeze out)

  -- Solar output falloff (§ solar-scales-with-sunward-position, ci-9ht; recalibrated
  -- to the ci-da2 zoned worldgen, ci-22v). Solar panels only REALLY work on the
  -- sunny (sunward) part of the ribbon: a panel's output fraction ramps from
  -- `solar_floor` (nightward) up to 1.0 (deep sunward), so placement is a real
  -- decision (build sunward, toward the heat/danger, for power). The full/zero
  -- ANCHORS are NOT fixed tiles: they are derived from the live zone layout (see
  -- M.solar_anchors) so full output lands only on the LAVA side and output reaches
  -- ~nothing by the temperate->ice boundary, tracking the actual worldgen widths.
  -- A cfg may still override `solar_full_at` / `solar_zero_at` (tuning / tests);
  -- when it does NOT, the zone-derived defaults apply. (tune) -- balance is §15-14.
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
--   y = 0              -> temp_center
--   y -> +saturate_at  -> temp_hot_max  (sunward)
--   y -> -saturate_at  -> temp_cold_min (nightward)
-- Interpolated linearly from the centre to each saturation edge, then held flat
-- beyond it. Symmetric geometry, asymmetric endpoints (fire one way, ice the
-- other) — the planet's whole thesis in one curve.
function M.temperature(y, cfg)
  cfg = M.resolve(cfg)
  local edge = cfg.saturate_at
  if y >= 0 then
    local t = clamp(y / edge, 0, 1)
    return lerp(cfg.temp_center, cfg.temp_hot_max, t)
  else
    local t = clamp(-y / edge, 0, 1)
    return lerp(cfg.temp_center, cfg.temp_cold_min, t)
  end
end

-- (`M.zone`, `M.damage_per_second` and `M.past_wall` lived here until ci-7k6.
-- WHERE THEIR JOBS WENT, if you come looking for them:
--   * "is this position safe, and to which extreme does it belong?"
--       -> terrain.lethal_at(p) / terrain.damage_bounds(), read off the ONE
--          heightmap rather than a distance from centre;
--   * "how much damage does the environment do here?"
--       -> terrain.tile_damage(tile_name) scaled by the `cindra-ribbon-max-dps`
--          setting, applied per-entity by scripts/tile-damage.lua. It is keyed to
--          the TILE, so concrete shields and every hazard tile bites (ci-ma18);
--   * "where does the world end?"
--       -> terrain.map_gen_bounds(), the map-gen's own finite dimension. There is
--          no wall to be past: ci-wly dropped the impassable ice-wall and the hot
--          lava ocean is the only ground you cannot walk on.
-- Do not reintroduce them: each would be a second, drifting copy of geometry that
-- terrain.lua already owns.)

-- The solar falloff ANCHORS for the live zone layout (ci-22v). Returns
-- (full_at, zero_at, floor):
--   full_at : y >= this earns full output (1.0). Derived from the inner edge of
--             the hot DAMAGING rings (terrain hot_inner.lo), so full sun lands ONLY
--             on the lava/hot side -- the reward for building toward the danger --
--             and NOT at the habitable middle (the ci-22v bug: it used to hit full
--             near spawn and stay flat into the lava).
--   zero_at : y <= this earns the floor. Derived from the MIDDLE->COLD boundary
--             (terrain middle.lo, the habitable middle's cold edge), so output falls
--             to ~nothing across the ribbon and a panel on the ice side makes
--             essentially nothing.
--   floor   : the far-nightward output fraction (solar_floor).
-- Anchors are read from terrain with the LIVE widths (settings / defaults), so
-- recalibrating a zone width keeps the solar curve sensible. A cfg may override
-- either anchor (tuning / tests); cfg.zone_widths (a terrain widths table keyed by
-- role) lets a caller derive the anchors for a DIFFERENT layout (worldgen tests).
function M.solar_anchors(cfg)
  cfg = cfg or {}
  local widths = cfg.zone_widths
  local full = cfg.solar_full_at
  local zero = cfg.solar_zero_at
  if full == nil then full = terrain.role_band("hot_inner", widths).lo end
  if zero == nil then zero = terrain.role_band("middle", widths).lo end
  local floor = cfg.solar_floor
  if floor == nil then floor = M.DEFAULTS.solar_floor end
  return full, zero, floor
end

-- Solar output FRACTION (0..1) a panel earns at ribbon coordinate `y` (§ ci-9ht).
-- This is the "how sunny is it here" curve, the spatial companion to the flare's
-- temporal curve: the two MULTIPLY (a panel's real output = nominal * intensity
-- * sunward_factor(y)), they don't replace each other.
--   y >= full_at   -> 1.0        (the lava/hot side: full sun, the reward for
--                                  building toward the heat/danger)
--   y <= zero_at    -> floor      (the temperate->ice boundary and beyond: ~nothing;
--                                  a panel here is near-useless, so placement matters)
--   between         -> linear ramp floor -> 1.0
-- The anchors come from M.solar_anchors (derived from the zone layout), so this
-- tracks the real worldgen. Same sunward-positive convention as temperature()/
-- zone(): it reads the ONE axis, never re-deriving the hot-cold orientation.
function M.sunward_factor(y, cfg)
  local full, zero, floor = M.solar_anchors(cfg)
  if y >= full then return 1.0 end
  if y <= zero then return floor end
  local t = (y - zero) / (full - zero)
  return floor + (1 - floor) * t
end

return M
