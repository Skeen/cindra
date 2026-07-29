-- The solar flare cycle (§15-7; DESIGN.md §5 "high-intensity solar via the
-- daylight curve"). Integrated from the proven flare-poc (ci-zg3).
--
-- Implemented via the ENGINE DAYLIGHT CURVE plus a fixed high surface solar
-- multiplier - no bespoke power system, no artificial overdrive. The flare is
-- the daylight cycle driven to full day (~6 MW/panel peak); the "dim"
-- between-flare trough is a near-night daytime whose non-zero solar factor,
-- scaled by the fixed 100x surface multiplier, still delivers a 400 kW baseline
-- (ci-ezk: the night floor that runs the factory between flares, and beats
-- Vulcanus's 240 kW -- Cindra is the best solar planet). The sky LOOKS dark at
-- baseline (a deep-dusk daytime) but production is decoupled from that dimness.
--
-- SPORADIC timing (ci-2ba): flares no longer fire on a fixed metronome. The
-- calm gap before each event is a random draw (unpredictable WHEN), while the
-- event's telegraph -> fast ramp -> plateau -> fast decay SHAPE and its ~6 MW peak
-- magnitude are unchanged (so capacity sizing still matters, and every event is
-- still telegraphed so you can react per-event). The design splits into:
--   * `state(tick, warning_start)` - a PURE function: the flare shape at `tick`
--     given the anchor tick at which THIS event's telegraph begins. Testable in
--     plain Lua (unit-tests/test_flare.lua).
--   * a SCHEDULER (`ensure_schedule`/`advance_schedule`) that persists the next
--     event's warning_start plus a deterministic PRNG state in `storage`, and
--     rolls a fresh random calm after each event. Deterministic + save/load
--     stable + desync-safe (a Lehmer PRNG, NOT math.random), yet unpredictable
--     to the player.
--   * `forecast(surface_index)` - the cross-mod remote source the environmental
--     scanner (ci-3o3) reads: nil during calm, a live forecast once a flare is
--     telegraphing/active. That is what makes the scanner a REACTIVE early
--     warning device instead of a schedule display.
--
-- Intensity is expressed in "Nauvis full-day equivalents": BASELINE_INTENSITY
-- (~6.67 => 400 kW) between flares, PEAK_INTENSITY (=SOLAR_MULT => ~6 MW, full
-- daylight) at the plateau -- a ~15x swing (ci-ezk). The engine's actual
-- per-panel output = PANEL_NOMINAL_W * intensity, because we drive daytime so
-- that solar_factor = intensity / SOLAR_MULT.

local C = require("scripts.flare-config")

local M = {}

M.PHASE = {
  CALM = "calm",
  WARNING = "warning",
  RAMP = "ramp",
  PLATEAU = "plateau",
  DECAY = "decay",
}

-- Event-relative phase boundaries: offsets measured FROM warning_start (the tick
-- an event's telegraph begins), so an event spans [0, EVENT_END). Outside that
-- window the surface is CALM on the baseline floor.
local WARNING_END = C.WARNING_TICKS
local RAMP_END = WARNING_END + C.RAMP_TICKS
local PLATEAU_END = RAMP_END + C.PLATEAU_TICKS
local EVENT_END = PLATEAU_END + C.DECAY_TICKS -- == C.EVENT_TICKS
M.EVENT_TICKS = EVENT_END

local BASE = C.BASELINE_INTENSITY
local PEAK = C.PEAK_INTENSITY
local SWING = PEAK - BASE

-- === Deterministic PRNG (Lehmer / MINSTD) ====================================
-- Sporadic timing must be desync-safe and stable across save/load, so we do NOT
-- use math.random (the codebase avoids it too). A tiny Lehmer generator, whose
-- integer state persists in `storage`, gives reproducible-yet-unpredictable calm
-- gaps. RNG_MUL * (RNG_MOD-1) < 2^53 stays exact in double precision, so it runs
-- identically in Factorio's Lua 5.2 and the plain-Lua unit test - no bit ops, no
-- 64-bit integers required.
local RNG_MOD = 2147483647 -- 2^31 - 1 (prime)
local RNG_MUL = 16807      -- 16807 * (RNG_MOD-1) ~= 3.6e13 < 2^53

-- Advance a Lehmer state (state in [1, RNG_MOD-1]) -> next state.
function M.rng_next(state)
  return (RNG_MUL * state) % RNG_MOD
end

-- Coerce any integer into the valid non-zero Lehmer range (0 is a fixed point).
local function rng_sanitize(state)
  state = math.floor(state) % RNG_MOD
  if state <= 0 then state = 1 end
  return state
end

-- Draw a random calm gap (ticks) in [CALM_MIN, CALM_MAX] from a Lehmer state.
-- Returns the gap AND the advanced state (the caller persists the new state).
function M.next_calm(state)
  state = M.rng_next(state)
  local span = C.CALM_MAX_TICKS - C.CALM_MIN_TICKS
  if span <= 0 then return C.CALM_MIN_TICKS, state end
  local gap = C.CALM_MIN_TICKS + math.floor((state / RNG_MOD) * (span + 1))
  if gap > C.CALM_MAX_TICKS then gap = C.CALM_MAX_TICKS end
  return gap, state
end

-- Deterministic flare state at `tick`, given `warning_start` (the tick this
-- event's telegraph begins). PURE: no game.* / storage. Returns:
--   phase     one of M.PHASE.*
--   intensity Nauvis-full-day equivalents (BASE..PEAK)
--   warning   true during the telegraph (alarm + countdown, power still at BASE)
--   countdown ticks remaining until the ramp begins (only during WARNING)
--   is_flare  true whenever intensity is above baseline (ramp/plateau/decay)
function M.state(tick, warning_start)
  local off = tick - (warning_start or 0)
  local phase, intensity, warning, countdown = M.PHASE.CALM, BASE, false, 0

  if off < 0 or off >= EVENT_END then
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

-- === Sporadic scheduler ======================================================
-- storage.cindra_flare_sched = { warning_start = <tick>, rng = <Lehmer state> }.
-- warning_start is the anchor of the CURRENT-or-NEXT event; rng carries the
-- persisted PRNG so each completed event rolls a fresh random calm.

-- A per-map RNG seed so different saves get different sporadic sequences. Read
-- from the surface's map seed when available (read-only), mixed so seed 0/1 do
-- not degenerate, with a nonzero fallback.
function M.seed_for(surface)
  local seed = 1
  local ok, mgs = pcall(function() return surface.map_gen_settings end)
  if ok and mgs and mgs.seed then seed = mgs.seed end
  return rng_sanitize(seed + 2654435761)
end

-- Create the schedule once (idempotent): the first event's telegraph starts one
-- random calm after `now`. `seed` varies the sequence per map.
function M.ensure_schedule(now, seed)
  local s = storage.cindra_flare_sched
  if s then return s end
  local gap, rng = M.next_calm(rng_sanitize(seed or 1))
  s = { warning_start = now + gap, rng = rng }
  storage.cindra_flare_sched = s
  return s
end

-- Advance the schedule so `tick` sits within the current event window or in the
-- calm before the next event. Each fully-decayed event rolls a fresh random calm
-- from the persisted RNG (unpredictable gap, reproducible on save/load). Returns
-- the active warning_start anchor.
function M.advance_schedule(tick)
  local s = M.ensure_schedule(tick)
  while tick >= s.warning_start + EVENT_END do
    local gap, rng = M.next_calm(s.rng)
    s.rng = rng
    s.warning_start = s.warning_start + EVENT_END + gap
  end
  return s.warning_start
end

-- Test seam: pin the schedule to a known warning_start (and optional rng state)
-- so apply/forecast tests can drive a deterministic flare. The real runtime never
-- calls this - it seeds + rolls via ensure_schedule / advance_schedule.
function M.set_schedule(warning_start, rng)
  storage.cindra_flare_sched = { warning_start = warning_start, rng = rng_sanitize(rng or 1) }
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

-- Apply the flare at `tick` to a surface: advance the sporadic schedule, then
-- drive a frozen daytime along the flare curve for the active event. Records the
-- state in storage for the damage sweep. Per-surface only; never touches another
-- planet.
--
-- The fixed high solar multiplier (~100x) is the planet's `solar-power` surface
-- property (prototypes/planet.lua), so the engine's effective multiplier is
-- SOLAR_MULT and driving daytime to solar_factor = intensity/SOLAR_MULT makes a
-- panel's real output exactly production * intensity. We do NOT also write
-- surface.solar_power_multiplier here: that would stack ON TOP of the property
-- and over-scale the whole curve (baseline included). The flare swing is the
-- daylight cycle, not the multiplier.
function M.apply(surface, tick)
  M.ensure_schedule(tick, M.seed_for(surface))
  local warning_start = M.advance_schedule(tick)
  local st = M.state(tick, warning_start)
  st.warning_start = warning_start
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

-- Cross-mod flare forecast for a surface index: the `cindra-flare` remote
-- interface the environmental scanner (ci-3o3) reads. REACTIVE early warning -
-- because flares are now sporadic (unpredictable by clock), this returns nil
-- during CALM and only reports { countdown, phase, intensity } once a flare has
-- entered its telegraph (or is active). Read-only: it never advances or rolls the
-- schedule (that is the driver's job via apply), so a scanner query has no side
-- effects on the timing.
function M.forecast(surface_index)
  local surface = game.get_surface(surface_index)
  if not surface or surface.name ~= C.SURFACE then return nil end
  local s = storage.cindra_flare_sched
  if not s then return nil end
  local st = M.state(game.tick, s.warning_start)
  if st.phase == M.PHASE.CALM then return nil end
  return { countdown = st.countdown, phase = st.phase, intensity = st.intensity }
end

return M
