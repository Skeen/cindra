-- PROOF: storage charges on the flare and discharges after (§15-9; DESIGN.md §5).
-- Live engine test: real panels drive real accumulators. The capacitor (fast,
-- small) fills the spike quickly; the battery (bulk, slow) soaks more slowly.
-- After the flare, a load drains both. The molten-salt battery also self-
-- discharges from heat upkeep; the capacitor does not. Integrated from flare-poc.

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

  it("molten-salt battery self-discharges from heat upkeep; capacitor does not", function()
    local s = H.cindra_surface()
    H.power_reset()
    H.grid(s, 6, 10)
    local cap = H.capacitor(s, { -6, 6 })
    local bat = H.battery(s, { -6, 10 })
    cap.energy = cap.electric_buffer_size
    bat.energy = bat.electric_buffer_size
    local bat0 = bat.energy

    sinks.apply_battery_upkeep(s)

    assert.is_true(bat.energy < bat0, "battery must bleed energy to heat upkeep when idle")
    assert.are.equal(cap.electric_buffer_size, cap.energy,
      "capacitor has no heat upkeep and must not self-discharge")
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
end)
