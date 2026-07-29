-- Plain-Lua unit test for the pure flare schedule (scripts/flare.lua).
-- Run: cd mods/cindra && nix shell nixpkgs#lua -c lua unit-tests/test_flare.lua
--
-- flare.state(tick, warning_start), the sporadic scheduler's PRNG maths, and
-- flare.solar_factor(intensity) are pure (no game.* / storage), so their whole
-- surface is reachable here. The factorio-test in tests/test_flare.lua asserts
-- the SAME shape under the real runtime plus the engine embodiment (real solar
-- output swings ~100x, and a long run really produces randomized gaps); keep the
-- two in sync.

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

-- A fixed telegraph anchor for the pure-shape tests: with warning_start = WS,
-- state(tick, WS) is calm before WS, then the fixed event shape, then calm again
-- once tick >= WS + EVENT_TICKS. WS is arbitrary (the shape is anchor-relative).
local WS = 600
local WARN = WS + C.WARNING_TICKS
local RAMP_MID = WARN + C.RAMP_TICKS / 2
local PLATEAU = WARN + C.RAMP_TICKS + 10
local DECAY_MID = WARN + C.RAMP_TICKS + C.PLATEAU_TICKS + C.DECAY_TICKS / 2

test("calm on baseline before a flare (non-zero floor, no flare, no warning)", function()
  local s = flare.state(10, WS)
  assert_eq(P.CALM, s.phase, "phase")
  assert_eq(C.BASELINE_INTENSITY, s.intensity, "intensity")
  assert_true(not s.warning, "no warning during calm")
  assert_true(not s.is_flare, "not a flare during calm")
end)

test("calm again after the event fully decays", function()
  local s = flare.state(WS + C.EVENT_TICKS + 5, WS)
  assert_eq(P.CALM, s.phase, "phase back to calm past the event")
  assert_eq(C.BASELINE_INTENSITY, s.intensity, "intensity back to baseline")
  assert_true(not s.is_flare, "not a flare after the event")
end)

test("telegraphs with a warning + countdown before power moves", function()
  local start = flare.state(WS, WS)
  assert_eq(P.WARNING, start.phase, "warning starts at the anchor")
  assert_true(start.warning, "warning flag set")
  assert_eq(C.WARNING_TICKS, start.countdown, "countdown = full warning window")
  assert_eq(C.BASELINE_INTENSITY, start.intensity, "power still at baseline during telegraph")
  assert_true(not start.is_flare, "telegraph is not yet a flare")

  local mid = flare.state(WS + 10, WS)
  assert_eq(C.WARNING_TICKS - 10, mid.countdown, "countdown ticks down toward the ramp")
end)

test("ramps fast, plateaus at the ~100x peak, then decays fast", function()
  local ramp = flare.state(RAMP_MID, WS)
  assert_eq(P.RAMP, ramp.phase, "mid-ramp phase")
  assert_true(ramp.is_flare, "ramp is a flare")
  assert_true(ramp.intensity > C.BASELINE_INTENSITY and ramp.intensity < C.PEAK_INTENSITY, "ramp between base and peak")

  local plateau = flare.state(PLATEAU, WS)
  assert_eq(P.PLATEAU, plateau.phase, "plateau phase")
  assert_eq(C.PEAK_INTENSITY, plateau.intensity, "plateau at peak")

  local decay = flare.state(DECAY_MID, WS)
  assert_eq(P.DECAY, decay.phase, "mid-decay phase")
  assert_true(decay.intensity > C.BASELINE_INTENSITY and decay.intensity < C.PEAK_INTENSITY, "decay between peak and base")
end)

test("peak is ~100x baseline (the signature magnitude, unchanged by sporadic timing)", function()
  assert_eq(100, C.PEAK_INTENSITY / C.BASELINE_INTENSITY, "100x baseline")
  assert_eq(C.SOLAR_MULT, C.PEAK_INTENSITY / C.BASELINE_INTENSITY, "peak = the surface multiplier")
end)

test("phases occur in order across one event", function()
  local order = { P.WARNING, P.RAMP, P.PLATEAU, P.DECAY }
  local rank = {}
  for i, ph in ipairs(order) do rank[ph] = i end
  local last = 0
  for off = 0, C.EVENT_TICKS - 1, 15 do
    local r = rank[flare.state(WS + off, WS).phase]
    assert_true(r ~= nil, "in-event phase must be one of warning..decay at off " .. off)
    assert_true(r >= last, "phase went backwards at off " .. off)
    last = r
  end
end)

