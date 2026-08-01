-- PROOF (ci-m96z): power-economy CONSERVATION invariants across Cindra's custom
-- power entities. Motivated by ci-76if, where a GREEN suite shipped a power diode
-- that drew a flat ~10 MW always AND generated ~10 MW from nothing: the old tests
-- asserted the IMPLEMENTATION MODEL (energy_usage == X) instead of the
-- player-observable INVARIANT (no free energy). This suite pins the invariant that
-- restating the constants can never satisfy:
--
--   * NO custom power entity creates net energy from nothing.
--   * A dark/empty source -> downstream receives 0 (no free generation).
--   * A drained accumulator with no source does NOT self-refill.
--   * The scripted accumulator upkeep only ever REMOVES energy (never adds, never
--     drives energy below 0).
--
-- Each test is RUNTIME/behavioral (drives the real engine or the real scripted
-- path) and would FAIL on a ci-76if-style free-energy regression, not just on a
-- changed constant.
--
-- Coverage map for "every custom power entity" (the bead's ask):
--   * power diode      -- tests/test_power_diode.lua owns the full demand-metered
--                         battery (OFF, idle, deficit, no-free-generation). A
--                         compact reaffirm of the headline invariant lives below.
--   * dissipator (EEI) -- the exact prototype TYPE that bit us on the diode; pinned
--                         below as a pure consumer that generates nothing.
--   * accumulators     -- capacitor + molten-salt battery: pinned below (no
--                         self-refill; upkeep is remove-only).
--   * solar panels     -- engine-native solar; their "no free energy above the
--                         rated ceiling" is pinned by tests/test_solar_magnitude.lua
--                         (output bounded ~6 MW peak / ~330 kW baseline, no free
--                         peak without the flare) and tests/test_panel_solar.lua.

local H = require("tests.helpers")
local C = require("scripts.flare-config")
local DC = require("scripts.diode-config")
local diode = require("scripts.diode")
local sinks = require("scripts.sinks")

describe("power conservation -- dissipator (EEI pure consumer, ci-m96z)", function()
  it("generates nothing: a dark grid with a dissipator never charges a witness store", function()
    local s = H.cindra_surface()
    H.power_reset()
    -- A grid with NO producer and NO charged store: only a dissipator plus an empty
    -- witness accumulator to catch any spurious generation. A ci-76if-style
    -- misconfig (energy_production / output_flow_limit > 0) would leak power onto
    -- the grid and charge the witness.
    H.grid(s, 0, 12)
    local diss = H.dissipator(s, { 6, 6 })
    diss.energy = 0
    local witness = H.measure_sink(s, { -6, 6 })
    witness.energy = 0

    async(600)
    after_ticks(300, function()
      -- The fuse cannot MANUFACTURE energy: with no source on the grid its own
      -- buffer never self-charges (the ci-76if hoarding shape), and no phantom
      -- surplus reaches the witness accumulator.
      assert.is_true(diss.energy < 1e3,
        "a dark-grid dissipator must not self-charge its own buffer: diss=" .. diss.energy)
      assert.are.equal(0, witness.energy,
        "a pure-consumer dissipator on a dark grid must generate nothing: witness=" .. witness.energy)
      done()
    end)
  end)

  it("the prototype can never SOURCE power (max production is zero)", function()
    -- A runtime read of the live prototype, paired with the behavioral test above:
    -- an electric-energy-interface can be made to PRODUCE (that is the ci-76if
    -- shape); the dissipator must not. `get_max_energy_production` reads the real
    -- energy_production the engine loaded, so a regression that gives the fuse a
    -- generation rate fails here. (The output_flow_limit field is deliberately NOT
    -- asserted: the engine reads a 0 flow limit back as "unlimited", so it is a
    -- misleading probe; the dark-grid runtime test above is the real one-way proof.)
    local d = prototypes.entity[C.DISSIPATOR]
    assert.are.equal("electric-energy-interface", d.type)
    assert.is_truthy(d.get_max_energy_production, "EEI prototypes expose get_max_energy_production")
    assert.are.equal(0, d.get_max_energy_production(),
      "the dissipator must produce zero energy -- it is a pure sink, never a source")
  end)
end)

describe("power conservation -- accumulators (capacitor + battery, ci-m96z)", function()
  it("a charged accumulator delivers only what it stored, then stays empty (no self-refill)", function()
    local s = H.cindra_surface()
    H.power_reset()
    -- The capacitor is the grid's ONLY energy: a full 0.5 MJ, no producer anywhere.
    -- A 20 MW dissipator drains it, then the grid goes dark. A self-generating
    -- accumulator would rebound above ~0; a conservative one rests empty.
    H.grid(s, 0, 12)
    local cap = H.capacitor(s, { -6, 6 })
    cap.energy = cap.electric_buffer_size
    H.dissipator(s, { 6, 6 })

    async(600)
    after_ticks(300, function()
      assert.is_true(cap.energy < 0.05 * cap.electric_buffer_size,
        "a drained accumulator with no source must NOT self-refill: energy=" .. cap.energy)
      done()
    end)
  end)

  it("scripted upkeep never generates charge in an empty store, and never goes negative", function()
    local s = H.cindra_surface()
    H.power_reset()
    -- EMPTY accumulators: the scripted self-discharge path (the kind of scripted
    -- power manipulation that bit us on the diode) must not conjure charge into an
    -- empty store, nor drive energy below zero.
    local cap = H.capacitor(s, { -6, 6 })
    local bat = H.battery(s, { -6, 10 })
    cap.energy = 0
    bat.energy = 0
    for _ = 1, 50 do
      sinks.apply_capacitor_upkeep(s)
      sinks.apply_battery_upkeep(s)
    end
    assert.are.equal(0, cap.energy, "upkeep must never generate charge in an empty capacitor")
    assert.are.equal(0, bat.energy, "upkeep must never generate charge in an empty battery")
  end)

  it("upkeep removes at most the stored energy: a full battery drains to exactly 0, never below", function()
    local s = H.cindra_surface()
    H.power_reset()
    -- energy OUT (drained by the leak) <= energy IN (stored): drive a charged
    -- battery all the way down and confirm it lands at EXACTLY 0, not a negative
    -- (free) charge. Bound the loop generously past the ~5-10 min full-drain window.
    local bat = H.battery(s, { -6, 10 })
    bat.energy = bat.electric_buffer_size
    for _ = 1, 5000 do
      if bat.energy <= 0 then break end
      sinks.apply_battery_upkeep(s)
    end
    assert.are.equal(0, bat.energy,
      "a fully drained battery must rest at exactly 0 (leak never removes more than is stored): energy=" .. bat.energy)
  end)
end)

describe("power conservation -- power diode (reaffirm ci-76if, ci-m96z)", function()
  it("carries nothing when the source buffer is empty (a dark source can't feed the sink)", function()
    -- The headline ci-76if invariant, reaffirmed for the conservation sweep: with
    -- an empty source (input) buffer the diode transfers nothing, so a dark source
    -- can never deliver free energy to the sink. The full demand-metered battery
    -- (OFF gate, idle no-parasitic-draw, deficit ramp, no-free-generation on source
    -- death) lives in tests/test_power_diode.lua.
    local s = H.cindra_surface()
    H.power_reset()
    diode.reset()
    local input = s.create_entity({ name = DC.INPUT, position = { -3, 0 }, force = "player" })
    local output = s.create_entity({ name = DC.OUTPUT, position = { 3, 0 }, force = "player" })
    input.energy = 0
    output.energy = 0

    local moved = diode.step(input, output, { rate_w = 6e6, dt = 10 })
    assert.are.equal(0, moved, "an empty source buffer must move zero energy (no free generation)")
    assert.are.equal(0, output.energy, "the sink gains nothing from a dark source")
  end)
end)
