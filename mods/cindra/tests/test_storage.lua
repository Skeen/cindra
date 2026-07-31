-- PROOF: storage charges on the flare and discharges after (§15-9; DESIGN.md §5).
-- Live engine test: real panels drive real accumulators. The capacitor (fast,
-- small) fills the spike quickly; the battery (bulk, slow) soaks more slowly.
-- After the flare, a load drains both. Both tiers also self-discharge when idle:
-- the molten-salt battery punishingly (heat upkeep, ~5-10 min), the capacitor
-- much more gently (~15-20 min, ci-411). Integrated from flare-poc.

local H = require("tests.helpers")
local C = require("scripts.flare-config")
local flare = require("scripts.flare")
local sinks = require("scripts.sinks")

-- Pin a deterministic sporadic-flare anchor (flares are now randomly timed, so
-- the tests set their own schedule): the event's telegraph begins at WS, so tick
-- 10 is calm and PEAK_TICK lands on the plateau.
local WS = 600
local PEAK_TICK = WS + C.WARNING_TICKS + C.RAMP_TICKS + 10
local CALM_TICK = 10

describe("storage", function()
  it("capacitor + battery charge during the flare and discharge after it", function()
    local s = H.cindra_surface()
    H.power_reset()
    flare.set_schedule(WS)
    H.grid(s, 6, 18)
    H.panel_col(s, 4, 6)                     -- 24 MW at peak, 0.24 MW baseline
    local cap = H.capacitor(s, { -6, 6 })
    local bat = H.battery(s, { -6, 10 })
    H.dissipator(s, { -6, 14 })              -- a 20 MW load on the grid
    cap.energy = 0
    bat.energy = 0

    -- Flare peak: generation (24 MW) exceeds the 20 MW load, so surplus charges.
    flare.apply(s, PEAK_TICK)

    async(600)
    after_ticks(120, function()
      local cap1, bat1 = cap.energy, bat.energy
      assert.is_true(cap1 > 0, "capacitor must charge during the flare")
      assert.is_true(bat1 > 0, "battery must charge during the flare")
      -- The fast capacitor reaches a far higher fraction of its capacity than the
      -- bulk battery in the same window (it catches the spike; the battery soaks).
      local cap_frac = cap1 / cap.electric_buffer_size
      local bat_frac = bat1 / bat.electric_buffer_size
      assert.is_true(cap_frac > bat_frac,
        "capacitor must fill faster than the battery: cap=" .. string.format("%.2f", cap_frac)
        .. " bat=" .. string.format("%.2f", bat_frac))

      -- After the flare: baseline generation (0.24 MW) is far below the 20 MW load,
      -- so both accumulators discharge to help cover it.
      flare.apply(s, CALM_TICK)
      after_ticks(120, function()
        assert.is_true(cap.energy < cap1, "capacitor must discharge after the flare")
        assert.is_true(bat.energy < bat1, "battery must discharge after the flare")
        done()
      end)
    end)
  end)

  it("both tiers self-discharge when idle, but the capacitor far more gently than the battery (ci-411)", function()
    local s = H.cindra_surface()
    H.power_reset()
    H.grid(s, 6, 10)
    local cap = H.capacitor(s, { -6, 6 })
    local bat = H.battery(s, { -6, 10 })
    cap.energy = cap.electric_buffer_size
    bat.energy = bat.electric_buffer_size
    local cap0, bat0 = cap.energy, bat.energy

    sinks.apply_battery_upkeep(s)
    sinks.apply_capacitor_upkeep(s)

    local bat_drop = bat0 - bat.energy
    local cap_drop = cap0 - cap.energy
    -- Both leak, so neither stays full.
    assert.is_true(bat_drop > 0, "battery must bleed energy to heat upkeep when idle")
    assert.is_true(cap_drop > 0, "capacitor must also bleed a slight self-discharge leak when idle")
    -- The capacitor's leak is MUCH milder: far less energy lost per upkeep tick.
    assert.is_true(cap_drop * 5 < bat_drop,
      "capacitor leak must be far gentler than the battery's: cap_drop=" .. cap_drop
      .. " bat_drop=" .. bat_drop)
  end)

  it("molten-salt battery fully self-drains its 2.5 MJ in ~5-10 min unpowered (ci-wcu)", function()
    local s = H.cindra_surface()
    H.power_reset()
    local bat = H.battery(s, { -6, 10 })
    bat.energy = bat.electric_buffer_size

    -- Upkeep is applied once per flare-driver tick (every C.FLARE_INTERVAL game
    -- ticks). Convert the 5-min and 10-min bounds to a whole number of upkeep
    -- applications and drive the real drain that many times.
    local function upkeep_ticks(minutes)
      return math.floor(minutes * 60 * 60 / C.FLARE_INTERVAL)
    end
    local five_min = upkeep_ticks(5)
    local ten_min = upkeep_ticks(10)

    -- At the 5-minute mark it must NOT yet be empty (drain is not too fast).
    for _ = 1, five_min do sinks.apply_battery_upkeep(s) end
    assert.is_true(bat.energy > 0,
      "battery must still hold charge at 5 min (self-drain not too fast): energy=" .. bat.energy)

    -- By the 10-minute mark it must be fully drained (drain is not too slow).
    for _ = five_min + 1, ten_min do sinks.apply_battery_upkeep(s) end
    assert.are.equal(0, bat.energy,
      "battery must be fully drained by 10 min unpowered: energy=" .. bat.energy)
  end)

  it("idle capacitor self-drains its 0.5 MJ in ~15-20 min unpowered -- far slower than the battery (ci-411)", function()
    local s = H.cindra_surface()
    H.power_reset()
    local cap = H.capacitor(s, { -6, 6 })
    cap.energy = cap.electric_buffer_size

    -- Upkeep is applied once per flare-driver tick (every C.FLARE_INTERVAL game
    -- ticks). Convert the 15-min and 20-min bounds to a whole number of upkeep
    -- applications and drive the real drain that many times.
    local function upkeep_ticks(minutes)
      return math.floor(minutes * 60 * 60 / C.FLARE_INTERVAL)
    end
    local fifteen_min = upkeep_ticks(15)
    local twenty_min = upkeep_ticks(20)

    -- At the 15-minute mark it must NOT yet be empty (leak is a gentle trickle,
    -- not punishing) -- this is well past the battery's ~5-10 min full-drain, so
    -- the capacitor's leak is demonstrably far slower.
    for _ = 1, fifteen_min do sinks.apply_capacitor_upkeep(s) end
    assert.is_true(cap.energy > 0,
      "capacitor must still hold charge at 15 min (leak is a slight trickle): energy=" .. cap.energy)

    -- By the 20-minute mark it must be fully drained (leak is not so slow it never
    -- empties): the ~15-20 min self-discharge window from the bead.
    for _ = fifteen_min + 1, twenty_min do sinks.apply_capacitor_upkeep(s) end
    assert.are.equal(0, cap.energy,
      "capacitor must be fully drained by 20 min unpowered: energy=" .. cap.energy)
  end)

  it("a dissipator draws its rated ~20 MW against the engine, not just in the capture MODEL (ci-xs6)", function()
    -- sinks.capture counts DISSIPATOR_DRAW_W (20 MW) per dissipator unconditionally;
    -- the other storage tests only pin a >0.24 MW baseline. This pins the REAL draw:
    -- a lone dissipator on a grid whose ONLY power source is a measurement
    -- accumulator (500 MW flow, 5 GJ buffer) drains that accumulator at ~20 MW, so
    -- every watt lost over the window is genuinely drawn by the dissipator (mirrors
    -- test_solar_magnitude's engine-measured solar draw).
    local s = H.cindra_surface()
    H.power_reset()
    H.grid(s, 0, 12)
    H.dissipator(s, { 6, 6 })
    local src = H.measure_sink(s, { -6, 6 })
    src.energy = src.electric_buffer_size      -- the sole source: a full 5 GJ store

    -- Let the network form and the dissipator's 1 MJ input buffer prime, so the
    -- measured window reads steady-state draw, not the one-time buffer fill.
    async(600)
    after_ticks(120, function()
      local e0 = src.energy
      after_ticks(120, function()
        local drew_w = (e0 - src.energy) / (120 / 60)
        assert.is_true(drew_w > 18e6 and drew_w < 22e6,
          "a dissipator must draw its rated ~20 MW against the engine; got "
            .. string.format("%.2f MW", drew_w / 1e6))
        done()
      end)
    end)
  end)

  it("a fed capacitor stays charged -- the gentle leak is overwhelmed by active charging (ci-411)", function()
    local s = H.cindra_surface()
    H.power_reset()
    flare.set_schedule(WS)
    H.grid(s, 6, 14)
    H.panel_col(s, 4, 6)                     -- 24 MW surplus at peak feeds the grid
    local cap = H.capacitor(s, { -6, 6 })
    cap.energy = 0                           -- start empty; the flare must fill it

    -- Hold the flare at peak: the panels far outproduce the trickle leak.
    flare.apply(s, PEAK_TICK)
    async(600)
    after_ticks(300, function()
      -- The flare charged the empty capacitor to (near) full despite the leak.
      assert.is_true(cap.energy > 0.9 * cap.electric_buffer_size,
        "a fed capacitor must charge to near full: energy=" .. cap.energy)
      -- Bleed a full flare tick's worth of upkeep, then let the flare re-feed it:
      -- the trickle leak is instantly overwhelmed by active charging.
      sinks.apply_capacitor_upkeep(s)
      after_ticks(60, function()
        assert.is_true(cap.energy > 0.9 * cap.electric_buffer_size,
          "the gentle leak must be overwhelmed by feeding: energy=" .. cap.energy)
        done()
      end)
    end)
  end)
end)