-- === Sporadic timing (the ci-2ba change) =====================================

test("calm gaps are randomized within the band and NOT constant", function()
  -- Walk the pure Lehmer PRNG over a long run and collect the calm gaps it draws.
  local state = 12345
  local gaps = {}
  for _ = 1, 200 do
    local gap
    gap, state = flare.next_calm(state)
    gaps[#gaps + 1] = gap
  end
  local seen = {}
  for _, g in ipairs(gaps) do
    assert_true(g >= C.CALM_MIN_TICKS and g <= C.CALM_MAX_TICKS,
      "gap in band [" .. C.CALM_MIN_TICKS .. "," .. C.CALM_MAX_TICKS .. "]: got " .. g)
    seen[g] = true
  end
  local distinct = 0
  for _ in pairs(seen) do distinct = distinct + 1 end
  assert_true(distinct > 5, "gaps must vary (sporadic, not a metronome): only " .. distinct .. " distinct values")
end)

test("the band spans a real range (min < max) so cadence genuinely varies", function()
  assert_true(C.CALM_MIN_TICKS > 0, "a real gap always separates flares (not clustered-to-death)")
  assert_true(C.CALM_MAX_TICKS > C.CALM_MIN_TICKS, "the calm is a band, not a fixed value")
end)

test("the calm band is the real-play 5-10 minute cadence (ci-1c7)", function()
  -- The gap between consecutive flares must be a random draw in ~[5min, 10min].
  -- At 60 ticks/s that is exactly 18000..36000 ticks. Every drawn gap sits in
  -- this band (asserted above via next_calm), so scheduled intervals fall inside
  -- the 5-10 min window and never on a fixed metronome.
  assert_eq(5 * 60 * 60, C.CALM_MIN_TICKS, "min gap is 5 minutes (18000 ticks)")
  assert_eq(10 * 60 * 60, C.CALM_MAX_TICKS, "max gap is 10 minutes (36000 ticks)")
end)

test("the PRNG is deterministic: same seed -> same gap sequence (save/load stable)", function()
  local a, b = 999, 999
  for _ = 1, 20 do
    local ga, gb
    ga, a = flare.next_calm(a)
    gb, b = flare.next_calm(b)
    assert_eq(ga, gb, "same seed reproduces the same gap")
  end
end)

test("every scheduled event is telegraphed: a warning precedes each ramp", function()
  -- Simulate the scheduler by hand (pure): start at an anchor, and for each event
  -- assert the telegraph precedes the surge, then roll the next random gap.
  local state = 424242
  local ws = 0
  for _ = 1, 30 do
    -- The instant the event begins is a warning, at baseline power.
    local at_start = flare.state(ws, ws)
    assert_eq(P.WARNING, at_start.phase, "event opens on the telegraph")
    assert_true(at_start.warning, "warning flag set at the event start")
    assert_eq(C.BASELINE_INTENSITY, at_start.intensity, "no surge before the telegraph ends")
    -- The ramp only begins AFTER the full warning window.
    local just_before_ramp = flare.state(ws + C.WARNING_TICKS - 1, ws)
    assert_eq(P.WARNING, just_before_ramp.phase, "still telegraphing right up to the ramp")
    local at_ramp = flare.state(ws + C.WARNING_TICKS, ws)
    assert_eq(P.RAMP, at_ramp.phase, "surge starts exactly when the telegraph ends")
    -- Advance to the next event via a random gap.
    local gap
    gap, state = flare.next_calm(state)
    ws = ws + C.EVENT_TICKS + gap
  end
end)

test("solar_factor inverts the multiplier: sf * SOLAR_MULT == intensity", function()
  assert_eq(C.BASELINE_INTENSITY, flare.solar_factor(C.BASELINE_INTENSITY) * C.SOLAR_MULT, "baseline sf")
  assert_eq(C.PEAK_INTENSITY, flare.solar_factor(C.PEAK_INTENSITY) * C.SOLAR_MULT, "peak sf")
  assert_eq(1.0, flare.solar_factor(C.PEAK_INTENSITY), "peak sf = full day")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
