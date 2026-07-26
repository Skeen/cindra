-- PROOF: a flare cycle occurs on schedule with the telegraph and a ~100x peak
-- vs baseline (planet_design.md sec.10 "Solar flares", sec.16 tuning rows).
--
-- Two layers: the canonical schedule (pure flare.state, exact) and the engine
-- embodiment (applying it to a real surface really swings solar output ~100x).

local H = require("tests.helpers")
local C = require("scripts.config")
local flare = require("scripts.flare")

describe("flare cycle - canonical schedule", function()
  local P = flare.PHASE

  it("is calm on baseline between flares (no damage risk, non-zero floor)", function()
    local s = flare.state(10)
    assert.are.equal(P.CALM, s.phase)
    assert.are.equal(C.BASELINE_INTENSITY, s.intensity)
    assert.is_false(s.warning)
    assert.is_false(s.is_flare)
  end)

  it("telegraphs with a warning + countdown before power moves", function()
    -- Warning begins exactly at the end of calm; countdown = full warning window.
    local start = flare.state(C.CALM_TICKS)
    assert.are.equal(P.WARNING, start.phase)
    assert.is_true(start.warning)
    assert.are.equal(C.WARNING_TICKS, start.countdown)
    -- Power is still at baseline during the telegraph (lead time to react).
    assert.are.equal(C.BASELINE_INTENSITY, start.intensity)
    assert.is_false(start.is_flare)
    -- Countdown ticks down toward the ramp.
    local mid = flare.state(C.CALM_TICKS + 10)
    assert.are.equal(C.WARNING_TICKS - 10, mid.countdown)
  end)

  it("ramps fast, plateaus at the ~100x peak, then decays fast", function()
    local ramp = flare.state(C.CALM_TICKS + C.WARNING_TICKS + C.RAMP_TICKS / 2)
    assert.are.equal(P.RAMP, ramp.phase)
    assert.is_true(ramp.is_flare)
    assert.is_true(ramp.intensity > C.BASELINE_INTENSITY and ramp.intensity < C.PEAK_INTENSITY)

    local plateau = flare.state(C.CALM_TICKS + C.WARNING_TICKS + C.RAMP_TICKS + 10)
    assert.are.equal(P.PLATEAU, plateau.phase)
    assert.are.equal(C.PEAK_INTENSITY, plateau.intensity)

    local decay = flare.state(C.CALM_TICKS + C.WARNING_TICKS + C.RAMP_TICKS
      + C.PLATEAU_TICKS + C.DECAY_TICKS / 2)
    assert.are.equal(P.DECAY, decay.phase)
    assert.is_true(decay.intensity > C.BASELINE_INTENSITY and decay.intensity < C.PEAK_INTENSITY)
  end)

  it("peak is ~100x baseline (the signature magnitude)", function()
    assert.are.equal(100, C.PEAK_INTENSITY / C.BASELINE_INTENSITY)
    assert.are.equal(C.SOLAR_MULT, C.PEAK_INTENSITY / C.BASELINE_INTENSITY)
  end)

  it("cadence is regular: the schedule repeats every period", function()
    for _, t in ipairs({ 0, 137, C.CALM_TICKS + 5, 999 }) do
      local a, b = flare.state(t), flare.state(t + C.PERIOD_TICKS)
      assert.are.equal(a.phase, b.phase)
      assert.are.equal(a.intensity, b.intensity)
    end
  end)

  it("phases occur in order across one period", function()
    local order = { P.CALM, P.WARNING, P.RAMP, P.PLATEAU, P.DECAY }
    local rank = {}
    for i, ph in ipairs(order) do rank[ph] = i end
    local last = 0
    for t = 0, C.PERIOD_TICKS - 1, 15 do
      local r = rank[flare.state(t).phase]
      assert.is_true(r >= last, "phase went backwards at tick " .. t)
      last = r
    end
  end)
end)

describe("flare cycle - engine embodiment", function()
  it("driving daytime really swings real solar output ~100x (non-zero floor)", function()
    local s = H.surface()
    H.reset()
    H.grid(s, 0, 0)               -- one substation networks everything
    H.panel(s, { 0, 5 })
    local sink = H.measure_sink(s, { 0, -5 })

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
