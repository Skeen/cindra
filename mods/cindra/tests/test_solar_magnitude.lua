-- PROOF (ci-ezk): a vanilla solar panel's ABSOLUTE output on Cindra. The prior
-- tests only checked RATIOS (peak/baseline, sunward/nightward), so a baseline
-- crushed to ~3 kW (a nightward band on the old 60 kW floor) slipped through with
-- every relative assertion still green. These tests pin the real magnitudes:
--
--   * OUTSIDE FLARES: a full-band vanilla panel produces ~330 kW -- MORE than
--     Vulcanus (measured live at 240 kW), because Cindra is the best solar planet.
--     The ci-63d balance target is additive: baseline = Vulcanus + 100-200 PERCENTAGE
--     POINTS of Nauvis (60 kW = 100%), i.e. Vulcanus (400%) + 100-200 pp = 500-600%
--     = 300-360 kW. 330 kW = +150 pp, mid-range. NOT the old +267 pp (400 kW) that
--     overshot, and NOT a 2x-3x multiple. Verified LIVE against Vulcanus below.
--   * DURING A FLARE: it jumps into the MW range (~6 MW at the plateau).
--   * The tidal-lock DIM sky (the flare driver freezes daytime deep toward night)
--     must NOT suppress production: a visually near-dark sky still delivers 330 kW.
--     Visual darkness and solar production are decoupled.
--
-- Position scaling (sunward panels beat nightward ones) is proven end-to-end in
-- tests/test_panel_solar.lua; those tests are unchanged and stay green, because the
-- re-baseline lifts every band uniformly (the bands are a fraction of the nominal,
-- prototypes/flare.lua).

local H = require("tests.helpers")
local C = require("scripts.flare-config")
local flare = require("scripts.flare")

-- A deterministic flare anchor: tick 10 is calm (baseline), PLATEAU_TICK is peak.
local WS = 600
local PLATEAU_TICK = WS + C.WARNING_TICKS + C.RAMP_TICKS + 10

-- Watts a measurement sink absorbs over a 2 s (120-tick) window. The sink's flow
-- (C.MEASURE_FLOW_W = 500 MW) dwarfs a single panel's output, so nothing throttles
-- and the energy gained is a clean read of real, unthrottled panel output.
local function watts_over_window(sink, cb)
  sink.energy = 0
  after_ticks(120, function() cb(sink.energy / (120 / 60)) end)
end

