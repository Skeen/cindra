-- PROOF for the one-way power-transfer PoC -- the "power diode" (ci-gcd).
--
-- Mandates from the bead, each an assertion below:
--   1. energy flows A->B up to the rate cap                (rate cap respected)
--   2. energy does NOT flow B->A (charge B, drain A)       (one-way)
--   3. rate cap respected                                  (never past the cap)
--   4. two-network isolation holds                         (distinct networks)
--
-- The device is two electric-energy-interface poles (prototypes/power-diode.lua)
-- bridged by scripts/diode.lua. The buffer-level tests drive diode.step directly
-- and are fully deterministic (no ticks). The network-level tests build two
-- genuinely ISOLATED electric networks (substations >18 tiles apart never wire
-- together) and let the registered runtime move power across, proving the
-- crossing happens end-to-end under the real engine.

local H = require("tests.helpers")
local C = require("scripts.diode-config")
local diode = require("scripts.diode")

-- A one-substation electric network centred at (cx, 0). Two of these placed far
-- apart (|cx| separation > 18, the substation wire reach) form two networks that
-- the engine never wires together -- the isolation the diode must bridge.
local function substation(s, cx)
  return s.create_entity({ name = "substation", position = { cx, 0 }, force = "player" })
end

local function place(s, name, pos)
  return s.create_entity({ name = name, position = pos, force = "player" })
end

-- A producer on a network: a vanilla EEI with runtime power_production set (the
-- same infinite-source pattern the other Cindra tests use). The input pole is a
-- LOAD, so it charges from this producer's power as real demand.
local function producer(s, pos, watts)
  local p = place(s, "electric-energy-interface", pos)
  p.power_production = watts
  p.power_usage = 0
  p.energy = p.electric_buffer_size
  return p
end

describe("power-diode (ci-gcd one-way transfer PoC)", function()
  it("moves energy A->B and respects the configured rate cap", function()
    local s = H.cindra_surface()
    H.power_reset()
    local input = place(s, C.INPUT, { -27, 0 })
    local output = place(s, C.OUTPUT, { 27, 0 })
    input.energy = input.electric_buffer_size -- source pole full
    output.energy = 0

    -- One step at an explicit rate/dt: the move is exactly the rate cap when
    -- supply and headroom are ample (rate/60 J per tick).
    local rate, dt = 6e6, 10
    local expect = rate / 60 * dt -- 1,000,000 J
    local moved = diode.step(input, output, { rate_w = rate, dt = dt })
    assert.are.equal(expect, moved, "one step must move exactly the rate cap")
    assert.are.equal(expect, output.energy, "the output pole gains the capped amount")
    assert.are.equal(input.electric_buffer_size - expect, input.energy,
      "the input pole loses exactly what the output gained")

    -- A second step moves the cap again: the cap is a per-step ceiling, not a
    -- one-off. Energy never crosses faster than the rate allows.
    local moved2 = diode.step(input, output, { rate_w = rate, dt = dt })
    assert.are.equal(expect, moved2, "the rate cap binds every step, not just the first")
    assert.are.equal(2 * expect, output.energy, "two capped steps = twice the cap, no more")
  end)

  it("never flows B->A: the script only ever moves input->output", function()
    local s = H.cindra_surface()
    H.power_reset()
    local input = place(s, C.INPUT, { -27, 0 })
    local output = place(s, C.OUTPUT, { 27, 0 })
    -- Charge the DESTINATION pole full, empty the SOURCE pole: the reverse of a
    -- forward transfer. A one-way device must move nothing.
    input.energy = 0
    output.energy = output.electric_buffer_size

    local moved = diode.step(input, output, { rate_w = 6e6, dt = 10 })
    assert.are.equal(0, moved, "a full output + empty input must transfer nothing")
    assert.are.equal(0, input.energy, "the input pole must NEVER gain energy from the output")
    assert.are.equal(output.electric_buffer_size, output.energy,
      "the output pole's charge is untouched -- no back-flow")
  end)

  it("keeps the two networks isolated (distinct electric networks)", function()
    local s = H.cindra_surface()
    H.power_reset()
    substation(s, -30)
    substation(s, 30)
    local input = place(s, C.INPUT, { -30, -4 }) -- inside network A's supply area
    local output = place(s, C.OUTPUT, { 30, -4 }) -- inside network B's supply area

    assert.is_truthy(input.electric_network_id, "input pole must join a network")
    assert.is_truthy(output.electric_network_id, "output pole must join a network")
    assert.is_not.equal(input.electric_network_id, output.electric_network_id,
      "the two poles must sit on SEPARATE networks -- the whole point of the diode")
  end)

  it("energy crosses A->B end-to-end through two real isolated networks", function()
    local s = H.cindra_surface()
    H.power_reset()
    substation(s, -30)
    substation(s, 30)
    -- Network A: a producer supplies the (load) input pole with power.
    producer(s, { -30, 6 }, 100e6)
    local input = place(s, C.INPUT, { -30, -4 })
    -- Network B: the (source) output pole feeds an empty accumulator, which
    -- charges only because the output pole is producing surplus into B.
    local output = place(s, C.OUTPUT, { 30, -4 })
    local sink = place(s, "accumulator", { 30, 6 })
    sink.energy = 0

    assert.is_not.equal(input.electric_network_id, output.electric_network_id,
      "setup must produce two isolated networks")

    -- Let the REGISTERED runtime (control.lua diode.register, nth-tick 7) drive
    -- the transfer while the networks settle: A charges the input pole, the
    -- sweep moves it to the output pole, the output pole feeds network B.
    async(600)
    after_ticks(400, function()
      assert.is_true(output.energy > 0,
        "power must cross the network boundary into the output pole: " .. output.energy)
      assert.is_true(sink.energy > 0,
        "the destination network B must actually receive power: " .. sink.energy)
      done()
    end)
  end)

  it("power never reaches A even when B is flooded and A is dark", function()
    local s = H.cindra_surface()
    H.power_reset()
    substation(s, -30)
    substation(s, 30)
    -- Network A: DARK -- an input pole and an empty accumulator, no producer.
    local input = place(s, C.INPUT, { -30, -4 })
    local a_acc = place(s, "accumulator", { -30, 4 })
    a_acc.energy = 0
    -- Network B: FLOODED -- a strong producer and the output pole.
    producer(s, { 30, 6 }, 100e6)
    local output = place(s, C.OUTPUT, { 30, -4 })

    assert.is_not.equal(input.electric_network_id, output.electric_network_id,
      "setup must produce two isolated networks")

    async(600)
    after_ticks(400, function()
      -- The output pole is discharge-only (input_flow_limit = 0): B's abundant
      -- power has NO way into the diode at all.
      assert.are.equal(0, output.energy,
        "the output pole must never soak power from network B: " .. output.energy)
      -- ...so nothing crosses, and dark network A stays dark.
      assert.are.equal(0, input.energy, "the input pole must stay empty (nothing feeds A): " .. input.energy)
      assert.are.equal(0, a_acc.energy, "network A must receive zero power from flooded network B: " .. a_acc.energy)
      done()
    end)
  end)
end)
