-- PROOF: a flare cycle occurs on schedule with a telegraph and a ~100x peak vs
-- baseline (§15-7; DESIGN.md §5, §7 tuning table). Integrated from flare-poc.
--
-- Two layers: the canonical schedule (pure flare.state — the exhaustive maths
-- lives in the plain-Lua unit-tests/test_flare.lua; a smoke check here keeps the
-- two in sync) and the engine embodiment (applying it to the real Cindra surface
-- really swings solar output ~100x).

local H = require("tests.helpers")
local C = require("scripts.flare-config")
local flare = require("scripts.flare")

describe("flare cycle - canonical schedule", function()
  local P = flare.PHASE

  it("is calm on baseline between flares (non-zero floor, no damage risk)", function()
    local s = flare.state(10)
    assert.are.equal(P.CALM, s.phase)
    assert.are.equal(C.BASELINE_INTENSITY, s.intensity)
    assert.is_false(s.is_flare)
  end)

  it("telegraphs, then ramps to the ~100x peak, then decays", function()
    local warn = flare.state(C.CALM_TICKS)
    assert.are.equal(P.WARNING, warn.phase)
    assert.is_true(warn.warning)
    assert.are.equal(C.WARNING_TICKS, warn.countdown)
    assert.are.equal(C.BASELINE_INTENSITY, warn.intensity) -- power still at baseline

    local plateau = flare.state(C.CALM_TICKS + C.WARNING_TICKS + C.RAMP_TICKS + 10)
    assert.are.equal(P.PLATEAU, plateau.phase)
    assert.are.equal(C.PEAK_INTENSITY, plateau.intensity)
    assert.are.equal(100, C.PEAK_INTENSITY / C.BASELINE_INTENSITY) -- the signature magnitude
  end)

  it("cadence is regular: the schedule repeats every period", function()
    for _, t in ipairs({ 0, 137, C.CALM_TICKS + 5, 999 }) do
      local a, b = flare.state(t), flare.state(t + C.PERIOD_TICKS)
      assert.are.equal(a.phase, b.phase)
      assert.are.equal(a.intensity, b.intensity)
    end
  end)
end)

describe("flare cycle - engine embodiment", function()
  it("driving daytime really swings real solar output ~100x (non-zero floor)", function()
    local s = H.cindra_surface()
    H.power_reset()
    H.grid(s, 0, 0)                 -- one substation networks everything
    H.panel(s, { 6, 0 })
    local sink = H.measure_sink(s, { -6, 0 })

    -- Baseline (calm): measure unthrottled panel output over a window.
    flare.apply(s, 10)
    sink.energy = 0
    async(600)
    after_ticks(120, function()
      local base_e = sink.energy
      assert.is_true(base_e > 0, "night floor must be non-zero (baseline runs the factory)")

      -- Peak (plateau): same window, same rig.
      sink.energy = 0
      flare.apply(s, C.CALM_TICKS + C.WARNING_TICKS + C.RAMP_TICKS + 10)
      after_ticks(120, function()
        local peak_e = sink.energy
        local ratio = peak_e / base_e
        assert.is_true(ratio > 50 and ratio < 150,
          "real solar output must swing ~100x baseline; got " .. string.format("%.1f", ratio))
        done()
      end)
    end)
  end)
end)
