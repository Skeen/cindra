-- PROOF for the one-way power-transfer device -- the "power diode" (ci-gcd,
-- reworked to a power-SWITCH-style single building in ci-8l4).
--
-- Mandates, each an assertion below:
--   1. it is ONE building (a power-switch) with TWO copper inputs -- not two
--      separately-placed poles paired by proximity                (the rework)
--   2. placing the device spawns + wires its hidden guts, and removing it tears
--      them down                                                  (composite lifecycle)
--   3. energy flows source->sink up to the rate cap               (rate cap respected)
--   4. energy does NOT flow sink->source (charge B, drain A)      (one-way)
--   5. two-network isolation holds                                (distinct networks)
--
-- The device (prototypes/power-diode.lua) is a reskinned power-switch; on build
-- the runtime (scripts/diode.lua) spawns two HIDDEN electric-energy-interface
-- buffers + two tap poles and copper-wires each tap to a switch connector, so the
-- player's two wired networks each host one buffer. The buffer-level tests drive
-- diode.step directly and are fully deterministic (no ticks). The network-level
-- tests build two genuinely ISOLATED networks (wired to the switch's two sides,
-- which the OPEN switch keeps apart) and let the registered runtime shuttle power
-- across, proving the crossing happens end-to-end under the real engine.

local H = require("tests.helpers")
local C = require("scripts.diode-config")
local diode = require("scripts.diode")

local WCID = defines.wire_connector_id

local function place(s, name, pos)
  return s.create_entity({ name = name, position = pos, force = "player" })
end

-- Build the device and run the REAL build handler (raise_built -> the registered
-- script_raised_built -> diode.attach), so the whole placement pipeline -- spawn
-- guts, wire taps -- is exercised, not a test-only shortcut.
local function place_device(s, pos)
  return s.create_entity({ name = C.DEVICE, position = pos, force = "player", raise_built = true })
end

-- Copper-wire two entities' connectors (reach check off: the test spans networks
-- far apart, and the link is script-made).
local function copper(a, a_id, b, b_id)
  a.get_wire_connector(a_id, true).connect_to(b.get_wire_connector(b_id, true), false, defines.wire_origin.script)
end

-- A one-substation network centred at (cx, 0), returned so the caller can wire it
-- to a switch side.
local function substation(s, cx)
  return s.create_entity({ name = "substation", position = { cx, 0 }, force = "player" })
end

-- A producer on a network: a vanilla EEI with runtime power_production set (the
-- same infinite-source pattern the other Cindra tests use). A buffer that is a
-- LOAD charges from this producer's power as real demand.
local function producer(s, pos, watts)
  local p = place(s, "electric-energy-interface", pos)
  p.power_production = watts
  p.power_usage = 0
  p.energy = p.electric_buffer_size
  return p
end

