-- Plain-Lua unit test for the pure reading maths (scripts/readings.lua).
-- Run: cd mods/env-scanner && nix shell nixpkgs#lua -c lua unit-tests/test_readings.lua
--
-- readings.lua is deliberately pure (no game.* / prototypes.* / remote.*), so
-- its whole surface is reachable here without Factorio. The factorio-test in
-- tests/test_scanner.lua asserts the SAME maths under the real runtime; keep the
-- two in sync.

package.path = package.path .. ";./?.lua;./?/init.lua"
local readings = require("scripts.readings")

local S = readings.SIGNALS
local NAUVIS = readings.DEFAULT_CURVE

local passed, failed = 0, 0

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
    print("ok - " .. name)
  else
    failed = failed + 1
    print("not ok - " .. name .. ": " .. tostring(err))
  end
end

local function assert_eq(a, b, msg)
  if a ~= b then error((msg or "values differ") .. " (" .. tostring(a) .. " ~= " .. tostring(b) .. ")", 2) end
end

local function assert_true(x, msg)
  if not x then error(msg or "expected true", 2) end
end

local function assert_near(a, b, eps, msg)
  eps = eps or 1e-9
  if math.abs(a - b) > eps then
    error((msg or "not near") .. " (" .. tostring(a) .. " vs " .. tostring(b) .. ")", 2)
  end
end

-- ============================================================================
-- solar_factor: the daylight curve (0..1)
-- ============================================================================
test("noon is full daylight, midnight is dark", function()
  assert_eq(1.0, readings.solar_factor(0.0, NAUVIS), "noon = full sun")
  assert_eq(0.0, readings.solar_factor(0.5, NAUVIS), "midnight = dark")
end)

test("daylight ramps linearly down at dusk and up at dawn", function()
  -- dusk=0.25, evening=0.45 -> midpoint 0.35 is half daylight.
  assert_near(0.5, readings.solar_factor(0.35, NAUVIS), 1e-9, "mid-dusk = 0.5")
  -- morning=0.55, dawn=0.75 -> midpoint 0.65 is half daylight.
  assert_near(0.5, readings.solar_factor(0.65, NAUVIS), 1e-9, "mid-dawn = 0.5")
end)

test("full-day plateau before dusk and after dawn", function()
  assert_eq(1.0, readings.solar_factor(0.20, NAUVIS), "pre-dusk still full day")
  assert_eq(1.0, readings.solar_factor(0.80, NAUVIS), "post-dawn full day")
  assert_eq(0.0, readings.solar_factor(0.50, NAUVIS), "deep night dark")
end)

test("daytime wraps: negative and >1 normalise", function()
  assert_near(readings.solar_factor(0.35, NAUVIS), readings.solar_factor(1.35, NAUVIS), 1e-9, "1.35 == 0.35")
  assert_near(readings.solar_factor(0.65, NAUVIS), readings.solar_factor(-0.35, NAUVIS), 1e-9, "-0.35 == 0.65")
end)

test("degenerate curve does not divide by zero", function()
  -- All four points collapsed onto one instant: the ramps have zero width, so
  -- the guards must avoid a divide-by-zero and still return a finite [0,1] value
  -- for every daytime (here: no night at all -> full day everywhere).
  local step = { dusk = 0.5, evening = 0.5, morning = 0.5, dawn = 0.5 }
  for _, t in ipairs({ 0.0, 0.25, 0.5, 0.75, 0.99 }) do
    local sf = readings.solar_factor(t, step)
    assert_true(sf == sf, "sf must not be NaN at t=" .. t)          -- NaN ~= NaN
    assert_true(sf >= 0.0 and sf <= 1.0, "sf in [0,1] at t=" .. t)
  end
end)

-- ============================================================================
-- surface_signals: the generic per-surface readout set
-- ============================================================================
test("noon on a normal planet: full daylight and solar, position 0", function()
  local out = readings.surface_signals(0.0, 1.0, 25000, NAUVIS)
  assert_eq(0, out[S.DAYTIME], "position permille at noon")
  assert_eq(100, out[S.DAYLIGHT], "daylight percent at noon")
  assert_eq(100, out[S.SOLAR], "solar percent = daylight * 1.0")
  assert_eq(0, out[S.TICK_OF_DAY], "tick of day at t=0")
end)

test("midnight: dark, but position and tick still advance", function()
  local out = readings.surface_signals(0.5, 1.0, 25000, NAUVIS)
  assert_eq(500, out[S.DAYTIME], "half-way round the day")
  assert_eq(0, out[S.DAYLIGHT], "no daylight at midnight")
  assert_eq(0, out[S.SOLAR], "no solar at midnight")
  assert_eq(12500, out[S.TICK_OF_DAY], "half of a 25000-tick day")
end)

