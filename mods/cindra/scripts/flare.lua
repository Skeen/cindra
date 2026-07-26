-- The solar flare cycle (§15-7; DESIGN.md §5 "high-intensity solar via the
-- daylight curve"). Integrated from the proven flare-poc (ci-zg3).
--
-- Implemented via the ENGINE DAYLIGHT CURVE plus a fixed high surface solar
-- multiplier - no bespoke power system, no artificial overdrive. The flare is
-- the daylight cycle driven to full day; the "dim" between-flare trough is a
-- near-night daytime whose non-zero solar factor, scaled by the fixed
-- SOLAR_MULT, still delivers a Nauvis-full-day-grade baseline (the night floor
-- that runs the factory between flares).
--
-- `state(tick)` is a PURE function of the tick: the whole schedule is
-- deterministic and telegraphed (telegraph -> fast ramp -> plateau -> fast
-- decay), so capture/dump capacity can be engineered against a known magnitude
-- and cadence. It is exercised directly by the plain-Lua unit test
-- (unit-tests/test_flare.lua) and the integration test (tests/test_flare.lua).
--
-- Intensity is expressed in "Nauvis full-day equivalents": BASELINE_INTENSITY
-- (=1) between flares, PEAK_INTENSITY (=SOLAR_MULT, ~100x) at the plateau. The
-- engine's actual per-panel output = PANEL_NOMINAL_W * intensity, because we
-- drive daytime so that solar_factor = intensity / SOLAR_MULT.

local C = require("scripts.flare-config")

local M = {}

M.PHASE = {
  CALM = "calm",
  WARNING = "warning",
  RAMP = "ramp",
  PLATEAU = "plateau",
  DECAY = "decay",
}

-- Phase boundaries within one period (offset in [0, PERIOD_TICKS)).
local CALM_END = C.CALM_TICKS
local WARNING_END = CALM_END + C.WARNING_TICKS
local RAMP_END = WARNING_END + C.RAMP_TICKS
local PLATEAU_END = RAMP_END + C.PLATEAU_TICKS

local BASE = C.BASELINE_INTENSITY
local PEAK = C.PEAK_INTENSITY
local SWING = PEAK - BASE

-- Deterministic flare state at a given tick. Returns:
--   phase     one of M.PHASE.*
--   intensity Nauvis-full-day equivalents (BASE..PEAK)
--   warning   true during the telegraph (alarm + countdown, power still at BASE)
--   countdown ticks remaining until the ramp begins (only during WARNING)
--   is_flare  true whenever intensity is above baseline (ramp/plateau/decay)
function M.state(tick)
  local off = tick % C.PERIOD_TICKS
  local phase, intensity, warning, countdown = M.PHASE.CALM, BASE, false, 0

  if off < CALM_END then
    phase, intensity = M.PHASE.CALM, BASE
  elseif off < WARNING_END then
    phase, intensity, warning = M.PHASE.WARNING, BASE, true
    countdown = WARNING_END - off
  elseif off < RAMP_END then
    phase = M.PHASE.RAMP
    intensity = BASE + SWING * ((off - WARNING_END) / C.RAMP_TICKS)
  elseif off < PLATEAU_END then
    phase, intensity = M.PHASE.PLATEAU, PEAK
  else
    phase = M.PHASE.DECAY
    intensity = PEAK - SWING * ((off - PLATEAU_END) / C.DECAY_TICKS)
  end

  return {
    phase = phase,
    intensity = intensity,
    warning = warning,
    countdown = countdown,
    is_flare = intensity > BASE + 1e-9,
  }
end

-- Canonical solar factor (0..1) for an intensity: sf * SOLAR_MULT == intensity.
function M.solar_factor(intensity)
  return intensity / C.SOLAR_MULT
end

-- The daytime that yields `intensity` on this surface's daylight curve. Solar
-- output ramps 1 -> 0 linearly across [dusk, evening]; we invert that. Read the
-- surface's own dusk/evening so we stay consistent with whatever curve it has
-- (never write them - that avoids depending on runtime write access and keeps
-- the engine's real output matching our canonical intensity for ANY dusk/evening).
function M.daytime_for(surface, intensity)
  local dusk = surface.dusk or C.DUSK
  local evening = surface.evening or C.EVENING
  local sf = M.solar_factor(intensity)
  if sf > 1 then sf = 1 elseif sf < 0 then sf = 0 end
  return dusk + (evening - dusk) * (1 - sf)
end

-- Apply the flare at `tick` to a surface: a frozen daytime driven along the
-- flare curve. Records the state in storage for the damage sweep. Per-surface
-- only; never touches another planet.
--
-- The fixed high solar multiplier (~100x) is the planet's `solar-power` surface
-- property (prototypes/planet.lua), so the engine's effective multiplier is
-- SOLAR_MULT and driving daytime to solar_factor = intensity/SOLAR_MULT makes a
-- panel's real output exactly production * intensity. We do NOT also write
-- surface.solar_power_multiplier here: that would stack ON TOP of the property
-- and over-scale the whole curve (baseline included). The flare swing is the
-- daylight cycle, not the multiplier (the locked §10 model).
function M.apply(surface, tick)
  local st = M.state(tick)
  surface.freeze_daytime = true
  surface.daytime = M.daytime_for(surface, st.intensity)
  storage.cindra_flare = st
  return st
end

-- Current intensity as last applied (defaults to baseline before any apply).
function M.current_intensity()
  local st = storage.cindra_flare
  if st then return st.intensity end
  return BASE
end

return M
