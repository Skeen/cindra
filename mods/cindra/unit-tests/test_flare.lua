-- Plain-Lua unit test for the pure flare schedule (scripts/flare.lua).
-- Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_flare.lua
--
-- flare.state(tick) and flare.solar_factor(intensity) are pure (no game.* /
-- storage), so their whole maths surface is reachable here. The factorio-test
-- in tests/test_flare.lua asserts the SAME schedule under the real runtime plus
-- the engine embodiment (real solar output swings ~100x); keep the two in sync.

package.path = package.path .. ";./?.lua;./?/init.lua"
local C = require("scripts.flare-config")
local flare = require("scripts.flare")

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

local P = flare.PHASE

test("calm on baseline between flares (non-zero floor, no flare, no warning)", function()
  local s = flare.state(10)
  assert_eq(P.CALM, s.phase, "phase")
  assert_eq(C.BASELINE_INTENSITY, s.intensity, "intensity")
  assert_true(not s.warning, "no warning during calm")
  assert_true(not s.is_flare, "not a flare during calm")
end)

test("telegraphs with a warning + countdown before power moves", function()
  local start = flare.state(C.CALM_TICKS)
  assert_eq(P.WARNING, start.phase, "warning starts at end of calm")
  assert_true(start.warning, "warning flag set")
  assert_eq(C.WARNING_TICKS, start.countdown, "countdown = full warning window")
  assert_eq(C.BASELINE_INTENSITY, start.intensity, "power still at baseline during telegraph")
  assert_true(not start.is_flare, "telegraph is not yet a flare")

  local mid = flare.state(C.CALM_TICKS + 10)
  assert_eq(C.WARNING_TICKS - 10, mid.countdown, "countdown ticks down toward the ramp")
end)

test("ramps fast, plateaus at the ~100x peak, then decays fast", function()
  local ramp = flare.state(C.CALM_TICKS + C.WARNING_TICKS + C.RAMP_TICKS / 2)
  assert_eq(P.RAMP, ramp.phase, "mid-ramp phase")
  assert_true(ramp.is_flare, "ramp is a flare")
  assert_true(ramp.intensity > C.BASELINE_INTENSITY and ramp.intensity < C.PEAK_INTENSITY, "ramp between base and peak")

  local plateau = flare.state(C.CALM_TICKS + C.WARNING_TICKS + C.RAMP_TICKS + 10)
  assert_eq(P.PLATEAU, plateau.phase, "plateau phase")
  assert_eq(C.PEAK_INTENSITY, plateau.intensity, "plateau at peak")

  local decay = flare.state(C.CALM_TICKS + C.WARNING_TICKS + C.RAMP_TICKS + C.PLATEAU_TICKS + C.DECAY_TICKS / 2)
  assert_eq(P.DECAY, decay.phase, "mid-decay phase")
  assert_true(decay.intensity > C.BASELINE_INTENSITY and decay.intensity < C.PEAK_INTENSITY, "decay between peak and base")
end)

test("peak is ~100x baseline (the signature magnitude)", function()
  assert_eq(100, C.PEAK_INTENSITY / C.BASELINE_INTENSITY, "100x baseline")
  assert_eq(C.SOLAR_MULT, C.PEAK_INTENSITY / C.BASELINE_INTENSITY, "peak = the surface multiplier")
end)

test("cadence is regular: the schedule repeats every period", function()
  for _, t in ipairs({ 0, 137, C.CALM_TICKS + 5, 999 }) do
    local a, b = flare.state(t), flare.state(t + C.PERIOD_TICKS)
    assert_eq(a.phase, b.phase, "phase repeats at t=" .. t)
    assert_eq(a.intensity, b.intensity, "intensity repeats at t=" .. t)
  end
end)

test("phases occur in order across one period", function()
  local order = { P.CALM, P.WARNING, P.RAMP, P.PLATEAU, P.DECAY }
  local rank = {}
  for i, ph in ipairs(order) do rank[ph] = i end
  local last = 0
  for t = 0, C.PERIOD_TICKS - 1, 15 do
    local r = rank[flare.state(t).phase]
    assert_true(r >= last, "phase went backwards at tick " .. t)
    last = r
  end
end)

test("solar_factor inverts the multiplier: sf * SOLAR_MULT == intensity", function()
  assert_eq(C.BASELINE_INTENSITY, flare.solar_factor(C.BASELINE_INTENSITY) * C.SOLAR_MULT, "baseline sf")
  assert_eq(C.PEAK_INTENSITY, flare.solar_factor(C.PEAK_INTENSITY) * C.SOLAR_MULT, "peak sf")
  assert_eq(1.0, flare.solar_factor(C.PEAK_INTENSITY), "peak sf = full day")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