-- A vanilla solar panel on a freshly-created Vulcanus surface at noon (full sun):
-- the live 240 kW reference the bead compares Cindra against.
local function vulcanus_panel_noon()
  local s = game.surfaces["vulcanus"] or game.planets["vulcanus"].create_surface()
  s.request_to_generate_chunks({ 0, 0 }, 2)
  s.force_generate_chunk_requests()
  for _, e in pairs(s.find_entities_filtered({ area = { { -30, -30 }, { 30, 30 } },
    name = { "solar-panel", "substation", C.MEASURE_SINK } })) do e.destroy() end
  local tiles = {}
  for x = -20, 20 do for y = -20, 20 do tiles[#tiles + 1] = { name = "refined-concrete", position = { x, y } } end end
  s.set_tiles(tiles)
  s.freeze_daytime = true
  s.daytime = 0 -- noon: a Vulcanus panel at its maximum
  local y = -6; while y <= 6 do s.create_entity({ name = "substation", position = { 0, y }, force = "player" }); y = y + 12 end
  s.create_entity({ name = "solar-panel", position = { 6, 0 }, force = "player" })
  return s, s.create_entity({ name = C.MEASURE_SINK, position = { -6, 0 }, force = "player" })
end

describe("solar output magnitude (ci-ezk)", function()
  it("outside flares a vanilla panel yields ~330 kW = Vulcanus (240 kW) + 100-200 pp (ci-63d target)", function()
    local s = H.cindra_surface()
    H.power_reset()
    flare.set_schedule(WS)
    H.grid(s, 0, 0)
    H.panel(s, { 6, 0 }) -- a fresh vanilla panel: the full (sunward) band
    local sink = H.measure_sink(s, { -6, 0 })

    -- Live Vulcanus reference, so the comparison survives any vanilla rebalance.
    local _, vulc_sink = vulcanus_panel_noon()

    flare.apply(s, 10) -- calm: the between-flare baseline floor
    async(700)
    watts_over_window(sink, function(base_w)
      watts_over_window(vulc_sink, function(vulc_w)
        assert.is_true(base_w > 310e3 and base_w < 350e3,
          "Cindra baseline must be ~330 kW; got " .. string.format("%.1f kW", base_w / 1e3))
        assert.is_true(vulc_w > 220e3 and vulc_w < 260e3,
          "sanity: the Vulcanus reference panel is ~240 kW; got " .. string.format("%.1f kW", vulc_w / 1e3))
        assert.is_true(base_w > vulc_w,
          "Cindra's baseline must BEAT Vulcanus (the best solar planet): "
            .. string.format("%.1f kW vs %.1f kW", base_w / 1e3, vulc_w / 1e3))

        -- The ci-63d balance target, verified LIVE against Vulcanus: baseline =
        -- Vulcanus + 100-200 PERCENTAGE POINTS of Nauvis (a Nauvis full-day panel is
        -- 60 kW = 100%, so 1 pp = 0.6 kW; 100 pp = 60 kW, 200 pp = 120 kW). This is
        -- the ADDITIVE target (not a 2x-3x multiple): Cindra beats Vulcanus modestly,
        -- "surplus, not overdrive". Computed from the live Vulcanus reading so it
        -- survives any vanilla solar rebalance.
        local NAUVIS_FULL_DAY_W = 60e3
        local pp = (base_w - vulc_w) / NAUVIS_FULL_DAY_W * 100
        assert.is_true(pp >= 100 and pp <= 200, string.format(
          "Cindra baseline must sit Vulcanus + 100-200 pp (additive, ci-63d); got +%.0f pp "
            .. "(%.1f kW vs Vulcanus %.1f kW)", pp, base_w / 1e3, vulc_w / 1e3))
        done()
      end)
    end)
  end)

  it("during a flare a vanilla panel jumps into the MW range (~6 MW)", function()
    local s = H.cindra_surface()
    H.power_reset()
    flare.set_schedule(WS)
    H.grid(s, 0, 0)
    H.panel(s, { 6, 0 })
    local sink = H.measure_sink(s, { -6, 0 })

    flare.apply(s, PLATEAU_TICK) -- plateau: the signature spike
    async(200)
    watts_over_window(sink, function(peak_w)
      assert.is_true(peak_w > 1e6,
        "flare output must be in the MW range; got " .. string.format("%.2f MW", peak_w / 1e6))
      assert.is_true(peak_w > 5e6 and peak_w < 7e6,
        "the flare plateau is ~6 MW per panel; got " .. string.format("%.2f MW", peak_w / 1e6))
      done()
    end)
  end)

  it("the dim tidal-lock sky does NOT suppress output (visual darkness decoupled from production)", function()
    local s = H.cindra_surface()
    H.power_reset()
    flare.set_schedule(WS)
    H.grid(s, 0, 0)
    H.panel(s, { 6, 0 })
    local sink = H.measure_sink(s, { -6, 0 })

    flare.apply(s, 10) -- baseline: the driver freezes daytime deep toward night
    -- The engine's raw daylight factor at the frozen baseline daytime is tiny
    -- (~0.055): the SKY reads as near-dark dusk. The visual dimness is the LOOK of
    -- the tidal-locked ribbon; it must not gate the (330 kW) production.
    local visual_sf = flare.solar_factor(C.BASELINE_INTENSITY)
    assert.is_true(visual_sf < 0.15,
      "baseline sky must read as visually dim (near-dark), not full day; sf=" .. string.format("%.3f", visual_sf))

    async(700)
    watts_over_window(sink, function(base_w)
      assert.is_true(base_w > 300e3,
        "the dim/dusk sky must still deliver the full ~330 kW baseline (decoupled); got "
          .. string.format("%.1f kW", base_w / 1e3))
      done()
    end)
  end)
end)
