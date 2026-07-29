-- PROOF: sporadic flares (ci-2ba) - randomized timing, but every event still
-- telegraphed with the fixed ramp/plateau/decay shape and ~100x peak (§15-7;
-- DESIGN.md §5, §7). Integrated from flare-poc.
--
-- Layers:
--   * canonical shape (pure flare.state - exhaustive maths live in the plain-Lua
--     unit-tests/test_flare.lua; a smoke check here keeps the two in sync),
--   * sporadic scheduling in-engine (a long run really yields randomized calm
--     gaps, never a fixed period),
--   * engine embodiment (applying an event to the real Cindra surface swings
--     solar output ~100x),
--   * the reactive forecast source the environmental scanner reads.

local H = require("tests.helpers")
local C = require("scripts.flare-config")
local flare = require("scripts.flare")

-- A deterministic telegraph anchor for the shape/embodiment tests. With
-- warning_start = WS, tick 10 is calm and WS.. is the fixed event shape.
local WS = 600
local PLATEAU_TICK = WS + C.WARNING_TICKS + C.RAMP_TICKS + 10

describe("flare cycle - canonical shape", function()
  local P = flare.PHASE

  it("is calm on baseline before a flare (non-zero floor, no damage risk)", function()
    local s = flare.state(10, WS)
    assert.are.equal(P.CALM, s.phase)
    assert.are.equal(C.BASELINE_INTENSITY, s.intensity)
    assert.is_false(s.is_flare)
  end)

  it("telegraphs, then ramps to the ~100x peak, then decays", function()
    local warn = flare.state(WS, WS)
    assert.are.equal(P.WARNING, warn.phase)
    assert.is_true(warn.warning)
    assert.are.equal(C.WARNING_TICKS, warn.countdown)
    assert.are.equal(C.BASELINE_INTENSITY, warn.intensity) -- power still at baseline

    local plateau = flare.state(PLATEAU_TICK, WS)
    assert.are.equal(P.PLATEAU, plateau.phase)
    assert.are.equal(C.PEAK_INTENSITY, plateau.intensity)
    assert.are.equal(100, C.PEAK_INTENSITY / C.BASELINE_INTENSITY) -- the signature magnitude
  end)
end)