test("solar multiplier scales solar output but not daylight fraction", function()
  -- A Cindra-style flare surface: same daylight curve, huge solar multiplier.
  local out = readings.surface_signals(0.0, 100.0, 25000, NAUVIS)
  assert_eq(100, out[S.DAYLIGHT], "daylight fraction is multiplier-independent")
  assert_eq(10000, out[S.SOLAR], "solar output = 100% * 100x = 10000%")
end)

test("tick-of-day scales with the configured day length", function()
  local out = readings.surface_signals(0.25, 1.0, 10000, NAUVIS)
  assert_eq(2500, out[S.TICK_OF_DAY], "quarter of a 10000-tick day")
end)

test("generic signals never include flare signals on their own", function()
  local out = readings.surface_signals(0.0, 1.0, 25000, NAUVIS)
  assert_eq(nil, out[S.FLARE_COUNTDOWN], "no flare countdown without a forecast")
  assert_eq(nil, out[S.FLARE_PHASE])
  assert_eq(nil, out[S.FLARE_INTENSITY])
end)

test("all four generic signals are always present (even when zero)", function()
  local out = readings.surface_signals(0.5, 1.0, 25000, NAUVIS)
  for _, name in ipairs({ S.DAYTIME, S.DAYLIGHT, S.SOLAR, S.TICK_OF_DAY }) do
    assert_true(out[name] ~= nil, name .. " must always be emitted")
  end
end)

-- ============================================================================
-- merge_forecast: the optional flare-forecast block
-- ============================================================================
test("forecast merges countdown, phase code, and intensity percent", function()
  local out = readings.surface_signals(0.0, 100.0, 25000, NAUVIS)
  readings.merge_forecast(out, { countdown = 780, phase = "warning", intensity = 1.0 })
  assert_eq(780, out[S.FLARE_COUNTDOWN], "countdown ticks pass through")
  assert_eq(readings.PHASE_CODE.warning, out[S.FLARE_PHASE], "phase string -> code")
  assert_eq(1, out[S.FLARE_PHASE], "warning code is 1")
  assert_eq(100, out[S.FLARE_INTENSITY], "baseline intensity 1.0 -> 100%")
end)

test("peak flare intensity emits a large percent", function()
  local out = {}
  readings.merge_forecast(out, { countdown = 0, phase = "plateau", intensity = 100.0 })
  assert_eq(readings.PHASE_CODE.plateau, out[S.FLARE_PHASE], "plateau code")
  assert_eq(3, out[S.FLARE_PHASE], "plateau code is 3")
  assert_eq(10000, out[S.FLARE_INTENSITY], "100x baseline -> 10000%")
  assert_eq(0, out[S.FLARE_COUNTDOWN], "countdown zero at the flare")
end)

test("every phase name maps to a distinct code 0..4", function()
  local seen = {}
  for _, phase in ipairs({ "calm", "warning", "ramp", "plateau", "decay" }) do
    local out = {}
    readings.merge_forecast(out, { phase = phase })
    local code = out[S.FLARE_PHASE]
    assert_true(code ~= nil, phase .. " must map to a code")
    assert_true(not seen[code], phase .. " code must be unique")
    seen[code] = true
  end
  assert_eq(5, (function() local n = 0 for _ in pairs(seen) do n = n + 1 end return n end)(), "five distinct phases")
end)

test("partial forecast degrades gracefully (missing fields skipped)", function()
  local out = {}
  readings.merge_forecast(out, { countdown = 42 })
  assert_eq(42, out[S.FLARE_COUNTDOWN], "countdown present")
  assert_eq(nil, out[S.FLARE_PHASE], "no phase field -> no phase signal")
  assert_eq(nil, out[S.FLARE_INTENSITY], "no intensity field -> no intensity signal")
end)

test("nil forecast is a no-op", function()
  local out = readings.surface_signals(0.0, 1.0, 25000, NAUVIS)
  local same = readings.merge_forecast(out, nil)
  assert_eq(out, same, "returns the same table")
  assert_eq(nil, out[S.FLARE_COUNTDOWN], "nothing added")
end)

test("unknown phase falls back to code 0", function()
  local out = {}
  readings.merge_forecast(out, { phase = "bogus" })
  assert_eq(0, out[S.FLARE_PHASE], "unknown phase -> 0")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
