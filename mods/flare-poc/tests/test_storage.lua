-- PROOF: storage charges on the flare and discharges after (planet_design.md
-- sec.12 items 5-6). Live engine test: real panels drive real accumulators. The
-- capacitor (fast, small) fills the spike quickly; the battery (bulk, slow) soaks
-- more slowly. After the flare, a load drains both.

local H = require("tests.helpers")
local C = require("scripts.config")
local flare = require("scripts.flare")
local sinks = require("scripts.sinks")

local PEAK_TICK = C.CALM_TICKS + C.WARNING_TICKS + C.RAMP_TICKS + 10
local CALM_TICK = 10

describe("storage", function()
  it("capacitor + battery charge during the flare and discharge after it", function()
    local s = H.surface()
    H.reset()
    H.grid(s, -8, 8)
    H.panel_row(s, 4, -6, 6)                 -- 40 MW at peak, 0.4 MW baseline
    local cap = H.capacitor(s, { 0, -6 })
    local bat = H.battery(s, { 4, -6 })
    H.dissipator(s, { 8, -6 })               -- a 20 MW load on the grid
    cap.energy = 0
    bat.energy = 0

    -- Flare peak: generation (40 MW) far exceeds the load, so surplus charges.
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

      -- After the flare: baseline generation (0.4 MW) is far below the 20 MW load,
      -- so both accumulators discharge to help cover it.
      flare.apply(s, CALM_TICK)
      after_ticks(120, function()
        assert.is_true(cap.energy < cap1, "capacitor must discharge after the flare")
        assert.is_true(bat.energy < bat1, "battery must discharge after the flare")
        done()
      end)
    end)
  end)

  it("molten-salt battery self-discharges from heat upkeep; capacitor does not", function()
    local s = H.surface()
    H.reset()
    H.grid(s, 0, 0)
    local cap = H.capacitor(s, { 0, -6 })
    local bat = H.battery(s, { 4, -6 })
    cap.energy = cap.electric_buffer_size
    bat.energy = bat.electric_buffer_size
    local bat0 = bat.energy

    sinks.apply_battery_upkeep(s)

    assert.is_true(bat.energy < bat0, "battery must bleed energy to heat upkeep when idle")
    assert.are.equal(cap.electric_buffer_size, cap.energy,
      "capacitor has no heat upkeep and must not self-discharge")
  end)
end)