describe("power-diode (ci-8l4 power-switch-style one-way device)", function()
  it("is ONE power-switch building with two copper connectors, not two placeable poles", function()
    local dev = prototypes.entity[C.DEVICE]
    assert.is_truthy(dev, "the device prototype must exist")
    assert.are.equal("power-switch", dev.type,
      "the device must be a power-switch (single building, two copper inputs)")
    -- Only the device is placeable: the buffers/taps are hidden guts with no item.
    assert.is_truthy(prototypes.item[C.DEVICE], "the device must have a placeable item")
    assert.is_nil(prototypes.item[C.INPUT], "the input buffer must NOT be a placeable item")
    assert.is_nil(prototypes.item[C.OUTPUT], "the output buffer must NOT be a placeable item")
    -- The hidden guts exist as entities but are not selectable/on-map.
    for _, name in ipairs({ C.INPUT, C.OUTPUT, C.INPUT_TAP, C.OUTPUT_TAP }) do
      assert.is_truthy(prototypes.entity[name], "hidden gut prototype must exist: " .. name)
    end
  end)

  it("spawns + wires its hidden guts on build, and tears them down on removal", function()
    local s = H.cindra_surface()
    H.power_reset()
    diode.reset()

    local dev = place_device(s, { 0, 0 })
    local d = diode.registry()[dev.unit_number]
    assert.is_truthy(d, "building the device must register it")
    assert.is_true(d.input.valid and d.output.valid, "both buffers must be spawned")
    assert.is_true(d.input_tap.valid and d.output_tap.valid, "both tap poles must be spawned")
    -- The input buffer's tap is wired to the LEFT connector, the output's to the
    -- RIGHT -- the two power inputs of the switch.
    local left = dev.get_wire_connector(WCID.power_switch_left_copper, false)
    local right = dev.get_wire_connector(WCID.power_switch_right_copper, false)
    assert.is_true(left ~= nil and left.connection_count > 0, "left connector must be wired (source input)")
    assert.is_true(right ~= nil and right.connection_count > 0, "right connector must be wired (sink output)")

    -- Removing the device destroys every hidden gut and forgets the registration.
    local input, output, itap, otap = d.input, d.output, d.input_tap, d.output_tap
    dev.destroy({ raise_destroy = true })
    assert.is_nil(diode.registry()[nil], "sanity")
    assert.is_false(input.valid, "input buffer must be destroyed with the device")
    assert.is_false(output.valid, "output buffer must be destroyed with the device")
    assert.is_false(itap.valid, "input tap must be destroyed with the device")
    assert.is_false(otap.valid, "output tap must be destroyed with the device")
  end)

  it("moves energy source->sink and respects the configured rate cap", function()
    local s = H.cindra_surface()
    H.power_reset()
    local input = place(s, C.INPUT, { -3, 0 })
    local output = place(s, C.OUTPUT, { 3, 0 })
    input.energy = input.electric_buffer_size -- source buffer full
    output.energy = 0

    -- One step at an explicit rate/dt: the move is exactly the rate cap when
    -- supply and headroom are ample (rate/60 J per tick).
    local rate, dt = 6e6, 10
    local expect = rate / 60 * dt -- 1,000,000 J
    local moved = diode.step(input, output, { rate_w = rate, dt = dt })
    assert.are.equal(expect, moved, "one step must move exactly the rate cap")
    assert.are.equal(expect, output.energy, "the output buffer gains the capped amount")
    assert.are.equal(input.electric_buffer_size - expect, input.energy,
      "the input buffer loses exactly what the output gained")

    -- A second step moves the cap again: the cap is a per-step ceiling, not a
    -- one-off. Energy never crosses faster than the rate allows.
    local moved2 = diode.step(input, output, { rate_w = rate, dt = dt })
    assert.are.equal(expect, moved2, "the rate cap binds every step, not just the first")
    assert.are.equal(2 * expect, output.energy, "two capped steps = twice the cap, no more")
  end)

  it("never flows sink->source: the script only ever moves input->output", function()
    local s = H.cindra_surface()
    H.power_reset()
    local input = place(s, C.INPUT, { -3, 0 })
    local output = place(s, C.OUTPUT, { 3, 0 })
    -- Charge the DESTINATION buffer full, empty the SOURCE buffer: the reverse of
    -- a forward transfer. A one-way device must move nothing.
    input.energy = 0
    output.energy = output.electric_buffer_size

    local moved = diode.step(input, output, { rate_w = 6e6, dt = 10 })
    assert.are.equal(0, moved, "a full output + empty input must transfer nothing")
    assert.are.equal(0, input.energy, "the input buffer must NEVER gain energy from the output")
    assert.are.equal(output.electric_buffer_size, output.energy,
      "the output buffer's charge is untouched -- no back-flow")
  end)

  it("keeps the two wired networks isolated (distinct electric networks)", function()
    local s = H.cindra_surface()
    H.power_reset()
    diode.reset()
    local dev = place_device(s, { 0, 0 })
    local subA = substation(s, -30)
    local subB = substation(s, 30)
    copper(subA, WCID.pole_copper, dev, WCID.power_switch_left_copper)
    copper(subB, WCID.pole_copper, dev, WCID.power_switch_right_copper)
    local d = diode.registry()[dev.unit_number]

    async(120)
    after_ticks(60, function()
      assert.is_truthy(d.input.electric_network_id, "input buffer must join a network")
      assert.is_truthy(d.output.electric_network_id, "output buffer must join a network")
      assert.is_not.equal(d.input.electric_network_id, d.output.electric_network_id,
        "the two switch sides must stay on SEPARATE networks -- the whole point of the diode")
      done()
    end)
  end)

  it("energy crosses source->sink end-to-end through two real isolated networks", function()
    local s = H.cindra_surface()
    H.power_reset()
    diode.reset()
    local dev = place_device(s, { 0, 0 })
    -- Source network: a producer feeds the (load) input buffer with power.
    local subA = substation(s, -30)
    producer(s, { -30, 6 }, 100e6)
    -- Sink network: an empty accumulator that charges only because the (source)
    -- output buffer is producing surplus into it.
    local subB = substation(s, 30)
    local sink = place(s, "accumulator", { 30, 6 })
    sink.energy = 0
    copper(subA, WCID.pole_copper, dev, WCID.power_switch_left_copper)
    copper(subB, WCID.pole_copper, dev, WCID.power_switch_right_copper)
    local d = diode.registry()[dev.unit_number]

    -- Let the REGISTERED runtime (control.lua diode.register, nth-tick 7) drive
    -- the transfer while the networks settle.
    async(600)
    after_ticks(400, function()
      assert.is_not.equal(d.input.electric_network_id, d.output.electric_network_id,
        "setup must produce two isolated networks")
      assert.is_true(d.output.energy > 0,
        "power must cross into the output buffer: " .. d.output.energy)
      assert.is_true(sink.energy > 0,
        "the destination network must actually receive power: " .. sink.energy)
      done()
    end)
  end)

  it("power never reaches the source even when the sink is flooded and the source is dark", function()
    local s = H.cindra_surface()
    H.power_reset()
    diode.reset()
    local dev = place_device(s, { 0, 0 })
    -- Source network: DARK -- just an empty accumulator, no producer.
    local subA = substation(s, -30)
    local a_acc = place(s, "accumulator", { -30, 6 })
    a_acc.energy = 0
    -- Sink network: FLOODED -- a strong producer.
    local subB = substation(s, 30)
    producer(s, { 30, 6 }, 100e6)
    copper(subA, WCID.pole_copper, dev, WCID.power_switch_left_copper)
    copper(subB, WCID.pole_copper, dev, WCID.power_switch_right_copper)
    local d = diode.registry()[dev.unit_number]

    async(600)
    after_ticks(400, function()
      assert.is_not.equal(d.input.electric_network_id, d.output.electric_network_id,
        "setup must produce two isolated networks")
      -- The output buffer is discharge-only (input_flow_limit = 0): the sink's
      -- abundant power has NO way into the diode at all.
      assert.are.equal(0, d.output.energy,
        "the output buffer must never soak power from the sink network: " .. d.output.energy)
      -- ...so nothing crosses, and the dark source network stays dark.
      assert.are.equal(0, d.input.energy, "the input buffer must stay empty: " .. d.input.energy)
      assert.are.equal(0, a_acc.energy, "the source network must receive zero power from the flooded sink: " .. a_acc.energy)
      done()
    end)
  end)
end)
