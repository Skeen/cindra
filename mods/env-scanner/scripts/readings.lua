-- The environmental scanner's reading maths -- the single source of truth for
-- "what does this surface look like right now, as circuit signals."
--
-- This module is DELIBERATELY PURE: no `game.*` / `prototypes.*` / `remote.*`
-- access. It maps a surface's daytime + solar multiplier (and an optional flare
-- forecast) to a set of integer circuit signals. Keeping it pure means the whole
-- signal maths is fast, deterministic, and reachable from a plain-Lua unit test
-- (unit-tests/test_readings.lua); the factorio-test in tests/test_scanner.lua
-- asserts the SAME behaviour under the real runtime. Keep the two in sync.
--
-- Circuit values are integers, so the continuous readouts are SCALED to fixed
-- integer ranges (documented per signal below and in README.md). The scanner's
-- runtime (scripts/scanner.lua) reads live surface state, calls in here, and
-- writes the result to the entity's constant-combinator output.

local M = {}

-- The virtual signals this scanner can emit. Names are shared with the data
-- stage (prototypes/scanner.lua defines the virtual-signal prototypes) and the
-- runtime writer, so all three agree on one spelling.
M.SIGNALS = {
  -- Generic surface readouts (meaningful on ANY planet):
  DAYTIME     = "env-daytime",      -- day/night cycle position, permille 0..1000
  DAYLIGHT    = "env-daylight",     -- daylight fraction, percent 0..100
  SOLAR       = "env-solar",        -- solar output, percent = daylight * multiplier
  TICK_OF_DAY = "env-tick-of-day",  -- integer tick within the current day

  -- Cindra flare forecast (only emitted when a flare provider is present):
  FLARE_COUNTDOWN = "env-flare-countdown", -- ticks until the next flare ramp
  FLARE_PHASE     = "env-flare-phase",     -- phase code (see PHASE_CODE)
  FLARE_INTENSITY = "env-flare-intensity", -- intensity, percent of baseline (100 = 1x)
}

-- Flare phase string -> integer code emitted on FLARE_PHASE. Documented so a
-- player's circuit logic can branch on the phase (e.g. "ramp -> fill capacitors").
M.PHASE_CODE = {
  calm    = 0,
  warning = 1,
  ramp    = 2,
  plateau = 3,
  decay   = 4,
}

-- Nominal day length (ticks) used to scale TICK_OF_DAY. Nauvis' default day is
-- 25000 ticks; the runtime passes this in so the constant lives in config.lua.
M.DEFAULT_DAY_TICKS = 25000

-- The engine's default daylight curve points (used only as a fallback when a
-- surface does not supply its own). Order: dusk < evening < morning < dawn.
-- daytime 0 = noon (full sun); the sun dims dusk->evening, is dark
-- evening->morning, and brightens morning->dawn.
M.DEFAULT_CURVE = { dusk = 0.25, evening = 0.45, morning = 0.55, dawn = 0.75 }

local function clamp(x, lo, hi)
  if x < lo then return lo end
  if x > hi then return hi end
  return x
end

local function round(x)
  return math.floor(x + 0.5)
end

-- Normalise a daytime to [0, 1).
local function wrap01(t)
  t = t % 1.0
  if t < 0 then t = t + 1.0 end
  return t
end

-- Daylight fraction (0..1) for a daytime on the engine's solar curve. This is
-- the same shape the base game uses for solar-panel output: full sun outside
-- [dusk, morning], a linear dim dusk->evening, full dark evening->morning, and a
-- linear brighten morning->dawn. Degenerate ramps (evening<=dusk, dawn<=morning)
-- collapse to an instant step rather than dividing by zero.
function M.solar_factor(daytime, curve)
  curve = curve or M.DEFAULT_CURVE
  local dusk    = curve.dusk    or M.DEFAULT_CURVE.dusk
  local evening = curve.evening or M.DEFAULT_CURVE.evening
  local morning = curve.morning or M.DEFAULT_CURVE.morning
  local dawn    = curve.dawn    or M.DEFAULT_CURVE.dawn

  local t = wrap01(daytime)
  if t <= dusk then
    return 1.0
  elseif t < evening then
    if evening <= dusk then return 0.0 end
    return clamp(1.0 - (t - dusk) / (evening - dusk), 0.0, 1.0)
  elseif t < morning then
    return 0.0
  elseif t < dawn then
    if dawn <= morning then return 1.0 end
    return clamp((t - morning) / (dawn - morning), 0.0, 1.0)
  else
    return 1.0
  end
end

-- The generic per-surface signal set. `daytime` in [0,1), `solar_multiplier` is
-- surface.solar_power_multiplier (1.0 on a normal planet), `day_ticks` scales
-- TICK_OF_DAY, `curve` carries the surface's dusk/evening/morning/dawn. All
-- outputs are integers ready to drop straight into a constant combinator slot.
function M.surface_signals(daytime, solar_multiplier, day_ticks, curve)
  solar_multiplier = solar_multiplier or 1.0
  day_ticks = day_ticks or M.DEFAULT_DAY_TICKS

  local t = wrap01(daytime)
  local sf = M.solar_factor(t, curve)

  local out = {}
  out[M.SIGNALS.DAYTIME]     = round(t * 1000)                       -- 0..1000
  out[M.SIGNALS.DAYLIGHT]    = round(sf * 100)                       -- 0..100
  out[M.SIGNALS.SOLAR]       = round(sf * solar_multiplier * 100)    -- percent
  out[M.SIGNALS.TICK_OF_DAY] = math.floor(t * day_ticks)             -- 0..day_ticks-1
  return out
end

-- Merge a flare forecast into an existing signal table (in place) and return it.
-- `forecast` is the cross-mod contract shape: { countdown, phase, intensity }.
--   countdown  ticks until the next flare ramp (integer-ish; rounded)
--   phase      one of the PHASE_CODE keys ("calm".."decay")
--   intensity  Nauvis-full-day equivalents (1.0 = baseline) -> emitted as percent
-- Missing fields are simply skipped, so partial forecasts degrade gracefully.
function M.merge_forecast(out, forecast)
  if not forecast then return out end
  if forecast.countdown ~= nil then
    out[M.SIGNALS.FLARE_COUNTDOWN] = math.floor(forecast.countdown + 0.5)
  end
  if forecast.phase ~= nil then
    out[M.SIGNALS.FLARE_PHASE] = M.PHASE_CODE[forecast.phase] or 0
  end
  if forecast.intensity ~= nil then
    out[M.SIGNALS.FLARE_INTENSITY] = round(forecast.intensity * 100)
  end
  return out
end

return M