describe("flare cycle - sporadic timing", function()
  it("a long run yields randomized calm gaps, never a fixed period", function()
    local s = H.cindra_surface()
    H.power_reset() -- clears the schedule + disables the periodic driver

    -- Drive the flare across many events and record each distinct event anchor.
    -- Run long enough that even at the maximum calm gap we still get several
    -- events (bound derived from the config so it stays correct if the band is
    -- retuned): ~8 worst-case periods.
    local run_ticks = 8 * (C.CALM_MAX_TICKS + flare.EVENT_TICKS)
    local starts, seen = {}, {}
    for tick = 0, run_ticks, C.FLARE_INTERVAL do
      flare.apply(s, tick)
      local ws = storage.cindra_flare_sched.warning_start
      if not seen[ws] then
        seen[ws] = true
        starts[#starts + 1] = ws
      end
    end
    assert.is_true(#starts >= 5, "several flares must fire across the run; got " .. #starts)

    table.sort(starts)
    local gaps, first, all_same = {}, nil, true
    for i = 2, #starts do
      local gap = starts[i] - starts[i - 1] - flare.EVENT_TICKS
      gaps[#gaps + 1] = gap
      assert.is_true(gap >= C.CALM_MIN_TICKS and gap <= C.CALM_MAX_TICKS,
        "each calm gap must sit within the band [" .. C.CALM_MIN_TICKS .. "," .. C.CALM_MAX_TICKS
        .. "]; got " .. gap)
      first = first or gap
      if gap ~= first then all_same = false end
    end
    assert.is_true(#gaps >= 4, "need several gaps to judge variance; got " .. #gaps)
    assert.is_false(all_same, "gaps must vary (sporadic), not repeat a fixed period")
  end)

  it("is deterministic on save/load: the same schedule + tick reproduces the anchor", function()
    local s = H.cindra_surface()
    H.power_reset()
    flare.set_schedule(1000, 777)
    local a = flare.advance_schedule(5000)
    -- Re-pin the identical schedule and advance the same way: same anchor.
    flare.set_schedule(1000, 777)
    local b = flare.advance_schedule(5000)
    assert.are.equal(a, b, "same rng seed + ticks -> same sporadic anchor")
  end)
end)

describe("flare cycle - engine embodiment", function()
  it("driving daytime really swings real solar output ~100x (non-zero floor)", function()
    local s = H.cindra_surface()
    H.power_reset()
    flare.set_schedule(WS) -- pin a deterministic event so the ticks below land right
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
      flare.apply(s, PLATEAU_TICK)
      after_ticks(120, function()
        local peak_e = sink.energy
        local ratio = peak_e / base_e
        assert.is_true(ratio > 50 and ratio < 150,
          "real solar output must swing ~100x baseline; got " .. string.format("%.1f", ratio))
        done()
      end)
    end)
  end)

  it("apply records the live intensity for the damage sweep to read", function()
    -- current_intensity() is what the driver hands panels.sweep each tick when no
    -- intensity is passed; it must reflect the last-applied flare state.
    local s = H.cindra_surface()
    H.power_reset()
    flare.set_schedule(WS)
    flare.apply(s, 10) -- calm
    assert.are.equal(C.BASELINE_INTENSITY, flare.current_intensity(),
      "current intensity is the baseline between flares")
    flare.apply(s, PLATEAU_TICK) -- plateau
    assert.are.equal(C.PEAK_INTENSITY, flare.current_intensity(),
      "current intensity tracks the flare peak while it is applied")
  end)
end)

describe("flare forecast (reactive early-warning source, ci-3o3 contract)", function()
  local P = flare.PHASE

  it("returns nil during calm, so the scanner can't predict a sporadic flare by clock", function()
    local s = H.cindra_surface()
    H.power_reset()
    -- Next event is well in the future: right now is calm.
    flare.set_schedule(game.tick + 500)
    assert.is_nil(flare.forecast(s.index), "calm before the telegraph -> no forecast")

    -- Past a fully-decayed event is also calm.
    flare.set_schedule(game.tick - flare.EVENT_TICKS - 10)
    assert.is_nil(flare.forecast(s.index), "after the event -> back to calm, no forecast")
  end)

  it("reports the live forecast once a flare telegraphs or is active", function()
    local s = H.cindra_surface()
    H.power_reset()

    -- Telegraph window: warning starts exactly now.
    flare.set_schedule(game.tick)
    local warn = flare.forecast(s.index)
    assert.is_not_nil(warn, "warning window -> forecast present")
    assert.are.equal(P.WARNING, warn.phase)
    assert.are.equal(C.WARNING_TICKS, warn.countdown)
    assert.are.equal(C.BASELINE_INTENSITY, warn.intensity)

    -- Active (plateau): anchor placed so 'now' sits on the plateau.
    flare.set_schedule(game.tick - (C.WARNING_TICKS + C.RAMP_TICKS + 10))
    local active = flare.forecast(s.index)
    assert.is_not_nil(active, "active flare -> forecast present")
    assert.are.equal(P.PLATEAU, active.phase)
    assert.are.equal(C.PEAK_INTENSITY, active.intensity)
  end)

  it("never forecasts for a non-Cindra surface (per-planet gate)", function()
    flare.set_schedule(game.tick) -- an active telegraph on Cindra's schedule...
    local nauvis = game.surfaces["nauvis"]
    assert.is_not_nil(nauvis, "vanilla nauvis exists")
    assert.is_nil(flare.forecast(nauvis.index), "...must not leak to another planet")
  end)

  it("is wired to the cindra-flare remote interface the scanner calls", function()
    -- control.lua must register the interface so the standalone env-scanner can
    -- reach the forecast across mods. Exercise the real remote path, not just the
    -- module function.
    local iface = remote.interfaces["cindra-flare"]
    assert.is_not_nil(iface, "cindra-flare interface must be registered")
    assert.is_true(iface["forecast"], "forecast method must be exposed")

    local s = H.cindra_surface()
    H.power_reset()
    flare.set_schedule(game.tick + 500) -- calm
    assert.is_nil(remote.call("cindra-flare", "forecast", s.index),
      "remote forecast is nil during calm")
    flare.set_schedule(game.tick) -- telegraphing now
    local warn = remote.call("cindra-flare", "forecast", s.index)
    assert.is_not_nil(warn, "remote forecast present once telegraphing")
    assert.are.equal(P.WARNING, warn.phase)
  end)
end)
